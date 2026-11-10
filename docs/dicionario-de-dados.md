# Dicionário de dados

Gerado por `scripts/gerar_dicionario.py` a partir de `target/manifest.json` (descrições dos YAML) e `target/catalog.json` (tipos reais do DuckDB). Não editar à mão: a descrição de cada coluna e a justificativa do tipo moram no YAML de `models/`.

## Ganhos medidos dos tipos

Medidas no DuckDB embutido desta máquina, 4 threads, 5 milhões de linhas, melhor de 3 execuções.

| Escolha | Alternativa | Medida |
|---|---|---|
| Chave substituta `INTEGER` | `md5` da chave natural | junção da tabela com ela mesma: 0,204 s contra 0,279 s. O `md5` ainda é reversível: 10 milhões de hashes de CPF em 3,1 s (G6, `docs/decisoes-de-modelagem.md`), e o CPF se espalharia por toda tabela. Tamanho em disco: não medido (4 bytes contra 32 caracteres, por construção) |
| `DATE` | texto `dd/mm/aaaa` | filtro de um ano: 0,004 s contra 0,076 s, porque o texto precisa de `strptime` a cada linha; o texto ainda aceita datas inválidas |
| `NUMERIC(18,2)` no capital | `DOUBLE` | soma de 5 milhões de valores com 2 casas: o `NUMERIC` dá 1782482175000,00 exato e o `DOUBLE` se afasta em cerca de 0,0001. Contra texto convertido a cada consulta: 0,002 s contra 0,039 s |

## Camada bronze

### `bronze_alfa.arquivos`

Registro de cargas da fonte: uma linha por arquivo lido, com o que a ingestão viu nele. Serve para conferir que a tabela de dados tem todas as linhas do arquivo. Não guarda horário de execução, para que duas execuções idênticas deem tabelas idênticas.

| Coluna | Tipo | Descrição |
|---|---|---|
| `arquivo` | `VARCHAR` | Caminho relativo do arquivo, a partir da raiz do repositório. Chave do registro. |
| `entidade` | `VARCHAR` | Nome da tabela de dados que recebeu as linhas do arquivo, na mesma fonte. |
| `hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo. |
| `bytes` | `BIGINT` | Tamanho do arquivo em bytes. |
| `linhas` | `BIGINT` | Quantidade de linhas de dados lidas do arquivo, sem contar o cabeçalho. Um arquivo só com cabeçalho tem 0. A tabela de dados deve ter exatamente esta quantidade de linhas para o arquivo. |
| `cabecalho` | `VARCHAR` | Cabeçalho do arquivo como veio (CSV). `NULL` para formatos sem cabeçalho, como o JSONL. |

### `bronze_alfa.devedores`

Uma linha por linha recebida dos arquivos do provedor alfa (histórico e entregas diárias). Colunas de dados em texto, como vieram; a coluna `cpf` é `NULL` nas entregas em que o provedor passou a chamá-la `documento`, e vice-versa.

| Coluna | Tipo | Descrição |
|---|---|---|
| `cpf` | `VARCHAR` | CPF do devedor como veio, com ou sem pontuação. `NULL` nos arquivos em que o provedor usa `documento` no lugar. |
| `nome_completo` | `VARCHAR` | Nome do devedor. |
| `data_nascimento` | `VARCHAR` | Data de nascimento em texto, no formato da origem. |
| `cnpj_empregador` | `VARCHAR` | CNPJ do empregador em texto, como veio. |
| `cargo` | `VARCHAR` | Cargo do devedor. |
| `salario_informado` | `VARCHAR` | Salário informado em texto, no formato da origem (decimal com vírgula). |
| `telefone` | `VARCHAR` | Telefone em texto, como veio. |
| `email` | `VARCHAR` | E-mail do devedor. |
| `endereco` | `VARCHAR` | Endereço em uma só string, como veio. |
| `cep` | `VARCHAR` | CEP em texto, como veio. |
| `uf` | `VARCHAR` | Sigla da UF. |
| `data_atualizacao` | `VARCHAR` | Data de atualização do registro informada pelo provedor, em texto. |
| `documento` | `VARCHAR` | Documento do devedor nos arquivos em que a coluna `cpf` passou a se chamar `documento`. `NULL` nos demais arquivos. |
| `_arquivo` | `VARCHAR` | Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |
| `_linha_original` | `VARCHAR` | Texto da linha como foi recebida, sem nenhuma interpretação. Fica preenchido mesmo quando a linha é ilegível. |
| `_motivo_ilegivel` | `VARCHAR` | `NULL` quando o leitor separou a linha em colunas. Quando não conseguiu (CSV malformado ou em branco), o motivo; nesse caso as colunas de dados ficam `NULL` e vale o texto em `_linha_original`. |

### `bronze_beta.arquivos`

Registro de cargas da fonte: uma linha por arquivo lido, com o que a ingestão viu nele. Serve para conferir que a tabela de dados tem todas as linhas do arquivo. Não guarda horário de execução, para que duas execuções idênticas deem tabelas idênticas.

| Coluna | Tipo | Descrição |
|---|---|---|
| `arquivo` | `VARCHAR` | Caminho relativo do arquivo, a partir da raiz do repositório. Chave do registro. |
| `entidade` | `VARCHAR` | Nome da tabela de dados que recebeu as linhas do arquivo, na mesma fonte. |
| `hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo. |
| `bytes` | `BIGINT` | Tamanho do arquivo em bytes. |
| `linhas` | `BIGINT` | Quantidade de linhas de dados lidas do arquivo, sem contar o cabeçalho. Um arquivo só com cabeçalho tem 0. A tabela de dados deve ter exatamente esta quantidade de linhas para o arquivo. |
| `cabecalho` | `VARCHAR` | Cabeçalho do arquivo como veio (CSV). `NULL` para formatos sem cabeçalho, como o JSONL. |

### `bronze_beta.devedores`

Uma linha por linha recebida dos arquivos do provedor beta. O JSON não é interpretado na bronze: o texto da linha fica em `registro`, e a validação e a abertura dos campos ficam na silver.

| Coluna | Tipo | Descrição |
|---|---|---|
| `registro` | `VARCHAR` | Texto da linha do JSONL, como veio, válido ou não. |
| `_arquivo` | `VARCHAR` | Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |
| `_linha_original` | `VARCHAR` | Texto da linha como foi recebida, sem nenhuma interpretação. Fica preenchido mesmo quando a linha é ilegível. |
| `_motivo_ilegivel` | `VARCHAR` | `NULL` quando o leitor separou a linha em colunas. Quando não conseguiu (CSV malformado ou em branco), o motivo; nesse caso as colunas de dados ficam `NULL` e vale o texto em `_linha_original`. |

### `bronze_cobranca.arquivos`

Registro de cargas da fonte: uma linha por arquivo lido, com o que a ingestão viu nele. Serve para conferir que a tabela de dados tem todas as linhas do arquivo. Não guarda horário de execução, para que duas execuções idênticas deem tabelas idênticas.

| Coluna | Tipo | Descrição |
|---|---|---|
| `arquivo` | `VARCHAR` | Caminho relativo do arquivo, a partir da raiz do repositório. Chave do registro. |
| `entidade` | `VARCHAR` | Nome da tabela de dados que recebeu as linhas do arquivo, na mesma fonte. |
| `hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo. |
| `bytes` | `BIGINT` | Tamanho do arquivo em bytes. |
| `linhas` | `BIGINT` | Quantidade de linhas de dados lidas do arquivo, sem contar o cabeçalho. Um arquivo só com cabeçalho tem 0. A tabela de dados deve ter exatamente esta quantidade de linhas para o arquivo. |
| `cabecalho` | `VARCHAR` | Cabeçalho do arquivo como veio (CSV). `NULL` para formatos sem cabeçalho, como o JSONL. |

### `bronze_cobranca.contatos_realizados`

Uma linha por linha recebida do histórico de contatos realizados. Colunas de dados em texto, como vieram.

| Coluna | Tipo | Descrição |
|---|---|---|
| `contato_id` | `VARCHAR` | Identificador do contato na origem. |
| `cpf_alvo` | `VARCHAR` | CPF do devedor contatado, como veio. |
| `canal` | `VARCHAR` | Canal usado no contato. |
| `destino` | `VARCHAR` | Telefone ou e-mail para o qual o contato foi feito. |
| `data_hora` | `VARCHAR` | Data e hora do contato, em texto. |
| `resultado` | `VARCHAR` | Resultado do contato. |
| `provedor_origem` | `VARCHAR` | Provedores de origem do contato, em texto (um ou mais, separados por `\|`). |
| `_arquivo` | `VARCHAR` | Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |
| `_linha_original` | `VARCHAR` | Texto da linha como foi recebida, sem nenhuma interpretação. Fica preenchido mesmo quando a linha é ilegível. |
| `_motivo_ilegivel` | `VARCHAR` | `NULL` quando o leitor separou a linha em colunas. Quando não conseguiu (CSV malformado ou em branco), o motivo; nesse caso as colunas de dados ficam `NULL` e vale o texto em `_linha_original`. |

### `bronze_gama.arquivos`

Registro de cargas da fonte: uma linha por arquivo lido, com o que a ingestão viu nele. Serve para conferir que a tabela de dados tem todas as linhas do arquivo. Não guarda horário de execução, para que duas execuções idênticas deem tabelas idênticas.

| Coluna | Tipo | Descrição |
|---|---|---|
| `arquivo` | `VARCHAR` | Caminho relativo do arquivo, a partir da raiz do repositório. Chave do registro. |
| `entidade` | `VARCHAR` | Nome da tabela de dados que recebeu as linhas do arquivo, na mesma fonte. |
| `hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo. |
| `bytes` | `BIGINT` | Tamanho do arquivo em bytes. |
| `linhas` | `BIGINT` | Quantidade de linhas de dados lidas do arquivo, sem contar o cabeçalho. Um arquivo só com cabeçalho tem 0. A tabela de dados deve ter exatamente esta quantidade de linhas para o arquivo. |
| `cabecalho` | `VARCHAR` | Cabeçalho do arquivo como veio (CSV). `NULL` para formatos sem cabeçalho, como o JSONL. |

