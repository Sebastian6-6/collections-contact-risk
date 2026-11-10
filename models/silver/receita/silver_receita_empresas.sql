{#
  Grão: uma linha por empresa (`cnpj_basico`, os 8 primeiros caracteres do CNPJ). Se a origem repetir
  a base (hoje não repete), vale a linha mais recente do arquivo: maior `_arquivo`, depois maior
  `_linha`. Textos sem espaços nas pontas e vazio como NULL; o capital social vira NUMERIC com a
  vírgula decimal da Receita. Códigos (natureza, qualificação, porte) ficam como vieram, para
  juntar com os domínios.
#}
WITH tPadronizados AS (
  SELECT
    NULLIF(TRIM(cnpj_basico), '') AS cnpj_basico
    , NULLIF(TRIM(razao_social_nome_empresarial), '') AS razao_social_nome_empresarial
    , NULLIF(TRIM(natureza_juridica), '') AS natureza_juridica
    , NULLIF(TRIM(qualificacao_do_responsavel), '') AS qualificacao_do_responsavel
    , {{ valor_decimal_virgula('capital_social_da_empresa') }} AS capital_social_da_empresa
    , NULLIF(TRIM(porte_da_empresa), '') AS porte_da_empresa
    , NULLIF(TRIM(ente_federativo_responsavel), '') AS ente_federativo_responsavel
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ source('bronze_receita', 'empresas') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tVersoes AS (
  SELECT
    cnpj_basico
    , razao_social_nome_empresarial
    , natureza_juridica
    , qualificacao_do_responsavel
    , capital_social_da_empresa
    , porte_da_empresa
    , ente_federativo_responsavel
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY cnpj_basico
      ORDER BY _arquivo DESC, _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM tPadronizados
  WHERE 1 = 1
    AND cnpj_basico IS NOT NULL
)

SELECT
  cnpj_basico
  , razao_social_nome_empresarial
  , natureza_juridica
  , qualificacao_do_responsavel
  , capital_social_da_empresa
  , porte_da_empresa
  , ente_federativo_responsavel
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
