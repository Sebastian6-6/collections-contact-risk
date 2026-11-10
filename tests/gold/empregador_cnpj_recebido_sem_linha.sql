{#
  Todo CNPJ de empregador recebido, de qualquer versão das três fontes, tem linha na
  `dim_empregador` (C5 do enriquecimento), encontrado ou não na Receita. Cada linha devolvida é um
  CNPJ recebido que a dimensão perdeu: a junção com a Receita não pode descartar empregador.
#}
WITH tRecebidos AS (
  SELECT cnpj_empregador AS cnpj
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND cnpj_empregador IS NOT NULL

  UNION

  SELECT vinculo_empresa_cnpj AS cnpj
  FROM {{ ref('silver_beta_devedores_historico') }}
  WHERE 1 = 1
    AND vinculo_empresa_cnpj IS NOT NULL

  UNION

  SELECT cnpj_empregador_raw AS cnpj
  FROM {{ ref('silver_gama_devedores_historico') }}
  WHERE 1 = 1
    AND cnpj_empregador_raw IS NOT NULL
)

SELECT tRecebidos.cnpj
FROM tRecebidos
LEFT JOIN {{ ref('dim_empregador') }} AS dim_empregador
  ON tRecebidos.cnpj = dim_empregador.cnpj
WHERE 1 = 1
  AND dim_empregador.cnpj IS NULL
