{#
  Padronização de data e valor monetário. Só o formato: datas sentinela (1900-01-01) e valores
  zero passam como vieram; quem os trata é a gold.
#}

{#
  Converte texto ISO (AAAA-MM-DD) em DATE, devolvendo NULL quando a data não existe no calendário
  (ex.: 2026-02-30), em vez de derrubar a consulta. Os dois motores não têm uma função em comum:
  o DuckDB usa TRY_CAST; o PostgreSQL 16 ou superior usa `pg_input_is_valid`. A implementação do
  PostgreSQL foi escrita a partir da documentação e não foi executada neste projeto.
#}
{% macro data_iso_ou_nulo(expressao) -%}
  {{ return(adapter.dispatch('data_iso_ou_nulo', 'collections_contact_risk')(expressao)) }}
{%- endmacro %}

{% macro default__data_iso_ou_nulo(expressao) -%}
  CASE
    WHEN pg_input_is_valid({{ expressao }}, 'date') THEN CAST({{ expressao }} AS DATE)
  END
{%- endmacro %}

{% macro duckdb__data_iso_ou_nulo(expressao) -%}
  TRY_CAST({{ expressao }} AS DATE)
{%- endmacro %}

{#
  DATE a partir dos três formatos reais das fontes:
    - ISO '2026-09-01', inclusive com hora e fuso ('2026-09-01T10:30:00-03:00'): vale a data
      escrita, que já é a local;
    - 'dd/mm/aaaa' (gama), sempre com dia e mês de 2 dígitos;
    - epoch em milissegundos, só dígitos com 12 a 14 posições (beta): vira a data no fuso do
      Brasil, por `deslocamento_horas` (padrão -3, sem horário de verão desde 2019).
  Qualquer outro formato, vazio ou data inexistente dá NULL. A conta do epoch é aritmética de
  DATE e NUMERIC, igual nos dois motores e sem depender do fuso da sessão.
#}
{% macro data_flexivel(expressao, deslocamento_horas=-3) -%}
  {%- set texto = "TRIM(CAST(" ~ expressao ~ " AS VARCHAR))" -%}
  CASE
    WHEN {{ texto }} ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}([T ].*)?$'
      THEN {{ data_iso_ou_nulo("SUBSTRING(" ~ texto ~ ", 1, 10)") }}
    WHEN {{ texto }} ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
      THEN {{ data_iso_ou_nulo(
        "SUBSTRING(" ~ texto ~ ", 7, 4) || '-' || SUBSTRING(" ~ texto ~ ", 4, 2) || '-' || SUBSTRING(" ~ texto ~ ", 1, 2)"
      ) }}
    WHEN {{ texto }} ~ '^[0-9]{12,14}$'
      THEN DATE '1970-01-01' + CAST(
        FLOOR(
          (CAST({{ texto }} AS NUMERIC) + {{ deslocamento_horas }} * 3600000) / 86400000
        ) AS INTEGER
      )
  END
{%- endmacro %}

{#
  Mês no formato AAAA-MM como DATE no dia 01 ('2020-05' -> 2020-05-01). O valor da origem é um mês
  (o beta não informa o dia); o dia 01 é só a representação do mês em um DATE, e quem consome
  deve ler o valor como mês. Qualquer outro formato, vazio ou mês inexistente ('2020-13') dá NULL.
#}
{% macro mes_como_data(expressao) -%}
  {%- set texto = "TRIM(CAST(" ~ expressao ~ " AS VARCHAR))" -%}
  CASE
    WHEN {{ texto }} ~ '^[0-9]{4}-[0-9]{2}$' THEN {{ data_iso_ou_nulo(texto ~ " || '-01'") }}
  END
{%- endmacro %}

{#
  Valor monetário em NUMERIC(14, 2). Aceita 'R$ 1.400,00', '1.290,07', '1298,35', '1400.00' e
  '9241.83'. Com vírgula, a vírgula é o decimal e os pontos são milhar; sem vírgula, o ponto é o
  decimal ('1.400' é 1,4, não 1400). Vazio, sem número ou fora desses formatos dá NULL (S8).
  '0,00' dá 0.00: o zero informado pelo provedor é um valor recebido, e quem o trata é a gold.
#}
{% macro valor_monetario(expressao) -%}
  {%- set limpo = "REGEXP_REPLACE(CAST(" ~ expressao ~ " AS VARCHAR), '[^0-9,.-]', '', 'g')" -%}
  {%- set decimal = "CASE WHEN " ~ limpo ~ " LIKE '%,%' THEN REPLACE(REPLACE(" ~ limpo ~ ", '.', ''), ',', '.') ELSE " ~ limpo ~ " END" -%}
  CASE
    WHEN {{ decimal }} ~ '^-?[0-9]+([.][0-9]+)?$' THEN CAST({{ decimal }} AS NUMERIC(14, 2))
  END
{%- endmacro %}

{#
  Data AAAA-MM-DD escrita no nome do arquivo (último trecho do caminho), como DATE. NULL quando
  o nome não tem essa data (o histórico não tem; quem o trata usa a variável do projeto) ou
  quando ela não existe no calendário. 'x/provedor_alfa_2026-09-01.csv' -> 2026-09-01.
#}
{% macro data_do_nome_do_arquivo(expressao) -%}
  {#- O Jinja interpreta '' como caractere de controle, então a referência é montada em duas partes. -#}
  {%- set retrovisor = '\\' ~ '1' -%}
  {%- set nome = "REGEXP_REPLACE(CAST(" ~ expressao ~ " AS VARCHAR), '^.*/', '')" -%}
  CASE
    WHEN {{ nome }} ~ '[0-9]{4}-[0-9]{2}-[0-9]{2}'
      THEN {{ data_iso_ou_nulo("REGEXP_REPLACE(" ~ nome ~ ", '^.*?([0-9]{4}-[0-9]{2}-[0-9]{2}).*$', '" ~ retrovisor ~ "')") }}
  END
{%- endmacro %}

{#
  Data de entrega de uma linha da bronze. O arquivo histórico da fonte (variável `arquivo_historico`,
  caminho exato) recebe `data_carga_historica`; qualquer outro arquivo usa a data do nome e, se ela
  faltar ou não existir no calendário, fica NULL em vez de herdar a data da carga histórica. O teste
  `entrega_diaria_sem_data_valida` reprova a pipeline nesse caso.
#}
{% macro data_de_entrega(expressao, fonte) -%}
  CASE
    WHEN CAST({{ expressao }} AS VARCHAR) = '{{ var("arquivo_historico")[fonte] }}'
      THEN CAST('{{ var("data_carga_historica") }}' AS DATE)
    ELSE {{ data_do_nome_do_arquivo(expressao) }}
  END
{%- endmacro %}

{#
  Converte texto 'AAAA-MM-DD HH:MM:SS' em TIMESTAMP, devolvendo NULL quando o texto não é um
  instante válido, em vez de derrubar a consulta. Segue o mesmo desenho de `data_iso_ou_nulo`:
    - DuckDB: TRY_CAST. Verificado por execução.
    - PostgreSQL (padrão): `pg_input_is_valid` (16 ou superior). Escrito a partir da documentação;
      não foi executado neste projeto.
  Sem fuso: o provedor não informa e o valor fica como veio.
#}
{% macro timestamp_ou_nulo(expressao) -%}
  {{ return(adapter.dispatch('timestamp_ou_nulo', 'collections_contact_risk')(expressao)) }}
{%- endmacro %}

{% macro default__timestamp_ou_nulo(expressao) -%}
  CASE
    WHEN pg_input_is_valid(NULLIF(TRIM({{ expressao }}), ''), 'timestamp')
      THEN CAST(NULLIF(TRIM({{ expressao }}), '') AS TIMESTAMP)
  END
{%- endmacro %}

{% macro duckdb__timestamp_ou_nulo(expressao) -%}
  TRY_CAST(NULLIF(TRIM({{ expressao }}), '') AS TIMESTAMP)
{%- endmacro %}
