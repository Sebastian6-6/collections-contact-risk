{#
  Tabela de domínio da Receita (CNAE, motivo, município, natureza jurídica, país, qualificação):
  duas colunas, `codigo` e `descricao`, iguais nas seis. Grão: uma linha por `codigo`; se a origem
  repetir o código (hoje não repete), vale a linha mais recente do arquivo. Texto sem espaços nas
  pontas; o código fica como texto, porque os zeros à esquerda fazem parte dele (`0111301`, `00`).
  Os seis modelos só chamam esta macro, para a regra ficar num lugar só.
#}
{% macro silver_receita_dominio(entidade) -%}
WITH tPadronizados AS (
  SELECT
    NULLIF(TRIM(codigo), '') AS codigo
    , NULLIF(TRIM(descricao), '') AS descricao
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ source('bronze_receita', entidade) }}
  WHERE 1 = 1
    AND _motivo_ilegivel IS NULL
)

, tVersoes AS (
  SELECT
    codigo
    , descricao
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY codigo
      ORDER BY _arquivo DESC, _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM tPadronizados
  WHERE 1 = 1
    AND codigo IS NOT NULL
)

SELECT
  codigo
  , descricao
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
{%- endmacro %}
