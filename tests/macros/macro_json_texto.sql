{# Falha para cada caso em que `json_texto` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('"11903840744"', '11903840744')
  , ('"+55 11 90040-5285"', '+55 11 90040-5285')
  , ('4090.2', '4090.2')
  , ('true', 'true')
  , ('null', NULL)
  , ('{"ddd": "21", "numero": "978986768"}', NULL)
  , ('["a", "b"]', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ json_texto(json_ou_nulo('entrada')) }} AS obtido
  FROM tCasos
)

SELECT
  entrada
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
