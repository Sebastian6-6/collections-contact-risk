{#
  Grão: uma linha por documento (tipo de documento + número normalizado). Vale a versão mais
  recente: data de atualização da fonte, depois data de entrega, depois arquivo e linha (S3). A
  padronização acontece antes, em `silver_beta_devedores_padronizados` (S2). Linha sem documento
  (vazio ou só zeros) não é devedor: sai antes do `ROW_NUMBER`, para os NULL não formarem um
  grupo. Telefones, e-mails
  e endereços são listas: estão em `devedores_contatos` e `devedores_enderecos`.
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
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento_tipo, documento
      ORDER BY
        atualizado_em DESC NULLS LAST
        , data_entrega DESC NULLS LAST
        , _arquivo DESC
        , _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM {{ ref('silver_beta_devedores_padronizados') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
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
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
