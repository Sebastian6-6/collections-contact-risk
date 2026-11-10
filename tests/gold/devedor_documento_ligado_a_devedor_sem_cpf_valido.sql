{#
  Todo documento ligado por correção de dígito ou por RG aponta para um devedor de CPF válido
  que existe na `dim_devedor` (G3a'). Cada linha devolvida é um documento ligado a um CPF que
  não está na dimensão ou que não é válido.
#}
SELECT
  devedores_documentos.documento_tipo
  , devedores_documentos.documento
  , devedores_documentos.cpf
  , dim_devedor.situacao_cpf
FROM {{ ref('devedores_documentos') }} AS devedores_documentos
LEFT JOIN {{ ref('dim_devedor') }} AS dim_devedor
  ON devedores_documentos.cpf = dim_devedor.cpf
WHERE 1 = 1
  AND devedores_documentos.situacao_documento IN ('cpf_corrigido', 'rg_por_nome_nascimento')
  AND dim_devedor.situacao_cpf IS DISTINCT FROM 'valido'
