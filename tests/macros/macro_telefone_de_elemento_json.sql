{# Falha para cada caso em que `telefone_de_elemento_json` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('"+55 11 90040-5285"', '11900405285')
  , ('"(21)960476196"', '21960476196')
  , ('{"ddd": "21", "numero": "978986768", "tipo": "celular", "principal": true}', '21978986768')
  , ('{"ddd": "11", "numero": "37981346", "tipo": "fixo", "principal": false}', '1137981346')
  , ('{"ddd": "11", "numero": null}', NULL)
  , ('{"ddd": null, "numero": "978986768"}', NULL)
  , ('""', NULL)
  , ('null', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ telefone_de_elemento_json(json_ou_nulo('entrada')) }} AS obtido
  FROM tCasos
)

SELECT
  entrada
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
