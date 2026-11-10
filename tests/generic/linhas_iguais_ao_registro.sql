{#
  Confere a carga contra o registro de arquivos da mesma fonte: cada arquivo do registro precisa
  ter na tabela tantas linhas quanto `linhas` diz (um arquivo só com cabeçalho tem 0), e a tabela
  não pode ter linha de arquivo que o registro não conhece. O registro filtra pela entidade, que
  por padrão é o nome da própria tabela.
  Uso: `arguments: {registro: source('bronze_alfa', 'arquivos')}`.
#}
{% test linhas_iguais_ao_registro(model, registro, entidade=none) %}

WITH tRegistrados AS (
  SELECT
    arquivo
    , linhas
  FROM {{ registro }}
  WHERE entidade = '{{ entidade if entidade else model.identifier }}'
)

, tDivergentes AS (
  SELECT
    r.arquivo
    , r.linhas AS qt_registradas
    , COUNT(m._arquivo) AS qt_na_tabela
  FROM tRegistrados AS r
  LEFT JOIN {{ model }} AS m
    ON r.arquivo = m._arquivo
  GROUP BY
    r.arquivo
    , r.linhas
  HAVING COUNT(m._arquivo) <> r.linhas
)

, tSemRegistro AS (
  SELECT
    m._arquivo AS arquivo
    , CAST(NULL AS BIGINT) AS qt_registradas
    , COUNT(*) AS qt_na_tabela
  FROM {{ model }} AS m
  LEFT JOIN tRegistrados AS r
    ON m._arquivo = r.arquivo
  WHERE r.arquivo IS NULL
  GROUP BY m._arquivo
)

SELECT
  arquivo
  , qt_registradas
  , qt_na_tabela
FROM tDivergentes

UNION ALL

SELECT
  arquivo
  , qt_registradas
  , qt_na_tabela
FROM tSemRegistro

{% endtest %}
