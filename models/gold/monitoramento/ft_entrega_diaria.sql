{#
  Grão: uma entrega diária de um provedor (`provedor`, `dt_referencia`), as mesmas linhas de
  `entregas_diarias_apuradas`. Os arquivos do dia (original e reenvio) já vêm somados.
  `qt_dias_desde_entrega_anterior` (D2): a entrega n é comparada com a n - 1 do mesmo provedor
  por `ROW_NUMBER()` e auto-junção, sem `LAG`; maior que 1 é dia sem entrega. A primeira entrega
  não tem anterior e fica `NULL`.
  `qt_media_movel` (D3): média de `qt_registros` das entregas anteriores do mesmo provedor e do
  mesmo tipo de dia (`tp_dia`: `util` ou `fim_de_semana`), com `SUM()` em `ROWS BETWEEN n PRECEDING
  AND 1 PRECEDING`, n = `var` `janela_media_movel`. A janela conta entregas, não dias: um dia sem
  entrega não entra como zero. `qt_entregas_base` diz com quantas a média foi feita.
  `situacao_volume`: `sem_base` com menos de `base_minima_media_movel` entregas na base, `acima`
  e `abaixo` quando `tx_variacao_media` passa de `limite_variacao_volume` (positivo ou negativo),
  senão `normal`. `situacao_cabecalho` compara os cabeçalhos com os da entrega anterior (`igual`
  ou `mudou`; `NULL` na primeira). Uma entrega com `qt_arquivos` maior que 1 tem reenvio.
#}
{%- set janela = var('janela_media_movel') -%}
{%- set limite = var('limite_variacao_volume') -%}
{%- set base_minima = var('base_minima_media_movel') -%}

WITH tNumeradas AS (
  SELECT
    provedor
    , dt_referencia
    , qt_arquivos
    , qt_registros
    , qt_registros_repetidos
    , qt_registros_atrasados
    , qt_linhas_ilegiveis
    , desc_cabecalho
    , desc_arquivos
    , CASE
      WHEN EXTRACT(ISODOW FROM dt_referencia) IN (6, 7) THEN 'fim_de_semana'
      ELSE 'util'
    END AS tp_dia
    , ROW_NUMBER() OVER (
      PARTITION BY provedor
      ORDER BY dt_referencia ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_entrega
  FROM {{ ref('entregas_diarias_apuradas') }}
)

, tComAnterior AS (
  SELECT
    atual.provedor
    , atual.dt_referencia
    , atual.tp_dia
    , atual.qt_arquivos
    , atual.qt_registros
    , atual.qt_registros_repetidos
    , atual.qt_registros_atrasados
    , atual.qt_linhas_ilegiveis
    , atual.desc_arquivos
    , atual.dt_referencia - anterior.dt_referencia AS qt_dias_desde_entrega_anterior
    , CASE
      WHEN anterior.desc_cabecalho IS NULL THEN CAST(NULL AS VARCHAR)
      WHEN atual.desc_cabecalho = anterior.desc_cabecalho THEN 'igual'
      ELSE 'mudou'
    END AS situacao_cabecalho
  FROM tNumeradas AS atual
  LEFT JOIN tNumeradas AS anterior
    ON atual.provedor = anterior.provedor
      AND atual.num_entrega = anterior.num_entrega + 1
)

, tComMedia AS (
  SELECT
    provedor
    , dt_referencia
    , tp_dia
    , qt_arquivos
    , qt_registros
    , qt_registros_repetidos
    , qt_registros_atrasados
    , qt_linhas_ilegiveis
    , qt_dias_desde_entrega_anterior
    , situacao_cabecalho
    , desc_arquivos
    , CAST(SUM(qt_registros) OVER (
      PARTITION BY provedor, tp_dia
      ORDER BY dt_referencia ASC
      ROWS BETWEEN {{ janela }} PRECEDING AND 1 PRECEDING
    ) AS NUMERIC) / SUM(1) OVER (
      PARTITION BY provedor, tp_dia
      ORDER BY dt_referencia ASC
      ROWS BETWEEN {{ janela }} PRECEDING AND 1 PRECEDING
    ) AS qt_media_movel
    , SUM(1) OVER (
      PARTITION BY provedor, tp_dia
      ORDER BY dt_referencia ASC
      ROWS BETWEEN {{ janela }} PRECEDING AND 1 PRECEDING
    ) AS qt_entregas_base
  FROM tComAnterior
)

, tComVariacao AS (
  SELECT
    provedor
    , dt_referencia
    , tp_dia
    , qt_arquivos
    , qt_registros
    , qt_media_movel
    , qt_entregas_base
    , qt_dias_desde_entrega_anterior
    , qt_registros_repetidos
    , qt_registros_atrasados
    , qt_linhas_ilegiveis
    , situacao_cabecalho
    , desc_arquivos
    , CASE
      WHEN qt_entregas_base >= {{ base_minima }}
        THEN (qt_registros - qt_media_movel) / qt_media_movel
    END AS tx_variacao_media
  FROM tComMedia
)

SELECT
  provedor
  , tp_dia
  , qt_arquivos
  , qt_registros
  , CAST(qt_media_movel AS NUMERIC(12, 2)) AS qt_media_movel
  , qt_entregas_base
  , CAST(tx_variacao_media AS NUMERIC(8, 4)) AS tx_variacao_media
  , qt_dias_desde_entrega_anterior
  , qt_registros_repetidos
  , qt_registros_atrasados
  , qt_linhas_ilegiveis
  , CASE
    WHEN tx_variacao_media IS NULL THEN 'sem_base'
    WHEN tx_variacao_media > {{ limite }} THEN 'acima'
    WHEN tx_variacao_media < -{{ limite }} THEN 'abaixo'
    ELSE 'normal'
  END AS situacao_volume
  , situacao_cabecalho
  , dt_referencia
  , desc_arquivos
FROM tComVariacao
