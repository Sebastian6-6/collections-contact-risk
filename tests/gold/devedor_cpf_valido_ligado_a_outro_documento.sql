{#
  Um CPF com dígito verificador certo é um devedor por si e nunca se liga a outro documento
  (G3a'). Cada linha devolvida é um CPF válido cujo devedor não é ele mesmo.
#}
SELECT
  documento_tipo
  , documento
  , cpf
FROM {{ ref('devedores_documentos') }}
WHERE 1 = 1
  AND documento_tipo = 'CPF'
  AND {{ cpf_valido('documento') }}
  AND cpf IS DISTINCT FROM documento
