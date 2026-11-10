{#
  Grão: uma linha por (documento, tipo_contato, contato normalizado), com a primeira e a
  última data de entrega em que o par apareceu. Sai da histórica (`silver_alfa_devedores_historico`),
  que guarda todas as versões, não só a atual (S4): um número que saiu da versão mais recente
  continua registrado. Só existe linha para contato que veio preenchido. A versão sem documento
  (vazio ou só zeros) também entra, com `documento` NULL: esses contatos são deduplicados só por
  (`tipo_contato`, `contato`) entre si e nunca se juntam a um par de documento válido.
  A primeira entrega é a menor das primeiras entregas das versões que têm o par; a última, a maior
  das últimas. `_arquivo`, `_linha` e `_hash_arquivo` são da aparição mais recente do par: a da
  versão com a maior `ordem_versao`, porque a data de entrega não identifica o arquivo.
#}
WITH tContatos AS (
  SELECT
    documento
    , 'telefone' AS tipo_contato
    , telefone AS contato
    , data_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
    , data_ultima_entrega AS data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND telefone IS NOT NULL

  UNION ALL

  SELECT
    documento
    , 'email' AS tipo_contato
    , email AS contato
    , data_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
    , data_ultima_entrega AS data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND email IS NOT NULL
)

, tEntregas AS (
  SELECT
    documento
    , tipo_contato
    , contato
    , MIN(data_primeira_entrega) AS data_primeira_entrega
    , MAX(data_ultima_entrega) AS data_ultima_entrega
  FROM tContatos
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
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento, tipo_contato, contato
      ORDER BY
        {{ ordem_versao('data_atualizacao') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tContatos
)

, tMaisRecentes AS (
  SELECT
    documento
    , tipo_contato
    , contato
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
