{# Falha para cada caso em que `data_compacta` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('20240606', CAST('2024-06-06' AS DATE))
  , (' 20260731 ', CAST('2026-07-31' AS DATE))
  , ('00000000', CAST(NULL AS DATE))
  , ('20260230', CAST(NULL AS DATE))
  , ('2024-06-06', CAST(NULL AS DATE))
  , ('202406', CAST(NULL AS DATE))
  , ('', CAST(NULL AS DATE))
  , (NULL, CAST(NULL AS DATE))
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ data_compacta('entrada') }} AS obtido
  FROM tCasos
)

SELECT
  entrada
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
