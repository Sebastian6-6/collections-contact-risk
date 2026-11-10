{#
  Ida e volta do endereço (S7): nos dois formatos de texto (`rua` e `endereco`), a linha separada
  recompõe exatamente o texto original (logradouro, número e, quando há, bairro), e a separação é
  tudo ou nada: ou logradouro e número vêm juntos, ou nenhuma parte vem. O formato em colunas
  separadas não tem texto (`endereco` nulo) e fica fora. Cada linha devolvida é um endereço que
  não recompõe ou uma separação pela metade.
#}
WITH tRecomposto AS (
  SELECT
    documento
    , endereco
    , logradouro
    , numero
    , bairro
    , CONCAT(logradouro, ', ', numero, COALESCE(' - ' || bairro, '')) AS endereco_recomposto
  FROM {{ ref('silver_gama_devedores') }}
  WHERE 1 = 1
    AND endereco IS NOT NULL
)

SELECT
  documento
  , endereco
  , endereco_recomposto
FROM tRecomposto
WHERE 1 = 1
  AND (
    (logradouro IS NOT NULL AND endereco_recomposto IS DISTINCT FROM endereco)
    OR (logradouro IS NULL AND (numero IS NOT NULL OR bairro IS NOT NULL))
    OR (logradouro IS NOT NULL AND numero IS NULL)
  )
