{#
  Etapa comum da gold de devedores: os documentos cuja versão mais recente empata com outra
  versão diferente (ponto 4). Grão: um documento (`provedor`, `documento_tipo`, `documento`)
  em que duas ou mais versões da histórica têm a mesma data de atualização, a mesma data de
  entrega e o mesmo arquivo; só a linha desempata, na `devedores` da silver (`_linha DESC`, uma
  convenção arbitrária). Lê a histórica, onde estão todas as versões. É efêmero: existe para a
  `dim_devedor` marcar `versao` em `tipo_conflito_cadastral`.
#}
{{ config(materialized='ephemeral') }}

WITH tHistorico AS (
  SELECT
    'alfa' AS provedor
    , 'CPF' AS documento_tipo
    , documento
    , data_atualizacao
    , data_ultima_entrega AS data_entrega
    , _arquivo
    , _linha
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL

  UNION ALL

  SELECT
    'beta' AS provedor
    , documento_tipo
    , documento
    , atualizado_em AS data_atualizacao
    , data_ultima_entrega AS data_entrega
    , _arquivo
    , _linha
  FROM {{ ref('silver_beta_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL

  UNION ALL

  SELECT
    'gama' AS provedor
    , 'CPF' AS documento_tipo
    , documento
    , dt_ref AS data_atualizacao
    , data_ultima_entrega AS data_entrega
    , _arquivo
    , _linha
  FROM {{ ref('silver_gama_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

, tVersoesOrdenadas AS (
  SELECT
    provedor
    , documento_tipo
    , documento
    , ROW_NUMBER() OVER (
      PARTITION BY provedor, documento_tipo, documento
      ORDER BY
        {{ ordem_versao('data_atualizacao') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
    , SUM(1) OVER (
      PARTITION BY provedor, documento_tipo, documento, data_atualizacao, data_entrega, _arquivo
      ORDER BY _linha
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS qt_versoes_no_topo
  FROM tHistorico
)

SELECT
  provedor
  , documento_tipo
  , documento
FROM tVersoesOrdenadas
WHERE 1 = 1
  AND num_versao = 1
  AND qt_versoes_no_topo > 1
