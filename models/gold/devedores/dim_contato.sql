{#
  Grão: um contato normalizado (`tipo_contato`, `contato`) de um devedor, com a régua de risco
  aplicada ao par (G2, G4 e G5). O contato de documento vazio ou de RG sem ligação não tem devedor:
  fica numa linha com `sk_devedor` `NULL`, e a régua o bloqueia. O par devedor × contato descreve o
  devedor, por isso é dimensão, e não fato.
  Os sinais saem de `regua_sinais_do_par` sem data de corte (régua de operação) e o nível e o motivo
  da `regua_de_risco`, a mesma macro que a validação chama com a data D (G4c). Cada grupo de sinais
  é uma coluna categórica ou `qt_`; o nível sai delas, e os sinais do devedor ficam na `dim_devedor`.
  A lista de não-contatar é esta tabela filtrada por `nivel_risco = 'bloqueado'` (G5).
  A rastreabilidade é da aparição mais recente do par.
#}
WITH {{ regua_sinais_do_par() }}

, tRegua AS (
  {{ regua_de_risco() }}
)

SELECT
  tSinaisDoPar.sk_contato
  , tSinaisDoPar.sk_devedor
  , tSinaisDoPar.cpf
  , tSinaisDoPar.tipo_contato
  , tSinaisDoPar.contato
  , tRegua.nivel_risco
  , tRegua.desc_motivo_risco
  , tSinaisDoPar.situacao_documento
  , tSinaisDoPar.documento_original
  , tSinaisDoPar.situacao_compartilhamento
  , tSinaisDoPar.tipo_alerta_historico
  , tSinaisDoPar.situacao_entrega
  , tSinaisDoPar.qt_provedores
  , tSinaisDoPar.qt_devedores_mesmo_contato
  , tSinaisDoPar.qt_tentativas
  , tSinaisDoPar.qt_tentativas_terceiro
  , tSinaisDoPar.dt_primeira_entrega
  , tSinaisDoPar.dt_ultima_entrega
  , tSinaisDoPar.dt_situacao_compartilhamento
  , tSinaisDoPar.dt_alerta_historico
  , tSinaisDoPar._arquivo
  , tSinaisDoPar._linha
  , tSinaisDoPar._hash_arquivo
FROM tSinaisDoPar
INNER JOIN tRegua
  ON tSinaisDoPar.sk_contato = tRegua.sk_contato
