{# Falha para cada caso em que `uf_normalizada` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('SP', 'SP')
  , ('sp', 'SP')
  , (' rj ', 'RJ')
  , ('Df', 'DF')
  , ('TO', 'TO')
  , ('AC', 'AC')
  , ('XX', NULL)
  , ('S', NULL)
  , ('SAO PAULO', NULL)
  , ('', NULL)
  , ('  ', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ uf_normalizada('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
