{#
  O vínculo `atual` é o período que contém a única versão vigente do devedor (G3b), então cada
  devedor tem no máximo um. Cada linha devolvida é um devedor com mais de um período atual.
#}
SELECT
  sk_devedor
  , COUNT(*) AS qt_vinculos_atuais
FROM {{ ref('ft_vinculo_empresa') }}
WHERE 1 = 1
  AND situacao_vinculo = 'atual'
  AND sk_devedor IS NOT NULL
GROUP BY sk_devedor
HAVING COUNT(*) > 1
