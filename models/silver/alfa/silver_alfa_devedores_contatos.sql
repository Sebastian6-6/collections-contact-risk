{#
  Grão: uma linha por (documento, tipo, contato normalizado), com a primeira e a última data de
  entrega em que o par apareceu. Considera todas as linhas da bronze com documento, não só a
  versão atual do devedor (S4): um número que saiu da versão mais recente continua registrado.
  Só existe linha para contato que veio preenchido.
#}
WITH tContatos AS (
  SELECT
    documento
    , 'telefone' AS tipo
    , telefone AS contato
    , data_entrega
  FROM {{ ref('silver_alfa_devedores_padronizados') }}
  WHERE 1 = 1
    AND telefone IS NOT NULL

  UNION ALL

  SELECT
    documento
    , 'email' AS tipo
    , email AS contato
    , data_entrega
  FROM {{ ref('silver_alfa_devedores_padronizados') }}
  WHERE 1 = 1
    AND email IS NOT NULL
)

SELECT
  documento
  , tipo
  , contato
  , MIN(data_entrega) AS data_primeira_entrega
  , MAX(data_entrega) AS data_ultima_entrega
FROM tContatos
GROUP BY
  documento
  , tipo
  , contato
