{#
  Todos os alertas do monitoramento diário, não só os da entrega mais recente (o teste
  `entrega_recente_com_alerta` olha esta). Grão: uma linha por entrega e motivo, pelas mesmas
  regras (macro `alertas_da_entrega`). É a consulta que mostra os incidentes conhecidos de
  setembro/2026 e quantos alarmes falsos sobram. Rodar com `dbt show --select alertas_das_entregas`.
#}
WITH tEntregas AS (
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
  FROM {{ ref('ft_entrega_diaria') }}
)

, tAlertas AS (
  {{ alertas_da_entrega('tEntregas') }}
)

SELECT
  provedor
  , dt_referencia
  , motivo
  , valor
FROM tAlertas
ORDER BY
  dt_referencia
  , provedor
  , motivo
