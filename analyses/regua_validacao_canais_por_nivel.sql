{#
  Validação da régua, passo 7: estratégia de canais e mensagens por nível no corte D (padrão
  2026-09-15). Grão: uma linha por `nivel_risco` x `canal`, sobre as tentativas depois de D, com
  o que cada canal rendeu naquele nível: taxa de contato confirmado, taxa de terceiro e o
  percentual de tentativas fora da janela de horário (`ft_tentativa_contato`; e-mail não tem
  janela). `desc_acao` repete a ação de cada nível da seção 9.9. Rodar com
  `dbt show --select regua_validacao_canais_por_nivel`.
#}
WITH {{ regua_tentativas_avaliadas() }}

, tPorNivelCanal AS (
  SELECT
    tTentativasAvaliadas.nivel_risco
    , tTentativasAvaliadas.canal
    , COUNT(*) AS qt_tentativas
    , COUNT(CASE WHEN tTentativasAvaliadas.tipo_desfecho = 'contato_confirmado' THEN 1 END)
      AS qt_contato_confirmado
    , COUNT(CASE WHEN tTentativasAvaliadas.tipo_desfecho = 'terceiro' THEN 1 END) AS qt_terceiro
    , COUNT(
      CASE
        WHEN ft_tentativa_contato.situacao_horario IN ('fora_do_horario', 'domingo', 'feriado')
          THEN 1
      END
    ) AS qt_fora_da_janela
  FROM tTentativasAvaliadas
  INNER JOIN {{ ref('ft_tentativa_contato') }} AS ft_tentativa_contato
    ON tTentativasAvaliadas.contato_id = ft_tentativa_contato.contato_id
  GROUP BY tTentativasAvaliadas.nivel_risco, tTentativasAvaliadas.canal
)

SELECT
  nivel_risco
  , canal
  , qt_tentativas
  , ROUND(100 * CAST(qt_contato_confirmado AS NUMERIC) / NULLIF(qt_tentativas, 0), 2)
    AS tx_contato_confirmado_pct
  , ROUND(100 * CAST(qt_terceiro AS NUMERIC) / NULLIF(qt_tentativas, 0), 2) AS tx_terceiro_pct
  , ROUND(100 * CAST(qt_fora_da_janela AS NUMERIC) / NULLIF(qt_tentativas, 0), 2)
    AS tx_fora_da_janela_pct
  , CASE nivel_risco
    WHEN 'liberado' THEN 'mensagem de cobrança'
    WHEN 'atencao' THEN 'mensagem neutra pedindo retorno ou confirmação de identidade'
    WHEN 'bloqueado' THEN 'sem contato; lista de não-contatar'
    ELSE 'sem nível: o par não estava na base em D'
  END AS desc_acao
FROM tPorNivelCanal
ORDER BY nivel_risco ASC, canal ASC
