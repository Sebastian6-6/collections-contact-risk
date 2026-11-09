{#
  Grão: uma linha por documento normalizado. Vale a versão mais recente: data de atualização da
  fonte (`dt_ref`), depois data de entrega, depois linha (S3). A padronização acontece antes, em
  `silver_gama_devedores_padronizados` (S2). Os contatos são uma lista: estão em
  `devedores_contatos`.
#}
WITH tVersoes AS (
  SELECT
    documento
    , nome
    , data_nascimento
    , cnpj_empregador
    , estado_civil
    , qtd_dependentes
    , score_externo
    , escolaridade
    , possui_imovel
    , fonte_score
    , endereco
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , uf
    , cep
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY data_atualizacao DESC NULLS LAST, data_entrega DESC NULLS LAST, _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM {{ ref('silver_gama_devedores_padronizados') }}
)

SELECT
  documento
  , nome
  , data_nascimento
  , cnpj_empregador
  , estado_civil
  , qtd_dependentes
  , score_externo
  , escolaridade
  , possui_imovel
  , fonte_score
  , endereco
  , logradouro
  , numero
  , complemento
  , bairro
  , cidade
  , uf
  , cep
  , data_atualizacao
  , data_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
