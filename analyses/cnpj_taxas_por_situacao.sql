{#
  Valor do CNPJ (p. 2 do enunciado), parte 2: as tentativas de setembro pela situação do
  empregador do devedor.
  Grão: uma linha por situação do empregador x canal, mais a linha `todos` de cada situação.
  A situação vem do vínculo atual do devedor (`ft_vinculo_empresa`, `situacao_vinculo` = `atual`;
  há no máximo um por devedor): a situação cadastral na Receita em minúsculas (`ativa`, `baixada`,
  `inapta`...), `nao_encontrado` quando a Receita não tem o estabelecimento, ou `sem_vinculo` quando
  o devedor não tem vínculo atual. `qt_devedores` conta todos os devedores da situação, com ou sem
  tentativa; `qt_devedores_tentados`, os que receberam tentativa no canal. `margem_*_pp` é a meia
  largura do intervalo de 95% da taxa (aproximação normal), como em `cnpj_cobertura_empregadores`.
  Rodar com `dbt show --select cnpj_taxas_por_situacao`.
#}
WITH tSituacaoDoDevedor AS (
  SELECT
    devedores.sk_devedor
    , CASE
      WHEN vinculos.sk_devedor IS NULL THEN 'sem_vinculo'
      WHEN empregadores.situacao_receita = 'nao_encontrado' THEN 'nao_encontrado'
      ELSE LOWER(empregadores.desc_situacao_cadastral)
    END AS situacao_empregador
  FROM {{ ref('dim_devedor') }} AS devedores
  LEFT JOIN {{ ref('ft_vinculo_empresa') }} AS vinculos
    ON
      devedores.sk_devedor = vinculos.sk_devedor
      AND vinculos.situacao_vinculo = 'atual'
  LEFT JOIN {{ ref('dim_empregador') }} AS empregadores
    ON vinculos.sk_empregador = empregadores.sk_empregador
)

, tDevedoresPorSituacao AS (
  SELECT
    situacao_empregador
    , COUNT(*) AS qt_devedores
  FROM tSituacaoDoDevedor
  GROUP BY situacao_empregador
)

, tTentativas AS (
  SELECT
    tSituacaoDoDevedor.situacao_empregador
    , tentativas.canal
    , tentativas.sk_devedor
    , tentativas.tipo_desfecho
  FROM {{ ref('ft_tentativa_contato') }} AS tentativas
  INNER JOIN tSituacaoDoDevedor
    ON tentativas.sk_devedor = tSituacaoDoDevedor.sk_devedor
)

, tPorCanal AS (
  SELECT
    situacao_empregador
    , canal
    , COUNT(DISTINCT sk_devedor) AS qt_devedores_tentados
    , COUNT(*) AS qt_tentativas
    , COUNT(CASE WHEN tipo_desfecho = 'terceiro' THEN 1 END) AS qt_terceiro
    , COUNT(CASE WHEN tipo_desfecho = 'contato_confirmado' THEN 1 END) AS qt_contato_confirmado
  FROM tTentativas
  GROUP BY situacao_empregador, canal

  UNION ALL

  SELECT
    situacao_empregador
    , CAST('todos' AS VARCHAR) AS canal
    , COUNT(DISTINCT sk_devedor) AS qt_devedores_tentados
    , COUNT(*) AS qt_tentativas
    , COUNT(CASE WHEN tipo_desfecho = 'terceiro' THEN 1 END) AS qt_terceiro
    , COUNT(CASE WHEN tipo_desfecho = 'contato_confirmado' THEN 1 END) AS qt_contato_confirmado
  FROM tTentativas
  GROUP BY situacao_empregador
)

, tFracoes AS (
  SELECT
    tPorCanal.situacao_empregador
    , tPorCanal.canal
    , tDevedoresPorSituacao.qt_devedores
    , tPorCanal.qt_devedores_tentados
    , tPorCanal.qt_tentativas
    , tPorCanal.qt_terceiro
    , tPorCanal.qt_contato_confirmado
    , CAST(tPorCanal.qt_terceiro AS NUMERIC) / tPorCanal.qt_tentativas AS tx_terceiro
    , CAST(tPorCanal.qt_contato_confirmado AS NUMERIC) / tPorCanal.qt_tentativas
      AS tx_confirmado
  FROM tPorCanal
  INNER JOIN tDevedoresPorSituacao
    ON tPorCanal.situacao_empregador = tDevedoresPorSituacao.situacao_empregador
)

, tTaxas AS (
  SELECT
    situacao_empregador
    , canal
    , qt_devedores
    , qt_devedores_tentados
    , qt_tentativas
    , qt_terceiro
    , qt_contato_confirmado
    , ROUND(100 * tx_terceiro, 2) AS tx_terceiro_pct
    , ROUND(CAST(196 * SQRT(tx_terceiro * (1 - tx_terceiro) / qt_tentativas) AS NUMERIC), 2)
      AS margem_terceiro_pp
    , ROUND(100 * tx_confirmado, 2) AS tx_contato_confirmado_pct
    , ROUND(CAST(196 * SQRT(tx_confirmado * (1 - tx_confirmado) / qt_tentativas) AS NUMERIC), 2)
      AS margem_contato_confirmado_pp
  FROM tFracoes
)

SELECT
  situacao_empregador
  , canal
  , qt_devedores
  , qt_devedores_tentados
  , qt_tentativas
  , qt_terceiro
  , tx_terceiro_pct
  , margem_terceiro_pp
  , qt_contato_confirmado
  , tx_contato_confirmado_pct
  , margem_contato_confirmado_pp
FROM tTaxas
ORDER BY situacao_empregador ASC, canal ASC
