{#
  Uma data do beta que chega preenchida em formato desconhecido (ou inexistente no calendário)
  vira NULL na padronização, e nenhum outro teste a conta. Hoje nenhuma linha cai nesse caso. A linha que repete o cabeçalho do arquivo fica fora. O
  teste avisa (`warn`) em vez de a regra adivinhar o formato ou apagar o valor em silêncio. Cada
  linha devolvida é uma linha legível da bronze cuja coluna veio preenchida e ficou NULL no
  modelo `*_padronizados`, com a coluna e o valor recebido. Colunas conferidas: `data_nascimento`, `atualizado_em` e `vinculo_empresa_desde`.
  Um teste por fonte, porque os modelos efêmeros de fontes diferentes compilam com o mesmo nome de
  CTE e não cabem numa consulta só.
#}
{{ config(severity='warn') }}

WITH tBetaBase AS (
  SELECT
    b._arquivo
    , b._linha
    , {{ json_ou_nulo('registro') }} AS registro_json
  FROM {{ source('bronze_beta', 'devedores') }} AS b
  LEFT JOIN {{ source('bronze_beta', 'arquivos') }} AS a
    ON b._arquivo = a.arquivo
  WHERE 1 = 1
    AND b._motivo_ilegivel IS NULL
    AND NOT COALESCE(b._linha_original = a.cabecalho, FALSE)
)

, tBeta AS (
  SELECT
    j._arquivo
    , j._linha
    , j.registro_json ->> 'data_nascimento' AS nascimento_origem
    , j.registro_json ->> 'atualizado_em' AS atualizacao_origem
    , (j.registro_json -> 'vinculo_empresa') ->> 'desde' AS vinculo_origem
    , p.data_nascimento IS NULL AS nascimento_nulo
    , p.atualizado_em IS NULL AS atualizacao_nula
    , p.vinculo_empresa_desde IS NULL AS vinculo_nulo
  FROM tBetaBase AS j
  INNER JOIN {{ ref('silver_beta_devedores_padronizados') }} AS p
    ON j._arquivo = p._arquivo
      AND j._linha = p._linha
)

, tDatas AS (
  SELECT
    'data_nascimento' AS coluna
    , _arquivo
    , _linha
    , nascimento_origem AS valor
    , nascimento_nulo AS ficou_nulo
  FROM tBeta

  UNION ALL

  SELECT
    'atualizado_em' AS coluna
    , _arquivo
    , _linha
    , atualizacao_origem AS valor
    , atualizacao_nula AS ficou_nulo
  FROM tBeta

  UNION ALL

  SELECT
    'vinculo_empresa_desde' AS coluna
    , _arquivo
    , _linha
    , vinculo_origem AS valor
    , vinculo_nulo AS ficou_nulo
  FROM tBeta
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
