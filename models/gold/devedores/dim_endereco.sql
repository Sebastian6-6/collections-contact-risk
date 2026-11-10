{#
  Grão: um devedor × um endereço padronizado distinto (G2c). Sai de `devedores_enderecos` das três
  fontes, que guarda todas as versões, e liga cada documento ao devedor por `devedores_documentos`.
  O endereço é identificado pelo `hash_endereco` da silver (as partes padronizadas, igual nas três
  fontes). Endereço de documento vazio ou de RG sem ligação não tem devedor: fica com
  `sk_devedor` `NULL`, e os de um mesmo RG sem ligação se juntam só entre si.
  Complemento (ponto 5): dois endereços do mesmo devedor iguais em tudo menos no complemento se
  juntam quando um dos dois complementos é `NULL` e há um só complemento preenchido; fica o
  preenchido, com a menor primeira entrega e a maior última entrega. Dois complementos
  preenchidos diferentes continuam separados, e o `NULL` não é juntado a nenhum dos dois.
  `situacao_endereco` (G3b, mutáveis): `atual` quando o endereço está na versão vigente do devedor
  (`devedores_versao_vigente`; no beta, os endereços marcados `atual` nessa versão); `anterior`
  nos demais. A linha traz, de uma aparição, o texto e a rastreabilidade: prefere a do próprio
  endereço preenchido, depois a que tem `tipo_endereco` (só o beta manda), depois a mais recente.
  `qt_provedores` conta os provedores que mandaram o endereço para o devedor.
#}
{%- set partes_sem_complemento = [
  'logradouro', 'numero_endereco', 'bairro', 'cidade', 'uf', 'cep', 'endereco_sem_partes'
] %}

WITH tEnderecos AS (
  SELECT
    provedor
    , documento_tipo
    , documento
    , hash_endereco
    , tipo_endereco
    , endereco
    , logradouro
    , numero_endereco
    , complemento
    , bairro
    , cidade
    , uf
    , cep
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('devedores_enderecos_registros') }}
)

, tComDono AS (
  SELECT
    tEnderecos.provedor
    , tEnderecos.documento_tipo
    , tEnderecos.documento
    , devedores_documentos.cpf
    , tEnderecos.hash_endereco
    , tEnderecos.tipo_endereco
    , tEnderecos.endereco
    , tEnderecos.logradouro
    , tEnderecos.numero_endereco
    , tEnderecos.complemento
    , tEnderecos.bairro
    , tEnderecos.cidade
    , tEnderecos.uf
    , tEnderecos.cep
    , tEnderecos.data_primeira_entrega
    , tEnderecos.data_ultima_entrega
    , tEnderecos._arquivo
    , tEnderecos._linha
    , tEnderecos._hash_arquivo
    , CASE WHEN devedores_documentos.cpf IS NULL THEN tEnderecos.documento END
      AS documento_sem_devedor
    , CASE
      WHEN tEnderecos.logradouro IS NULL
        AND tEnderecos.numero_endereco IS NULL
        AND tEnderecos.complemento IS NULL
        AND tEnderecos.bairro IS NULL
        AND tEnderecos.cidade IS NULL
        AND tEnderecos.uf IS NULL
        AND tEnderecos.cep IS NULL THEN tEnderecos.endereco
    END AS endereco_sem_partes
  FROM tEnderecos
  LEFT JOIN {{ ref('devedores_documentos') }} AS devedores_documentos
    ON tEnderecos.documento_tipo = devedores_documentos.documento_tipo
      AND tEnderecos.documento = devedores_documentos.documento
)

, tComHash AS (
  SELECT
    provedor
    , documento_tipo
    , documento
    , cpf
    , documento_sem_devedor
    , hash_endereco
    , tipo_endereco
    , endereco
    , logradouro
    , numero_endereco
    , complemento
    , bairro
    , cidade
    , uf
    , cep
    , data_primeira_entrega
    , data_ultima_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , {{ hash_conteudo(partes_sem_complemento) }} AS hash_sem_complemento
  FROM tComDono
)

, tVariantes AS (
  SELECT DISTINCT
    cpf
    , documento_sem_devedor
    , hash_sem_complemento
    , hash_endereco
    , complemento
  FROM tComHash
)

