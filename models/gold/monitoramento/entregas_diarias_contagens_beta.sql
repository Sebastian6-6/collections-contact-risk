{#
  Contagens por arquivo do provedor beta (macro `contagens_da_entrega`). Grão: um arquivo.
  Efêmero: etapa interna de `entregas_diarias_apuradas`.
#}
{{ contagens_da_entrega('beta', "(" ~ json_ou_nulo('bronze.registro') ~ ") ->> 'atualizado_em'") }}
