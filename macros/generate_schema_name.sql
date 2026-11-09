{#
  O schema sai da pasta do modelo, não de configuração:
    models/bronze/<fonte>/...  ->  bronze_<fonte>
    models/silver/<fonte>/...  ->  silver_<fonte>
    models/<outra_camada>/...  ->  <outra_camada> (ex.: gold)
  Bronze e silver sem subpasta de fonte são erro de compilação.
  Nós que não são modelos (testes, seeds, snapshots) seguem o comportamento padrão do dbt.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- if node.resource_type != 'model' -%}
    {{ return(default__generate_schema_name(custom_schema_name, node)) }}
  {%- endif -%}

  {#- fqn = [projeto, camada, (fonte), ..., nome do modelo] -#}
  {%- set camada = node.fqn[1] -%}

  {%- if camada in ['bronze', 'silver'] -%}
    {%- if node.fqn | length < 4 -%}
      {{ exceptions.raise_compiler_error(
        "O modelo '" ~ node.name ~ "' está em models/" ~ camada ~ "/ sem pasta de fonte. "
        ~ "Mova-o para models/" ~ camada ~ "/<fonte>/."
      ) }}
    {%- endif -%}
    {{ return(camada ~ '_' ~ node.fqn[2]) }}
  {%- endif -%}

  {{ return(camada) }}
{%- endmacro %}
