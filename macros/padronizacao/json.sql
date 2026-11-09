{#
  Leitura segura de JSON. A bronze guarda o JSON como texto, inclusive o truncado ("Registro
  Interrompido" no beta, `contatos` cortado na gama); a validação é da silver (decisão I4 do
  plano). Converter texto inválido com CAST derruba a consulta inteira, então esta macro devolve
  NULL na linha inválida e o JSON na válida.
  Não há função em comum entre os motores, por isso `adapter.dispatch`:
    - DuckDB: `json_valid` e CAST para JSON. Verificado por execução.
    - PostgreSQL (padrão): o predicado `IS JSON` e CAST para JSONB, do PostgreSQL 16 em diante.
      Escrito a partir da documentação; não foi executado neste projeto.
  O resultado se lê igual nos dois: `->` e `->>` para chaves, `o resultado IS NULL (com o texto não NULL)` para achar a
  linha inválida. Para extrair listas, cada motor tem a própria função; isso é assunto da silver.
  Texto NULL dá NULL.
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
