{#
  Régua de risco de contato (G4a, G4b e G5; seção 9.9 de docs/decisoes-de-modelagem.md).

  As regras de nível e motivo estão aqui; o cálculo dos sinais (`tSinaisDoPar`) é da macro
  `regua_sinais_do_par` (passo 4.5), que também usa `data_corte`.

  Grão da saída: uma linha por par devedor x contato de `sinais`.
  Entrada: a CTE `sinais` (padrão `tSinaisDoPar`) com as colunas
    sk_contato, sk_devedor,
    situacao_documento          (cpf_valido, cpf_corrigido, rg_por_nome_nascimento, cpf_invalido, sem_documento),
    situacao_compartilhamento   (exclusivo, compartilhado, migrado),
    tipo_alerta_historico       (nenhum, falecido, opt_out, nao_e_o_devedor),
    tipo_conflito_cadastral     (do devedor: nenhum, identidade, versao, identidade_e_versao).
  Saída: sk_contato, sk_devedor, nivel_risco (liberado, atencao, bloqueado) e desc_motivo_risco.
  O motivo é o principal, pela prioridade falecido > opt_out > disse não ser o devedor > contato
  migrado > contato sem devedor; os demais ficam visíveis nas colunas de sinal.

  data_corte: sem corte (`none`) é a régua de operação; com 'AAAA-MM-DD' é a validação (G4c), que
  deve calcular os sinais só com entregas e tentativas até a data. Aqui só se valida o formato;
  o filtro por data é montado por `regua_filtro_corte`.
#}

{#- Regras em ordem de prioridade: [nível, motivo, condição]. Fonte única do nível e do motivo. -#}
{% macro regua_regras() -%}
  {{ return([
    ['bloqueado', 'falecido: devedor falecido registrado em contato', "tipo_alerta_historico = 'falecido'"],
    ['bloqueado', 'opt_out: titular do contato pediu para não ser contatado', "tipo_alerta_historico = 'opt_out'"],
    ['bloqueado', 'terceiro: contato informou não ser o devedor', "tipo_alerta_historico = 'nao_e_o_devedor'"],
    ['bloqueado', 'contato migrado: passou a outro CPF', "situacao_compartilhamento = 'migrado'"],
    ['bloqueado', 'contato sem devedor identificado', 'sk_devedor IS NULL'],
    ['atencao', 'contato compartilhado entre devedores', "situacao_compartilhamento = 'compartilhado'"],
    ['atencao', 'conflito de identidade no cadastro', "tipo_conflito_cadastral IN ('identidade', 'identidade_e_versao')"],
    ['atencao', 'documento ligado por correção ou por RG', "situacao_documento IN ('cpf_corrigido', 'rg_por_nome_nascimento')"],
    ['atencao', 'CPF inválido sem ligação', "situacao_documento = 'cpf_invalido'"],
  ]) }}
{%- endmacro %}

{% macro regua_valida_corte(data_corte) -%}
  {%- if data_corte is not none -%}
    {%- if modules.re.match('^[0-9]{4}-[0-9]{2}-[0-9]{2}$', data_corte | string) is none -%}
      {{ exceptions.raise_compiler_error(
        "regua_de_risco: data_corte deve ser 'AAAA-MM-DD' ou none, e veio '" ~ data_corte ~ "'."
      ) }}
    {%- endif -%}
  {%- endif -%}
{%- endmacro %}

{#- Predicado para limitar uma coluna de data ao corte; vazio na régua de operação. -#}
{% macro regua_filtro_corte(coluna, data_corte) -%}
  {{ regua_valida_corte(data_corte) }}
  {%- if data_corte is not none -%}
    AND {{ coluna }} <= CAST('{{ data_corte }}' AS DATE)
  {%- endif -%}
{%- endmacro %}

{% macro regua_de_risco(data_corte=none, sinais='tSinaisDoPar') -%}
  {{ regua_valida_corte(data_corte) }}
  {%- set regras = regua_regras() -%}
  SELECT
    sk_contato
    , sk_devedor
    , CASE
  {%- for regra in regras %}
      WHEN {{ regra[2] }} THEN '{{ regra[0] }}'
  {%- endfor %}
      ELSE 'liberado'
    END AS nivel_risco
    , CASE
  {%- for regra in regras %}
      WHEN {{ regra[2] }} THEN '{{ regra[1] }}'
  {%- endfor %}
      ELSE 'sem sinal de risco'
    END AS desc_motivo_risco
  FROM {{ sinais }}
{%- endmacro %}
