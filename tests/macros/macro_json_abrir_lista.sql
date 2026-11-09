{#
  Falha para cada caso em que `json_abrir_lista` devolve algo diferente do esperado: a lista vira
  uma linha por elemento, com a posição a partir de 1 e o elemento nulo preservado; lista vazia,
  NULL, `null` e objeto não geram linha.
#}
WITH tCasos (caso, lista) AS (
  VALUES
  (1, {{ json_ou_nulo("'[\"a\", {\"x\": 1}, null]'") }})
  , (2, {{ json_ou_nulo("'[]'") }})
  , (3, {{ json_ou_nulo("'null'") }})
  , (4, {{ json_ou_nulo("'{\"x\": 1}'") }})
  , (5, CAST(NULL AS JSON))
)

, tObtido AS (
  SELECT
    c.caso
    , CAST(t.posicao AS INTEGER) AS posicao
    , CAST(t.valor AS VARCHAR) AS valor
  FROM tCasos AS c
  CROSS JOIN LATERAL {{ json_abrir_lista('c.lista', 't') }}
)

, tEsperado (caso, posicao, valor) AS (
  VALUES
  (1, 1, '"a"')
  , (1, 2, '{"x":1}')
  , (1, 3, CAST(NULL AS VARCHAR))
)

, tSobrando AS (
  SELECT
    caso
    , posicao
    , valor
  FROM tObtido
  EXCEPT
  SELECT
    caso
    , posicao
    , valor
  FROM tEsperado
)

, tFaltando AS (
  SELECT
    caso
    , posicao
    , valor
  FROM tEsperado
  EXCEPT
  SELECT
    caso
    , posicao
    , valor
  FROM tObtido
)

SELECT
  caso
  , posicao
  , valor
FROM tSobrando

UNION ALL

SELECT
  caso
  , posicao
  , valor
FROM tFaltando
