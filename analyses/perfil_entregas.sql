{#
  Perfil das fontes (docs/perfil-das-fontes.md, "Entregas diárias"), regenerado pela pipeline.
  Grão: uma linha por provedor. Fontes:
    - `ft_entrega_diaria` (uma linha por provedor e dia com entrega): entregas, dias sem entrega,
      dias com mais de um arquivo, volume médio por tipo de dia e a parte das linhas atualizadas
      antes do dia da entrega nas entregas comuns (sem a primeira, que não tem dia anterior, e sem
      as que passam do limite de alerta `limite_registros_anormais`);
    - registro de cargas da bronze: as linhas do arquivo `_reenvio` e do original da mesma data;
    - silver: versões da histórica com a data de atualização padrão 2025-09-01, pela entrega em
      que foram vistas pela primeira vez, e os documentos das entregas diárias que já estavam na
      carga histórica.
  Rodar com `dbt show --select perfil_entregas`.
#}
WITH tPrimeiraEntrega AS (
  SELECT
    provedor
    , MIN(dt_referencia) AS dt_primeira_entrega
  FROM {{ ref('ft_entrega_diaria') }}
  GROUP BY provedor
)

, tEntregas AS (
  SELECT
    entregas.provedor
    , COUNT(*) AS qt_entregas
    , SUM(entregas.qt_arquivos) AS qt_arquivos
    , SUM(
      CASE
        WHEN entregas.qt_dias_desde_entrega_anterior > 1
          THEN entregas.qt_dias_desde_entrega_anterior - 1
        ELSE 0
      END
    ) AS qt_dias_sem_entrega
    , COUNT(CASE WHEN entregas.qt_arquivos > 1 THEN 1 END) AS qt_dias_com_reenvio
    , ROUND(AVG(CASE WHEN entregas.tp_dia = 'util' THEN entregas.qt_registros END), 1)
      AS vl_media_dia_util
    , ROUND(AVG(CASE WHEN entregas.tp_dia = 'fim_de_semana' THEN entregas.qt_registros END), 1)
      AS vl_media_fim_de_semana
    , ROUND(
      100 * MIN(
        CASE
          WHEN
            entregas.dt_referencia > tPrimeiraEntrega.dt_primeira_entrega
            AND CAST(entregas.qt_registros_atrasados AS NUMERIC) / entregas.qt_registros
            <= {{ var('limite_registros_anormais') }}
            THEN CAST(entregas.qt_registros_atrasados AS NUMERIC) / entregas.qt_registros
        END
      )
      , 1
    ) AS tx_atrasados_min_pct
    , ROUND(
      100 * MAX(
        CASE
          WHEN
            entregas.dt_referencia > tPrimeiraEntrega.dt_primeira_entrega
            AND CAST(entregas.qt_registros_atrasados AS NUMERIC) / entregas.qt_registros
            <= {{ var('limite_registros_anormais') }}
            THEN CAST(entregas.qt_registros_atrasados AS NUMERIC) / entregas.qt_registros
        END
      )
      , 1
    ) AS tx_atrasados_max_pct
  FROM {{ ref('ft_entrega_diaria') }} AS entregas
  INNER JOIN tPrimeiraEntrega
    ON entregas.provedor = tPrimeiraEntrega.provedor
  GROUP BY entregas.provedor
)

, tArquivos AS (
  {%- for fonte in var('arquivo_historico') %}
    SELECT
      CAST('{{ fonte }}' AS VARCHAR) AS provedor
      , arquivo
      , linhas
    FROM {{ source('bronze_' ~ fonte, 'arquivos') }}
    {%- if not loop.last %}

      UNION ALL

    {% endif -%}
  {%- endfor %}
)

, tReenvios AS (
  SELECT
    reenvios.provedor
    , SUM(originais.linhas) AS qt_linhas_originais_reenviados
    , SUM(reenvios.linhas) AS qt_linhas_reenvios
  FROM tArquivos AS reenvios
  INNER JOIN tArquivos AS originais
    ON
      reenvios.provedor = originais.provedor
      AND REPLACE(reenvios.arquivo, '_reenvio', '') = originais.arquivo
  WHERE 1 = 1
    AND reenvios.arquivo LIKE '%\_reenvio.%' ESCAPE '\'
  GROUP BY reenvios.provedor
)

, tVersoes AS (
  SELECT
    CAST('alfa' AS VARCHAR) AS provedor
    , documento
    , data_atualizacao AS dt_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
  FROM {{ ref('silver_alfa_devedores_historico') }}

  UNION ALL

  SELECT
    CAST('beta' AS VARCHAR) AS provedor
    , documento
    , atualizado_em AS dt_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
  FROM {{ ref('silver_beta_devedores_historico') }}

  UNION ALL

  SELECT
    CAST('gama' AS VARCHAR) AS provedor
    , documento
    , dt_ref AS dt_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
  FROM {{ ref('silver_gama_devedores_historico') }}
)

, tDataPadrao AS (
  SELECT
    provedor
    , COUNT(
      CASE
        WHEN data_primeira_entrega = CAST('{{ var("data_carga_historica") }}' AS DATE) THEN 1
      END
    ) AS qt_versoes_2025_09_01_historica
    , COUNT(
      CASE
        WHEN data_primeira_entrega > CAST('{{ var("data_carga_historica") }}' AS DATE) THEN 1
      END
    ) AS qt_versoes_2025_09_01_diarias
  FROM tVersoes
  WHERE 1 = 1
    AND dt_atualizacao = CAST('2025-09-01' AS DATE)
  GROUP BY provedor
)

, tDocumentos AS (
  SELECT
    provedor
    , documento
    , MAX(
      CASE
        WHEN data_primeira_entrega = CAST('{{ var("data_carga_historica") }}' AS DATE) THEN 1
        ELSE 0
      END
    ) AS na_historica
    , MAX(
      CASE
        WHEN data_ultima_entrega > CAST('{{ var("data_carga_historica") }}' AS DATE) THEN 1
        ELSE 0
      END
    ) AS nas_diarias
  FROM tVersoes
  WHERE 1 = 1
    AND documento IS NOT NULL
  GROUP BY provedor, documento
)

, tDocumentosDiarios AS (
  SELECT
    provedor
    , SUM(nas_diarias) AS qt_documentos_diarias
    , SUM(nas_diarias * na_historica) AS qt_documentos_diarias_ja_na_historica
  FROM tDocumentos
  GROUP BY provedor
)

SELECT
  tEntregas.provedor
  , tEntregas.qt_entregas
  , tEntregas.qt_arquivos
  , tEntregas.qt_dias_sem_entrega
  , tEntregas.qt_dias_com_reenvio
  , tReenvios.qt_linhas_originais_reenviados
  , tReenvios.qt_linhas_reenvios
  , tEntregas.vl_media_dia_util
  , tEntregas.vl_media_fim_de_semana
  , tEntregas.tx_atrasados_min_pct
  , tEntregas.tx_atrasados_max_pct
  , tDataPadrao.qt_versoes_2025_09_01_historica
  , tDataPadrao.qt_versoes_2025_09_01_diarias
  , tDocumentosDiarios.qt_documentos_diarias
  , tDocumentosDiarios.qt_documentos_diarias_ja_na_historica
  , ROUND(
    100 * CAST(tDocumentosDiarios.qt_documentos_diarias_ja_na_historica AS NUMERIC)
    / NULLIF(tDocumentosDiarios.qt_documentos_diarias, 0)
    , 1
  ) AS tx_documentos_ja_na_historica_pct
FROM tEntregas
LEFT JOIN tReenvios
  ON tEntregas.provedor = tReenvios.provedor
LEFT JOIN tDataPadrao
  ON tEntregas.provedor = tDataPadrao.provedor
LEFT JOIN tDocumentosDiarios
  ON tEntregas.provedor = tDocumentosDiarios.provedor
ORDER BY tEntregas.provedor
