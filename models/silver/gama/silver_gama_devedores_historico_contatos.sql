{#
  Grão: uma linha por (versão, tipo_contato, contato normalizado). São os telefones e e-mails de
  cada versão de `devedores_historico`, tirados da linha da aparição mais recente da versão (a
  lista é igual em todas as aparições, a menos da posição, porque a assinatura dela faz parte do
  `hash_conteudo`). `celular` e `fixo` viram o `tipo_contato` `telefone`, com o `tipo` do
  provedor; o `email` não tem `tipo`. A versão de linha com a lista truncada (JSON inválido) não
  tem contato legível e fica sem linhas aqui.
#}

SELECT
  h.hash_conteudo
  , c.tipo_contato
  , c.contato
  , c.tipo
  , c.posicao
  , c._arquivo
  , c._linha
  , c._hash_arquivo
FROM {{ ref('silver_gama_devedores_historico') }} AS h
INNER JOIN {{ ref('silver_gama_devedores_contatos_padronizados') }} AS c
  ON h._arquivo = c._arquivo
    AND h._linha = c._linha
