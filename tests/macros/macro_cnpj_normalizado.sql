{# Falha para cada caso em que `cnpj_normalizado` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('00000000000191', '00000000000191')
  , ('00.000.000/0001-91', '00000000000191')
  , ('191', '00000000000191')
  , ('4182736500157', '04182736500157')
  , ('000000000001', '000000000001')
  , ('A7K2M9Q4000140', 'A7K2M9Q4000140')
  , ('a7.k2m.9q4/0001-40', 'A7K2M9Q4000140')
  , ('Z0P4LC220001', 'Z0P4LC220001')
  , ('3RT8XB51000136', '3RT8XB51000136')
  , ('', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ cnpj_normalizado('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
