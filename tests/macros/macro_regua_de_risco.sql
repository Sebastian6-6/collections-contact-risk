{%- set filtro_sem_corte = regua_filtro_corte("dt", none) | trim -%}
{%- set filtro_com_corte = regua_filtro_corte("dt", "2026-09-15") | trim -%}
{%- set filtro_com_corte = filtro_com_corte | replace("'", "''") -%}
{#
  Prova a régua: cada linha de entrada traz os sinais de um par e o nível e o motivo esperados.
  Cobre a prioridade da G5 (falecido vence opt_out, que vence terceiro, migrado e sem devedor),
  o `atencao` e o `liberado`, e que `NULL` num sinal não dispara regra. Prova também o filtro de
  corte (`regua_filtro_corte`) com e sem data. O cálculo dos sinais é do passo 4.5.
#}
WITH tSinaisDoPar AS (
  SELECT
    CAST(sk_contato AS INTEGER) AS sk_contato
    , CAST(sk_devedor AS INTEGER) AS sk_devedor
    , CAST(situacao_documento AS VARCHAR) AS situacao_documento
    , CAST(situacao_compartilhamento AS VARCHAR) AS situacao_compartilhamento
    , CAST(tipo_alerta_historico AS VARCHAR) AS tipo_alerta_historico
    , CAST(tipo_conflito_cadastral AS VARCHAR) AS tipo_conflito_cadastral
  FROM (
    VALUES
    (1, 1, 'cpf_valido', 'exclusivo', 'nenhum', 'nenhum')
    , (2, 1, 'cpf_valido', 'exclusivo', 'falecido', 'nenhum')
    , (3, 1, 'cpf_valido', 'migrado', 'falecido', 'nenhum')
    , (4, 1, 'cpf_valido', 'exclusivo', 'opt_out', 'identidade')
    , (5, 1, 'cpf_valido', 'migrado', 'nao_e_o_devedor', 'nenhum')
    , (6, 1, 'cpf_valido', 'migrado', 'nenhum', 'nenhum')
    , (7, NULL, 'sem_documento', 'compartilhado', 'nenhum', NULL)
    , (8, 1, 'cpf_valido', 'compartilhado', 'nenhum', 'nenhum')
    , (9, 1, 'cpf_valido', 'exclusivo', 'nenhum', 'identidade_e_versao')
    , (10, 1, 'cpf_corrigido', 'exclusivo', 'nenhum', 'nenhum')
    , (11, 1, 'rg_por_nome_nascimento', 'exclusivo', 'nenhum', 'nenhum')
    , (12, 1, 'cpf_invalido', 'exclusivo', 'nenhum', 'nenhum')
    , (13, 1, 'cpf_valido', 'exclusivo', 'nenhum', 'versao')
    , (14, 1, NULL, NULL, NULL, NULL)
  ) AS tFixture (
    sk_contato, sk_devedor, situacao_documento, situacao_compartilhamento
    , tipo_alerta_historico, tipo_conflito_cadastral
  )
)

, tEsperado (sk_contato, nivel_risco, motivo_inicio) AS (
  VALUES
  (1, 'liberado', 'sem sinal')
  , (2, 'bloqueado', 'falecido')
  , (3, 'bloqueado', 'falecido')
  , (4, 'bloqueado', 'opt_out')
  , (5, 'bloqueado', 'terceiro')
  , (6, 'bloqueado', 'contato migrado')
  , (7, 'bloqueado', 'contato sem devedor')
  , (8, 'atencao', 'contato compartilhado')
  , (9, 'atencao', 'conflito de identidade')
  , (10, 'atencao', 'documento ligado')
  , (11, 'atencao', 'documento ligado')
  , (12, 'atencao', 'CPF inválido')
  , (13, 'liberado', 'sem sinal')
  , (14, 'liberado', 'sem sinal')
)

, tObtido AS (
  {{ regua_de_risco() }}
)

, tDivergencias AS (
  SELECT
    tEsperado.sk_contato
    , tEsperado.nivel_risco AS nivel_esperado
    , tObtido.nivel_risco AS nivel_obtido
    , tObtido.desc_motivo_risco
  FROM tEsperado
  LEFT JOIN tObtido
    ON tEsperado.sk_contato = tObtido.sk_contato
  WHERE 1 = 1
    AND (
      tObtido.nivel_risco IS DISTINCT FROM tEsperado.nivel_risco
      OR tObtido.desc_motivo_risco IS NULL
      OR NOT STARTS_WITH(tObtido.desc_motivo_risco, tEsperado.motivo_inicio)
    )
)

, tFiltroCorte AS (
  SELECT
    'sem corte' AS caso
    , '{{ filtro_sem_corte }}' AS obtido
    , '' AS esperado
  UNION ALL
  SELECT
    'com corte' AS caso
    , '{{ filtro_com_corte }}' AS obtido
    , 'AND dt <= CAST(''2026-09-15'' AS DATE)' AS esperado
)

SELECT
  CAST(sk_contato AS VARCHAR) AS referencia
  , nivel_esperado || ' <> ' || COALESCE(nivel_obtido, 'NULL') AS problema
FROM tDivergencias
UNION ALL
SELECT
  caso AS referencia
  , obtido || ' <> ' || esperado AS problema
FROM tFiltroCorte
WHERE 1 = 1
  AND obtido IS DISTINCT FROM esperado
