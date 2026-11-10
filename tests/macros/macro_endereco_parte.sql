{# Falha para cada caso em que as macros de endereço devolvem algo diferente do esperado. #}
WITH tCasos (entrada, logradouro, numero, complemento, bairro, cidade) AS (
  VALUES
  (
    'RUA TIRADENTES, 1039 - CENTRO - SAO PAULO'
    , 'RUA TIRADENTES', '1039', CAST(NULL AS VARCHAR), 'CENTRO', 'SAO PAULO'
  )
  , (
    'AV. MARECHAL DEODORO, 2499, FUNDOS - CENTRO - GUARULHOS'
    , 'AV. MARECHAL DEODORO', '2499', 'FUNDOS', 'CENTRO', 'GUARULHOS'
  )
  , (
    'AL. RUI BARBOSA, S/N, APTO 101 - MENINO DEUS - PORTO ALEGRE'
    , 'AL. RUI BARBOSA', 'S/N', 'APTO 101', 'MENINO DEUS', 'PORTO ALEGRE'
  )
  , (
    'RUA ANA-MARIA, 10 - CENTRO - SANTOS'
    , CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
    , CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
  , (
    'RUA SEM NUMERO - CENTRO - SANTOS'
    , CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
    , CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
  , (
    'RUA A, 1, B, C - CENTRO - SANTOS'
    , CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
    , CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
  , (
    NULL
    , CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
    , CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
)

SELECT entrada
FROM tCasos
WHERE 1 = 1
  AND (
    {{ endereco_parte('entrada', 1) }} IS DISTINCT FROM logradouro
    OR {{ endereco_parte('entrada', 2) }} IS DISTINCT FROM numero
    OR {{ endereco_parte('entrada', 3) }} IS DISTINCT FROM complemento
    OR {{ endereco_parte('entrada', 4) }} IS DISTINCT FROM bairro
    OR {{ endereco_parte('entrada', 5) }} IS DISTINCT FROM cidade
  )
