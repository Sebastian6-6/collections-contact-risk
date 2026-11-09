{#
  Grão: uma linha por (tipo de documento, documento, posição do endereço na lista) da versão
  atual do devedor (a mesma de `silver_beta_devedores`). O beta manda o endereço como lista
  (`enderecos`) ou como um objeto só (`endereco`); o objeto vira a posição 1. O `atual` fica como
  veio (S7): nenhuma regra escolhe o endereço vigente aqui.
#}
WITH tListas AS (
  SELECT
    d.tipo_documento
    , d.documento
    , CAST(l.posicao AS INTEGER) AS posicao
    , l.valor AS endereco_json
    , d._arquivo
    , d._linha
    , d._hash_arquivo
  FROM {{ ref('silver_beta_devedores') }} AS d
  INNER JOIN {{ ref('silver_beta_devedores_padronizados') }} AS p
    ON d._arquivo = p._arquivo
      AND d._linha = p._linha
  CROSS JOIN LATERAL {{ json_abrir_lista('p.lista_enderecos', 'l') }}
)

, tUnicos AS (
  SELECT
    d.tipo_documento
    , d.documento
    , CAST(1 AS INTEGER) AS posicao
    , p.endereco_unico AS endereco_json
    , d._arquivo
    , d._linha
    , d._hash_arquivo
  FROM {{ ref('silver_beta_devedores') }} AS d
  INNER JOIN {{ ref('silver_beta_devedores_padronizados') }} AS p
    ON d._arquivo = p._arquivo
      AND d._linha = p._linha
  WHERE 1 = 1
    AND p.endereco_unico IS NOT NULL
)

, tEnderecos AS (
  SELECT
    tipo_documento
    , documento
    , posicao
    , endereco_json
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tListas

  UNION ALL

  SELECT
    tipo_documento
    , documento
    , posicao
    , endereco_json
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tUnicos
)

SELECT
  tipo_documento
  , documento
  , posicao
  , NULLIF(TRIM(endereco_json ->> 'tipo'), '') AS tipo
  , NULLIF(TRIM(endereco_json ->> 'logradouro'), '') AS logradouro
  , NULLIF(TRIM(endereco_json ->> 'numero'), '') AS numero
  , NULLIF(TRIM(endereco_json ->> 'complemento'), '') AS complemento
  , NULLIF(TRIM(endereco_json ->> 'bairro'), '') AS bairro
  , NULLIF(TRIM(endereco_json ->> 'cidade'), '') AS cidade
  , NULLIF(TRIM(endereco_json ->> 'uf'), '') AS uf
  , LPAD({{ somente_digitos("endereco_json ->> 'cep'") }}, 8, '0') AS cep
  , CAST(endereco_json ->> 'atual' AS BOOLEAN) AS atual
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tEnderecos
