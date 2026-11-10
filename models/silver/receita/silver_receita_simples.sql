{#
  Grão: uma linha por empresa (`cnpj_basico`) com os dados do Simples Nacional e do MEI. As datas
  AAAAMMDD viram DATE e '00000000' (sem data) vira NULL. Se a origem repetir a base, vale a linha
  mais recente do arquivo.
#}
WITH tPadronizados AS (
  SELECT
    NULLIF(TRIM(cnpj_basico), '') AS cnpj_basico
    , NULLIF(TRIM(opcao_pelo_simples), '') AS opcao_pelo_simples
    , {{ data_compacta('data_de_opcao_pelo_simples') }} AS data_de_opcao_pelo_simples
    , {{ data_compacta('data_de_exclusao_do_simples') }} AS data_de_exclusao_do_simples
    , NULLIF(TRIM(opcao_pelo_mei), '') AS opcao_pelo_mei
    , {{ data_compacta('data_de_opcao_pelo_mei') }} AS data_de_opcao_pelo_mei
    , {{ data_compacta('data_de_exclusao_do_mei') }} AS data_de_exclusao_do_mei
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ source('bronze_receita', 'simples') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tVersoes AS (
  SELECT
    cnpj_basico
    , opcao_pelo_simples
    , data_de_opcao_pelo_simples
    , data_de_exclusao_do_simples
    , opcao_pelo_mei
    , data_de_opcao_pelo_mei
    , data_de_exclusao_do_mei
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
  , opcao_pelo_simples
  , data_de_opcao_pelo_simples
  , data_de_exclusao_do_simples
  , opcao_pelo_mei
  , data_de_opcao_pelo_mei
  , data_de_exclusao_do_mei
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