### `bronze_gama.devedores`

Uma linha por linha recebida dos arquivos do provedor gama. Colunas de dados em texto, como vieram, inclusive o JSON embutido (`contatos`, `endereco_json`, `atributos_extra`), que a silver interpreta.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | Documento do devedor, como veio, com ou sem pontuação. |
| `nome` | `VARCHAR` | Nome do devedor. |
| `data_nascimento` | `VARCHAR` | Data de nascimento em texto, no formato da origem. |
| `contatos` | `VARCHAR` | Lista de contatos em JSON, em texto. |
| `endereco_json` | `VARCHAR` | Endereço em JSON, em texto; o layout varia entre registros. |
| `atributos_extra` | `VARCHAR` | Atributos adicionais do devedor em JSON, em texto. |
| `cnpj_empregador_raw` | `VARCHAR` | CNPJ do empregador em texto, como veio. |
| `dt_ref` | `VARCHAR` | Data de referência do registro informada pelo provedor, em texto. |
| `_arquivo` | `VARCHAR` | Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |
| `_linha_original` | `VARCHAR` | Texto da linha como foi recebida, sem nenhuma interpretação. Fica preenchido mesmo quando a linha é ilegível. |
| `_motivo_ilegivel` | `VARCHAR` | `NULL` quando o leitor separou a linha em colunas. Quando não conseguiu (CSV malformado ou em branco), o motivo; nesse caso as colunas de dados ficam `NULL` e vale o texto em `_linha_original`. |

## Camada silver

### `silver_alfa.devedores`

Devedores do provedor alfa, uma linha por documento normalizado, tirada de `devedores_historico`. Vale a versão mais recente do documento: maior data de atualização da fonte, depois maior data de entrega, depois maior arquivo (nome) e maior linha. Documento vazio, sem dígitos ou só com zeros (`0`, `000.000.000-00`) não identifica ninguém: a linha não vira devedor (fica fora antes de escolher a versão) e continua na bronze, e os contatos dela estão em `devedores_contatos` com `documento` NULL. Nenhuma coluna recebe marcação interpretativa: datas sentinela (1900-01-01) e CPFs inválidos passam como vieram.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | Documento do devedor só com dígitos, com os zeros à esquerda repostos até 11 posições, vindo de `cpf` ou de `documento` da bronze (o provedor renomeou a coluna). Nunca é NULL nem só zeros: documento vazio ou zerado não identifica ninguém. Chave da tabela. |
| `nome_completo` | `VARCHAR` | Nome do devedor, sem espaços nas pontas; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `data_nascimento` | `DATE` | Data de nascimento. A data sentinela 1900-01-01 da origem fica como veio. |
| `cnpj_empregador` | `VARCHAR` | CNPJ do empregador, padronizado para 14 caracteres alfanuméricos. Regra (macro `cnpj_normalizado`): só letras e dígitos, em maiúsculas. Com 14 caracteres, fica como veio. Com menos, completa com zeros à esquerda se o resultado tiver dígitos verificadores válidos; com 12 caracteres e sem essa possibilidade, calcula os dois dígitos pela regra oficial da Receita. O que não encaixa fica como veio (limitação da base, teste `cnpj_do_empregador_fora_da_regra`). Todo valor de 14 caracteres tem dígitos verificadores válidos (teste `cnpj_do_empregador_com_digito_verificador_valido`). `NULL` quando o provedor não informou. |
| `cargo` | `VARCHAR` | Cargo do devedor; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `salario_informado` | `DECIMAL(14,2)` | Salário informado em `NUMERIC(14, 2)`. `NULL` quando vazio; o zero informado pelo provedor fica 0.00. |
| `telefone` | `VARCHAR` | Telefone da versão mais recente, só dígitos, DDD + número, sem o código do país. |
| `email` | `VARCHAR` | E-mail da versão mais recente, em minúsculas; `NULL` quando vazio. |
| `endereco` | `VARCHAR` | Endereço em texto, aparado nas pontas. Texto livre em maiúscula (H4). |
| `logradouro` | `VARCHAR` | Logradouro, só quando `endereco` casa inteiro com `logradouro, numero[, complemento] - bairro - cidade`; senão `NULL`, como todas as outras partes. Texto livre em maiúscula (H4). |
| `numero` | `VARCHAR` | Número do endereço (pode ser `S/N`); `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `complemento` | `VARCHAR` | Complemento do endereço; `NULL` quando não há ou o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `bairro` | `VARCHAR` | Bairro; `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `cidade` | `VARCHAR` | Cidade; `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `cep` | `VARCHAR` | CEP só com dígitos, com o zero à esquerda reposto até 8 posições. |
| `uf` | `VARCHAR` | Sigla da UF em maiúsculas e sem espaços nas pontas. Valor fora das 27 UFs (a origem manda `XX`) vira `NULL`; `NULL` também quando vazio. |
| `data_atualizacao` | `DATE` | Data de atualização do registro informada pelo provedor, usada para escolher a versão. |
| `data_entrega` | `DATE` | Data da entrega do arquivo de onde veio a versão: a data escrita no nome do arquivo ou, só no arquivo histórico configurado, a variável `data_carga_historica` (2026-08-31, enunciado p. 1). `NULL` em entrega diária sem data válida no nome, o que reprova o teste `entrega_diaria_sem_data_valida`. |
| `hash_conteudo` | `VARCHAR` | Chave da versão atual na histórica (`silver_alfa.devedores_historico`): liga o devedor ao conteúdo de que ele saiu. |
| `_arquivo` | `VARCHAR` | Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_alfa.devedores_contatos`

Histórico de contatos do provedor alfa, uma linha por (documento, tipo_contato, contato normalizado), tirado de `devedores_historico`. Considera todas as linhas da bronze com documento, não só a versão atual do devedor: um telefone ou e-mail que saiu da versão mais recente continua registrado, com a última data de entrega em que apareceu. Só existe linha para contato que veio preenchido.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | Documento do devedor, como em `silver_alfa.devedores`. `NULL` nos contatos de linhas de documento vazio ou zerado, que não são devedor: nesse caso o par (`tipo_contato`, `contato`) é único entre as linhas sem documento. |
| `tipo_contato` | `VARCHAR` | Tipo do contato, criado na silver: `telefone` ou `email`. |
| `contato` | `VARCHAR` | Telefone (só dígitos, DDD + número) ou e-mail (minúsculas), conforme `tipo_contato`. |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que o par apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que o par apareceu. |
| `_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento, tipo_contato, contato) (a data de atualização da fonte pesa antes da data de entrega). Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da versão de maior `ordem_versao` que contém o par (documento, tipo_contato, contato) (a data de atualização da fonte pesa antes da data de entrega). Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento, tipo_contato, contato) (a data de atualização da fonte pesa antes da data de entrega). SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_alfa.devedores_enderecos`

