{#
  Padronização de documento. Cada macro recebe uma expressão SQL (normalmente o nome de uma coluna
  de texto) e devolve uma expressão. Só ajustam o formato: nenhuma decide regra de negócio nem
  filtra linha. Entrada vazia, sem nenhum caractere útil ou só com zeros devolve NULL: um documento
  que não identifica ninguém é ausência de chave, não um valor (ausência é NULL, nunca zero).
  Só usam funções que existem com o mesmo comportamento no DuckDB e no PostgreSQL.
#}

{#
  Só os dígitos 0-9 do texto; NULL quando não sobra nenhum.
  Entrada '123.456.789-09' -> '12345678909'. Entrada '' ou 'abc' -> NULL.
#}
{% macro somente_digitos(expressao) -%}
  NULLIF(REGEXP_REPLACE(CAST({{ expressao }} AS VARCHAR), '[^0-9]', '', 'g'), '')
{%- endmacro %}

{#
  NULL quando o texto só tem zeros ('0', '000', '00000000000'); senão o próprio texto. Documento
  zerado é o preenchimento de quem não tem o dado: tratá-lo como valor juntaria pessoas
  diferentes sob a mesma chave.
#}
{% macro nulo_se_so_zeros(expressao) -%}
  CASE WHEN {{ expressao }} ~ '^0+$' THEN CAST(NULL AS VARCHAR) ELSE {{ expressao }} END
{%- endmacro %}

{#
  CPF só com dígitos, com os zeros à esquerda repostos até 11 posições (o alfa perde zeros:
  '1006543201' -> '01006543201'). Documento vazio ou só com zeros ('0', '000.000.000-00') dá NULL.
  Mais de 11 dígitos ficam como estão, sem truncar, para o teste de qualidade enxergar o valor.
  Não verifica o dígito verificador (ver `cpf_valido`) e não distingue CPF de outro documento: um
  RG do beta não deve passar por aqui.
#}
{% macro cpf_normalizado(expressao) -%}
  {%- set digitos = somente_digitos(expressao) -%}
  CASE
    WHEN {{ digitos }} ~ '^0+$' THEN CAST(NULL AS VARCHAR)
    WHEN LENGTH({{ digitos }}) <= 11 THEN LPAD({{ digitos }}, 11, '0')
    ELSE {{ digitos }}
  END
{%- endmacro %}

{#
  CNPJ em maiúsculas, sem máscara, aceitando o formato alfanumérico (A7K2M9Q4000140). Repõe os
  zeros à esquerda até 14 posições ('191' -> '00000000000191'). Com exatamente 12 caracteres o
  valor é a base sem os dois dígitos verificadores; completá-lo com zeros daria outro CNPJ, então
  fica como veio (completar exigiria calcular os dígitos, que é regra, não formato).
#}
{% macro cnpj_normalizado(expressao) -%}
  {%- set limpo = "NULLIF(REGEXP_REPLACE(UPPER(CAST(" ~ expressao ~ " AS VARCHAR)), '[^0-9A-Z]', '', 'g'), '')" -%}
  CASE
    WHEN LENGTH({{ limpo }}) = 12 OR LENGTH({{ limpo }}) >= 14 THEN {{ limpo }}
    ELSE LPAD({{ limpo }}, 14, '0')
  END
{%- endmacro %}

{#
  Validade do dígito verificador do CPF, devolvendo BOOLEAN. Recebe um CPF já normalizado
  (`cpf_normalizado`). NULL quando a entrada é NULL; FALSE quando não tem 11 dígitos, quando
  todos os dígitos são iguais ou quando os dígitos verificadores não batem. Só informa: não filtra.
#}
{% macro cpf_valido(expressao) -%}
  {%- set cpf = "CAST(" ~ expressao ~ " AS VARCHAR)" -%}
  {%- set soma1 = [] -%}
  {%- for i in range(1, 10) -%}
    {%- do soma1.append("CAST(SUBSTRING(" ~ cpf ~ ", " ~ i ~ ", 1) AS INTEGER) * " ~ (11 - i)) -%}
  {%- endfor -%}
  {%- set soma2 = [] -%}
  {%- for i in range(1, 11) -%}
    {%- do soma2.append("CAST(SUBSTRING(" ~ cpf ~ ", " ~ i ~ ", 1) AS INTEGER) * " ~ (12 - i)) -%}
  {%- endfor -%}
  CASE
    WHEN {{ cpf }} IS NULL THEN CAST(NULL AS BOOLEAN)
    WHEN {{ cpf }} !~ '^[0-9]{11}$' THEN FALSE
    WHEN {{ cpf }} = REPEAT(SUBSTRING({{ cpf }}, 1, 1), 11) THEN FALSE
    ELSE
      (({{ soma1 | join(' + ') }}) * 10) % 11 % 10 = CAST(SUBSTRING({{ cpf }}, 10, 1) AS INTEGER)
      AND (({{ soma2 | join(' + ') }}) * 10) % 11 % 10 = CAST(SUBSTRING({{ cpf }}, 11, 1) AS INTEGER)
  END
{%- endmacro %}
