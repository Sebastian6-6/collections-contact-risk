{#
  CNPJ de empregador que a normalização não consegue deixar com 14 caracteres: mais de 14, ou
  menos de 14 sem regra que o complete (nem zeros à esquerda com dígitos verificadores válidos,
  nem os 12 caracteres da base). Fica como veio e é uma limitação da base, documentada em
  `docs/contratos-de-dados.md`. Só avisa (`warn`): cada linha devolvida é um valor que o provedor
  precisa corrigir. Hoje nenhum valor da base cai aqui.
#}
{{ config(severity='warn') }}

SELECT
  'silver_alfa.devedores' AS tabela
  , cnpj_empregador AS cnpj
FROM {{ ref('silver_alfa_devedores') }}
WHERE 1 = 1
  AND LENGTH(cnpj_empregador) <> 14

UNION ALL

SELECT
  'silver_beta.devedores' AS tabela
  , vinculo_empresa_cnpj AS cnpj
FROM {{ ref('silver_beta_devedores') }}
WHERE 1 = 1
  AND LENGTH(vinculo_empresa_cnpj) <> 14

UNION ALL

SELECT
  'silver_gama.devedores' AS tabela
  , cnpj_empregador_raw AS cnpj
FROM {{ ref('silver_gama_devedores') }}
WHERE 1 = 1
  AND LENGTH(cnpj_empregador_raw) <> 14
