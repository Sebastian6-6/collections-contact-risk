{#
  Todo `contato_id` de `contatos_realizados` tem ao menos um provedor em
  `contatos_realizados_provedores`. Cada linha devolvida é um contato sem provedor (o texto
  `provedor_origem` veio vazio ou só com separadores).
#}
SELECT c.contato_id
FROM {{ ref('silver_cobranca_contatos_realizados') }} AS c
LEFT JOIN {{ ref('silver_cobranca_contatos_realizados_provedores') }} AS p
  ON c.contato_id = p.contato_id
WHERE 1 = 1
  AND p.contato_id IS NULL
