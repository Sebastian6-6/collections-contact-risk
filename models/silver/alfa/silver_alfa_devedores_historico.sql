{#
  Grão: uma linha por versão do registro do alfa. Versão é o mesmo conteúdo padronizado (documento
  incluído), sem contar `_arquivo`, `_linha`, `_hash_arquivo` e `data_entrega` (H2); a data de
  atualização da fonte é conteúdo. O conteúdo igual colapsa onde quer que apareça, e NULL é igual
  a NULL. Chave: `hash_conteudo` (H3, macro `hash_conteudo`).
  Entram as linhas sem documento (`documento` NULL, R3). Fica fora a linha que repete o cabeçalho
  do próprio arquivo (`_linha_original` igual a `arquivos.cabecalho`); ela continua na bronze e o
  teste `cabecalho_repetido_fora_da_historica` a conta.
  `data_primeira_entrega` e `data_ultima_entrega` cobrem todas as aparições da versão; `_arquivo`,
  `_linha` e `_hash_arquivo` são da aparição mais recente (R1), escolhida por `ordem_versao`.
#}
{{ config(materialized='table') }}
{%- set colunas_do_conteudo = [
  'documento', 'nome_completo', 'data_nascimento', 'cnpj_empregador', 'cargo'
  , 'salario_informado', 'telefone', 'email', 'endereco', 'logradouro', 'numero', 'complemento'
  , 'bairro', 'cidade', 'cep', 'uf', 'data_atualizacao'
] %}

WITH tLinhas AS (
  SELECT
    p.documento
    , p.nome_completo
    , p.data_nascimento
    , p.cnpj_empregador
    , p.cargo
    , p.salario_informado
    , p.telefone
    , p.email
    , p.endereco
    , p.logradouro
    , p.numero
    , p.complemento
    , p.bairro
    , p.cidade
    , p.cep
    , p.uf
    , p.data_atualizacao
    , p.data_entrega
    , p._arquivo
    , p._linha
    , p._hash_arquivo
  FROM {{ ref('silver_alfa_devedores_padronizados') }} AS p
  INNER JOIN {{ source('bronze_alfa', 'devedores') }} AS b
    ON p._arquivo = b._arquivo
      AND p._linha = b._linha
  LEFT JOIN {{ source('bronze_alfa', 'arquivos') }} AS a
    ON p._arquivo = a.arquivo
  WHERE 1 = 1
    AND NOT COALESCE(b._linha_original = a.cabecalho, FALSE)
)

, tComHash AS (
  SELECT
    documento
    , nome_completo
    , data_nascimento
    , cnpj_empregador
    , cargo
    , salario_informado
    , telefone
    , email
    , endereco
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , cep
    , uf
    , data_atualizacao
    , data_entrega
    , _arquivo
    , _linha
    , _hash_arquivo
    , {{ hash_conteudo(colunas_do_conteudo) }} AS hash_conteudo
  FROM tLinhas
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
    , nome_completo
    , data_nascimento
    , cnpj_empregador
    , cargo
    , salario_informado
    , telefone
    , email
    , endereco
    , logradouro
    , numero
    , complemento
    , bairro
    , cidade
    , cep
    , uf
    , data_atualizacao
    , hash_conteudo
    , _arquivo
    , _linha
    , _hash_arquivo
    , ROW_NUMBER() OVER (
      PARTITION BY hash_conteudo
      ORDER BY
        {{ ordem_versao('data_atualizacao') }}
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tComHash
)

SELECT
  o.documento
  , o.nome_completo
  , o.data_nascimento
  , o.cnpj_empregador
  , o.cargo
  , o.salario_informado
  , o.telefone
  , o.email
  , o.endereco
  , o.logradouro
  , o.numero
  , o.complemento
  , o.bairro
  , o.cidade
  , o.cep
  , o.uf
  , o.data_atualizacao
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
