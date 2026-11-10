{#
  Aviso com a contagem dos documentos ligados a um devedor por correção de dígito do CPF ou por
  RG (G3a'): cada linha devolvida é um documento ligado, e o número de linhas é a contagem. O
  detalhe por caso e por provedor sai de `devedores_registros` com esta mesma ligação e vai para o
  README. A ligação é regra do projeto, e não defeito: o aviso só deixa o número visível.
#}
{{ config(severity='warn') }}

SELECT
  documento_tipo
  , documento
  , cpf
  , situacao_documento
FROM {{ ref('devedores_documentos') }}
WHERE 1 = 1
  AND situacao_documento IN ('cpf_corrigido', 'rg_por_nome_nascimento')
