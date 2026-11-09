{#
  Endereço em uma só string, separado só quando a linha inteira casa com o padrão estrito
    logradouro, numero[, complemento] - bairro - cidade
  ancorado do início ao fim. Logradouro, número e complemento não levam vírgula nem hífen, bairro
  e cidade não levam hífen, então cada linha tem uma única leitura possível. Quem não casa (inclusive
  NULL) dá NULL em todas as partes: nunca se adivinha uma separação. Como os separadores são
  literais e nada é aparado, as partes recompõem exatamente o texto original.
  Só usa REGEXP_REPLACE com grupos, que tem o mesmo resultado no DuckDB e no PostgreSQL.
#}
{% macro endereco_padrao_estrito() -%}
  '^([^,-]+), ([^,-]+)(?:, ([^,-]+))? - ([^-]+) - ([^-]+)$'
{%- endmacro %}

{#
  O texto casa com o padrão estrito? BOOLEAN; NULL quando o texto é NULL.
#}
{% macro endereco_casa_padrao(expressao) -%}
  CAST({{ expressao }} AS VARCHAR) ~ {{ endereco_padrao_estrito() }}
{%- endmacro %}

{#
  Parte do endereço pelo número do grupo: 1 logradouro, 2 numero, 3 complemento, 4 bairro,
  5 cidade. NULL quando a linha não casa com o padrão ou, no complemento, quando não há.
#}
{% macro endereco_parte(expressao, grupo) -%}
  {#- A referência ao grupo ('\1') é montada em duas partes, como em `data_do_nome_do_arquivo`. -#}
  {%- set retrovisor = '\\' ~ grupo -%}
  {%- set texto = "CAST(" ~ expressao ~ " AS VARCHAR)" -%}
  {%- set parte = "REGEXP_REPLACE(" ~ texto ~ ", " ~ endereco_padrao_estrito() ~ ", '" ~ retrovisor ~ "')" -%}
  CASE
    WHEN {{ endereco_casa_padrao(expressao) }} THEN NULLIF({{ parte }}, '')
  END
{%- endmacro %}
