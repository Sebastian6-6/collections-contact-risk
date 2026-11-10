{#
  Ida e volta do endereço (S7): em toda linha separada, as partes recompõem exatamente o texto
  original; e a separação é tudo ou nada (logradouro, número, bairro e cidade vêm juntos, ou
  nenhuma parte vem). Cada linha devolvida é um endereço que não recompõe ou uma separação pela
  metade.
#}
WITH tRecomposto AS (
  SELECT
    documento
    , endereco
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , CONCAT(
      logradouro, ', ', numero, COALESCE(', ' || complemento, '')
      , ' - ', bairro, ' - ', cidade
    ) AS endereco_recomposto
  FROM {{ ref('silver_alfa_devedores') }}
)

SELECT
  documento
  , endereco
  , endereco_recomposto
FROM tRecomposto
WHERE 1 = 1
  AND (
    (logradouro IS NOT NULL AND endereco_recomposto IS DISTINCT FROM endereco)
    OR (
      logradouro IS NULL
      AND (
        numero IS NOT NULL OR complemento IS NOT NULL OR bairro IS NOT NULL OR cidade IS NOT NULL
      )
    )
    OR (logradouro IS NOT NULL AND (numero IS NULL OR bairro IS NULL OR cidade IS NULL))
  )
