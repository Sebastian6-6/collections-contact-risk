{#
  Linhas do gama com a lista `contatos` truncada (JSON inválido): o devedor entra em `devedores`
  com os demais campos, mas os contatos cortados não chegam a `devedores_contatos`. Só avisa
  (`warn`); cada linha devolvida é uma linha com documento cuja lista não pôde ser aberta. Fora
  dela ficam as linhas ilegíveis e o cabeçalho repetido, que o teste `gama_linhas_sem_chave` conta.
#}
{{ config(severity='warn') }}

SELECT
  p._arquivo
  , p._linha
FROM {{ source('bronze_gama', 'devedores') }} AS b
INNER JOIN {{ ref('silver_gama_devedores_padronizados') }} AS p
  ON b._arquivo = p._arquivo
    AND b._linha = p._linha
WHERE 1 = 1
  AND p.documento IS NOT NULL
  AND p.lista_contatos IS NULL
