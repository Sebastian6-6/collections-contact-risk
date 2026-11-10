{#
  Validação da régua, passo 5: padrões de erro no corte D (padrão 2026-09-15).
    - `ponto_cego`: tentativa de nível `liberado` que terminou em `terceiro`;
    - `falso_bloqueio`: tentativa de nível `bloqueado` ou `atencao` que terminou em
      `contato_confirmado` (cobrança que a régua teria impedido ou desviado).
  Grão: uma linha por tipo de erro x dimensão x valor. `dimensao` = `motivo` (o `desc_motivo_risco`
  que a régua deu), `qt_provedores` (quantos provedores entregaram o contato até D) ou `canal`.
  `pct_do_erro` é a parte do erro que o valor concentra. `sem_par_no_corte` não entra: a régua não
  deu nível a essas tentativas. Rodar com `dbt show --select regua_validacao_erros`.
  Proposta de ajuste que sai daqui, para o loop 4.7b medir: o contato entregue por um só provedor
  concentra 40 dos 73 pontos cegos e tem 6,33% de terceiro, contra 1,4% nas demais tentativas (ver
  `regua_validacao_peso_sinais`); `atencao` para ele é a hipótese a testar, contra o custo em
  `contato_confirmado` liberado.
#}
WITH {{ regua_tentativas_avaliadas() }}

, tErros AS (
  SELECT
    canal
    , desc_motivo_risco
    , qt_provedores
    , CASE
      WHEN nivel_risco = 'liberado' AND tipo_desfecho = 'terceiro' THEN 'ponto_cego'
      WHEN nivel_risco IN ('bloqueado', 'atencao') AND tipo_desfecho = 'contato_confirmado'
        THEN 'falso_bloqueio'
    END AS tipo_erro
  FROM tTentativasAvaliadas
)

, tPorDimensao AS (
  SELECT
    tipo_erro
    , 'motivo' AS dimensao
    , COALESCE(desc_motivo_risco, 'sem motivo') AS valor
  FROM tErros
  WHERE 1 = 1
    AND tipo_erro IS NOT NULL

  UNION ALL

  SELECT
    tipo_erro
    , 'qt_provedores' AS dimensao
    , CAST(qt_provedores AS VARCHAR) AS valor
  FROM tErros
  WHERE 1 = 1
    AND tipo_erro IS NOT NULL

  UNION ALL

  SELECT
    tipo_erro
    , 'canal' AS dimensao
    , canal AS valor
  FROM tErros
  WHERE 1 = 1
    AND tipo_erro IS NOT NULL
)

, tContagem AS (
  SELECT
    tipo_erro
    , dimensao
    , valor
    , COUNT(*) AS qt_tentativas
  FROM tPorDimensao
  GROUP BY tipo_erro, dimensao, valor
)

SELECT
  tipo_erro
  , dimensao
  , valor
  , qt_tentativas
  , ROUND(
    100 * CAST(qt_tentativas AS NUMERIC) / NULLIF(SUM(qt_tentativas) OVER (
      PARTITION BY tipo_erro, dimensao
      ORDER BY valor ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ), 0)
    , 1
  ) AS pct_do_erro
FROM tContagem
ORDER BY tipo_erro ASC, dimensao ASC, qt_tentativas DESC, valor ASC
