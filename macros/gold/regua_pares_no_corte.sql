{#
  Pares devedor × contato como a régua os via na data de corte (G4c). Devolve as CTEs, sem o
  `WITH`, até `tParesVisiveis`, com as colunas que `regua_sinais_do_par` lê. Só entra no cálculo
  o que já tinha sido entregue até a data: a linha do contato e a versão do cadastro com
  `data_primeira_entrega` até a data. A última entrega vale no máximo a data (a silver não diz se
  o par saiu depois dela).
  O que se recalcula, para o par ter só o que a régua sabia em D:
    - `qt_provedores`: provedores que já tinham entregado o par;
    - `situacao_documento` e `documento_original`: o melhor documento, pela mesma prioridade de
      `devedores_contatos_pares`, só entre os documentos que já tinham entregado o par;
    - `tipo_conflito_cadastral`: os mesmos conflitos da `dim_devedor`, só com as versões já
      entregues (`identidade`: primeiro ou último nome diferente entre os provedores; `versao`:
      empate no topo das versões de um documento);
    - `sk_devedor`: o par só existe com uma linha entregue até D, e uma linha com CPF é de um
      devedor que a régua já conhecia; o valor é o da `dim_devedor`, e fica `NULL` para o par
      sem devedor.
  `sk_contato` é o da `devedores_contatos_pares` (a posição do par no conjunto todo), para a
  tentativa achar o par; um par visível em D existe nela, com a mesma chave.
  Limite: a ligação de um documento ao CPF (`devedores_documentos`: correção por um dígito e RG
  por nome e nascimento) é a final, não a de D. O teste `regua_sinais_no_corte_futuro_igual_a_
  operacao` prova que, com um corte depois da última entrega, tudo volta ao valor da operação.
#}
{% macro regua_pares_no_corte(data_corte) -%}
  {{ regua_valida_corte(data_corte) }}
  {%- set corte = "CAST('" ~ data_corte ~ "' AS DATE)" -%}
  tLinhasNoCorte AS (
    SELECT
      contatos.provedor
      , contatos.documento
      , contatos.tipo_contato
      , contatos.contato
      , contatos.data_primeira_entrega
      , LEAST(contatos.data_ultima_entrega, {{ corte }}) AS data_ultima_entrega
      , documentos.cpf
      , CASE WHEN documentos.cpf IS NULL THEN contatos.documento END AS documento_sem_devedor
      , CASE documentos.situacao_documento
        WHEN 'cpf_valido' THEN 1
        WHEN 'cpf_corrigido' THEN 2
        WHEN 'rg_por_nome_nascimento' THEN 3
        WHEN 'cpf_invalido' THEN 4
        ELSE 5
      END AS prioridade_documento
    FROM {{ ref('devedores_contatos_registros') }} AS contatos
    LEFT JOIN {{ ref('devedores_documentos') }} AS documentos
      ON contatos.documento_tipo = documentos.documento_tipo
        AND contatos.documento = documentos.documento
    WHERE 1 = 1
      AND contatos.data_primeira_entrega <= {{ corte }}
  )

  , tEntregasNoCorte AS (
    SELECT
      cpf
      , documento_sem_devedor
      , tipo_contato
      , contato
      , MIN(data_primeira_entrega) AS dt_primeira_entrega
      , MAX(data_ultima_entrega) AS dt_ultima_entrega
      , COUNT(DISTINCT provedor) AS qt_provedores
    FROM tLinhasNoCorte
    GROUP BY cpf, documento_sem_devedor, tipo_contato, contato
  )

  , tDocumentosOrdenados AS (
    SELECT
      cpf
      , documento_sem_devedor
      , tipo_contato
      , contato
      , documento
      , prioridade_documento
      , ROW_NUMBER() OVER (
        PARTITION BY cpf, documento_sem_devedor, tipo_contato, contato
        ORDER BY
          prioridade_documento ASC
          , data_ultima_entrega DESC NULLS LAST
          , documento ASC
          , provedor ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS num_documento
    FROM tLinhasNoCorte
  )

  , tMelhorDocumentoNoCorte AS (
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
    FROM tDocumentosOrdenados
    WHERE 1 = 1
      AND num_documento = 1
  )

  , tVersoesNoCorte AS (
    SELECT
      'alfa' AS provedor
      , 'CPF' AS documento_tipo
      , documento
      , {{ nome_comparavel('nome_completo') }} AS nome_chave
      , data_atualizacao
      , LEAST(data_ultima_entrega, {{ corte }}) AS data_entrega
      , _arquivo
      , _linha
    FROM {{ ref('silver_alfa_devedores_historico') }}
    WHERE 1 = 1
      AND documento IS NOT NULL
      AND data_primeira_entrega <= {{ corte }}

    UNION ALL

    SELECT
      'beta' AS provedor
      , documento_tipo
      , documento
      , {{ nome_comparavel('nome_completo') }} AS nome_chave
      , atualizado_em AS data_atualizacao
      , LEAST(data_ultima_entrega, {{ corte }}) AS data_entrega
      , _arquivo
      , _linha
    FROM {{ ref('silver_beta_devedores_historico') }}
    WHERE 1 = 1
      AND documento IS NOT NULL
      AND data_primeira_entrega <= {{ corte }}

    UNION ALL

    SELECT
      'gama' AS provedor
      , 'CPF' AS documento_tipo
      , documento
      , {{ nome_comparavel('nome') }} AS nome_chave
      , dt_ref AS data_atualizacao
      , LEAST(data_ultima_entrega, {{ corte }}) AS data_entrega
      , _arquivo
      , _linha
    FROM {{ ref('silver_gama_devedores_historico') }}
    WHERE 1 = 1
      AND documento IS NOT NULL
      AND data_primeira_entrega <= {{ corte }}
  )

  , tVersoesOrdenadasNoCorte AS (
    SELECT
      provedor
      , documento_tipo
      , documento
      , nome_chave
      , data_atualizacao
      , data_entrega
      , ROW_NUMBER() OVER (
        PARTITION BY provedor, documento_tipo, documento
        ORDER BY
          {{ ordem_versao('data_atualizacao') }}
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS num_versao
      , SUM(1) OVER (
        PARTITION BY provedor, documento_tipo, documento, data_atualizacao, data_entrega, _arquivo
        ORDER BY _linha
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
      ) AS qt_versoes_no_topo
    FROM tVersoesNoCorte
  )

  , tVersoesAtuaisDoDevedor AS (
    SELECT
      documentos.cpf
      , versoes.provedor
      , versoes.nome_chave
      , ROW_NUMBER() OVER (
        PARTITION BY documentos.cpf, versoes.provedor
        ORDER BY
          versoes.data_atualizacao DESC NULLS LAST
          , versoes.data_entrega DESC NULLS LAST
          , CASE WHEN versoes.documento = documentos.cpf THEN 0 ELSE 1 END
          , versoes.documento_tipo ASC
          , versoes.documento ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS num_versao_do_devedor
    FROM tVersoesOrdenadasNoCorte AS versoes
    INNER JOIN {{ ref('devedores_documentos') }} AS documentos
      ON versoes.documento_tipo = documentos.documento_tipo
        AND versoes.documento = documentos.documento
    WHERE 1 = 1
      AND versoes.num_versao = 1
      AND documentos.cpf IS NOT NULL
  )

  , tConflitoDeIdentidadeNoCorte AS (
    SELECT cpf
    FROM tVersoesAtuaisDoDevedor
    WHERE 1 = 1
      AND num_versao_do_devedor = 1
      AND nome_chave IS NOT NULL
    GROUP BY cpf
    HAVING COUNT(DISTINCT SPLIT_PART(nome_chave, ' ', 1)) > 1
      OR COUNT(DISTINCT REGEXP_REPLACE(nome_chave, '^.* ', '')) > 1
  )

  , tConflitoDeVersaoNoCorte AS (
    SELECT DISTINCT documentos.cpf
    FROM tVersoesOrdenadasNoCorte AS versoes
    INNER JOIN {{ ref('devedores_documentos') }} AS documentos
      ON versoes.documento_tipo = documentos.documento_tipo
        AND versoes.documento = documentos.documento
    WHERE 1 = 1
      AND versoes.num_versao = 1
      AND versoes.qt_versoes_no_topo > 1
      AND documentos.cpf IS NOT NULL
  )

  , tParesVisiveis AS (
    SELECT
      pares.sk_contato
      , pares.sk_devedor
      , entregas.cpf
      , entregas.tipo_contato
      , entregas.contato
      , CASE
        WHEN entregas.cpf IS NULL THEN CAST(NULL AS VARCHAR)
        WHEN tConflitoDeIdentidadeNoCorte.cpf IS NOT NULL
          AND tConflitoDeVersaoNoCorte.cpf IS NOT NULL THEN 'identidade_e_versao'
        WHEN tConflitoDeIdentidadeNoCorte.cpf IS NOT NULL THEN 'identidade'
        WHEN tConflitoDeVersaoNoCorte.cpf IS NOT NULL THEN 'versao'
        ELSE 'nenhum'
      END AS tipo_conflito_cadastral
      , melhor.situacao_documento
      , CASE
        WHEN melhor.situacao_documento <> 'cpf_valido' THEN melhor.documento
      END AS documento_original
      , CAST(NULL AS VARCHAR) AS situacao_entrega
      , entregas.qt_provedores
      , entregas.dt_primeira_entrega
      , entregas.dt_ultima_entrega
      , pares._arquivo
      , pares._linha
      , pares._hash_arquivo
    FROM tEntregasNoCorte AS entregas
    INNER JOIN tMelhorDocumentoNoCorte AS melhor
      ON entregas.cpf IS NOT DISTINCT FROM melhor.cpf
        AND entregas.documento_sem_devedor IS NOT DISTINCT FROM melhor.documento_sem_devedor
        AND entregas.tipo_contato = melhor.tipo_contato
        AND entregas.contato = melhor.contato
    INNER JOIN {{ ref('devedores_contatos_pares') }} AS pares
      ON entregas.cpf IS NOT DISTINCT FROM pares.cpf
        AND entregas.documento_sem_devedor IS NOT DISTINCT FROM pares.documento_sem_devedor
        AND entregas.tipo_contato = pares.tipo_contato
        AND entregas.contato = pares.contato
    LEFT JOIN tConflitoDeIdentidadeNoCorte
      ON entregas.cpf = tConflitoDeIdentidadeNoCorte.cpf
    LEFT JOIN tConflitoDeVersaoNoCorte
      ON entregas.cpf = tConflitoDeVersaoNoCorte.cpf
  )
{%- endmacro %}
