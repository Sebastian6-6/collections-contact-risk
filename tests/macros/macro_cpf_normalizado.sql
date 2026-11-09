{# Falha para cada caso em que `cpf_normalizado` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('12345678909', '12345678909')
  , ('123.456.789-09', '12345678909')
  , ('1006543201', '01006543201')
  , ('121653951', '00121653951')
  , ('15850374', '00015850374')
  , ('0', '00000000000')
  , ('123456789012', '123456789012')
  , ('', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ cpf_normalizado('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
