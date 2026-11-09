{#
  Etapa comum da silver do gama: toda linha da bronze lida e com documento, já padronizada e sem
  deduplicar. Grão: uma linha por linha recebida que tem documento (`_arquivo`, `_linha`). É
  efêmera: não vira tabela. Existe para `devedores` (que fica com a versão mais recente) e para
  `devedores_contatos` (que abre a lista de contatos de todas as versões) padronizarem do mesmo
  jeito, num lugar só.

  Três colunas trazem JSON em texto (`contatos`, `endereco_json`, `atributos_extra`); cada uma
  só é lida quando é um JSON válido, e a linha com JSON truncado não derruba a consulta (S9).
  O endereço tem três formatos (docs/perfil-das-fontes.md), que viram as mesmas colunas:
    - colunas separadas: {logradouro, numero, complemento, bairro, cidade, uf, cep};
    - `rua` = "logradouro, numero", com `municipio` e `estado`;
    - `endereco` = "logradouro, numero - bairro", com `cidade` e `uf`.
  Nos dois formatos de texto, as partes só saem quando o texto casa inteiro com o padrão estrito
  (S7); senão ficam `NULL` e o texto original continua em `endereco`.
  `dt_ref` vira `data_atualizacao`: a medição está no YAML do modelo `silver_gama_devedores`.
#}
{{ config(materialized='ephemeral') }}

WITH tBase AS (
  SELECT
    {{ cpf_normalizado('documento') }} AS documento
    , NULLIF(TRIM(nome), '') AS nome
    , data_nascimento
    , cnpj_empregador_raw
    , dt_ref
    , {{ json_ou_nulo('contatos') }} AS lista_contatos
    , {{ json_ou_nulo('endereco_json') }} AS endereco_json
    , {{ json_ou_nulo('atributos_extra') }} AS atributos_json
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ source('bronze_gama', 'devedores') }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tCampos AS (
  SELECT
    documento
    , nome
    , {{ data_flexivel('data_nascimento') }} AS data_nascimento
    , {{ cnpj_normalizado('cnpj_empregador_raw') }} AS cnpj_empregador
    , NULLIF(TRIM(atributos_json ->> 'estado_civil'), '') AS estado_civil
    , CAST(NULLIF(TRIM(atributos_json ->> 'qtd_dependentes'), '') AS INTEGER) AS qtd_dependentes
    , CAST(NULLIF(TRIM(atributos_json ->> 'score_externo'), '') AS INTEGER) AS score_externo
    , NULLIF(TRIM(atributos_json ->> 'escolaridade'), '') AS escolaridade
    , CAST(NULLIF(TRIM(atributos_json ->> 'possui_imovel'), '') AS BOOLEAN) AS possui_imovel
    , NULLIF(TRIM(atributos_json ->> 'fonte_score'), '') AS fonte_score
    , COALESCE(
      NULLIF(TRIM(endereco_json ->> 'rua'), '')
      , NULLIF(TRIM(endereco_json ->> 'endereco'), '')
    ) AS endereco
    , NULLIF(TRIM(endereco_json ->> 'rua'), '') AS endereco_rua
    , NULLIF(TRIM(endereco_json ->> 'endereco'), '') AS endereco_rua_bairro
    , NULLIF(TRIM(endereco_json ->> 'logradouro'), '') AS logradouro_origem
    , NULLIF(TRIM(endereco_json ->> 'numero'), '') AS numero_origem
    , NULLIF(TRIM(endereco_json ->> 'complemento'), '') AS complemento
    , NULLIF(TRIM(endereco_json ->> 'bairro'), '') AS bairro_origem
    , COALESCE(
      NULLIF(TRIM(endereco_json ->> 'cidade'), '')
      , NULLIF(TRIM(endereco_json ->> 'municipio'), '')
    ) AS cidade
    , COALESCE(
      NULLIF(TRIM(endereco_json ->> 'uf'), '')
      , NULLIF(TRIM(endereco_json ->> 'estado'), '')
    ) AS uf
    , LPAD({{ somente_digitos("endereco_json ->> 'cep'") }}, 8, '0') AS cep
    , {{ data_flexivel('dt_ref') }} AS data_atualizacao
    , COALESCE(
      {{ data_do_nome_do_arquivo('_arquivo') }}
      , CAST('{{ var("data_carga_historica") }}' AS DATE)
    ) AS data_entrega
    , lista_contatos
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tBase
  WHERE 1 = 1
    AND documento IS NOT NULL
)

SELECT
  documento
  , nome
  , data_nascimento
  , cnpj_empregador
  , estado_civil
  , qtd_dependentes
  , score_externo
  , escolaridade
  , possui_imovel
  , fonte_score
  , endereco
  , COALESCE(
    logradouro_origem
    , {{ endereco_parte('endereco_rua', 1, endereco_padrao_rua()) }}
    , {{ endereco_parte('endereco_rua_bairro', 1, endereco_padrao_rua_bairro()) }}
  ) AS logradouro
  , COALESCE(
    numero_origem
    , {{ endereco_parte('endereco_rua', 2, endereco_padrao_rua()) }}
    , {{ endereco_parte('endereco_rua_bairro', 2, endereco_padrao_rua_bairro()) }}
  ) AS numero
  , complemento
  , COALESCE(
    bairro_origem
    , {{ endereco_parte('endereco_rua_bairro', 3, endereco_padrao_rua_bairro()) }}
  ) AS bairro
  , cidade
  , uf
  , cep
  , data_atualizacao
  , data_entrega
  , lista_contatos
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tCampos
