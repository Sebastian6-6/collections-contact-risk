{#
  Grão: um CNPJ recebido de empregador. Sai da histórica das três fontes, que guarda todas as
  versões, para que o empregador de uma versão antiga também exista na dimensão. O CNPJ entra como
  a silver o padronizou (14 caracteres), inclusive o que não tem dígito verificador válido: é o
  que o provedor mandou. Versões sem CNPJ não geram linha. A rastreabilidade é da aparição mais
  recente do CNPJ (maior data de entrega, depois arquivo e linha). Etapa efêmera de `dim_empregador`,
  separada dela para que a junção com a Receita tenha teste unitário.
#}
WITH tCnpjs AS (
  SELECT
    'alfa' AS provedor
    , cnpj_empregador AS cnpj
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND cnpj_empregador IS NOT NULL

  UNION ALL

  SELECT
    'beta' AS provedor
    , vinculo_empresa_cnpj AS cnpj
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_beta_devedores_historico') }}
  WHERE 1 = 1
    AND vinculo_empresa_cnpj IS NOT NULL

  UNION ALL

  SELECT
    'gama' AS provedor
    , cnpj_empregador_raw AS cnpj
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_gama_devedores_historico') }}
  WHERE 1 = 1
    AND cnpj_empregador_raw IS NOT NULL
)

, tOrdenados AS (
  SELECT
    cnpj
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY cnpj
      ORDER BY
        data_ultima_entrega DESC NULLS LAST
        , _arquivo COLLATE "C" DESC
        , _linha DESC
        , provedor ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tCnpjs
)

SELECT
  cnpj
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tOrdenados
WHERE 1 = 1
  AND num_aparicao = 1
