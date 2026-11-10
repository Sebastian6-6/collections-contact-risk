{#
  Toda linha da bronze do alfa está representada na silver: o documento normalizado existe em
  `devedores`, e cada contato preenchido tem o par em `devedores_contatos`. A linha sem documento
  (vazio ou só zeros) não é devedor, mas seus contatos têm o par com `documento` NULL. Cada
  endereço preenchido de cada linha legível (fora o cabeçalho repetido) tem o par em
  `devedores_enderecos`, achado pelo mesmo `hash_endereco` (macro `hash_conteudo`, oito posições),
  inclusive com `documento` NULL. Toda linha legível (fora o cabeçalho repetido) tem em
  `devedores_historico` uma versão com os mesmos campos simples, comparados com
  `IS NOT DISTINCT FROM`; no alfa não há listas. Cada linha devolvida é um documento, um contato,
  um endereço ou uma versão (`tipo_contato` = `versao`) que a silver perdeu.
#}
{%- set partes_do_endereco = [
  'logradouro', 'numero', 'complemento', 'bairro', 'cidade', 'uf', 'cep', 'endereco_sem_partes'
] -%}
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
    ON b.documento IS NOT DISTINCT FROM s.documento
      AND b.tipo_contato = s.tipo_contato
      AND b.contato = s.contato
  WHERE 1 = 1
    AND s.contato IS NULL
)

, tLinhasLegiveis AS (
  SELECT
    p.documento
    , p.nome_completo
    , p.data_nascimento
    , p.cnpj_empregador
    , p.cargo
    , p.salario_informado
    , p.telefone
    , p.email
    , p.endereco
    , p.logradouro
    , p.numero
    , p.complemento
    , p.bairro
    , p.cidade
    , p.cep
    , p.uf
    , p.data_atualizacao
    , CASE
      WHEN p.logradouro IS NULL
        AND p.numero IS NULL
        AND p.complemento IS NULL
        AND p.bairro IS NULL
        AND p.cidade IS NULL
        AND p.uf IS NULL
        AND p.cep IS NULL THEN p.endereco
    END AS endereco_sem_partes
  FROM {{ ref('silver_alfa_devedores_padronizados') }} AS p
  INNER JOIN {{ source('bronze_alfa', 'devedores') }} AS b
    ON p._arquivo = b._arquivo
      AND p._linha = b._linha
  LEFT JOIN {{ source('bronze_alfa', 'arquivos') }} AS a
    ON p._arquivo = a.arquivo
  WHERE 1 = 1
    AND NOT COALESCE(b._linha_original = a.cabecalho, FALSE)
)

, tEnderecos AS (
  SELECT DISTINCT
    documento
    , {{ hash_conteudo(partes_do_endereco) }} AS hash_endereco
  FROM tLinhasLegiveis
  WHERE 1 = 1
    AND COALESCE(endereco, logradouro, numero, complemento, bairro, cidade, uf, cep) IS NOT NULL
)

, tEnderecosPerdidos AS (
  SELECT
    b.documento
    , CAST(NULL AS VARCHAR) AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM tEnderecos AS b
  LEFT JOIN {{ ref('silver_alfa_devedores_enderecos') }} AS s
    ON b.documento IS NOT DISTINCT FROM s.documento
      AND b.hash_endereco = s.hash_endereco
  WHERE 1 = 1
    AND s.hash_endereco IS NULL
)

, tVersoesPerdidas AS (
  SELECT DISTINCT
    l.documento
    , 'versao' AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM tLinhasLegiveis AS l
  LEFT JOIN {{ ref('silver_alfa_devedores_historico') }} AS h
    ON l.documento IS NOT DISTINCT FROM h.documento
      AND l.nome_completo IS NOT DISTINCT FROM h.nome_completo
      AND l.data_nascimento IS NOT DISTINCT FROM h.data_nascimento
      AND l.cnpj_empregador IS NOT DISTINCT FROM h.cnpj_empregador
      AND l.cargo IS NOT DISTINCT FROM h.cargo
      AND l.salario_informado IS NOT DISTINCT FROM h.salario_informado
      AND l.telefone IS NOT DISTINCT FROM h.telefone
      AND l.email IS NOT DISTINCT FROM h.email
      AND l.endereco IS NOT DISTINCT FROM h.endereco
      AND l.logradouro IS NOT DISTINCT FROM h.logradouro
      AND l.numero IS NOT DISTINCT FROM h.numero
      AND l.complemento IS NOT DISTINCT FROM h.complemento
      AND l.bairro IS NOT DISTINCT FROM h.bairro
      AND l.cidade IS NOT DISTINCT FROM h.cidade
      AND l.cep IS NOT DISTINCT FROM h.cep
      AND l.uf IS NOT DISTINCT FROM h.uf
      AND l.data_atualizacao IS NOT DISTINCT FROM h.data_atualizacao
  WHERE 1 = 1
    AND h.hash_conteudo IS NULL
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

UNION ALL

SELECT
  documento
  , tipo_contato
  , contato
FROM tEnderecosPerdidos

UNION ALL

SELECT
  documento
  , tipo_contato
  , contato
FROM tVersoesPerdidas
