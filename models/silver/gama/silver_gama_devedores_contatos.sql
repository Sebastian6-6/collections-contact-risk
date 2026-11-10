{#
  Grão: uma linha por (documento, tipo_contato, contato normalizado), com a primeira e a última
  data de entrega em que o par apareceu. Considera todas as linhas da bronze com documento, não só a
  versão atual do devedor (S4): um número que saiu da versão mais recente continua registrado.
  Só existe linha para contato que veio preenchido. A linha de documento vazio ou só com zeros
  também entra, com `documento` NULL: esses contatos são deduplicados só por (`tipo_contato`,
  `contato`) entre as linhas sem documento e nunca se juntam a um par de documento válido.

  Os contatos vêm da lista `contatos`, de elementos {tipo, valor}. `celular` e `fixo` viram o `tipo_contato`
  `telefone`, e `email` vira `email`. O `tipo` do telefone (`celular` ou `fixo`) é do provedor e
  vem da aparição mais recente do contato (mesma ordem da versão do devedor, S3); fica `NULL` no
  e-mail. `_arquivo`, `_linha` e `_hash_arquivo` são dessa mesma aparição, porque a data de
  entrega não identifica o arquivo (a gama tem arquivo original e reenvio na mesma data). A linha
  com a lista truncada (JSON inválido) não tem contato legível: o devedor entra em `devedores`,
  mas esta tabela não traz o que a lista cortada tinha.
#}
WITH tElementos AS (
  SELECT
    p.documento
    , p.dt_ref
    , p.data_entrega
    , p._arquivo
    , p._linha
    , p._hash_arquivo
    , CAST(c.posicao AS INTEGER) AS posicao
    , c.valor ->> 'tipo' AS tipo_origem
    , c.valor ->> 'valor' AS valor_origem
  FROM {{ ref('silver_gama_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_contatos', 'c') }}
)

, tAparicoes AS (
  SELECT
    documento
    , posicao
    , dt_ref
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
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

, tValidas AS (
  SELECT
    documento
    , tipo_contato
    , contato
    , tipo
    , posicao
    , dt_ref
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tAparicoes
  WHERE 1 = 1
    AND tipo_contato IS NOT NULL
    AND contato IS NOT NULL
)

, tEntregas AS (
  SELECT
    documento
    , tipo_contato
    , contato
    , MIN(data_entrega) AS data_primeira_entrega
    , MAX(data_entrega) AS data_ultima_entrega
  FROM tValidas
  GROUP BY
    documento
    , tipo_contato
    , contato
)

, tOrdenadas AS (
  SELECT
    documento
    , tipo_contato
    , contato
    , tipo
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento, tipo_contato, contato
      ORDER BY
        dt_ref DESC NULLS LAST
        , data_entrega DESC NULLS LAST
        , _arquivo DESC
        , _linha DESC
        , posicao DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tValidas
)

, tMaisRecentes AS (
  SELECT
    documento
    , tipo_contato
    , contato
    , tipo
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tOrdenadas
  WHERE 1 = 1
    AND num_aparicao = 1
)

SELECT
  e.documento
  , e.tipo_contato
  , e.contato
  , r.tipo
  , e.data_primeira_entrega
  , e.data_ultima_entrega
  , r._arquivo
  , r._linha
  , r._hash_arquivo
FROM tEntregas AS e
INNER JOIN tMaisRecentes AS r
  ON e.documento IS NOT DISTINCT FROM r.documento
    AND e.tipo_contato = r.tipo_contato
    AND e.contato = r.contato
