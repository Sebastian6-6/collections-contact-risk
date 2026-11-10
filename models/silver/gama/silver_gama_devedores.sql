{#
  Grão: uma linha por documento normalizado. Vale a versão mais recente: data de atualização da
  fonte (`dt_ref`), depois data de entrega, depois arquivo e linha (S3). A padronização acontece antes, em
  `silver_gama_devedores_padronizados` (S2). Linha sem documento (vazio ou só zeros)
  não é devedor: sai antes do `ROW_NUMBER`, para os NULL não formarem um grupo. Os contatos são uma lista: estão em
  `devedores_contatos`.
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
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY
        dt_ref DESC NULLS LAST
        , data_entrega DESC NULLS LAST
        , _arquivo DESC
        , _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM {{ ref('silver_gama_devedores_padronizados') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
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
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
