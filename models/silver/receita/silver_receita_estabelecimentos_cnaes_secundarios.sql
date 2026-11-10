{#
  Grão: uma linha por (`cnpj`, `cnae_fiscal_secundaria`). A origem guarda os CNAEs secundários num
  só campo, separados por vírgula (`4693100,4711302`); aqui cada código vira uma linha, só do
  estabelecimento que está em `estabelecimentos` (a versão escolhida). Código repetido no mesmo
  campo conta uma vez, e elemento vazio não gera linha. `STRING_TO_ARRAY` e `UNNEST` existem com o
  mesmo comportamento no DuckDB e no PostgreSQL. `_arquivo`, `_linha` e `_hash_arquivo` são da
  linha do estabelecimento que originou o par.
#}
WITH tAbertos AS (
  SELECT
    e.cnpj
    , e._arquivo
    , e._linha
    , e._hash_arquivo
    , NULLIF(TRIM(c.cnae), '') AS cnae_fiscal_secundaria
  FROM {{ ref('silver_receita_estabelecimentos') }} AS e
  INNER JOIN {{ ref('silver_receita_estabelecimentos_padronizados') }} AS p
    ON e._arquivo = p._arquivo
      AND e._linha = p._linha
  CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(p.cnae_fiscal_secundaria, ',')) AS c (cnae)
)

, tOrdenados AS (
  SELECT
    cnpj
    , cnae_fiscal_secundaria
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY cnpj, cnae_fiscal_secundaria
      ORDER BY cnpj
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_repeticao
  FROM tAbertos
  WHERE 1 = 1
    AND cnae_fiscal_secundaria IS NOT NULL
)

SELECT
  cnpj
  , cnae_fiscal_secundaria
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tOrdenados
WHERE 1 = 1
  AND num_repeticao = 1
