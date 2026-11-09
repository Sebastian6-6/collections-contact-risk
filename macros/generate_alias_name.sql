{#
  O nome da tabela sai do arquivo, sem o prefixo de camada e fonte:
    bronze_alfa_devedores.sql  ->  devedores (em bronze_alfa)
    silver_alfa_devedores.sql  ->  devedores (em silver_alfa)
    dim_devedor.sql (gold)     ->  dim_devedor
  Um `alias` explícito na configuração do modelo sempre prevalece.
  Nós que não são modelos seguem o comportamento padrão do dbt.
#}
{% macro generate_alias_name(custom_alias_name=none, node=none) -%}
  {%- if custom_alias_name or node.resource_type != 'model' -%}
    {{ return(default__generate_alias_name(custom_alias_name, node)) }}
  {%- endif -%}

  {%- set camada = node.fqn[1] -%}

  {%- if camada in ['bronze', 'silver'] and node.fqn | length >= 4 -%}
    {%- set prefixo = camada ~ '_' ~ node.fqn[2] ~ '_' -%}
    {%- if not node.name.startswith(prefixo) or node.name | length == prefixo | length -%}
      {{ exceptions.raise_compiler_error(
        "O modelo '" ~ node.name ~ "' deve se chamar '" ~ prefixo ~ "<entidade>'."
      ) }}
    {%- endif -%}
    {{ return(node.name[prefixo | length:]) }}
  {%- endif -%}

  {{ return(default__generate_alias_name(custom_alias_name, node)) }}
{%- endmacro %}
