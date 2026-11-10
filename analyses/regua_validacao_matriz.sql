{#
  Validação da régua, passo 2: matriz nível x desfecho no corte D (padrão 2026-09-15).
  Grão: uma linha por `nivel_risco`, com a contagem de tentativas depois de D por `tipo_desfecho`.
  `sem_par_no_corte` mostra as tentativas a que a régua não deu nível. As colunas `pct_*` são a
  fração dos terceiros e dos confirmados a que a régua deu nível que a linha concentra; como nas
  métricas do loop, `sem_par_no_corte` fica fora do denominador e tem `pct_*` `NULL`.
  Rodar com `dbt show --select regua_validacao_matriz`.
#}
WITH {{ regua_tentativas_avaliadas() }}

, tMatriz AS (
  SELECT
    nivel_risco
    , COUNT(*) AS qt_tentativas
    , COUNT(CASE WHEN tipo_desfecho = 'contato_confirmado' THEN 1 END) AS qt_contato_confirmado
    , COUNT(CASE WHEN tipo_desfecho = 'sem_confirmacao' THEN 1 END) AS qt_sem_confirmacao
    , COUNT(CASE WHEN tipo_desfecho = 'terceiro' THEN 1 END) AS qt_terceiro
    , COUNT(CASE WHEN tipo_desfecho = 'opt_out' THEN 1 END) AS qt_opt_out
    , COUNT(CASE WHEN tipo_desfecho = 'falecido' THEN 1 END) AS qt_falecido
  FROM tTentativasAvaliadas
  GROUP BY nivel_risco
)

, tMatrizComNivel AS (
  SELECT
    nivel_risco
    , qt_tentativas
    , qt_contato_confirmado
    , qt_sem_confirmacao
    , qt_terceiro
    , qt_opt_out
    , qt_falecido
    , CASE WHEN nivel_risco <> 'sem_par_no_corte' THEN qt_terceiro END AS qt_terceiro_com_nivel
    , CASE WHEN nivel_risco <> 'sem_par_no_corte' THEN qt_contato_confirmado END
      AS qt_confirmado_com_nivel
  FROM tMatriz
)

SELECT
  nivel_risco
  , qt_tentativas
  , qt_contato_confirmado
  , qt_sem_confirmacao
  , qt_terceiro
  , qt_opt_out
  , qt_falecido
  , ROUND(100 * CAST(qt_terceiro_com_nivel AS NUMERIC) / NULLIF(SUM(qt_terceiro_com_nivel) OVER (
    ORDER BY nivel_risco ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ), 0), 1) AS pct_dos_terceiros
  , ROUND(
    100 * CAST(qt_confirmado_com_nivel AS NUMERIC) / NULLIF(SUM(qt_confirmado_com_nivel) OVER (
      ORDER BY nivel_risco ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ), 0), 1
  ) AS pct_dos_confirmados
FROM tMatrizComNivel
ORDER BY nivel_risco ASC
