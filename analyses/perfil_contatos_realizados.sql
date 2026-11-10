{#
  Perfil das fontes (docs/perfil-das-fontes.md, "Histórico de contatos"), regenerado da silver.
  Grão: uma linha por medida, com a contagem em `qt`:
    - volume: tentativas, CPFs alvo, canais e resultados distintos;
    - `tentativas_vistas_por_*_provedores`: quantos provedores trouxeram o destino da tentativa;
    - horário (de Brasília, como a silver grava): antes das 8h, às 20h, a partir das 21h e aos
      domingos, em todos os canais;
    - salvaguardas que falharam: tentativas depois de um `opt_out` no mesmo destino (qualquer CPF)
      e no mesmo par CPF x destino, e depois de um `falecido` no mesmo CPF;
    - destino: tentativas que a gold liga a um contato (`ft_tentativa_contato`, `sk_contato`) e as
      que não ligam a nenhum contato dos provedores.
  Rodar com `dbt show --select perfil_contatos_realizados`.
#}
WITH tTentativas AS (
  SELECT
    contato_id
    , cpf_alvo
    , canal
    , destino
    , data_hora
    , resultado
  FROM {{ ref('silver_cobranca_contatos_realizados') }}
)

, tProvedoresPorTentativa AS (
  SELECT
    contato_id
    , COUNT(*) AS qt_provedores
  FROM {{ ref('silver_cobranca_contatos_realizados_provedores') }}
  GROUP BY contato_id
)

, tPrimeiroOptOutNoDestino AS (
  SELECT
    destino
    , MIN(data_hora) AS data_hora
  FROM tTentativas
  WHERE 1 = 1
    AND resultado = 'opt_out'
  GROUP BY destino
)

, tPrimeiroOptOutNoPar AS (
  SELECT
    cpf_alvo
    , destino
    , MIN(data_hora) AS data_hora
  FROM tTentativas
  WHERE 1 = 1
    AND resultado = 'opt_out'
  GROUP BY cpf_alvo, destino
)

, tPrimeiroFalecido AS (
  SELECT
    cpf_alvo
    , MIN(data_hora) AS data_hora
  FROM tTentativas
  WHERE 1 = 1
    AND resultado = 'falecido'
  GROUP BY cpf_alvo
)

, tMedidas AS (
  SELECT
    CAST('tentativas' AS VARCHAR) AS medida
    , COUNT(*) AS qt
  FROM tTentativas

  UNION ALL

  SELECT
    CAST('cpfs_alvo' AS VARCHAR) AS medida
    , COUNT(DISTINCT cpf_alvo) AS qt
  FROM tTentativas

  UNION ALL

  SELECT
    CAST('canais' AS VARCHAR) AS medida
    , COUNT(DISTINCT canal) AS qt
  FROM tTentativas

  UNION ALL

  SELECT
    CAST('resultados' AS VARCHAR) AS medida
    , COUNT(DISTINCT resultado) AS qt
  FROM tTentativas

  UNION ALL

  SELECT
    'tentativas_vistas_por_' || CAST(qt_provedores AS VARCHAR) || '_provedores' AS medida
    , COUNT(*) AS qt
  FROM tProvedoresPorTentativa
  GROUP BY qt_provedores

  UNION ALL

  SELECT
    CAST('horario_antes_das_8h' AS VARCHAR) AS medida
    , COUNT(CASE WHEN EXTRACT(HOUR FROM data_hora) < 8 THEN 1 END) AS qt
  FROM tTentativas

  UNION ALL

  SELECT
    CAST('horario_as_20h' AS VARCHAR) AS medida
    , COUNT(CASE WHEN EXTRACT(HOUR FROM data_hora) = 20 THEN 1 END) AS qt
  FROM tTentativas

  UNION ALL

  SELECT
    CAST('horario_a_partir_das_21h' AS VARCHAR) AS medida
    , COUNT(CASE WHEN EXTRACT(HOUR FROM data_hora) >= 21 THEN 1 END) AS qt
  FROM tTentativas

  UNION ALL

  SELECT
    CAST('horario_domingo' AS VARCHAR) AS medida
    , COUNT(CASE WHEN EXTRACT(DOW FROM data_hora) = 0 THEN 1 END) AS qt
  FROM tTentativas

  UNION ALL

  SELECT
    CAST('salvaguarda_apos_opt_out_no_destino' AS VARCHAR) AS medida
    , COUNT(*) AS qt
  FROM tTentativas
  INNER JOIN tPrimeiroOptOutNoDestino
    ON
      tTentativas.destino = tPrimeiroOptOutNoDestino.destino
      AND tTentativas.data_hora > tPrimeiroOptOutNoDestino.data_hora

  UNION ALL

  SELECT
    CAST('salvaguarda_apos_opt_out_no_par' AS VARCHAR) AS medida
    , COUNT(*) AS qt
  FROM tTentativas
  INNER JOIN tPrimeiroOptOutNoPar
    ON
      tTentativas.cpf_alvo = tPrimeiroOptOutNoPar.cpf_alvo
      AND tTentativas.destino = tPrimeiroOptOutNoPar.destino
      AND tTentativas.data_hora > tPrimeiroOptOutNoPar.data_hora

  UNION ALL

  SELECT
    CAST('salvaguarda_apos_falecido_no_cpf' AS VARCHAR) AS medida
    , COUNT(*) AS qt
  FROM tTentativas
  INNER JOIN tPrimeiroFalecido
    ON
      tTentativas.cpf_alvo = tPrimeiroFalecido.cpf_alvo
      AND tTentativas.data_hora > tPrimeiroFalecido.data_hora

  UNION ALL

  SELECT
    CAST('destino_com_contato_na_gold' AS VARCHAR) AS medida
    , COUNT(CASE WHEN sk_contato IS NOT NULL THEN 1 END) AS qt
  FROM {{ ref('ft_tentativa_contato') }}

  UNION ALL

  SELECT
    CAST('destino_sem_contato_nos_provedores' AS VARCHAR) AS medida
    , COUNT(CASE WHEN sk_contato IS NULL THEN 1 END) AS qt
  FROM {{ ref('ft_tentativa_contato') }}
)

SELECT
  medida
  , qt
FROM tMedidas
ORDER BY medida
