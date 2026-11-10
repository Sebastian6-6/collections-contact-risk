{#
  Etapa comum da silver do gama: toda linha da bronze lida, já padronizada e sem deduplicar.
  Grão: uma linha por linha recebida (`_arquivo`, `_linha`). Documento vazio ou só com zeros vira
  `documento` NULL, e a linha continua aqui: `devedores` a deixa de fora (não há chave) e
  `devedores_contatos` guarda os contatos dela sem documento. É
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
  Os campos de `atributos_extra` e o `complemento` do `endereco_json` viram colunas `<objeto>_<chave>`
  (`atributos_extra_score_externo`, `endereco_json_complemento`). `dt_ref` e `cnpj_empregador_raw` mantêm o nome da fonte; a medição de `dt_ref` como data de
  atualização está no YAML do modelo `silver_gama_devedores`.
#}
{{ config(materialized='ephemeral') }}
{%- set uf_origem -%}
  COALESCE(NULLIF(TRIM(endereco_json ->> 'uf'), ''), NULLIF(TRIM(endereco_json ->> 'estado'), ''))
{%- endset %}
{%- set endereco_origem -%}
  COALESCE(
    NULLIF(TRIM(endereco_json ->> 'rua'), '')
    , NULLIF(TRIM(endereco_json ->> 'endereco'), '')
  )
{%- endset %}
{%- set cidade_origem -%}
  COALESCE(
    NULLIF(TRIM(endereco_json ->> 'cidade'), '')
    , NULLIF(TRIM(endereco_json ->> 'municipio'), '')
  )
{%- endset %}

WITH tBase AS (
  SELECT
    {{ cpf_normalizado('documento') }} AS documento
    , {{ texto_maiusculo("NULLIF(TRIM(nome), '')") }} AS nome
    , data_nascimento
    , {{ cnpj_sem_mascara('cnpj_empregador_raw') }} AS cnpj_empregador_raw
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
    , {{ cnpj_normalizado('cnpj_empregador_raw') }} AS cnpj_empregador_raw
    , NULLIF(TRIM(atributos_json ->> 'estado_civil'), '') AS atributos_extra_estado_civil
    , CAST(
      NULLIF(TRIM(atributos_json ->> 'qtd_dependentes'), '') AS INTEGER
    ) AS atributos_extra_qtd_dependentes
    , CAST(
      NULLIF(TRIM(atributos_json ->> 'score_externo'), '') AS INTEGER
    ) AS atributos_extra_score_externo
    , NULLIF(TRIM(atributos_json ->> 'escolaridade'), '') AS atributos_extra_escolaridade
    , CAST(
      NULLIF(TRIM(atributos_json ->> 'possui_imovel'), '') AS BOOLEAN
    ) AS atributos_extra_possui_imovel
    , NULLIF(TRIM(atributos_json ->> 'fonte_score'), '') AS atributos_extra_fonte_score
    , {{ texto_maiusculo(endereco_origem) }} AS endereco
    , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'rua'), '')") }} AS endereco_rua
    , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'endereco'), '')") }}
      AS endereco_rua_bairro
    , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'logradouro'), '')") }}
      AS logradouro_origem
    , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'numero'), '')") }}
      AS numero_origem
    , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'complemento'), '')") }}
      AS endereco_json_complemento
    , {{ texto_maiusculo("NULLIF(TRIM(endereco_json ->> 'bairro'), '')") }} AS bairro_origem
    , {{ texto_maiusculo(cidade_origem) }} AS cidade
    , {{ uf_normalizada(uf_origem) }} AS uf
    , LPAD({{ somente_digitos("endereco_json ->> 'cep'") }}, 8, '0') AS cep
    , {{ data_flexivel('dt_ref') }} AS dt_ref
    , {{ data_de_entrega('_arquivo', 'gama') }} AS data_entrega
    , lista_contatos
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tBase
)

SELECT
  documento
  , nome
  , data_nascimento
  , cnpj_empregador_raw
  , atributos_extra_estado_civil
  , atributos_extra_qtd_dependentes
  , atributos_extra_score_externo
  , atributos_extra_escolaridade
  , atributos_extra_possui_imovel
  , atributos_extra_fonte_score
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
  , endereco_json_complemento
  , COALESCE(
    bairro_origem
    , {{ endereco_parte('endereco_rua_bairro', 3, endereco_padrao_rua_bairro()) }}
  ) AS bairro
  , cidade
  , uf
  , cep
  , dt_ref
  , data_entrega
  , lista_contatos
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tCampos
