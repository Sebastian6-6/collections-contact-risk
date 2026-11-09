{#
  Falha para cada caso em que as macros de endereço do gama (`rua` e `endereco`) devolvem algo
  diferente do esperado.
#}
WITH tCasos (entrada, padrao, logradouro, numero, bairro) AS (
  VALUES
  ('R. Santos Dumont, 3306', 'rua', 'R. Santos Dumont', '3306', CAST(NULL AS VARCHAR))
  , ('AV. X, S/N', 'rua', 'AV. X', 'S/N', CAST(NULL AS VARCHAR))
  , (
    'RUA ANA-MARIA, 10'
    , 'rua', CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
  , (
    'RUA A, 1 - CENTRO'
    , 'rua', CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
  , ('TV. Santos Dumont, 744 - Centro', 'endereco', 'TV. Santos Dumont', '744', 'Centro')
  , (
    'RUA A, 1'
    , 'endereco', CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
  , (
    'RUA A, 1 - B - C'
    , 'endereco', CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
  , (
    CAST(NULL AS VARCHAR)
    , 'endereco', CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR)
  )
)

SELECT entrada
FROM tCasos
WHERE 1 = 1
  AND (
    CASE padrao
      WHEN 'rua' THEN {{ endereco_parte('entrada', 1, endereco_padrao_rua()) }}
      ELSE {{ endereco_parte('entrada', 1, endereco_padrao_rua_bairro()) }}
    END IS DISTINCT FROM logradouro
    OR CASE padrao
      WHEN 'rua' THEN {{ endereco_parte('entrada', 2, endereco_padrao_rua()) }}
      ELSE {{ endereco_parte('entrada', 2, endereco_padrao_rua_bairro()) }}
    END IS DISTINCT FROM numero
    OR CASE padrao
      WHEN 'rua' THEN CAST(NULL AS VARCHAR)
      ELSE {{ endereco_parte('entrada', 3, endereco_padrao_rua_bairro()) }}
    END IS DISTINCT FROM bairro
  )
