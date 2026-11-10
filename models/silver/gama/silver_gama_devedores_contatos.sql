{#
  Grão: uma linha por (documento, tipo_contato, contato normalizado), com a primeira e a última
  data de entrega em que o par apareceu. Sai da histórica (`silver_gama_devedores_historico` e
  `silver_gama_devedores_historico_contatos`), que guarda todas as versões, não só a atual (S4):
  um número que saiu da versão mais recente continua registrado. Só existe linha para contato que
  veio preenchido. A versão sem documento (vazio ou só zeros) também entra, com `documento`
  NULL: esses contatos são deduplicados só por (`tipo_contato`, `contato`) entre si e nunca se
  juntam a um par de documento válido.

  Os contatos vêm da lista `contatos`: `celular` e `fixo` viram o `tipo_contato` `telefone`, e
  `email` vira `email`. A primeira entrega é a menor das primeiras entregas das versões que têm o
  par; a última, a maior das últimas. O `tipo` do telefone (`celular` ou `fixo`) é do provedor e
  vem da aparição mais recente do par: a da versão com a maior `ordem_versao` (mesma ordem da
  versão do devedor, S3) e, no empate, a maior posição na lista; fica `NULL` no e-mail.
  `_arquivo`, `_linha` e `_hash_arquivo` são dessa mesma aparição, porque a data de entrega não
  identifica o arquivo (a gama tem arquivo original e reenvio na mesma data). A linha com a lista
  truncada (JSON inválido) não tem contato legível: o devedor entra em `devedores`, mas esta
  tabela não traz o que a lista cortada tinha.
#}
WITH tAparicoes AS (
  SELECT
    h.documento
    , c.tipo_contato
    , c.contato
    , c.tipo
    , c.posicao
    , h.dt_ref
    , h.data_primeira_entrega
    , h.data_ultima_entrega
    , h.data_ultima_entrega AS data_entrega
    , c._arquivo
    , c._linha
    , c._hash_arquivo
  FROM {{ ref('silver_gama_devedores_historico') }} AS h
  INNER JOIN {{ ref('silver_gama_devedores_historico_contatos') }} AS c
    ON h.hash_conteudo = c.hash_conteudo
)

, tEntregas AS (
  SELECT
    documento
    , tipo_contato
    , contato
    , MIN(data_primeira_entrega) AS data_primeira_entrega
    , MAX(data_ultima_entrega) AS data_ultima_entrega
  FROM tAparicoes
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
        {{ ordem_versao('dt_ref') }}
        , posicao DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tAparicoes
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
