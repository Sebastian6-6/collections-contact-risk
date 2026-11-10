{#
  Quantas posições de dois textos de mesmo tamanho têm caractere diferente (distância de Hamming),
  para o CPF de 11 dígitos. Existe porque `hamming` só existe no DuckDB; `SUBSTRING` e `CAST` de
  booleano são iguais no PostgreSQL. O tamanho é parâmetro; quem chama garante que os dois textos o têm
  (o CPF com mais de 11 dígitos não é comparado). NULL em qualquer lado dá NULL.
#}
{% macro posicoes_diferentes(texto_a, texto_b, tamanho) -%}
  (
  {%- for posicao in range(1, tamanho + 1) %}
    {{ '+ ' if not loop.first else '' }}CAST(SUBSTRING({{ texto_a }}, {{ posicao }}, 1) <> SUBSTRING({{ texto_b }}, {{ posicao }}, 1) AS INTEGER)
  {%- endfor %}
  )
{%- endmacro %}
