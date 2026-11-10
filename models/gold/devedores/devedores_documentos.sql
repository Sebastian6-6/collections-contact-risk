{#
  Liga cada documento recebido ao devedor (G3a'). Grão: um documento distinto (`documento_tipo`,
  `documento`), qualquer que seja o provedor. `cpf` é o CPF do devedor a que o documento
  pertence, e `situacao_documento` diz por quê:
    - `cpf_valido`: CPF com dígito verificador certo; é o próprio devedor;
    - `cpf_corrigido`: CPF inválido com o mesmo nome comparável e o mesmo nascimento de um único
      CPF válido, a um dígito de distância; liga-se a esse devedor;
    - `rg_por_nome_nascimento`: RG do beta com o mesmo nome comparável e o mesmo nascimento de um
      único CPF válido (evidência mais fraca, sem teste de dígito); liga-se a esse devedor;
    - `cpf_invalido`: CPF inválido sem ligação; é um devedor próprio;
    - `sem_documento`: RG sem ligação; não é devedor (`cpf` NULL), e os contatos dele ficam sem
      `sk_devedor`.
  Só votam nome e nascimento da versão atual de cada provedor, e nascimento só se for confiável
  (`devedores_registros`). "Único" conta os CPFs válidos que têm o mesmo nome e nascimento, em
  qualquer distância: um empate nunca se resolve. Dois CPFs válidos nunca se ligam entre si.
  É efêmero: não é tabela da gold. Existe para `dim_devedor` e para as tabelas filhas
  (contatos, endereços e vínculos) usarem a mesma ligação.
#}
{{ config(materialized='ephemeral') }}

WITH tDocumentos AS (
  SELECT DISTINCT
    documento_tipo
    , documento
    , documento_tipo = 'CPF' AND {{ cpf_valido('documento') }} AS documento_valido
  FROM {{ ref('devedores_registros') }}
)

, tPares AS (
  SELECT DISTINCT
    documento_tipo
    , documento
    , nome_chave
    , dt_nascimento
  FROM {{ ref('devedores_registros') }}
  WHERE 1 = 1
    AND nascimento_confiavel
    AND nome_chave IS NOT NULL
)

, tParesValidos AS (
  SELECT
    tPares.documento
    , tPares.nome_chave
    , tPares.dt_nascimento
  FROM tPares
  INNER JOIN tDocumentos
    ON tPares.documento_tipo = tDocumentos.documento_tipo
      AND tPares.documento = tDocumentos.documento
  WHERE 1 = 1
    AND tDocumentos.documento_valido
)

, tParesRuidosos AS (
  SELECT
    tPares.documento_tipo
    , tPares.documento
    , tPares.nome_chave
    , tPares.dt_nascimento
  FROM tPares
  INNER JOIN tDocumentos
    ON tPares.documento_tipo = tDocumentos.documento_tipo
      AND tPares.documento = tDocumentos.documento
  WHERE 1 = 1
    AND NOT tDocumentos.documento_valido
)

, tCorrespondencias AS (
  SELECT DISTINCT
    tParesRuidosos.documento_tipo
    , tParesRuidosos.documento
    , tParesValidos.documento AS cpf_correspondente
  FROM tParesRuidosos
  INNER JOIN tParesValidos
    ON tParesRuidosos.nome_chave = tParesValidos.nome_chave
      AND tParesRuidosos.dt_nascimento = tParesValidos.dt_nascimento
)

, tContados AS (
  SELECT
    documento_tipo
    , documento
    , cpf_correspondente
    , SUM(1) OVER (
      PARTITION BY documento_tipo, documento
      ORDER BY cpf_correspondente
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS qt_correspondentes
  FROM tCorrespondencias
)

, tLigacoes AS (
  SELECT
    documento_tipo
    , documento
    , cpf_correspondente
  FROM tContados
  WHERE 1 = 1
    AND qt_correspondentes = 1
    AND (
      documento_tipo = 'RG'
      OR (
        LENGTH(documento) = 11
        AND {{ posicoes_diferentes('documento', 'cpf_correspondente', 11) }} = 1
      )
    )
)

SELECT
  tDocumentos.documento_tipo
  , tDocumentos.documento
  , CASE
    WHEN tDocumentos.documento_valido THEN tDocumentos.documento
    WHEN tLigacoes.cpf_correspondente IS NOT NULL THEN tLigacoes.cpf_correspondente
    WHEN tDocumentos.documento_tipo = 'CPF' THEN tDocumentos.documento
  END AS cpf
  , CASE
    WHEN tDocumentos.documento_valido THEN 'cpf_valido'
    WHEN tLigacoes.cpf_correspondente IS NOT NULL AND tDocumentos.documento_tipo = 'CPF'
      THEN 'cpf_corrigido'
    WHEN tLigacoes.cpf_correspondente IS NOT NULL THEN 'rg_por_nome_nascimento'
    WHEN tDocumentos.documento_tipo = 'CPF' THEN 'cpf_invalido'
    ELSE 'sem_documento'
  END AS situacao_documento
FROM tDocumentos
LEFT JOIN tLigacoes
  ON tDocumentos.documento_tipo = tLigacoes.documento_tipo
    AND tDocumentos.documento = tLigacoes.documento
