{#
  Regra confirmada (2026-11-10): sem vírgula, o ponto de `valor_monetario` é o decimal (`1.234`
  vale 1,234). Um texto como `1.234` ou `R$ 4.482` também pode ser milhar (1234 ou 4482), e a
  regra não tem como saber qual dos dois o provedor quis. Hoje nenhum valor cai nesse caso. O
  teste avisa (`warn`) em vez de a regra adivinhar ou apagar o valor em silêncio. Cada linha
  devolvida é uma linha legível da bronze com renda em texto, sem vírgula e com ponto seguido de
  exatamente 3 dígitos no fim: `salario_informado` no alfa e `renda_mensal` no beta, quando vem
  como texto no JSON (número JSON como 1.234 é decimal sem ambiguidade).
#}
{{ config(severity='warn') }}

WITH tBetaBase AS (
  SELECT
    _arquivo
    , _linha
    , {{ json_ou_nulo('registro') }} AS registro_json
  FROM {{ source('bronze_beta', 'devedores') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tValores AS (
  SELECT
    'alfa' AS fonte
    , 'salario_informado' AS coluna
    , _arquivo
    , _linha
    , salario_informado AS valor
  FROM {{ source('bronze_alfa', 'devedores') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL

  UNION ALL

  SELECT
    'beta' AS fonte
    , 'renda_mensal' AS coluna
    , _arquivo
    , _linha
    , registro_json ->> 'renda_mensal' AS valor
  FROM tBetaBase
  WHERE 1 = 1
    AND registro_json IS NOT NULL
    AND CAST(registro_json -> 'renda_mensal' AS VARCHAR) LIKE '"%'
)

SELECT
  fonte
  , coluna
  , _arquivo
  , _linha
  , valor
FROM tValores
WHERE 1 = 1
  AND TRIM(valor) ~ '^[^,]*[0-9][.][0-9]{3}$'
