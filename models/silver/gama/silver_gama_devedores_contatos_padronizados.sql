{#
  Etapa comum dos contatos do gama: os contatos de cada linha recebida, já abertos em linhas e
  normalizados, sem deduplicar. Grão: uma linha por contato de uma linha recebida (`_arquivo`,
  `_linha`, `posicao`). Só existe linha para contato de tipo conhecido e com valor preenchido. É
  efêmera: não vira tabela. Existe para a histórica (que calcula a assinatura da lista de cada
  versão) e para `devedores_historico_contatos` (que traz a lista da aparição mais recente)
  normalizarem do mesmo jeito, num lugar só.

  Os contatos vêm da lista `contatos`, de elementos {tipo, valor}. `celular` e `fixo` viram o
  `tipo_contato` `telefone`, e `email` vira `email`. O `tipo` do telefone (`celular` ou `fixo`) é
  do provedor; fica `NULL` no e-mail. A linha com a lista truncada (JSON inválido) não tem
  contato legível e não gera linha aqui.
#}
{{ config(materialized='ephemeral') }}

WITH tElementos AS (
  SELECT
    p._arquivo
    , p._linha
    , p._hash_arquivo
    , CAST(c.posicao AS INTEGER) AS posicao
    , c.valor ->> 'tipo' AS tipo_origem
    , c.valor ->> 'valor' AS valor_origem
  FROM {{ ref('silver_gama_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_contatos', 'c') }}
)

, tNormalizados AS (
  SELECT
    _arquivo
    , _linha
    , _hash_arquivo
    , posicao
    , CASE
      WHEN tipo_origem IN ('celular', 'fixo') THEN 'telefone'
      WHEN tipo_origem = 'email' THEN 'email'
    END AS tipo_contato
    , CASE
      WHEN tipo_origem IN ('celular', 'fixo') THEN {{ telefone_normalizado('valor_origem') }}
      WHEN tipo_origem = 'email' THEN {{ email_normalizado('valor_origem') }}
    END AS contato
    , CASE WHEN tipo_origem IN ('celular', 'fixo') THEN tipo_origem END AS tipo
  FROM tElementos
)

SELECT
  tipo_contato
  , contato
  , tipo
  , posicao
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tNormalizados
WHERE 1 = 1
  AND tipo_contato IS NOT NULL
  AND contato IS NOT NULL
