{#
  Etapa comum da gold de devedores: a versão vigente de cada devedor. Grão: um devedor (`cpf`).
  Entre as versões atuais dos provedores (`devedores_registros`) de todos os documentos ligados
  ao devedor, vale a de data de atualização mais recente, como veio (inclusive 2025-09-01, ponto
  9/a2); depois a de entrega mais recente, o documento do próprio CPF e o nome do provedor, para
  o empate ser determinístico. Dela saem o endereço `atual` e o vínculo `atual` (G3b, mutáveis).
  É efêmero: existe para `dim_endereco` e `ft_vinculo_empresa` usarem a mesma escolha.
#}
{{ config(materialized='ephemeral') }}

WITH tRegistros AS (
  SELECT
    devedores_documentos.cpf
    , devedores_registros.provedor
    , devedores_registros.documento_tipo
    , devedores_registros.documento
    , devedores_registros.hash_conteudo
    , devedores_registros.dt_atualizacao
    , devedores_registros.dt_entrega
  FROM {{ ref('devedores_registros') }} AS devedores_registros
  INNER JOIN {{ ref('devedores_documentos') }} AS devedores_documentos
    ON devedores_registros.documento_tipo = devedores_documentos.documento_tipo
      AND devedores_registros.documento = devedores_documentos.documento
  WHERE 1 = 1
    AND devedores_documentos.cpf IS NOT NULL
)

, tOrdenados AS (
  SELECT
    cpf
    , provedor
    , documento_tipo
    , documento
    , hash_conteudo
    , ROW_NUMBER() OVER (
      PARTITION BY cpf
      ORDER BY
        dt_atualizacao DESC NULLS LAST
        , dt_entrega DESC NULLS LAST
        , CASE WHEN documento = cpf THEN 0 ELSE 1 END ASC
        , provedor ASC
        , documento_tipo ASC
        , documento ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM tRegistros
)

SELECT
  cpf
  , provedor
  , documento_tipo
  , documento
  , hash_conteudo
FROM tOrdenados
WHERE 1 = 1
  AND num_versao = 1
