{#
  Falha para cada caso em que `cnpj_normalizado` devolve algo diferente do esperado. Os dígitos
  verificadores esperados vêm da regra oficial da Receita (00.000.000/0001-91 e o exemplo
  alfanumérico 12.ABC.345/01DE-35 do manual) e dos CNPJs que a base traz.
#}
WITH tCasos (entrada, esperado) AS (
  VALUES
  -- 14 caracteres: ficam como vieram
  ('00000000000191', '00000000000191')
  , ('00.000.000/0001-91', '00000000000191')
  , ('A7K2M9Q4000140', 'A7K2M9Q4000140')
  , ('a7.k2m.9q4/0001-40', 'A7K2M9Q4000140')
  , ('3RT8XB51000136', '3RT8XB51000136')
  -- menos de 14, completa com zeros quando os dígitos verificadores batem
  , ('191', '00000000000191')
  , ('4182736500157', '04182736500157')
  , ('7526557000100', '07526557000100')
  -- 12 caracteres: completar com zeros daria um CNPJ válido, então completa
  , ('360305000104', '00360305000104')
  -- 12 caracteres: completar com zeros não daria válido, então calcula os dois dígitos
  , ('000000000001', '00000000000191')
  , ('12ABC34501DE', '12ABC34501DE35')
  , ('12.ABC.345/01DE', '12ABC34501DE35')
  , ('607469480001', '60746948000112')
  , ('Z0P4LC220001', 'Z0P4LC22000124')
  , ('3RT8XB510001', '3RT8XB51000136')
  -- sem regra que encaixe: fica como veio (limitação da base)
  , ('1234567', '1234567')
  , ('CNPJEMPREGADORRAW', 'CNPJEMPREGADORRAW')
  , ('123456789012345', '123456789012345')
  , ('', NULL)
  , (NULL, NULL)
)

, tResultado AS (
  SELECT
    entrada
    , esperado
    , {{ cnpj_normalizado(cnpj_sem_mascara('entrada')) }} AS obtido
  FROM tCasos
)

SELECT *
FROM tResultado
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
