{#
  Prova que o teste genérico `combinacao_unica` trata NULL como um valor da chave: duas linhas com
  a mesma combinação, inclusive com NULL em uma coluna, contam como repetição. É o que protege a
  chave de `devedores_contatos`, onde `documento` é NULL nos contatos de linhas sem documento. O
  `unique` do dbt ignora NULL, por isso a chave composta usa `combinacao_unica`.
  Falha se a repetição com NULL passar despercebida ou se linhas distintas forem acusadas.
#}
{%- set com_repeticao_em_null -%}
(
  SELECT
    CAST(NULL AS VARCHAR) AS documento
    , 'telefone' AS tipo_contato
    , '11900405285' AS contato

  UNION ALL

  SELECT
    CAST(NULL AS VARCHAR) AS documento
    , 'telefone' AS tipo_contato
    , '11900405285' AS contato

  UNION ALL

  SELECT
    '12345678909' AS documento
    , 'telefone' AS tipo_contato
    , '11900405285' AS contato
) AS tFixture
{%- endset -%}
{%- set sem_repeticao -%}
(
  SELECT
    CAST(NULL AS VARCHAR) AS documento
    , 'telefone' AS tipo_contato
    , '11900405285' AS contato

  UNION ALL

  SELECT
    '12345678909' AS documento
    , 'telefone' AS tipo_contato
    , '11900405285' AS contato

  UNION ALL

  SELECT
    CAST(NULL AS VARCHAR) AS documento
    , 'email' AS tipo_contato
    , 'a@x.com' AS contato
) AS tFixture
{%- endset -%}
{%- set colunas = ['documento', 'tipo_contato', 'contato'] -%}

WITH tRepeticoesComNull AS (
  {{ test_combinacao_unica(com_repeticao_em_null, colunas) }}
)

, tRepeticoesSemNull AS (
  {{ test_combinacao_unica(sem_repeticao, colunas) }}
)

, tContagens AS (
  SELECT
    (SELECT COUNT(*) FROM tRepeticoesComNull) AS qt_com_null
    , (SELECT COUNT(*) FROM tRepeticoesSemNull) AS qt_sem_repeticao
)

SELECT 'repetição com NULL na chave não foi detectada' AS falha
FROM tContagens
WHERE 1 = 1
  AND qt_com_null <> 1

UNION ALL

SELECT 'combinações distintas foram acusadas como repetição' AS falha
FROM tContagens
WHERE 1 = 1
  AND qt_sem_repeticao <> 0
