{#
  Toda linha da bronze do beta com JSON válido está representada na silver: o documento existe
  em `devedores`, cada telefone e e-mail preenchido tem o par em `devedores_contatos` (com
  `documento_tipo` e `documento` NULL quando a linha não tem documento, vazio ou só zeros, e
  então não é devedor) e a versão
  atual de cada devedor tem em `devedores_enderecos` tantos endereços quanto a lista dela traz.
  As listas são abertas de novo aqui, a partir da etapa padronizada, sem passar pelos modelos
  testados. Cada linha devolvida é um documento, um contato ou um grupo de endereços que a
  silver perdeu ou duplicou.
#}
WITH tTelefones AS (
  SELECT DISTINCT
    p.documento_tipo
    , p.documento
    , 'telefone' AS tipo_contato
    , {{ telefone_de_elemento_json('t.valor') }} AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_telefones', 't') }}
)

, tEmails AS (
  SELECT DISTINCT
    p.documento_tipo
    , p.documento
    , 'email' AS tipo_contato
    , {{ email_normalizado(json_texto('e.valor')) }} AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_emails', 'e') }}
)

, tContatos AS (
  SELECT
    documento_tipo
    , documento
    , tipo_contato
    , contato
  FROM tTelefones

  UNION

  SELECT
    documento_tipo
    , documento
    , tipo_contato
    , contato
  FROM tEmails

  UNION

  SELECT
    documento_tipo
    , documento
    , 'email' AS tipo_contato
    , email_unico AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }}
)

, tDocumentosPerdidos AS (
  SELECT DISTINCT
    p.documento_tipo
    , p.documento
    , CAST(NULL AS VARCHAR) AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  LEFT JOIN {{ ref('silver_beta_devedores') }} AS d
    ON p.documento_tipo = d.documento_tipo
      AND p.documento = d.documento
  WHERE 1 = 1
    AND p.documento IS NOT NULL
    AND d.documento IS NULL
)

, tContatosPerdidos AS (
  SELECT
    b.documento_tipo
    , b.documento
    , b.tipo_contato
    , b.contato
  FROM tContatos AS b
  LEFT JOIN {{ ref('silver_beta_devedores_contatos') }} AS s
    ON b.documento_tipo IS NOT DISTINCT FROM s.documento_tipo
      AND b.documento IS NOT DISTINCT FROM s.documento
      AND b.tipo_contato = s.tipo_contato
      AND b.contato = s.contato
  WHERE 1 = 1
    AND b.contato IS NOT NULL
    AND s.contato IS NULL
)

, tEnderecosDaVersaoAtual AS (
  SELECT
    d.documento_tipo
    , d.documento
    , 1 AS qt_enderecos
  FROM {{ ref('silver_beta_devedores') }} AS d
  INNER JOIN {{ ref('silver_beta_devedores_padronizados') }} AS p
    ON d._arquivo = p._arquivo
      AND d._linha = p._linha
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_enderecos', 'l') }}

  UNION ALL

  SELECT
    d.documento_tipo
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
    documento_tipo
    , documento
    , SUM(qt_enderecos) AS qt_enderecos
  FROM tEnderecosDaVersaoAtual
  GROUP BY
    documento_tipo
    , documento
)

, tEnderecosSilver AS (
  SELECT
    documento_tipo
    , documento
    , COUNT(*) AS qt_enderecos
  FROM {{ ref('silver_beta_devedores_enderecos') }}
  GROUP BY
    documento_tipo
    , documento
)

, tEnderecosDivergentes AS (
  SELECT
    e.documento_tipo
    , e.documento
    , CAST(NULL AS VARCHAR) AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM tEnderecosEsperados AS e
  LEFT JOIN tEnderecosSilver AS s
    ON e.documento_tipo = s.documento_tipo
      AND e.documento = s.documento
  WHERE 1 = 1
    AND e.qt_enderecos IS DISTINCT FROM s.qt_enderecos

  UNION ALL

  SELECT
    s.documento_tipo
    , s.documento
    , CAST(NULL AS VARCHAR) AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM tEnderecosSilver AS s
  LEFT JOIN tEnderecosEsperados AS e
    ON s.documento_tipo = e.documento_tipo
      AND s.documento = e.documento
  WHERE 1 = 1
    AND e.documento IS NULL
)

SELECT
  documento_tipo
  , documento
  , tipo_contato
  , contato
FROM tDocumentosPerdidos

UNION ALL

SELECT
  documento_tipo
  , documento
  , tipo_contato
  , contato
FROM tContatosPerdidos

UNION ALL

SELECT
  documento_tipo
  , documento
  , tipo_contato
  , contato
FROM tEnderecosDivergentes
