{#
  Validação da régua, passo 3: calibração no corte D (padrão 2026-09-15). Uma régua calibrada tem
  taxa de desfecho de risco crescente de `liberado` para `atencao` e `bloqueado`.
  Grão: uma linha por `nivel_risco`, com a taxa (em %) de terceiro, opt_out, falecido e contato
  confirmado entre as tentativas depois de D, e a taxa de risco total (os três primeiros).
  Rodar com `dbt show --select regua_validacao_calibracao`.
#}
WITH {{ regua_tentativas_avaliadas() }}

, tPorNivel AS (
  SELECT
    nivel_risco
    , COUNT(*) AS qt_tentativas
    , COUNT(CASE WHEN tipo_desfecho = 'terceiro' THEN 1 END) AS qt_terceiro
    , COUNT(CASE WHEN tipo_desfecho = 'opt_out' THEN 1 END) AS qt_opt_out
    , COUNT(CASE WHEN tipo_desfecho = 'falecido' THEN 1 END) AS qt_falecido
    , COUNT(CASE WHEN tipo_desfecho = 'contato_confirmado' THEN 1 END) AS qt_contato_confirmado
  FROM tTentativasAvaliadas
  GROUP BY nivel_risco
)

SELECT
  nivel_risco
  , qt_tentativas
  , ROUND(100 * CAST(qt_terceiro AS NUMERIC) / NULLIF(qt_tentativas, 0), 2) AS tx_terceiro_pct
  , ROUND(100 * CAST(qt_opt_out AS NUMERIC) / NULLIF(qt_tentativas, 0), 2) AS tx_opt_out_pct
  , ROUND(100 * CAST(qt_falecido AS NUMERIC) / NULLIF(qt_tentativas, 0), 2) AS tx_falecido_pct
  , ROUND(
    100 * CAST(qt_terceiro + qt_opt_out + qt_falecido AS NUMERIC) / NULLIF(qt_tentativas, 0)
    , 2
  ) AS tx_risco_pct
  , ROUND(100 * CAST(qt_contato_confirmado AS NUMERIC) / NULLIF(qt_tentativas, 0), 2)
    AS tx_contato_confirmado_pct
FROM tPorNivel
ORDER BY nivel_risco ASC
