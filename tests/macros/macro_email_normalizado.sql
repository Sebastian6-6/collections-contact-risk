{# Falha para cada caso em que `email_normalizado` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('ADRIANO.ALMEIDA625@OUTLOOK.COM', 'adriano.almeida625@outlook.com')
  , ('Adriano.monteiro324@hotmail.com', 'adriano.monteiro324@hotmail.com')
  , ('  ana@uol.com.br ', 'ana@uol.com.br')
  , ('   ', NULL)
  , ('', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ email_normalizado('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
