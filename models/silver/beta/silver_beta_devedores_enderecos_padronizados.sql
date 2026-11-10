{#
  Etapa comum dos endereços do beta: os endereços de cada linha recebida, já abertos em linhas e
  padronizados, sem deduplicar. Grão: uma linha por endereço de uma linha recebida (`_arquivo`,
  `_linha`, `posicao`). O beta manda o endereço como lista (`enderecos`) ou como um objeto só
  (`endereco`); o objeto vira a posição 1. O `atual` fica como veio (S7). É efêmera: não vira
  tabela. Existe para a histórica (que calcula a assinatura da lista de cada versão) e para
  `devedores_historico_enderecos` (que traz a lista da aparição mais recente) padronizarem do
  mesmo jeito, num lugar só.
#}
{{ config(materialized='ephemeral') }}

WITH tListas AS (
  SELECT
    CAST(l.posicao AS INTEGER) AS posicao
    , l.valor AS endereco_json
    , p._arquivo
    , p._linha
    , p._hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_enderecos', 'l') }}
)

, tUnicos AS (
  SELECT
    CAST(1 AS INTEGER) AS posicao
    , endereco_unico AS endereco_json
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }}
  WHERE 1 = 1
    AND endereco_unico IS NOT NULL
)

, tEnderecos AS (
  SELECT
    posicao
    , endereco_json
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tListas

  UNION ALL

  SELECT
    posicao
    , endereco_json
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tUnicos
)

SELECT
  posicao
  , NULLIF(TRIM(endereco_json ->> 'tipo'), '') AS tipo
  , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'logradouro'), '')") }} AS logradouro
  , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'numero'), '')") }} AS numero
  , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'complemento'), '')") }} AS complemento
  , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'bairro'), '')") }} AS bairro
  , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'cidade'), '')") }} AS cidade
  , {{ uf_normalizada("endereco_json ->> 'uf'") }} AS uf
  , LPAD({{ somente_digitos("endereco_json ->> 'cep'") }}, 8, '0') AS cep
  , CAST(endereco_json ->> 'atual' AS BOOLEAN) AS atual
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tEnderecos
