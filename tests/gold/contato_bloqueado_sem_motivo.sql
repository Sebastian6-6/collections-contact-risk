{#
  Todo contato fora do nível `liberado` tem motivo (G4a): `desc_motivo_risco` diz por que o par não
  é liberado, e só o `liberado` traz "sem sinal de risco". Cada linha devolvida é um par `atencao`
  ou `bloqueado` sem motivo, ou `liberado` com motivo.
#}
SELECT
  sk_contato
  , nivel_risco
  , desc_motivo_risco
FROM {{ ref('dim_contato') }}
WHERE 1 = 1
  AND (
    (
      nivel_risco <> 'liberado'
      AND (desc_motivo_risco IS NULL OR desc_motivo_risco = 'sem sinal de risco')
    )
    OR (nivel_risco = 'liberado' AND desc_motivo_risco <> 'sem sinal de risco')
  )
