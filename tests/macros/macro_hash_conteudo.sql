{#
  Prova a serialização injetiva de `hash_conteudo`: NULL difere de texto vazio, nenhum valor real
  colide com o marcador de NULL, ('ab', 'c') difere de ('a', 'bc'), ('aV', 'b') difere de ('a', 'Vb') (o marcador V no texto não pode
  emendar valores), a posição do NULL importa, a
  ordem das colunas importa e a mesma entrada dá sempre o mesmo hash. Falha se dois casos que
  deveriam diferir derem o mesmo hash ou se entradas iguais derem hashes diferentes.
#}
WITH tCasos AS (
  SELECT
    caso
    , CAST(a AS VARCHAR) AS a
    , CAST(b AS VARCHAR) AS b
  FROM (
    VALUES
    ('nulo_nulo', NULL, NULL)
    , ('vazio_vazio', '', '')
    , ('letra_n_vazio', 'N', '')
    , ('ab_c', 'ab', 'c')
    , ('a_bc', 'a', 'bc')
    , ('nulo_x', NULL, 'x')
    , ('x_nulo', 'x', NULL)
    , ('x_vazio', 'x', '')
    , ('vazio_x', '', 'x')
    , ('av_b', 'aV', 'b')
    , ('a_vb', 'a', 'Vb')
    , ('x_nulo_repetido', 'x', NULL)
  ) AS tFixture (caso, a, b)
)

, tHashes AS (
  SELECT
    caso
    , {{ hash_conteudo(['a', 'b']) }} AS hash_ab
    , {{ hash_conteudo(['b', 'a']) }} AS hash_ba
  FROM tCasos
)

, tDistintos AS (
  SELECT
    COUNT(*) AS qt_total
    , COUNT(DISTINCT hash_ab) AS qt_hashes
  FROM tHashes
  WHERE 1 = 1
    AND caso <> 'x_nulo_repetido'
)

, tRepetido AS (
  SELECT COUNT(DISTINCT hash_ab) AS qt_hashes
  FROM tHashes
  WHERE 1 = 1
    AND caso IN ('x_nulo', 'x_nulo_repetido')
)

, tOrdem AS (
  SELECT COUNT(*) AS qt_iguais
  FROM tHashes
  WHERE 1 = 1
    AND caso = 'ab_c'
    AND hash_ab = hash_ba
)

SELECT 'casos que deveriam diferir deram o mesmo hash' AS falha
FROM tDistintos
WHERE 1 = 1
  AND qt_hashes <> qt_total

UNION ALL

SELECT 'a mesma entrada deu hashes diferentes' AS falha
FROM tRepetido
WHERE 1 = 1
  AND qt_hashes <> 1

UNION ALL

SELECT 'a ordem das colunas não mudou o hash' AS falha
FROM tOrdem
WHERE 1 = 1
  AND qt_iguais <> 0
