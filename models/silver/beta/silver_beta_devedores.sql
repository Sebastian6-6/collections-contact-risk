{#
  Grão: uma linha por documento (tipo de documento + número normalizado). Vale a versão mais
  recente: data de atualização da fonte, depois data de entrega, depois linha (S3). A
  padronização acontece antes, em `silver_beta_devedores_padronizados` (S2). Telefones, e-mails
  e endereços são listas: estão em `devedores_contatos` e `devedores_enderecos`.
#}
WITH tVersoes AS (
  SELECT
    tipo_documento
    , documento
    , nome_completo
    , data_nascimento
    , cnpj_empregador
    , vinculo_desde
    , renda_mensal
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY tipo_documento, documento
      ORDER BY data_atualizacao DESC NULLS LAST, data_entrega DESC NULLS LAST, _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM {{ ref('silver_beta_devedores_padronizados') }}
)

SELECT
  tipo_documento
  , documento
  , nome_completo
  , data_nascimento
  , cnpj_empregador
  , vinculo_desde
  , renda_mensal
  , data_atualizacao
  , data_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
