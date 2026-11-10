{#
  Cada devedor tem ao menos um endereço `atual` quando a versão vigente dele trouxe endereço (G3b).
  Cada linha devolvida é um devedor sem nenhum endereço `atual`: aponta falha na ligação entre a
  versão vigente e o endereço da silver (o `hash_endereco` recalculado deixou de bater).
#}
SELECT dim_devedor.sk_devedor
FROM {{ ref('dim_devedor') }} AS dim_devedor
LEFT JOIN {{ ref('dim_endereco') }} AS dim_endereco
  ON dim_devedor.sk_devedor = dim_endereco.sk_devedor
    AND dim_endereco.situacao_endereco = 'atual'
GROUP BY dim_devedor.sk_devedor
HAVING COUNT(dim_endereco.sk_endereco) = 0
