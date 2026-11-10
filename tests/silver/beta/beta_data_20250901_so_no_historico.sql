{#
  A data 2025-09-01 em `atualizado_em` aparece só no arquivo histórico (S3, decisão D8): é o
  coorte da data padrão, que a silver mantém como veio e a gold trata. Se ela passar a aparecer
  numa entrega diária, o provedor mudou o comportamento e o contrato precisa ser revisto. Só
  avisa (`warn`); cada linha devolvida é uma linha de entrega diária com essa data.
#}
{{ config(severity='warn') }}

SELECT
  _arquivo
  , _linha
  , atualizado_em
FROM {{ ref('silver_beta_devedores_padronizados') }}
WHERE 1 = 1
  AND atualizado_em = CAST('2025-09-01' AS DATE)
  AND _arquivo LIKE '%entregas_diarias%'
