{#
  Nenhuma tabela da silver com documento guarda um documento só com zeros: ele não identifica
  ninguém e vira NULL (ausência de chave). Cada linha devolvida é um documento zerado que passou
  para uma tabela. Vale para as tabelas de devedores e de contatos dos três provedores e para o
  `cpf_alvo` da cobrança.
#}
SELECT
  'silver_alfa.devedores' AS tabela
  , documento
FROM {{ ref('silver_alfa_devedores') }}
WHERE 1 = 1
  AND documento ~ '^0+$'

UNION ALL

SELECT
  'silver_alfa.devedores_contatos' AS tabela
  , documento
FROM {{ ref('silver_alfa_devedores_contatos') }}
WHERE 1 = 1
  AND documento ~ '^0+$'

UNION ALL

SELECT
  'silver_beta.devedores' AS tabela
  , documento
FROM {{ ref('silver_beta_devedores') }}
WHERE 1 = 1
  AND documento ~ '^0+$'

UNION ALL

SELECT
  'silver_beta.devedores_contatos' AS tabela
  , documento
FROM {{ ref('silver_beta_devedores_contatos') }}
WHERE 1 = 1
  AND documento ~ '^0+$'

UNION ALL

SELECT
  'silver_gama.devedores' AS tabela
  , documento
FROM {{ ref('silver_gama_devedores') }}
WHERE 1 = 1
  AND documento ~ '^0+$'

UNION ALL

SELECT
  'silver_gama.devedores_contatos' AS tabela
  , documento
FROM {{ ref('silver_gama_devedores_contatos') }}
WHERE 1 = 1
  AND documento ~ '^0+$'

UNION ALL

SELECT
  'silver_cobranca.contatos_realizados' AS tabela
  , cpf_alvo AS documento
FROM {{ ref('silver_cobranca_contatos_realizados') }}
WHERE 1 = 1
  AND cpf_alvo ~ '^0+$'
