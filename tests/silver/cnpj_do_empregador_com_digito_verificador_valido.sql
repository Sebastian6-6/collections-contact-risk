{#
  Todo CNPJ de empregador com 14 caracteres na silver tem os dois dígitos verificadores certos
  (regra oficial da Receita, macro `cnpj_valido`). Vale para o que veio com 14 caracteres, que
  `cnpj_normalizado` não altera, e para o que ela completou ou calculou. Cada linha devolvida é um
  CNPJ de 14 caracteres que a regra não reconhece: o provedor mandou um número inválido.
#}
SELECT
  'silver_alfa.devedores' AS tabela
  , cnpj_empregador AS cnpj
FROM {{ ref('silver_alfa_devedores') }}
WHERE 1 = 1
  AND LENGTH(cnpj_empregador) = 14
  AND {{ cnpj_valido('cnpj_empregador') }} IS NOT TRUE

UNION ALL

SELECT
  'silver_beta.devedores' AS tabela
  , cnpj_empregador AS cnpj
FROM {{ ref('silver_beta_devedores') }}
WHERE 1 = 1
  AND LENGTH(cnpj_empregador) = 14
  AND {{ cnpj_valido('cnpj_empregador') }} IS NOT TRUE

UNION ALL

SELECT
  'silver_gama.devedores' AS tabela
  , cnpj_empregador_raw AS cnpj
FROM {{ ref('silver_gama_devedores') }}
WHERE 1 = 1
  AND LENGTH(cnpj_empregador_raw) = 14
  AND {{ cnpj_valido('cnpj_empregador_raw') }} IS NOT TRUE