Endereços do provedor alfa, uma linha por (documento, endereço padronizado), tirada de `devedores_historico`. Considera todas as versões da histórica, não só a atual: um endereço que saiu da versão mais recente continua registrado. O endereço é o conjunto das partes padronizadas, e o texto original não entra na identidade (só se todas as partes forem `NULL`). Só existe linha para endereço que veio preenchido. A versão sem documento entra com `documento` `NULL`, deduplicada só pelo endereço e nunca junta a um documento válido. Com a primeira e a última data de entrega em que o par apareceu.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | Documento do devedor, como em `silver_alfa.devedores`. `NULL` nos endereços de linhas de documento vazio ou zerado, que não são devedor: nesse caso o endereço é único entre as linhas sem documento. |
| `hash_endereco` | `VARCHAR` | Identidade do endereço, criada na silver: `MD5` das partes padronizadas (`logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `uf`, `cep`) pela macro `hash_conteudo`, sem o documento, para a gold achar o mesmo endereço em documentos diferentes. O texto original só entra quando todas as partes são `NULL`. Igual nas três fontes para as mesmas partes (o hash não é portável entre DuckDB e PostgreSQL, não verificado). |
| `endereco` | `VARCHAR` | Endereço em texto da versão de maior `ordem_versao` que contém o par (a data de atualização da fonte pesa antes da data de entrega), aparado nas pontas. Não entra na identidade do endereço. Texto livre em maiúscula (H4). |
| `logradouro` | `VARCHAR` | Logradouro, só quando o endereço em texto casa com o padrão; senão `NULL`, como as outras partes. Texto livre em maiúscula (H4). |
| `numero` | `VARCHAR` | Número do endereço (pode ser `S/N`); `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `complemento` | `VARCHAR` | Complemento do endereço; `NULL` quando não há ou o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `bairro` | `VARCHAR` | Bairro; `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `cidade` | `VARCHAR` | Cidade; `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `uf` | `VARCHAR` | Sigla da UF em maiúsculas e sem espaços nas pontas. Valor fora das 27 UFs vira `NULL`; `NULL` também quando vazio. |
| `cep` | `VARCHAR` | CEP só com dígitos, com o zero à esquerda reposto até 8 posições. |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que o par apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que o par apareceu. |
| `_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da versão de maior `ordem_versao` que contém o par (documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_alfa.devedores_historico`

Todas as versões dos registros do provedor alfa, uma linha por versão. Versão é o mesmo conteúdo padronizado (documento incluído, listas incluídas), sem contar `_arquivo`, `_linha`, `_hash_arquivo` e `data_entrega`; a data de atualização da fonte é conteúdo, e NULL é igual a NULL. O conteúdo igual colapsa onde quer que apareça, e a ordem dos elementos de uma lista não cria versão. Entram as linhas sem documento (`documento` NULL). Fica de fora a linha que repete o cabeçalho do próprio arquivo, que continua na bronze (teste `cabecalho_repetido_fora_da_historica`, `warn`). As colunas de negócio são as de `devedores`; as listas viram tabelas filhas por versão ou colunas.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | Documento do devedor, como em `silver_alfa.devedores`. `NULL` nas versões de linhas de documento vazio ou zerado, que não identificam ninguém e estão aqui para a gold e para os contatos delas. |
| `nome_completo` | `VARCHAR` | Nome do devedor, sem espaços nas pontas; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `data_nascimento` | `DATE` | Data de nascimento. A data sentinela 1900-01-01 da origem fica como veio. |
| `cnpj_empregador` | `VARCHAR` | CNPJ do empregador, padronizado para 14 caracteres alfanuméricos. Regra (macro `cnpj_normalizado`): só letras e dígitos, em maiúsculas. Com 14 caracteres, fica como veio. Com menos, completa com zeros à esquerda se o resultado tiver dígitos verificadores válidos; com 12 caracteres e sem essa possibilidade, calcula os dois dígitos pela regra oficial da Receita. O que não encaixa fica como veio (limitação da base, teste `cnpj_do_empregador_fora_da_regra`). Todo valor de 14 caracteres tem dígitos verificadores válidos (teste `cnpj_do_empregador_com_digito_verificador_valido`). `NULL` quando o provedor não informou. |
| `cargo` | `VARCHAR` | Cargo do devedor; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `salario_informado` | `DECIMAL(14,2)` | Salário informado em `NUMERIC(14, 2)`. `NULL` quando vazio; o zero informado pelo provedor fica 0.00. |
| `telefone` | `VARCHAR` | Telefone da versão mais recente, só dígitos, DDD + número, sem o código do país. |
| `email` | `VARCHAR` | E-mail da versão mais recente, em minúsculas; `NULL` quando vazio. |
| `endereco` | `VARCHAR` | Endereço em texto, aparado nas pontas. Texto livre em maiúscula (H4). |
| `logradouro` | `VARCHAR` | Logradouro, só quando `endereco` casa inteiro com `logradouro, numero[, complemento] - bairro - cidade`; senão `NULL`, como todas as outras partes. Texto livre em maiúscula (H4). |
| `numero` | `VARCHAR` | Número do endereço (pode ser `S/N`); `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `complemento` | `VARCHAR` | Complemento do endereço; `NULL` quando não há ou o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `bairro` | `VARCHAR` | Bairro; `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `cidade` | `VARCHAR` | Cidade; `NULL` quando o endereço não casa com o padrão. Texto livre em maiúscula (H4). |
| `cep` | `VARCHAR` | CEP só com dígitos, com o zero à esquerda reposto até 8 posições. |
| `uf` | `VARCHAR` | Sigla da UF em maiúsculas e sem espaços nas pontas. Valor fora das 27 UFs (a origem manda `XX`) vira `NULL`; `NULL` também quando vazio. |
| `data_atualizacao` | `DATE` | Data de atualização do registro informada pelo provedor, usada para escolher a versão. |
| `hash_conteudo` | `VARCHAR` | Chave da versão: `MD5` do conteúdo padronizado da linha (colunas acima, com o documento) mais a assinatura ordenada de cada lista. Duas linhas com o mesmo conteúdo têm o mesmo hash, onde quer que apareçam; `data_entrega` e a rastreabilidade não entram. Chave da tabela. O texto que o `CAST` gera para o hash pode diferir entre DuckDB e PostgreSQL, então a chave não é portável entre os motores (não verificado). |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que a versão apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que a versão apareceu. |
| `_arquivo` | `VARCHAR` | Da aparição mais recente da versão. Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da aparição mais recente da versão. Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da aparição mais recente da versão. SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_beta.devedores`

Devedores do provedor beta, uma linha por (tipo de documento, documento normalizado), tirada de `devedores_historico`. Vale a versão mais recente: maior data de atualização da fonte, depois maior data de entrega, depois maior arquivo (nome) e maior linha. O CPF fica só com dígitos, com os zeros repostos até 11 posições. O RG (`documento.tipo` igual a RG) não vira CPF: fica só com letras e dígitos, sem zeros repostos, e a chave inclui o tipo, para um RG nunca se confundir com um CPF de mesmo número. Documento vazio ou só com zeros (`0`, `000.000.000-00`) não identifica ninguém: a linha não vira devedor (fica fora antes de escolher a versão) e continua na bronze, e os contatos dela estão em `devedores_contatos` com `documento` NULL. Linha com JSON inválido também fica fora e continua na bronze (teste `warn`). Nenhuma coluna recebe marcação interpretativa: a data 2025-09-01 e as rendas `0,00` passam como vieram. Os telefones, e-mails e endereços estão em `devedores_contatos` e `devedores_enderecos`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento_tipo` | `VARCHAR` | Tipo do documento: `CPF` quando o JSON traz `cpf` ou `documento.tipo` CPF, `RG` quando traz `documento.tipo` RG. Parte da chave da tabela. |
| `documento` | `VARCHAR` | Número do documento sem máscara. CPF: só dígitos, com zeros à esquerda repostos até 11 posições. RG: letras maiúsculas e dígitos, como veio. Parte da chave da tabela. |
| `nome_completo` | `VARCHAR` | Nome do devedor, sem espaços nas pontas. Vem de `nome_completo`, `nome` ou `nome_devedor` do JSON, a primeira preenchida (o nome fixo é `nome_completo`, o mesmo do alfa). Os nomes passam como vieram, sem correção de caracteres (U+FFFD: 0 ocorrências nos 92 arquivos, medido em 2026-11-09). Texto livre em maiúscula (H4). |
| `data_nascimento` | `DATE` | Data de nascimento (ISO ou dd/mm/aaaa na origem); `NULL` quando vazia ou inexistente no calendário. |
| `vinculo_empresa_cnpj` | `VARCHAR` | CNPJ do empregador (`vinculo_empresa.cnpj`), padronizado para 14 caracteres alfanuméricos. Regra (macro `cnpj_normalizado`): só letras e dígitos, em maiúsculas. Com 14 caracteres, fica como veio. Com menos, completa com zeros à esquerda se o resultado tiver dígitos verificadores válidos; com 12 caracteres e sem essa possibilidade, calcula os dois dígitos pela regra oficial da Receita. O que não encaixa fica como veio (limitação da base, teste `cnpj_do_empregador_fora_da_regra`). Todo valor de 14 caracteres tem dígitos verificadores válidos (teste `cnpj_do_empregador_com_digito_verificador_valido`). `NULL` quando o provedor não informou vínculo. |
| `vinculo_empresa_desde` | `DATE` | Mês de início do vínculo com o empregador (`vinculo_empresa.desde`). O valor é o MÊS do vínculo: a origem manda `AAAA-MM`, sem dia, e o DATE mostra o dia 01 só porque o tipo exige um dia; ele não diz que o vínculo começou no dia 1. `NULL` quando o provedor não informou ou mandou fora do formato `AAAA-MM` (teste `beta_vinculo_desde_fora_do_formato`). |
| `renda_mensal` | `DECIMAL(14,2)` | Renda mensal em `NUMERIC(14, 2)`, vinda de número ou de texto "R$ x,xx". `NULL` quando a origem é nula; o zero informado pelo provedor fica 0.00. |
| `atualizado_em` | `DATE` | Data de atualização do registro informada pelo provedor, com o nome do campo da origem (`atualizado_em`, ISO 8601 ou epoch em milissegundos, este no fuso do Brasil), usada para escolher a versão. |
| `data_entrega` | `DATE` | Data da entrega do arquivo de onde veio a versão: a data escrita no nome do arquivo ou, só no arquivo histórico configurado, a variável `data_carga_historica` (2026-08-31, enunciado p. 1). `NULL` em entrega diária sem data válida no nome, o que reprova o teste `entrega_diaria_sem_data_valida`. |
| `hash_conteudo` | `VARCHAR` | Chave da versão atual na histórica (`silver_beta.devedores_historico`): liga o devedor ao conteúdo de que ele saiu. |
| `_arquivo` | `VARCHAR` | Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_beta.devedores_contatos`

Histórico de contatos do provedor beta, uma linha por (tipo de documento, documento, tipo_contato, contato normalizado), tirado de `devedores_historico` e `devedores_historico_contatos`. Considera todas as linhas da bronze com documento, não só a versão atual do devedor: um telefone ou e-mail que saiu da versão mais recente continua registrado, com a última data de entrega em que apareceu. Só existe linha para contato que veio preenchido. Telefone vem da lista `contato.telefones` (texto ou objeto com `ddd` e `numero`, que são concatenados); e-mail vem da lista `contato.emails` ou do texto `contato.email`. O tipo do telefone e o `principal` são do provedor e vêm da versão de maior `ordem_versao` que contém o par (a data de atualização da fonte pesa antes da data de entrega).

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento_tipo` | `VARCHAR` | Tipo do documento, como em `silver_beta.devedores`. `NULL` quando `documento` é `NULL`. |
| `documento` | `VARCHAR` | Documento do devedor, como em `silver_beta.devedores`. `NULL` nos contatos de linhas de documento vazio ou zerado, que não são devedor: nesse caso o par (`tipo_contato`, `contato`) é único entre as linhas sem documento. |
| `tipo_contato` | `VARCHAR` | Tipo do contato, criado na silver: `telefone` ou `email`. |
| `contato` | `VARCHAR` | Telefone (só dígitos, DDD + número, sem o código do país) ou e-mail (minúsculas), conforme `tipo_contato`. |
| `tipo` | `VARCHAR` | Campo `tipo` do telefone informado pelo provedor (`celular` ou `fixo`) na versão de maior `ordem_versao` que contém o par. `NULL` para e-mail e para telefone que o provedor escreveu como texto. |
| `principal` | `BOOLEAN` | Se o provedor marcou o telefone como principal, na versão de maior `ordem_versao` que contém o par. `NULL` para e-mail e para telefone escrito como texto. |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que o contato apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que o contato apareceu. |
| `_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (a data de atualização da fonte pesa antes da data de entrega). Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da versão de maior `ordem_versao` que contém o par (a data de atualização da fonte pesa antes da data de entrega). Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (a data de atualização da fonte pesa antes da data de entrega). SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_beta.devedores_enderecos`

Endereços do provedor beta, uma linha por (tipo de documento, documento, endereço padronizado), tirada de `devedores_historico` e `devedores_historico_enderecos`. Considera todas as versões, não só a atual: um endereço que saiu da versão mais recente continua registrado. O endereço é o conjunto das partes padronizadas; a posição na lista não entra na identidade. O provedor manda uma lista (`enderecos`) ou um objeto só (`endereco`). O `tipo` e o `atual` são da versão de maior `ordem_versao` que contém o par e ficam como vieram: nenhuma regra escolhe o endereço vigente nesta camada. A versão sem documento entra com `documento_tipo` e `documento` `NULL`, deduplicada só pelo endereço e nunca junta a um documento válido.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento_tipo` | `VARCHAR` | Tipo do documento, como em `silver_beta.devedores`. `NULL` nas versões sem documento. |
| `documento` | `VARCHAR` | Documento do devedor, como em `silver_beta.devedores`. `NULL` nas versões sem documento. |
| `hash_endereco` | `VARCHAR` | Identidade do endereço, criada na silver: `MD5` das partes padronizadas (`logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `uf`, `cep`) pela macro `hash_conteudo`, sem o documento, para a gold achar o mesmo endereço em documentos diferentes. O texto original só entra quando todas as partes são `NULL`. Igual nas três fontes para as mesmas partes (o hash não é portável entre DuckDB e PostgreSQL, não verificado). |
| `tipo` | `VARCHAR` | Tipo do endereço informado pelo provedor (por exemplo `residencial`) na versão de maior `ordem_versao` que contém o par; `NULL` quando vazio. |
| `logradouro` | `VARCHAR` | Logradouro, sem espaços nas pontas; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `numero` | `VARCHAR` | Número do endereço (pode ser `S/N`); `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `complemento` | `VARCHAR` | Complemento; `NULL` quando o provedor mandou nulo ou vazio. Texto livre em maiúscula (H4). |
| `bairro` | `VARCHAR` | Bairro; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `cidade` | `VARCHAR` | Cidade; `NULL` quando vazia. Texto livre em maiúscula (H4). |
| `uf` | `VARCHAR` | Sigla da UF em maiúsculas e sem espaços nas pontas. Valor fora das 27 UFs vira `NULL`; `NULL` também quando vazio. |
| `cep` | `VARCHAR` | CEP só com dígitos, com o zero à esquerda reposto até 8 posições. |
| `atual` | `BOOLEAN` | Marcação `atual` do provedor na versão de maior `ordem_versao` que contém o par, como veio (verdadeiro ou falso); `NULL` quando o provedor não a enviou. Não escolhe o endereço vigente: isso é regra da gold. |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que o par apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que o par apareceu. |
| `_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento_tipo, documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da versão de maior `ordem_versao` que contém o par (documento_tipo, documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento_tipo, documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_beta.devedores_historico`

Todas as versões dos registros do provedor beta, uma linha por versão. Versão é o mesmo conteúdo padronizado (documento incluído, listas incluídas), sem contar `_arquivo`, `_linha`, `_hash_arquivo` e `data_entrega`; a data de atualização da fonte é conteúdo, e NULL é igual a NULL. O conteúdo igual colapsa onde quer que apareça, e a ordem dos elementos de uma lista não cria versão. Entram as linhas sem documento (`documento` NULL). Fica de fora a linha que repete o cabeçalho do próprio arquivo, que continua na bronze (teste `cabecalho_repetido_fora_da_historica`, `warn`). As colunas de negócio são as de `devedores`; as listas viram tabelas filhas por versão ou colunas. Os contatos estão em `devedores_historico_contatos` e os endereços em `devedores_historico_enderecos`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento_tipo` | `VARCHAR` | Tipo do documento: `CPF` quando o JSON traz `cpf` ou `documento.tipo` CPF, `RG` quando traz `documento.tipo` RG. `NULL` quando `documento` é `NULL`. |
| `documento` | `VARCHAR` | Número do documento sem máscara, como em `silver_beta.devedores`. `NULL` nas versões de linhas de documento vazio ou zerado. |
| `nome_completo` | `VARCHAR` | Nome do devedor, sem espaços nas pontas. Vem de `nome_completo`, `nome` ou `nome_devedor` do JSON, a primeira preenchida (o nome fixo é `nome_completo`, o mesmo do alfa). Os nomes passam como vieram, sem correção de caracteres (U+FFFD: 0 ocorrências nos 92 arquivos, medido em 2026-11-09). Texto livre em maiúscula (H4). |
| `data_nascimento` | `DATE` | Data de nascimento (ISO ou dd/mm/aaaa na origem); `NULL` quando vazia ou inexistente no calendário. |
| `vinculo_empresa_cnpj` | `VARCHAR` | CNPJ do empregador (`vinculo_empresa.cnpj`), padronizado para 14 caracteres alfanuméricos. Regra (macro `cnpj_normalizado`): só letras e dígitos, em maiúsculas. Com 14 caracteres, fica como veio. Com menos, completa com zeros à esquerda se o resultado tiver dígitos verificadores válidos; com 12 caracteres e sem essa possibilidade, calcula os dois dígitos pela regra oficial da Receita. O que não encaixa fica como veio (limitação da base, teste `cnpj_do_empregador_fora_da_regra`). Todo valor de 14 caracteres tem dígitos verificadores válidos (teste `cnpj_do_empregador_com_digito_verificador_valido`). `NULL` quando o provedor não informou vínculo. |
| `vinculo_empresa_desde` | `DATE` | Mês de início do vínculo com o empregador (`vinculo_empresa.desde`). O valor é o MÊS do vínculo: a origem manda `AAAA-MM`, sem dia, e o DATE mostra o dia 01 só porque o tipo exige um dia; ele não diz que o vínculo começou no dia 1. `NULL` quando o provedor não informou ou mandou fora do formato `AAAA-MM` (teste `beta_vinculo_desde_fora_do_formato`). |
| `renda_mensal` | `DECIMAL(14,2)` | Renda mensal em `NUMERIC(14, 2)`, vinda de número ou de texto "R$ x,xx". `NULL` quando a origem é nula; o zero informado pelo provedor fica 0.00. |
| `atualizado_em` | `DATE` | Data de atualização do registro informada pelo provedor, com o nome do campo da origem (`atualizado_em`, ISO 8601 ou epoch em milissegundos, este no fuso do Brasil), usada para escolher a versão. |
| `hash_conteudo` | `VARCHAR` | Chave da versão: `MD5` do conteúdo padronizado da linha (colunas acima, com o documento) mais a assinatura ordenada de cada lista. Duas linhas com o mesmo conteúdo têm o mesmo hash, onde quer que apareçam; `data_entrega` e a rastreabilidade não entram. Chave da tabela. O texto que o `CAST` gera para o hash pode diferir entre DuckDB e PostgreSQL, então a chave não é portável entre os motores (não verificado). |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que a versão apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que a versão apareceu. |
| `_arquivo` | `VARCHAR` | Da aparição mais recente da versão. Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da aparição mais recente da versão. Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da aparição mais recente da versão. SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_beta.devedores_historico_contatos`

Contatos de cada versão do beta, uma linha por (versão, tipo_contato, contato normalizado), tirados da linha da aparição mais recente da versão. Telefone vem de `contato.telefones` (texto ou objeto com `ddd` e `numero`), e-mail de `contato.emails` ou de `contato.email`. O tipo do telefone e o `principal` são do provedor.

| Coluna | Tipo | Descrição |
|---|---|---|
| `hash_conteudo` | `VARCHAR` | Versão do devedor a que o item pertence, como em `devedores_historico`. |
| `tipo_contato` | `VARCHAR` | Tipo do contato, criado na silver: `telefone` ou `email`. |
| `contato` | `VARCHAR` | Telefone (só dígitos, DDD + número, sem o código do país) ou e-mail (minúsculas), conforme `tipo_contato`. |
| `tipo` | `VARCHAR` | Campo `tipo` do telefone informado pelo provedor (`celular` ou `fixo`). `NULL` para e-mail e para telefone escrito como texto. |
| `principal` | `BOOLEAN` | Se o provedor marcou o telefone como principal. `NULL` para e-mail e para telefone escrito como texto. |
| `posicao` | `INTEGER` | Posição do item na lista da linha recebida (1, 2, ...); 1 para o e-mail ou endereço que veio como valor único. |
| `_arquivo` | `VARCHAR` | Da aparição mais recente da versão. Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da aparição mais recente da versão. Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da aparição mais recente da versão. SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_beta.devedores_historico_enderecos`

Endereços de cada versão do beta, uma linha por (versão, posição na lista), tirados da linha da aparição mais recente da versão e já padronizados. O provedor manda uma lista (`enderecos`) ou um objeto só (`endereco`); o objeto vira a posição 1. O `atual` fica como veio: nenhuma regra escolhe o endereço vigente nesta camada.

| Coluna | Tipo | Descrição |
|---|---|---|
| `hash_conteudo` | `VARCHAR` | Versão do devedor a que o item pertence, como em `devedores_historico`. |
| `posicao` | `INTEGER` | Posição do endereço na lista da versão (1, 2, ...); 1 para o objeto único. |
| `tipo` | `VARCHAR` | Tipo do endereço informado pelo provedor (por exemplo `residencial`); `NULL` quando vazio. |
| `logradouro` | `VARCHAR` | Logradouro, sem espaços nas pontas; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `numero` | `VARCHAR` | Número do endereço (pode ser `S/N`); `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `complemento` | `VARCHAR` | Complemento; `NULL` quando o provedor mandou nulo ou vazio. Texto livre em maiúscula (H4). |
| `bairro` | `VARCHAR` | Bairro; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `cidade` | `VARCHAR` | Cidade; `NULL` quando vazia. Texto livre em maiúscula (H4). |
| `uf` | `VARCHAR` | Sigla da UF em maiúsculas e sem espaços nas pontas. Valor fora das 27 UFs vira `NULL`; `NULL` também quando vazio. |
| `cep` | `VARCHAR` | CEP só com dígitos, com o zero à esquerda reposto até 8 posições. |
| `atual` | `BOOLEAN` | Marcação `atual` do provedor, como veio (verdadeiro ou falso); `NULL` quando o provedor não a enviou. Não escolhe o endereço vigente: isso é regra da gold. |
| `_arquivo` | `VARCHAR` | Da aparição mais recente da versão. Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da aparição mais recente da versão. Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da aparição mais recente da versão. SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_cobranca.contatos_realizados`

Tentativas de contato do time de Cobranças, uma linha por `contato_id`. O CPF e o destino saem normalizados (o destino conforme o canal: telefone para `ligacao`, `sms` e `whatsapp`, e-mail para `email`), e o texto original do destino fica em `destino_original`. Os provedores de origem não estão aqui: são uma lista e ficam em `contatos_realizados_provedores`. Fora ficam, e continuam na bronze, a linha ilegível e a sem `contato_id` (S9, avisado por teste `warn`).

| Coluna | Tipo | Descrição |
|---|---|---|
| `contato_id` | `VARCHAR` | Identificador do contato na origem, sem espaços nas pontas. Chave da tabela. |
| `cpf_alvo` | `VARCHAR` | CPF do devedor contatado, só com dígitos e com os zeros à esquerda repostos até 11 posições. `NULL` quando vazio. |
| `canal` | `VARCHAR` | Canal do contato, em minúsculas. |
| `destino_original` | `VARCHAR` | Telefone ou e-mail como veio da origem, sem nenhum tratamento. |
| `destino` | `VARCHAR` | Destino normalizado conforme o canal: telefone só com dígitos, DDD + número, sem o código do país, ou e-mail em minúsculas. `NULL` quando vazio ou quando o canal não é conhecido. |
| `data_hora` | `TIMESTAMP` | Instante do contato (sem fuso, como o provedor informa). `NULL` quando o texto não é um instante válido. |
| `resultado` | `VARCHAR` | Resultado do contato, como veio (sem espaços nas pontas). |
| `_arquivo` | `VARCHAR` | Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_cobranca.contatos_realizados_provedores`

Provedores de origem de cada tentativa de contato, uma linha por (`contato_id`, `provedor_origem`), abertos do texto `alfa\|beta\|gama`. Um contato que veio de mais de um provedor tem mais de uma linha. É o padrão de tabela ponte: não há uma coluna booleana por provedor, para que um provedor novo não mude o esquema.

| Coluna | Tipo | Descrição |
|---|---|---|
| `contato_id` | `VARCHAR` | Contato, como em `silver_cobranca.contatos_realizados`. |
| `provedor_origem` | `VARCHAR` | Provedor que informou o contato (um elemento do `provedor_origem` da origem), em minúsculas. |
| `_arquivo` | `VARCHAR` | Da linha do contato realizado que originou o par (contato, provedor_origem). Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da linha do contato realizado que originou o par (contato, provedor_origem). Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da linha do contato realizado que originou o par (contato, provedor_origem). SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_gama.devedores`

Devedores do provedor gama, uma linha por documento normalizado, tirada de `devedores_historico`. Vale a versão mais recente do documento: maior `dt_ref` (a data de atualização da fonte), depois maior data de entrega, depois maior arquivo (nome) e maior linha. Fora ficam, e continuam na bronze, a linha ilegível, o cabeçalho repetido dentro do histórico e o documento vazio ou só com zeros, que não identifica ninguém (S9); os contatos das linhas de documento vazio estão em `devedores_contatos` com `documento` NULL. O endereço vem em três formatos (colunas separadas, `rua` e `endereco`) e sai nas mesmas colunas; nos dois formatos de texto as partes só são separadas quando o texto casa inteiro com o padrão estrito, e o texto original fica em `endereco` (S7). Os `atributos_extra` viram colunas (S8). Nenhuma coluna recebe marcação interpretativa: datas sentinela e valores zero passam como vieram. Medição de `dt_ref` como data de atualização (2026-11-09, sobre as 19.505 linhas lidas): 19.504 viram data (a restante é o cabeçalho repetido, que não tem data); nenhuma é posterior à data de entrega do arquivo. Nas entregas diárias (9.505 linhas), 8.791 trazem exatamente a data de entrega e 714 trazem 1 a 3 dias antes (mediana 0). No histórico a data vai de 2025-01-27 a 2026-08, e 372 linhas trazem 2025-09-01, data que não aparece em nenhuma entrega diária. Com 5.391 documentos em mais de uma linha, ordenar por `dt_ref` escolhe outra linha que não a mais recente por entrega em 59 dos 11.436 documentos; tratar 2025-09-01 como ausente mudaria a escolha em 5 (consulta `analyses/medicao_ordenacao_devedores_gama.sql`; os 87 e 35 anteriores não se reproduzem). A regra da sentinela continua pendente de decisão do autor. Hoje `dt_ref` ordena porque nunca vem do futuro e acompanha a entrega nas diárias, e 2025-09-01 fica como veio (S8); quem trata essa data é a decisão pendente. A suposição de que `dt_ref` é a data de atualização do registro está no contrato do provedor.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | CPF só com dígitos, com os zeros à esquerda repostos até 11 posições. Chave da tabela. |
| `nome` | `VARCHAR` | Nome do devedor, sem espaços nas pontas; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `data_nascimento` | `DATE` | Data de nascimento, lida de `dd/mm/aaaa`. A data sentinela, se houver, fica como veio. |
| `cnpj_empregador_raw` | `VARCHAR` | CNPJ do empregador (campo `cnpj_empregador_raw` da origem), padronizado para 14 caracteres alfanuméricos. Regra (macro `cnpj_normalizado`): só letras e dígitos, em maiúsculas. Com 14 caracteres, fica como veio. Com menos, completa com zeros à esquerda se o resultado tiver dígitos verificadores válidos; com 12 caracteres e sem essa possibilidade, calcula os dois dígitos pela regra oficial da Receita. O que não encaixa fica como veio (limitação da base, teste `cnpj_do_empregador_fora_da_regra`). Todo valor de 14 caracteres tem dígitos verificadores válidos (teste `cnpj_do_empregador_com_digito_verificador_valido`). `NULL` quando o provedor não informou. |
| `atributos_extra_estado_civil` | `VARCHAR` | Estado civil de `atributos_extra`; `NULL` quando a chave não veio. |
| `atributos_extra_qtd_dependentes` | `INTEGER` | Quantidade de dependentes de `atributos_extra`; `NULL` quando a chave não veio, e o 0 informado fica 0. |
| `atributos_extra_score_externo` | `INTEGER` | Score de um birô externo, de `atributos_extra`; `NULL` quando a chave não veio. |
| `atributos_extra_escolaridade` | `VARCHAR` | Escolaridade de `atributos_extra`; `NULL` quando a chave não veio. |
| `atributos_extra_possui_imovel` | `BOOLEAN` | Se o devedor possui imóvel, de `atributos_extra`; `NULL` quando a chave não veio. |
| `atributos_extra_fonte_score` | `VARCHAR` | Birô de onde vem o `atributos_extra_score_externo`, de `atributos_extra`; `NULL` quando a chave não veio. |
| `endereco` | `VARCHAR` | Texto do endereço, nos formatos `rua` ("logradouro, numero") e `endereco` ("logradouro, numero - bairro"). `NULL` quando o endereço veio em colunas separadas. Texto livre em maiúscula (H4). |
| `logradouro` | `VARCHAR` | Logradouro: da coluna da origem ou, nos formatos de texto, do texto que casa com o padrão estrito; `NULL` quando não casa. Texto livre em maiúscula (H4). |
| `numero` | `VARCHAR` | Número do endereço (pode ser `S/N`), com a mesma regra do logradouro. Texto livre em maiúscula (H4). |
| `endereco_json_complemento` | `VARCHAR` | Complemento; só existe no formato de colunas separadas, e `NULL` quando não há. Texto livre em maiúscula (H4). |
| `bairro` | `VARCHAR` | Bairro: da coluna da origem ou, no formato `endereco`, do texto que casa com o padrão estrito; `NULL` no formato `rua`, que não traz bairro. Texto livre em maiúscula (H4). |
| `cidade` | `VARCHAR` | Cidade, de `cidade` ou `municipio` conforme o formato do endereço. Texto livre em maiúscula (H4). |
| `uf` | `VARCHAR` | Sigla da UF, de `uf` ou `estado` conforme o formato do endereço, em maiúsculas e sem espaços nas pontas. Valor fora das 27 UFs vira `NULL`; `NULL` também quando vazio. |
| `cep` | `VARCHAR` | CEP só com dígitos, com o zero à esquerda reposto até 8 posições (o provedor manda número em alguns formatos). |
| `dt_ref` | `DATE` | Data de referência do registro informada pelo provedor, com o nome do campo da origem, usada para escolher a versão. |
| `data_entrega` | `DATE` | Data da entrega do arquivo de onde veio a versão: a data escrita no nome do arquivo ou, só no arquivo histórico configurado, a variável `data_carga_historica` (2026-08-31, enunciado p. 1). `NULL` em entrega diária sem data válida no nome, o que reprova o teste `entrega_diaria_sem_data_valida`. |
| `hash_conteudo` | `VARCHAR` | Chave da versão atual na histórica (`silver_gama.devedores_historico`): liga o devedor ao conteúdo de que ele saiu. |
| `_arquivo` | `VARCHAR` | Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_gama.devedores_contatos`

Histórico de contatos do provedor gama, uma linha por (documento, tipo_contato, contato normalizado), aberto da lista `contatos` e tirado de `devedores_historico` e `devedores_historico_contatos`. Considera todas as linhas da bronze com documento, não só a versão atual do devedor: um telefone ou e-mail que saiu da versão mais recente continua registrado, com a última data de entrega em que apareceu. A linha com a lista truncada não tem contato legível e fica sem contatos aqui, embora o devedor entre em `devedores`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | Documento do devedor, como em `silver_gama.devedores`. `NULL` nos contatos de linhas de documento vazio ou zerado, que não são devedor: nesse caso o par (`tipo_contato`, `contato`) é único entre as linhas sem documento. |
| `tipo_contato` | `VARCHAR` | Tipo do contato, criado na silver: `telefone` (`celular` e `fixo` do provedor) ou `email`. |
| `contato` | `VARCHAR` | Telefone (só dígitos, DDD + número) ou e-mail (minúsculas), conforme `tipo_contato`. |
| `tipo` | `VARCHAR` | Campo `tipo` do telefone informado pelo provedor, `celular` ou `fixo`, na versão de maior `ordem_versao` que contém o par. `NULL` no e-mail. |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que o par apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que o par apareceu. |
| `_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento, tipo_contato, contato) (a data de atualização da fonte pesa antes da data de entrega). Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da versão de maior `ordem_versao` que contém o par (documento, tipo_contato, contato) (a data de atualização da fonte pesa antes da data de entrega). Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento, tipo_contato, contato) (a data de atualização da fonte pesa antes da data de entrega). SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_gama.devedores_enderecos`

Endereços do provedor gama, uma linha por (documento, endereço padronizado), tirada de `devedores_historico`. Considera todas as versões da histórica, não só a atual: um endereço que saiu da versão mais recente continua registrado. O endereço é o conjunto das partes padronizadas, e o texto original não entra na identidade (só se todas as partes forem `NULL`). Só existe linha para endereço que veio preenchido. A versão sem documento entra com `documento` `NULL`, deduplicada só pelo endereço e nunca junta a um documento válido. Com a primeira e a última data de entrega em que o par apareceu.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | Documento do devedor, como em `silver_gama.devedores`. `NULL` nos endereços de linhas de documento vazio ou zerado, que não são devedor: nesse caso o endereço é único entre as linhas sem documento. |
| `hash_endereco` | `VARCHAR` | Identidade do endereço, criada na silver: `MD5` das partes padronizadas (`logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `uf`, `cep`) pela macro `hash_conteudo`, sem o documento, para a gold achar o mesmo endereço em documentos diferentes. O texto original só entra quando todas as partes são `NULL`. Igual nas três fontes para as mesmas partes (o hash não é portável entre DuckDB e PostgreSQL, não verificado). |
| `endereco` | `VARCHAR` | Endereço em texto da versão de maior `ordem_versao` que contém o par (a data de atualização da fonte pesa antes da data de entrega), aparado nas pontas. Não entra na identidade do endereço. Texto livre em maiúscula (H4). |
| `logradouro` | `VARCHAR` | Logradouro, vindo do texto ou das colunas do layout; `NULL` quando não veio. Texto livre em maiúscula (H4). |
| `numero` | `VARCHAR` | Número do endereço (pode ser `S/N`); `NULL` quando não veio. Texto livre em maiúscula (H4). |
| `endereco_json_complemento` | `VARCHAR` | Complemento do endereço (`endereco_json_complemento` na histórica); `NULL` quando não há. Texto livre em maiúscula (H4). |
| `bairro` | `VARCHAR` | Bairro; `NULL` quando não veio. Texto livre em maiúscula (H4). |
| `cidade` | `VARCHAR` | Cidade; `NULL` quando não veio. Texto livre em maiúscula (H4). |
| `uf` | `VARCHAR` | Sigla da UF em maiúsculas e sem espaços nas pontas. Valor fora das 27 UFs vira `NULL`; `NULL` também quando vazio. |
| `cep` | `VARCHAR` | CEP só com dígitos, com o zero à esquerda reposto até 8 posições. |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que o par apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que o par apareceu. |
| `_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da versão de maior `ordem_versao` que contém o par (documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da versão de maior `ordem_versao` que contém o par (documento, endereço) (a data de atualização da fonte pesa antes da data de entrega). SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_gama.devedores_historico`

