{#
  O `falecido` em qualquer contato do devedor bloqueia todos os pares dele (G5). Cada linha devolvida
  é um par `liberado` ou `atencao` de um devedor que tem outro par com alerta `falecido`.
#}
WITH tDevedoresFalecidos AS (
  SELECT DISTINCT sk_devedor
  FROM {{ ref('dim_contato') }}
  WHERE 1 = 1
    AND tipo_alerta_historico = 'falecido'
    AND sk_devedor IS NOT NULL
)

SELECT
  dim_contato.sk_contato
  , dim_contato.nivel_risco
FROM {{ ref('dim_contato') }} AS dim_contato
INNER JOIN tDevedoresFalecidos
  ON dim_contato.sk_devedor = tDevedoresFalecidos.sk_devedor
WHERE 1 = 1
  AND dim_contato.nivel_risco <> 'bloqueado'
