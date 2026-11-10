{#
  Linhas da bronze do gama que não viram devedor por não terem chave (S9): linha ilegível,
  cabeçalho repetido dentro do histórico ou documento vazio ou só com zeros. Só avisa (`warn`):
  cada linha devolvida continua na bronze e não está em `devedores`; o total aparece no
  resultado do teste e o motivo, em cada linha. Os contatos de uma linha de documento vazio ou
  zerado ficam em `devedores_contatos` com `documento` NULL (o teste `gama_linhas_representadas`
  confere).
#}
{{ config(severity='warn') }}

SELECT
  _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    WHEN documento = 'documento' THEN 'cabeçalho repetido'
    ELSE 'documento vazio ou zerado'
  END AS motivo
FROM {{ source('bronze_gama', 'devedores') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR {{ cpf_normalizado('documento') }} IS NULL
  )
