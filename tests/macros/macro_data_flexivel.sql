{# Falha para cada caso em que `data_flexivel` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('2026-09-01', CAST('2026-09-01' AS DATE))
  , ('1900-01-01', CAST('1900-01-01' AS DATE))
  , ('2026-09-01T10:30:00-03:00', CAST('2026-09-01' AS DATE))
  , ('24/07/2002', CAST('2002-07-24' AS DATE))
  , ('29/02/2024', CAST('2024-02-29' AS DATE))
  , ('1788231600000', CAST('2026-09-01' AS DATE))
  , ('1788231599999', CAST('2026-08-31' AS DATE))
  , (' 2026-09-01 ', CAST('2026-09-01' AS DATE))
  , ('30/02/2024', NULL)
  , ('2026-13-45', NULL)
  , ('01-09-2026', NULL)
  , ('ontem', NULL)
  , ('', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ data_flexivel('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
