{#
  Compara as colunas que a tabela tem de fato com as declaradas no YAML da fonte. Falha para
  cada coluna que está só de um lado: uma coluna nova na origem (um provedor que acrescentou ou
  renomeou um campo) ou uma declarada que sumiu. Assim a mudança de esquema aparece na bronze,
  antes de a silver trabalhar com um layout que ninguém revisou.
  Roda só em fontes (`source`): lê as colunas declaradas no grafo do dbt.
#}
{% test colunas_declaradas(model) %}

{% set declaradas = namespace(nomes=[]) %}
{% if execute %}
  {% for no in graph.sources.values() %}
    {% if no.schema == model.schema and no.identifier == model.identifier %}
      {% set declaradas.nomes = no.columns.keys() | map('lower') | list %}
    {% endif %}
  {% endfor %}
  {% if declaradas.nomes | length == 0 %}
    {{ exceptions.raise_compiler_error(
      "colunas_declaradas: nenhuma coluna declarada para " ~ model ~ ". O teste vale só para fontes."
    ) }}
  {% endif %}
{% endif %}

WITH tReais AS (
  SELECT LOWER(column_name) AS nome_coluna
  FROM information_schema.columns
  WHERE table_catalog = '{{ model.database }}'
    AND table_schema = '{{ model.schema }}'
    AND table_name = '{{ model.identifier }}'
)

, tDeclaradas AS (
  {% for nome in declaradas.nomes %}
  SELECT '{{ nome }}' AS nome_coluna
  {% if not loop.last %}
  UNION ALL
  {% endif %}
  {% endfor %}
)

SELECT
  COALESCE(r.nome_coluna, d.nome_coluna) AS nome_coluna
  , CASE
    WHEN d.nome_coluna IS NULL THEN 'na tabela e nao declarada'
    ELSE 'declarada e ausente da tabela'
  END AS situacao
FROM tReais AS r
FULL OUTER JOIN tDeclaradas AS d
  ON r.nome_coluna = d.nome_coluna
WHERE r.nome_coluna IS NULL
  OR d.nome_coluna IS NULL

{% endtest %}
