{#
  Grão: uma linha por (versão, tipo_contato, contato normalizado). São os telefones e e-mails de
  cada versão de `devedores_historico`, tirados da linha da aparição mais recente da versão (a
  lista é igual em todas as aparições, a menos da posição, porque a assinatura dela faz parte do
  `hash_conteudo`). Só existe linha para contato que veio preenchido. O `tipo` do telefone e o
  `principal` são do provedor e ficam `NULL` quando o elemento não os traz.
#}
{{ config(materialized='table') }}

SELECT
  h.hash_conteudo
  , c.tipo_contato
  , c.contato
  , c.tipo
  , c.principal
  , c.posicao
  , c._arquivo
  , c._linha
  , c._hash_arquivo
FROM {{ ref('silver_beta_devedores_historico') }} AS h
INNER JOIN {{ ref('silver_beta_devedores_contatos_padronizados') }} AS c
  ON h._arquivo = c._arquivo
    AND h._linha = c._linha
