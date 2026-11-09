{# Falha para cada caso em que `timestamp_ou_nulo` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('2026-09-01 06:19:48', CAST('2026-09-01 06:19:48' AS TIMESTAMP))
  , (' 2026-09-01 23:59:59 ', CAST('2026-09-01 23:59:59' AS TIMESTAMP))
  , ('2026-02-30 10:00:00', CAST(NULL AS TIMESTAMP))
  , ('ontem', CAST(NULL AS TIMESTAMP))
  , ('', CAST(NULL AS TIMESTAMP))
  , (CAST(NULL AS VARCHAR), CAST(NULL AS TIMESTAMP))
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ timestamp_ou_nulo('entrada') }} AS obtido
  FROM tCasos
)

SELECT
  entrada
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
