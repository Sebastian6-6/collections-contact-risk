{#
  Etapa comum da silver dos estabelecimentos: toda linha legível da bronze, já padronizada e sem
  deduplicar. Grão: uma linha por linha recebida com chave (`_arquivo`, `_linha`). É efêmera:
  existe para `estabelecimentos` (uma linha por CNPJ) e `estabelecimentos_cnaes_secundarios` (abre a
  lista `cnae_fiscal_secundaria`) padronizarem do mesmo jeito.

  O `cnpj` é a base, a ordem e os dois dígitos verificadores juntos (14 caracteres; no CNPJ
  alfanumérico a letra está na ordem). Textos sem espaços nas pontas e vazio como NULL; datas
  AAAAMMDD viram DATE, e '00000000' vira NULL. O `pais`, o `municipio` e os CNAEs são códigos
  que ficam como vieram, para juntar com os domínios.
#}
{{ config(materialized='ephemeral') }}

SELECT
  NULLIF(TRIM(cnpj_basico), '')
  || NULLIF(TRIM(cnpj_ordem), '')
  || NULLIF(TRIM(cnpj_dv), '') AS cnpj
  , NULLIF(TRIM(cnpj_basico), '') AS cnpj_basico
  , NULLIF(TRIM(cnpj_ordem), '') AS cnpj_ordem
  , NULLIF(TRIM(cnpj_dv), '') AS cnpj_dv
  , NULLIF(TRIM(identificador_matriz_filial), '') AS identificador_matriz_filial
  , NULLIF(TRIM(nome_fantasia), '') AS nome_fantasia
  , NULLIF(TRIM(situacao_cadastral), '') AS situacao_cadastral
  , {{ data_compacta('data_situacao_cadastral') }} AS data_situacao_cadastral
  , NULLIF(TRIM(motivo_situacao_cadastral), '') AS motivo_situacao_cadastral
  , NULLIF(TRIM(nome_da_cidade_no_exterior), '') AS nome_da_cidade_no_exterior
  , NULLIF(TRIM(pais), '') AS pais
  , {{ data_compacta('data_de_inicio_atividade') }} AS data_de_inicio_atividade
  , NULLIF(TRIM(cnae_fiscal_principal), '') AS cnae_fiscal_principal
  , NULLIF(TRIM(cnae_fiscal_secundaria), '') AS cnae_fiscal_secundaria
  , NULLIF(TRIM(tipo_de_logradouro), '') AS tipo_de_logradouro
  , NULLIF(TRIM(logradouro), '') AS logradouro
  , NULLIF(TRIM(numero), '') AS numero
  , NULLIF(TRIM(complemento), '') AS complemento
  , NULLIF(TRIM(bairro), '') AS bairro
  , NULLIF(TRIM(cep), '') AS cep
  , NULLIF(TRIM(uf), '') AS uf
  , NULLIF(TRIM(municipio), '') AS municipio
  , NULLIF(TRIM(ddd_1), '') AS ddd_1
  , NULLIF(TRIM(telefone_1), '') AS telefone_1
  , NULLIF(TRIM(ddd_2), '') AS ddd_2
  , NULLIF(TRIM(telefone_2), '') AS telefone_2
  , NULLIF(TRIM(ddd_do_fax), '') AS ddd_do_fax
  , NULLIF(TRIM(fax), '') AS fax
  , NULLIF(TRIM(correio_eletronico), '') AS correio_eletronico
  , NULLIF(TRIM(situacao_especial), '') AS situacao_especial
  , {{ data_compacta('data_da_situacao_especial') }} AS data_da_situacao_especial
  , _arquivo
  , _linha
  , _hash_arquivo
FROM {{ source('bronze_receita', 'estabelecimentos') }}
WHERE 1 = 1
  AND _motivo_ilegivel IS NULL
