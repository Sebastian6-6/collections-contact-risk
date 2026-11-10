{#
  Aviso: a macro `nome_comparavel` só tira os acentos do mapa dela. Cada linha devolvida é um
  nome cuja chave de comparação ainda traz um caractere fora do ASCII imprimível, isto é, um
  acento que o mapa não cobre e que poderia separar o mesmo nome entre provedores.
#}
{{ config(severity='warn') }}

SELECT
  provedor
  , documento_tipo
  , documento
  , nome_chave
FROM {{ ref('devedores_registros') }}
WHERE 1 = 1
  AND nome_chave ~ '[^ -~]'
