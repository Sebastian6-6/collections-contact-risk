{#
  Medição da regra de versão do devedor no alfa. Grão: uma linha com contagens, sobre os documentos
  distintos da etapa `silver_alfa_devedores_padronizados`. Cada coluna conta em quantos documentos
  o vencedor (`_arquivo`, `_linha`) é outro que não o da regra do modelo (atualização, entrega,
  arquivo, linha, todas decrescentes e com `NULL` por último):
    - `muda_sentinela_ausente`: a data 2025-09-01 de atualização é tratada como ausente (`NULL`);
    - `muda_entrega_antes`: a entrega ordena antes da atualização;
    - `muda_so_entrega`: a atualização não entra na ordenação (só entrega, arquivo e linha).
  Rodar com `dbt compile --select medicao_ordenacao_devedores_alfa` e executar o SQL de
  `target/compiled/` no banco, ou `dbt show --select medicao_ordenacao_devedores_alfa`.
  Medido em 2026-11-09 (resultado no commit que criou esta consulta).
#}
WITH tBase AS (
  SELECT
    documento
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , CASE
      WHEN data_atualizacao = CAST('2025-09-01' AS DATE) THEN CAST(NULL AS DATE)
      ELSE data_atualizacao
    END AS data_atualizacao_sem_sentinela
  FROM {{ ref('silver_alfa_devedores_padronizados') }}
)

, tOrdens AS (
  SELECT
    documento
    , _arquivo || '#' || CAST(_linha AS VARCHAR) AS linha_origem
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY
        data_atualizacao DESC NULLS LAST
        , data_entrega DESC NULLS LAST
        , _arquivo DESC
        , _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_modelo
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY
        data_atualizacao_sem_sentinela DESC NULLS LAST
        , data_entrega DESC NULLS LAST
        , _arquivo DESC
        , _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_sentinela
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY
        data_entrega DESC NULLS LAST
        , data_atualizacao DESC NULLS LAST
        , _arquivo DESC
        , _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_entrega_primeiro
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY
        data_entrega DESC NULLS LAST
        , _arquivo DESC
        , _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_so_entrega
  FROM tBase
)

, tVencedores AS (
  SELECT
    documento
    , MAX(CASE WHEN num_modelo = 1 THEN linha_origem END) AS v_modelo
    , MAX(CASE WHEN num_sentinela = 1 THEN linha_origem END) AS v_sentinela
    , MAX(CASE WHEN num_entrega_primeiro = 1 THEN linha_origem END) AS v_entrega_primeiro
    , MAX(CASE WHEN num_so_entrega = 1 THEN linha_origem END) AS v_so_entrega
  FROM tOrdens
  GROUP BY documento
)

SELECT
  COUNT(*) AS qt_documentos
  , SUM(CASE WHEN v_sentinela <> v_modelo THEN 1 ELSE 0 END) AS muda_sentinela_ausente
  , SUM(CASE WHEN v_entrega_primeiro <> v_modelo THEN 1 ELSE 0 END) AS muda_entrega_antes
  , SUM(CASE WHEN v_so_entrega <> v_modelo THEN 1 ELSE 0 END) AS muda_so_entrega
FROM tVencedores
