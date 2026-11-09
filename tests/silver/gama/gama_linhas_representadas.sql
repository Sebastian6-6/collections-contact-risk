{#
  Toda linha da bronze do gama com chave está representada na silver: o documento normalizado
  existe em `devedores` e cada telefone e e-mail preenchido, de lista válida, tem o par em
  `devedores_contatos`. As listas são abertas de novo aqui, direto da bronze, sem passar pela
  etapa padronizada. Cada linha devolvida é um documento ou um contato que a silver perdeu, ou um
  contato de tipo que a silver não conhece.
#}
WITH tOrigem AS (
  SELECT
    {{ cpf_normalizado('documento') }} AS documento
    , {{ json_ou_nulo('contatos') }} AS lista_contatos
  FROM {{ source('bronze_gama', 'devedores') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tElementos AS (
  SELECT
    o.documento
    , c.valor ->> 'tipo' AS tipo_origem
    , c.valor ->> 'valor' AS valor_origem
  FROM tOrigem AS o
  CROSS JOIN LATERAL {{ json_abrir_lista('o.lista_contatos', 'c') }}
  WHERE 1 = 1
    AND o.documento IS NOT NULL
)

, tContatos AS (
  SELECT DISTINCT
    documento
    , 'telefone' AS tipo
    , {{ telefone_normalizado('valor_origem') }} AS contato
  FROM tElementos
  WHERE 1 = 1
    AND tipo_origem IN ('celular', 'fixo')

  UNION ALL

  SELECT DISTINCT
    documento
    , 'email' AS tipo
    , {{ email_normalizado('valor_origem') }} AS contato
  FROM tElementos
  WHERE 1 = 1
    AND tipo_origem = 'email'
)

, tTiposDesconhecidos AS (
  SELECT DISTINCT
    documento
    , tipo_origem AS tipo
    , CAST(NULL AS VARCHAR) AS contato
  FROM tElementos
  WHERE 1 = 1
    AND tipo_origem IS DISTINCT FROM 'email'
    AND tipo_origem NOT IN ('celular', 'fixo')
)

, tDocumentosPerdidos AS (
  SELECT DISTINCT
    o.documento
    , CAST(NULL AS VARCHAR) AS tipo
    , CAST(NULL AS VARCHAR) AS contato
  FROM tOrigem AS o
  LEFT JOIN {{ ref('silver_gama_devedores') }} AS d
    ON o.documento = d.documento
  WHERE 1 = 1
    AND o.documento IS NOT NULL
    AND d.documento IS NULL
)

, tContatosPerdidos AS (
  SELECT
    b.documento
    , b.tipo
    , b.contato
  FROM tContatos AS b
  LEFT JOIN {{ ref('silver_gama_devedores_contatos') }} AS s
    ON b.documento = s.documento
      AND b.tipo = s.tipo
      AND b.contato = s.contato
  WHERE 1 = 1
    AND b.contato IS NOT NULL
    AND s.documento IS NULL
)

SELECT
  documento
  , tipo
  , contato
FROM tDocumentosPerdidos

UNION ALL

SELECT
  documento
  , tipo
  , contato
FROM tContatosPerdidos

UNION ALL

SELECT
  documento
  , tipo
  , contato
FROM tTiposDesconhecidos
