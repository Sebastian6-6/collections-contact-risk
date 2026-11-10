{#
  Grão: uma tentativa de contato (`contato_id`), as mesmas linhas de
  `silver_cobranca.contatos_realizados`. Cada tentativa liga-se ao par (CPF, contato) da
  `dim_contato`; sem o par, ao contato sem devedor de mesmo valor (`sk_devedor` `NULL`); sem
  nenhum dos dois, `sk_devedor` e `sk_contato` ficam `NULL` (G2c', ligação em `cobranca_tentativas`).
  `canal` e `resultado` ficam na tabela (G2b), e `tipo_desfecho` é a classe do resultado (macro
  `tipo_desfecho`). Um `resultado` fora da lista deixa `tipo_desfecho` `NULL` e reprova o teste.
  `situacao_horario` (G7) compara o dia e a hora da tentativa, em horário de Brasília, com a
  janela única e conservadora da Lei SP 17.832/2023, art. 51, e do SARB 27/2023, art. 32: segunda a
  sexta das 8h às 20h e sábado das 9h às 14h (a hora final não entra), sem domingos nem feriados
  nacionais (`var` `feriados_nacionais_2026`), para todo canal exceto e-mail (`nao_se_aplica`).
  Domingo vence feriado. O horário diz quando, não com quem: não muda `nivel_risco`.
  A rastreabilidade é da linha da Cobrança.
#}
{%- set feriados = var('feriados_nacionais_2026') -%}

WITH tClassificadas AS (
  SELECT
    sk_devedor
    , sk_contato
    , contato_id
    , canal
    , resultado
    , tipo_desfecho
    , dt_tentativa
    , CAST(data_hora AS TIME) AS hr_tentativa
    , _arquivo
    , _linha
    , _hash_arquivo
    , EXTRACT(ISODOW FROM data_hora) AS dia_da_semana
  FROM {{ ref('cobranca_tentativas') }}
)

, tComHorario AS (
  SELECT
    sk_devedor
    , sk_contato
    , contato_id
    , canal
    , resultado
    , tipo_desfecho
    , CASE
      WHEN canal = 'email' THEN 'nao_se_aplica'
      WHEN dia_da_semana = 7 THEN 'domingo'
      WHEN dt_tentativa IN (
          {%- for feriado in feriados %}
            CAST('{{ feriado }}' AS DATE){{ ',' if not loop.last }}
          {%- endfor %}
        ) THEN 'feriado'
      WHEN dia_da_semana BETWEEN 1 AND 5
        AND hr_tentativa >= TIME '08:00:00'
        AND hr_tentativa < TIME '20:00:00' THEN 'permitido'
      WHEN dia_da_semana = 6
        AND hr_tentativa >= TIME '09:00:00'
        AND hr_tentativa < TIME '14:00:00' THEN 'permitido'
      ELSE 'fora_do_horario'
    END AS situacao_horario
    , dt_tentativa
    , hr_tentativa
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tClassificadas
)

SELECT
  sk_devedor
  , sk_contato
  , contato_id
  , canal
  , resultado
  , tipo_desfecho
  , situacao_horario
  , dt_tentativa
  , hr_tentativa
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tComHorario
