{#
  Grão: uma linha por (documento, endereço padronizado), com a primeira e a última data de
  entrega em que o par apareceu. Sai da histórica (`silver_gama_devedores_historico`), que guarda
  todas as versões, não só a atual (S4): um endereço que saiu da versão mais recente continua
  registrado. O endereço é o conjunto das partes padronizadas (`logradouro`, `numero`,
  `endereco_json_complemento`, `bairro`, `cidade`, `uf`, `cep`; H4), resumido em `hash_endereco` (macro
  `hash_conteudo`, sem o documento, para a gold achar o mesmo endereço em documentos
  diferentes). O texto original (`endereco`) não entra na identidade, a não ser que todas as
  partes sejam NULL: então ele entra no hash. Só existe linha para endereço que veio preenchido.
  A versão sem documento (vazio ou só zeros) também entra, com `documento` NULL: esses endereços
  são deduplicados só por `hash_endereco` entre si e nunca se juntam a um par de documento válido.
  A primeira entrega é a menor das primeiras entregas das versões que têm o par; a última, a maior
  das últimas. `endereco`, `_arquivo`, `_linha` e `_hash_arquivo` são da aparição mais recente do
  par: a da versão com a maior `ordem_versao`, porque a data de entrega não identifica o arquivo.
#}
{%- set partes_do_endereco = [
  'logradouro', 'numero', 'endereco_json_complemento', 'bairro', 'cidade', 'uf', 'cep'
  , 'endereco_sem_partes'
] %}

WITH tAparicoes AS (
  SELECT
    documento
    , endereco
    , logradouro
    , numero
    , endereco_json_complemento
    , bairro
    , cidade
    , uf
    , cep
    , dt_ref
    , data_primeira_entrega
    , data_ultima_entrega
    , data_ultima_entrega AS data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , CASE
      WHEN logradouro IS NULL
        AND numero IS NULL
        AND endereco_json_complemento IS NULL
        AND bairro IS NULL
        AND cidade IS NULL
        AND uf IS NULL
        AND cep IS NULL THEN endereco
    END AS endereco_sem_partes
  FROM {{ ref('silver_gama_devedores_historico') }}
  WHERE 1 = 1
    AND COALESCE(
      endereco, logradouro, numero, endereco_json_complemento, bairro, cidade, uf, cep
    ) IS NOT NULL
)

, tComHash AS (
  SELECT
    documento
    , endereco
    , logradouro
    , numero
    , endereco_json_complemento
    , bairro
    , cidade
    , uf
    , cep
    , dt_ref
    , data_primeira_entrega
    , data_ultima_entrega
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , {{ hash_conteudo(partes_do_endereco) }} AS hash_endereco
  FROM tAparicoes
)

, tEntregas AS (
  SELECT
    documento
    , hash_endereco
    , MIN(data_primeira_entrega) AS data_primeira_entrega
    , MAX(data_ultima_entrega) AS data_ultima_entrega
  FROM tComHash
  GROUP BY
    documento
    , hash_endereco
)

, tOrdenadas AS (
  SELECT
    documento
    , hash_endereco
    , endereco
    , logradouro
    , numero
    , endereco_json_complemento
    , bairro
    , cidade
    , uf
    , cep
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento, hash_endereco
      ORDER BY
        {{ ordem_versao('dt_ref') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tComHash
)

, tMaisRecentes AS (
  SELECT
    documento
    , hash_endereco
    , endereco
    , logradouro
    , numero
    , endereco_json_complemento
    , bairro
    , cidade
    , uf
    , cep
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tOrdenadas
  WHERE 1 = 1
    AND num_aparicao = 1
)

SELECT
  e.documento
  , e.hash_endereco
  , r.endereco
  , r.logradouro
  , r.numero
  , r.endereco_json_complemento
  , r.bairro
  , r.cidade
  , r.uf
  , r.cep
  , e.data_primeira_entrega
  , e.data_ultima_entrega
  , r._arquivo
  , r._linha
  , r._hash_arquivo
FROM tEntregas AS e
INNER JOIN tMaisRecentes AS r
  ON e.documento IS NOT DISTINCT FROM r.documento
    AND e.hash_endereco = r.hash_endereco
