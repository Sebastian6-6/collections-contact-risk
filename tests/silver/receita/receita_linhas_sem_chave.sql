{#
  Linhas da bronze da Receita que ficam fora da silver por não terem chave: linha ilegível ou chave
  vazia. Só avisa (`warn`): cada linha devolvida continua na bronze. A chave de `estabelecimentos` é
  o CNPJ montado de base, ordem e dígitos; a de `socios`, a base e o identificador de sócio; a de
  `empresas` e `simples`, a base; a dos domínios, o código.
#}
{{ config(severity='warn') }}

SELECT
  'empresas' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'empresas') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(cnpj_basico), '') IS NULL
  )

UNION ALL

SELECT
  'estabelecimentos' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'estabelecimentos') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(cnpj_basico), '') IS NULL
    OR NULLIF(TRIM(cnpj_ordem), '') IS NULL
    OR NULLIF(TRIM(cnpj_dv), '') IS NULL
  )

UNION ALL

SELECT
  'simples' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'simples') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(cnpj_basico), '') IS NULL
  )

UNION ALL

SELECT
  'socios' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'socios') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(cnpj_basico), '') IS NULL
    OR NULLIF(TRIM(identificador_de_socio), '') IS NULL
  )

UNION ALL

SELECT
  'cnaes' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'cnaes') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(codigo), '') IS NULL
  )

UNION ALL

SELECT
  'motivos' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'motivos') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(codigo), '') IS NULL
  )

UNION ALL

SELECT
  'municipios' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'municipios') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(codigo), '') IS NULL
  )

UNION ALL

SELECT
  'naturezas' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'naturezas') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(codigo), '') IS NULL
  )

UNION ALL

SELECT
  'paises' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'paises') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(codigo), '') IS NULL
  )

UNION ALL

SELECT
  'qualificacoes' AS entidade
  , _arquivo
  , _linha
  , CASE
    WHEN _motivo_ilegivel IS NOT NULL THEN 'ilegível'
    ELSE 'chave vazia'
  END AS motivo
FROM {{ source('bronze_receita', 'qualificacoes') }}
WHERE 1 = 1
  AND (
    _motivo_ilegivel IS NOT NULL
    OR NULLIF(TRIM(codigo), '') IS NULL
  )
