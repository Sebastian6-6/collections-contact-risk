{#
  Chave de comparação de nomes entre provedores (G3a', seção 9.6 de docs/decisoes-de-modelagem.md).
  Por quê: o alfa manda nomes sem acento e o beta e a gama com acento; sem tirar o acento o mesmo
  nome viraria dois. `TRANSLATE` com o mapa dos acentos maiúsculos existe no núcleo do PostgreSQL
  e no DuckDB; `strip_accents` só existe no DuckDB e `unaccent` é extensão do PostgreSQL.
  Espera o nome já em maiúscula, como a silver entrega (`texto_maiusculo`). Um acento fora do mapa
  passa sem aviso; o teste de aviso da `dim_devedor` conta os caracteres fora do ASCII que sobram.
  Só serve para comparar: a coluna `nome_devedor` mostra o nome recebido.
#}
{% macro nome_comparavel(expressao) -%}
  TRANSLATE(
    {{ expressao }}
    , 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ'
    , 'AAAAAEEEEIIIIOOOOOUUUUCN'
  )
{%- endmacro %}
