{#
  Valor do CNPJ (p. 2 do enunciado), parte 1: o que a Receita devolve para cada empregador.
  Grão: um CNPJ recebido (`dim_empregador`), com:
    - `situacao_raiz_receita`: se a raiz (os 8 primeiros caracteres) tem empresa na Receita, mesmo
      quando o estabelecimento recebido não existe (`situacao_receita` = `nao_encontrado`);
    - situação cadastral, porte e CNAE do estabelecimento, `NULL` quando não encontrado;
    - os devedores cujo vínculo atual (`situacao_vinculo` = `atual`) é com esse CNPJ e as
      tentativas de setembro a eles, com a taxa de terceiro e a de contato confirmado.
  `margem_*_pp` é a meia largura do intervalo de 95% da taxa (aproximação normal,
  1,96 x raiz de p(1 - p) / n), em pontos percentuais: duas taxas cuja diferença cabe nas margens
  não se distinguem com esse volume. Rodar com `dbt show --select cnpj_cobertura_empregadores`.
#}
WITH tVinculoAtual AS (
  SELECT
    sk_devedor
    , sk_empregador
  FROM {{ ref('ft_vinculo_empresa') }}
  WHERE 1 = 1
    AND situacao_vinculo = 'atual'
)

, tTentativasPorEmpregador AS (
  SELECT
    tVinculoAtual.sk_empregador
    , COUNT(DISTINCT tVinculoAtual.sk_devedor) AS qt_devedores
    , COUNT(tentativas.contato_id) AS qt_tentativas
    , COUNT(CASE WHEN tentativas.tipo_desfecho = 'terceiro' THEN 1 END) AS qt_terceiro
    , COUNT(CASE WHEN tentativas.tipo_desfecho = 'contato_confirmado' THEN 1 END)
      AS qt_contato_confirmado
  FROM tVinculoAtual
  LEFT JOIN {{ ref('ft_tentativa_contato') }} AS tentativas
    ON tVinculoAtual.sk_devedor = tentativas.sk_devedor
  GROUP BY tVinculoAtual.sk_empregador
)

, tFracoes AS (
  SELECT
    sk_empregador
    , qt_devedores
    , qt_tentativas
    , qt_terceiro
    , qt_contato_confirmado
    , CAST(qt_terceiro AS NUMERIC) / NULLIF(qt_tentativas, 0) AS tx_terceiro
    , CAST(qt_contato_confirmado AS NUMERIC) / NULLIF(qt_tentativas, 0) AS tx_confirmado
  FROM tTentativasPorEmpregador
)

, tTaxas AS (
  SELECT
    sk_empregador
    , qt_devedores
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

, tEmpregadores AS (
  SELECT
    empregadores.sk_empregador
    , empregadores.cnpj
    , empregadores.situacao_receita
    , empregadores.desc_situacao_cadastral
    , empregadores.desc_porte
    , empregadores.cnae
    , empregadores.desc_cnae
    , empregadores.nome_razao_social
    , CASE
      WHEN empresas.cnpj_basico IS NOT NULL THEN 'encontrada'
      ELSE 'nao_encontrada'
    END AS situacao_raiz_receita
  FROM {{ ref('dim_empregador') }} AS empregadores
  LEFT JOIN {{ ref('silver_receita_empresas') }} AS empresas
    ON LEFT(empregadores.cnpj, 8) = empresas.cnpj_basico
)

SELECT
  tEmpregadores.cnpj
  , tEmpregadores.situacao_receita
  , tEmpregadores.situacao_raiz_receita
  , tEmpregadores.desc_situacao_cadastral
  , tEmpregadores.desc_porte
  , tEmpregadores.cnae
  , tEmpregadores.desc_cnae
  , tEmpregadores.nome_razao_social

  , tTaxas.qt_devedores
  , tTaxas.qt_tentativas
  , tTaxas.qt_terceiro
  , tTaxas.tx_terceiro_pct
  , tTaxas.margem_terceiro_pp
  , tTaxas.qt_contato_confirmado
  , tTaxas.tx_contato_confirmado_pct
  , tTaxas.margem_contato_confirmado_pp
FROM tEmpregadores
LEFT JOIN tTaxas
  ON tEmpregadores.sk_empregador = tTaxas.sk_empregador
ORDER BY tEmpregadores.situacao_receita ASC, tEmpregadores.cnpj ASC