, tVariantesContadas AS (
  SELECT
    cpf
    , documento_sem_devedor
    , hash_sem_complemento
    , hash_endereco
    , complemento
    , SUM(CASE WHEN complemento IS NOT NULL THEN 1 ELSE 0 END) OVER (
      PARTITION BY cpf, documento_sem_devedor, hash_sem_complemento
      ORDER BY hash_endereco
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS qt_preenchidos
  FROM tVariantes
)

, tAbsorcoes AS (
  SELECT
    vazio.cpf
    , vazio.documento_sem_devedor
    , vazio.hash_endereco
    , preenchido.hash_endereco AS hash_endereco_final
  FROM tVariantesContadas AS vazio
  INNER JOIN tVariantesContadas AS preenchido
    ON vazio.cpf IS NOT DISTINCT FROM preenchido.cpf
      AND vazio.documento_sem_devedor IS NOT DISTINCT FROM preenchido.documento_sem_devedor
      AND vazio.hash_sem_complemento = preenchido.hash_sem_complemento
  WHERE 1 = 1
    AND vazio.complemento IS NULL
    AND preenchido.complemento IS NOT NULL
    AND vazio.qt_preenchidos = 1
)

, tVigentes AS (
  SELECT
    provedor
    , documento
    , hash_endereco
  FROM {{ ref('devedores_enderecos_vigentes') }}
)

, tFinal AS (
  SELECT
    tComHash.provedor
    , tComHash.cpf
    , tComHash.documento_sem_devedor
    , tComHash.hash_endereco
    , tComHash.tipo_endereco
    , tComHash.endereco
    , tComHash.logradouro
    , tComHash.numero_endereco
    , tComHash.complemento
    , tComHash.bairro
    , tComHash.cidade
    , tComHash.uf
    , tComHash.cep
    , tComHash.data_primeira_entrega
    , tComHash.data_ultima_entrega
    , tComHash._arquivo
    , tComHash._linha
    , tComHash._hash_arquivo
    , COALESCE(tAbsorcoes.hash_endereco_final, tComHash.hash_endereco)
      AS hash_endereco_final
    , CASE WHEN tVigentes.hash_endereco IS NOT NULL THEN 1 ELSE 0 END AS endereco_vigente
  FROM tComHash
  LEFT JOIN tAbsorcoes
    ON tComHash.cpf IS NOT DISTINCT FROM tAbsorcoes.cpf
      AND tComHash.documento_sem_devedor IS NOT DISTINCT FROM tAbsorcoes.documento_sem_devedor
      AND tComHash.hash_endereco = tAbsorcoes.hash_endereco
  LEFT JOIN tVigentes
    ON tComHash.provedor = tVigentes.provedor
      AND tComHash.documento IS NOT DISTINCT FROM tVigentes.documento
      AND tComHash.hash_endereco = tVigentes.hash_endereco
)

, tOrdenadas AS (
  SELECT
    cpf
    , documento_sem_devedor
    , hash_endereco_final
    , tipo_endereco
    , endereco
    , logradouro
    , numero_endereco
    , complemento
    , bairro
    , cidade
    , uf
    , cep
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY cpf, documento_sem_devedor, hash_endereco_final
      ORDER BY
        CASE WHEN hash_endereco = hash_endereco_final THEN 0 ELSE 1 END ASC
        , CASE WHEN tipo_endereco IS NULL THEN 1 ELSE 0 END ASC
        , data_ultima_entrega DESC NULLS LAST
        , _arquivo COLLATE "C" DESC
        , _linha DESC
        , provedor ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tFinal
)

, tEntregas AS (
  SELECT
    cpf
    , documento_sem_devedor
    , hash_endereco_final
    , MIN(data_primeira_entrega) AS dt_primeira_entrega
    , MAX(data_ultima_entrega) AS dt_ultima_entrega
    , COUNT(DISTINCT provedor) AS qt_provedores
    , MAX(endereco_vigente) AS endereco_vigente
  FROM tFinal
  GROUP BY cpf, documento_sem_devedor, hash_endereco_final
)

, tMontada AS (
  SELECT
    dim_devedor.sk_devedor
    , tOrdenadas.tipo_endereco
    , tOrdenadas.endereco
    , tOrdenadas.logradouro
    , tOrdenadas.numero_endereco
    , tOrdenadas.complemento
    , tOrdenadas.bairro
    , tOrdenadas.cidade
    , tOrdenadas.uf
    , tOrdenadas.cep
    , tEntregas.qt_provedores
    , tEntregas.dt_primeira_entrega
    , tEntregas.dt_ultima_entrega
    , tOrdenadas._arquivo
    , tOrdenadas._linha
    , tOrdenadas._hash_arquivo
    , tOrdenadas.cpf
    , tOrdenadas.documento_sem_devedor
    , CASE WHEN tEntregas.endereco_vigente = 1 THEN 'atual' ELSE 'anterior' END
      AS situacao_endereco
  FROM tOrdenadas
  INNER JOIN tEntregas
    ON tOrdenadas.cpf IS NOT DISTINCT FROM tEntregas.cpf
      AND tOrdenadas.documento_sem_devedor IS NOT DISTINCT FROM tEntregas.documento_sem_devedor
      AND tOrdenadas.hash_endereco_final = tEntregas.hash_endereco_final
  LEFT JOIN {{ ref('dim_devedor') }} AS dim_devedor
    ON tOrdenadas.cpf = dim_devedor.cpf
  WHERE 1 = 1
    AND tOrdenadas.num_aparicao = 1
)

SELECT
  CAST(
    ROW_NUMBER() OVER (
      ORDER BY
        cpf ASC NULLS LAST
        , documento_sem_devedor ASC NULLS LAST
        , logradouro ASC NULLS LAST
        , numero_endereco ASC NULLS LAST
        , complemento ASC NULLS LAST
        , bairro ASC NULLS LAST
        , cidade ASC NULLS LAST
        , uf ASC NULLS LAST
        , cep ASC NULLS LAST
        , endereco ASC NULLS LAST
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS INTEGER
  ) AS sk_endereco
  , sk_devedor
  , tipo_endereco
  , situacao_endereco
  , endereco
  , logradouro
  , numero_endereco
  , complemento
  , bairro
  , cidade
  , uf
  , cep
  , qt_provedores
  , dt_primeira_entrega
  , dt_ultima_entrega
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tMontada
