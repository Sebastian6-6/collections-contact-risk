{#
  Padronização de contato: só o formato, nenhuma validação de existência ou de regra.
#}

{#
  Telefone só com dígitos, no formato DDD + número (10 ou 11 dígitos), sem o código do país.
  '(11) 90040-5285', '+55 11 90035-3520', '+5511900470747' e '11900139013' dão formas
  comparáveis. O 55 só sai quando o total é 12 ou 13 dígitos, para não confundir com o DDD 55 (RS).
  Entrada sem dígitos dá NULL. Números inventados ('0000000000') passam como vieram: quem os trata
  é a gold. Quem junta DDD e número em colunas separadas (beta) concatena antes de chamar.
#}
{% macro telefone_normalizado(expressao) -%}
  {%- set digitos = somente_digitos(expressao) -%}
  CASE
    WHEN LENGTH({{ digitos }}) IN (12, 13) AND SUBSTRING({{ digitos }}, 1, 2) = '55'
      THEN SUBSTRING({{ digitos }}, 3)
    ELSE {{ digitos }}
  END
{%- endmacro %}

{#
  E-mail em minúsculas e sem espaços nas pontas; vazio dá NULL. Não valida o endereço.
#}
{% macro email_normalizado(expressao) -%}
  NULLIF(LOWER(TRIM(CAST({{ expressao }} AS VARCHAR))), '')
{%- endmacro %}
