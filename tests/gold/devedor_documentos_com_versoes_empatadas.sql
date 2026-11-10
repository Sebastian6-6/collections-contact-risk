{#
  Aviso com a contagem dos documentos cuja versão mais recente empata com outra versão diferente
  na data de atualização, na data de entrega e no arquivo (ponto 4): cada linha devolvida é um
  documento, e o número de linhas é a contagem. Não é defeito da silver, que decide pela linha
  de forma determinística; o aviso deixa o número visível para o README.
#}
{{ config(severity='warn') }}

SELECT
  provedor
  , documento_tipo
  , documento
FROM {{ ref('devedores_conflitos_versao') }}
