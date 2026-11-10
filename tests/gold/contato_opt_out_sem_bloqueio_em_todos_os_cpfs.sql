{#
  O `opt_out` bloqueia o contato para todos os CPFs ligados a ele (G5): quem pediu foi o titular do
  número. Cada linha devolvida é um par `liberado` ou `atencao` cujo contato tem `opt_out` em outro
  par.
#}
WITH tContatosComOptOut AS (
  SELECT DISTINCT
    tipo_contato
    , contato
  FROM {{ ref('dim_contato') }}
  WHERE 1 = 1
    AND tipo_alerta_historico = 'opt_out'
)

SELECT
  dim_contato.sk_contato
  , dim_contato.nivel_risco
FROM {{ ref('dim_contato') }} AS dim_contato
INNER JOIN tContatosComOptOut
  ON dim_contato.tipo_contato = tContatosComOptOut.tipo_contato
    AND dim_contato.contato = tContatosComOptOut.contato
WHERE 1 = 1
  AND dim_contato.nivel_risco <> 'bloqueado'
