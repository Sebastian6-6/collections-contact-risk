{#
  Falha para cada combinação de colunas que aparece mais de uma vez. O dbt só traz `unique` para
  uma coluna; aqui a chave é composta, como (`_arquivo`, `_linha`) na bronze. Cada linha devolvida
  é uma combinação repetida, com quantas vezes aparece.
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
