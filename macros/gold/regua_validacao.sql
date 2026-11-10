{#
  Base da validação da régua (G4c; seção 9.9 de docs/decisoes-de-modelagem.md). Devolve as CTEs,
  sem o `WITH`, até `tTentativasAvaliadas`. Uso: `WITH {{ regua_tentativas_avaliadas() }}`.

  Grão de `tTentativasAvaliadas`: uma tentativa de `cobranca_tentativas` depois do corte D, com o
  nível e os sinais do par que a régua (`regua_de_risco(D)`) dava a esse par em D. Os sinais usam só
  entregas e tentativas até D; o desfecho (`tipo_desfecho`) é o que veio depois, sem vazamento.

  Tentativa sem par na régua de D (`nivel_risco` = `sem_par_no_corte`): o contato não tinha o par
  entregue até D, ou a tentativa não liga a nenhum par (`ligacao` = `sem_ligacao`). Ela fica na
  matriz com esse rótulo, em vez de ser descartada ou de receber um nível que a régua não deu;
  nas métricas do loop (`regua_metricas`) ela fica fora dos totais e das frações e aparece à parte,
  como contagem (`qt_sem_par_no_corte`).

  `data_corte`: 'AAAA-MM-DD'. Sem argumento vale a `var` `data_corte_validacao` (padrão
  2026-09-15), que o `scripts/medir_regua.py` troca para medir o segundo corte.
#}
{% macro regua_tentativas_avaliadas(data_corte=none) -%}
  {%- set corte = data_corte if data_corte is not none else var('data_corte_validacao', '2026-09-15') -%}
  {{ regua_sinais_do_par(corte) }}

  , tReguaNoCorte AS (
    {{ regua_de_risco(corte) }}
  )

  , tTentativasAvaliadas AS (
    SELECT
      cobranca_tentativas.contato_id
      , cobranca_tentativas.canal
      , cobranca_tentativas.dt_tentativa
      , cobranca_tentativas.resultado
      , cobranca_tentativas.tipo_desfecho
      , cobranca_tentativas.ligacao
      , cobranca_tentativas.sk_contato
      , cobranca_tentativas.sk_devedor
      , COALESCE(tReguaNoCorte.nivel_risco, 'sem_par_no_corte') AS nivel_risco
      , tReguaNoCorte.desc_motivo_risco
      , tSinaisDoPar.situacao_documento
      , tSinaisDoPar.situacao_compartilhamento
      , tSinaisDoPar.tipo_alerta_historico
      , tSinaisDoPar.tipo_conflito_cadastral
      , tSinaisDoPar.qt_provedores
      , tSinaisDoPar.qt_devedores_mesmo_contato
      , tSinaisDoPar.qt_tentativas
      , tSinaisDoPar.qt_tentativas_terceiro
    FROM {{ ref('cobranca_tentativas') }} AS cobranca_tentativas
    LEFT JOIN tReguaNoCorte
      ON cobranca_tentativas.sk_contato = tReguaNoCorte.sk_contato
    LEFT JOIN tSinaisDoPar
      ON cobranca_tentativas.sk_contato = tSinaisDoPar.sk_contato
    WHERE 1 = 1
      AND cobranca_tentativas.dt_tentativa > CAST('{{ corte }}' AS DATE)
  )
{%- endmacro %}
