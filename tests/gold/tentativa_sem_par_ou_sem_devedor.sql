{#
  Aviso com a contagem das tentativas cujas chaves ficam `NULL` na `ft_tentativa_contato` (G2c'):
  cada linha devolvida é uma tentativa cujo alvo não é devedor da gold (`sk_devedor` `NULL`, ligada
  ao contato sem devedor) ou que não liga a nenhum contato (`sk_contato` `NULL`), com o motivo. O
  `sk_devedor` vem do CPF da tentativa, então uma tentativa sem par mas de devedor conhecido não
  entra aqui. Não é defeito: o alvo não tem o contato nas entregas dos provedores, e a régua trata
  isso como sinal. O número vai para o README.
#}
{{ config(severity='warn') }}

SELECT
  contato_id
  , CASE
    WHEN sk_contato IS NULL THEN 'sem_ligacao'
    ELSE 'contato_sem_devedor'
  END AS motivo
FROM {{ ref('ft_tentativa_contato') }}
WHERE 1 = 1
  AND (sk_devedor IS NULL OR sk_contato IS NULL)
