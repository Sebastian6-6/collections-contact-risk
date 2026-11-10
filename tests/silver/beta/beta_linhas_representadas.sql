{#
  Toda linha da bronze do beta com JSON válido está representada na silver: o documento existe
  em `devedores`, cada telefone e e-mail preenchido tem o par em `devedores_contatos` (com
  `documento_tipo` e `documento` NULL quando a linha não tem documento, vazio ou só zeros, e
  então não é devedor) e cada endereço de cada linha (partes padronizadas, na etapa
  `devedores_enderecos_padronizados`) tem o par com o documento em `devedores_enderecos`, mesmo
  quando o documento é NULL. As listas são abertas de novo aqui, a partir da etapa padronizada,
  sem passar pelos modelos testados. Cada linha devolvida é um documento, um contato ou um
  endereço que a silver perdeu.
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

, tEnderecosPerdidos AS (
  SELECT DISTINCT
    p.documento_tipo
    , p.documento
    , CAST(NULL AS VARCHAR) AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  INNER JOIN {{ ref('silver_beta_devedores_enderecos_padronizados') }} AS e
    ON p._arquivo = e._arquivo
      AND p._linha = e._linha
  LEFT JOIN {{ ref('silver_beta_devedores_enderecos') }} AS s
    ON p.documento_tipo IS NOT DISTINCT FROM s.documento_tipo
      AND p.documento IS NOT DISTINCT FROM s.documento
      AND e.logradouro IS NOT DISTINCT FROM s.logradouro
      AND e.numero IS NOT DISTINCT FROM s.numero
      AND e.complemento IS NOT DISTINCT FROM s.complemento
      AND e.bairro IS NOT DISTINCT FROM s.bairro
      AND e.cidade IS NOT DISTINCT FROM s.cidade
      AND e.uf IS NOT DISTINCT FROM s.uf
      AND e.cep IS NOT DISTINCT FROM s.cep
  WHERE 1 = 1
    AND s.hash_endereco IS NULL
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
FROM tEnderecosPerdidos
