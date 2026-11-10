{#
  Grão: uma entrega diária de um provedor, a que chegou numa data de referência (`provedor`,
  `dt_referencia`). A data é a do nome do arquivo (macro `data_de_entrega`); os arquivos do mesmo
  dia (o original e o reenvio) somam numa linha só (D1). A carga histórica fica fora: não é uma
  entrega do dia e distorceria toda média.
  Cada coluna responde a uma pergunta sobre os arquivos do dia, sem julgar:
    - `qt_registros`: linhas recebidas (`bronze_<fonte>.arquivos.linhas`), legíveis ou não;
    - `qt_linhas_ilegiveis`: linhas que o leitor não separou em colunas;
    - `qt_registros_repetidos`: linhas cujo texto idêntico já tinha chegado antes, em arquivo
      anterior ou mais acima no mesmo arquivo (a carga histórica conta como anterior);
    - `qt_registros_atrasados`: linhas legíveis atualizadas na fonte antes do dia da entrega
      (`dt_atualizacao` menor que `dt_referencia`); `NULL` na data de atualização não conta;
    - `desc_cabecalho`: os cabeçalhos distintos dos arquivos do dia, em ordem de bytes.
  As contagens por arquivo vêm de `entregas_diarias_contagens_<fonte>` (macro
  `contagens_da_entrega`). Fonte nova entra em `arquivo_historico` e ganha o próprio modelo de
  contagens. A comparação com a entrega anterior e a média ficam em `ft_entrega_diaria`.
#}
WITH tArquivosDiarios AS (
  {%- for fonte, arquivo_historico in var('arquivo_historico').items() %}
    SELECT
      '{{ fonte }}' AS provedor
      , arquivo
      , linhas
      , cabecalho
    FROM {{ source('bronze_' ~ fonte, 'arquivos') }}
    WHERE 1 = 1
      AND arquivo <> '{{ arquivo_historico }}'
    {%- if not loop.last %}

      UNION ALL

    {% endif -%}
  {%- endfor %}
)

, tComData AS (
  SELECT
    provedor
    , arquivo
    , linhas
    , cabecalho
    , {{ data_do_nome_do_arquivo('arquivo') }} AS dt_referencia
  FROM tArquivosDiarios
)

, tContagens AS (
  {%- for fonte in var('arquivo_historico') %}
    SELECT
      provedor
      , arquivo
      , qt_linhas_ilegiveis
      , qt_registros_repetidos
      , qt_registros_atrasados
    FROM {{ ref('entregas_diarias_contagens_' ~ fonte) }}
    {%- if not loop.last %}

      UNION ALL

    {% endif -%}
  {%- endfor %}
)

SELECT
  arquivos.provedor
  , arquivos.dt_referencia
  , COUNT(*) AS qt_arquivos
  , SUM(arquivos.linhas) AS qt_registros
  , SUM(contagens.qt_linhas_ilegiveis) AS qt_linhas_ilegiveis
  , SUM(contagens.qt_registros_repetidos) AS qt_registros_repetidos
  , SUM(contagens.qt_registros_atrasados) AS qt_registros_atrasados
  , STRING_AGG(DISTINCT arquivos.cabecalho, ' | ' ORDER BY arquivos.cabecalho) AS desc_cabecalho
  , STRING_AGG(arquivos.arquivo, ' | ' ORDER BY arquivos.arquivo) AS desc_arquivos
FROM tComData AS arquivos
INNER JOIN tContagens AS contagens
  ON arquivos.provedor = contagens.provedor
    AND arquivos.arquivo = contagens.arquivo
GROUP BY
  arquivos.provedor
  , arquivos.dt_referencia
