{#
  Linhas da bronze do beta que ficam fora da silver por não terem chave (S9): o JSON não é válido
  (registro truncado, "Registro Interrompido") ou o documento está vazio. Só avisa (`warn`):
  cada linha devolvida continua na bronze e não chegou à silver; o total aparece no resultado do
  teste e o motivo, em cada linha.
#}
{{ config(severity='warn') }}

SELECT
  b._arquivo
  , b._linha
  , CASE
    WHEN {{ json_ou_nulo('b.registro') }} IS NULL THEN 'json inválido'
    ELSE 'sem documento'
  END AS motivo
FROM {{ source('bronze_beta', 'devedores') }} AS b
LEFT JOIN {{ ref('silver_beta_devedores_padronizados') }} AS p
  ON b._arquivo = p._arquivo
    AND b._linha = p._linha
WHERE 1 = 1
  AND p._linha IS NULL
