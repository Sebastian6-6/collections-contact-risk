{#
  Prova a ordem da versão mais recente (S3, R7, H5) num conjunto pequeno. Cada documento tem um
  empate a desfazer e uma linha esperada como vencedora:
    - doc 1: a data de atualização maior vence ('v2');
    - doc 2: data de atualização NULL perde para qualquer data ('com_data');
    - doc 3: mesma atualização, a entrega maior vence ('entrega_nova');
    - doc 4: mesma atualização e entrega, o reenvio vence o original ('reenvio');
    - doc 5: mesmo arquivo, a linha maior vence ('linha_20').
  Falha se a linha vencedora de algum documento não for a esperada.
#}
WITH tLinhas AS (
  SELECT
    documento
    , marca
    , CAST(dt_atualizacao AS DATE) AS dt_atualizacao
    , CAST(data_entrega AS DATE) AS data_entrega
    , _arquivo
    , _linha
  FROM (
    VALUES
    (1, 'v1', '2026-01-01', '2026-02-01', 'a/cadastro_20260201.csv', 1)
    , (1, 'v2', '2026-01-05', '2026-02-01', 'a/cadastro_20260201.csv', 2)
    , (2, 'sem_data', NULL, '2026-02-01', 'a/cadastro_20260201.csv', 3)
    , (2, 'com_data', '2020-01-01', '2026-02-01', 'a/cadastro_20260201.csv', 1)
    , (3, 'entrega_antiga', '2026-01-01', '2026-02-01', 'a/cadastro_20260201.csv', 9)
    , (3, 'entrega_nova', '2026-01-01', '2026-03-01', 'a/cadastro_20260301.csv', 1)
    , (4, 'original', '2026-01-01', '2026-02-01', 'a/cadastro_20260201.csv', 9)
    , (4, 'reenvio', '2026-01-01', '2026-02-01', 'a/cadastro_20260201_reenvio.csv', 1)
    , (5, 'linha_10', '2026-01-01', '2026-02-01', 'a/cadastro_20260201.csv', 10)
    , (5, 'linha_20', '2026-01-01', '2026-02-01', 'a/cadastro_20260201.csv', 20)
  ) AS tFixture (documento, marca, dt_atualizacao, data_entrega, _arquivo, _linha)
)

, tOrdenadas AS (
  SELECT
    documento
    , marca
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY {{ ordem_versao('dt_atualizacao') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS posicao
  FROM tLinhas
)

, tEsperadas AS (
  SELECT
    documento
    , marca_esperada
  FROM (
    VALUES
    (1, 'v2')
    , (2, 'com_data')
    , (3, 'entrega_nova')
    , (4, 'reenvio')
    , (5, 'linha_20')
  ) AS tFixture (documento, marca_esperada)
)

SELECT
  tEsperadas.documento
  , tEsperadas.marca_esperada
  , tOrdenadas.marca AS marca_obtida
FROM tEsperadas
LEFT JOIN tOrdenadas
  ON tEsperadas.documento = tOrdenadas.documento
    AND tOrdenadas.posicao = 1
WHERE 1 = 1
  AND tOrdenadas.marca IS DISTINCT FROM tEsperadas.marca_esperada
