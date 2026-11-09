{#
  Grão: uma linha por (documento, tipo, contato normalizado), com a primeira e a última data de
  entrega em que o par apareceu. Considera todas as linhas da bronze com documento, não só a
  versão atual do devedor (S4): um número que saiu da versão mais recente continua registrado.
  Só existe linha para contato que veio preenchido.

  Os contatos vêm da lista `contatos`, de elementos {tipo, valor}. `celular` e `fixo` viram o tipo
  `telefone`, e `email` vira `email`. O tipo do telefone (`celular` ou `fixo`) é do provedor e
  vem da aparição mais recente do contato (mesma ordem da versão do devedor, S3); fica `NULL` no
  e-mail. A linha com a lista truncada (JSON inválido) não tem contato legível: o devedor entra
  em `devedores`, mas esta tabela não traz o que a lista cortada tinha.
#}
WITH tElementos AS (
  SELECT
    p.documento
    , p.data_atualizacao
    , p.data_entrega
    , p._linha
    , c.valor ->> 'tipo' AS tipo_origem
    , c.valor ->> 'valor' AS valor_origem
    , CAST(c.posicao AS INTEGER) AS posicao
  FROM {{ ref('silver_gama_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_contatos', 'c') }}
)

, tAparicoes AS (
  SELECT
    documento
    , posicao
    , data_atualizacao
    , data_entrega
    , _linha
    , CASE
      WHEN tipo_origem IN ('celular', 'fixo') THEN 'telefone'
      WHEN tipo_origem = 'email' THEN 'email'
    END AS tipo
    , CASE
      WHEN tipo_origem IN ('celular', 'fixo') THEN {{ telefone_normalizado('valor_origem') }}
      WHEN tipo_origem = 'email' THEN {{ email_normalizado('valor_origem') }}
    END AS contato
    , CASE WHEN tipo_origem IN ('celular', 'fixo') THEN tipo_origem END AS tipo_telefone
  FROM tElementos
)

, tValidas AS (
  SELECT
    documento
    , tipo
    , contato
    , tipo_telefone
    , posicao
    , data_atualizacao
    , data_entrega
    , _linha
  FROM tAparicoes
  WHERE 1 = 1
    AND tipo IS NOT NULL
    AND contato IS NOT NULL
)

, tEntregas AS (
  SELECT
    documento
    , tipo
    , contato
    , MIN(data_entrega) AS data_primeira_entrega
    , MAX(data_entrega) AS data_ultima_entrega
  FROM tValidas
  GROUP BY
    documento
    , tipo
    , contato
)

, tOrdenadas AS (
  SELECT
    documento
    , tipo
    , contato
    , tipo_telefone
    , ROW_NUMBER() OVER (
      PARTITION BY documento, tipo, contato
      ORDER BY
        data_atualizacao DESC NULLS LAST
        , data_entrega DESC NULLS LAST
        , _linha DESC
        , posicao DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tValidas
)

, tMaisRecentes AS (
  SELECT
    documento
    , tipo
    , contato
    , tipo_telefone
  FROM tOrdenadas
  WHERE 1 = 1
    AND num_aparicao = 1
)

SELECT
  e.documento
  , e.tipo
  , e.contato
  , r.tipo_telefone
  , e.data_primeira_entrega
  , e.data_ultima_entrega
FROM tEntregas AS e
INNER JOIN tMaisRecentes AS r
  ON e.documento = r.documento
    AND e.tipo = r.tipo
    AND e.contato = r.contato
