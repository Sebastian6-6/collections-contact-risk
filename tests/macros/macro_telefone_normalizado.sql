{# Falha para cada caso em que `telefone_normalizado` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('(11) 90040-5285', '11900405285')
  , ('+5511900470747', '11900470747')
  , ('11900139013', '11900139013')
  , ('+55 11 90035-3520', '11900353520')
  , ('(11)900331479', '11900331479')
  , ('(11) 0468-7901', '1104687901')
  , ('+551104687901', '1104687901')
  , ('55912345678', '55912345678')
  , ('0000000000', '0000000000')
  , ('', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ telefone_normalizado('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
