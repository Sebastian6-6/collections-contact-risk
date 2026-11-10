{#
  Grão: uma linha por documento normalizado. Vale a versão mais recente da histórica
  (`silver_alfa_devedores_historico`): data de atualização da fonte, depois data de entrega
  (a última da versão), depois arquivo e linha (S3, H5, macro `ordem_versao`). A padronização
  acontece antes, em `silver_alfa_devedores_padronizados` (S2). Linha sem documento (vazio ou só
  zeros) não é devedor: sai antes do `ROW_NUMBER`, para os NULL não formarem um grupo.
  `hash_conteudo` liga a versão atual à histórica.
#}
WITH tVersoes AS (
  SELECT
    documento
    , nome_completo
    , data_nascimento
    , cnpj_empregador
    , cargo
    , salario_informado
    , telefone
    , email
    , endereco
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , cep
    , uf
    , data_atualizacao
    , data_ultima_entrega AS data_entrega
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

, tOrdenadas AS (
  SELECT
    documento
    , nome_completo
    , data_nascimento
    , cnpj_empregador
    , cargo
    , salario_informado
    , telefone
    , email
    , endereco
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , cep
    , uf
    , data_atualizacao
    , data_entrega
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY
        {{ ordem_versao('data_atualizacao') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM tVersoes
)

SELECT
  documento
  , nome_completo
  , data_nascimento
  , cnpj_empregador
  , cargo
  , salario_informado
  , telefone
  , email
  , endereco
  , logradouro
  , numero
  , complemento
  , bairro
  , cidade
  , cep
  , uf
  , data_atualizacao
  , data_entrega
  , hash_conteudo
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tOrdenadas
WHERE 1 = 1
  AND num_versao = 1
