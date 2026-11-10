{#
  Taxa de contato com terceiro por provedor (G2d; seção 9.2 de docs/decisoes-de-modelagem.md), sobre
  `silver_cobranca.contatos_realizados_provedores`, que guarda os provedores que trouxeram cada
  tentativa (lista aberta em linhas).
  Grão: uma linha por medida. `dimensao` = `provedor` (um valor por provedor que viu a tentativa;
  uma tentativa vista por dois provedores entra nos dois) ou `qt_provedores` (quantos provedores
  viram a tentativa, de 1 a 3; cada tentativa entra uma vez). A taxa é a fração das tentativas
  com `tipo_desfecho` = `terceiro` (numero_errado ou nao_conhece_devedor). Rodar com
  `dbt show --select taxa_terceiro_por_provedor`.
#}
WITH tQuantidadePorTentativa AS (
  SELECT
    contato_id
    , COUNT(*) AS qt_provedores
  FROM {{ ref('silver_cobranca_contatos_realizados_provedores') }}
  GROUP BY contato_id
)

, tProvedoresDaTentativa AS (
  SELECT
    provedores.contato_id
    , provedores.provedor_origem
    , tQuantidadePorTentativa.qt_provedores
  FROM {{ ref('silver_cobranca_contatos_realizados_provedores') }} AS provedores
  INNER JOIN tQuantidadePorTentativa
    ON provedores.contato_id = tQuantidadePorTentativa.contato_id
)

, tPorProvedor AS (
  SELECT
    CAST('provedor' AS VARCHAR) AS dimensao
    , tProvedoresDaTentativa.provedor_origem AS valor
    , COUNT(*) AS qt_tentativas
    , COUNT(CASE WHEN tentativas.tipo_desfecho = 'terceiro' THEN 1 END) AS qt_terceiro
  FROM tProvedoresDaTentativa
  INNER JOIN {{ ref('cobranca_tentativas') }} AS tentativas
    ON tProvedoresDaTentativa.contato_id = tentativas.contato_id
  GROUP BY tProvedoresDaTentativa.provedor_origem
)

, tPorQuantidade AS (
  SELECT
    CAST('qt_provedores' AS VARCHAR) AS dimensao
    , CAST(tProvedoresDaTentativa.qt_provedores AS VARCHAR) AS valor
    , COUNT(DISTINCT tProvedoresDaTentativa.contato_id) AS qt_tentativas
    , COUNT(
      DISTINCT CASE WHEN tentativas.tipo_desfecho = 'terceiro' THEN tentativas.contato_id END
    ) AS qt_terceiro
  FROM tProvedoresDaTentativa
  INNER JOIN {{ ref('cobranca_tentativas') }} AS tentativas
    ON tProvedoresDaTentativa.contato_id = tentativas.contato_id
  GROUP BY tProvedoresDaTentativa.qt_provedores
)

, tMedidas AS (
  SELECT
    dimensao
    , valor
    , qt_tentativas
    , qt_terceiro
  FROM tPorProvedor

  UNION ALL

  SELECT
    dimensao
    , valor
    , qt_tentativas
    , qt_terceiro
  FROM tPorQuantidade
)

SELECT
  dimensao
  , valor
  , qt_tentativas
  , qt_terceiro
  , ROUND(100 * CAST(qt_terceiro AS NUMERIC) / NULLIF(qt_tentativas, 0), 1) AS tx_terceiro_pct
FROM tMedidas
ORDER BY dimensao, valor
