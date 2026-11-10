{#
  Grão: uma linha por estabelecimento (`cnpj`, 14 caracteres). Se a origem repetir o CNPJ (hoje não
  repete), vale a linha mais recente do arquivo: maior `_arquivo`, depois maior `_linha`. A
  padronização acontece antes, em `silver_receita_estabelecimentos_padronizados`. A lista de CNAEs
  secundários não está aqui: está em `estabelecimentos_cnaes_secundarios`.
#}
WITH tVersoes AS (
  SELECT
    cnpj
    , cnpj_basico
    , cnpj_ordem
    , cnpj_dv
    , identificador_matriz_filial
    , nome_fantasia
    , situacao_cadastral
    , data_situacao_cadastral
    , motivo_situacao_cadastral
    , nome_da_cidade_no_exterior
    , pais
    , data_de_inicio_atividade
    , cnae_fiscal_principal
    , tipo_de_logradouro
    , logradouro
    , numero
    , complemento
    , bairro
    , cep
    , uf
    , municipio
    , ddd_1
    , telefone_1
    , ddd_2
    , telefone_2
    , ddd_do_fax
    , fax
    , correio_eletronico
    , situacao_especial
    , data_da_situacao_especial
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY cnpj
      ORDER BY _arquivo DESC, _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM {{ ref('silver_receita_estabelecimentos_padronizados') }}
  WHERE 1 = 1
    AND cnpj IS NOT NULL
)

SELECT
  cnpj
  , cnpj_basico
  , cnpj_ordem
  , cnpj_dv
  , identificador_matriz_filial
  , nome_fantasia
  , situacao_cadastral
  , data_situacao_cadastral
  , motivo_situacao_cadastral
  , nome_da_cidade_no_exterior
  , pais
  , data_de_inicio_atividade
  , cnae_fiscal_principal
  , tipo_de_logradouro
  , logradouro
  , numero
  , complemento
  , bairro
  , cep
  , uf
  , municipio
  , ddd_1
  , telefone_1
  , ddd_2
  , telefone_2
  , ddd_do_fax
  , fax
  , correio_eletronico
  , situacao_especial
  , data_da_situacao_especial
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
