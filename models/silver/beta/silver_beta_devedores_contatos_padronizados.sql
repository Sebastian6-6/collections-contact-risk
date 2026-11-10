{#
  Etapa comum dos contatos do beta: os telefones e e-mails de cada linha recebida, já abertos em
  linhas e normalizados, sem deduplicar. Grão: uma linha por contato de uma linha recebida
  (`_arquivo`, `_linha`, `tipo_contato`, `posicao`). Só existe linha para contato que veio
  preenchido. É efêmera: não vira tabela. Existe para a histórica (que calcula a assinatura da
  lista de cada versão) e para `devedores_historico_contatos` (que traz a lista da aparição mais
  recente) normalizarem do mesmo jeito, num lugar só.

  Os contatos vêm de três lugares do JSON (S6): a lista de telefones (cada elemento é um texto
  ou um objeto {ddd, numero, tipo, principal}), a lista `emails` e o texto `email`. O `tipo` do
  telefone (celular ou fixo) e o `principal` são do provedor; ficam `NULL` quando o elemento não
  os traz (telefone escrito como texto, e-mail). `tipo_contato` (`telefone` ou `email`) é criado
  aqui; `tipo` é o campo do provedor.
#}
{{ config(materialized='ephemeral') }}

WITH tTelefones AS (
  SELECT
    'telefone' AS tipo_contato
    , {{ telefone_de_elemento_json('t.valor') }} AS contato
    , CAST(t.valor ->> 'tipo' AS VARCHAR) AS tipo
    , CAST(t.valor ->> 'principal' AS BOOLEAN) AS principal
    , CAST(t.posicao AS INTEGER) AS posicao
    , p._arquivo
    , p._linha
    , p._hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_telefones', 't') }}
)

, tEmailsDaLista AS (
  SELECT
    'email' AS tipo_contato
    , {{ email_normalizado(json_texto('e.valor')) }} AS contato
    , CAST(NULL AS VARCHAR) AS tipo
    , CAST(NULL AS BOOLEAN) AS principal
    , CAST(e.posicao AS INTEGER) AS posicao
    , p._arquivo
    , p._linha
    , p._hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_emails', 'e') }}
)

, tEmailsUnicos AS (
  SELECT
    'email' AS tipo_contato
    , email_unico AS contato
    , CAST(NULL AS VARCHAR) AS tipo
    , CAST(NULL AS BOOLEAN) AS principal
    , CAST(1 AS INTEGER) AS posicao
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }}
  WHERE 1 = 1
    AND email_unico IS NOT NULL
)

, tContatos AS (
  SELECT
    tipo_contato
    , contato
    , tipo
    , principal
    , posicao
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tTelefones

  UNION ALL

  SELECT
    tipo_contato
    , contato
    , tipo
    , principal
    , posicao
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tEmailsDaLista

  UNION ALL

  SELECT
    tipo_contato
    , contato
    , tipo
    , principal
    , posicao
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tEmailsUnicos
)

SELECT
  tipo_contato
  , contato
  , tipo
  , principal
  , posicao
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tContatos
WHERE 1 = 1
  AND contato IS NOT NULL
