{# Falha para cada caso em que `json_ou_nulo` devolve algo diferente do esperado. #}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('{"cpf": "16428742136", "contato": {"emails": ["a@b.com"]}}', '16428742136')
  , (
    '{"cpf": "94502272841", "nome": "Registro Interrompido", "contato": {"telefones": [{"ddd": "1'
    , NULL
  )
  , ('[{"tipo": "celular", "valor": "(21) 94780-1773"}, {"tipo": "ema', NULL)
  , ('', NULL)
  , ('nao e json', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ json_ou_nulo('entrada') }} ->> 'cpf' AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
