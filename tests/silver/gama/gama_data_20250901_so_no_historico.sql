{#
  A data 01/09/2025 em `dt_ref` aparece só no arquivo histórico (372 linhas, medido em
  2026-11-09): é o coorte da data padrão, que a silver mantém como veio e a gold trata. Se ela
  passar a aparecer numa entrega diária, o provedor mudou o comportamento e o contrato precisa
  ser revisto. Só avisa (`warn`); cada linha devolvida é uma linha de entrega diária com essa data.
#}
{{ config(severity='warn') }}

SELECT
  _arquivo
  , _linha
  , data_atualizacao
FROM {{ ref('silver_gama_devedores_padronizados') }}
WHERE 1 = 1
  AND data_atualizacao = CAST('2025-09-01' AS DATE)
  AND _arquivo LIKE '%entregas_diarias%'
