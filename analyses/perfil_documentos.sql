{#
  Perfil das fontes (docs/perfil-das-fontes.md, "Identificação do devedor"), regenerado da silver.
  Grão: uma linha por medida, com a contagem em `qt`:
    - `cpfs_historica_*`: CPFs distintos nas cargas históricas (versão vista pela primeira vez na
      `var` `data_carga_historica`), no total e por número de provedores que os mandam;
    - `cpfs_todas_entregas_*`: o mesmo, com as entregas diárias de setembro;
    - `cpfs_nome_divergente` e `cpfs_nascimento_divergente`: CPFs de 2 ou mais provedores cuja
      versão atual (`devedores`) traz nomes diferentes pela chave `nome_comparavel` (sem acento)
      ou datas de nascimento diferentes (sem contar `NULL`);
    - `versoes_nascimento_1900` e `versoes_nascimento_futuro`: versões da histórica com a data
      sentinela 1900-01-01 ou com nascimento depois da carga histórica.
  O documento é o da silver, já com os zeros à esquerda repostos; o RG do beta fica fora, porque
  não é CPF. Rodar com `dbt show --select perfil_documentos`.
#}
WITH tVersoes AS (
  SELECT
    CAST('alfa' AS VARCHAR) AS fonte
    , documento
    , data_nascimento
    , data_primeira_entrega
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL

  UNION ALL

  SELECT
    CAST('beta' AS VARCHAR) AS fonte
    , documento
    , data_nascimento
    , data_primeira_entrega
  FROM {{ ref('silver_beta_devedores_historico') }}
  WHERE 1 = 1
    AND documento_tipo = 'CPF'
    AND documento IS NOT NULL

  UNION ALL

  SELECT
    CAST('gama' AS VARCHAR) AS fonte
    , documento
    , data_nascimento
    , data_primeira_entrega
  FROM {{ ref('silver_gama_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

, tVersoesAtuais AS (
  SELECT
    CAST('alfa' AS VARCHAR) AS fonte
    , documento
    , {{ nome_comparavel('nome_completo') }} AS nome_chave
    , data_nascimento
  FROM {{ ref('silver_alfa_devedores') }}
  WHERE 1 = 1
    AND documento IS NOT NULL

  UNION ALL

  SELECT
    CAST('beta' AS VARCHAR) AS fonte
    , documento
    , {{ nome_comparavel('nome_completo') }} AS nome_chave
    , data_nascimento
  FROM {{ ref('silver_beta_devedores') }}
  WHERE 1 = 1
    AND documento_tipo = 'CPF'
    AND documento IS NOT NULL

  UNION ALL

  SELECT
    CAST('gama' AS VARCHAR) AS fonte
    , documento
    , {{ nome_comparavel('nome') }} AS nome_chave
    , data_nascimento
  FROM {{ ref('silver_gama_devedores') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

, tProvedoresPorCpf AS (
  SELECT
    documento
    , COUNT(
      DISTINCT CASE
        WHEN data_primeira_entrega = CAST('{{ var("data_carga_historica") }}' AS DATE) THEN fonte
      END
    ) AS qt_provedores_historica
    , COUNT(DISTINCT fonte) AS qt_provedores
  FROM tVersoes
  GROUP BY documento
)

, tDivergencias AS (
  SELECT
    documento
    , COUNT(DISTINCT fonte) AS qt_provedores
    , COUNT(DISTINCT nome_chave) AS qt_nomes
    , COUNT(DISTINCT data_nascimento) AS qt_nascimentos
  FROM tVersoesAtuais
  GROUP BY documento
)

, tMedidas AS (
  SELECT
    CAST('cpfs_historica_total' AS VARCHAR) AS medida
    , COUNT(CASE WHEN qt_provedores_historica > 0 THEN 1 END) AS qt
  FROM tProvedoresPorCpf

  UNION ALL

  SELECT
    'cpfs_historica_em_' || CAST(qt_provedores_historica AS VARCHAR) || '_provedores' AS medida
    , COUNT(*) AS qt
  FROM tProvedoresPorCpf
  WHERE 1 = 1
    AND qt_provedores_historica > 0
  GROUP BY qt_provedores_historica

  UNION ALL

  SELECT
    CAST('cpfs_todas_entregas_total' AS VARCHAR) AS medida
    , COUNT(*) AS qt
  FROM tProvedoresPorCpf

  UNION ALL

  SELECT
    'cpfs_todas_entregas_em_' || CAST(qt_provedores AS VARCHAR) || '_provedores' AS medida
    , COUNT(*) AS qt
  FROM tProvedoresPorCpf
  GROUP BY qt_provedores

  UNION ALL

  SELECT
    CAST('cpfs_nome_divergente' AS VARCHAR) AS medida
    , COUNT(CASE WHEN qt_provedores > 1 AND qt_nomes > 1 THEN 1 END) AS qt
  FROM tDivergencias

  UNION ALL

  SELECT
    CAST('cpfs_nascimento_divergente' AS VARCHAR) AS medida
    , COUNT(CASE WHEN qt_provedores > 1 AND qt_nascimentos > 1 THEN 1 END) AS qt
  FROM tDivergencias

  UNION ALL

  SELECT
    CAST('versoes_nascimento_1900' AS VARCHAR) AS medida
    , COUNT(CASE WHEN data_nascimento = CAST('1900-01-01' AS DATE) THEN 1 END) AS qt
  FROM tVersoes

  UNION ALL

  SELECT
    CAST('versoes_nascimento_futuro' AS VARCHAR) AS medida
    , COUNT(
      CASE WHEN data_nascimento > CAST('{{ var("data_carga_historica") }}' AS DATE) THEN 1 END
    ) AS qt
  FROM tVersoes
)

SELECT
  medida
  , qt
FROM tMedidas
ORDER BY medida
