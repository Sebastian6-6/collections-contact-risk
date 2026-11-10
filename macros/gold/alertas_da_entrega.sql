{#
  Regras de alerta das entregas diárias, num lugar só: o teste da entrega mais recente
  (`entrega_recente_com_alerta`) e a consulta do histórico (`alertas_das_entregas`) usam a mesma
  lista. Recebe o nome de uma CTE com as colunas de `ft_entrega_diaria` e devolve uma linha por
  entrega e motivo (`provedor`, `dt_referencia`, `motivo`, `valor`), nada se a entrega não tem alerta.
  Motivos:
    - `volume_acima` e `volume_abaixo`: `situacao_volume`, com a variação em `valor`;
    - `dia_sem_entrega`: `qt_dias_desde_entrega_anterior` maior que 1, com os dias em `valor`;
    - `reenvio`: mais de um arquivo no dia, com `qt_arquivos` em `valor`;
    - `cabecalho_mudou`: `situacao_cabecalho` igual a `mudou`;
    - `registros_repetidos` e `registros_atrasados`: a parte das linhas da entrega acima de
      `limite_registros_anormais`, com a parte em `valor`;
    - `linhas_ilegiveis`: qualquer linha que o leitor não separou, com a quantidade em `valor`.
#}
{% macro alertas_da_entrega(entregas) -%}
{%- set limite = var('limite_registros_anormais') -%}
SELECT
  provedor
  , dt_referencia
  , 'volume_acima' AS motivo
  , tx_variacao_media AS valor
FROM {{ entregas }}
WHERE 1 = 1
  AND situacao_volume = 'acima'

UNION ALL

SELECT
  provedor
  , dt_referencia
  , 'volume_abaixo' AS motivo
  , tx_variacao_media AS valor
FROM {{ entregas }}
WHERE 1 = 1
  AND situacao_volume = 'abaixo'

UNION ALL

SELECT
  provedor
  , dt_referencia
  , 'dia_sem_entrega' AS motivo
  , CAST(qt_dias_desde_entrega_anterior - 1 AS NUMERIC(8, 4)) AS valor
FROM {{ entregas }}
WHERE 1 = 1
  AND qt_dias_desde_entrega_anterior > 1

UNION ALL

SELECT
  provedor
  , dt_referencia
  , 'reenvio' AS motivo
  , CAST(qt_arquivos AS NUMERIC(8, 4)) AS valor
FROM {{ entregas }}
WHERE 1 = 1
  AND qt_arquivos > 1

UNION ALL

SELECT
  provedor
  , dt_referencia
  , 'cabecalho_mudou' AS motivo
  , CAST(NULL AS NUMERIC(8, 4)) AS valor
FROM {{ entregas }}
WHERE 1 = 1
  AND situacao_cabecalho = 'mudou'

UNION ALL

SELECT
  provedor
  , dt_referencia
  , 'registros_repetidos' AS motivo
  , CAST(CAST(qt_registros_repetidos AS NUMERIC) / qt_registros AS NUMERIC(8, 4)) AS valor
FROM {{ entregas }}
WHERE 1 = 1
  AND CAST(qt_registros_repetidos AS NUMERIC) / qt_registros > {{ limite }}

UNION ALL

SELECT
  provedor
  , dt_referencia
  , 'registros_atrasados' AS motivo
  , CAST(CAST(qt_registros_atrasados AS NUMERIC) / qt_registros AS NUMERIC(8, 4)) AS valor
FROM {{ entregas }}
WHERE 1 = 1
  AND CAST(qt_registros_atrasados AS NUMERIC) / qt_registros > {{ limite }}

UNION ALL

SELECT
  provedor
  , dt_referencia
  , 'linhas_ilegiveis' AS motivo
  , CAST(qt_linhas_ilegiveis AS NUMERIC(8, 4)) AS valor
FROM {{ entregas }}
WHERE 1 = 1
  AND qt_linhas_ilegiveis > 0
{%- endmacro %}
