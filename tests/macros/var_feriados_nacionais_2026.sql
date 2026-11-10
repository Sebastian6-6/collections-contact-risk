{#
  Falha se a `var` dos feriados nacionais deixar de ser os sete dias da Lei 662/1949, art. 1º
  (redação da Lei 10.607/2002), todos em 2026 e sem repetição.
#}
{%- set lista = var('feriados_nacionais_2026') | join("', '") -%}
WITH tFeriados AS (
  SELECT CAST(UNNEST(ARRAY['{{ lista }}']) AS DATE) AS dia
)

, tProblemas AS (
  SELECT 'quantidade diferente de 7' AS problema
  FROM tFeriados
  HAVING COUNT(*) <> 7
  UNION ALL
  SELECT 'data repetida'
  FROM tFeriados
  HAVING COUNT(DISTINCT dia) <> COUNT(*)
  UNION ALL
  SELECT 'data fora de 2026'
  FROM tFeriados
  WHERE 1 = 1
    AND EXTRACT(YEAR FROM dia) <> 2026
)

SELECT problema
FROM tProblemas