Todas as versões dos registros do provedor gama, uma linha por versão. Versão é o mesmo conteúdo padronizado (documento incluído, listas incluídas), sem contar `_arquivo`, `_linha`, `_hash_arquivo` e `data_entrega`; a data de atualização da fonte é conteúdo, e NULL é igual a NULL. O conteúdo igual colapsa onde quer que apareça, e a ordem dos elementos de uma lista não cria versão. Entram as linhas sem documento (`documento` NULL). Fica de fora a linha que repete o cabeçalho do próprio arquivo, que continua na bronze (teste `cabecalho_repetido_fora_da_historica`, `warn`). As colunas de negócio são as de `devedores`; as listas viram tabelas filhas por versão ou colunas. Os contatos estão em `devedores_historico_contatos`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `documento` | `VARCHAR` | Documento do devedor, como em `silver_gama.devedores`. `NULL` nas versões de linhas de documento vazio ou zerado, que não identificam ninguém e estão aqui para a gold e para os contatos delas. |
| `nome` | `VARCHAR` | Nome do devedor, sem espaços nas pontas; `NULL` quando vazio. Texto livre em maiúscula (H4). |
| `data_nascimento` | `DATE` | Data de nascimento, lida de `dd/mm/aaaa`. A data sentinela, se houver, fica como veio. |
| `cnpj_empregador_raw` | `VARCHAR` | CNPJ do empregador (campo `cnpj_empregador_raw` da origem), padronizado para 14 caracteres alfanuméricos. Regra (macro `cnpj_normalizado`): só letras e dígitos, em maiúsculas. Com 14 caracteres, fica como veio. Com menos, completa com zeros à esquerda se o resultado tiver dígitos verificadores válidos; com 12 caracteres e sem essa possibilidade, calcula os dois dígitos pela regra oficial da Receita. O que não encaixa fica como veio (limitação da base, teste `cnpj_do_empregador_fora_da_regra`). Todo valor de 14 caracteres tem dígitos verificadores válidos (teste `cnpj_do_empregador_com_digito_verificador_valido`). `NULL` quando o provedor não informou. |
| `atributos_extra_estado_civil` | `VARCHAR` | Estado civil de `atributos_extra`; `NULL` quando a chave não veio. |
| `atributos_extra_qtd_dependentes` | `INTEGER` | Quantidade de dependentes de `atributos_extra`; `NULL` quando a chave não veio, e o 0 informado fica 0. |
| `atributos_extra_score_externo` | `INTEGER` | Score de um birô externo, de `atributos_extra`; `NULL` quando a chave não veio. |
| `atributos_extra_escolaridade` | `VARCHAR` | Escolaridade de `atributos_extra`; `NULL` quando a chave não veio. |
| `atributos_extra_possui_imovel` | `BOOLEAN` | Se o devedor possui imóvel, de `atributos_extra`; `NULL` quando a chave não veio. |
| `atributos_extra_fonte_score` | `VARCHAR` | Birô de onde vem o `atributos_extra_score_externo`, de `atributos_extra`; `NULL` quando a chave não veio. |
| `endereco` | `VARCHAR` | Texto do endereço, nos formatos `rua` ("logradouro, numero") e `endereco` ("logradouro, numero - bairro"). `NULL` quando o endereço veio em colunas separadas. Texto livre em maiúscula (H4). |
| `logradouro` | `VARCHAR` | Logradouro: da coluna da origem ou, nos formatos de texto, do texto que casa com o padrão estrito; `NULL` quando não casa. Texto livre em maiúscula (H4). |
| `numero` | `VARCHAR` | Número do endereço (pode ser `S/N`), com a mesma regra do logradouro. Texto livre em maiúscula (H4). |
| `endereco_json_complemento` | `VARCHAR` | Complemento; só existe no formato de colunas separadas, e `NULL` quando não há. Texto livre em maiúscula (H4). |
| `bairro` | `VARCHAR` | Bairro: da coluna da origem ou, no formato `endereco`, do texto que casa com o padrão estrito; `NULL` no formato `rua`, que não traz bairro. Texto livre em maiúscula (H4). |
| `cidade` | `VARCHAR` | Cidade, de `cidade` ou `municipio` conforme o formato do endereço. Texto livre em maiúscula (H4). |
| `uf` | `VARCHAR` | Sigla da UF, de `uf` ou `estado` conforme o formato do endereço, em maiúsculas e sem espaços nas pontas. Valor fora das 27 UFs vira `NULL`; `NULL` também quando vazio. |
| `cep` | `VARCHAR` | CEP só com dígitos, com o zero à esquerda reposto até 8 posições (o provedor manda número em alguns formatos). |
| `dt_ref` | `DATE` | Data de referência do registro informada pelo provedor, com o nome do campo da origem, usada para escolher a versão. |
| `hash_conteudo` | `VARCHAR` | Chave da versão: `MD5` do conteúdo padronizado da linha (colunas acima, com o documento) mais a assinatura ordenada de cada lista. Duas linhas com o mesmo conteúdo têm o mesmo hash, onde quer que apareçam; `data_entrega` e a rastreabilidade não entram. Chave da tabela. O texto que o `CAST` gera para o hash pode diferir entre DuckDB e PostgreSQL, então a chave não é portável entre os motores (não verificado). |
| `data_primeira_entrega` | `DATE` | Menor data de entrega dos arquivos em que a versão apareceu. |
| `data_ultima_entrega` | `DATE` | Maior data de entrega dos arquivos em que a versão apareceu. |
| `_arquivo` | `VARCHAR` | Da aparição mais recente da versão. Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da aparição mais recente da versão. Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da aparição mais recente da versão. SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

