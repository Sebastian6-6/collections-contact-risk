{#
  Toda linha da bronze do alfa com chave está representada na silver: o documento normalizado
  existe em `devedores`, e cada contato preenchido tem o par em `devedores_contatos`. Cada linha
  devolvida é um documento ou um contato que a silver perdeu.
#}
{%- set documento_origem = "COALESCE(NULLIF(TRIM(cpf), ''), NULLIF(TRIM(documento), ''))" -%}

WITH tOrigem AS (
  SELECT
    {{ cpf_normalizado(documento_origem) }} AS documento
    , {{ telefone_normalizado('telefone') }} AS telefone
    , {{ email_normalizado('email') }} AS email
  FROM {{ source('bronze_alfa', 'devedores') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tContatos AS (
  SELECT DISTINCT
    documento
    , 'telefone' AS tipo_contato
    , telefone AS contato
  FROM tOrigem
  WHERE 1 = 1
    AND telefone IS NOT NULL

  UNION ALL

  SELECT DISTINCT
    documento
    , 'email' AS tipo_contato
    , email AS contato
  FROM tOrigem
  WHERE 1 = 1
    AND email IS NOT NULL
)

, tDocumentosPerdidos AS (
  SELECT DISTINCT
    o.documento
    , CAST(NULL AS VARCHAR) AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM tOrigem AS o
  LEFT JOIN {{ ref('silver_alfa_devedores') }} AS d
    ON o.documento = d.documento
  WHERE 1 = 1
    AND o.documento IS NOT NULL
    AND d.documento IS NULL
)

, tContatosPerdidos AS (
  SELECT
    b.documento
    , b.tipo_contato
    , b.contato
  FROM tContatos AS b
  LEFT JOIN {{ ref('silver_alfa_devedores_contatos') }} AS s
    ON b.documento = s.documento
      AND b.tipo_contato = s.tipo_contato
      AND b.contato = s.contato
  WHERE 1 = 1
    AND b.documento IS NOT NULL
    AND s.documento IS NULL
)

SELECT
  documento
  , tipo_contato
  , contato
FROM tDocumentosPerdidos

UNION ALL

SELECT
  documento
  , tipo_contato
  , contato
FROM tContatosPerdidos
