{# Falha para cada caso em que `cpf_valido` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('52998224725', TRUE)
  , ('11144477735', TRUE)
  , ('52998224724', FALSE)
  , ('52998224715', FALSE)
  , ('11111111111', FALSE)
  , ('00000000000', FALSE)
  , ('5299822472', FALSE)
  , ('5299822472A', FALSE)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ cpf_valido('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