### `silver_gama.devedores_historico_contatos`

Contatos de cada versão do gama, uma linha por (versão, tipo_contato, contato normalizado), tirados da linha da aparição mais recente da versão e abertos da lista `contatos`. A versão de linha com a lista truncada não tem contato legível e fica sem linhas aqui.

| Coluna | Tipo | Descrição |
|---|---|---|
| `hash_conteudo` | `VARCHAR` | Versão do devedor a que o item pertence, como em `devedores_historico`. |
| `tipo_contato` | `VARCHAR` | Tipo do contato, criado na silver: `telefone` (`celular` e `fixo` do provedor) ou `email`. |
| `contato` | `VARCHAR` | Telefone (só dígitos, DDD + número, sem o código do país) ou e-mail (minúsculas), conforme `tipo_contato`. |
| `tipo` | `VARCHAR` | Campo `tipo` do telefone informado pelo provedor, `celular` ou `fixo`. `NULL` no e-mail. |
| `posicao` | `INTEGER` | Posição do item na lista da linha recebida (1, 2, ...); 1 para o e-mail ou endereço que veio como valor único. |
| `_arquivo` | `VARCHAR` | Da aparição mais recente da versão. Caminho relativo do arquivo de origem, a partir da raiz do repositório. É o mesmo texto que a coluna `arquivo` do registro `arquivos`. |
| `_linha` | `BIGINT` | Da aparição mais recente da versão. Número da linha física do arquivo onde o registro começa (a primeira linha do arquivo é a 1, inclusive o cabeçalho do CSV). Com `_arquivo`, identifica a linha recebida. |
| `_hash_arquivo` | `VARCHAR` | Da aparição mais recente da versão. SHA-256 do conteúdo do arquivo de origem. Dois arquivos com o mesmo nome e conteúdo diferente (um reenvio) têm hashes diferentes. |

