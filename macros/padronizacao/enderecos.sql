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
  Padrões estritos do gama, que manda o endereço em texto de dois jeitos (docs/perfil-das-fontes.md),
  com as mesmas regras do padrão do alfa (sem vírgula nem hífen dentro das partes, ancorado):
    - `rua`: logradouro, numero                     (grupos 1 e 2)
    - `endereco`: logradouro, numero - bairro       (grupos 1, 2 e 3)
#}
{% macro endereco_padrao_rua() -%}
  '^([^,-]+), ([^,-]+)$'
{%- endmacro %}

{% macro endereco_padrao_rua_bairro() -%}
  '^([^,-]+), ([^,-]+) - ([^-]+)$'
{%- endmacro %}

{#
  O texto casa com o padrão estrito? BOOLEAN; NULL quando o texto é NULL.
#}
{% macro endereco_casa_padrao(expressao, padrao=none) -%}
  CAST({{ expressao }} AS VARCHAR) ~ {{ padrao if padrao else endereco_padrao_estrito() }}
{%- endmacro %}

{#
  Parte do endereço pelo número do grupo: 1 logradouro, 2 numero, 3 complemento, 4 bairro,
  5 cidade. NULL quando a linha não casa com o padrão ou, no complemento, quando não há.
  `padrao` troca o padrão estrito de `endereco_padrao_estrito()` por outro, ancorado do início ao
  fim, e os grupos passam a seguir a ordem dele (gama: `endereco_padrao_rua` e
  `endereco_padrao_rua_bairro`).
#}
{% macro endereco_parte(expressao, grupo, padrao=none) -%}
  {#- A referência ao grupo ('\1') é montada em duas partes, como em `data_do_nome_do_arquivo`. -#}
  {%- set retrovisor = '\\' ~ grupo -%}
  {%- set texto = "CAST(" ~ expressao ~ " AS VARCHAR)" -%}
  {%- set padrao_usado = padrao if padrao else endereco_padrao_estrito() -%}
  {%- set parte = "REGEXP_REPLACE(" ~ texto ~ ", " ~ padrao_usado ~ ", '" ~ retrovisor ~ "')" -%}
  CASE
    WHEN {{ endereco_casa_padrao(expressao, padrao_usado) }} THEN NULLIF({{ parte }}, '')
  END
{%- endmacro %}

{#
  Sigla da UF em maiúsculas e sem espaços nas pontas ('sp' e ' SP ' dão 'SP'). Valor que não é uma
  das 27 UFs do Brasil ('XX', 'S', 'SÃO PAULO'), vazio ou NULL dá NULL: ausência é NULL, e um
  texto fora do domínio não é uma UF. A lista é a das unidades federativas do IBGE.
#}
{% macro uf_normalizada(expressao) -%}
  {%- set uf = "UPPER(TRIM(CAST(" ~ expressao ~ " AS VARCHAR)))" -%}
  CASE
    WHEN {{ uf }} IN (
      'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB'
      , 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
    ) THEN {{ uf }}
  END
{%- endmacro %}
