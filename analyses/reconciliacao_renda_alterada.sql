{#
  Reconcilia a contagem de documentos com renda alterada (ponto 3, "Renda alterada"). Cada linha é
  uma medida; rodar com `dbt show --select reconciliacao_renda_alterada`.
    - `alfa_documentos_renda_alterada` e `beta_documentos_renda_alterada`: documentos cujas versões
      da histórica trazem mais de um valor de renda ou salário preenchido (silver, qualquer tipo
      de origem). Plano: 1.982 e 1.416.
    - `beta_documentos_renda_alterada_so_numerica`: o mesmo no beta, só com as versões cuja renda
      veio como número no JSON (o texto "R$ 9.241,83" fica de fora). É a conta da medição antiga
      do desenho da gold (962 contra 960 aqui, ver docs/contratos-de-dados.md, seção 8).
    - `beta_versoes_renda_em_texto`: versões do beta cuja renda veio como texto (3.057 aqui; as 3.262 linhas da medição antiga contam todas as aparições, e não só a mais recente de cada versão).
    - `alfa_versoes_salario_zero` e `alfa_documentos_salario_zero`: o 0,00 do alfa que a gold
      guarda como `vl_renda` NULL (ponto 6).
  Cada versão da histórica liga à linha da bronze pela aparição mais recente (`_arquivo`, `_linha`).
#}
WITH tBeta AS (
  SELECT
    historico.documento_tipo
    , historico.documento
    , historico.renda_mensal
    , bronze.registro ~ '"renda_mensal": *-?[0-9]' AS renda_numerica
    , bronze.registro ~ '"renda_mensal": *"' AS renda_texto
  FROM {{ ref('silver_beta_devedores_historico') }} AS historico
  INNER JOIN {{ source('bronze_beta', 'devedores') }} AS bronze
    ON historico._arquivo = bronze._arquivo
      AND historico._linha = bronze._linha
  WHERE 1 = 1
    AND historico.documento IS NOT NULL
)

, tBetaAlteradas AS (
  SELECT
    documento_tipo
    , documento
    , COUNT(DISTINCT renda_mensal) AS qt_rendas
    , COUNT(DISTINCT CASE WHEN renda_numerica THEN renda_mensal END) AS qt_rendas_numericas
  FROM tBeta
  GROUP BY documento_tipo, documento
)

, tAlfaAlteradas AS (
  SELECT
    documento
    , COUNT(DISTINCT salario_informado) AS qt_rendas
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
  GROUP BY documento
)

SELECT
  'alfa_documentos_renda_alterada' AS medida
  , COUNT(CASE WHEN qt_rendas > 1 THEN 1 END) AS valor
FROM tAlfaAlteradas

UNION ALL

SELECT
  'beta_documentos_renda_alterada' AS medida
  , COUNT(CASE WHEN qt_rendas > 1 THEN 1 END) AS valor
FROM tBetaAlteradas

UNION ALL

SELECT
  'beta_documentos_renda_alterada_so_numerica' AS medida
  , COUNT(CASE WHEN qt_rendas_numericas > 1 THEN 1 END) AS valor
FROM tBetaAlteradas

UNION ALL

SELECT
  'beta_versoes_renda_em_texto' AS medida
  , COUNT(CASE WHEN renda_texto THEN 1 END) AS valor
FROM tBeta

UNION ALL

SELECT
  'alfa_versoes_salario_zero' AS medida
  , COUNT(CASE WHEN salario_informado = 0 THEN 1 END) AS valor
FROM {{ ref('silver_alfa_devedores_historico') }}

UNION ALL

SELECT
  'alfa_documentos_salario_zero' AS medida
  , COUNT(DISTINCT CASE WHEN salario_informado = 0 THEN documento END) AS valor
FROM {{ ref('silver_alfa_devedores_historico') }}
