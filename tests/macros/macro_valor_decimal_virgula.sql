{# Falha para cada caso em que `valor_decimal_virgula` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('14202162483,70', CAST(14202162483.70 AS NUMERIC(18, 2)))
  , ('205431960490,52', CAST(205431960490.52 AS NUMERIC(18, 2)))
  , ('35000,00', CAST(35000.00 AS NUMERIC(18, 2)))
  , (' 12,5 ', CAST(12.50 AS NUMERIC(18, 2)))
  , ('0,00', CAST(0.00 AS NUMERIC(18, 2)))
  , ('1500', CAST(1500.00 AS NUMERIC(18, 2)))
  , ('1.234,56', CAST(NULL AS NUMERIC(18, 2)))
  , ('R$ 10,00', CAST(NULL AS NUMERIC(18, 2)))
  , ('', CAST(NULL AS NUMERIC(18, 2)))
  , (NULL, CAST(NULL AS NUMERIC(18, 2)))
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ valor_decimal_virgula('entrada') }} AS obtido
  FROM tCasos
)

SELECT
  entrada
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
