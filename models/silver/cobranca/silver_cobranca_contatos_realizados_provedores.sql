{#
  Grão: uma linha por (`contato_id`, provedor). O `provedor_origem` da bronze é um texto como
  `alfa|beta|gama`; aqui cada provedor vira uma linha, só do contato que está em
  `contatos_realizados` (a versão escolhida). Provedor repetido no mesmo texto conta uma vez, e
  elemento vazio não gera linha. `STRING_TO_ARRAY` e `UNNEST` existem com o mesmo comportamento
  no DuckDB e no PostgreSQL. `_arquivo`, `_linha` e `_hash_arquivo` são da linha do contato
  realizado que originou o par.
#}
WITH tAbertos AS (
  SELECT
    c.contato_id
    , c._arquivo
    , c._linha
    , c._hash_arquivo
    , NULLIF(TRIM(p.provedor), '') AS provedor
  FROM {{ ref('silver_cobranca_contatos_realizados') }} AS c
  INNER JOIN {{ ref('silver_cobranca_contatos_realizados_padronizados') }} AS e
    ON c._arquivo = e._arquivo
      AND c._linha = e._linha
  CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(e.provedor_origem, '|')) AS p (provedor)
)

, tOrdenados AS (
  SELECT
    contato_id
    , provedor
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY contato_id, provedor
      ORDER BY contato_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_repeticao
  FROM tAbertos
  WHERE 1 = 1
    AND provedor IS NOT NULL
)

SELECT
  contato_id
  , provedor
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tOrdenados
WHERE 1 = 1
  AND num_repeticao = 1
