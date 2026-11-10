{#
  Grão: uma linha por versão do registro do gama. Versão é o mesmo conteúdo padronizado (campos
  escalares, com o texto original do endereço e as partes, mais a lista de contatos), sem contar
  `_arquivo`, `_linha`, `_hash_arquivo` e `data_entrega` (H2); a data de atualização da fonte
  (`dt_ref`) é conteúdo. A ordem dos contatos não cria versão: a assinatura da lista ordena os
  elementos pelo próprio conteúdo (macro `assinatura_lista`). O conteúdo igual colapsa onde quer
  que apareça, e NULL é igual a NULL. Chave: `hash_conteudo` (H3, macro `hash_conteudo`).
  Entram as linhas sem documento (`documento` NULL, R3). Fica fora a linha que repete o
  cabeçalho do próprio arquivo (`_linha_original` igual a `arquivos.cabecalho`); ela continua na
  bronze e o teste `cabecalho_repetido_fora_da_historica` a conta.
  Os contatos de cada versão estão em `devedores_historico_contatos`. `data_primeira_entrega` e
  `data_ultima_entrega` cobrem todas as aparições da versão; `_arquivo`, `_linha` e
  `_hash_arquivo` são da aparição mais recente (R1), escolhida por `ordem_versao`.
#}
{%- set colunas_do_conteudo = [
  'documento', 'nome', 'data_nascimento', 'cnpj_empregador_raw', 'atributos_extra_estado_civil'
  , 'atributos_extra_qtd_dependentes', 'atributos_extra_score_externo'
  , 'atributos_extra_escolaridade', 'atributos_extra_possui_imovel', 'atributos_extra_fonte_score'
  , 'endereco', 'logradouro', 'numero', 'endereco_json_complemento', 'bairro', 'cidade', 'uf'
  , 'cep', 'dt_ref', 'assinatura_contatos'
] %}

WITH tLinhas AS (
  SELECT
    p.documento
    , p.nome
    , p.data_nascimento
    , p.cnpj_empregador_raw
    , p.atributos_extra_estado_civil
    , p.atributos_extra_qtd_dependentes
    , p.atributos_extra_score_externo
    , p.atributos_extra_escolaridade
    , p.atributos_extra_possui_imovel
    , p.atributos_extra_fonte_score
    , p.endereco
    , p.logradouro
    , p.numero
    , p.endereco_json_complemento
    , p.bairro
    , p.cidade
    , p.uf
    , p.cep
    , p.dt_ref
    , p.data_entrega
    , p._arquivo
    , p._linha
    , p._hash_arquivo
  FROM {{ ref('silver_gama_devedores_padronizados') }} AS p
  INNER JOIN {{ source('bronze_gama', 'devedores') }} AS b
    ON p._arquivo = b._arquivo
      AND p._linha = b._linha
  LEFT JOIN {{ source('bronze_gama', 'arquivos') }} AS a
    ON p._arquivo = a.arquivo
  WHERE 1 = 1
    AND NOT COALESCE(b._linha_original = a.cabecalho, FALSE)
)

, tElementosDeContato AS (
  SELECT
    _arquivo
    , _linha
    , {{ hash_conteudo(['tipo_contato', 'contato', 'tipo']) }} AS hash_elemento
  FROM {{ ref('silver_gama_devedores_contatos_padronizados') }}
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

, tComAssinatura AS (
  SELECT
    l.documento
    , l.nome
    , l.data_nascimento
    , l.cnpj_empregador_raw
    , l.atributos_extra_estado_civil
    , l.atributos_extra_qtd_dependentes
    , l.atributos_extra_score_externo
    , l.atributos_extra_escolaridade
    , l.atributos_extra_possui_imovel
    , l.atributos_extra_fonte_score
    , l.endereco
    , l.logradouro
    , l.numero
    , l.endereco_json_complemento
    , l.bairro
    , l.cidade
    , l.uf
    , l.cep
    , l.dt_ref
    , l.data_entrega
    , l._arquivo
    , l._linha
    , l._hash_arquivo
    , c.assinatura_contatos
  FROM tLinhas AS l
  LEFT JOIN tAssinaturaDeContatos AS c
    ON l._arquivo = c._arquivo
      AND l._linha = c._linha
)

, tComHash AS (
  SELECT
    documento
    , nome
    , data_nascimento
    , cnpj_empregador_raw
    , atributos_extra_estado_civil
    , atributos_extra_qtd_dependentes
    , atributos_extra_score_externo
    , atributos_extra_escolaridade
    , atributos_extra_possui_imovel
    , atributos_extra_fonte_score
    , endereco
    , logradouro
    , numero
    , endereco_json_complemento
    , bairro
    , cidade
    , uf
    , cep
    , dt_ref
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , {{ hash_conteudo(colunas_do_conteudo) }} AS hash_conteudo
  FROM tComAssinatura
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
    documento
    , nome
    , data_nascimento
    , cnpj_empregador_raw
    , atributos_extra_estado_civil
    , atributos_extra_qtd_dependentes
    , atributos_extra_score_externo
    , atributos_extra_escolaridade
    , atributos_extra_possui_imovel
    , atributos_extra_fonte_score
    , endereco
    , logradouro
    , numero
    , endereco_json_complemento
    , bairro
    , cidade
    , uf
    , cep
    , dt_ref
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY hash_conteudo
      ORDER BY
        {{ ordem_versao('dt_ref') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tComHash
)

SELECT
  o.documento
  , o.nome
  , o.data_nascimento
  , o.cnpj_empregador_raw
  , o.atributos_extra_estado_civil
  , o.atributos_extra_qtd_dependentes
  , o.atributos_extra_score_externo
  , o.atributos_extra_escolaridade
  , o.atributos_extra_possui_imovel
  , o.atributos_extra_fonte_score
  , o.endereco
  , o.logradouro
  , o.numero
  , o.endereco_json_complemento
  , o.bairro
  , o.cidade
  , o.uf
  , o.cep
  , o.dt_ref
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
