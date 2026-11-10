{#
  Grão: uma linha por (versão, posição do endereço na lista). São os endereços de cada versão de
  `devedores_historico`, tirados da linha da aparição mais recente da versão, já padronizados. O
  beta manda o endereço como lista ou como um objeto só; o objeto vira a posição 1. O `atual`
  fica como veio (S7): nenhuma regra escolhe o endereço vigente aqui.
#}

SELECT
  h.hash_conteudo
  , e.posicao
  , e.tipo
  , e.logradouro
  , e.numero
  , e.complemento
  , e.bairro
  , e.cidade
  , e.uf
  , e.cep
  , e.atual
  , e._arquivo
  , e._linha
  , e._hash_arquivo
FROM {{ ref('silver_beta_devedores_historico') }} AS h
INNER JOIN {{ ref('silver_beta_devedores_enderecos_padronizados') }} AS e
  ON h._arquivo = e._arquivo
    AND h._linha = e._linha
