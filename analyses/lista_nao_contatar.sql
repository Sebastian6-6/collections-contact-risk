{#
  Lista de não-contatar (G5; seção 9.9 de docs/decisoes-de-modelagem.md): a `dim_contato` filtrada
  por `nivel_risco` = `bloqueado`, sem tabela própria. Grão: um par devedor x contato bloqueado,
  com o motivo principal. O opt-out já bloqueia o contato para todos os CPFs ligados a ele, e o
  falecimento bloqueia todos os pares do devedor. Rodar com `dbt show --select lista_nao_contatar`
  (`--limit` troca o tamanho da amostra).
#}
SELECT
  sk_contato
  , sk_devedor
  , cpf
  , tipo_contato
  , contato
  , desc_motivo_risco
  , tipo_alerta_historico
  , situacao_compartilhamento
  , dt_alerta_historico
FROM {{ ref('dim_contato') }}
WHERE 1 = 1
  AND nivel_risco = 'bloqueado'
ORDER BY desc_motivo_risco ASC, sk_contato ASC
