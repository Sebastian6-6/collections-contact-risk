{#
  Etapa comum da silver do alfa: toda linha da bronze com documento, já padronizada e sem
  deduplicar. Grão: uma linha por linha recebida que tem documento (`_arquivo`, `_linha`).
  É efêmera: não vira tabela. Existe para `devedores` (que fica com a versão mais recente) e
  `devedores_contatos` (que olha todas as versões) padronizarem do mesmo jeito, num lugar só.
#}
{{ config(materialized='ephemeral') }}

WITH tBase AS (
  SELECT
    nome_completo
    , data_nascimento
    , cnpj_empregador
    , cargo
    , salario_informado
    , telefone
    , email
    , endereco
    , cep
    , uf
    , data_atualizacao
    , _arquivo
    , _linha
    , _hash_arquivo
    , COALESCE(NULLIF(TRIM(cpf), ''), NULLIF(TRIM(documento), '')) AS documento_origem
  FROM {{ source('bronze_alfa', 'devedores') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tPadronizada AS (
  SELECT
    {{ cpf_normalizado('documento_origem') }} AS documento
    , NULLIF(TRIM(nome_completo), '') AS nome_completo
    , {{ data_flexivel('data_nascimento') }} AS data_nascimento
    , {{ cnpj_normalizado('cnpj_empregador') }} AS cnpj_empregador
    , NULLIF(TRIM(cargo), '') AS cargo
    , {{ valor_monetario('salario_informado') }} AS salario_informado
    , {{ telefone_normalizado('telefone') }} AS telefone
    , {{ email_normalizado('email') }} AS email
    , NULLIF(TRIM(endereco), '') AS endereco
    , LPAD({{ somente_digitos('cep') }}, 8, '0') AS cep
    , NULLIF(TRIM(uf), '') AS uf
    , {{ data_flexivel('data_atualizacao') }} AS data_atualizacao
    , {{ data_de_entrega('_arquivo', 'alfa') }} AS data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tBase
)

, tComEndereco AS (
  SELECT
    documento
    , nome_completo
    , data_nascimento
    , cnpj_empregador
    , cargo
    , salario_informado
    , telefone
    , email
    , endereco
    , {{ endereco_parte('endereco', 1) }} AS logradouro
    , {{ endereco_parte('endereco', 2) }} AS numero
    , {{ endereco_parte('endereco', 3) }} AS complemento
    , {{ endereco_parte('endereco', 4) }} AS bairro
    , {{ endereco_parte('endereco', 5) }} AS cidade
    , cep
    , uf
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tPadronizada
  WHERE 1 = 1
    AND documento IS NOT NULL
)

SELECT
  documento
  , nome_completo
  , data_nascimento
  , cnpj_empregador
  , cargo
  , salario_informado
  , telefone
  , email
  , endereco
  , logradouro
  , numero
  , complemento
  , bairro
  , cidade
  , cep
  , uf
  , data_atualizacao
  , data_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tComEndereco
