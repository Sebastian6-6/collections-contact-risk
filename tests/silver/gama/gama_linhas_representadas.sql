{#
  Toda linha da bronze do gama está representada na silver: o documento normalizado existe em
  `devedores` e cada telefone e e-mail preenchido, de lista válida, tem o par em
  `devedores_contatos`. A linha sem documento (vazio ou só zeros) não é devedor, mas seus
  contatos têm o par com `documento` NULL. As listas são abertas de novo aqui, direto da bronze,
  sem passar pela etapa padronizada. Cada endereço preenchido de cada linha legível (fora o
  cabeçalho repetido) tem o par em `devedores_enderecos`, achado pelo mesmo `hash_endereco`
  (macro `hash_conteudo`, oito posições), inclusive com `documento` NULL. Toda linha legível (fora
  o cabeçalho repetido) tem em `devedores_historico` uma versão com os mesmos campos simples,
  comparados com `IS NOT DISTINCT FROM`; a lista de contatos fica de fora dessa conferência (o
  teste dos contatos acima a cobre). Cada linha devolvida é um documento, um contato, um endereço
  ou uma versão (`tipo_contato` = `versao`) que a silver perdeu, ou um contato de tipo que a
  silver não conhece.
#}
{%- set partes_do_endereco = [
  'logradouro', 'numero', 'endereco_json_complemento', 'bairro', 'cidade', 'uf', 'cep'
  , 'endereco_sem_partes'
] -%}

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
)

, tContatos AS (
  SELECT DISTINCT
    documento
    , 'telefone' AS tipo_contato
    , {{ telefone_normalizado('valor_origem') }} AS contato
  FROM tElementos
  WHERE 1 = 1
    AND tipo_origem IN ('celular', 'fixo')

  UNION ALL

  SELECT DISTINCT
    documento
    , 'email' AS tipo_contato
    , {{ email_normalizado('valor_origem') }} AS contato
  FROM tElementos
  WHERE 1 = 1
    AND tipo_origem = 'email'
)

, tTiposDesconhecidos AS (
  SELECT DISTINCT
    documento
    , tipo_origem AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM tElementos
  WHERE 1 = 1
    AND tipo_origem IS DISTINCT FROM 'email'
    AND tipo_origem NOT IN ('celular', 'fixo')
)

, tDocumentosPerdidos AS (
  SELECT DISTINCT
    o.documento
    , CAST(NULL AS VARCHAR) AS tipo_contato
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
    , b.tipo_contato
    , b.contato
  FROM tContatos AS b
  LEFT JOIN {{ ref('silver_gama_devedores_contatos') }} AS s
    ON b.documento IS NOT DISTINCT FROM s.documento
      AND b.tipo_contato = s.tipo_contato
      AND b.contato = s.contato
  WHERE 1 = 1
    AND b.contato IS NOT NULL
    AND s.contato IS NULL
)

, tLinhasLegiveis AS (
  SELECT
    p.documento
    , p.nome
    , p.data_nascimento
    , p.cnpj_empregador_raw
    , p.atributos_extra_estado_civil
    , p.atributos_extra_qtd_dependentes
    , p.atributos_extra_score_externo
    , p.atributos_extra_escolaridade
    , p.atributos_extra_possui_imovel
    , p.atributos_extra_fonte_score
    , p.endereco
    , p.logradouro
    , p.numero
    , p.endereco_json_complemento
    , p.bairro
    , p.cidade
    , p.uf
    , p.cep
    , p.dt_ref
    , CASE
      WHEN p.logradouro IS NULL
        AND p.numero IS NULL
        AND p.endereco_json_complemento IS NULL
        AND p.bairro IS NULL
        AND p.cidade IS NULL
        AND p.uf IS NULL
        AND p.cep IS NULL THEN p.endereco
    END AS endereco_sem_partes
  FROM {{ ref('silver_gama_devedores_padronizados') }} AS p
  INNER JOIN {{ source('bronze_gama', 'devedores') }} AS b
    ON p._arquivo = b._arquivo
      AND p._linha = b._linha
  LEFT JOIN {{ source('bronze_gama', 'arquivos') }} AS a
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
    AND COALESCE(
      endereco, logradouro, numero, endereco_json_complemento, bairro, cidade, uf, cep
    ) IS NOT NULL
)

, tEnderecosPerdidos AS (
  SELECT
    b.documento
    , CAST(NULL AS VARCHAR) AS tipo_contato
    , CAST(NULL AS VARCHAR) AS contato
  FROM tEnderecos AS b
  LEFT JOIN {{ ref('silver_gama_devedores_enderecos') }} AS s
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
  LEFT JOIN {{ ref('silver_gama_devedores_historico') }} AS h
    ON l.documento IS NOT DISTINCT FROM h.documento
      AND l.nome IS NOT DISTINCT FROM h.nome
      AND l.data_nascimento IS NOT DISTINCT FROM h.data_nascimento
      AND l.cnpj_empregador_raw IS NOT DISTINCT FROM h.cnpj_empregador_raw
      AND l.atributos_extra_estado_civil IS NOT DISTINCT FROM h.atributos_extra_estado_civil
      AND l.atributos_extra_qtd_dependentes IS NOT DISTINCT FROM h.atributos_extra_qtd_dependentes
      AND l.atributos_extra_score_externo IS NOT DISTINCT FROM h.atributos_extra_score_externo
      AND l.atributos_extra_escolaridade IS NOT DISTINCT FROM h.atributos_extra_escolaridade
      AND l.atributos_extra_possui_imovel IS NOT DISTINCT FROM h.atributos_extra_possui_imovel
      AND l.atributos_extra_fonte_score IS NOT DISTINCT FROM h.atributos_extra_fonte_score
      AND l.endereco IS NOT DISTINCT FROM h.endereco
      AND l.logradouro IS NOT DISTINCT FROM h.logradouro
      AND l.numero IS NOT DISTINCT FROM h.numero
      AND l.endereco_json_complemento IS NOT DISTINCT FROM h.endereco_json_complemento
      AND l.bairro IS NOT DISTINCT FROM h.bairro
      AND l.cidade IS NOT DISTINCT FROM h.cidade
      AND l.uf IS NOT DISTINCT FROM h.uf
      AND l.cep IS NOT DISTINCT FROM h.cep
      AND l.dt_ref IS NOT DISTINCT FROM h.dt_ref
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
FROM tTiposDesconhecidos

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
