{#
  Leitura segura de JSON. A bronze guarda o JSON como texto, inclusive o truncado ("Registro
  Interrompido" no beta, `contatos` cortado na gama); a validação é da silver (decisão I4 do
  plano). Converter texto inválido com CAST derruba a consulta inteira, então esta macro devolve
  NULL na linha inválida e o JSON na válida.
  Não há função em comum entre os motores, por isso `adapter.dispatch`:
    - DuckDB: `json_valid` e CAST para JSON. Verificado por execução.
    - PostgreSQL (padrão): o predicado `IS JSON` e CAST para JSONB, do PostgreSQL 16 em diante.
      Escrito a partir da documentação; não foi executado neste projeto.
  O resultado se lê igual nos dois: `->` e `->>` para chaves (sempre entre parênteses antes de
  comparar: `(x ->> 'k') IS NULL`) e `o resultado IS NULL (com o texto não NULL)` para achar a
  linha inválida. Para abrir listas e ler o texto de um valor solto, veja `json_abrir_lista` e
  `json_texto`. Texto NULL dá NULL.
#}
{% macro json_ou_nulo(expressao) -%}
  {{ return(adapter.dispatch('json_ou_nulo', 'collections_contact_risk')(expressao)) }}
{%- endmacro %}

{% macro default__json_ou_nulo(expressao) -%}
  CASE
    WHEN CAST({{ expressao }} AS TEXT) IS JSON THEN CAST({{ expressao }} AS JSONB)
  END
{%- endmacro %}

{% macro duckdb__json_ou_nulo(expressao) -%}
  CASE
    WHEN json_valid({{ expressao }}) THEN CAST({{ expressao }} AS JSON)
  END
{%- endmacro %}

{#
  Texto de um valor JSON escalar (string, número, booleano) como VARCHAR. Objeto, lista e `null`
  dão NULL: quem lê um elemento de lista que pode ser texto ou objeto (telefone do beta) usa esta
  macro para o caso do texto e `->>` para o caso do objeto, sem confundir um com o outro.
  Para o valor de uma chave basta `->>`, que já devolve o texto do escalar nos dois motores.
    - DuckDB: `json_extract_string` com o caminho raiz. Verificado por execução.
    - PostgreSQL (padrão): o operador `#>>` com caminho vazio. Escrito a partir da documentação;
      não foi executado neste projeto.
#}
{% macro json_texto(expressao) -%}
  {{ return(adapter.dispatch('json_texto', 'collections_contact_risk')(expressao)) }}
{%- endmacro %}

{% macro default__json_texto(expressao) -%}
  CASE
    WHEN jsonb_typeof({{ expressao }}) NOT IN ('object', 'array') THEN {{ expressao }} #>> '{}'
  END
{%- endmacro %}

{% macro duckdb__json_texto(expressao) -%}
  CASE
    WHEN json_type({{ expressao }}) NOT IN ('OBJECT', 'ARRAY') THEN json_extract_string({{ expressao }}, '$')
  END
{%- endmacro %}

{#
  Abre uma lista JSON em linhas, para usar depois de `CROSS JOIN LATERAL`:
    CROSS JOIN LATERAL {{ json_abrir_lista('p.telefones', 't') }}
  O alias (`t`) expõe `valor` (o elemento, em JSON) e `posicao` (1, 2, 3, ... na ordem da lista).
  Expressão NULL, lista vazia ou JSON que não é lista não geram linha (o CROSS JOIN descarta a
  linha de origem, então nada aparece onde a origem não tem elemento). Abrir lista em linhas é
  específico de cada motor, e é o único lugar do projeto que sabe disso:
    - DuckDB: `UNNEST(FROM_JSON(lista, '["JSON"]')) WITH ORDINALITY`. Verificado por execução.
    - PostgreSQL (padrão): `jsonb_array_elements(lista) WITH ORDINALITY`. Escrito a partir da
      documentação; não foi executado neste projeto. A função do PostgreSQL falha com JSON que
      não é lista, por isso a guarda com `jsonb_typeof`, que devolve NULL e zero linhas.
  `posicao` é BIGINT nos dois.
#}
{% macro json_abrir_lista(expressao, alias) -%}
  {{ return(adapter.dispatch('json_abrir_lista', 'collections_contact_risk')(expressao, alias)) }}
{%- endmacro %}

{% macro default__json_abrir_lista(expressao, alias) -%}
  jsonb_array_elements(CASE WHEN jsonb_typeof({{ expressao }}) = 'array' THEN {{ expressao }} END)
    WITH ORDINALITY AS {{ alias }}(valor, posicao)
{%- endmacro %}

{% macro duckdb__json_abrir_lista(expressao, alias) -%}
  UNNEST(FROM_JSON(CASE WHEN json_type({{ expressao }}) = 'ARRAY' THEN {{ expressao }} END, '["JSON"]'))
    WITH ORDINALITY AS {{ alias }}(valor, posicao)
{%- endmacro %}
