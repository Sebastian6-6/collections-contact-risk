{#
  Etapa comum da gold de devedores: os pares documento × contato das três fontes (`devedores_contatos`
  da silver, de todas as versões), empilhados no mesmo formato. Grão: um par por provedor
  (`provedor`, `documento_tipo`, `documento`, `tipo_contato`, `contato`), o mesmo da silver; o
  documento é `NULL` na versão sem documento. Alfa e gama só têm CPF. Traz também a última entrega
  de cada provedor (`dt_ultima_entrega_provedor`, a maior última entrega entre os contatos dele),
  para saber se o par ainda aparece nas entregas. É efêmero: existe para `devedores_contatos_pares`
  partir de um só lugar.
#}
{{ config(materialized='ephemeral') }}

WITH tContatos AS (
  SELECT
    'alfa' AS provedor
    , 'CPF' AS documento_tipo
    , documento
    , tipo_contato
    , contato
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_alfa_devedores_contatos') }}

  UNION ALL

  SELECT
    'beta' AS provedor
    , documento_tipo
    , documento
    , tipo_contato
    , contato
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_beta_devedores_contatos') }}

  UNION ALL

  SELECT
    'gama' AS provedor
    , 'CPF' AS documento_tipo
    , documento
    , tipo_contato
    , contato
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_gama_devedores_contatos') }}
)

, tEntregasDoProvedor AS (
  SELECT
    provedor
    , MAX(data_ultima_entrega) AS dt_ultima_entrega_provedor
  FROM tContatos
  GROUP BY provedor
)

SELECT
  tContatos.provedor
  , tContatos.documento_tipo
  , tContatos.documento
  , tContatos.tipo_contato
  , tContatos.contato
  , tContatos.data_primeira_entrega
  , tContatos.data_ultima_entrega
  , tEntregasDoProvedor.dt_ultima_entrega_provedor
  , tContatos._arquivo
  , tContatos._linha
  , tContatos._hash_arquivo
FROM tContatos
INNER JOIN tEntregasDoProvedor
  ON tContatos.provedor = tEntregasDoProvedor.provedor
