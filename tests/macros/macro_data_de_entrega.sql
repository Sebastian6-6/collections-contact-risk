{#
  Falha para cada caso em que `data_de_entrega` devolve algo diferente do esperado. Só o arquivo
  histórico configurado (nome exato) recebe a data da carga; nome parecido com o de uma entrega
  diária mas sem data válida fica NULL, e é isso que o teste `entrega_diaria_sem_data_valida` pega.
#}
WITH tCasos (entrada, esperado) AS (
  VALUES
  ('contact_data/provedor_alfa.csv', CAST('2026-08-31' AS DATE))
  , ('contact_data/entregas_diarias/alfa/provedor_alfa_2026-09-01.csv', CAST('2026-09-01' AS DATE))
  , ('contact_data/entregas_diarias/alfa/provedor_alfa_20260901.csv', NULL)
  , ('contact_data/entregas_diarias/alfa/provedor_alfa_2026-09-31.csv', NULL)
  , ('contact_data/entregas_diarias/alfa/provedor_alfa_2026-9-1.csv', NULL)
  , ('contact_data/provedor_alfa_copia.csv', NULL)
  , ('contact_data/provedor_beta.jsonl', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ data_de_entrega('entrada', 'alfa') }} AS obtido
  FROM tCasos
)

SELECT
  entrada
  , esperado
  , obtido
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
