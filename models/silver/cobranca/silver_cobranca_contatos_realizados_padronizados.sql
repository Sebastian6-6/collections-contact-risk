{#
  Etapa comum da silver da cobrança: toda linha lida da bronze que tem `contato_id`, já
  padronizada e sem deduplicar. Grão: uma linha por linha recebida com chave (`_arquivo`,
  `_linha`). É efêmera: existe para `contatos_realizados` (uma linha por contato) e
  `contatos_realizados_provedores` (abre `provedor_origem`) padronizarem do mesmo jeito (S2).

  O `destino` depende do canal: `ligacao`, `sms` e `whatsapp` levam telefone; `email` leva
  e-mail. Canal fora dessa lista deixa o destino normalizado `NULL` (o texto original continua
  em `destino_original`), em vez de adivinhar o formato.
#}
{{ config(materialized='ephemeral') }}

WITH tBase AS (
  SELECT
    NULLIF(TRIM(contato_id), '') AS contato_id
    , {{ cpf_normalizado('cpf_alvo') }} AS cpf_alvo
    , NULLIF(LOWER(TRIM(canal)), '') AS canal
    , destino
    , data_hora
    , NULLIF(TRIM(resultado), '') AS resultado
    , NULLIF(LOWER(TRIM(provedor_origem)), '') AS provedor_origem
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ source('bronze_cobranca', 'contatos_realizados') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

SELECT
  contato_id
  , cpf_alvo
  , canal
  , destino AS destino_original
  , CASE
    WHEN canal IN ('ligacao', 'sms', 'whatsapp') THEN {{ telefone_normalizado('destino') }}
    WHEN canal = 'email' THEN {{ email_normalizado('destino') }}
  END AS destino
  , {{ timestamp_ou_nulo('data_hora') }} AS data_hora
  , resultado
  , provedor_origem
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tBase
WHERE 1 = 1
  AND contato_id IS NOT NULL
