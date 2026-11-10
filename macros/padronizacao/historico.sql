{#
  Peças da histórica de versões (decisões H2, H3 e H5 do plano). A histórica guarda uma linha por
  versão do registro; a chave da versão é o `hash_conteudo`, e a versão atual de cada documento sai
  de um `ROW_NUMBER()` ordenado por `ordem_versao`. As macros ficam aqui para a serialização e o
  desempate existirem num lugar só, iguais nas três fontes.
  Só `MD5`, `LENGTH`, `CAST AS VARCHAR`, `||`, `STRING_AGG` e `COLLATE "C"`, que existem no
  PostgreSQL 18 e no DuckDB 2.0. O DuckDB aceitou `COLLATE "C"` com aspas por execução.
#}

{#
  Serialização injetiva de um valor: NULL vira `N`; um valor vira `V<tamanho>:<texto>`, com o texto
  de `CAST(valor AS VARCHAR)`. O prefixo de tamanho evita que ('ab', 'c') e ('a', 'bc') deem o mesmo
  texto, e o marcador `N` nunca começa um valor, então NULL difere de texto vazio (`V0:`). Não usa
  `CONCAT_WS`, que pula NULL. Macro de apoio de `hash_conteudo` e `assinatura_lista`.
#}
{% macro serializar_valor(expressao) -%}
  CASE
    WHEN {{ expressao }} IS NULL THEN 'N'
    ELSE 'V' || CAST(LENGTH(CAST({{ expressao }} AS VARCHAR)) AS VARCHAR) || ':' || CAST({{ expressao }} AS VARCHAR)
  END
{%- endmacro %}

{#
  `MD5` da serialização das expressões recebidas, na ordem recebida, concatenadas sem separador
  (o prefixo de tamanho já separa). Devolve texto hexadecimal. A ordem das colunas faz parte do
  contrato: o mesmo conteúdo em outra ordem dá outro hash. O texto gerado pelo `CAST` pode diferir
  entre DuckDB e PostgreSQL, então o hash não é portável entre os motores (não verificado, não há
  instância de PostgreSQL); a deduplicação dá o mesmo resultado nos dois.
#}
{% macro hash_conteudo(colunas) -%}
  MD5(
    {%- for coluna in colunas %}
    {{ '|| ' if not loop.first else '' }}{{ serializar_valor(coluna) }}
    {%- endfor %}
  )
{%- endmacro %}

{#
  Assinatura de uma lista de elementos para usar num `GROUP BY` que traga uma linha recebida por
  grupo: `STRING_AGG` dos elementos serializados, ordenados pelo próprio texto serializado em ordem
  de bytes (`COLLATE "C"`). Ordenar pelo conteúdo faz a ordem em que a lista chegou não mudar a
  assinatura (H2: a ordem dos elementos não cria versão). A lista vazia dá NULL, que entra no
  `hash_conteudo` como ausência. Para elementos com várias partes, passe uma expressão que já
  junta as partes (por exemplo um `hash_conteudo` das partes).
#}
{% macro assinatura_lista(expressao_elemento) -%}
  STRING_AGG(
    {{ serializar_valor(expressao_elemento) }}
    , ''
    ORDER BY {{ serializar_valor(expressao_elemento) }} COLLATE "C"
  )
{%- endmacro %}

{#
  Lista de ordenação da versão mais recente (S3, R7, H5), para usar dentro do `ORDER BY` de um
  `ROW_NUMBER()`: data de atualização da fonte, data de entrega, arquivo e linha, todos
  decrescentes, com NULL por último nas datas. `_arquivo` usa `COLLATE "C"` (ordem por bytes), e
  por isso `..._reenvio` vence o original da mesma data. O `_linha DESC` final é uma convenção
  arbitrária e determinística ("o último registro escrito vale"): a posição da linha no arquivo
  não tem significado medido. Os conflitos que ela decide a gold resolve com regra própria.
#}
{% macro ordem_versao(coluna_atualizacao) -%}
  {{ coluna_atualizacao }} DESC NULLS LAST
  , data_entrega DESC NULLS LAST
  , _arquivo COLLATE "C" DESC
  , _linha DESC
{%- endmacro %}
