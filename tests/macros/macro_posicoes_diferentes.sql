{# Falha para cada caso em que `posicoes_diferentes` devolve algo diferente do esperado. #}
WITH tCasos (texto_a, texto_b, esperado) AS (
  VALUES
  ('52998224725', '52998224725', 0)
  , ('52998224725', '52998224726', 1)
  , ('52998224725', '12998224726', 2)
  , ('11111111111', '22222222222', 11)
  , ('52998224725', NULL, NULL)
)

, tResultado AS (
  SELECT
    texto_a
    , texto_b
    , esperado
    , {{ posicoes_diferentes('texto_a', 'texto_b', 11) }} AS obtido
  FROM tCasos
)

SELECT
  texto_a
  , texto_b
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