## Camada gold

### `gold_devedores.dim_contato`

Um contato normalizado de um devedor, com a régua de risco aplicada ao par (G4, G5). O contato de documento vazio ou de RG sem ligação fica numa linha com `sk_devedor` NULL e sempre bloqueado. Os sinais saem de `regua_sinais_do_par` e o nível e o motivo, de `regua_de_risco` (sem data de corte: a régua de operação). A lista de não-contatar é esta tabela com `nivel_risco = 'bloqueado'`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `sk_contato` | `INTEGER` | Chave substituta: a posição do par em ordem de CPF, documento, tipo e contato (G6). `INTEGER`, pelo mesmo motivo de `sk_endereco`. |
| `sk_devedor` | `INTEGER` | Devedor do contato. `NULL` quando o documento é vazio ou é um RG sem ligação. |
| `cpf` | `VARCHAR` | CPF do devedor, só dígitos. `NULL` quando o contato não tem devedor. |
| `tipo_contato` | `VARCHAR` | `telefone` ou `email`. |
| `contato` | `VARCHAR` | Telefone (DDD + número) ou e-mail em minúsculas, como a silver o normalizou. |
| `nivel_risco` | `VARCHAR` | `liberado` (mensagem de cobrança), `atencao` (contato sem expor a dívida) ou `bloqueado` (sem contato; lista de não-contatar). |
| `desc_motivo_risco` | `VARCHAR` | Motivo principal do nível pela prioridade falecido > opt_out > disse não ser o devedor > contato migrado > contato sem devedor > compartilhado > conflito de identidade > documento ligado > CPF inválido. Os demais motivos ficam visíveis nas colunas de sinal. |
| `situacao_documento` | `VARCHAR` | Por qual documento o contato chegou ao devedor, o melhor entre os que o trouxeram. |
| `documento_original` | `VARCHAR` | Documento como foi recebido, quando não é `cpf_valido` (CPF corrigido, RG ou CPF inválido). `NULL` quando o documento é o CPF válido do devedor ou está vazio. |
| `situacao_compartilhamento` | `VARCHAR` | `compartilhado` quando mais de um CPF tem o contato; `migrado` quando um CPF passou a tê-lo só depois da última entrega de outro; `exclusivo` nos demais. Vale para todos os pares do contato. |
| `tipo_alerta_historico` | `VARCHAR` | Alerta das tentativas, pela prioridade falecido > opt_out > nao_e_o_devedor: `falecido` em qualquer contato do devedor, `opt_out` em qualquer tentativa ao contato, `nao_e_o_devedor` (`numero_errado` ou `nao_conhece_devedor`) no par; `nenhum` sem alerta. |
| `situacao_entrega` | `VARCHAR` | `presente` quando algum provedor mandou o par na última entrega dele; `ausente` nos demais (ponto 7, só na régua de operação). Uma versão atual da gama com a lista cortada também aparece como `ausente`. |
| `qt_provedores` | `BIGINT` | Quantos provedores mandaram o par. `qt_provedores = 1` é o provedor único. |
| `qt_devedores_mesmo_contato` | `BIGINT` | Quantos CPFs têm o mesmo contato. 0 no contato sem devedor que nenhum CPF tem. |
| `qt_tentativas` | `BIGINT` | Tentativas da Cobrança ligadas ao par. |
| `qt_tentativas_terceiro` | `BIGINT` | Tentativas ligadas ao par com resultado `numero_errado` ou `nao_conhece_devedor`. |
| `dt_primeira_entrega` | `DATE` | Menor primeira entrega entre os provedores e documentos do par. |
| `dt_ultima_entrega` | `DATE` | Maior última entrega entre os provedores e documentos do par. |
| `dt_situacao_compartilhamento` | `DATE` | Quando o contato passou a `migrado` (primeira entrega do CPF que o recebeu) ou a `compartilhado` (primeira entrega do segundo CPF). `NULL` quando exclusivo. Informativa: a validação recalcula os sinais pela data de corte. |
| `dt_alerta_historico` | `DATE` | Data da primeira tentativa do alerta escolhido. `NULL` quando `tipo_alerta_historico` é `nenhum`. Informativa. |
| `_arquivo` | `VARCHAR` | Arquivo da aparição mais recente do par. |
| `_linha` | `BIGINT` | Linha do arquivo da mesma aparição. |
| `_hash_arquivo` | `VARCHAR` | Hash do arquivo da mesma aparição. |

