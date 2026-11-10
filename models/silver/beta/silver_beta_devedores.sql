{#
  Grão: uma linha por documento (tipo de documento + número normalizado). Vale a versão mais
  recente da histórica (`silver_beta_devedores_historico`): data de atualização da fonte, depois
  data de entrega (a última da versão), depois arquivo e linha (S3, H5, macro `ordem_versao`). A
  padronização acontece antes, em `silver_beta_devedores_padronizados` (S2). Linha sem documento
  (vazio ou só zeros) não é devedor: sai antes do `ROW_NUMBER`, para os NULL não formarem um
  grupo. Telefones, e-mails e endereços são listas: estão em `devedores_contatos` e
  `devedores_enderecos`. `hash_conteudo` liga a versão atual à histórica.
#}
WITH tVersoes AS (
  SELECT
    documento_tipo
    , documento
    , nome_completo
    , data_nascimento
    , vinculo_empresa_cnpj
    , vinculo_empresa_desde
    , renda_mensal
    , atualizado_em
    , data_ultima_entrega AS data_entrega
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_beta_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

, tOrdenadas AS (
  SELECT
    documento_tipo
    , documento
    , nome_completo
    , data_nascimento
    , vinculo_empresa_cnpj
    , vinculo_empresa_desde
    , renda_mensal
    , atualizado_em
    , data_entrega
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento_tipo, documento
      ORDER BY
        {{ ordem_versao('atualizado_em') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM tVersoes
)

SELECT
  documento_tipo
  , documento
  , nome_completo
  , data_nascimento
  , vinculo_empresa_cnpj
  , vinculo_empresa_desde
  , renda_mensal
  , atualizado_em
  , data_entrega
  , hash_conteudo
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tOrdenadas
WHERE 1 = 1
  AND num_versao = 1
