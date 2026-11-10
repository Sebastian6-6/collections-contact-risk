{#
  A versão que a `silver_gama_devedores` escolhe para cada documento tem de ser a de maior
  `_arquivo` entre as linhas que empatam com ela em atualização, entrega e linha. Devolve uma
  linha para cada documento em que outra linha empata com a vencedora e tem `_arquivo` maior,
  ou seja, em que o vencedor ficou arbitrário por falta do desempate pelo arquivo (o original e
  o reenvio da mesma data trazem a mesma linha).
#}
SELECT
  v.documento
  , v._arquivo AS arquivo_vencedor
  , MAX(p._arquivo) AS maior_arquivo_empatado
FROM {{ ref('silver_gama_devedores') }} AS v
INNER JOIN {{ ref('silver_gama_devedores_padronizados') }} AS p
  ON v.documento = p.documento
    AND v.dt_ref IS NOT DISTINCT FROM p.dt_ref
    AND v.data_entrega IS NOT DISTINCT FROM p.data_entrega
    AND v._linha = p._linha
GROUP BY
  v.documento
  , v._arquivo
HAVING MAX(p._arquivo) > v._arquivo
