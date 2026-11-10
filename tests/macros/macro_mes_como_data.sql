{# Falha para cada caso em que `mes_como_data` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('2020-05', CAST('2020-05-01' AS DATE))
  , (' 2026-09 ', CAST('2026-09-01' AS DATE))
  , ('2015-12', CAST('2015-12-01' AS DATE))
  , ('2020-13', CAST(NULL AS DATE))
  , ('2020-00', CAST(NULL AS DATE))
  , ('2020-5', CAST(NULL AS DATE))
  , ('2020-05-15', CAST(NULL AS DATE))
  , ('maio de 2020', CAST(NULL AS DATE))
  , ('', CAST(NULL AS DATE))
  , (NULL, CAST(NULL AS DATE))
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ mes_como_data('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
