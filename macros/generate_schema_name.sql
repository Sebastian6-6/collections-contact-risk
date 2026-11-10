{#
  O schema sai da pasta do modelo, não de configuração:
    models/bronze/<fonte>/...  ->  bronze_<fonte>
    models/silver/<fonte>/...  ->  silver_<fonte>
    models/gold/<domínio>/...  ->  gold_<domínio> (ex.: gold_devedores)
    models/<outra_camada>/...  ->  <outra_camada>
  Erros de compilação:
    - `schema`/`+schema` explícito em um modelo (a pasta é a única fonte do schema);
    - modelo direto em models/, sem pasta de camada;
    - bronze ou silver sem subpasta de fonte;
    - gold sem subpasta de domínio.
  Nós que não são modelos (testes, seeds, snapshots) seguem o comportamento padrão do dbt.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- if node.resource_type != 'model' -%}
    {{ return(default__generate_schema_name(custom_schema_name, node)) }}
  {%- endif -%}

  {%- if custom_schema_name is not none -%}
    {{ exceptions.raise_compiler_error(
      "O modelo '" ~ node.name ~ "' define o schema '" ~ custom_schema_name ~ "' na configuração. "
      ~ "Neste projeto o schema sai da pasta do modelo; remova `schema`/`+schema`. "
      ~ "Veja AGENTS.md, seção 'Camadas e nomes'."
    ) }}
  {%- endif -%}

  {#- fqn = [projeto, camada, (fonte), ..., nome do modelo] -#}
  {%- if node.fqn | length < 3 -%}
    {{ exceptions.raise_compiler_error(
      "O modelo '" ~ node.name ~ "' está direto em models/, sem pasta de camada. "
      ~ "Mova-o para models/bronze/<fonte>/, models/silver/<fonte>/ ou models/gold/<domínio>/."
    ) }}
  {%- endif -%}

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

  {%- if camada == 'gold' -%}
    {%- if node.fqn | length < 4 -%}
      {{ exceptions.raise_compiler_error(
        "O modelo '" ~ node.name ~ "' está em models/gold/ sem pasta de domínio. "
        ~ "Mova-o para models/gold/<domínio>/."
      ) }}
    {%- endif -%}
    {{ return('gold_' ~ node.fqn[2]) }}
  {%- endif -%}

  {{ return(camada) }}
{%- endmacro %}
