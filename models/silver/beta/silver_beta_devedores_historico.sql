{#
  Grão: uma linha por versão do registro do beta. Versão é o mesmo conteúdo padronizado (tipo e
  número do documento, campos escalares, mais a lista de contatos e a de endereços), sem contar
  `_arquivo`, `_linha`, `_hash_arquivo` e `data_entrega` (H2); a data de atualização da fonte é
  conteúdo. A ordem dos elementos de uma lista não cria versão: a assinatura de cada lista ordena
  os elementos pelo próprio conteúdo (macro `assinatura_lista`). O conteúdo igual colapsa onde
  quer que apareça, e NULL é igual a NULL. Chave: `hash_conteudo` (H3, macro `hash_conteudo`).
  Entram as linhas sem documento (`documento_tipo` e `documento` NULL, R3). Fica fora a linha que
  repete o cabeçalho do próprio arquivo (`_linha_original` igual a `arquivos.cabecalho`; o beta é
  JSON Lines e não tem cabeçalho, então nenhuma sai); o teste
  `cabecalho_repetido_fora_da_historica` conta as linhas excluídas de cada fonte.
  Os contatos e os endereços de cada versão estão em `devedores_historico_contatos` e
  `devedores_historico_enderecos`. `data_primeira_entrega` e `data_ultima_entrega` cobrem todas as
  aparições da versão; `_arquivo`, `_linha` e `_hash_arquivo` são da aparição mais recente (R1),
  escolhida por `ordem_versao`.
#}
{{ config(materialized='table') }}
{%- set colunas_do_conteudo = [
  'documento_tipo', 'documento', 'nome_completo', 'data_nascimento', 'vinculo_empresa_cnpj'
  , 'vinculo_empresa_desde', 'renda_mensal', 'atualizado_em', 'assinatura_contatos'
  , 'assinatura_enderecos'
] %}

WITH tLinhas AS (
  SELECT
    p.documento_tipo
    , p.documento
    , p.nome_completo
    , p.data_nascimento
    , p.vinculo_empresa_cnpj
    , p.vinculo_empresa_desde
    , p.renda_mensal
    , p.atualizado_em
    , p.data_entrega
    , p._arquivo
    , p._linha
    , p._hash_arquivo
  FROM {{ ref('silver_beta_devedores_padronizados') }} AS p
  INNER JOIN {{ source('bronze_beta', 'devedores') }} AS b
    ON p._arquivo = b._arquivo
      AND p._linha = b._linha
  LEFT JOIN {{ source('bronze_beta', 'arquivos') }} AS a
    ON p._arquivo = a.arquivo
  WHERE 1 = 1
    AND NOT COALESCE(b._linha_original = a.cabecalho, FALSE)
)

, tElementosDeContato AS (
  SELECT
    _arquivo
    , _linha
    , {{ hash_conteudo(['tipo_contato', 'contato', 'tipo', 'principal']) }} AS hash_elemento
  FROM {{ ref('silver_beta_devedores_contatos_padronizados') }}
)

, tAssinaturaDeContatos AS (
  SELECT
    _arquivo
    , _linha
    , {{ assinatura_lista('hash_elemento') }} AS assinatura_contatos
  FROM tElementosDeContato
  GROUP BY
    _arquivo
    , _linha
)

, tElementosDeEndereco AS (
  SELECT
    _arquivo
    , _linha
    , {{ hash_conteudo([
      'tipo', 'logradouro', 'numero', 'complemento', 'bairro', 'cidade', 'uf', 'cep', 'atual'
    ]) }} AS hash_elemento
  FROM {{ ref('silver_beta_devedores_enderecos_padronizados') }}
)

, tAssinaturaDeEnderecos AS (
  SELECT
    _arquivo
    , _linha
    , {{ assinatura_lista('hash_elemento') }} AS assinatura_enderecos
  FROM tElementosDeEndereco
  GROUP BY
    _arquivo
    , _linha
)

, tComAssinaturas AS (
  SELECT
    l.documento_tipo
    , l.documento
    , l.nome_completo
    , l.data_nascimento
    , l.vinculo_empresa_cnpj
    , l.vinculo_empresa_desde
    , l.renda_mensal
    , l.atualizado_em
    , l.data_entrega
    , l._arquivo
    , l._linha
    , l._hash_arquivo
    , c.assinatura_contatos
    , e.assinatura_enderecos
  FROM tLinhas AS l
  LEFT JOIN tAssinaturaDeContatos AS c
    ON l._arquivo = c._arquivo
      AND l._linha = c._linha
  LEFT JOIN tAssinaturaDeEnderecos AS e
    ON l._arquivo = e._arquivo
      AND l._linha = e._linha
)

, tComHash AS (
  SELECT
    documento_tipo
    , documento
    , nome_completo
    , data_nascimento
    , vinculo_empresa_cnpj
    , vinculo_empresa_desde
    , renda_mensal
    , atualizado_em
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , {{ hash_conteudo(colunas_do_conteudo) }} AS hash_conteudo
  FROM tComAssinaturas
)

, tEntregas AS (
  SELECT
    hash_conteudo
    , MIN(data_entrega) AS data_primeira_entrega
    , MAX(data_entrega) AS data_ultima_entrega
  FROM tComHash
  GROUP BY
    hash_conteudo
)

, tOrdenadas AS (
  SELECT
    documento_tipo
    , documento
    , nome_completo
    , data_nascimento
    , vinculo_empresa_cnpj
    , vinculo_empresa_desde
    , renda_mensal
    , atualizado_em
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY hash_conteudo
      ORDER BY
        {{ ordem_versao('atualizado_em') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tComHash
)

SELECT
  o.documento_tipo
  , o.documento
  , o.nome_completo
  , o.data_nascimento
  , o.vinculo_empresa_cnpj
  , o.vinculo_empresa_desde
  , o.renda_mensal
  , o.atualizado_em
  , o.hash_conteudo
  , e.data_primeira_entrega
  , e.data_ultima_entrega
  , o._arquivo
  , o._linha
  , o._hash_arquivo
FROM tOrdenadas AS o
INNER JOIN tEntregas AS e
  ON o.hash_conteudo = e.hash_conteudo
WHERE 1 = 1
  AND o.num_aparicao = 1
