{#
  Texto livre em maiúscula (H4): nomes, cargo, partes do endereço e o texto original do endereço.
  Por quê: o mesmo nome ou endereço chega em caixas diferentes ('Rua X' e 'RUA X'), e sem unificar
  o formato cada variação criaria uma versão ou um par a mais. O formato é o mesmo da UF
  (`uf_normalizada`, R6). O original, com a caixa de origem, fica na bronze.
  Não remove acento nem aparece em valores de domínio (tipo e atual do endereço, atributos_extra
  da gama), que seguem como vieram. O e-mail segue o `email_normalizado`.

  Acentos. A documentação do PostgreSQL 18 (https://www.postgresql.org/docs/current/functions-string.html,
  acessada em 2026-11-10) diz de `upper`: "Converts the string to all upper case, according to the
  rules of the database's locale." A página de locale
  (https://www.postgresql.org/docs/current/locale.html) lista "The upper, lower, and initcap
  functions" entre os recursos influenciados pelas configurações de locale e define o LC_CTYPE
  como "Character classification (What is a letter? Its upper-case equivalent?)". Ou seja, para
  letras fora do ASCII ('ç', 'ã') o resultado depende do locale do banco: num banco com
  C.UTF-8 ou PG_UNICODE_FAST (Unicode) 'ação' dá 'AÇÃO'; num banco com locale `C` clássico as letras
  acentuadas ficam como estão. A documentação não afirma nada além disso sobre não ASCII. No
  DuckDB, `UPPER('ação')` dá 'AÇÃO' (conferido por execução em 2026-11-10); o banco do PostgreSQL
  deve ser criado com um locale UTF-8 para o mesmo resultado (não verificado: não há instância).
  Nenhuma regex do endereço (`endereco_padrao_*`) depende da caixa: usam classes negadas
  (`[^,-]`) e separadores literais.
#}
{% macro texto_maiusculo(expressao) -%}
  UPPER({{ expressao }})
{%- endmacro %}
