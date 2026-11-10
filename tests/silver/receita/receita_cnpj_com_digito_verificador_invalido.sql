{#
  Todo CNPJ de estabelecimento da Receita tem 14 caracteres e os dois dígitos verificadores certos
  (regra oficial, macro `cnpj_valido`, que aceita o CNPJ alfanumérico). É a base pública: um CNPJ
  inválido aqui é erro de ingestão ou de montagem, não do provedor. Cada linha devolvida é um CNPJ
  que a regra não reconhece.
#}
SELECT
  cnpj
  , _arquivo
  , _linha
FROM {{ ref('silver_receita_estabelecimentos') }}
WHERE 1 = 1
  AND {{ cnpj_valido('cnpj') }} IS NOT TRUE
