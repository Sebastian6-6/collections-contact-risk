{#
  Etapa comum da gold de devedores: a versão atual de cada documento das três fontes, empilhada
  no mesmo formato. Grão: uma linha por provedor e documento (`provedor`, `documento_tipo`,
  `documento`), o mesmo grão das `silver_<fonte>.devedores`. Alfa e gama só têm CPF; o beta traz
  `CPF` ou `RG`. O perfil (estado civil, dependentes, score, escolaridade, imóvel e fonte do score)
  só a gama manda: nas outras fontes é `NULL` estrutural.
  `nome_chave` é o nome para comparar entre provedores (`nome_comparavel`). `nascimento_confiavel`
  separa a data que pode votar: a sentinela 1900-01-01 e a data posterior à entrega da própria
  linha (nasceu depois de ser entregue) não votam, mas continuam na coluna `dt_nascimento`, como
  vieram. `hash_conteudo` é o da versão atual na silver (liga à histórica). É efêmero: existe
  para `devedores_documentos` (liga os documentos) e `dim_devedor` (escolhe os atributos)
  partirem das mesmas linhas.
#}
{{ config(materialized='ephemeral') }}

WITH tAlfa AS (
  SELECT
    'alfa' AS provedor
    , 'CPF' AS documento_tipo
    , documento
    , nome_completo AS nome_devedor
    , data_nascimento AS dt_nascimento
    , data_atualizacao AS dt_atualizacao
    , data_entrega AS dt_entrega
    , hash_conteudo
    , CAST(NULL AS VARCHAR) AS estado_civil
    , CAST(NULL AS VARCHAR) AS escolaridade
    , CAST(NULL AS VARCHAR) AS fonte_score
    , CAST(NULL AS INTEGER) AS qt_dependentes
    , CAST(NULL AS INTEGER) AS score_externo
    , CAST(NULL AS BOOLEAN) AS flag_possui_imovel
  FROM {{ ref('silver_alfa_devedores') }}
)

, tBeta AS (
  SELECT
    'beta' AS provedor
    , documento_tipo
    , documento
    , nome_completo AS nome_devedor
    , data_nascimento AS dt_nascimento
    , atualizado_em AS dt_atualizacao
    , data_entrega AS dt_entrega
    , hash_conteudo
    , CAST(NULL AS VARCHAR) AS estado_civil
    , CAST(NULL AS VARCHAR) AS escolaridade
    , CAST(NULL AS VARCHAR) AS fonte_score
    , CAST(NULL AS INTEGER) AS qt_dependentes
    , CAST(NULL AS INTEGER) AS score_externo
    , CAST(NULL AS BOOLEAN) AS flag_possui_imovel
  FROM {{ ref('silver_beta_devedores') }}
)

, tGama AS (
  SELECT
    'gama' AS provedor
    , 'CPF' AS documento_tipo
    , documento
    , nome AS nome_devedor
    , data_nascimento AS dt_nascimento
    , dt_ref AS dt_atualizacao
    , data_entrega AS dt_entrega
    , hash_conteudo
    , atributos_extra_estado_civil AS estado_civil
    , atributos_extra_escolaridade AS escolaridade
    , atributos_extra_fonte_score AS fonte_score
    , atributos_extra_qtd_dependentes AS qt_dependentes
    , atributos_extra_score_externo AS score_externo
    , atributos_extra_possui_imovel AS flag_possui_imovel
  FROM {{ ref('silver_gama_devedores') }}
)

, tEmpilhados AS (
  SELECT
    provedor
    , documento_tipo
    , documento
    , nome_devedor
    , dt_nascimento
    , dt_atualizacao
    , dt_entrega
    , hash_conteudo
    , estado_civil
    , escolaridade
    , fonte_score
    , qt_dependentes
    , score_externo
    , flag_possui_imovel
  FROM tAlfa

  UNION ALL

  SELECT
    provedor
    , documento_tipo
    , documento
    , nome_devedor
    , dt_nascimento
    , dt_atualizacao
    , dt_entrega
    , hash_conteudo
    , estado_civil
    , escolaridade
    , fonte_score
    , qt_dependentes
    , score_externo
    , flag_possui_imovel
  FROM tBeta

  UNION ALL

  SELECT
    provedor
    , documento_tipo
    , documento
    , nome_devedor
    , dt_nascimento
    , dt_atualizacao
    , dt_entrega
    , hash_conteudo
    , estado_civil
    , escolaridade
    , fonte_score
    , qt_dependentes
    , score_externo
    , flag_possui_imovel
  FROM tGama
)

SELECT
  provedor
  , documento_tipo
  , documento
  , nome_devedor
  , {{ nome_comparavel('nome_devedor') }} AS nome_chave
  , dt_nascimento
  , COALESCE(
    dt_nascimento <> DATE '1900-01-01' AND dt_nascimento <= dt_entrega
    , FALSE
  ) AS nascimento_confiavel
  , dt_atualizacao
  , dt_entrega
  , hash_conteudo
  , estado_civil
  , escolaridade
  , fonte_score
  , qt_dependentes
  , score_externo
  , flag_possui_imovel
FROM tEmpilhados
