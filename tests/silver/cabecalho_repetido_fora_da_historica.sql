{#
  A histórica de cada fonte deixa de fora a linha que repete o cabeçalho do próprio arquivo
  (`_linha_original` igual a `arquivos.cabecalho`): ela não é um registro, e na bronze continua
  inteira. Este teste só avisa (`warn`); devolve uma linha por fonte com quantas linhas legíveis
  da bronze ficaram fora por isso. Medido em 2026-11-10: 1 no gama (o `provedor_gama.csv`
  histórico) e 0 no alfa e no beta.
#}
{{ config(severity='warn') }}

WITH tCabecalhos AS (
  SELECT
    'alfa' AS fonte
    , COUNT(*) AS qt_linhas
  FROM {{ source('bronze_alfa', 'devedores') }} AS b
  INNER JOIN {{ source('bronze_alfa', 'arquivos') }} AS a
    ON b._arquivo = a.arquivo
  WHERE 1 = 1
    AND b._motivo_ilegivel IS NULL
    AND b._linha_original = a.cabecalho

  UNION ALL

  SELECT
    'beta' AS fonte
    , COUNT(*) AS qt_linhas
  FROM {{ source('bronze_beta', 'devedores') }} AS b
  INNER JOIN {{ source('bronze_beta', 'arquivos') }} AS a
    ON b._arquivo = a.arquivo
  WHERE 1 = 1
    AND b._motivo_ilegivel IS NULL
    AND b._linha_original = a.cabecalho

  UNION ALL

  SELECT
    'gama' AS fonte
    , COUNT(*) AS qt_linhas
  FROM {{ source('bronze_gama', 'devedores') }} AS b
  INNER JOIN {{ source('bronze_gama', 'arquivos') }} AS a
    ON b._arquivo = a.arquivo
  WHERE 1 = 1
    AND b._motivo_ilegivel IS NULL
    AND b._linha_original = a.cabecalho
)

SELECT
  fonte
  , qt_linhas
FROM tCabecalhos
WHERE 1 = 1
  AND qt_linhas > 0
