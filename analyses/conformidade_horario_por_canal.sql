{#
  Conformidade de horário por canal (G7; seção 9.10 de docs/decisoes-de-modelagem.md).
  Grão: uma linha por canal, com a contagem das tentativas de setembro por `situacao_horario` da
  `ft_tentativa_contato` e o percentual fora da janela (domingo, feriado e fora do horário). O
  e-mail é `nao_se_aplica` e fica fora do percentual. Rodar com
  `dbt show --select conformidade_horario_por_canal`.
#}
WITH tPorCanal AS (
  SELECT
    canal
    , COUNT(*) AS qt_tentativas
    , COUNT(CASE WHEN situacao_horario = 'permitido' THEN 1 END) AS qt_permitido
    , COUNT(CASE WHEN situacao_horario = 'fora_do_horario' THEN 1 END) AS qt_fora_do_horario
    , COUNT(CASE WHEN situacao_horario = 'domingo' THEN 1 END) AS qt_domingo
    , COUNT(CASE WHEN situacao_horario = 'feriado' THEN 1 END) AS qt_feriado
    , COUNT(CASE WHEN situacao_horario = 'nao_se_aplica' THEN 1 END) AS qt_nao_se_aplica
  FROM {{ ref('ft_tentativa_contato') }}
  GROUP BY canal
)

SELECT
  canal
  , qt_tentativas
  , qt_permitido
  , qt_fora_do_horario
  , qt_domingo
  , qt_feriado
  , qt_nao_se_aplica
  , ROUND(
    100 * CAST(qt_fora_do_horario + qt_domingo + qt_feriado AS NUMERIC)
    / NULLIF(qt_tentativas - qt_nao_se_aplica, 0)
    , 1
  ) AS tx_fora_da_janela_pct
FROM tPorCanal
ORDER BY canal
