{#
  Endereço em caixas diferentes é o mesmo endereço (H4): em `devedores_enderecos` de cada fonte, não
  pode haver dois pares do mesmo documento cujas partes só diferem na caixa do texto. Cada linha
  devolvida é um par repetido; deve ser vazio. Compara em minúscula para pegar também o texto que
  escapasse da maiúscula na padronização. No gama o complemento chama-se `endereco_json_complemento`.
#}
WITH tPares AS (
  SELECT
    'alfa' AS fonte
    , documento
    , LOWER(logradouro) AS logradouro
    , LOWER(numero) AS numero
    , LOWER(complemento) AS complemento
    , LOWER(bairro) AS bairro
    , LOWER(cidade) AS cidade
    , LOWER(uf) AS uf
    , cep
  FROM {{ ref('silver_alfa_devedores_enderecos') }}

  UNION ALL

  SELECT
    'beta' AS fonte
    , documento
    , LOWER(logradouro) AS logradouro
    , LOWER(numero) AS numero
    , LOWER(complemento) AS complemento
    , LOWER(bairro) AS bairro
    , LOWER(cidade) AS cidade
    , LOWER(uf) AS uf
    , cep
  FROM {{ ref('silver_beta_devedores_enderecos') }}

  UNION ALL

  SELECT
    'gama' AS fonte
    , documento
    , LOWER(logradouro) AS logradouro
    , LOWER(numero) AS numero
    , LOWER(endereco_json_complemento) AS complemento
    , LOWER(bairro) AS bairro
    , LOWER(cidade) AS cidade
    , LOWER(uf) AS uf
    , cep
  FROM {{ ref('silver_gama_devedores_enderecos') }}
)

SELECT
  fonte
  , documento
  , logradouro
  , numero
  , complemento
  , bairro
  , cidade
  , uf
  , cep
  , COUNT(*) AS qt_pares
FROM tPares
GROUP BY
  fonte
  , documento
  , logradouro
  , numero
  , complemento
  , bairro
  , cidade
  , uf
  , cep
HAVING COUNT(*) > 1
