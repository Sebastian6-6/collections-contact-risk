{#
  Contagens por arquivo do provedor alfa (macro `contagens_da_entrega`). Grão: um arquivo.
  Efêmero: etapa interna de `entregas_diarias_apuradas`.
#}
{{ contagens_da_entrega('alfa', "bronze.data_atualizacao") }}
