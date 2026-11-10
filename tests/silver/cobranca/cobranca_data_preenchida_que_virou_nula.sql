{#
  Uma data do cobranca que chega preenchida em formato desconhecido (ou inexistente no calendário)
  vira NULL na padronização, e nenhum outro teste a conta. Hoje nenhuma linha cai nesse caso. A linha que repete o cabeçalho do arquivo fica fora. O
  teste avisa (`warn`) em vez de a regra adivinhar o formato ou apagar o valor em silêncio. Cada
  linha devolvida é uma linha legível da bronze cuja coluna veio preenchida e ficou NULL no
  modelo `*_padronizados`, com a coluna e o valor recebido. Colunas conferidas: `data_hora`.
  Um teste por fonte, porque os modelos efêmeros de fontes diferentes compilam com o mesmo nome de
  CTE e não cabem numa consulta só.
#}
{{ config(severity='warn') }}

WITH tCobranca AS (
  SELECT
    b._arquivo
    , b._linha
    , b.data_hora AS data_hora_origem
    , p.data_hora IS NULL AS data_hora_nula
  FROM {{ source('bronze_cobranca', 'contatos_realizados') }} AS b
  LEFT JOIN {{ source('bronze_cobranca', 'arquivos') }} AS a
    ON b._arquivo = a.arquivo
  INNER JOIN {{ ref('silver_cobranca_contatos_realizados_padronizados') }} AS p
    ON b._arquivo = p._arquivo
      AND b._linha = p._linha
  WHERE 1 = 1
    AND b._motivo_ilegivel IS NULL
    AND NOT COALESCE(b._linha_original = a.cabecalho, FALSE)
)

, tDatas AS (
  SELECT
    'data_hora' AS coluna
    , _arquivo
    , _linha
    , data_hora_origem AS valor
    , data_hora_nula AS ficou_nulo
  FROM tCobranca
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
