{% docs bronze_arquivo %}
Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a
coluna `arquivo` do registro `arquivos`.
{% enddocs %}

{% docs bronze_linha %}
Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1,
inclusive o cabeçalho do CSV).
Com `_arquivo`, identifica a linha recebida.
{% enddocs %}

{% docs bronze_hash_arquivo %}
SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente
(um reenvio) têm hashes diferentes.
{% enddocs %}

{% docs bronze_linha_original %}
Texto da linha como foi recebida, sem nenhuma interpretação. Fica preenchido mesmo quando a
linha é ilegível.
{% enddocs %}

{% docs bronze_motivo_ilegivel %}
`NULL` quando o leitor separou a linha em colunas. Quando não conseguiu (CSV malformado ou em
branco), o motivo; nesse caso as colunas de dados ficam `NULL` e vale o texto em
`_linha_original`.
{% enddocs %}

{% docs bronze_arquivos_tabela %}
Registro de cargas da fonte: uma linha por arquivo lido, com o que a ingestão viu nele. Serve
para conferir que a tabela de dados tem todas as linhas do arquivo. Não guarda horário de
execução, para que duas execuções idênticas deem tabelas idênticas.
{% enddocs %}

{% docs bronze_arquivos_arquivo %}
Caminho relativo do arquivo, a partir da raiz do repositório. Chave do registro.
{% enddocs %}

{% docs bronze_arquivos_entidade %}
Nome da tabela de dados que recebeu as linhas do arquivo, na mesma fonte.
{% enddocs %}

{% docs bronze_arquivos_hash %}
SHA-256 do conteúdo do arquivo.
{% enddocs %}

{% docs bronze_arquivos_bytes %}
Tamanho do arquivo em bytes.
{% enddocs %}

{% docs bronze_arquivos_linhas %}
Quantidade de linhas de dados lidas do arquivo, sem contar o cabeçalho. Um arquivo só com
cabeçalho tem 0. A tabela de dados deve ter exatamente esta quantidade de linhas para o arquivo.
{% enddocs %}

{% docs bronze_arquivos_cabecalho %}
Cabeçalho do arquivo como veio (CSV). `NULL` para formatos sem cabeçalho, como o JSONL.
{% enddocs %}
