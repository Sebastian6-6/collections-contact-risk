{#
  Grão: uma linha por sócio de cada empresa. A origem não traz identificador do sócio e o CPF vem
  mascarado, então a chave é a combinação de `cnpj_basico`, `identificador_de_socio`, o nome, o
  `cnpj_cpf_do_socio` e a data de entrada. Linha repetida nessa combinação conta uma vez (vale a
  mais recente do arquivo). Nome, documento e data podem ser NULL (sócio estrangeiro, por exemplo),
  e o NULL conta como um valor da chave; só a base e o identificador são obrigatórios. Data
  AAAAMMDD vira DATE, e '00000000' vira NULL.
#}
WITH tPadronizados AS (
  SELECT
    NULLIF(TRIM(cnpj_basico), '') AS cnpj_basico
    , NULLIF(TRIM(identificador_de_socio), '') AS identificador_de_socio
    , NULLIF(TRIM(nome_do_socio_no_caso_pf_ou_razao_social_no_caso_pj), '')
      AS nome_do_socio_no_caso_pf_ou_razao_social_no_caso_pj
    , NULLIF(TRIM(cnpj_cpf_do_socio), '') AS cnpj_cpf_do_socio
    , NULLIF(TRIM(qualificacao_do_socio), '') AS qualificacao_do_socio
    , {{ data_compacta('data_de_entrada_sociedade') }} AS data_de_entrada_sociedade
    , NULLIF(TRIM(pais), '') AS pais
    , NULLIF(TRIM(representante_legal), '') AS representante_legal
    , NULLIF(TRIM(nome_do_representante), '') AS nome_do_representante
    , NULLIF(TRIM(qualificacao_do_representante_legal), '') AS qualificacao_do_representante_legal
    , NULLIF(TRIM(faixa_etaria), '') AS faixa_etaria
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ source('bronze_receita', 'socios') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tVersoes AS (
  SELECT
    cnpj_basico
    , identificador_de_socio
    , nome_do_socio_no_caso_pf_ou_razao_social_no_caso_pj
    , cnpj_cpf_do_socio
    , qualificacao_do_socio
    , data_de_entrada_sociedade
    , pais
    , representante_legal
    , nome_do_representante
    , qualificacao_do_representante_legal
    , faixa_etaria
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY
        cnpj_basico
        , identificador_de_socio
        , nome_do_socio_no_caso_pf_ou_razao_social_no_caso_pj
        , cnpj_cpf_do_socio
        , data_de_entrada_sociedade
      ORDER BY _arquivo DESC, _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM tPadronizados
  WHERE 1 = 1
    AND cnpj_basico IS NOT NULL
    AND identificador_de_socio IS NOT NULL
)

SELECT
  cnpj_basico
  , identificador_de_socio
  , nome_do_socio_no_caso_pf_ou_razao_social_no_caso_pj
  , cnpj_cpf_do_socio
  , qualificacao_do_socio
  , data_de_entrada_sociedade
  , pais
  , representante_legal
  , nome_do_representante
  , qualificacao_do_representante_legal
  , faixa_etaria
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
