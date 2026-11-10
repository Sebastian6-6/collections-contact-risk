{#
  Prova que `assinatura_lista` não depende da ordem da lista e depende do conteúdo: os grupos 1 e 2
  têm os mesmos elementos em ordens diferentes (assinatura igual); o grupo 3 troca um elemento
  (assinatura diferente); o grupo 4 tem um NULL e o grupo 5 um texto vazio (diferentes); o grupo 6
  repete um elemento (difere do grupo 1); os grupos 7 e 8 ({'aV','b'} e {'a','Vb'}) e os
  grupos 9 e 10 ({'a','b'} e {'aVb'}) diferem entre si (o marcador V no texto não pode emendar
  elementos). Falha se qualquer uma dessas relações for violada.
#}
WITH tElementos AS (
  SELECT
    grupo
    , CAST(elemento AS VARCHAR) AS elemento
  FROM (
    VALUES
    (1, 'b'), (1, 'a'), (1, 'C')
    , (2, 'C'), (2, 'b'), (2, 'a')
    , (3, 'C'), (3, 'b'), (3, 'd')
    , (4, NULL)
    , (5, '')
    , (6, 'b'), (6, 'a'), (6, 'C'), (6, 'a')
    , (7, 'aV'), (7, 'b')
    , (8, 'a'), (8, 'Vb')
    , (9, 'a'), (9, 'b')
    , (10, 'aVb')
  ) AS tFixture (grupo, elemento)
)

, tAssinaturas AS (
  SELECT
    grupo
    , {{ assinatura_lista('elemento') }} AS assinatura
  FROM tElementos
  GROUP BY grupo
)

, tComparacao AS (
  SELECT
    MAX(CASE WHEN grupo = 1 THEN assinatura END) AS g1
    , MAX(CASE WHEN grupo = 2 THEN assinatura END) AS g2
    , MAX(CASE WHEN grupo = 3 THEN assinatura END) AS g3
    , MAX(CASE WHEN grupo = 4 THEN assinatura END) AS g4
    , MAX(CASE WHEN grupo = 5 THEN assinatura END) AS g5
    , MAX(CASE WHEN grupo = 6 THEN assinatura END) AS g6
    , MAX(CASE WHEN grupo = 7 THEN assinatura END) AS g7
    , MAX(CASE WHEN grupo = 8 THEN assinatura END) AS g8
    , MAX(CASE WHEN grupo = 9 THEN assinatura END) AS g9
    , MAX(CASE WHEN grupo = 10 THEN assinatura END) AS g10
  FROM tAssinaturas
)

SELECT 'a ordem da lista mudou a assinatura' AS falha
FROM tComparacao
WHERE 1 = 1
  AND g1 IS DISTINCT FROM g2

UNION ALL

SELECT 'um elemento diferente não mudou a assinatura' AS falha
FROM tComparacao
WHERE 1 = 1
  AND g2 IS NOT DISTINCT FROM g3

UNION ALL

SELECT 'NULL e texto vazio deram a mesma assinatura' AS falha
FROM tComparacao
WHERE 1 = 1
  AND g4 IS NOT DISTINCT FROM g5

UNION ALL

SELECT 'um elemento repetido não mudou a assinatura' AS falha
FROM tComparacao
WHERE 1 = 1
  AND g1 IS NOT DISTINCT FROM g6

UNION ALL

SELECT 'elementos com V no texto deram a mesma assinatura' AS falha
FROM tComparacao
WHERE 1 = 1
  AND (g7 IS NOT DISTINCT FROM g8 OR g9 IS NOT DISTINCT FROM g10)
