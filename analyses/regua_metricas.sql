{#
  Métricas do loop de refinamento da régua (passo 4.7b), instrumento do `scripts/medir_regua.py`.
  Grão: uma linha, para o corte D da `var` `data_corte_validacao` (padrão 2026-09-15); o script
  roda com 2026-09-15 e 2026-09-22.
    - desfechos de risco: `terceiro`, `opt_out` e `falecido`; pego = par em `atencao` ou `bloqueado`;
    - `contato_confirmado` liberado = par em `liberado`; `sem_confirmacao` fica fora;
    - `acuracia_balanceada` = média da fração de riscos pegos e da fração de confirmados liberados;
    - `sem_par_no_corte` não conta como pego nem como liberado.
  Rodar com `dbt show --select regua_metricas`.
#}
WITH {{ regua_tentativas_avaliadas() }}

, tTotais AS (
  SELECT
    COUNT(CASE WHEN tipo_desfecho IN ('terceiro', 'opt_out', 'falecido') THEN 1 END) AS qt_risco
    , COUNT(
      CASE
        WHEN tipo_desfecho IN ('terceiro', 'opt_out', 'falecido')
          AND nivel_risco IN ('atencao', 'bloqueado') THEN 1
      END
    ) AS qt_risco_pego
    , COUNT(CASE WHEN tipo_desfecho = 'terceiro' THEN 1 END) AS qt_terceiro
    , COUNT(
      CASE WHEN tipo_desfecho = 'terceiro' AND nivel_risco IN ('atencao', 'bloqueado') THEN 1 END
    ) AS qt_terceiro_pego
    , COUNT(CASE WHEN tipo_desfecho = 'contato_confirmado' THEN 1 END) AS qt_confirmado
    , COUNT(
      CASE WHEN tipo_desfecho = 'contato_confirmado' AND nivel_risco = 'liberado' THEN 1 END
    ) AS qt_confirmado_liberado
  FROM tTentativasAvaliadas
)

, tFracoes AS (
  SELECT
    qt_risco
    , qt_risco_pego
    , qt_terceiro
    , qt_terceiro_pego
    , qt_confirmado
    , qt_confirmado_liberado
    , CAST(qt_risco_pego AS NUMERIC) / NULLIF(qt_risco, 0) AS fracao_risco_pego
    , CAST(qt_terceiro_pego AS NUMERIC) / NULLIF(qt_terceiro, 0) AS fracao_terceiro_pego
    , CAST(qt_confirmado_liberado AS NUMERIC) / NULLIF(qt_confirmado, 0)
      AS fracao_confirmado_liberado
  FROM tTotais
)

SELECT
  CAST('{{ var('data_corte_validacao', '2026-09-15') }}' AS DATE) AS dt_corte
  , qt_risco
  , qt_risco_pego
  , qt_terceiro
  , qt_terceiro_pego
  , qt_confirmado
  , qt_confirmado_liberado
  , ROUND(fracao_risco_pego, 4) AS fracao_risco_pego
  , ROUND(fracao_terceiro_pego, 4) AS fracao_terceiro_pego
  , ROUND(fracao_confirmado_liberado, 4) AS fracao_confirmado_liberado
  , ROUND((fracao_risco_pego + fracao_confirmado_liberado) / 2, 4) AS acuracia_balanceada
FROM tFracoes
