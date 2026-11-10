{#
  Uma data do gama que chega preenchida em formato desconhecido (ou inexistente no calendário)
  vira NULL na padronização, e nenhum outro teste a conta. Hoje nenhuma linha cai nesse caso. A linha que repete o cabeçalho do arquivo fica fora. O
  teste avisa (`warn`) em vez de a regra adivinhar o formato ou apagar o valor em silêncio. Cada
  linha devolvida é uma linha legível da bronze cuja coluna veio preenchida e ficou NULL no
  modelo `*_padronizados`, com a coluna e o valor recebido. Colunas conferidas: `data_nascimento` e `dt_ref`.
  Um teste por fonte, porque os modelos efêmeros de fontes diferentes compilam com o mesmo nome de
  CTE e não cabem numa consulta só.
#}
{{ config(severity='warn') }}

WITH tGama AS (
  SELECT
    b._arquivo
    , b._linha
    , b.data_nascimento AS nascimento_origem
    , b.dt_ref AS referencia_origem
    , p.data_nascimento IS NULL AS nascimento_nulo
    , p.dt_ref IS NULL AS referencia_nula
  FROM {{ source('bronze_gama', 'devedores') }} AS b
  LEFT JOIN {{ source('bronze_gama', 'arquivos') }} AS a
    ON b._arquivo = a.arquivo
  INNER JOIN {{ ref('silver_gama_devedores_padronizados') }} AS p
    ON b._arquivo = p._arquivo
      AND b._linha = p._linha
  WHERE 1 = 1
    AND b._motivo_ilegivel IS NULL
    AND NOT COALESCE(b._linha_original = a.cabecalho, FALSE)
)

, tDatas AS (
  SELECT
    'data_nascimento' AS coluna
    , _arquivo
    , _linha
    , nascimento_origem AS valor
    , nascimento_nulo AS ficou_nulo
  FROM tGama

  UNION ALL

  SELECT
    'dt_ref' AS coluna
    , _arquivo
    , _linha
    , referencia_origem AS valor
    , referencia_nula AS ficou_nulo
  FROM tGama
)

SELECT
  coluna
  , _arquivo
  , _linha
  , valor
FROM tDatas
WHERE 1 = 1
  AND ficou_nulo
  AND NULLIF(TRIM(valor), '') IS NOT NULL
