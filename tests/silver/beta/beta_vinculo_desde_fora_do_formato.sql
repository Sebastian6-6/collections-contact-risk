{#
  O início do vínculo do beta vem como mês, `AAAA-MM`. Um valor preenchido em outro formato (ou um
  mês inexistente) vira NULL em `vinculo_empresa_desde`, e nenhum outro teste conta esses NULL. Só avisa
  (`warn`): cada linha devolvida é uma linha da bronze com `vinculo_empresa.desde` preenchido que a
  silver não conseguiu ler como mês.
#}
{{ config(severity='warn') }}

WITH tOrigem AS (
  SELECT
    _arquivo
    , _linha
    , {{ json_ou_nulo('registro') }} AS registro_json
  FROM {{ source('bronze_beta', 'devedores') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tDesde AS (
  SELECT
    _arquivo
    , _linha
    , NULLIF(TRIM((registro_json -> 'vinculo_empresa') ->> 'desde'), '') AS desde
  FROM tOrigem
  WHERE 1 = 1
    AND registro_json IS NOT NULL
)

SELECT
  _arquivo
  , _linha
  , desde
FROM tDesde
WHERE 1 = 1
  AND desde IS NOT NULL
  AND {{ mes_como_data('desde') }} IS NULL
