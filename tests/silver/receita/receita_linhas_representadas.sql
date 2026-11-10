{#
  Toda linha legível da bronze da Receita com chave está representada na silver: o CNPJ de cada
  estabelecimento, a base de cada empresa e de cada linha do Simples, o código de cada domínio e,
  nos sócios, a combinação completa da chave. Cada linha devolvida é uma chave que a silver perdeu.
#}
SELECT
  'empresas' AS entidade
  , b.cnpj_basico AS chave
FROM {{ source('bronze_receita', 'empresas') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.cnpj_basico), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_empresas') }} AS s
    WHERE 1 = 1
      AND s.cnpj_basico = NULLIF(TRIM(b.cnpj_basico), '')
  )

UNION ALL

SELECT
  'simples' AS entidade
  , b.cnpj_basico AS chave
FROM {{ source('bronze_receita', 'simples') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.cnpj_basico), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_simples') }} AS s
    WHERE 1 = 1
      AND s.cnpj_basico = NULLIF(TRIM(b.cnpj_basico), '')
  )

UNION ALL

SELECT
  'cnaes' AS entidade
  , b.codigo AS chave
FROM {{ source('bronze_receita', 'cnaes') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.codigo), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_cnaes') }} AS s
    WHERE 1 = 1
      AND s.codigo = NULLIF(TRIM(b.codigo), '')
  )

UNION ALL

SELECT
  'motivos' AS entidade
  , b.codigo AS chave
FROM {{ source('bronze_receita', 'motivos') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.codigo), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_motivos') }} AS s
    WHERE 1 = 1
      AND s.codigo = NULLIF(TRIM(b.codigo), '')
  )

UNION ALL

SELECT
  'municipios' AS entidade
  , b.codigo AS chave
FROM {{ source('bronze_receita', 'municipios') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.codigo), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_municipios') }} AS s
    WHERE 1 = 1
      AND s.codigo = NULLIF(TRIM(b.codigo), '')
  )

UNION ALL

SELECT
  'naturezas' AS entidade
  , b.codigo AS chave
FROM {{ source('bronze_receita', 'naturezas') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.codigo), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_naturezas') }} AS s
    WHERE 1 = 1
      AND s.codigo = NULLIF(TRIM(b.codigo), '')
  )

UNION ALL

SELECT
  'paises' AS entidade
  , b.codigo AS chave
FROM {{ source('bronze_receita', 'paises') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.codigo), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_paises') }} AS s
    WHERE 1 = 1
      AND s.codigo = NULLIF(TRIM(b.codigo), '')
  )

UNION ALL

SELECT
  'qualificacoes' AS entidade
  , b.codigo AS chave
FROM {{ source('bronze_receita', 'qualificacoes') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.codigo), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_qualificacoes') }} AS s
    WHERE 1 = 1
      AND s.codigo = NULLIF(TRIM(b.codigo), '')
  )

UNION ALL

SELECT
  'estabelecimentos' AS entidade
  , b.cnpj_basico || b.cnpj_ordem || b.cnpj_dv AS chave
FROM {{ source('bronze_receita', 'estabelecimentos') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.cnpj_basico), '') IS NOT NULL
  AND NULLIF(TRIM(b.cnpj_ordem), '') IS NOT NULL
  AND NULLIF(TRIM(b.cnpj_dv), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_estabelecimentos') }} AS s
    WHERE 1 = 1
      AND s.cnpj_basico = NULLIF(TRIM(b.cnpj_basico), '')
      AND s.cnpj_ordem = NULLIF(TRIM(b.cnpj_ordem), '')
      AND s.cnpj_dv = NULLIF(TRIM(b.cnpj_dv), '')
  )

UNION ALL

SELECT
  'socios' AS entidade
  , b.cnpj_basico || '|' || b.identificador_de_socio AS chave
FROM {{ source('bronze_receita', 'socios') }} AS b
WHERE 1 = 1
  AND b._motivo_ilegivel IS NULL
  AND NULLIF(TRIM(b.cnpj_basico), '') IS NOT NULL
  AND NULLIF(TRIM(b.identificador_de_socio), '') IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM {{ ref('silver_receita_socios') }} AS s
    WHERE 1 = 1
      AND s.cnpj_basico = NULLIF(TRIM(b.cnpj_basico), '')
      AND s.identificador_de_socio = NULLIF(TRIM(b.identificador_de_socio), '')
      AND s.nome_do_socio_no_caso_pf_ou_razao_social_no_caso_pj
      IS NOT DISTINCT FROM
      NULLIF(TRIM(b.nome_do_socio_no_caso_pf_ou_razao_social_no_caso_pj), '')
      AND s.cnpj_cpf_do_socio IS NOT DISTINCT FROM NULLIF(TRIM(b.cnpj_cpf_do_socio), '')
      AND s.data_de_entrada_sociedade
      IS NOT DISTINCT FROM {{ data_compacta('b.data_de_entrada_sociedade') }}
  )
