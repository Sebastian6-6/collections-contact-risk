{#
  Grão: uma linha por (tipo de documento, documento, tipo, contato normalizado), com a primeira e
  a última data de entrega em que o par apareceu. Considera todas as linhas da bronze com
  documento, não só a versão atual do devedor (S4): um número que saiu da versão mais recente
  continua registrado. Só existe linha para contato que veio preenchido.

  Os contatos vêm de três lugares do JSON (S6): a lista de telefones (cada elemento é um texto
  ou um objeto {ddd, numero, tipo, principal}), a lista `emails` e o texto `email`. O tipo do
  telefone (celular ou fixo) e o `principal` são do provedor e vêm da aparição mais recente do
  contato (mesma ordem da versão do devedor, S3); ficam `NULL` quando essa aparição não os traz
  (telefone escrito como texto, e-mail).
#}
WITH tTelefones AS (
  SELECT
    p.tipo_documento
    , p.documento
    , 'telefone' AS tipo
    , {{ telefone_de_elemento_json('t.valor') }} AS contato
    , CAST(t.valor ->> 'tipo' AS VARCHAR) AS tipo_telefone
    , CAST(t.valor ->> 'principal' AS BOOLEAN) AS principal
    , CAST(t.posicao AS INTEGER) AS posicao
    , p.data_atualizacao
    , p.data_entrega
    , p._arquivo
    , p._linha
    , p._hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_telefones', 't') }}
)

, tEmailsDaLista AS (
  SELECT
    p.tipo_documento
    , p.documento
    , 'email' AS tipo
    , {{ email_normalizado(json_texto('e.valor')) }} AS contato
    , CAST(NULL AS VARCHAR) AS tipo_telefone
    , CAST(NULL AS BOOLEAN) AS principal
    , CAST(e.posicao AS INTEGER) AS posicao
    , p.data_atualizacao
    , p.data_entrega
    , p._arquivo
    , p._linha
    , p._hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_emails', 'e') }}
)

, tEmailsUnicos AS (
  SELECT
    tipo_documento
    , documento
    , 'email' AS tipo
    , email_unico AS contato
    , CAST(NULL AS VARCHAR) AS tipo_telefone
    , CAST(NULL AS BOOLEAN) AS principal
    , CAST(1 AS INTEGER) AS posicao
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }}
  WHERE 1 = 1
    AND email_unico IS NOT NULL
)

, tAparicoes AS (
  SELECT
    tipo_documento
    , documento
    , tipo
    , contato
    , tipo_telefone
    , principal
    , posicao
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tTelefones
  WHERE 1 = 1
    AND contato IS NOT NULL

  UNION ALL

  SELECT
    tipo_documento
    , documento
    , tipo
    , contato
    , tipo_telefone
    , principal
    , posicao
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tEmailsDaLista
  WHERE 1 = 1
    AND contato IS NOT NULL

  UNION ALL

  SELECT
    tipo_documento
    , documento
    , tipo
    , contato
    , tipo_telefone
    , principal
    , posicao
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tEmailsUnicos
)

, tEntregas AS (
  SELECT
    tipo_documento
    , documento
    , tipo
    , contato
    , MIN(data_entrega) AS data_primeira_entrega
    , MAX(data_entrega) AS data_ultima_entrega
  FROM tAparicoes
  GROUP BY
    tipo_documento
    , documento
    , tipo
    , contato
)

, tOrdenadas AS (
  SELECT
    tipo_documento
    , documento
    , tipo
    , contato
    , tipo_telefone
    , principal
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY tipo_documento, documento, tipo, contato
      ORDER BY
        data_atualizacao DESC NULLS LAST
        , data_entrega DESC NULLS LAST
        , _arquivo DESC
        , _linha DESC
        , posicao DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tAparicoes
)

, tMaisRecentes AS (
  SELECT
    tipo_documento
    , documento
    , tipo
    , contato
    , tipo_telefone
    , principal
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tOrdenadas
  WHERE 1 = 1
    AND num_aparicao = 1
)

SELECT
  e.tipo_documento
  , e.documento
  , e.tipo
  , e.contato
  , r.tipo_telefone
  , r.principal
  , e.data_primeira_entrega
  , e.data_ultima_entrega
  , r._arquivo
  , r._linha
  , r._hash_arquivo
FROM tEntregas AS e
INNER JOIN tMaisRecentes AS r
  ON e.tipo_documento = r.tipo_documento
    AND e.documento = r.documento
    AND e.tipo = r.tipo
    AND e.contato = r.contato
