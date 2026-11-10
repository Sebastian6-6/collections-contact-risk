{#
  Falha para cada combinação de colunas que aparece mais de uma vez. O dbt só traz `unique` para
  uma coluna; aqui a chave é composta, como (`_arquivo`, `_linha`) na bronze. Cada linha devolvida
  é uma combinação repetida, com quantas vezes aparece.
  NULL conta como um valor: duas linhas com NULL na mesma coluna e o resto igual são repetição
  (o `unique` do dbt ignora NULL; este não). A prova está em
  `tests/macros/teste_combinacao_unica_trata_null_como_valor.sql`.
  Uso: `arguments: {colunas: [_arquivo, _linha]}`.
#}
{% test combinacao_unica(model, colunas) %}

WITH tRepetidas AS (
  SELECT
    {{ colunas | join('\n    , ') }}
    , COUNT(*) AS qt_linhas
  FROM {{ model }}
  GROUP BY
    {{ colunas | join('\n    , ') }}
  HAVING COUNT(*) > 1
)

SELECT *
FROM tRepetidas

{% endtest %}
