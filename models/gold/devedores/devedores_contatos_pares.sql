{#
  Etapa comum da gold de devedores: os pares devedor × contato. Grão: um contato normalizado
  (`tipo_contato`, `contato`) de um devedor (`cpf`); o contato de documento vazio ou de RG sem
  ligação não tem devedor e fica numa linha própria por documento (`cpf` NULL), como a G2c'.
  Os documentos ligados ao mesmo CPF (G3a') contribuem para o mesmo par.
  `situacao_documento` é a do melhor documento pelo qual o contato chegou ao devedor (`cpf_valido`
  vence `cpf_corrigido`, que vence `rg_por_nome_nascimento`, `cpf_invalido` e `sem_documento`);
  `documento_original` é esse documento quando não é `cpf_valido`. `situacao_entrega` é `presente`
  quando algum provedor ainda mandou o par na última entrega dele, e `ausente` nos demais (ponto 7;
  uma versão atual da gama com a lista cortada também aparece como `ausente`). A rastreabilidade
  é da aparição mais recente do par. `sk_contato` é a posição do par em ordem de CPF, documento,
  tipo e contato (G6). É efêmero: existe para `dim_contato` e para a ligação das tentativas.
#}
{{ config(materialized='ephemeral') }}

WITH tComDono AS (
  SELECT
    devedores_contatos_registros.provedor
    , devedores_contatos_registros.documento
    , devedores_contatos_registros.tipo_contato
    , devedores_contatos_registros.contato
    , devedores_contatos_registros.data_primeira_entrega
    , devedores_contatos_registros.data_ultima_entrega
    , devedores_contatos_registros.dt_ultima_entrega_provedor
    , devedores_contatos_registros._arquivo
    , devedores_contatos_registros._linha
    , devedores_contatos_registros._hash_arquivo
    , devedores_documentos.cpf
    , CASE WHEN devedores_documentos.cpf IS NULL THEN devedores_contatos_registros.documento END
      AS documento_sem_devedor
    , CASE devedores_documentos.situacao_documento
      WHEN 'cpf_valido' THEN 1
      WHEN 'cpf_corrigido' THEN 2
      WHEN 'rg_por_nome_nascimento' THEN 3
      WHEN 'cpf_invalido' THEN 4
      ELSE 5
    END AS prioridade_documento
    , CASE
      WHEN devedores_contatos_registros.data_ultima_entrega
        = devedores_contatos_registros.dt_ultima_entrega_provedor THEN 1
      ELSE 0
    END AS entrega_presente
  FROM {{ ref('devedores_contatos_registros') }} AS devedores_contatos_registros
  LEFT JOIN {{ ref('devedores_documentos') }} AS devedores_documentos
    ON devedores_contatos_registros.documento_tipo = devedores_documentos.documento_tipo
      AND devedores_contatos_registros.documento = devedores_documentos.documento
)

, tOrdenadas AS (
  SELECT
    cpf
    , documento_sem_devedor
    , tipo_contato
    , contato
    , documento
    , prioridade_documento
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY cpf, documento_sem_devedor, tipo_contato, contato
      ORDER BY
        prioridade_documento ASC
        , data_ultima_entrega DESC NULLS LAST
        , documento ASC
        , provedor ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_documento
    , ROW_NUMBER() OVER (
      PARTITION BY cpf, documento_sem_devedor, tipo_contato, contato
      ORDER BY
        data_ultima_entrega DESC NULLS LAST
        , _arquivo COLLATE "C" DESC
        , _linha DESC
        , provedor ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tComDono
)

, tEntregas AS (
  SELECT
    cpf
    , documento_sem_devedor
    , tipo_contato
    , contato
    , MIN(data_primeira_entrega) AS dt_primeira_entrega
    , MAX(data_ultima_entrega) AS dt_ultima_entrega
    , COUNT(DISTINCT provedor) AS qt_provedores
    , MAX(entrega_presente) AS entrega_presente
  FROM tComDono
  GROUP BY cpf, documento_sem_devedor, tipo_contato, contato
)

, tMelhor AS (
  SELECT
    cpf
    , documento_sem_devedor
    , tipo_contato
    , contato
    , documento
    , CASE prioridade_documento
      WHEN 1 THEN 'cpf_valido'
      WHEN 2 THEN 'cpf_corrigido'
      WHEN 3 THEN 'rg_por_nome_nascimento'
      WHEN 4 THEN 'cpf_invalido'
      ELSE 'sem_documento'
    END AS situacao_documento
  FROM tOrdenadas
  WHERE 1 = 1
    AND num_documento = 1
)

, tUltima AS (
  SELECT
    cpf
    , documento_sem_devedor
    , tipo_contato
    , contato
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tOrdenadas
  WHERE 1 = 1
    AND num_aparicao = 1
)

, tMontada AS (
  SELECT
    tEntregas.cpf
    , tEntregas.documento_sem_devedor
    , tEntregas.tipo_contato
    , tEntregas.contato
    , dim_devedor.sk_devedor
    , dim_devedor.tipo_conflito_cadastral
    , tMelhor.situacao_documento
    , tEntregas.qt_provedores
    , tEntregas.dt_primeira_entrega
    , tEntregas.dt_ultima_entrega
    , tUltima._arquivo
    , tUltima._linha
    , tUltima._hash_arquivo
    , CASE
      WHEN tMelhor.situacao_documento <> 'cpf_valido' THEN tMelhor.documento
    END AS documento_original
    , CASE WHEN tEntregas.entrega_presente = 1 THEN 'presente' ELSE 'ausente' END
      AS situacao_entrega
  FROM tEntregas
  INNER JOIN tMelhor
    ON tEntregas.cpf IS NOT DISTINCT FROM tMelhor.cpf
      AND tEntregas.documento_sem_devedor IS NOT DISTINCT FROM tMelhor.documento_sem_devedor
      AND tEntregas.tipo_contato = tMelhor.tipo_contato
      AND tEntregas.contato = tMelhor.contato
  INNER JOIN tUltima
    ON tEntregas.cpf IS NOT DISTINCT FROM tUltima.cpf
      AND tEntregas.documento_sem_devedor IS NOT DISTINCT FROM tUltima.documento_sem_devedor
      AND tEntregas.tipo_contato = tUltima.tipo_contato
      AND tEntregas.contato = tUltima.contato
  LEFT JOIN {{ ref('dim_devedor') }} AS dim_devedor
    ON tEntregas.cpf = dim_devedor.cpf
)

SELECT
  CAST(
    ROW_NUMBER() OVER (
      ORDER BY
        cpf ASC NULLS LAST
        , documento_sem_devedor ASC NULLS LAST
        , tipo_contato ASC
        , contato ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS INTEGER
  ) AS sk_contato
  , sk_devedor
  , cpf
  , tipo_contato
  , contato
  , tipo_conflito_cadastral
  , situacao_documento
  , documento_original
  , situacao_entrega
  , qt_provedores
  , dt_primeira_entrega
  , dt_ultima_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tMontada
