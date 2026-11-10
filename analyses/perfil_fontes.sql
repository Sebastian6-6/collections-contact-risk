{#
  Perfil das fontes (docs/perfil-das-fontes.md, "Visão geral"), regenerado pela pipeline.
  Grão: uma linha por fonte. Arquivos e linhas recebidas vêm do registro de cargas da bronze
  (`bronze_<fonte>.arquivos`), o único lugar que conta arquivos; documentos e versões vêm da
  silver: `qt_documentos` são os documentos distintos de `devedores` (CPF ou RG, sem o `NULL`) e
  `qt_versoes`, as linhas de `devedores_historico`. Na cobrança, o arquivo é um só, o documento é
  o `cpf_alvo` e não há versões. A lista de fontes de devedores é a `var` `arquivo_historico`, a
  mesma do monitoramento. Rodar com `dbt show --select perfil_fontes`.
#}
WITH tFontesDeDevedores AS (
  {%- for fonte, arquivo_historico in var('arquivo_historico').items() %}
    SELECT
      CAST('{{ fonte }}' AS VARCHAR) AS fonte
      , COUNT(*) AS qt_arquivos
      , SUM(arquivos.linhas) AS qt_linhas
      , COUNT(CASE WHEN arquivos.arquivo <> '{{ arquivo_historico }}' THEN 1 END)
        AS qt_arquivos_diarios
      , SUM(CASE WHEN arquivos.arquivo <> '{{ arquivo_historico }}' THEN arquivos.linhas END)
        AS qt_linhas_diarias
      , (
        SELECT COUNT(DISTINCT devedores.documento)
        FROM {{ ref('silver_' ~ fonte ~ '_devedores') }} AS devedores
      ) AS qt_documentos
      , (
        SELECT COUNT(*)
        FROM {{ ref('silver_' ~ fonte ~ '_devedores_historico') }}
      ) AS qt_versoes
    FROM {{ source('bronze_' ~ fonte, 'arquivos') }} AS arquivos
    {%- if not loop.last %}

      UNION ALL

    {% endif -%}
  {%- endfor %}
)

, tCobranca AS (
  SELECT
    CAST('cobranca' AS VARCHAR) AS fonte
    , COUNT(*) AS qt_arquivos
    , SUM(arquivos.linhas) AS qt_linhas
    , CAST(0 AS BIGINT) AS qt_arquivos_diarios
    , CAST(0 AS BIGINT) AS qt_linhas_diarias
    , (
      SELECT COUNT(DISTINCT contatos.cpf_alvo)
      FROM {{ ref('silver_cobranca_contatos_realizados') }} AS contatos
    ) AS qt_documentos
    , CAST(NULL AS BIGINT) AS qt_versoes
  FROM {{ source('bronze_cobranca', 'arquivos') }} AS arquivos
)

, tFontes AS (
  SELECT
    fonte
    , qt_arquivos
    , qt_linhas
    , qt_arquivos_diarios
    , qt_linhas_diarias
    , qt_documentos
    , qt_versoes
  FROM tFontesDeDevedores

  UNION ALL

  SELECT
    fonte
    , qt_arquivos
    , qt_linhas
    , qt_arquivos_diarios
    , qt_linhas_diarias
    , qt_documentos
    , qt_versoes
  FROM tCobranca
)

SELECT
  fonte
  , qt_arquivos
  , qt_linhas
  , qt_arquivos_diarios
  , qt_linhas_diarias
  , qt_documentos
  , qt_versoes
FROM tFontes
ORDER BY fonte
