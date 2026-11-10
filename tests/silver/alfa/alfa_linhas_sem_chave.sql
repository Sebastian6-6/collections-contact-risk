{#
  Linhas da bronze do alfa que não viram devedor por não terem chave (S9): documento vazio ou só
  com zeros, ou linha ilegível. Só avisa (`warn`): cada linha devolvida continua na bronze e não
  está em `devedores`; o total aparece no resultado do teste e o motivo, em cada linha. Os
  contatos de uma linha de documento vazio ou zerado não se perdem: ficam em `devedores_contatos`
  com `documento` NULL (o teste `alfa_linhas_representadas` confere).
#}
{{ config(severity='warn') }}
{%- set documento_origem = "COALESCE(NULLIF(TRIM(cpf), ''), NULLIF(TRIM(documento), ''))" -%}

SELECT
  _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'documento vazio ou zerado'
  END AS motivo
FROM {{ source('bronze_alfa', 'devedores') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR {{ cpf_normalizado(documento_origem) }} IS NULL
  )
