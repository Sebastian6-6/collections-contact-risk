{#
  Alerta do monitoramento diário (D4): olha só a entrega mais recente de cada provedor, a que a
  execução de hoje trouxe, e devolve uma linha por motivo de alerta (macro `alertas_da_entrega`).
  Severidade `warn`: um alerta pede olhar o provedor, não derruba a pipeline. Sem linhas, a entrega
  de hoje está normal. As entregas antigas com alerta são as de `alertas_das_entregas`.
#}
{{ config(severity='warn') }}

WITH tNumeradas AS (
  SELECT
    provedor
    , dt_referencia
    , qt_arquivos
    , qt_registros
    , qt_dias_desde_entrega_anterior
    , tx_variacao_media
    , situacao_volume
    , situacao_cabecalho
    , qt_registros_repetidos
    , qt_registros_atrasados
    , qt_linhas_ilegiveis
    , ROW_NUMBER() OVER (
      PARTITION BY provedor
      ORDER BY dt_referencia DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_recente
  FROM {{ ref('ft_entrega_diaria') }}
)

, tMaisRecentes AS (
  SELECT
    provedor
    , dt_referencia
    , qt_arquivos
    , qt_registros
    , qt_dias_desde_entrega_anterior
    , tx_variacao_media
    , situacao_volume
    , situacao_cabecalho
    , qt_registros_repetidos
    , qt_registros_atrasados
    , qt_linhas_ilegiveis
  FROM tNumeradas
  WHERE 1 = 1
    AND num_recente = 1
)

{{ alertas_da_entrega('tMaisRecentes') }}
