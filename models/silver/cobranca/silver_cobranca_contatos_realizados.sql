{#
  Grão: uma linha por `contato_id`. Se a origem repetir o identificador (hoje não repete), vale a
  linha mais recente do arquivo: maior `_arquivo`, depois maior `_linha`. A padronização acontece
  antes, em `silver_cobranca_contatos_realizados_padronizados` (S2). Os provedores de origem são
  uma lista: estão em `contatos_realizados_provedores`.
#}
WITH tVersoes AS (
  SELECT
    contato_id
    , cpf_alvo
    , canal
    , destino_original
    , destino
    , data_hora
    , resultado
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY contato_id
      ORDER BY _arquivo DESC, _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_versao
  FROM {{ ref('silver_cobranca_contatos_realizados_padronizados') }}
)

SELECT
  contato_id
  , cpf_alvo
  , canal
  , destino_original
  , destino
  , data_hora
  , resultado
  , _arquivo
  , _linha
  , _hash_arquivo
FROM tVersoes
WHERE 1 = 1
  AND num_versao = 1
