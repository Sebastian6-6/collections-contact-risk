{#
  Grão: uma linha por (tipo de documento, documento, tipo_contato, contato normalizado), com a
  primeira e a última data de entrega em que o par apareceu. Sai da histórica
  (`silver_beta_devedores_historico` e `silver_beta_devedores_historico_contatos`), que guarda
  todas as versões, não só a atual (S4): um número que saiu da versão mais recente continua
  registrado. Só existe linha para contato que veio preenchido. A versão sem documento (vazio ou
  só zeros) também entra, com `documento_tipo` e `documento` NULL: esses contatos são
  deduplicados só por (`tipo_contato`, `contato`) entre si e nunca se juntam a um par de
  documento válido.

  A primeira entrega é a menor das primeiras entregas das versões que têm o par; a última, a
  maior das últimas. O `tipo` do telefone (celular ou fixo) e o `principal` são do provedor e
  vêm da aparição mais recente do par: a da versão com a maior `ordem_versao` (mesma ordem da
  versão do devedor, S3) e, no empate, a maior posição na lista. `_arquivo`, `_linha` e
  `_hash_arquivo` são dessa mesma aparição, porque a data de entrega não identifica o arquivo.
#}
WITH tAparicoes AS (
  SELECT
    h.documento_tipo
    , h.documento
    , c.tipo_contato
    , c.contato
    , c.tipo
    , c.principal
    , c.posicao
    , h.atualizado_em
    , h.data_primeira_entrega
    , h.data_ultima_entrega
    , h.data_ultima_entrega AS data_entrega
    , c._arquivo
    , c._linha
    , c._hash_arquivo
  FROM {{ ref('silver_beta_devedores_historico') }} AS h
  INNER JOIN {{ ref('silver_beta_devedores_historico_contatos') }} AS c
    ON h.hash_conteudo = c.hash_conteudo
)

, tEntregas AS (
  SELECT
    documento_tipo
    , documento
    , tipo_contato
    , contato
    , MIN(data_primeira_entrega) AS data_primeira_entrega
    , MAX(data_ultima_entrega) AS data_ultima_entrega
  FROM tAparicoes
  GROUP BY
    documento_tipo
    , documento
    , tipo_contato
    , contato
)

, tOrdenadas AS (
  SELECT
    documento_tipo
    , documento
    , tipo_contato
    , contato
    , tipo
    , principal
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento_tipo, documento, tipo_contato, contato
      ORDER BY
        {{ ordem_versao('atualizado_em') }}
        , posicao DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tAparicoes
)

, tMaisRecentes AS (
  SELECT
    documento_tipo
    , documento
    , tipo_contato
    , contato
    , tipo
    , principal
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tOrdenadas
  WHERE 1 = 1
    AND num_aparicao = 1
)

SELECT
  e.documento_tipo
  , e.documento
  , e.tipo_contato
  , e.contato
  , r.tipo
  , r.principal
  , e.data_primeira_entrega
  , e.data_ultima_entrega
  , r._arquivo
  , r._linha
  , r._hash_arquivo
FROM tEntregas AS e
INNER JOIN tMaisRecentes AS r
  ON e.documento_tipo IS NOT DISTINCT FROM r.documento_tipo
    AND e.documento IS NOT DISTINCT FROM r.documento
    AND e.tipo_contato = r.tipo_contato
    AND e.contato = r.contato
