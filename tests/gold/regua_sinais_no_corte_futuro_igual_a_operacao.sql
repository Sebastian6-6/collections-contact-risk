{#
  Falha para cada par em que os sinais calculados com um corte depois da última entrega
  (`regua_sinais_do_par('2099-12-31')`) diferem dos da régua de operação
  (`devedores_contatos_pares`): par que falta ou sobra, `sk_devedor`, `tipo_conflito_cadastral`,
  `situacao_documento`, `documento_original`, `qt_provedores` e as datas de entrega. Sem entrega depois do corte, o
  recálculo de `regua_pares_no_corte` tem de reproduzir a operação, então qualquer diferença é erro
  do recálculo e não vazamento.
#}
WITH {{ regua_sinais_do_par('2099-12-31') }}

SELECT COALESCE(tSinaisDoPar.sk_contato, pares.sk_contato) AS sk_contato
FROM tSinaisDoPar
FULL OUTER JOIN {{ ref('devedores_contatos_pares') }} AS pares
  ON tSinaisDoPar.sk_contato = pares.sk_contato
WHERE 1 = 1
  AND (
    tSinaisDoPar.sk_contato IS NULL
    OR pares.sk_contato IS NULL
    OR tSinaisDoPar.sk_devedor IS DISTINCT FROM pares.sk_devedor
    OR tSinaisDoPar.tipo_conflito_cadastral IS DISTINCT FROM pares.tipo_conflito_cadastral
    OR tSinaisDoPar.situacao_documento IS DISTINCT FROM pares.situacao_documento
    OR tSinaisDoPar.documento_original IS DISTINCT FROM pares.documento_original
    OR tSinaisDoPar.qt_provedores IS DISTINCT FROM pares.qt_provedores
    OR tSinaisDoPar.dt_primeira_entrega IS DISTINCT FROM pares.dt_primeira_entrega
    OR tSinaisDoPar.dt_ultima_entrega IS DISTINCT FROM pares.dt_ultima_entrega
  )
