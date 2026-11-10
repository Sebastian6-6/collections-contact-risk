{#
  Etapa comum da gold de devedores: o endereço vigente de cada devedor, no formato do par da
  silver. Grão: um endereço (`provedor`, `documento`, `hash_endereco`) que está na versão vigente
  do devedor (`devedores_versao_vigente`). Alfa e gama têm um endereço por versão; no beta valem
  só os endereços marcados `atual` nessa versão. O `hash_endereco` é recalculado com a mesma
  macro e a mesma ordem de partes da silver, a partir das colunas da histórica. É efêmero: existe
  para `dim_endereco` marcar `situacao_endereco`.
#}
{{ config(materialized='ephemeral') }}
{%- set partes_alfa = [
  'logradouro', 'numero', 'complemento', 'bairro', 'cidade', 'uf', 'cep'
  , 'CASE WHEN logradouro IS NULL AND numero IS NULL AND complemento IS NULL AND bairro IS NULL AND cidade IS NULL AND uf IS NULL AND cep IS NULL THEN endereco END'
] %}
{%- set partes_gama = [
  'logradouro', 'numero', 'endereco_json_complemento', 'bairro', 'cidade', 'uf', 'cep'
  , 'CASE WHEN logradouro IS NULL AND numero IS NULL AND endereco_json_complemento IS NULL AND bairro IS NULL AND cidade IS NULL AND uf IS NULL AND cep IS NULL THEN endereco END'
] %}
{%- set partes_beta = [
  'logradouro', 'numero', 'complemento', 'bairro', 'cidade', 'uf', 'cep', 'CAST(NULL AS VARCHAR)'
] %}

SELECT DISTINCT
  historico.hash_conteudo
  , 'alfa' AS provedor
  , historico.documento
  , {{ hash_conteudo(partes_alfa) }} AS hash_endereco
FROM {{ ref('silver_alfa_devedores_historico') }} AS historico
INNER JOIN {{ ref('devedores_versao_vigente') }} AS devedores_versao_vigente
  ON historico.hash_conteudo = devedores_versao_vigente.hash_conteudo
    AND devedores_versao_vigente.provedor = 'alfa'

UNION ALL

SELECT DISTINCT
  historico.hash_conteudo
  , 'gama' AS provedor
  , historico.documento
  , {{ hash_conteudo(partes_gama) }} AS hash_endereco
FROM {{ ref('silver_gama_devedores_historico') }} AS historico
INNER JOIN {{ ref('devedores_versao_vigente') }} AS devedores_versao_vigente
  ON historico.hash_conteudo = devedores_versao_vigente.hash_conteudo
    AND devedores_versao_vigente.provedor = 'gama'

UNION ALL

SELECT DISTINCT
  historico_enderecos.hash_conteudo
  , 'beta' AS provedor
  , historico.documento
  , {{ hash_conteudo(partes_beta) }} AS hash_endereco
FROM {{ ref('silver_beta_devedores_historico_enderecos') }} AS historico_enderecos
INNER JOIN {{ ref('silver_beta_devedores_historico') }} AS historico
  ON historico_enderecos.hash_conteudo = historico.hash_conteudo
INNER JOIN {{ ref('devedores_versao_vigente') }} AS devedores_versao_vigente
  ON historico_enderecos.hash_conteudo = devedores_versao_vigente.hash_conteudo
    AND devedores_versao_vigente.provedor = 'beta'
WHERE 1 = 1
  AND historico_enderecos.atual
