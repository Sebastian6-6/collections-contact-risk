{#
  Nenhuma linha que repete o cabeçalho do próprio arquivo (`_linha_original` igual a
  `arquivos.cabecalho`) pode ser a aparição mais recente de uma versão da histórica: ela não é um
  registro. Complementa o aviso `cabecalho_repetido_fora_da_historica`, que só conta as linhas
  da bronze, e falha (erro) se o filtro de qualquer histórica sumir. Cada linha devolvida é um
  (`_arquivo`, `_linha`) de `devedores_historico` que é o cabeçalho de um arquivo. Só confere a
  aparição que a histórica guarda (`_arquivo` e `_linha` da versão mais recente).
#}
WITH tCabecalhosNaHistorica AS (
  SELECT
    'alfa' AS fonte
    , h._arquivo
    , h._linha
  FROM {{ ref('silver_alfa_devedores_historico') }} AS h
  INNER JOIN {{ source('bronze_alfa', 'devedores') }} AS b
    ON h._arquivo = b._arquivo
      AND h._linha = b._linha
  INNER JOIN {{ source('bronze_alfa', 'arquivos') }} AS a
    ON h._arquivo = a.arquivo
  WHERE 1 = 1
    AND b._linha_original = a.cabecalho

  UNION ALL

  SELECT
    'beta' AS fonte
    , h._arquivo
    , h._linha
  FROM {{ ref('silver_beta_devedores_historico') }} AS h
  INNER JOIN {{ source('bronze_beta', 'devedores') }} AS b
    ON h._arquivo = b._arquivo
      AND h._linha = b._linha
  INNER JOIN {{ source('bronze_beta', 'arquivos') }} AS a
    ON h._arquivo = a.arquivo
  WHERE 1 = 1
    AND b._linha_original = a.cabecalho

  UNION ALL

  SELECT
    'gama' AS fonte
    , h._arquivo
    , h._linha
  FROM {{ ref('silver_gama_devedores_historico') }} AS h
  INNER JOIN {{ source('bronze_gama', 'devedores') }} AS b
    ON h._arquivo = b._arquivo
      AND h._linha = b._linha
  INNER JOIN {{ source('bronze_gama', 'arquivos') }} AS a
    ON h._arquivo = a.arquivo
  WHERE 1 = 1
    AND b._linha_original = a.cabecalho
)

SELECT
  fonte
  , _arquivo
  , _linha
FROM tCabecalhosNaHistorica
