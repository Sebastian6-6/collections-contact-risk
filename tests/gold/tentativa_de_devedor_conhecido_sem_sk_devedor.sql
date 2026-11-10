{#
  Falha para cada tentativa cujo CPF alvo é de um devedor da gold e que, mesmo assim, ficou sem
  `sk_devedor`. O devedor vem do CPF da tentativa, não do par: a ausência do par no contato não o
  apaga.
#}
SELECT cobranca_tentativas.contato_id
FROM {{ ref('cobranca_tentativas') }} AS cobranca_tentativas
INNER JOIN {{ ref('dim_devedor') }} AS dim_devedor
  ON cobranca_tentativas.cpf = dim_devedor.cpf
WHERE 1 = 1
  AND cobranca_tentativas.sk_devedor IS NULL
