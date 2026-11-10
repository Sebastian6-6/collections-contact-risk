{#
  Regra confirmada (2026-11-10): um CPF com mais de 11 dígitos fica como veio na silver, sem corte
  e sem descarte; hoje nenhuma versão cai nesse caso. O teste avisa (`warn`) em vez de a regra
  adivinhar qual parte do número vale ou apagar o valor em silêncio, para uma entrega futura que
  traga um CPF longo ser vista. Cada linha devolvida é uma fonte com o total de versões de
  `devedores_historico` cujo documento é CPF e tem mais de 11 caracteres. No alfa e no gama o
  documento é sempre CPF; no beta só vale com `documento_tipo = 'CPF'` (o RG tem outro formato).
#}
{{ config(severity='warn') }}

WITH tDocumentos AS (
  SELECT
    'alfa' AS fonte
    , documento
  FROM {{ ref('silver_alfa_devedores_historico') }}

  UNION ALL

  SELECT
    'beta' AS fonte
    , documento
  FROM {{ ref('silver_beta_devedores_historico') }}
  WHERE 1 = 1
    AND documento_tipo = 'CPF'

  UNION ALL

  SELECT
    'gama' AS fonte
    , documento
  FROM {{ ref('silver_gama_devedores_historico') }}
)

SELECT
  fonte
  , COUNT(*) AS qt_versoes
FROM tDocumentos
WHERE 1 = 1
  AND LENGTH(documento) > 11
GROUP BY fonte
