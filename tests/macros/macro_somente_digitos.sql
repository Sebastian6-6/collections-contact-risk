{# Falha para cada caso em que `somente_digitos` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('123.456.789-09', '12345678909')
  , ('(11) 90040-5285', '11900405285')
  , ('000.000.000-00', '00000000000')
  , ('  98 7 ', '987')
  , ('', NULL)
  , ('sem numero', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ somente_digitos('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