### `gold_devedores.dim_devedor`

Uma linha por pessoa identificada por um CPF (G3a'). Os documentos ruidosos se ligam ao devedor quando a evidência é forte (ver `devedores_documentos`); o CPF inválido sem ligação tem linha própria com `situacao_cpf` `invalido`; RG sem ligação e documento vazio não são devedores. Os atributos seguem a G3b: um voto por provedor (a versão atual mais recente do provedor entre os documentos do devedor); nome pela maioria depois de resolver abreviações, empate pela forma mais recente e, entre grafias que só diferem no acento, a acentuada; nascimento pela maioria entre as datas confiáveis, com empate `NULL`; perfil só da gama. Sem rastreabilidade (ponto 8): a linha junta até três provedores, e a origem de cada atributo se acha nas tabelas filhas e na silver.

| Coluna | Tipo | Descrição |
|---|---|---|
| `sk_devedor` | `INTEGER` | Chave substituta: a posição do CPF em ordem crescente. Determinística porque o banco é recriado a cada execução, e não carrega o CPF (G6). |
| `cpf` | `VARCHAR` | CPF do devedor, só dígitos. Chave natural. Para `situacao_cpf` `invalido` é o CPF inválido como foi recebido. |
| `situacao_cpf` | `VARCHAR` | `valido` quando o dígito verificador confere; `invalido` quando não confere e o documento não se ligou a outro. |
| `tipo_conflito_cadastral` | `VARCHAR` | `identidade` quando o primeiro ou o último nome difere entre os provedores (G3c); `versao` quando algum documento do devedor tem duas versões diferentes no topo, com as mesmas datas e o mesmo arquivo (ponto 4); `identidade_e_versao` quando os dois ocorrem; `nenhum` caso contrário. Sinal para a régua; não muda os atributos. |
| `estado_civil` | `VARCHAR` | Estado civil, como a gama o mandou. `NULL` quando a gama não manda ou não informou. |
| `escolaridade` | `VARCHAR` | Escolaridade, como a gama a mandou. `NULL` quando a gama não manda ou não informou. |
| `fonte_score` | `VARCHAR` | Fonte do score externo, como a gama a mandou. `NULL` quando a gama não manda ou não informou. |
| `nome_devedor` | `VARCHAR` | Nome escolhido pela G3b. Texto em maiúscula, com acento quando algum provedor o mandou. |
| `qt_dependentes` | `INTEGER` | Quantidade de dependentes, da versão atual da gama. `NULL` quando a gama não manda ou não informou. |
| `score_externo` | `INTEGER` | Score externo, da versão atual da gama. `NULL` quando a gama não manda ou não informou. |
| `qt_provedores` | `BIGINT` | Quantos provedores (de 1 a 3) têm algum documento ligado a este devedor. |
| `qt_documentos_vinculados` | `BIGINT` | Quantos documentos distintos foram ligados a este devedor por correção de dígito ou por RG. |
| `flag_possui_imovel` | `BOOLEAN` | Atributo recebido da gama, e não sinal da régua. `NULL` quando a gama não manda ou não informou. |
| `dt_nascimento` | `DATE` | Data de nascimento pela maioria dos provedores, só entre datas confiáveis. `NULL` quando não há data confiável ou quando há empate, inclusive dia e mês trocados (ponto 9/b2: é a falta de um valor confiável, e não uma data recebida trocada). Tipo `DATE`: rejeita data inválida e filtra por período sem converter texto (0,004 s contra 0,076 s em 5 milhões de linhas). |

### `gold_devedores.dim_empregador`

Um CNPJ recebido de empregador, de todas as versões das três fontes, como a silver o padronizou, com os atributos da Receita (dados abertos de 2026-10) por `LEFT JOIN` pelo CNPJ de 14 caracteres. O CNPJ sem estabelecimento na Receita fica `nao_encontrado` e com os atributos `NULL`; nenhum empregador some nem ganha linha fictícia. A situação cadastral e o porte vêm do estabelecimento e da empresa que a Receita guarda; os três CNPJs alfanuméricos recebidos não estão na base de 2026-10.

| Coluna | Tipo | Descrição |
|---|---|---|
| `sk_empregador` | `INTEGER` | Chave substituta: a posição do CNPJ em ordem crescente (G6). |
| `cnpj` | `VARCHAR` | CNPJ de 14 caracteres como a silver o padronizou, inclusive o de dígito verificador inválido. Chave natural. |
| `_arquivo` | `VARCHAR` | Arquivo da aparição mais recente do CNPJ nos provedores (não é o arquivo da Receita). |
| `_linha` | `BIGINT` | Linha do arquivo da mesma aparição. |
| `_hash_arquivo` | `VARCHAR` | Hash do arquivo da mesma aparição. |

### `gold_devedores.dim_endereco`

Um devedor × um endereço padronizado distinto (G2c), de todas as versões e das três fontes. Endereço sem devedor (documento vazio ou RG sem ligação) mantém a linha com `sk_devedor` NULL. Dois endereços iguais em tudo menos no complemento se juntam quando um dos complementos é NULL e há um só complemento preenchido (ponto 5). `situacao_endereco` `atual` vem da versão vigente do devedor; os demais são `anterior`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `sk_endereco` | `INTEGER` | Chave substituta: a posição do endereço na ordem de devedor e das partes. Determinística (G6). `INTEGER` de 4 bytes: junta mais rápido que o `md5` da chave natural (0,204 s contra 0,279 s) e não é reversível a um documento. |
| `sk_devedor` | `INTEGER` | Devedor do endereço. `NULL` quando o documento é vazio ou é um RG sem ligação. |
| `tipo_endereco` | `VARCHAR` | Tipo do endereço como o beta o mandou. `NULL` para quem só vem de alfa ou gama. |
| `situacao_endereco` | `VARCHAR` | `atual` quando o endereço está na versão vigente do devedor; `anterior` nos demais. |
| `endereco` | `VARCHAR` | Texto original do endereço em maiúscula. `NULL` quando só o beta o mandou. |
| `logradouro` | `VARCHAR` | Logradouro padronizado. `NULL` quando a origem não permitiu separar. |
| `numero_endereco` | `VARCHAR` | Número do endereço, como texto. `NULL` quando não veio. |
| `complemento` | `VARCHAR` | Complemento. `NULL` quando não veio ou quando só houve variantes com complemento preenchido (ponto 5 mantém o preenchido). |
| `bairro` | `VARCHAR` | Bairro padronizado. `NULL` quando não veio. |
| `cidade` | `VARCHAR` | Cidade padronizada. `NULL` quando não veio. |
| `uf` | `VARCHAR` | UF de duas letras. `NULL` quando não é uma UF válida. |
| `cep` | `VARCHAR` | CEP de 8 dígitos. `NULL` quando não veio. |
| `qt_provedores` | `BIGINT` | Quantos provedores mandaram o endereço para o devedor. |
| `dt_primeira_entrega` | `DATE` | Menor primeira entrega entre as versões que têm o endereço. |
| `dt_ultima_entrega` | `DATE` | Maior última entrega entre as versões que têm o endereço. |
| `_arquivo` | `VARCHAR` | Arquivo da aparição mais recente do endereço, preferindo a do endereço preenchido. |
| `_linha` | `BIGINT` | Linha do arquivo da mesma aparição. |
| `_hash_arquivo` | `VARCHAR` | Hash do arquivo da mesma aparição. |

### `gold_devedores.ft_tentativa_contato`

Uma tentativa de contato (`contato_id`), as mesmas linhas da Cobrança. Liga-se ao par (CPF, contato) da `dim_contato`; sem o par, ao contato sem devedor de mesmo valor; sem nenhum dos dois, `sk_contato` fica NULL. `sk_devedor` vem do CPF da tentativa, com ou sem par. `tipo_desfecho` é a classe do resultado (G2b) e `situacao_horario` compara o horário com a janela única da G7.

| Coluna | Tipo | Descrição |
|---|---|---|
| `sk_devedor` | `INTEGER` | Devedor dono do CPF da tentativa, mesmo quando o contato dela não foi entregue por nenhum provedor. `NULL` só quando o alvo não é devedor da gold. |
| `sk_contato` | `INTEGER` | Par ou contato sem devedor a que a tentativa se liga. `NULL` quando nenhum existe nas entregas. |
| `contato_id` | `VARCHAR` | Identificador da tentativa na Cobrança. Chave. |
| `canal` | `VARCHAR` | Canal da tentativa. |
| `resultado` | `VARCHAR` | Resultado como a Cobrança o registrou. Um valor fora da lista reprova o teste. |
| `tipo_desfecho` | `VARCHAR` | Classe do resultado (G2b): `contato_confirmado`, `terceiro`, `opt_out`, `falecido` ou `sem_confirmacao`. |
| `situacao_horario` | `VARCHAR` | Janela única da G7: `permitido` (segunda a sexta 8h-20h, sábado 9h-14h), `fora_do_horario`, `domingo`, `feriado` (nacional) ou `nao_se_aplica` (e-mail). |
| `dt_tentativa` | `DATE` | Data da tentativa, em horário de Brasília. |
| `hr_tentativa` | `TIME` | Hora da tentativa, em horário de Brasília. |
| `_arquivo` | `VARCHAR` | Arquivo da Cobrança de onde veio a tentativa. |
| `_linha` | `BIGINT` | Linha do arquivo. |
| `_hash_arquivo` | `VARCHAR` | Hash do arquivo. |

### `gold_devedores.ft_vinculo_empresa`

Um período contínuo do mesmo conteúdo de vínculo (CNPJ, cargo, renda e mês de início), por documento e provedor (ponto 3). Um vínculo que volta depois de outro abre um período novo; conteúdo todo vazio não vira linha mas separa períodos. Sem data de fim. `situacao_vinculo` `atual` é o período que contém a versão vigente do devedor.

| Coluna | Tipo | Descrição |
|---|---|---|
| `sk_devedor` | `INTEGER` | Devedor do documento. `NULL` quando o documento é um RG sem ligação. |
| `sk_empregador` | `INTEGER` | Empregador do período. `NULL` quando o período não traz CNPJ. |
| `provedor` | `VARCHAR` | Provedor que mandou o vínculo (`alfa`, `beta` ou `gama`). |
| `situacao_vinculo` | `VARCHAR` | `atual` quando o período contém a versão vigente do devedor; `anterior` nos demais. |
| `cargo` | `VARCHAR` | Cargo em maiúscula. `NULL` para beta e gama, que não mandam, e quando o alfa não informou. |
| `vl_renda` | `DECIMAL(14,2)` | Renda ou salário informado. `NULL` quando não informado, inclusive o 0,00 do alfa (ponto 6). |
| `dt_inicio_vinculo` | `DATE` | Mês de início do vínculo (dia 01 por convenção), só do beta. `NULL` para alfa e gama. |
| `dt_atualizacao` | `DATE` | Maior data de atualização das versões do período, como veio. |
| `dt_primeira_entrega` | `DATE` | Menor primeira entrega das versões do período. |
| `dt_ultima_entrega` | `DATE` | Maior última entrega das versões do período. |
| `_arquivo` | `VARCHAR` | Arquivo da última versão do período. |
| `_linha` | `BIGINT` | Linha do arquivo da última versão do período. |
| `_hash_arquivo` | `VARCHAR` | Hash do arquivo da última versão do período. |
