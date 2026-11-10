{#
  Grão: uma linha por (tipo de documento, documento, endereço padronizado), com a primeira e a
  última data de entrega em que o par apareceu. Sai da histórica (`silver_beta_devedores_historico`
  e `silver_beta_devedores_historico_enderecos`), que guarda todas as versões, não só a atual
  (S4): um endereço que saiu da versão mais recente continua registrado. O endereço é o conjunto
  das partes padronizadas (`logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `uf`, `cep`;
  H4), resumido em `hash_endereco` (macro `hash_conteudo`, sem o documento, para a gold achar o
  mesmo endereço em documentos diferentes). O beta não manda o endereço em texto; a oitava
  posição do hash (texto, usado nas outras fontes só quando todas as partes são NULL) fica NULL,
  para o mesmo endereço dar o mesmo hash nas três fontes. A posição na lista e o fato de o
  endereço estar numa lista ou ser um objeto só não entram na identidade. Só existe linha para
  endereço com alguma parte preenchida, como no alfa e no gama. A versão sem documento
  (vazio ou só zeros) também entra, com `documento_tipo` e `documento` NULL: esses endereços são
  deduplicados só por `hash_endereco` entre si e nunca se juntam a um par de documento válido.

  A primeira entrega é a menor das primeiras entregas das versões que têm o par; a última, a
  maior das últimas. O `tipo` e o `atual` são do provedor e vêm da aparição mais recente do par:
  a da versão com a maior `ordem_versao` (mesma ordem da versão do devedor, S3) e, no empate, a
  maior posição na lista. `atual` fica como veio (S7): nenhuma regra escolhe o endereço vigente
  aqui. `_arquivo`, `_linha` e `_hash_arquivo` são dessa mesma aparição, porque a data de entrega
  não identifica o arquivo.
#}
{%- set partes_do_endereco = [
  'logradouro', 'numero', 'complemento', 'bairro', 'cidade', 'uf', 'cep', 'endereco_sem_partes'
] %}

WITH tAparicoes AS (
  SELECT
    h.documento_tipo
    , h.documento
    , e.tipo
    , e.logradouro
    , e.numero
    , e.complemento
    , e.bairro
    , e.cidade
    , e.uf
    , e.cep
    , CAST(NULL AS VARCHAR) AS endereco_sem_partes
    , e.atual
    , e.posicao
    , h.atualizado_em
    , h.data_primeira_entrega
    , h.data_ultima_entrega
    , h.data_ultima_entrega AS data_entrega
    , e._arquivo
    , e._linha
    , e._hash_arquivo
  FROM {{ ref('silver_beta_devedores_historico') }} AS h
  INNER JOIN {{ ref('silver_beta_devedores_historico_enderecos') }} AS e
    ON h.hash_conteudo = e.hash_conteudo
  WHERE 1 = 1
    AND COALESCE(
      e.logradouro, e.numero, e.complemento, e.bairro, e.cidade, e.uf, e.cep
    ) IS NOT NULL
)

, tComHash AS (
  SELECT
    documento_tipo
    , documento
    , tipo
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , uf
    , cep
    , atual
    , posicao
    , atualizado_em
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
    documento_tipo
    , documento
    , hash_endereco
    , MIN(data_primeira_entrega) AS data_primeira_entrega
    , MAX(data_ultima_entrega) AS data_ultima_entrega
  FROM tComHash
  GROUP BY
    documento_tipo
    , documento
    , hash_endereco
)

, tOrdenadas AS (
  SELECT
    documento_tipo
    , documento
    , hash_endereco
    , tipo
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , uf
    , cep
    , atual
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY documento_tipo, documento, hash_endereco
      ORDER BY
        {{ ordem_versao('atualizado_em') }}
        , posicao DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tComHash
)

, tMaisRecentes AS (
  SELECT
    documento_tipo
    , documento
    , hash_endereco
    , tipo
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , uf
    , cep
    , atual
    , _arquivo
    , _linha
    , _hash_arquivo
  FROM tOrdenadas
  WHERE 1 = 1
    AND num_aparicao = 1
)

SELECT
  e.documento_tipo
  , e.documento
  , e.hash_endereco
  , r.tipo
  , r.logradouro
  , r.numero
  , r.complemento
  , r.bairro
  , r.cidade
  , r.uf
  , r.cep
  , r.atual
  , e.data_primeira_entrega
  , e.data_ultima_entrega
  , r._arquivo
  , r._linha
  , r._hash_arquivo
FROM tEntregas AS e
INNER JOIN tMaisRecentes AS r
  ON e.documento_tipo IS NOT DISTINCT FROM r.documento_tipo
    AND e.documento IS NOT DISTINCT FROM r.documento
    AND e.hash_endereco = r.hash_endereco
