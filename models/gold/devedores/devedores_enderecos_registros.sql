{#
  Etapa comum da gold de devedores: os endereços recebidos das três fontes (`devedores_enderecos`
  da silver), empilhados no mesmo formato. Grão: um par documento × endereço padronizado por
  provedor (`provedor`, `documento_tipo`, `documento`, `hash_endereco`), o mesmo da silver; o
  documento é `NULL` na versão sem documento. Alfa e gama só têm CPF. `tipo_endereco` só o beta
  manda; o texto original (`endereco`) só alfa e gama mandam. O complemento da gama
  (`endereco_json_complemento`) sai como `complemento`. É efêmero: existe para `dim_endereco`
  partir de um só lugar.
#}
{{ config(materialized='ephemeral') }}

SELECT
  'alfa' AS provedor
  , 'CPF' AS documento_tipo
  , documento
  , hash_endereco
  , CAST(NULL AS VARCHAR) AS tipo_endereco
  , endereco
  , logradouro
  , numero AS numero_endereco
  , complemento
  , bairro
  , cidade
  , uf
  , cep
  , data_primeira_entrega
  , data_ultima_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM {{ ref('silver_alfa_devedores_enderecos') }}

UNION ALL

SELECT
  'beta' AS provedor
  , documento_tipo
  , documento
  , hash_endereco
  , tipo AS tipo_endereco
  , CAST(NULL AS VARCHAR) AS endereco
  , logradouro
  , numero AS numero_endereco
  , complemento
  , bairro
  , cidade
  , uf
  , cep
  , data_primeira_entrega
  , data_ultima_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM {{ ref('silver_beta_devedores_enderecos') }}

UNION ALL

SELECT
  'gama' AS provedor
  , 'CPF' AS documento_tipo
  , documento
  , hash_endereco
  , CAST(NULL AS VARCHAR) AS tipo_endereco
  , endereco
  , logradouro
  , numero AS numero_endereco
  , endereco_json_complemento AS complemento
  , bairro
  , cidade
  , uf
  , cep
  , data_primeira_entrega
  , data_ultima_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM {{ ref('silver_gama_devedores_enderecos') }}
