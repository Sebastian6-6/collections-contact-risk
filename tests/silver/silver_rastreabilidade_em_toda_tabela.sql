{#
  Toda tabela da silver tem de carregar `_arquivo`, `_linha` e `_hash_arquivo` (AGENTS.md, seção
  "Stack": a rastreabilidade de cada linha vem do nome, do número da linha e do hash do arquivo
  de origem). Devolve uma linha para cada tabela e coluna que faltam. As etapas efêmeras não viram
  tabela e ficam de fora. O `not_null` das três colunas está no YAML de cada tabela.
  As linhas `depends_on` fazem o dbt construir as tabelas antes do teste; o `depends_on` não aceita
  laço, então uma tabela nova da silver entra aqui também (a checagem em si já a pega pelo grafo).
#}
-- depends_on: {{ ref('silver_alfa_devedores') }}
-- depends_on: {{ ref('silver_alfa_devedores_contatos') }}
-- depends_on: {{ ref('silver_alfa_devedores_enderecos') }}
-- depends_on: {{ ref('silver_beta_devedores') }}
-- depends_on: {{ ref('silver_beta_devedores_contatos') }}
-- depends_on: {{ ref('silver_beta_devedores_enderecos') }}
-- depends_on: {{ ref('silver_gama_devedores') }}
-- depends_on: {{ ref('silver_gama_devedores_contatos') }}
-- depends_on: {{ ref('silver_gama_devedores_enderecos') }}
-- depends_on: {{ ref('silver_alfa_devedores_historico') }}
-- depends_on: {{ ref('silver_beta_devedores_historico') }}
-- depends_on: {{ ref('silver_beta_devedores_historico_contatos') }}
-- depends_on: {{ ref('silver_beta_devedores_historico_enderecos') }}
-- depends_on: {{ ref('silver_gama_devedores_historico') }}
-- depends_on: {{ ref('silver_gama_devedores_historico_contatos') }}
-- depends_on: {{ ref('silver_cobranca_contatos_realizados') }}
-- depends_on: {{ ref('silver_cobranca_contatos_realizados_provedores') }}
-- depends_on: {{ ref('silver_receita_empresas') }}
-- depends_on: {{ ref('silver_receita_estabelecimentos') }}
-- depends_on: {{ ref('silver_receita_estabelecimentos_cnaes_secundarios') }}
-- depends_on: {{ ref('silver_receita_simples') }}
-- depends_on: {{ ref('silver_receita_socios') }}
-- depends_on: {{ ref('silver_receita_cnaes') }}
-- depends_on: {{ ref('silver_receita_motivos') }}
-- depends_on: {{ ref('silver_receita_municipios') }}
-- depends_on: {{ ref('silver_receita_naturezas') }}
-- depends_on: {{ ref('silver_receita_paises') }}
-- depends_on: {{ ref('silver_receita_qualificacoes') }}
{% set exigidas = [] %}
{% for coluna in ['_arquivo', '_linha', '_hash_arquivo'] %}
  {% do exigidas.append("SELECT '" ~ coluna ~ "' AS coluna") %}
{% endfor %}
{% set tabelas = [] %}
{% if execute %}
  {% for no in graph.nodes.values() %}
    {% if no.resource_type == 'model' and no.fqn[1] == 'silver' %}
      {% if no.config.materialized != 'ephemeral' %}
        {% set linha = "SELECT '" ~ no.schema ~ "' AS esquema, '" ~ no.alias ~ "' AS tabela" %}
        {% do tabelas.append(linha) %}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endif %}

WITH tTabelas AS (
  {{ tabelas | join('
  UNION ALL
  ') }}
)

, tExigidas AS (
  {{ exigidas | join('
  UNION ALL
  ') }}
)

, tEsperadas AS (
  SELECT
    t.esquema
    , t.tabela
    , x.coluna
  FROM tTabelas AS t
  CROSS JOIN tExigidas AS x
)

SELECT
  e.esquema
  , e.tabela
  , e.coluna
FROM tEsperadas AS e
LEFT JOIN information_schema.columns AS c
  ON e.esquema = c.table_schema
    AND e.tabela = c.table_name
    AND e.coluna = c.column_name
WHERE 1 = 1
  AND c.column_name IS NULL
