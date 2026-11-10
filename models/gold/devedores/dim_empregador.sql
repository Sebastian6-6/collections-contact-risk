{#
  Grão: um CNPJ recebido de empregador (`empregadores_cnpjs`, que junta as três fontes), com os
  atributos da Receita por LEFT JOIN pelo CNPJ de 14 caracteres (C5 do enriquecimento): o
  estabelecimento traz situação, CNAE, UF, município e início da atividade; a empresa (pela base
  do CNPJ), a razão social, a natureza e o porte; o Simples, a opção pelo Simples e pelo MEI.
  Cada tabela da Receita é única na chave do join, então a junção não multiplica linhas. CNPJ sem
  estabelecimento na Receita fica `nao_encontrado` e com os atributos NULL, sem linha fictícia.
  As descrições de situação cadastral e de porte são o domínio do layout oficial, que não vem em
  tabela de domínio nos arquivos.
#}
WITH tEmpregadores AS (
  SELECT
    CAST(
      ROW_NUMBER() OVER (ORDER BY cnpj ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
      AS INTEGER
    ) AS sk_empregador
    , cnpj
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM {{ ref('empregadores_cnpjs') }}
)

, tReceita AS (
  SELECT
    tEmpregadores.sk_empregador
    , tEmpregadores.cnpj
    , empresas.natureza_juridica AS cod_natureza_juridica
    , naturezas.descricao AS desc_natureza_juridica
    , empresas.porte_da_empresa AS cod_porte
    , estabelecimentos.situacao_cadastral AS cod_situacao_cadastral
    , estabelecimentos.motivo_situacao_cadastral AS cod_motivo_situacao_cadastral
    , motivos.descricao AS desc_motivo_situacao_cadastral
    , estabelecimentos.cnae_fiscal_principal AS cod_cnae
    , cnaes.descricao AS desc_cnae
    , estabelecimentos.uf AS sigla_uf
    , estabelecimentos.municipio AS cod_municipio
    , municipios.descricao AS desc_municipio
    , empresas.razao_social_nome_empresarial AS nome_razao_social
    , estabelecimentos.data_situacao_cadastral AS dt_situacao_cadastral
    , estabelecimentos.data_de_inicio_atividade AS dt_inicio_atividade
    , tEmpregadores._arquivo
    , tEmpregadores._linha
    , tEmpregadores._hash_arquivo
    , CASE
      WHEN estabelecimentos.cnpj IS NOT NULL THEN 'encontrado'
      ELSE 'nao_encontrado'
    END AS situacao_receita
    , CASE empresas.porte_da_empresa
      WHEN '00' THEN 'NAO INFORMADO'
      WHEN '01' THEN 'MICRO EMPRESA'
      WHEN '03' THEN 'EMPRESA DE PEQUENO PORTE'
      WHEN '05' THEN 'DEMAIS'
    END AS desc_porte
    , CASE estabelecimentos.situacao_cadastral
      WHEN '01' THEN 'NULA'
      WHEN '02' THEN 'ATIVA'
      WHEN '03' THEN 'SUSPENSA'
      WHEN '04' THEN 'INAPTA'
      WHEN '08' THEN 'BAIXADA'
    END AS desc_situacao_cadastral
    , CASE simples.opcao_pelo_simples
      WHEN 'S' THEN TRUE
      WHEN 'N' THEN FALSE
    END AS flag_optante_simples
    , CASE simples.opcao_pelo_mei
      WHEN 'S' THEN TRUE
      WHEN 'N' THEN FALSE
    END AS flag_optante_mei
  FROM tEmpregadores
  LEFT JOIN {{ ref('silver_receita_estabelecimentos') }} AS estabelecimentos
    ON tEmpregadores.cnpj = estabelecimentos.cnpj
  LEFT JOIN {{ ref('silver_receita_empresas') }} AS empresas
    ON estabelecimentos.cnpj_basico = empresas.cnpj_basico
  LEFT JOIN {{ ref('silver_receita_simples') }} AS simples
    ON estabelecimentos.cnpj_basico = simples.cnpj_basico
  LEFT JOIN {{ ref('silver_receita_naturezas') }} AS naturezas
    ON empresas.natureza_juridica = naturezas.codigo
  LEFT JOIN {{ ref('silver_receita_motivos') }} AS motivos
    ON estabelecimentos.motivo_situacao_cadastral = motivos.codigo
  LEFT JOIN {{ ref('silver_receita_cnaes') }} AS cnaes
    ON estabelecimentos.cnae_fiscal_principal = cnaes.codigo
  LEFT JOIN {{ ref('silver_receita_municipios') }} AS municipios
    ON estabelecimentos.municipio = municipios.codigo
)

SELECT
  sk_empregador
  , cnpj
  , situacao_receita

  , cod_natureza_juridica
  , desc_natureza_juridica
  , cod_porte
  , desc_porte
  , cod_situacao_cadastral
  , desc_situacao_cadastral
  , cod_motivo_situacao_cadastral
  , desc_motivo_situacao_cadastral
  , cod_cnae
  , desc_cnae
  , sigla_uf
  , cod_municipio
  , desc_municipio

  , nome_razao_social

  , flag_optante_simples
  , flag_optante_mei

  , dt_situacao_cadastral
  , dt_inicio_atividade

  , _arquivo
  , _linha
  , _hash_arquivo
FROM tReceita
