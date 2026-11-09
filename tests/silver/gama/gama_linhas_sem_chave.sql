{#
  Linhas da bronze do gama que ficam fora da silver por não terem chave (S9): linha ilegível,
  cabeçalho repetido dentro do histórico ou documento vazio ou sem dígitos. Só avisa (`warn`):
  cada linha devolvida continua na bronze e não chegou à silver; o total aparece no resultado do
  teste e o motivo, em cada linha.
#}
{{ config(severity='warn') }}

SELECT
  _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    WHEN documento = 'documento' THEN 'cabeçalho repetido'
    ELSE 'sem documento'
  END AS motivo
FROM {{ source('bronze_gama', 'devedores') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR {{ somente_digitos('documento') }} IS NULL
  )
