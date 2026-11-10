{#
  Grão: uma linha por documento normalizado. Vale a versão mais recente da histórica
  (`silver_gama_devedores_historico`): data de atualização da fonte (`dt_ref`), depois data de
  entrega (a última da versão), depois arquivo e linha (S3, H5, macro `ordem_versao`). A
  padronização acontece antes, em `silver_gama_devedores_padronizados` (S2). Linha sem documento
  (vazio ou só zeros) não é devedor: sai antes do `ROW_NUMBER`, para os NULL não formarem um
  grupo. Os contatos são uma lista: estão em `devedores_contatos`. `hash_conteudo` liga a versão
  atual à histórica.
#}
WITH tVersoes AS (
  SELECT
    documento
    , nome
    , data_nascimento
    , cnpj_empregador_raw
    , atributos_extra_estado_civil
    , atributos_extra_qtd_dependentes
    , atributos_extra_score_externo
    , atributos_extra_escolaridade
    , atributos_extra_possui_imovel
    , atributos_extra_fonte_score
    , endereco
    , logradouro
    , numero
    , endereco_json_complemento
    , bairro
    , cidade
    , uf
    , cep
    , dt_ref
    , data_ultima_entrega AS data_entrega
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_gama_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

, tOrdenadas AS (
  SELECT
    documento
    , nome
    , data_nascimento
    , cnpj_empregador_raw
    , atributos_extra_estado_civil
    , atributos_extra_qtd_dependentes
    , atributos_extra_score_externo
    , atributos_extra_escolaridade
    , atributos_extra_possui_imovel
    , atributos_extra_fonte_score
    , endereco
    , logradouro
    , numero
    , endereco_json_complemento
    , bairro
    , cidade
    , uf
    , cep
    , dt_ref
    , data_entrega
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY
        {{ ordem_versao('dt_ref') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM tVersoes
)

SELECT
  documento
  , nome
  , data_nascimento
  , cnpj_empregador_raw
  , atributos_extra_estado_civil
  , atributos_extra_qtd_dependentes
  , atributos_extra_score_externo
  , atributos_extra_escolaridade
  , atributos_extra_possui_imovel
  , atributos_extra_fonte_score
  , endereco
  , logradouro
  , numero
  , endereco_json_complemento
  , bairro
  , cidade
  , uf
  , cep
  , dt_ref
  , data_entrega
  , hash_conteudo
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tOrdenadas
WHERE 1 = 1
  AND num_versao = 1
