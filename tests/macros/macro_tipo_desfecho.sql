{# Falha para cada resultado que `tipo_desfecho` classifica diferente do esperado (G2b). #}
WITH tCasos (resultado, esperado) AS (
  VALUES
  ('pagamento', 'contato_confirmado')
  , ('promessa_pagamento', 'contato_confirmado')
  , ('reclamacao', 'contato_confirmado')
  , ('numero_errado', 'terceiro')
  , ('nao_conhece_devedor', 'terceiro')
  , ('opt_out', 'opt_out')
  , ('falecido', 'falecido')
  , ('entregue', 'sem_confirmacao')
  , ('lido', 'sem_confirmacao')
  , ('sem_resposta', 'sem_confirmacao')
  , ('valor_novo', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    resultado
    , esperado
    , {{ tipo_desfecho('resultado') }} AS obtido
  FROM tCasos
)

SELECT
  resultado
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
