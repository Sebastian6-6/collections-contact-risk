{# Falha para cada caso em que `valor_monetario` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('8.556,50', CAST(8556.50 AS NUMERIC(14, 2)))
  , ('R$ 1.400,00', CAST(1400.00 AS NUMERIC(14, 2)))
  , ('R$ 10.009,54', CAST(10009.54 AS NUMERIC(14, 2)))
  , ('1298,35', CAST(1298.35 AS NUMERIC(14, 2)))
  , ('1400.00', CAST(1400.00 AS NUMERIC(14, 2)))
  , ('10003.32', CAST(10003.32 AS NUMERIC(14, 2)))
  , ('R$ 9241,83', CAST(9241.83 AS NUMERIC(14, 2)))
  , ('9241.83', CAST(9241.83 AS NUMERIC(14, 2)))
  , ('0,00', CAST(0.00 AS NUMERIC(14, 2)))
  , ('-15,5', CAST(-15.50 AS NUMERIC(14, 2)))
  , ('', NULL)
  , ('R$', NULL)
  , ('1,2,3', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ valor_monetario('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
