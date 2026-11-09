{# Falha para cada caso em que `data_do_nome_do_arquivo` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('contact_data/entregas_diarias/alfa/provedor_alfa_2026-09-01.csv', CAST('2026-09-01' AS DATE))
  , (
    'contact_data/entregas_diarias/gama/provedor_gama_2026-09-15_reenvio.csv'
    , CAST('2026-09-15' AS DATE)
  )
  , ('provedor_beta_2026-09-29.jsonl', CAST('2026-09-29' AS DATE))
  , ('contact_data/2026-09-01/provedor_alfa.csv', NULL)
  , ('contact_data/provedor_alfa.csv', NULL)
  , ('contact_data/contatos_realizados.csv', NULL)
  , ('provedor_alfa_2026-02-30.csv', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ data_do_nome_do_arquivo('entrada') }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
