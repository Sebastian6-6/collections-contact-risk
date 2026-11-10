{# Falha para cada caso em que `cnpj_valido` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('00000000000191', TRUE)
  , ('12ABC34501DE35', TRUE)
  , ('33000167000101', TRUE)
  , ('04182736500157', TRUE)
  , ('00000000000192', FALSE)
  , ('12ABC34501DE36', FALSE)
  , ('12ABC34501DEAB', FALSE)
  , ('0000000000019', FALSE)
  , ('000000000001911', FALSE)
  , ('12abc34501de35', FALSE)
  , ('', FALSE)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ cnpj_valido('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
