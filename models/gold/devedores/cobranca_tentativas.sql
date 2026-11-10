{#
  Etapa comum da gold de devedores: as tentativas da Cobrança ligadas ao devedor e ao par.
  Grão: uma tentativa (`contato_id`), as mesmas linhas de `silver_cobranca.contatos_realizados`.
  `cpf` é o CPF do devedor a que o `cpf_alvo` pertence (`devedores_documentos`, só CPF); `NULL`
  quando o alvo não é documento recebido. `tipo_contato` é `email` para o canal e-mail e
  `telefone` para os demais; `contato` é o destino normalizado. `tipo_desfecho` vem da macro
  `tipo_desfecho` (G2b).
  Ligação ao par (G2c'): primeiro o par (`cpf`, `tipo_contato`, `contato`); sem ele, o contato
  sem devedor de mesmo valor (o de menor `sk_contato`); sem nenhum dos dois, `sk_contato` e
  `sk_devedor` ficam `NULL`. `sk_devedor` é o do par ligado. `ligacao` diz qual dos três casos
  valeu: `par`, `contato_sem_devedor` ou `sem_ligacao`.
  É efêmero: existe para a régua (`dim_contato`) e para `ft_tentativa_contato` partirem da mesma
  ligação.
#}
{{ config(materialized='ephemeral') }}

WITH tTentativas AS (
  SELECT
    contatos_realizados.contato_id
    , contatos_realizados.canal
    , contatos_realizados.destino AS contato
    , contatos_realizados.resultado
    , {{ tipo_desfecho('contatos_realizados.resultado') }} AS tipo_desfecho
    , contatos_realizados.data_hora
    , CAST(contatos_realizados.data_hora AS DATE) AS dt_tentativa
    , CASE WHEN contatos_realizados.canal = 'email' THEN 'email' ELSE 'telefone' END
      AS tipo_contato
    , devedores_documentos.cpf
    , contatos_realizados._arquivo
    , contatos_realizados._linha
    , contatos_realizados._hash_arquivo
  FROM {{ ref('silver_cobranca_contatos_realizados') }} AS contatos_realizados
  LEFT JOIN {{ ref('devedores_documentos') }} AS devedores_documentos
    ON devedores_documentos.documento_tipo = 'CPF'
      AND contatos_realizados.cpf_alvo = devedores_documentos.documento
)

, tContatosSemDevedor AS (
  SELECT
    tipo_contato
    , contato
    , MIN(sk_contato) AS sk_contato
  FROM {{ ref('devedores_contatos_pares') }}
  WHERE 1 = 1
    AND cpf IS NULL
  GROUP BY tipo_contato, contato
)

SELECT
  tTentativas.contato_id
  , tTentativas.canal
  , tTentativas.tipo_contato
  , tTentativas.contato
  , tTentativas.resultado
  , tTentativas.tipo_desfecho
  , tTentativas.data_hora
  , tTentativas.dt_tentativa
  , tTentativas.cpf
  , devedores_contatos_pares.sk_devedor
  , tTentativas._arquivo
  , tTentativas._linha
  , tTentativas._hash_arquivo
  , COALESCE(devedores_contatos_pares.sk_contato, tContatosSemDevedor.sk_contato) AS sk_contato
  , CASE
    WHEN devedores_contatos_pares.sk_contato IS NOT NULL THEN 'par'
    WHEN tContatosSemDevedor.sk_contato IS NOT NULL THEN 'contato_sem_devedor'
    ELSE 'sem_ligacao'
  END AS ligacao
FROM tTentativas
LEFT JOIN {{ ref('devedores_contatos_pares') }} AS devedores_contatos_pares
  ON tTentativas.cpf = devedores_contatos_pares.cpf
    AND tTentativas.tipo_contato = devedores_contatos_pares.tipo_contato
    AND tTentativas.contato = devedores_contatos_pares.contato
LEFT JOIN tContatosSemDevedor
  ON tTentativas.tipo_contato = tContatosSemDevedor.tipo_contato
    AND tTentativas.contato = tContatosSemDevedor.contato
