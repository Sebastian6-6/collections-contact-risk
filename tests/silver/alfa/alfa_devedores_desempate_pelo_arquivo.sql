{#
  A versão que a `silver_alfa_devedores` escolhe para cada documento tem de ser a de maior
  `_arquivo` entre as linhas que empatam com ela em atualização, entrega e linha. Devolve uma
  linha para cada documento em que outra linha empata com a vencedora e tem `_arquivo` maior,
  ou seja, em que o vencedor ficou arbitrário por falta do desempate pelo arquivo (o original e
  o reenvio da mesma data trazem a mesma linha).
#}
SELECT
  v.documento
  , v._arquivo AS arquivo_vencedor
  , MAX(p._arquivo) AS maior_arquivo_empatado
FROM {{ ref('silver_alfa_devedores') }} AS v
INNER JOIN {{ ref('silver_alfa_devedores_padronizados') }} AS p
  ON p.documento = v.documento
    AND p.data_atualizacao IS NOT DISTINCT FROM v.data_atualizacao
    AND p.data_entrega IS NOT DISTINCT FROM v.data_entrega
    AND p._linha = v._linha
GROUP BY
  v.documento
  , v._arquivo
HAVING MAX(p._arquivo) > v._arquivo
