{#
  Validação da régua, passo 4: peso preditivo de cada sinal no corte D (padrão 2026-09-15).
  Grão: uma linha por sinal, sobre as tentativas depois de D cujo par a régua conhecia em D
  (`sem_par_no_corte` fica fora, porque não tem sinais). Compara a taxa de `terceiro` entre as
  tentativas com o sinal e sem ele; `razao` é a taxa com o sinal dividida pela taxa sem ele, e
  `qt_*` são as quantidades de cada lado. Sinais que a régua já usa e sinais que ela ainda não usa
  (`provedor unico`, `sem tentativa anterior`) ficam lado a lado, para apoiar as propostas de ajuste.
  Rodar com `dbt show --select regua_validacao_peso_sinais`.
#}
WITH {{ regua_tentativas_avaliadas() }}

, tComPar AS (
  SELECT
    situacao_documento
    , situacao_compartilhamento
    , tipo_alerta_historico
    , tipo_conflito_cadastral
    , sk_devedor
    , qt_provedores
    , qt_tentativas
    , (tipo_desfecho = 'terceiro') AS e_terceiro
  FROM tTentativasAvaliadas
  WHERE 1 = 1
    AND nivel_risco <> 'sem_par_no_corte'
)

, tPorSinal AS (
  SELECT
    'falecido' AS sinal
    , e_terceiro
    , (tipo_alerta_historico = 'falecido') AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'opt_out' AS sinal
    , e_terceiro
    , (tipo_alerta_historico = 'opt_out') AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'disse nao ser o devedor' AS sinal
    , e_terceiro
    , (tipo_alerta_historico = 'nao_e_o_devedor') AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'contato migrado' AS sinal
    , e_terceiro
    , (situacao_compartilhamento = 'migrado') AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'contato compartilhado' AS sinal
    , e_terceiro
    , (situacao_compartilhamento = 'compartilhado') AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'contato sem devedor' AS sinal
    , e_terceiro
    , (sk_devedor IS NULL) AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'conflito de identidade' AS sinal
    , e_terceiro
    , (tipo_conflito_cadastral IN ('identidade', 'identidade_e_versao')) AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'documento por correcao ou RG' AS sinal
    , e_terceiro
    , (situacao_documento IN ('cpf_corrigido', 'rg_por_nome_nascimento')) AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'CPF invalido sem ligacao' AS sinal
    , e_terceiro
    , (situacao_documento = 'cpf_invalido') AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'provedor unico' AS sinal
    , e_terceiro
    , (qt_provedores = 1) AS tem_sinal
  FROM tComPar

  UNION ALL

  SELECT
    'sem tentativa anterior' AS sinal
    , e_terceiro
    , (qt_tentativas = 0) AS tem_sinal
  FROM tComPar
)

, tPesos AS (
  SELECT
    sinal
    , COUNT(CASE WHEN tem_sinal THEN 1 END) AS qt_com
    , COUNT(CASE WHEN tem_sinal AND e_terceiro THEN 1 END) AS qt_terceiro_com
    , COUNT(CASE WHEN NOT tem_sinal THEN 1 END) AS qt_sem
    , COUNT(CASE WHEN NOT tem_sinal AND e_terceiro THEN 1 END) AS qt_terceiro_sem
  FROM tPorSinal
  GROUP BY sinal
)

SELECT
  sinal
  , qt_com
  , qt_terceiro_com
  , qt_sem
  , qt_terceiro_sem
  , ROUND(100 * CAST(qt_terceiro_com AS NUMERIC) / NULLIF(qt_com, 0), 2) AS tx_terceiro_com_pct
  , ROUND(100 * CAST(qt_terceiro_sem AS NUMERIC) / NULLIF(qt_sem, 0), 2) AS tx_terceiro_sem_pct
  , ROUND(
    (CAST(qt_terceiro_com AS NUMERIC) / NULLIF(qt_com, 0))
    / NULLIF(CAST(qt_terceiro_sem AS NUMERIC) / NULLIF(qt_sem, 0), 0)
    , 1
  ) AS razao
FROM tPesos
ORDER BY razao DESC NULLS LAST, sinal ASC
