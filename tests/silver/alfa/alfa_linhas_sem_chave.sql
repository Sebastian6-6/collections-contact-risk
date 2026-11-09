{#
  Linhas da bronze do alfa que ficam fora da silver por não terem chave (S9): documento vazio ou
  sem dígitos, ou linha ilegível. Só avisa (`warn`): cada linha devolvida é uma linha que
  continua na bronze e não chegou à silver, e o total aparece no resultado do teste.
#}
{{ config(severity='warn') }}
{%- set documento_origem = "COALESCE(NULLIF(TRIM(cpf), ''), NULLIF(TRIM(documento), ''))" -%}

SELECT
  _arquivo
  , _linha
FROM {{ source('bronze_alfa', 'devedores') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR {{ somente_digitos(documento_origem) }} IS NULL
  )
