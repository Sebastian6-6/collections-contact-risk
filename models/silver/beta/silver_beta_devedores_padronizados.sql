{#
  Etapa comum da silver do beta: toda linha da bronze com JSON válido, já padronizada e sem
  deduplicar. Grão: uma linha por linha recebida com JSON válido (`_arquivo`, `_linha`).
  `vinculo_empresa_desde` é o mês do vínculo (AAAA-MM) e vira DATE no dia 01.
  Documento vazio ou só com zeros vira `documento` NULL (e `documento_tipo` também, já que não há
  documento para tipar), e a linha continua aqui: `devedores` a deixa de fora (não há chave) e
  `devedores_contatos` guarda os contatos dela sem documento. É efêmera: não vira tabela. Existe para `devedores` (que fica com a
  versão mais recente) e para `devedores_contatos` e `devedores_enderecos` (que abrem as listas)
  padronizarem do mesmo jeito, num lugar só.

  O JSON do beta tem 12 combinações de chaves (docs/perfil-das-fontes.md). Cada variante vira
  uma coluna de nome fixo, juntando as chaves equivalentes com COALESCE (S6):
    - documento: `cpf` (texto) ou `documento` {tipo, valor};
    - nome: `nome_completo`, `nome` ou `nome_devedor`;
    - e-mail: lista `contato.emails` ou texto `contato.email`;
    - endereço: lista `enderecos` ou objeto `endereco`;
    - data de atualização: ISO 8601 ou epoch em milissegundos;
    - renda: número, texto "R$ x,xx" ou nulo.
  As listas de telefone, e-mail e endereço seguem como JSON: quem muda de grão as abre.
#}
{{ config(materialized='ephemeral') }}
{%- set documento_alfanumerico -%}
  NULLIF(REGEXP_REPLACE(UPPER(documento_origem), '[^0-9A-Z]', '', 'g'), '')
{%- endset %}
{%- set nome_origem -%}
  COALESCE(
    NULLIF(TRIM(registro_json ->> 'nome_completo'), '')
    , NULLIF(TRIM(registro_json ->> 'nome'), '')
    , NULLIF(TRIM(registro_json ->> 'nome_devedor'), '')
  )
{%- endset %}

WITH tBase AS (
  SELECT
    {{ json_ou_nulo('registro') }} AS registro_json
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ source('bronze_beta', 'devedores') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tCampos AS (
  SELECT
    _arquivo
    , _linha
    , _hash_arquivo
    , COALESCE(
      NULLIF(UPPER(TRIM((registro_json -> 'documento') ->> 'tipo')), '')
      , CASE WHEN NULLIF(TRIM(registro_json ->> 'cpf'), '') IS NOT NULL THEN 'CPF' END
    ) AS documento_tipo
    , COALESCE(
      NULLIF(TRIM(registro_json ->> 'cpf'), '')
      , NULLIF(TRIM((registro_json -> 'documento') ->> 'valor'), '')
    ) AS documento_origem
    , {{ texto_maiusculo(nome_origem) }} AS nome_completo
    , registro_json ->> 'data_nascimento' AS data_nascimento
    , {{ cnpj_sem_mascara("(registro_json -> 'vinculo_empresa') ->> 'cnpj'") }}
      AS vinculo_empresa_cnpj
    , NULLIF(TRIM((registro_json -> 'vinculo_empresa') ->> 'desde'), '') AS vinculo_empresa_desde
    , registro_json ->> 'renda_mensal' AS renda_mensal
    , registro_json ->> 'atualizado_em' AS atualizado_em
    , (registro_json -> 'contato') -> 'telefones' AS lista_telefones
    , (registro_json -> 'contato') -> 'emails' AS lista_emails
    , (registro_json -> 'contato') ->> 'email' AS email_unico
    , registro_json -> 'enderecos' AS lista_enderecos
    , registro_json -> 'endereco' AS endereco_unico
  FROM tBase
  WHERE 1 = 1
    AND registro_json IS NOT NULL
)

, tPadronizada AS (
  SELECT
    documento_tipo
    , CASE
      WHEN documento_tipo = 'CPF' THEN {{ cpf_normalizado('documento_origem') }}
      ELSE {{ nulo_se_so_zeros(documento_alfanumerico) }}
    END AS documento
    , nome_completo
    , {{ data_flexivel('data_nascimento') }} AS data_nascimento
    , {{ cnpj_normalizado('vinculo_empresa_cnpj') }} AS vinculo_empresa_cnpj
    , {{ mes_como_data('vinculo_empresa_desde') }} AS vinculo_empresa_desde
    , {{ valor_monetario('renda_mensal') }} AS renda_mensal
    , {{ data_flexivel('atualizado_em') }} AS atualizado_em
    , {{ data_de_entrega('_arquivo', 'beta') }} AS data_entrega
    , lista_telefones
    , lista_emails
    , {{ email_normalizado('email_unico') }} AS email_unico
    , lista_enderecos
    , endereco_unico
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tCampos
)

SELECT
  documento
  , nome_completo
  , data_nascimento
  , vinculo_empresa_cnpj
  , vinculo_empresa_desde
  , renda_mensal
  , atualizado_em
  , data_entrega
  , lista_telefones
  , lista_emails
  , email_unico
  , lista_enderecos
  , endereco_unico
  , _arquivo
  , _linha
  , _hash_arquivo
  , CASE WHEN documento IS NOT NULL THEN documento_tipo END AS documento_tipo
FROM tPadronizada
WHERE 1 = 1
  AND (documento IS NULL OR documento_tipo IS NOT NULL)
