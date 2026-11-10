{#
  Etapa comum da gold de devedores: o conteúdo de vínculo de cada versão da histórica, das três
  fontes, no mesmo formato. Grão: uma versão (`hash_conteudo`), a mesma da histórica de cada
  provedor, só as que têm documento. Conteúdo do vínculo:
    - alfa: `cnpj_empregador`, `cargo`, `salario_informado`;
    - beta: `vinculo_empresa_cnpj`, `vinculo_empresa_desde`, `renda_mensal`;
    - gama: `cnpj_empregador_raw` (não manda cargo nem renda).
  O `salario_informado` 0,00 do alfa vira `vl_renda` `NULL` (ponto 6): é "não informado", e a
  regra do case é que ausência de dado é `NULL`, nunca zero. A silver guarda o 0,00 como veio.
  Alfa e gama não mandam o mês de início, `dt_inicio_vinculo` fica `NULL` para elas. É efêmero:
  existe para `ft_vinculo_empresa` abrir os períodos a partir de um só lugar.
#}
{{ config(materialized='ephemeral') }}

WITH tAlfa AS (
  SELECT
    'alfa' AS provedor
    , 'CPF' AS documento_tipo
    , documento
    , hash_conteudo
    , cnpj_empregador AS cnpj
    , cargo
    , CAST(NULL AS DATE) AS dt_inicio_vinculo
    , data_atualizacao AS dt_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , NULLIF(salario_informado, 0) AS vl_renda
  FROM {{ ref('silver_alfa_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

, tBeta AS (
  SELECT
    'beta' AS provedor
    , documento_tipo
    , documento
    , hash_conteudo
    , vinculo_empresa_cnpj AS cnpj
    , CAST(NULL AS VARCHAR) AS cargo
    , renda_mensal AS vl_renda
    , vinculo_empresa_desde AS dt_inicio_vinculo
    , atualizado_em AS dt_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_beta_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

, tGama AS (
  SELECT
    'gama' AS provedor
    , 'CPF' AS documento_tipo
    , documento
    , hash_conteudo
    , cnpj_empregador_raw AS cnpj
    , CAST(NULL AS VARCHAR) AS cargo
    , CAST(NULL AS NUMERIC(14, 2)) AS vl_renda
    , CAST(NULL AS DATE) AS dt_inicio_vinculo
    , dt_ref AS dt_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('silver_gama_devedores_historico') }}
  WHERE 1 = 1
    AND documento IS NOT NULL
)

SELECT
  provedor
  , documento_tipo
  , documento
  , hash_conteudo
  , cnpj
  , cargo
  , vl_renda
  , dt_inicio_vinculo
  , dt_atualizacao
  , data_primeira_entrega
  , data_ultima_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tAlfa

UNION ALL

SELECT
  provedor
  , documento_tipo
  , documento
  , hash_conteudo
  , cnpj
  , cargo
  , vl_renda
  , dt_inicio_vinculo
  , dt_atualizacao
  , data_primeira_entrega
  , data_ultima_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tBeta

UNION ALL

SELECT
  provedor
  , documento_tipo
  , documento
  , hash_conteudo
  , cnpj
  , cargo
  , vl_renda
  , dt_inicio_vinculo
  , dt_atualizacao
  , data_primeira_entrega
  , data_ultima_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tGama
