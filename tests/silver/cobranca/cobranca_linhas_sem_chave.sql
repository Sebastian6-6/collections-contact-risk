{#
  Linhas da bronze da cobrança que ficam fora da silver por não terem chave (S9): linha ilegível
  ou `contato_id` vazio. Só avisa (`warn`): cada linha devolvida continua na bronze.
#}
{{ config(severity='warn') }}

SELECT
  _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'sem contato_id'
  END AS motivo
FROM {{ source('bronze_cobranca', 'contatos_realizados') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(contato_id), '') IS NULL
  )
