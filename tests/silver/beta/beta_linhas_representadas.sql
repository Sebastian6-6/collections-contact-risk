{#
  Toda linha da bronze do beta com chave está representada na silver: o documento existe em
  `devedores`, cada telefone e e-mail preenchido tem o par em `devedores_contatos` e a versão
  atual de cada devedor tem em `devedores_enderecos` tantos endereços quanto a lista dela traz.
  As listas são abertas de novo aqui, a partir da etapa padronizada, sem passar pelos modelos
  testados. Cada linha devolvida é um documento, um contato ou um grupo de endereços que a
  silver perdeu ou duplicou.
#}
WITH tTelefones AS (
  SELECT DISTINCT
    p.tipo_documento
    , p.documento
    , 'telefone' AS tipo
    , {{ telefone_de_elemento_json('t.valor') }} AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_telefones', 't') }}
)

, tEmails AS (
  SELECT DISTINCT
    p.tipo_documento
    , p.documento
    , 'email' AS tipo
    , {{ email_normalizado(json_texto('e.valor')) }} AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_emails', 'e') }}
)

, tContatos AS (
  SELECT
    tipo_documento
    , documento
    , tipo
    , contato
  FROM tTelefones

  UNION

  SELECT
    tipo_documento
    , documento
    , tipo
    , contato
  FROM tEmails

  UNION

  SELECT
    tipo_documento
    , documento
    , 'email' AS tipo
    , email_unico AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }}
)

, tDocumentosPerdidos AS (
  SELECT DISTINCT
    p.tipo_documento
    , p.documento
    , CAST(NULL AS VARCHAR) AS tipo
    , CAST(NULL AS VARCHAR) AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  LEFT JOIN {{ ref('silver_beta_devedores') }} AS d
    ON p.tipo_documento = d.tipo_documento
      AND p.documento = d.documento
  WHERE 1 = 1
    AND d.documento IS NULL
)

, tContatosPerdidos AS (
  SELECT
    b.tipo_documento
    , b.documento
    , b.tipo
    , b.contato
  FROM tContatos AS b
  LEFT JOIN {{ ref('silver_beta_devedores_contatos') }} AS s
    ON b.tipo_documento = s.tipo_documento
      AND b.documento = s.documento
      AND b.tipo = s.tipo
      AND b.contato = s.contato
  WHERE 1 = 1
    AND b.contato IS NOT NULL
    AND s.documento IS NULL
)

, tEnderecosDaVersaoAtual AS (
  SELECT
    d.tipo_documento
    , d.documento
    , 1 AS qt_enderecos
  FROM {{ ref('silver_beta_devedores') }} AS d
  INNER JOIN {{ ref('silver_beta_devedores_padronizados') }} AS p
    ON d._arquivo = p._arquivo
      AND d._linha = p._linha
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_enderecos', 'l') }}

  UNION ALL

  SELECT
    d.tipo_documento
    , d.documento
    , 1 AS qt_enderecos
  FROM {{ ref('silver_beta_devedores') }} AS d
  INNER JOIN {{ ref('silver_beta_devedores_padronizados') }} AS p
    ON d._arquivo = p._arquivo
      AND d._linha = p._linha
  WHERE 1 = 1
    AND p.endereco_unico IS NOT NULL
)

, tEnderecosEsperados AS (
  SELECT
    tipo_documento
    , documento
    , SUM(qt_enderecos) AS qt_enderecos
  FROM tEnderecosDaVersaoAtual
  GROUP BY
    tipo_documento
    , documento
)

, tEnderecosSilver AS (
  SELECT
    tipo_documento
    , documento
    , COUNT(*) AS qt_enderecos
  FROM {{ ref('silver_beta_devedores_enderecos') }}
  GROUP BY
    tipo_documento
    , documento
)

, tEnderecosDivergentes AS (
  SELECT
    e.tipo_documento
    , e.documento
    , CAST(NULL AS VARCHAR) AS tipo
    , CAST(NULL AS VARCHAR) AS contato
  FROM tEnderecosEsperados AS e
  LEFT JOIN tEnderecosSilver AS s
    ON e.tipo_documento = s.tipo_documento
      AND e.documento = s.documento
  WHERE 1 = 1
    AND e.qt_enderecos IS DISTINCT FROM s.qt_enderecos

  UNION ALL

  SELECT
    s.tipo_documento
    , s.documento
    , CAST(NULL AS VARCHAR) AS tipo
    , CAST(NULL AS VARCHAR) AS contato
  FROM tEnderecosSilver AS s
  LEFT JOIN tEnderecosEsperados AS e
    ON s.tipo_documento = e.tipo_documento
      AND s.documento = e.documento
  WHERE 1 = 1
    AND e.documento IS NULL
)

SELECT
  tipo_documento
  , documento
  , tipo
  , contato
FROM tDocumentosPerdidos

UNION ALL

SELECT
  tipo_documento
  , documento
  , tipo
  , contato
FROM tContatosPerdidos

UNION ALL

SELECT
  tipo_documento
  , documento
  , tipo
  , contato
FROM tEnderecosDivergentes
