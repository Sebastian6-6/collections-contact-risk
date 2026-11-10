{#
  Validação da régua, passo 6: segmentação dos devedores elegíveis no corte D (padrão 2026-09-15).
  Grão: uma linha por segmento de devedor, pelo melhor nível entre os pares dele em D:
    - `cobranca_normal`: ao menos um par `liberado` (mensagem de cobrança);
    - `cobranca_com_cautela`: sem par liberado, ao menos um `atencao` (mensagem neutra);
    - `nao_contatar`: todos os pares `bloqueado`.
  Devedores sem par na régua em D não têm segmento. Mostra quantos devedores e pares há em cada
  segmento e quantos pares por tipo de contato, que é o que define os canais possíveis (telefone
  serve a ligação, SMS e WhatsApp; e-mail só a ele mesmo). Rodar com
  `dbt show --select regua_validacao_segmentacao`.
#}
WITH {{ regua_tentativas_avaliadas() }}

, tPares AS (
  SELECT
    tReguaNoCorte.sk_devedor
    , tSinaisDoPar.tipo_contato
    , tReguaNoCorte.nivel_risco
    , CASE tReguaNoCorte.nivel_risco
      WHEN 'liberado' THEN 1
      WHEN 'atencao' THEN 2
      ELSE 3
    END AS ordem_nivel
  FROM tReguaNoCorte
  INNER JOIN tSinaisDoPar
    ON tReguaNoCorte.sk_contato = tSinaisDoPar.sk_contato
  WHERE 1 = 1
    AND tReguaNoCorte.sk_devedor IS NOT NULL
)

, tDevedores AS (
  SELECT
    sk_devedor
    , MIN(ordem_nivel) AS melhor_ordem
  FROM tPares
  GROUP BY sk_devedor
)

, tSegmentos AS (
  SELECT
    tDevedores.sk_devedor
    , tPares.tipo_contato
    , tPares.nivel_risco
    , CASE tDevedores.melhor_ordem
      WHEN 1 THEN 'cobranca_normal'
      WHEN 2 THEN 'cobranca_com_cautela'
      ELSE 'nao_contatar'
    END AS segmento
  FROM tDevedores
  INNER JOIN tPares
    ON tDevedores.sk_devedor = tPares.sk_devedor
)

SELECT
  segmento
  , COUNT(DISTINCT sk_devedor) AS qt_devedores
  , COUNT(*) AS qt_pares
  , COUNT(CASE WHEN nivel_risco = 'liberado' THEN 1 END) AS qt_pares_liberados
  , COUNT(CASE WHEN nivel_risco = 'atencao' THEN 1 END) AS qt_pares_atencao
  , COUNT(CASE WHEN nivel_risco = 'bloqueado' THEN 1 END) AS qt_pares_bloqueados
  , COUNT(CASE WHEN tipo_contato = 'telefone' AND nivel_risco <> 'bloqueado' THEN 1 END)
    AS qt_pares_telefone_contatavel
  , COUNT(CASE WHEN tipo_contato = 'email' AND nivel_risco <> 'bloqueado' THEN 1 END)
    AS qt_pares_email_contatavel
FROM tSegmentos
GROUP BY segmento
ORDER BY segmento ASC
