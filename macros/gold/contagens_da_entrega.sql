{#
  Corpo dos modelos `entregas_diarias_contagens_<fonte>`: para cada arquivo de uma fonte, quantas
  linhas ilegíveis, repetidas e atrasadas ele trouxe. Grão: um arquivo (`provedor`, `arquivo`).
    - `qt_linhas_ilegiveis`: linhas que o leitor não separou em colunas;
    - `qt_registros_repetidos`: linhas legíveis cujo texto idêntico (`_linha_original`) já tinha
      chegado antes, em arquivo anterior (a carga histórica conta) ou mais acima no mesmo arquivo.
      A ordem é a data de entrega, o arquivo em ordem de bytes e a linha; `ROW_NUMBER()` maior que 1.
      As ilegíveis não numeram com as legíveis (`legivel` entra na partição);
    - `qt_registros_atrasados`: linhas legíveis atualizadas na fonte antes do dia da entrega. A data
      de atualização de cada fonte tem nome e lugar próprios (coluna `data_atualizacao`, chave JSON
      `atualizado_em`, coluna `dt_ref`), por isso `expressao_atualizacao` é argumento: a expressão
      sobre a bronze (alias `bronze`) que dá o texto da data, lida com `data_flexivel` como a
      silver lê; `NULL` na data não conta.
  Lê da bronze e não de `*_devedores_padronizados`: as três silvers efêmeras têm o mesmo apelido de
  CTE no dbt, e duas delas na mesma consulta dão "Duplicate CTE name". Cada fonte tem o próprio
  modelo efêmero para os apelidos serem distintos.
#}
{% macro contagens_da_entrega(fonte, expressao_atualizacao) -%}
WITH tRegistros AS (
  SELECT
    bronze._arquivo
    , bronze._linha
    , bronze._linha_original
    , bronze._motivo_ilegivel IS NULL AS legivel
    , {{ data_de_entrega('bronze._arquivo', fonte) }} AS data_entrega
    , {{ data_flexivel(expressao_atualizacao) }} AS dt_atualizacao
  FROM {{ source('bronze_' ~ fonte, 'devedores') }} AS bronze
)

, tNumeradas AS (
  SELECT
    _arquivo
    , legivel
    , data_entrega
    , dt_atualizacao
    , ROW_NUMBER() OVER (
      PARTITION BY legivel, _linha_original
      ORDER BY
        data_entrega ASC NULLS LAST
        , _arquivo COLLATE "C" ASC
        , _linha ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS num_aparicao
  FROM tRegistros
)

, tPorArquivo AS (
  SELECT
    _arquivo AS arquivo
    , COUNT(CASE WHEN NOT legivel THEN 1 END) AS qt_linhas_ilegiveis
    , COUNT(CASE WHEN legivel AND num_aparicao > 1 THEN 1 END) AS qt_registros_repetidos
    , COUNT(CASE WHEN legivel AND dt_atualizacao < data_entrega THEN 1 END) AS qt_registros_atrasados
  FROM tNumeradas
  GROUP BY _arquivo
)

SELECT
  '{{ fonte }}' AS provedor
  , arquivos.arquivo
  , contagem.qt_linhas_ilegiveis
  , contagem.qt_registros_repetidos
  , contagem.qt_registros_atrasados
FROM {{ source('bronze_' ~ fonte, 'arquivos') }} AS arquivos
LEFT JOIN tPorArquivo AS contagem
  ON arquivos.arquivo = contagem.arquivo
{%- endmacro %}
