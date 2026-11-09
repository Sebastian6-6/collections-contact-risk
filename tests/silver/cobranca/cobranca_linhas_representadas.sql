{#
  Toda linha da bronze da cobrança com chave está representada na silver: o `contato_id` existe
  em `contatos_realizados` e cada provedor do `provedor_origem` tem a linha em
  `contatos_realizados_provedores`. Os provedores são abertos de novo aqui, direto da bronze.
  Cada linha devolvida é um contato ou um par contato e provedor que a silver perdeu.
#}
WITH tOrigem AS (
  SELECT
    NULLIF(TRIM(contato_id), '') AS contato_id
    , NULLIF(LOWER(TRIM(provedor_origem)), '') AS provedor_origem
  FROM {{ source('bronze_cobranca', 'contatos_realizados') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tPares AS (
  SELECT DISTINCT
    o.contato_id
    , NULLIF(TRIM(p.provedor), '') AS provedor
  FROM tOrigem AS o
  CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(o.provedor_origem, '|')) AS p (provedor)
  WHERE 1 = 1
    AND o.contato_id IS NOT NULL
)

, tContatosPerdidos AS (
  SELECT DISTINCT
    o.contato_id
    , CAST(NULL AS VARCHAR) AS provedor
  FROM tOrigem AS o
  LEFT JOIN {{ ref('silver_cobranca_contatos_realizados') }} AS s
    ON o.contato_id = s.contato_id
  WHERE 1 = 1
    AND o.contato_id IS NOT NULL
    AND s.contato_id IS NULL
)

, tParesPerdidos AS (
  SELECT
    b.contato_id
    , b.provedor
  FROM tPares AS b
  LEFT JOIN {{ ref('silver_cobranca_contatos_realizados_provedores') }} AS s
    ON b.contato_id = s.contato_id
      AND b.provedor = s.provedor
  WHERE 1 = 1
    AND b.provedor IS NOT NULL
    AND s.contato_id IS NULL
)

SELECT
  contato_id
  , provedor
FROM tContatosPerdidos

UNION ALL

SELECT
  contato_id
  , provedor
FROM tParesPerdidos
