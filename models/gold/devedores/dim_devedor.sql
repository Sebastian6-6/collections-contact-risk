{#
  Grão: uma pessoa identificada por um CPF (G3a'). Os documentos ruidosos (CPF inválido a um
  dígito de um CPF válido com mesmo nome e nascimento, ou RG com mesmo nome e nascimento) se
  ligam ao devedor em `devedores_documentos`; os que não se ligam e são CPF viram linha própria
  com `situacao_cpf` `invalido`. RG sem ligação e documento vazio não são devedores.
  Escolha dos atributos (G3b), com um voto por provedor, a versão atual mais recente do provedor
  entre os documentos do devedor:
    - nome: abreviação não é conflito (mesmo primeiro nome, último nome e iniciais, com a forma
      mais curta abreviada: vale a forma por extenso); depois, a forma com mais votos; empate, a
      mais recente; entre grafias que só diferem no acento, a acentuada;
    - nascimento: sentinelas e datas posteriores à entrega não votam; maioria; empate dá NULL;
    - perfil: só a gama manda; `NULL` para quem a gama não manda.
  `tipo_conflito_cadastral` (G3c, ponto 4): `identidade` quando o primeiro ou o último nome
  difere entre os provedores; `versao` quando algum documento do devedor tem duas versões
  diferentes no topo, com a mesma data de atualização, a mesma entrega e o mesmo arquivo (a
  `devedores` da silver escolhe por `_linha DESC`, uma convenção arbitrária).
  Sem rastreabilidade (ponto 8): a linha junta até três provedores.
  A chave substituta é a posição do CPF em ordem: determinística porque o banco é recriado a
  cada execução, e não carrega o CPF (G6).
#}
WITH tDevedores AS (
  SELECT
    cpf
    , CASE situacao_documento WHEN 'cpf_valido' THEN 'valido' ELSE 'invalido' END AS situacao_cpf
  FROM {{ ref('devedores_documentos') }}
  WHERE 1 = 1
    AND situacao_documento IN ('cpf_valido', 'cpf_invalido')
)

, tDocumentosDoDevedor AS (
  SELECT
    cpf
    , COUNT(
      CASE WHEN situacao_documento IN ('cpf_corrigido', 'rg_por_nome_nascimento') THEN 1 END
    ) AS qt_documentos_vinculados
  FROM {{ ref('devedores_documentos') }}
  WHERE 1 = 1
    AND cpf IS NOT NULL
  GROUP BY cpf
)

, tRegistros AS (
  SELECT
    devedores_documentos.cpf
    , devedores_registros.provedor
    , devedores_registros.documento_tipo
    , devedores_registros.documento
    , devedores_registros.nome_devedor
    , devedores_registros.nome_chave
    , devedores_registros.dt_nascimento
    , devedores_registros.nascimento_confiavel
    , devedores_registros.dt_atualizacao
    , devedores_registros.dt_entrega
    , devedores_registros.estado_civil
    , devedores_registros.escolaridade
    , devedores_registros.fonte_score
    , devedores_registros.qt_dependentes
    , devedores_registros.score_externo
    , devedores_registros.flag_possui_imovel
  FROM {{ ref('devedores_registros') }} AS devedores_registros
  INNER JOIN {{ ref('devedores_documentos') }} AS devedores_documentos
    ON devedores_registros.documento_tipo = devedores_documentos.documento_tipo
      AND devedores_registros.documento = devedores_documentos.documento
  WHERE 1 = 1
    AND devedores_documentos.cpf IS NOT NULL
)

, tProvedoresDoDevedor AS (
  SELECT
    cpf
    , COUNT(DISTINCT provedor) AS qt_provedores
  FROM tRegistros
  GROUP BY cpf
)

, tRegistrosOrdenados AS (
  SELECT
    cpf
    , provedor
    , nome_devedor
    , nome_chave
    , dt_nascimento
    , nascimento_confiavel
    , dt_atualizacao
    , dt_entrega
    , estado_civil
    , escolaridade
    , fonte_score
    , qt_dependentes
    , score_externo
    , flag_possui_imovel
    , ROW_NUMBER() OVER (
      PARTITION BY cpf, provedor
      ORDER BY
        dt_atualizacao DESC NULLS LAST
        , dt_entrega DESC NULLS LAST
        , CASE WHEN documento = cpf THEN 0 ELSE 1 END
        , documento_tipo ASC
        , documento ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM tRegistros
)

, tVotos AS (
  SELECT
    cpf
    , provedor
    , nome_devedor
    , nome_chave
    , dt_nascimento
    , nascimento_confiavel
    , dt_atualizacao
    , dt_entrega
    , estado_civil
    , escolaridade
    , fonte_score
    , qt_dependentes
    , score_externo
    , flag_possui_imovel
  FROM tRegistrosOrdenados
  WHERE 1 = 1
    AND num_versao = 1
)

, tPerfilGama AS (
  SELECT
    cpf
    , estado_civil
    , escolaridade
    , fonte_score
    , qt_dependentes
    , score_externo
    , flag_possui_imovel
  FROM tVotos
  WHERE 1 = 1
    AND provedor = 'gama'
)


, tVotosNome AS (
  SELECT
    cpf
    , provedor
    , nome_devedor
    , nome_chave
    , dt_atualizacao
    , dt_entrega
    , SPLIT_PART(nome_chave, ' ', 1) AS primeiro_nome
    , REGEXP_REPLACE(nome_chave, '^.* ', '') AS ultimo_nome
    , REPLACE(REGEXP_REPLACE(nome_chave, '([^ ])[^ ]*', '\1', 'g'), ' ', '') AS iniciais
    , nome_chave ~ '(^| )[A-Z][.]?( |$)' AS nome_abreviado
  FROM tVotos
  WHERE 1 = 1
    AND nome_chave IS NOT NULL
)

, tFormasCompletas AS (
  SELECT
    abreviado.cpf
    , abreviado.provedor
    , completo.nome_chave AS nome_chave_completo
    , ROW_NUMBER() OVER (
      PARTITION BY abreviado.cpf, abreviado.provedor
      ORDER BY LENGTH(completo.nome_chave) DESC, completo.nome_chave
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_forma
  FROM tVotosNome AS abreviado
  INNER JOIN tVotosNome AS completo
    ON abreviado.cpf = completo.cpf
      AND abreviado.primeiro_nome = completo.primeiro_nome
      AND abreviado.ultimo_nome = completo.ultimo_nome
      AND abreviado.iniciais = completo.iniciais
      AND (
        abreviado.nome_chave = completo.nome_chave
        OR (
          abreviado.nome_abreviado
          AND LENGTH(completo.nome_chave) > LENGTH(abreviado.nome_chave)
        )
      )
)

, tGruposDeNome AS (
  SELECT
    tVotosNome.cpf
    , tFormasCompletas.nome_chave_completo
    , COUNT(*) AS qt_votos
    , MAX(tVotosNome.dt_atualizacao) AS dt_atualizacao
    , MAX(tVotosNome.dt_entrega) AS dt_entrega
  FROM tVotosNome
  INNER JOIN tFormasCompletas
    ON tVotosNome.cpf = tFormasCompletas.cpf
      AND tVotosNome.provedor = tFormasCompletas.provedor
  WHERE 1 = 1
    AND tFormasCompletas.num_forma = 1
  GROUP BY tVotosNome.cpf, tFormasCompletas.nome_chave_completo
)

, tGruposOrdenados AS (
  SELECT
    cpf
    , nome_chave_completo
    , ROW_NUMBER() OVER (
      PARTITION BY cpf
      ORDER BY
        qt_votos DESC
        , dt_atualizacao DESC NULLS LAST
        , dt_entrega DESC NULLS LAST
        , nome_chave_completo ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_grupo
  FROM tGruposDeNome
)

, tNomesDoGrupo AS (
  SELECT
    tVotosNome.cpf
    , tVotosNome.nome_devedor
    , ROW_NUMBER() OVER (
      PARTITION BY tVotosNome.cpf
      ORDER BY
        CASE WHEN tVotosNome.nome_devedor <> tVotosNome.nome_chave THEN 0 ELSE 1 END
        , tVotosNome.dt_atualizacao DESC NULLS LAST
        , tVotosNome.dt_entrega DESC NULLS LAST
        , tVotosNome.provedor ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_nome
  FROM tVotosNome
  INNER JOIN tGruposOrdenados
    ON tVotosNome.cpf = tGruposOrdenados.cpf
      AND tVotosNome.nome_chave = tGruposOrdenados.nome_chave_completo
  WHERE 1 = 1
    AND tGruposOrdenados.num_grupo = 1
)

, tNomeEscolhido AS (
  SELECT
    cpf
    , nome_devedor
  FROM tNomesDoGrupo
  WHERE 1 = 1
    AND num_nome = 1
)

, tConflitoDeIdentidade AS (
  SELECT cpf
  FROM tVotosNome
  GROUP BY cpf
  HAVING COUNT(DISTINCT primeiro_nome) > 1 OR COUNT(DISTINCT ultimo_nome) > 1
)

, tVotosNascimento AS (
  SELECT
    cpf
    , dt_nascimento
    , COUNT(*) AS qt_votos
  FROM tVotos
  WHERE 1 = 1
    AND nascimento_confiavel
  GROUP BY cpf, dt_nascimento
)

, tNascimentosOrdenados AS (
  SELECT
    cpf
    , dt_nascimento
    , ROW_NUMBER() OVER (
      PARTITION BY cpf
      ORDER BY qt_votos DESC, dt_nascimento ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_nascimento
    , SUM(1) OVER (
      PARTITION BY cpf, qt_votos
      ORDER BY dt_nascimento
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS qt_empatados
  FROM tVotosNascimento
)

, tNascimentoEscolhido AS (
  SELECT
    cpf
    , dt_nascimento
  FROM tNascimentosOrdenados
  WHERE 1 = 1
    AND num_nascimento = 1
    AND qt_empatados = 1
)

, tConflitoDeVersao AS (
  SELECT DISTINCT devedores_documentos.cpf
  FROM {{ ref('devedores_conflitos_versao') }} AS devedores_conflitos_versao
  INNER JOIN {{ ref('devedores_documentos') }} AS devedores_documentos
    ON devedores_conflitos_versao.documento_tipo = devedores_documentos.documento_tipo
      AND devedores_conflitos_versao.documento = devedores_documentos.documento
  WHERE 1 = 1
    AND devedores_documentos.cpf IS NOT NULL
)

, tMontada AS (
  SELECT
    tDevedores.cpf
    , tDevedores.situacao_cpf
    , tPerfilGama.estado_civil
    , tPerfilGama.escolaridade
    , tPerfilGama.fonte_score
    , tNomeEscolhido.nome_devedor
    , tPerfilGama.qt_dependentes
    , tPerfilGama.score_externo
    , tProvedoresDoDevedor.qt_provedores
    , tDocumentosDoDevedor.qt_documentos_vinculados
    , tPerfilGama.flag_possui_imovel
    , tNascimentoEscolhido.dt_nascimento
    , CASE
      WHEN tConflitoDeIdentidade.cpf IS NOT NULL AND tConflitoDeVersao.cpf IS NOT NULL
        THEN 'identidade_e_versao'
      WHEN tConflitoDeIdentidade.cpf IS NOT NULL THEN 'identidade'
      WHEN tConflitoDeVersao.cpf IS NOT NULL THEN 'versao'
      ELSE 'nenhum'
    END AS tipo_conflito_cadastral
  FROM tDevedores
  LEFT JOIN tDocumentosDoDevedor ON tDevedores.cpf = tDocumentosDoDevedor.cpf
  LEFT JOIN tProvedoresDoDevedor ON tDevedores.cpf = tProvedoresDoDevedor.cpf
  LEFT JOIN tPerfilGama ON tDevedores.cpf = tPerfilGama.cpf
  LEFT JOIN tNomeEscolhido ON tDevedores.cpf = tNomeEscolhido.cpf
  LEFT JOIN tNascimentoEscolhido ON tDevedores.cpf = tNascimentoEscolhido.cpf
  LEFT JOIN tConflitoDeIdentidade ON tDevedores.cpf = tConflitoDeIdentidade.cpf
  LEFT JOIN tConflitoDeVersao ON tDevedores.cpf = tConflitoDeVersao.cpf
)

SELECT
  CAST(
    ROW_NUMBER() OVER (ORDER BY cpf ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS INTEGER
  ) AS sk_devedor
  , cpf
  , situacao_cpf
  , tipo_conflito_cadastral
  , estado_civil
  , escolaridade
  , fonte_score
  , nome_devedor
  , qt_dependentes
  , score_externo
  , qt_provedores
  , qt_documentos_vinculados
  , flag_possui_imovel
  , dt_nascimento
FROM tMontada
