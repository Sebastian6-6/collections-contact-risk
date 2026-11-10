{#
  Ausência de dado é `NULL`, nunca zero (convenções do case): o 0,00 que o alfa manda como
  salário vira `vl_renda` `NULL` na gold (ponto 6). Cada linha devolvida é um período de vínculo
  com renda zero.
#}
SELECT
  provedor
  , sk_devedor
  , vl_renda
FROM {{ ref('ft_vinculo_empresa') }}
WHERE 1 = 1
  AND vl_renda = 0
