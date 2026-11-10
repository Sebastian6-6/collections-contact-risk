{#
  Grão: um período contínuo do mesmo conteúdo de vínculo, por documento e provedor (ponto 3). As
  versões da histórica de cada documento são ordenadas da mais antiga para a mais nova (data de
  atualização como veio, depois entrega, arquivo e linha, o inverso da escolha da versão atual da
  silver). Versões seguidas com o mesmo conteúdo (CNPJ, cargo, renda e mês de início) formam um
  período; um vínculo que volta depois de outro abre um período novo. Os períodos saem pelas ilhas
  da diferença entre dois `ROW_NUMBER()`, sem `LAG`, e não há data de fim (isso pediria `LEAD`).
  Conteúdo todo vazio não vira linha, mas separa os períodos de cada lado.
  `situacao_vinculo` (G3b, mutáveis): `atual` quando o período contém a versão vigente do devedor
  (`devedores_versao_vigente`); `anterior` nos demais. `dt_atualizacao` é a maior data de
  atualização do período, como veio; `dt_primeira_entrega` e `dt_ultima_entrega` são a menor
  primeira e a maior última entrega das versões do período. A rastreabilidade é da última versão
  do período. Documento sem devedor (RG sem ligação) mantém as linhas com `sk_devedor` `NULL`;
  versão sem documento não tem série e não entra.
#}
WITH tOrdenadas AS (
  SELECT
    provedor
    , documento_tipo
    , documento
    , hash_conteudo
    , cnpj
    , cargo
    , vl_renda
    , dt_inicio_vinculo
    , dt_atualizacao
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY provedor, documento_tipo, documento
      ORDER BY
        dt_atualizacao ASC NULLS FIRST
        , data_ultima_entrega ASC NULLS FIRST
        , _arquivo COLLATE "C" ASC
        , _linha ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
    , ROW_NUMBER() OVER (
      PARTITION BY provedor, documento_tipo, documento, cnpj, cargo, vl_renda, dt_inicio_vinculo
      ORDER BY
        dt_atualizacao ASC NULLS FIRST
        , data_ultima_entrega ASC NULLS FIRST
        , _arquivo COLLATE "C" ASC
        , _linha ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao_no_conteudo
  FROM {{ ref('devedores_vinculos_versoes') }}
)

, tIlhas AS (
  SELECT
    tOrdenadas.provedor
    , tOrdenadas.documento_tipo
    , tOrdenadas.documento
    , tOrdenadas.cnpj
    , tOrdenadas.cargo
    , tOrdenadas.vl_renda
    , tOrdenadas.dt_inicio_vinculo
    , tOrdenadas.dt_atualizacao
    , tOrdenadas.data_primeira_entrega
    , tOrdenadas.data_ultima_entrega
    , tOrdenadas.num_versao
    , tOrdenadas._arquivo
    , tOrdenadas._linha
    , tOrdenadas._hash_arquivo
    , tOrdenadas.num_versao - tOrdenadas.num_versao_no_conteudo AS ilha
    , CASE WHEN devedores_versao_vigente.hash_conteudo IS NOT NULL THEN 1 ELSE 0 END
      AS versao_vigente
  FROM tOrdenadas
  LEFT JOIN {{ ref('devedores_versao_vigente') }} AS devedores_versao_vigente
    ON tOrdenadas.provedor = devedores_versao_vigente.provedor
      AND tOrdenadas.hash_conteudo = devedores_versao_vigente.hash_conteudo
)

, tPeriodos AS (
  SELECT
    provedor
    , documento_tipo
    , documento
    , cnpj
    , cargo
    , vl_renda
    , dt_inicio_vinculo
    , ilha
    , MAX(dt_atualizacao) AS dt_atualizacao
    , MIN(data_primeira_entrega) AS dt_primeira_entrega
    , MAX(data_ultima_entrega) AS dt_ultima_entrega
    , MAX(num_versao) AS num_ultima_versao
    , MAX(versao_vigente) AS versao_vigente
  FROM tIlhas
  WHERE 1 = 1
    AND (
      cnpj IS NOT NULL
      OR cargo IS NOT NULL
      OR vl_renda IS NOT NULL
      OR dt_inicio_vinculo IS NOT NULL
    )
  GROUP BY
    provedor
    , documento_tipo
    , documento
    , cnpj
    , cargo
    , vl_renda
    , dt_inicio_vinculo
    , ilha
)

, tPeriodosSituados AS (
  SELECT
    provedor
    , documento_tipo
    , documento
    , cnpj
    , cargo
    , vl_renda
    , dt_inicio_vinculo
    , dt_atualizacao
    , dt_primeira_entrega
    , dt_ultima_entrega
    , num_ultima_versao
    , CASE WHEN versao_vigente = 1 THEN 'atual' ELSE 'anterior' END AS situacao_vinculo
  FROM tPeriodos
)

SELECT
  dim_devedor.sk_devedor
  , dim_empregador.sk_empregador
  , tPeriodosSituados.provedor
  , tPeriodosSituados.situacao_vinculo
  , tPeriodosSituados.cargo
  , tPeriodosSituados.vl_renda
  , tPeriodosSituados.dt_inicio_vinculo
  , tPeriodosSituados.dt_atualizacao
  , tPeriodosSituados.dt_primeira_entrega
  , tPeriodosSituados.dt_ultima_entrega
  , tIlhas._arquivo
  , tIlhas._linha
  , tIlhas._hash_arquivo
FROM tPeriodosSituados
INNER JOIN tIlhas
  ON tPeriodosSituados.provedor = tIlhas.provedor
    AND tPeriodosSituados.documento_tipo = tIlhas.documento_tipo
    AND tPeriodosSituados.documento = tIlhas.documento
    AND tPeriodosSituados.num_ultima_versao = tIlhas.num_versao
LEFT JOIN {{ ref('devedores_documentos') }} AS devedores_documentos
  ON tPeriodosSituados.documento_tipo = devedores_documentos.documento_tipo
    AND tPeriodosSituados.documento = devedores_documentos.documento
LEFT JOIN {{ ref('dim_devedor') }} AS dim_devedor
  ON devedores_documentos.cpf = dim_devedor.cpf
LEFT JOIN {{ ref('dim_empregador') }} AS dim_empregador
  ON tPeriodosSituados.cnpj = dim_empregador.cnpj
