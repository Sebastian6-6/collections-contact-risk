{# Falha para cada caso em que `nome_comparavel` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('JOSÉ DA CONCEIÇÃO', 'JOSE DA CONCEICAO')
  , ('JOSE DA CONCEICAO', 'JOSE DA CONCEICAO')
  , ('ÁÀÂÃÄ ÉÈÊË ÍÌÎÏ ÓÒÔÕÖ ÚÙÛÜ ÇÑ', 'AAAAA EEEE IIII OOOOO UUUU CN')
  , ('MARIA D''ÁVILA-SOUZA', 'MARIA D''AVILA-SOUZA')
  , ('', '')
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ nome_comparavel('entrada') }} AS obtido
  FROM tCasos
)

SELECT
  entrada
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
