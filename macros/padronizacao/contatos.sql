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

{#
  Telefone normalizado de um elemento JSON que pode ser um texto ("+55 11 90040-5285") ou um
  objeto {ddd, numero, ...} (beta): o texto passa direto por `telefone_normalizado` e no objeto
  o DDD e o número são concatenados antes. Objeto sem DDD ou sem número dá NULL, em vez de um
  número incompleto que pareceria outro. Usa `json_texto` e `->>`, que o dispatch resolve por motor.
#}
{% macro telefone_de_elemento_json(expressao) -%}
  {{ telefone_normalizado(
    "COALESCE(" ~ json_texto(expressao) ~ ", (" ~ expressao ~ " ->> 'ddd') || (" ~ expressao ~ " ->> 'numero'))"
  ) }}
{%- endmacro %}
