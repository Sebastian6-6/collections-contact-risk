{#
  Falha para cada caso em que `generate_schema_name` devolve um schema diferente do esperado.
  Os nós são dicionários com os campos que a macro lê (`resource_type` e `fqn`). Os caminhos de
  erro (schema explícito, modelo sem pasta de camada, de fonte ou de domínio) interrompem a
  compilação e não cabem num teste de dados.
#}
WITH tCasos (descricao, obtido, esperado) AS (
  VALUES
  (
    'bronze usa a fonte'
    , '{{ generate_schema_name(
      none
      , {"resource_type": "model", "fqn": ["p", "bronze", "alfa", "x"]}
    ) }}'
    , 'bronze_alfa'
  )
  , (
    'silver usa a fonte'
    , '{{ generate_schema_name(
      none
      , {"resource_type": "model", "fqn": ["p", "silver", "beta", "x"]}
    ) }}'
    , 'silver_beta'
  )
  , (
    'gold usa o dominio'
    , '{{ generate_schema_name(
      none
      , {"resource_type": "model", "fqn": ["p", "gold", "devedores", "dim_x"]}
    ) }}'
    , 'gold_devedores'
  )
  , (
    'gold com subpasta mais funda continua no dominio'
    , '{{ generate_schema_name(
      none
      , {"resource_type": "model", "fqn": ["p", "gold", "devedores", "sub", "dim_x"]}
    ) }}'
    , 'gold_devedores'
  )
)

SELECT
  descricao
  , obtido
  , esperado
FROM tCasos
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
