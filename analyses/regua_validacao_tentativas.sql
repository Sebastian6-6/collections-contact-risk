{#
  Validação da régua (p. 2 do enunciado; seção 9.9 de docs/decisoes-de-modelagem.md), passo 1.
  Grão: uma tentativa depois do corte D (padrão 2026-09-15, `var` `data_corte_validacao`), com o
  nível de `regua_de_risco(D)` para o par dela e o `tipo_desfecho`. Os sinais usam só dados até D.
  `sem_par_no_corte` é a tentativa cujo par a régua não tinha em D (ver `regua_tentativas_avaliadas`).
  Rodar com `dbt show --select regua_validacao_tentativas`.
#}
WITH {{ regua_tentativas_avaliadas() }}

SELECT
  contato_id
  , canal
  , dt_tentativa
  , sk_contato
  , sk_devedor
  , nivel_risco
  , desc_motivo_risco
  , resultado
  , tipo_desfecho
FROM tTentativasAvaliadas
ORDER BY dt_tentativa ASC, contato_id ASC
