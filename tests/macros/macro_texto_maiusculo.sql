{# Falha para cada caso em que `texto_maiusculo` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('rua a', 'RUA A')
  , ('Rua A', 'RUA A')
  , ('RUA A', 'RUA A')
  , ('ação', 'AÇÃO')
  , ('Açaí', 'AÇAÍ')
  , ('apto 3b', 'APTO 3B')
  , ('', '')
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ texto_maiusculo('entrada') }} AS obtido
  FROM tCasos
)

SELECT
  entrada
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
