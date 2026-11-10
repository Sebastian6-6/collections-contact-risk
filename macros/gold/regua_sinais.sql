{#
  Sinais da régua de risco por par devedor × contato (G4b e G4c). Devolve as CTEs, sem o `WITH`,
  até `tSinaisDoPar`, que `regua_de_risco` lê. Uso: `WITH {{ regua_sinais_do_par(data_corte) }}`.
  Lê `devedores_contatos_pares` (os pares e as entregas) e `cobranca_tentativas` (as tentativas
  ligadas ao par); nenhum dos dois traz horário de execução.

  Sem corte (`none`) é a régua de operação. Com 'AAAA-MM-DD' é a validação (G4c): os pares e os
  sinais do devedor e do par (`tipo_conflito_cadastral`, `situacao_documento`, `sk_devedor`,
  `qt_provedores`) saem só das entregas até a data, pela macro `regua_pares_no_corte`, e só contam
  as tentativas até a data. `situacao_entrega` só existe na operação (ponto 7): com corte sai
  `NULL`, porque a silver guarda só a primeira e a última entrega de cada par.

  Sinais:
    - `situacao_compartilhamento`: `compartilhado` quando o contato tem mais de um CPF; `migrado`
      quando, além disso, um CPF passa a ter o contato só depois da última entrega de outro (o
      contato passou de um CPF para outro); `exclusivo` nos demais. É do contato: vale para todos
      os pares dele. `dt_situacao_compartilhamento` é a data em que passou a `migrado` (primeira
      entrega do CPF que o recebeu) ou a `compartilhado` (primeira entrega do segundo CPF);
    - `tipo_alerta_historico`, por prioridade falecido > opt_out > nao_e_o_devedor:
      `falecido` se qualquer tentativa do devedor teve esse resultado (vale para todos os pares
      dele); `opt_out` se qualquer tentativa ao contato teve esse resultado (vale para todos os
      CPFs do contato, porque quem pediu foi o titular do número); `nao_e_o_devedor` se uma
      tentativa ao par teve `numero_errado` ou `nao_conhece_devedor`. `dt_alerta_historico` é a
      primeira tentativa do alerta escolhido.
  Contagens: `qt_devedores_mesmo_contato` (CPFs distintos do contato), `qt_tentativas` e
  `qt_tentativas_terceiro` (tentativas ligadas ao par e as de classe `terceiro`).
#}
{% macro regua_sinais_do_par(data_corte=none) -%}
  {{ regua_valida_corte(data_corte) }}
  {%- if data_corte is none %}
  tParesVisiveis AS (
    SELECT
      sk_contato
      , sk_devedor
      , cpf
      , tipo_contato
      , contato
      , tipo_conflito_cadastral
      , situacao_documento
      , documento_original
      , situacao_entrega
      , qt_provedores
      , dt_primeira_entrega
      , dt_ultima_entrega
      , _arquivo
      , _linha
      , _hash_arquivo
    FROM {{ ref('devedores_contatos_pares') }}
  )
  {%- else %}
  {{ regua_pares_no_corte(data_corte) }}
  {%- endif %}

  , tTentativasVisiveis AS (
    SELECT
      contato_id
      , tipo_contato
      , contato
      , resultado
      , tipo_desfecho
      , dt_tentativa
      , cpf
      , sk_contato
    FROM {{ ref('cobranca_tentativas') }}
    WHERE 1 = 1
      {{ regua_filtro_corte('dt_tentativa', data_corte) }}
  )

  , tDevedoresDoContato AS (
    SELECT
      tipo_contato
      , contato
      , COUNT(DISTINCT cpf) AS qt_devedores_mesmo_contato
    FROM tParesVisiveis
    WHERE 1 = 1
      AND cpf IS NOT NULL
    GROUP BY tipo_contato, contato
  )

  , tMigracoes AS (
    SELECT
      anterior.tipo_contato
      , anterior.contato
      , MIN(posterior.dt_primeira_entrega) AS dt_migracao
    FROM tParesVisiveis AS anterior
    INNER JOIN tParesVisiveis AS posterior
      ON anterior.tipo_contato = posterior.tipo_contato
        AND anterior.contato = posterior.contato
        AND anterior.cpf <> posterior.cpf
        AND posterior.dt_primeira_entrega > anterior.dt_ultima_entrega
    GROUP BY anterior.tipo_contato, anterior.contato
  )

  , tEntradasNoContato AS (
    SELECT
      tipo_contato
      , contato
      , dt_primeira_entrega
      , ROW_NUMBER() OVER (
        PARTITION BY tipo_contato, contato
        ORDER BY dt_primeira_entrega ASC, cpf ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS num_entrada
    FROM tParesVisiveis
    WHERE 1 = 1
      AND cpf IS NOT NULL
  )

  , tSegundasEntradas AS (
    SELECT
      tipo_contato
      , contato
      , dt_primeira_entrega AS dt_segunda_entrada
    FROM tEntradasNoContato
    WHERE 1 = 1
      AND num_entrada = 2
  )

  , tFalecidos AS (
    SELECT
      cpf
      , MIN(dt_tentativa) AS dt_alerta
    FROM tTentativasVisiveis
    WHERE 1 = 1
      AND cpf IS NOT NULL
      AND tipo_desfecho = 'falecido'
    GROUP BY cpf
  )

  , tOptOuts AS (
    SELECT
      tipo_contato
      , contato
      , MIN(dt_tentativa) AS dt_alerta
    FROM tTentativasVisiveis
    WHERE 1 = 1
      AND tipo_desfecho = 'opt_out'
    GROUP BY tipo_contato, contato
  )

  , tNaoEoDevedor AS (
    SELECT
      sk_contato
      , MIN(dt_tentativa) AS dt_alerta
    FROM tTentativasVisiveis
    WHERE 1 = 1
      AND sk_contato IS NOT NULL
      AND tipo_desfecho = 'terceiro'
    GROUP BY sk_contato
  )

  , tContagens AS (
    SELECT
      tParesVisiveis.sk_contato
      , COUNT(tTentativasVisiveis.contato_id) AS qt_tentativas
      , COUNT(
        CASE WHEN tTentativasVisiveis.tipo_desfecho = 'terceiro' THEN 1 END
      ) AS qt_tentativas_terceiro
    FROM tParesVisiveis
    LEFT JOIN tTentativasVisiveis
      ON tParesVisiveis.sk_contato = tTentativasVisiveis.sk_contato
    GROUP BY tParesVisiveis.sk_contato
  )

  , tSinaisDoPar AS (
    SELECT
      tParesVisiveis.sk_contato
      , tParesVisiveis.sk_devedor
      , tParesVisiveis.cpf
      , tParesVisiveis.tipo_contato
      , tParesVisiveis.contato
      , tParesVisiveis.tipo_conflito_cadastral
      , tParesVisiveis.situacao_documento
      , tParesVisiveis.documento_original
      , CASE
        WHEN tMigracoes.dt_migracao IS NOT NULL THEN 'migrado'
        WHEN tDevedoresDoContato.qt_devedores_mesmo_contato > 1 THEN 'compartilhado'
        ELSE 'exclusivo'
      END AS situacao_compartilhamento
      , CASE
        WHEN tMigracoes.dt_migracao IS NOT NULL THEN tMigracoes.dt_migracao
        WHEN tDevedoresDoContato.qt_devedores_mesmo_contato > 1
          THEN tSegundasEntradas.dt_segunda_entrada
      END AS dt_situacao_compartilhamento
      , CASE
        WHEN tFalecidos.cpf IS NOT NULL THEN 'falecido'
        WHEN tOptOuts.contato IS NOT NULL THEN 'opt_out'
        WHEN tNaoEoDevedor.sk_contato IS NOT NULL THEN 'nao_e_o_devedor'
        ELSE 'nenhum'
      END AS tipo_alerta_historico
      , CASE
        WHEN tFalecidos.cpf IS NOT NULL THEN tFalecidos.dt_alerta
        WHEN tOptOuts.contato IS NOT NULL THEN tOptOuts.dt_alerta
        WHEN tNaoEoDevedor.sk_contato IS NOT NULL THEN tNaoEoDevedor.dt_alerta
      END AS dt_alerta_historico
      , tParesVisiveis.situacao_entrega
      , tParesVisiveis.qt_provedores
      , CASE
        WHEN tDevedoresDoContato.qt_devedores_mesmo_contato IS NULL THEN 0
        ELSE tDevedoresDoContato.qt_devedores_mesmo_contato
      END AS qt_devedores_mesmo_contato
      , tContagens.qt_tentativas
      , tContagens.qt_tentativas_terceiro
      , tParesVisiveis.dt_primeira_entrega
      , tParesVisiveis.dt_ultima_entrega
      , tParesVisiveis._arquivo
      , tParesVisiveis._linha
      , tParesVisiveis._hash_arquivo
    FROM tParesVisiveis
    LEFT JOIN tDevedoresDoContato
      ON tParesVisiveis.tipo_contato = tDevedoresDoContato.tipo_contato
        AND tParesVisiveis.contato = tDevedoresDoContato.contato
    LEFT JOIN tMigracoes
      ON tParesVisiveis.tipo_contato = tMigracoes.tipo_contato
        AND tParesVisiveis.contato = tMigracoes.contato
    LEFT JOIN tSegundasEntradas
      ON tParesVisiveis.tipo_contato = tSegundasEntradas.tipo_contato
        AND tParesVisiveis.contato = tSegundasEntradas.contato
    LEFT JOIN tFalecidos
      ON tParesVisiveis.cpf = tFalecidos.cpf
    LEFT JOIN tOptOuts
      ON tParesVisiveis.tipo_contato = tOptOuts.tipo_contato
        AND tParesVisiveis.contato = tOptOuts.contato
    LEFT JOIN tNaoEoDevedor
      ON tParesVisiveis.sk_contato = tNaoEoDevedor.sk_contato
    INNER JOIN tContagens
      ON tParesVisiveis.sk_contato = tContagens.sk_contato
  )
{%- endmacro %}
