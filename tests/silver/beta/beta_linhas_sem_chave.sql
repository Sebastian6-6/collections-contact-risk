{#
  Linhas da bronze do beta que não viram devedor por não terem chave (S9): o JSON não é válido
  (registro truncado, "Registro Interrompido") ou o documento está vazio ou só com zeros. Só
  avisa (`warn`): cada linha devolvida continua na bronze e não está em `devedores`; o total
  aparece no resultado do teste e o motivo, em cada linha. Os contatos de uma linha de documento
  vazio ou zerado ficam em `devedores_contatos` com `documento` NULL (o teste
  `beta_linhas_representadas` confere).
#}
{{ config(severity='warn') }}

SELECT
  b._arquivo
  , b._linha
  , CASE
    WHEN {{ json_ou_nulo('b.registro') }} IS NULL THEN 'json inválido'
    ELSE 'documento vazio ou zerado'
  END AS motivo
FROM {{ source('bronze_beta', 'devedores') }} AS b
LEFT JOIN {{ ref('silver_beta_devedores_padronizados') }} AS p
  ON b._arquivo = p._arquivo
    AND b._linha = p._linha
WHERE 1 = 1
  AND (p._linha IS NULL OR p.documento IS NULL)
