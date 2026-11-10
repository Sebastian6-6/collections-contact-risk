{#
  Nenhum arquivo, fora o histórico configurado em `arquivo_historico`, pode chegar à silver sem
  data de entrega. Devolve uma linha para cada arquivo cujo nome não traz uma data AAAA-MM-DD
  válida (por exemplo `provedor_alfa_20260901.csv` ou `provedor_alfa_2026-09-31.csv`, que casam
  com o padrão `provedor_alfa_*.csv`). Severidade `error`: a data de entrega ordena a versão
  vencedora, então uma entrega sem data reprova a pipeline em vez de herdar a data da carga
  histórica. A conferência é na bronze, com a mesma macro da silver, para pegar também o arquivo
  cujas linhas ficam todas fora da silver por não terem documento.
#}
{{ config(severity='error') }}

SELECT
  'alfa' AS fonte
  , _arquivo
  , COUNT(*) AS qt_linhas
FROM {{ source('bronze_alfa', 'devedores') }}
WHERE 1 = 1
  AND {{ data_de_entrega('_arquivo', 'alfa') }} IS NULL
GROUP BY _arquivo

UNION ALL

SELECT
  'beta' AS fonte
  , _arquivo
  , COUNT(*) AS qt_linhas
FROM {{ source('bronze_beta', 'devedores') }}
WHERE 1 = 1
  AND {{ data_de_entrega('_arquivo', 'beta') }} IS NULL
GROUP BY _arquivo

UNION ALL

SELECT
  'gama' AS fonte
  , _arquivo
  , COUNT(*) AS qt_linhas
FROM {{ source('bronze_gama', 'devedores') }}
WHERE 1 = 1
  AND {{ data_de_entrega('_arquivo', 'gama') }} IS NULL
GROUP BY _arquivo
