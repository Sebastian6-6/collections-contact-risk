{#
  Uma data do alfa que chega preenchida em formato desconhecido (ou inexistente no calendário)
  vira NULL na padronização, e nenhum outro teste a conta. Hoje nenhuma linha cai nesse caso. A linha que repete o cabeçalho do arquivo fica fora. O
  teste avisa (`warn`) em vez de a regra adivinhar o formato ou apagar o valor em silêncio. Cada
  linha devolvida é uma linha legível da bronze cuja coluna veio preenchida e ficou NULL no
  modelo `*_padronizados`, com a coluna e o valor recebido. Colunas conferidas: `data_nascimento` e `data_atualizacao`.
  Um teste por fonte, porque os modelos efêmeros de fontes diferentes compilam com o mesmo nome de
  CTE e não cabem numa consulta só.
#}
{{ config(severity='warn') }}

WITH tAlfa AS (
  SELECT
    b._arquivo
    , b._linha
    , b.data_nascimento AS nascimento_origem
    , b.data_atualizacao AS atualizacao_origem
    , p.data_nascimento IS NULL AS nascimento_nulo
    , p.data_atualizacao IS NULL AS atualizacao_nula
  FROM {{ source('bronze_alfa', 'devedores') }} AS b
  LEFT JOIN {{ source('bronze_alfa', 'arquivos') }} AS a
    ON b._arquivo = a.arquivo
  INNER JOIN {{ ref('silver_alfa_devedores_padronizados') }} AS p
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
  FROM tAlfa

  UNION ALL

  SELECT
    'data_atualizacao' AS coluna
    , _arquivo
    , _linha
    , atualizacao_origem AS valor
    , atualizacao_nula AS ficou_nulo
  FROM tAlfa
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
