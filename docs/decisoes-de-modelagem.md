# Decisões de modelagem: ingestão, silver e gold

Este documento registra como os dados recebidos chegam até a silver e por quê: as camadas, as fontes, a ingestão, a rastreabilidade e as regras da silver (seções 1 a 8). As decisões da gold (base única, régua de risco) estão na seção 9.

- **Base:** o enunciado (`.context/converted/case-tecnico-dados-cobranca.md`, citado pela página), as convenções do case no `AGENTS.md` e as fontes externas listadas na seção 4 e na seção 5.
- **Números:** medidos em 2026-11-09 sobre a carga completa (92 arquivos, 73.050 linhas recebidas); os da histórica de versões (seção 6), em 2026-11-09 e 2026-11-10. Cada número vem do corpo de um commit do tópico ou de uma consulta indicada aqui. Os dados são sintéticos (p. 2) e cobrem um mês de entregas diárias; nenhum número daqui vale como estimativa para dados reais.
- **O que não foi verificado** está reunido na seção 8.

O que se espera de cada provedor (nomes de coluna, formatos, valores sentinela) fica em [contratos-de-dados.md](contratos-de-dados.md).

## 1. Camadas

O banco tem três camadas: bronze, silver e gold. Não há pasta de pouso entre os arquivos recebidos e a bronze.

| Camada | Papel | Onde está o código |
|---|---|---|
| bronze | tudo o que foi recebido, como veio, uma linha por linha recebida | gravada pela ingestão (`ingestion/`); `models/bronze/` guarda só o contrato (fontes do dbt com descrição e testes) |
| silver | padroniza e deduplica cada fonte isoladamente | modelos dbt em `models/silver/<fonte>/` |
| gold | une as fontes, resolve conflitos, aplica a régua | `models/gold/<domínio>/` (seção 9) |

**Por que três e não quatro.** O enunciado avalia "a clareza da arquitetura das camadas (bronze, staging/silver, marts/gold)" (p. 3). A primeira versão deste tópico gravava um pouso em Parquet e expunha a bronze como view sobre ele. O pouso era uma cópia a mais dos mesmos bytes: `contact_data/` já é a zona bruta imutável, e o banco é recriado do zero a cada execução. A cópia não acrescentava informação, só um lugar a mais para manter. Ela foi descartada.

**Por que a ingestão grava a bronze.** A convenção do case diz que `ingestion/` faz a "leitura dos arquivos dos provedores, sem transformação" e que as transformações ficam em SQL em `models/` (AGENTS.md, convenções do case). Gravar o texto recebido numa tabela é leitura sem transformação. Já interpretar o JSON, converter tipos e deduplicar é transformação e fica na silver. Por isso `models/bronze/` não tem SQL: as tabelas são declaradas como fontes do dbt, com descrição e testes de integridade.

**Materialização.** As três camadas são tabelas (AGENTS.md, Stack). A bronze é gravada como tabela pela ingestão; a silver e a gold são `table` no `dbt_project.yml`. A base é o guia oficial do dbt, "How we structure our dbt projects", que na parte Marts diz que "storage is cheap and compute is expensive" (conferido na fonte em 2026-11-10). O mesmo guia recomenda view na staging, camada que corresponde à silver, por dois motivos: não ocupar espaço com modelos que ninguém consulta e ler sempre o dado mais novo. Nenhum dos dois vale aqui. O banco é recriado a cada execução, então a tabela nunca fica desatualizada. E a silver é consultada pela gold, pela régua e pelos 274 testes do dbt, que numa view refariam a leitura de JSON, as expressões regulares e a deduplicação a cada leitura.

| Medido em 2026-11-10 (mediana de 3 execuções) | Silver como view | Silver como tabela | Efêmeros também como tabela |
|---|---|---|---|
| Pipeline completa | 17,1 s | 15,4 s | 15,7 s |
| Leitura completa das relações da silver | 0,343 s | 0,007 s | 0,010 s |
| Tamanho do banco | — | 39,9 MB | 49,6 MB |

Os modelos efêmeros (`*_padronizados`) continuam efêmeros. Eles são etapas internas no grão da linha recebida, sem a deduplicação que define uma tabela da silver; como tabela, ficariam ao lado das tabelas da camada e poderiam ser consumidos pela gold como se fossem contrato. Também não trariam ganho: a pipeline ficou em 15,7 s contra 15,4 s, dentro do ruído das execuções (14,8 a 15,9 s), e o banco cresceria 24 %. Os datasets do schema `analises` ficam fora desta regra; a gold substituiu esses datasets por consultas em `analyses/`, que não são materializadas (seção 9.1).

## 2. Fontes: base única não é fonte única

Cada provedor é uma fonte (`alfa`, `beta`, `gama`), com schemas `bronze_<fonte>` e `silver_<fonte>`. O histórico de tentativas de contato é a fonte `cobranca`, porque não vem de um provedor: são as "tentativas de contato efetuadas durante setembro/2026" (p. 3).

O enunciado pede "uma base cadastral única e confiável" (p. 1) e descreve "três provedores diferentes, cada um no seu próprio formato" (p. 1). A base única é o resultado, e ela é construída na gold. Até a silver, cada provedor fica separado por dois motivos:

1. **Cada formato tem problemas próprios.** O alfa renomeia uma coluna no meio do mês, o beta tem 12 combinações de chaves JSON e a gama tem três layouts de endereço ([perfil-das-fontes.md](perfil-das-fontes.md)). Padronizar cada um no seu modelo deixa cada regra perto do problema que ela resolve.
2. **A procedência é um sinal de risco.** Na análise exploratória de 2026-11-08, um contato confirmado por 2 ou 3 provedores teve 1,1% de contato errado em 7.333 tentativas, contra 6,6% em 7.720 tentativas de contatos vistos por um só provedor ([perfil-das-fontes.md](perfil-das-fontes.md), "Sinais de risco de contato"). Fundir os provedores antes da gold apagaria esse sinal. O enunciado põe o risco de "contatar quem não deve" no centro do problema (p. 1).

A fonte externa citada para essa divisão é a arquitetura medalhão: a bronze é tipicamente só de acréscimo e guarda até os registros inválidos, a silver limpa, normaliza e deduplica, e os agregados de negócio ficam na gold (https://learn.microsoft.com/en-us/azure/databricks/lakehouse/medallion). O guia de estrutura do dbt separa a etapa que só renomeia e converte tipos, sem junções (https://docs.getdbt.com/best-practices/how-we-structure/2-staging), da etapa que muda o grão e pede teste de chave primária no modelo que mudou de grão (https://docs.getdbt.com/best-practices/how-we-structure/3-intermediate). Como o enunciado nomeia só "bronze, staging/silver, marts/gold" (p. 3), a silver deste projeto faz as duas etapas, sempre dentro de uma fonte só.

## 3. Ingestão

**A cada execução, a ingestão lê todos os arquivos e grava a bronze.** Não há modos de carga, chave nem manifesto persistente. O banco é recriado do zero, então reler tudo é o que garante o requisito de que "a execução da pipeline a partir do estado inicial deve produzir exatamente os mesmos resultados a cada rodada" (p. 2).

| Opção | Ganho | Custo |
|---|---|---|
| Reler tudo a cada execução (adotada) | execuções idênticas sem estado guardado; nenhum caso especial para reenvio ou arquivo atrasado | o tempo cresce com o histórico; hoje a pipeline completa leva cerca de 6,5 s |
| Pular arquivo já carregado (caminho e hash) | lê só o que é novo | exige estado persistente entre execuções e regras para reenvio e substituição |

Em produção, com volume que torne a releitura cara, a evolução é pular o arquivo já carregado pelo caminho e pelo hash. É o padrão dos carregadores consagrados: o Snowflake guarda metadados de carga por arquivo e pula o que já foi carregado, a menos que se use `FORCE = TRUE`, que pode duplicar linhas (https://docs.snowflake.com/en/user-guide/data-load-considerations-load). O Auto Loader do Databricks ingere cada arquivo uma vez, rastreado pelo caminho (https://docs.databricks.com/aws/en/ingestion/cloud-object-storage/auto-loader/faq). Um reenvio com outro nome (como `provedor_gama_2026-09-15_reenvio.csv`) é um arquivo novo nos dois casos. Quem resolve a duplicação é a deduplicação por chave da silver, e não a ingestão.

**Tabelas e volumes.** Uma linha por linha recebida, sem descarte:

| Tabela | Arquivos | Linhas |
|---|---|---|
| `bronze_alfa.devedores` | 30 | 19.476 |
| `bronze_beta.devedores` | 29 | 19.015 |
| `bronze_gama.devedores` | 32 | 19.506 (1 ilegível) |
| `bronze_cobranca.contatos_realizados` | 1 | 15.053 |

No CSV, as colunas são a união dos cabeçalhos de todos os arquivos da entidade, em texto. Por isso o alfa tem `cpf` e `documento`, e a que um arquivo não traz fica `NULL`. No JSON Lines, a coluna `registro` guarda o texto da linha.

**Ilegível** é só a linha que o leitor não consegue separar em colunas: um CSV malformado ou em branco. Ela entra com o texto original e o motivo em `_motivo_ilegivel`. O JSONL entra sempre como texto, e a validação do JSON fica na silver. Assim, as 15 linhas truncadas do beta estão na bronze e são contadas na silver (seção 5.8). Um byte fora do encoding interrompe a fonte, com o arquivo e a linha no erro, em vez de virar um caractere de substituição. Conferi em 2026-11-09 que os 92 arquivos decodificam em UTF-8 estrito.

**Configuração em vez de código.** O que é específico de cada fonte fica em `ingestion/fontes.yml`: formato, origem e a lista de locais. O histórico em `contact_data/` e as entregas em `contact_data/entregas_diarias/<provedor>/` vão para a mesma tabela. Um arquivo que case com duas entradas é erro, para nunca ser carregado duas vezes. Um formato novo é uma função `@leitor`, e uma origem nova, uma função `@conector`. Uma API grava a resposta como arquivo numa pasta versionada antes de ser lida, e daí em diante vale o mesmo leitor.

**Gravação em lote.** A ingestão grava cada tabela num único `INSERT` com `UNNEST` de uma lista por coluna. Medido contra um `INSERT` por linha numa base em memória, com a mediana de 7 execuções do lote e de 3 do linha a linha: de 53 a 74 vezes mais rápido nas quatro tabelas (alfa: 331 ms contra 19.938 ms). O `executemany` não foi medido (commit a69cc69).

## 4. Rastreabilidade

Toda tabela da bronze tem `_arquivo` (caminho relativo ao repositório), `_linha` (onde o registro começa no arquivo), `_hash_arquivo` (sha256 do arquivo), `_linha_original` e `_motivo_ilegivel`. Cada fonte tem um registro de cargas em `bronze_<fonte>.arquivos`: arquivo, entidade, hash, bytes, linhas e cabeçalho.

Toda tabela da silver carrega `_arquivo`, `_linha` e `_hash_arquivo`, e um teste exige as três em toda tabela da camada. A regra vem da seção "Stack" do AGENTS.md: a rastreabilidade de cada linha vem do arquivo, da linha e do hash de origem. Numa tabela em que cada linha vem de uma linha da bronze (`contatos_realizados`), são as colunas dessa linha. Numa tabela que agrega várias aparições, são as da aparição mais recente:
- em `devedores_historico`, a última linha da bronze em que a versão apareceu, escolhida pela mesma ordem da versão atual (seção 5.3);
- em `devedores`, as da versão vencedora, que vêm da histórica;
- nas filhas da histórica (`devedores_historico_contatos`, `devedores_historico_enderecos`), as da aparição mais recente da versão;
- em `devedores_contatos` e `devedores_enderecos`, as da aparição mais recente do par (documento, contato) ou (documento, endereço): a da versão com a maior ordem que contém o par.

Em `contatos_realizados_provedores`, são as da linha do contato realizado que originou o par (contato, provedor_origem).

Essas colunas seguem o padrão dos carregadores consagrados. Para cada linha, guarda-se a origem, a posição e uma chave do conteúdo. Para cada carga, um registro referenciado pelas linhas.

| Este projeto | Snowflake | Fivetran | Databricks | dlt | Airbyte |
|---|---|---|---|---|---|
| `_arquivo` | `METADATA$FILENAME` | `_file` | `_metadata.file_path` | via `_dlt_load_id` → `_dlt_loads` | — |
| `_linha` | `METADATA$FILE_ROW_NUMBER` | `_line` | — | — | — |
| `_hash_arquivo` | `METADATA$FILE_CONTENT_KEY` | — | — | — | — |
| `_linha_original` + `_motivo_ilegivel` | — | — | — | — | `_airbyte_meta.changes` (o que não coube no esquema) |
| `bronze_<fonte>.arquivos` | metadados de carga por arquivo (nome, tamanho, checksum) | — | checkpoint do Auto Loader (por caminho) | tabela `_dlt_loads` | — |
| **não adotado:** horário da carga | — | `_fivetran_synced` | — | `inserted_at` em `_dlt_loads` | `_airbyte_extracted_at` |
| **não adotado:** data de modificação do arquivo | — | `_modified` | `_metadata.file_modification_time` | — | — |
| **não adotado:** id que muda a cada carga | — | — | — | `load_id`, novo a cada execução | `_airbyte_raw_id` (UUID aleatório) |

"—" quer dizer que não encontrei equivalente nas páginas consultadas, e não que o produto não tenha um. Fontes, acessadas em 2026-11-09:
- Snowflake: https://docs.snowflake.com/en/user-guide/querying-metadata e https://docs.snowflake.com/en/user-guide/data-load-considerations-load
- Fivetran: https://fivetran.com/docs/connectors/files e https://fivetran.com/docs/core-concepts/system-columns-and-tables
- Databricks: https://docs.databricks.com/aws/en/ingestion/file-metadata-column e https://docs.databricks.com/aws/en/ingestion/cloud-object-storage/auto-loader/faq
- dlt: https://dlthub.com/docs/general-usage/destination-tables (cópia em `.context/raw/referencias/dlt/`, Apache 2.0)
- Airbyte: https://docs.airbyte.com/platform/understanding-airbyte/airbyte-metadata-fields

**Desvio consciente.** O projeto não guarda horário de execução, data de modificação do arquivo nem id aleatório. Os três mudam a cada execução, e duas execuções sobre os mesmos arquivos dariam tabelas diferentes, contra o requisito da p. 2. A rastreabilidade que eles dariam sai de outra forma:
- **quando chegou:** a data de entrega vem do nome do arquivo;
- **qual versão do arquivo:** o sha256 identifica o conteúdo;
- **qual linha:** `_arquivo` e `_linha` localizam o registro.

O teste `test_nenhuma_tabela_guarda_caminho_absoluto_nem_horario` e o teste de duas execuções idênticas (`test_duas_execucoes_geram_tabelas_identicas`) fiscalizam isso na ingestão.

## 5. Silver

### 5.1 O que a silver faz

A silver trabalha dentro de uma fonte só: tipos, limpeza, normalização, abertura de listas em linhas e deduplicação de cada tabela pela sua chave. O que cruza fontes ou carrega regra de negócio fica na gold. O enunciado avalia a "consistência no tratamento de deduplicações, conflitos cadastrais e dados incompletos ou ruidosos" (p. 3); a silver resolve a deduplicação dentro da fonte, e os conflitos entre fontes ficam para a gold.

| Tabela | Grão (chave) | Linhas |
|---|---|---|
| `silver_alfa.devedores_historico` | hash_conteudo (uma linha por versão) | 18.587 |
| `silver_alfa.devedores` | documento | 11.458 |
| `silver_alfa.devedores_contatos` | documento, tipo_contato, contato | 22.978 (11.970 telefones, 11.008 e-mails; 63 com documento `NULL`) |
| `silver_alfa.devedores_enderecos` | documento, hash_endereco | 14.945 (14.912 com documento, 33 com documento `NULL`) |
| `silver_beta.devedores_historico` | hash_conteudo | 17.861 |
| `silver_beta.devedores_historico_contatos` | hash_conteudo, tipo_contato, contato | 43.277 |
| `silver_beta.devedores_historico_enderecos` | hash_conteudo, posicao | 18.657 |
| `silver_beta.devedores` | documento_tipo, documento | 11.321 (11.279 CPF, 42 RG) |
| `silver_beta.devedores_contatos` | documento_tipo, documento, tipo_contato, contato | 28.701 (17.246 telefones, 11.455 e-mails; 96 com documento `NULL`) |
| `silver_beta.devedores_enderecos` | documento_tipo, documento, hash_endereco | 15.037 (14.994 com documento, 43 com documento `NULL`) |
| `silver_gama.devedores_historico` | hash_conteudo | 18.564 |
| `silver_gama.devedores_historico_contatos` | hash_conteudo, tipo_contato, contato | 45.311 |
| `silver_gama.devedores` | documento | 11.436 |
| `silver_gama.devedores_contatos` | documento, tipo_contato, contato | 29.936 (15.691 celulares, 2.466 fixos, 11.779 e-mails; 100 com documento `NULL`) |
| `silver_gama.devedores_enderecos` | documento, hash_endereco | 16.780 (16.739 com documento, 41 com documento `NULL`) |
| `silver_cobranca.contatos_realizados` | contato_id | 15.053 |
| `silver_cobranca.contatos_realizados_provedores` | contato_id, provedor_origem | 24.774 |

Toda tabela tem teste de chave primária (`unique` ou `combinacao_unica`), e as filhas da histórica têm `relationships` para ela. Um teste `*_linhas_representadas` falha se uma linha da bronze não estiver representada: o documento em `devedores` ou, na linha sem documento, os contatos dela em `devedores_contatos`; os endereços preenchidos dela em `devedores_enderecos` (mesmo `hash_endereco`); e uma versão em `devedores_historico` com os mesmos campos simples. Essa última conferência deixa as listas de fora: que os contatos e endereços de cada versão estão nas filhas é garantido pela construção e pelos testes unitários, não por um teste sobre os dados. O teste `cabecalho_fora_de_toda_historica` (severidade de erro) falha se o cabeçalho repetido entrar numa histórica. As contagens de `devedores`, `devedores_contatos` e das tabelas da cobrança são de 2026-11-09, depois da segunda revisão da silver, e não mudaram quando essas tabelas passaram a sair da histórica (seção 6.6). As da histórica, das filhas e dos pares de endereço são do commit cdbc2f9, com o texto em maiúscula da seção 6.4. Nas tabelas de pares, o `NULL` de `documento` é um valor da chave (seção 5.8).

### 5.2 Padronizar antes de deduplicar

Toda a padronização acontece numa etapa efêmera por fonte (`silver_<fonte>_devedores_padronizados`, que não vira tabela), antes de qualquer deduplicação. Deduplicar sobre o texto bruto trata como diferentes o mesmo CPF com e sem máscara, ou o mesmo telefone em formatos diferentes.

O exemplo medido é o alfa. Na fase de desenho, contei 3.279 pares (CPF, telefone) que só existiam em versões antigas do devedor. Essa contagem foi feita sobre o texto bruto e misturava formatos diferentes do mesmo número. Com o telefone normalizado, são 481 pares (commit 48507a8). A diferença é a razão desta regra.

As regras de formato ficam em macros (`macros/padronizacao/`), cada uma com teste singular em `tests/macros/`. Cada macro só ajusta o formato e devolve `NULL` para ausência. Nenhuma filtra linha nem decide regra de negócio; a validade do dígito verificador do CPF (`cpf_valido`) só informa.

### 5.3 Deduplicação pela chave de cada tabela

A deduplicação usa `ROW_NUMBER() OVER (PARTITION BY <chave> ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`, como pede a convenção do case para funções de janela. Ela acontece em dois pontos:
1. **Na histórica**, pela chave da versão (`PARTITION BY hash_conteudo`): as linhas com o mesmo conteúdo viram uma versão só, com a rastreabilidade da aparição mais recente. A primeira e a última entrega saem de um `GROUP BY` com `MIN` e `MAX`, porque a convenção do case só permite `ROW_NUMBER()` e `SUM()` em janela (seção 6).
2. **Em `devedores`**, sobre as versões da histórica (`PARTITION BY documento`, no beta `documento_tipo, documento`): vale a versão mais recente.

As duas usam a mesma ordem, escrita uma vez na macro `ordem_versao` (`macros/padronizacao/historico.sql`):

```
ORDER BY <data de atualização> DESC NULLS LAST, data_entrega DESC NULLS LAST, _arquivo COLLATE "C" DESC, _linha DESC
```

A linha sem documento não entra em `devedores`: o filtro `documento IS NOT NULL` vem antes do `ROW_NUMBER`, para os `NULL` não formarem um grupo (seção 5.8). Ela continua na histórica, com `documento` `NULL`.

- A data de atualização é a informada pelo provedor, com o nome que a fonte usa: `data_atualizacao` no alfa, `atualizado_em` no beta e `dt_ref` na gama (seção 5.9).
- `data_entrega` sai do nome do arquivo. O histórico não tem data no nome: só o arquivo configurado em `arquivo_historico` (nome exato) usa a variável `data_carga_historica: 2026-08-31`, a data em que o enunciado fixa a carga histórica (p. 1). Um arquivo diário sem data válida no nome fica com a data nula e o teste `entrega_diaria_sem_data_valida` reprova a pipeline.
- Em `devedores`, a data de entrega de cada versão é a última em que ela apareceu (`data_ultima_entrega`), e o arquivo e a linha são os dessa aparição.
- `_arquivo` e depois `_linha` desempatam: o original e o reenvio da mesma data (gama, 15/09) trazem a mesma linha, e sem o arquivo o vencedor era arbitrário. `COLLATE "C"` fixa a ordem do texto por bytes, igual no PostgreSQL e no DuckDB. O resultado é determinístico porque (documento, atualização, entrega, arquivo, linha) não tem empate. O `_linha DESC` final é uma convenção arbitrária, e a seção 6.5 mostra por quê.

**Por que a data de atualização vem antes da data de entrega.** Ordenar pela entrega antes da atualização escolhe outro vencedor em 0 dos 11.458 documentos do alfa, 1 dos 11.321 do beta e 1 dos 11.436 da gama (consulta abaixo). O caso do beta é um reenvio atrasado: uma entrega trouxe um registro atualizado um dia antes do que já tinha vindo numa entrega anterior (commit ddc2107). Com a atualização primeiro, um reenvio velho não substitui a versão mais nova.

Na gama, `dt_ref` foi medido antes de ser usado como data de atualização: nenhuma das 19.505 linhas lidas é posterior à data de entrega. Nas entregas diárias (9.505 linhas), 8.791 trazem a data de entrega e 714 trazem de 1 a 3 dias antes (commit d6bb9e4).

**Reenvio da gama de 15/09.** O original tem 85 linhas, e a última está cortada (1 linha ilegível); o reenvio traz o conteúdo completo. Como os dois têm a mesma data no nome, o desempate é o `_arquivo` (o reenvio, de nome maior, vence) e depois a linha. Medi em 2026-11-09, antes de pôr o `_arquivo` no desempate: 40 versões vencedoras vinham do original, e as 40 são idênticas, byte a byte, a uma linha do reenvio, então o desempate não muda o conteúdo. Depois dele, as 200 versões vencedoras de 15/09 vêm do reenvio.

### 5.4 A data 2025-09-01 (decidida: fica como veio na ordenação)

Cada provedor tem um grupo de cerca de 370 registros com data de atualização 01/09/2025, só nos arquivos históricos. Parece uma data padrão de migração, e não indica que o registro é recente ([perfil-das-fontes.md](perfil-das-fontes.md)). Medido: 376 linhas no alfa, 372 de 9.969 linhas no histórico do beta e 372 no histórico da gama, e nenhuma linha nas entregas diárias. Os testes `beta_data_20250901_so_no_historico` e `gama_data_20250901_so_no_historico` (severidade warn) avisam se isso mudar. O alfa não tem esse teste.

**Decisão do autor (2026-11-09):** a data fica como veio e entra na ordenação como qualquer outra (decisão S8: nenhuma marcação interpretativa na silver); quem a trata é a gold. A alternativa descartada era ordenar com a sentinela como data desconhecida, sem mudar nenhuma coluna. As medições abaixo mostram o que cada escolha custa.

**O que foi medido, e onde as medições divergem:**

| Medição (vencedor diferente do da regra do modelo, com `_arquivo DESC` no desempate) | Alfa | Beta | Gama |
|---|---|---|---|
| Documentos distintos | 11.458 | 11.321 | 11.436 |
| A sentinela 2025-09-01 é tratada como ausente (`NULL`, vai para o fim) | 5 | 2 | 5 |
| A entrega ordena antes da atualização | 0 | 1 | 1 |
| Só entrega, arquivo e linha (a atualização não entra) | 62 | 70 | 59 |

Reproduzido em 2026-11-09 (de novo depois da segunda revisão, só com linhas com documento) pelas consultas `analyses/medicao_ordenacao_devedores_alfa.sql`, `analyses/medicao_ordenacao_devedores_beta.sql` e `analyses/medicao_ordenacao_devedores_gama.sql` (`dbt show --select medicao_ordenacao_devedores_<fonte>`), uma por fonte, com a regra do modelo e o desempate por `_arquivo`.

**Números anteriores que não se reproduzem.** Os passos 4.4 e 4.6 (commit d6bb9e4) registraram 35 documentos da gama (e 0 do alfa) para a sentinela, e 87 da gama para "ordenar por `dt_ref` muda o vencedor frente à ordem só por entrega". Nenhum dos dois se reproduz: a medição da sentinela dá 5 no alfa, 2 no beta e 5 na gama, e a de "só entrega" dá 59 na gama. O 60 que apareceu numa refeita anterior vinha dos empates entre o original e o reenvio da gama de 15/09 (58 documentos), que o desempate pelo arquivo eliminou. A afirmação de que tratar a sentinela como ausente "não muda a escolha" também é falsa: muda em até 5 documentos por fonte.

O efeito é pequeno: no máximo 5 devedores por fonte mudariam de versão vencedora se a sentinela fosse tratada como ausente. Com a decisão acima, esses devedores ficam com a versão que a ordenação escolhe com a data como veio, e a gold decide o que fazer com o cohort.

Consulta (rodar com `dbt show --inline`, trocando `alfa` pela fonte; no beta a partição é `documento_tipo, documento`):

```sql
WITH tOrdens AS (
  SELECT
    documento
    , _arquivo
    , _linha
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY data_atualizacao DESC NULLS LAST, data_entrega DESC NULLS LAST, _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ordem_como_veio
    , ROW_NUMBER() OVER (
      PARTITION BY documento
      ORDER BY
        CASE WHEN CAST(data_atualizacao AS DATE) = DATE '2025-09-01' THEN NULL ELSE data_atualizacao END DESC NULLS LAST
        , data_entrega DESC NULLS LAST
        , _linha DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ordem_sentinela_ausente
  FROM {{ ref('silver_alfa_devedores_padronizados') }}
)

SELECT
  COUNT(*) AS vencedores_que_mudam
FROM tOrdens AS a
INNER JOIN tOrdens AS b
  ON a.documento = b.documento
WHERE 1 = 1
  AND a.ordem_como_veio = 1
  AND b.ordem_sentinela_ausente = 1
  AND (a._arquivo <> b._arquivo OR a._linha <> b._linha)
```

### 5.5 A histórica como base: `devedores`, `devedores_contatos` e `devedores_enderecos` saem dela

Por fonte, a base é `devedores_historico`: todas as versões de tudo o que foi recebido, inclusive as linhas sem documento (`documento` `NULL`). As listas viram tabelas filhas por versão. O alfa manda um telefone e um e-mail por linha, e eles ficam como colunas da histórica.

```
<fonte>_devedores_padronizados (efêmero, uma linha por linha recebida)
  └─ devedores_historico (uma linha por versão)
       ├─ devedores_historico_contatos  (beta, gama: versão × contato)
       ├─ devedores_historico_enderecos (beta: versão × posição na lista)
       ├─ devedores           (versão atual de cada documento)
       ├─ devedores_contatos  (documento × contato, todas as versões)
       └─ devedores_enderecos (documento × endereço, todas as versões)
```

| Tabela | O que é | Por que existe |
|---|---|---|
| `devedores_historico` | uma linha por versão; chave `hash_conteudo` | a gold precisa de todas as versões (seção 6.1) |
| `devedores_historico_contatos` | os contatos de cada versão (beta, gama) | as listas viram linhas na silver, e não JSON numa tabela que a gold lê |
| `devedores_historico_enderecos` | os endereços de cada versão (beta), com `posicao` e o `atual` como veio | idem; o objeto `endereco` único vira a posição 1 |
| `devedores` | a versão atual de cada documento (seção 5.3); `hash_conteudo` liga a versão atual à histórica | a gold e a régua leem o cadastro atual sem refazer o desempate |
| `devedores_contatos` | uma linha por (documento, tipo_contato, contato), com a primeira e a última entrega e os atributos do provedor (`tipo`, `principal`) da aparição mais recente | o histórico da relação devedor–contato, que é o que a régua usa |
| `devedores_enderecos` | uma linha por (documento, endereço padronizado), com a primeira e a última entrega; no beta, `tipo` e `atual` da aparição mais recente | a `dim_endereco` da gold (seção 6.4) |

**Por que o histórico da relação devedor–contato.** O motivo é o risco do enunciado: "um número que mudou de dono ou um contato ligado a vários CPFs" (p. 1). A versão atual do devedor perde os contatos que saíram dela, e são justamente esses que mostram a troca de dono. Medido: 481 telefones do alfa e 922 telefones e 91 e-mails do beta só aparecem em versões anteriores à atual (commits 48507a8 e ddc2107). Na análise exploratória, telefones que passaram para outro CPF entre o histórico e as entregas tiveram 25,1% de contato errado em 1.014 tentativas ([perfil-das-fontes.md](perfil-das-fontes.md)). O desenho dos pares é próximo do que o Data Vault chama de satélite de efetividade num link: o histórico da relação (fontes: a documentação de snapshots do dbt, cópia em `.context/raw/referencias/dbt/snapshots.md`, Apache 2.0, e, como referência secundária, https://www.wikiwand.com/en/Data_vault_modeling).

**Como os pares saem da histórica.** A primeira entrega de um par é a menor das primeiras entregas das versões que o contêm; a última, a maior das últimas. A rastreabilidade e os atributos do provedor são os da versão com a maior `ordem_versao` que contém o par, porque a data de entrega sozinha não identifica o arquivo. Um par com documento `NULL` é deduplicado só pelo contato (ou pelo endereço) entre as linhas sem documento e nunca se junta a um par de documento válido (seção 5.8).

**Até 2026-11-09**, a silver guardava só a versão atual em `devedores`, a `devedores_contatos` lia as linhas padronizadas, e a `devedores_enderecos` do beta tinha a lista da versão atual. A seção 6 explica a mudança. Quando `devedores` e `devedores_contatos` passaram a sair da histórica, nenhuma das tabelas que já existiam mudou de conteúdo (seção 6.6). A `devedores_enderecos` do beta mudou de grão depois, de (documento, posição) para (documento, endereço), e ganhou as versões antigas (seção 6.4).

### 5.6 A ponte de provedores na cobrança

`contatos_realizados` tem uma linha por `contato_id`, e `contatos_realizados_provedores`, uma linha por (contato, provedor), abrindo o texto `alfa|beta|gama`. Resultado: 7.720 contatos com um único provedor, 4.945 com dois e 2.388 com os três (commit 6be923e). Os 7.720 batem com a contagem da fase de desenho.

**Por que não uma coluna booleana por provedor.** Uma coluna por valor (`flag_alfa`, `flag_beta`, `flag_gama`) é um grupo repetido, a violação clássica da primeira forma normal (https://help.hcl-software.com/onedb/current/ddi/ids_ddi_188.html), e um provedor novo mudaria o esquema. A tabela ponte é a técnica de Kimball para atributo multivalorado (https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/multivalued-dimension-bridge-table/). O alerta do próprio Kimball vale para a gold: somar tentativas atravessando a ponte conta duas vezes a tentativa com dois provedores (Design Tip #166, https://www.kimballgroup.com/2014/05/design-tip-166-potential-bridge-table-detours/).

A coluna da ponte se chama `provedor_origem`, como o campo da origem (seção 5.9). A abertura usa `STRING_TO_ARRAY` e `UNNEST`, que existem nos dois motores. O destino é normalizado conforme o canal (telefone em ligação, SMS e WhatsApp; e-mail em e-mail), e o texto original fica em `destino_original`.

### 5.7 Endereço: separação estrita, com teste de ida e volta

O endereço em texto é separado em logradouro, número, complemento, bairro e cidade só quando casa inteiro, do início ao fim, com um padrão estrito. Quando não casa, todas as partes ficam `NULL`, e o texto original fica sempre em `endereco`. Os testes `alfa_endereco_ida_e_volta` e `gama_endereco_ida_e_volta` exigem que as partes recomponham o texto original.

| Opção | Ganho | Custo |
|---|---|---|
| Padrão estrito ancorado + ida e volta (adotada) | nenhuma parte inventada nem deslocada; o teste prova que nada se perdeu | uma linha fora do padrão fica sem partes |
| Separação tolerante (cortar pelo último hífen, por exemplo) | mais linhas com partes | um hífen dentro do nome da rua desloca o bairro para a cidade sem aviso |

Cobertura medida: 11.459 de 11.459 endereços do alfa e 100% das 6.918 linhas do layout `rua` e das 2.936 do layout `endereco` da gama (commits 48507a8 e d6bb9e4). Os 9.650 endereços da gama no layout estruturado e todos os do beta já vêm separados pelo provedor. O que o padrão não pega é a troca de campos com o mesmo formato (bairro no lugar da cidade). O autor decidiu em 2026-11-09 que o padrão estrito fica e que a ordem dos campos é obrigação do provedor no contrato ([contratos-de-dados.md](contratos-de-dados.md)): nenhum teste distingue dois textos livres.

As partes separadas aqui são a identidade do endereço nos pares `devedores_enderecos`, e o texto livre do endereço vai para maiúscula (seção 6.4). Os testes de ida e volta (`alfa_endereco_ida_e_volta`, `gama_endereco_ida_e_volta`) continuam verdes com o texto em maiúscula: nenhuma expressão regular do endereço depende de maiúscula ou minúscula.

### 5.8 Linhas sem chave e documento que não identifica ninguém

Uma linha que não se lê (CSV ilegível, JSON truncado do beta) ou que repete o cabeçalho não entra na silver e continua na bronze. O cabeçalho repetido não é um registro e nunca vira versão; o teste de aviso `cabecalho_repetido_fora_da_historica` conta essas linhas (hoje 1, na gama). Documento vazio ou só com zeros (`0`, `000.000.000-00`, `00000000000`) é ausência de chave: `documento` fica `NULL` antes de qualquer deduplicação, e a linha nunca vira devedor. Ela entra na histórica como versão com `documento` `NULL`, para nenhuma informação recebida se perder. O autor decidiu isso em 2026-11-09 e 2026-11-10, a partir de "ausência é `NULL`, nunca zero" (AGENTS.md, convenções do case).

| Opção | Ganho | Custo |
|---|---|---|
| `NULL`, fora de `devedores`, com os contatos em `devedores_contatos` com `documento` `NULL` (adotada) | nenhuma pessoa é fundida sob um documento falso; os contatos dessas linhas continuam disponíveis | a chave de `devedores_contatos` tem de tratar `NULL` como valor |
| Manter o documento zerado como chave (como estava) | nada a mudar | juntava pessoas diferentes: 3 nomes distintos em 3 linhas do alfa e 8 em 9 linhas do beta (por nome, sem normalizar) ficavam num único devedor |
| Descartar a linha inteira (como era com o documento vazio) | simples | perdia os contatos dessas linhas |

O plano falava em 5 pessoas diferentes no CPF zerado do beta; medi 8 nomes distintos em 9 linhas e não investiguei a diferença.

**Como funciona.**
- `cpf_normalizado` devolve `NULL` para documento vazio ou só com zeros, e o RG do beta passa pela macro `nulo_se_so_zeros`. No beta, `documento_tipo` também fica `NULL` quando não há documento. O mesmo vale para o `cpf_alvo` da cobrança (nenhuma linha cai nisso hoje; o teste `documento_que_nao_identifica_ninguem` confere todas as tabelas).
- `devedores` filtra `documento IS NOT NULL` antes do `ROW_NUMBER`, para os `NULL` não formarem um grupo.
- `devedores_contatos` (e `devedores_enderecos`) recebe os contatos (e os endereços) das versões dessas linhas. O `GROUP BY` e o `ROW_NUMBER` agrupam `NULL` com `NULL`, então esses contatos são deduplicados só por (`tipo_contato`, `contato`) entre as linhas sem documento, com a primeira e a última entrega e a rastreabilidade da aparição mais recente. A junção que devolve essa rastreabilidade usa `IS NOT DISTINCT FROM`, e um par sem documento nunca se junta a um par de documento válido (teste unitário nas três fontes).
- A chave primária dessas tabelas usa `combinacao_unica`, que trata `NULL` como valor; o `unique` do dbt ignoraria o `NULL`. Um teste (`teste_combinacao_unica_trata_null_como_valor`) prova isso e falha se o teste genérico passar a ignorar `NULL`.

**Medido (2026-11-09).** 124 linhas sem documento utilizável: alfa 37 (34 vazios e 3 zerados), beta 42 (33 vazios e 9 zerados) e gama 45 (vazios). Os devedores com documento zerado caíram de 1 para 0 no alfa e no beta. Os contatos dessas linhas ficaram em `devedores_contatos` com `documento` `NULL`: 259 pares (alfa 63, beta 96, gama 100). 81 tentativas da cobrança chegam a esses contatos pelo canal e pelo destino (o plano citava 79; não investiguei a diferença).

| Fonte | Linhas que não viram devedor | Motivo | Teste (aviso) |
|---|---|---|---|
| alfa | 37 | 34 documentos vazios, 3 zerados | `alfa_linhas_sem_chave` |
| beta | 57 | 15 JSON truncados, 33 documentos vazios, 9 zerados | `beta_linhas_sem_chave` |
| gama | 47 | 1 ilegível, 1 cabeçalho repetido, 45 documentos vazios | `gama_linhas_sem_chave` |
| cobranca | 0 | — | `cobranca_linhas_sem_chave` |

Na gama, outras 21 linhas têm documento, mas o JSON de `contatos` está truncado. O devedor entra, e os contatos cortados não (teste warn `gama_contatos_truncados`). Não há tabela de rejeitados: a bronze já guarda a linha com o texto e o motivo, e uma tabela a mais repetiria os mesmos dados.

No PostgreSQL, a junção com `IS NOT DISTINCT FROM` não usa hash join (o predicado não é uma igualdade); o desenho foi executado só no DuckDB, onde o plano usa Hash Join e não tem alertas.

### 5.9 Nomes de coluna: os da origem

Decisão do autor (2026-11-09; AGENTS.md, "Camadas e nomes"): a bronze e a silver mantêm os nomes de coluna da origem, e só a gold renomeia para o padrão de prefixos. Quando a silver une variantes de um campo, usa um dos nomes que a fonte usa: alfa `documento` (que substituiu `cpf` a partir de 12/09), beta `nome_completo` (junta `nome`, `nome_completo` e `nome_devedor` com `COALESCE`) e gama `uf` e `cidade` (no lugar de `estado` e `municipio`). Coluna criada pela pipeline recebe nome novo e cede o nome numa colisão.

A primeira versão da silver tinha renomeado 6 colunas que não têm variante na fonte: `dt_ref` e `cnpj_empregador_raw` da gama, `atualizado_em` do beta, o `tipo` do telefone no beta e na gama (`tipo_telefone`) e o `provedor_origem` da ponte da cobrança (`provedor`). Todas voltaram ao nome da origem (commit 1ed6423). A coluna criada que diz se o contato é telefone ou e-mail passou a `tipo_contato` nas três tabelas `devedores_contatos`, porque o `tipo` é o campo do provedor.

Colunas criadas, com nome próprio: `tipo_contato`, `contato` (o valor normalizado, que junta campos diferentes de telefone e e-mail), `data_entrega`, `data_primeira_entrega`, `data_ultima_entrega`, `posicao`, `hash_conteudo` e `hash_endereco` (seção 6), e as partes do endereço do alfa.

Campo de objeto JSON aninhado que vira coluna da tabela-mãe chama-se `<objeto>_<chave>`, com os dois nomes da fonte (decisão do autor, 2026-11-09; AGENTS.md, "Camadas e nomes"): no beta, `documento_tipo` (de `documento.tipo`), `vinculo_empresa_cnpj` e `vinculo_empresa_desde`; na gama, `atributos_extra_estado_civil`, `atributos_extra_qtd_dependentes`, `atributos_extra_score_externo`, `atributos_extra_escolaridade`, `atributos_extra_possui_imovel` e `atributos_extra_fonte_score`, e `endereco_json_complemento`, o único campo de `endereco_json` que passa como veio. O `documento` (une `cpf` e `documento.valor`) e as partes do endereço da gama (`logradouro`, `numero`, `bairro`, `cidade`, `uf`, `cep`, que unem layouts ou completam o valor) são criadas pela pipeline e mantêm o nome próprio. Elemento de lista aberta em tabela filha mantém as chaves da fonte (a tabela filha é o objeto): `tipo`, `logradouro` e demais em `devedores_enderecos`. O teste `colunas_declaradas` falha se uma tabela da bronze ganhar ou perder uma coluna em relação ao YAML.

### 5.10 Tipos adotados

O enunciado pede os tipos de cada coluna e o ganho de integridade (p. 2).

| Dado | Tipo | Por quê |
|---|---|---|
| CPF, CNPJ, CEP, telefone | texto | são códigos: o zero à esquerda faz parte do valor (662 linhas do histórico do alfa perderam zeros do CPF, 3.562 linhas do alfa têm CEP com 7 dígitos) e o CNPJ pode ser alfanumérico |
| datas (nascimento, atualização, entrega) | `DATE` | permite ordenar e comparar; data impossível vira `NULL`; datas sem fuso valem como horário de Brasília (seção 5.11) |
| `data_hora` da cobrança | `TIMESTAMP` | as 15.053 linhas têm data e hora válidas |
| salário e renda | `NUMERIC(14, 2)` | valor exato, sem erro de ponto flutuante; vazio é `NULL` e o `0,00` recebido fica 0.00 |
| dependentes e score da gama | `INTEGER` | contagem e pontuação inteiras |
| `principal`, `atual`, `possui_imovel` | `BOOLEAN` | vêm como booleano no JSON |
| `vinculo_empresa_desde` do beta | `DATE`, no dia 01 | decisão do autor (2026-11-09): o valor é o MÊS do vínculo (a origem manda `AAAA-MM`); o dia 01 é só o jeito de guardar um mês em um `DATE`, e a descrição da coluna diz que ninguém deve lê-lo como "começou no dia 1". Formato fora de `AAAA-MM` vira `NULL`, e o aviso `beta_vinculo_desde_fora_do_formato` o conta (hoje 0) |

Rastreabilidade: `_linha` é `BIGINT` e `_arquivo` e `_hash_arquivo` são texto. `hash_conteudo` e `hash_endereco` são o texto hexadecimal que o `MD5` devolve.

### 5.11 Fuso horário: Brasília

Decisão do autor (2026-11-09; AGENTS.md, "Ingestão"): datas e horas que chegam sem fuso são tratadas como horário de Brasília, e os valores em epoch são convertidos para esse fuso (UTC−3, sem horário de verão desde o Decreto 9.772/2019). Aplica-se ao `atualizado_em` do beta em epoch (2.784 valores, todos entre 09:00 e 23:59 UTC, medidos em 2026-11-09: nenhum muda de dia na conversão), às datas ISO e `dd/mm/aaaa` e à `data_hora` da cobrança. Uma data escrita com fuso explícito (`2026-09-02T10:30:00-03:00`) vale a data local escrita. O fuso é a regra do projeto, e não uma informação confirmada pelos provedores.

### 5.12 UF

Todas as colunas de UF da silver (`silver_alfa.devedores`, `silver_beta.devedores_enderecos`, `silver_gama.devedores`) passam por `uf_normalizada`: `UPPER(TRIM(valor))`, e só vale se for uma das 27 UFs; vazio ou fora do domínio dá `NULL`. Medido na versão atual de cada devedor: no alfa, 343 UFs fora do padrão de maiúscula (`sp` 98 passou a `SP`, e o total de SP foi de 2.902 para 3.000) e 27 `XX` que viraram `NULL`; beta e gama já vinham no domínio. O `XX` é o preenchimento do provedor para UF desconhecida e está no contrato ([contratos-de-dados.md](contratos-de-dados.md)). A mesma lógica de formato leva o texto livre para maiúscula (seção 6.4).

### 5.13 CNPJ do empregador

Regra (macro `cnpj_normalizado`, sobre o CNPJ sem máscara de `cnpj_sem_mascara`): só letras e dígitos, em maiúsculas. Com 14 caracteres, fica. Com menos, completa com zeros à esquerda se o resultado tiver dígitos verificadores válidos. Com 12 caracteres e sem essa possibilidade, calcula os dois dígitos pela regra oficial da Receita: cada caractere vale o código ASCII menos 48, os pesos vão de 2 a 9 da direita para a esquerda e recomeçam, resto 0 ou 1 dá dígito 0 e senão o dígito é 11 menos o resto, e o segundo dígito usa o primeiro anexado (https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj/manual-dv-cnpj.pdf, acessado em 2026-11-09). A macro foi conferida com 00.000.000/0001-91 (dígitos 91) e com o exemplo alfanumérico do manual, 12.ABC.345/01DE (dígitos 35).

Medido sobre as linhas recebidas: 14 caracteres em 46.276 linhas, todas válidas, 13 CNPJs distintos; 12 caracteres em 980 linhas, que completam sempre num dos mesmos 13; 13 caracteres em 1.528 linhas do alfa (2 valores, completam com um zero), 3 caracteres em 784 linhas do alfa (`191`, que completa para `00000000000191`) e um valor de 17 caracteres na gama, que é o texto do cabeçalho repetido (`cnpj_empregador_raw`). Na silver (versão atual de cada devedor, 29.300 com CNPJ preenchido) os CNPJs válidos de 14 caracteres passaram de 28.723 para 29.300 (os 577 de 12 caracteres: alfa 507, beta 41, gama 29) e os valores distintos por fonte, de 26, 24 e 22 para 13, 13 e 13.

Limitação da base: o que não encaixa em nenhuma regra (mais de 14 caracteres, ou menos de 14 sem regra que o complete) fica como veio. Hoje nenhum valor da silver cai aí (o único de 17 caracteres é o cabeçalho repetido, que não está em nenhuma tabela); o aviso `cnpj_do_empregador_fora_da_regra` o mostra se aparecer, e o teste `cnpj_do_empregador_com_digito_verificador_valido` reprova a pipeline se algum CNPJ de 14 caracteres tiver dígitos inválidos. Completar com zeros e calcular os dígitos recompõem o que a origem escreveu sem os zeros à esquerda ou sem os dígitos; nenhuma delas adivinha um empregador, mas a regra supõe que o provedor mandou a base certa. Custo: reler as três colunas de CNPJ da silver foi de 0,37 s para 0,65 s (mediana de 7 execuções).

## 6. Mudança de rumo: histórico de versões (2026-11-10)

Esta seção reabre três decisões da silver: as tabelas (S1), a versão atual como única versão do devedor (S3) e o histórico só da relação devedor–contato (S4). As demais regras das seções 4 e 5 continuam valendo.

### 6.1 Motivo

A gold aprovou duas tabelas que precisam de todas as versões de cada registro:
- `ft_vinculo_empresa`: uma linha por versão de vínculo recebida (empregador, cargo, renda, início do vínculo);
- `dim_endereco`: documento × endereço distinto, com a primeira e a última vez em que foi visto.

A silver guardava só a versão mais recente de cada documento. O enunciado pede uma base que consolide "identificação, endereço, contatos e vínculo empregatício" e uma régua validada contra os "pontos cegos" da classificação (p. 1), e avalia a "consistência no tratamento de deduplicações, conflitos cadastrais" (p. 3). Uma renda ou um endereço que saiu da versão atual é exatamente o que a versão atual esconde.

**Medido em 2026-11-09 e 2026-11-10** (banco gerado no commit `fded0da`, conexão só de leitura):

| | alfa | beta | gama |
|---|---|---|---|
| Linhas legíveis / sem documento | 19.476 / 37 | 19.000 / 42 | 19.505 / 46 (1 é o cabeçalho repetido) |
| Versões (campos, contatos e endereços padronizados) | 18.587 | 17.866 | 18.565 (18.564 sem o cabeçalho repetido) |
| Versões que só diferem na data de atualização | 1.724 | 257 | 0 |
| Documentos com mais de uma renda | 1.982 | 1.416 | — (a gama não manda renda) |
| Conflitos no topo: mesmo documento, mesmas datas, conteúdos diferentes, decididos pela linha (antes da maiúscula; depois dela, 55 / 73 / 80, seção 6.5) | 55 | 76 | 80 |

### 6.2 Estrutura: as opções e por que M3

| Opção | Como fica | A favor | Contra |
|---|---|---|---|
| C (a primeira aprovada) | histórica só com os campos simples, base da `devedores`; a `devedores_contatos` continua lendo as linhas | mexe pouco | a histórica não tem tudo o que foi recebido (as listas ficam fora); duas bases para a mesma fonte |
| C com JSON | a histórica guarda as listas como vieram | mexe pouco | JSON numa tabela que a gold lê; comparar listas exige padronizá-las (o JSON bruto daria 4 versões falsas no beta); duas bases |
| B relacional | histórica + filhas por versão; a `devedores` e a `devedores_contatos` saem dela | uma base e uma regra de versão; a histórica tem tudo, sem JSON | mais tabelas; a `devedores_contatos` muda de origem, e um teste tem de provar que ela fica igual |
| M1 | só a histórica e as filhas; a gold calcula a versão atual e os pares | a silver não escolhe nada arbitrário; nenhuma tabela derivada para manter igual | a gold refaz o cálculo; saem tabelas já testadas; o contrato que a gold esperava muda |
| M2 | M1 + a versão atual e os pares como views | a gold recebe pronto; nada guardado duas vezes | a silver continua decidindo o desempate arbitrário |
| **M3 (adotada)** | B relacional, com a `devedores`, a `devedores_contatos` e a `devedores_enderecos` como tabelas | mantém o contrato que a gold esperava e as tabelas já testadas | redundância; a igualdade das derivadas com as tabelas anteriores foi provada uma vez, na refatoração (seção 6.6), e não por um teste permanente |

A escolha foi do autor, em 2026-11-10. A estrutura de cada fonte está na seção 5.5. As listas viram filhas, e não JSON, porque a silver abre listas em linhas (AGENTS.md, "Camadas e nomes"), como já faz com o `alfa|beta|gama` da cobrança (seção 5.6). O desempate arbitrário que a M3 mantém na silver está declarado na seção 6.5.

### 6.3 Duplicata real e chave da versão

**Duplicata real** é o mesmo documento com todo o conteúdo padronizado igual, sem contar `_arquivo`, `_linha`, `_hash_arquivo` e `data_entrega`.
- A data de atualização da fonte é conteúdo: 1.724 versões do alfa e 257 do beta só diferem por ela.
- O conteúdo igual colapsa onde quer que apareça, e não só quando se repete em seguida. Os casos A → B → A medidos são conflitos no mesmo arquivo e na mesma data, ordenados pela linha, e não retornos no tempo.
- `NULL` é igual a `NULL`.
- A ordem dos elementos de uma lista não cria versão.

**Chave: `hash_conteudo`.** É uma coluna criada: o `MD5` do conteúdo padronizado, com o documento e a assinatura de cada lista. Três macros em `macros/padronizacao/historico.sql` fazem a serialização num lugar só, igual nas três fontes:
- `serializar_valor`: `NULL` vira `N`; um valor vira `V<tamanho>:<texto>`. O prefixo de tamanho torna a serialização injetiva: (`ab`, `c`) e (`a`, `bc`) dão textos diferentes, e `NULL` difere do texto vazio (`V0:`). O `CONCAT_WS` não serve porque pula o `NULL`.
- `hash_conteudo`: o `MD5` das colunas serializadas, numa ordem fixa. A ordem das colunas faz parte do contrato.
- `assinatura_lista`: `STRING_AGG` dos elementos serializados, ordenados pelo próprio texto em ordem de bytes (`COLLATE "C"`). Por isso a ordem em que a lista chegou não muda a assinatura. Sem o `ORDER BY`, as documentações do PostgreSQL e do DuckDB dizem que a ordem do `STRING_AGG` é indefinida, e o hash poderia mudar entre execuções.

Os testes `macro_hash_conteudo` e `macro_assinatura_lista` provam que `NULL` difere de texto vazio e que a ordem da lista não muda o hash. Sem o prefixo de tamanho, os dois falham (verificado no passo das macros, commit 0732cea).

| Opção de chave | A favor | Contra |
|---|---|---|
| **K1. `hash_conteudo` (adotada)** | nunca é `NULL`, nem com `documento` `NULL`, então o `unique` e o `not_null` do dbt bastam; a mesma versão tem a mesma chave em qualquer execução e com cargas novas; a deduplicação particiona por uma coluna, e não por cerca de 20 | a serialização tem de ser única e fixa (por isso a macro); a chave não é legível; não é portável entre motores (seção 8) |
| K2. Rastreabilidade da aparição mais recente (`_arquivo`, `_linha`) | legível, única por construção | muda quando uma entrega nova repete a versão; a comparação de conteúdo continua precisando de todas as colunas e das listas |
| K3. Documento + número da versão (`ROW_NUMBER()`) | "versão 3 do CPF X" | a numeração muda quando chega uma versão com data mais antiga; depende do desempate arbitrário; o documento `NULL` precisa de caso especial |

**Colisão.** Com cerca de 18,6 mil versões por fonte, a chance de duas versões diferentes terem o mesmo `MD5` é da ordem de n²/2¹²⁹, cerca de 10⁻³¹. É uma estimativa de probabilidade, não uma medição. O `MD5` serve aqui só como impressão digital do conteúdo, sem adversário.

**Filhas.** `devedores_historico_contatos` (beta e gama) tem chave (`hash_conteudo`, `tipo_contato`, `contato`); medi 0 contatos repetidos dentro de uma lista, e um teste guarda isso. `devedores_historico_enderecos` (beta) tem chave (`hash_conteudo`, `posicao`). As duas têm `relationships` para a histórica. A `posicao` é atributo, vindo da aparição mais recente. As 21 linhas da gama com a lista de contatos truncada viram versões sem contatos, porque é o que foi recebido: são 20 versões, e 8 delas são a versão atual na `devedores` (medido no commit d872a8d). A gold não deve ler a falta de contatos nessas versões como "sem contato" (`docs/contratos-de-dados.md`, seção 6.4).

### 6.4 Endereços e texto em maiúscula

**O mesmo endereço** é o mesmo conjunto de partes padronizadas: `logradouro`, `numero`, `complemento` (na gama, `endereco_json_complemento`), `bairro`, `cidade`, `uf` e `cep`.
- As partes viram `hash_endereco` pela mesma macro `hash_conteudo`, **sem o documento**. Assim, a gold acha o mesmo endereço em documentos diferentes, e as mesmas partes dão o mesmo hash nas três fontes.
- O texto original fica na histórica e, nos pares, o da aparição mais recente, mas não é comparado. Ele só entra no hash quando todas as partes são `NULL` (0 casos medidos). O beta não manda texto, e essa posição do hash fica `NULL` nele.
- O complemento é comparado. Tratar como iguais o mesmo endereço com e sem complemento (221 pares na gama, entre layouts diferentes) é um julgamento, e fica para a gold.
- Os pares de versões sem documento ficam, com `documento` `NULL`, deduplicados só pelo endereço (seção 5.8).
- No beta, a posição na lista e o fato de o endereço vir numa lista ou num objeto só não entram na identidade. O `tipo` e o `atual` vêm da aparição mais recente do par, e o `atual` fica como veio (S7).

**Texto livre em maiúscula.** Nomes, cargo, partes do endereço e texto original do endereço vão para maiúscula, como a UF (seção 5.12). É padronização de formato: a mesma rua escrita em minúscula numa entrega e em maiúscula em outra é o mesmo endereço. Os valores de domínio da gama (`atributos_extra_estado_civil`, `atributos_extra_escolaridade`) ficam como vieram. Os acentos não são removidos: a medição de antes da implementação não registrou efeito, e o `unaccent` não faz parte do núcleo do PostgreSQL (não verificado).

| `devedores_enderecos` | alfa | beta | gama |
|---|---|---|---|
| Pares com documento, pelas partes (commit ca207e1) | 14.912 | 16.286 | 17.388 |
| Pares com documento `NULL` (commit ca207e1) | 33 | 43 | 41 |
| Endereços distintos (`hash_endereco`, commit ca207e1) | 14.709 | 16.175 | 17.320 |
| Pares com documento em maiúscula, medido antes da implementação | 14.912 | 14.994 | 16.739 |
| Pares com documento em maiúscula, na tabela (commit cdbc2f9) | 14.912 | 14.994 | 16.739 |
| Endereços distintos em maiúscula, na tabela (commit cdbc2f9) | 14.709 | 14.833 | 16.639 |

Há menos endereços distintos que pares: o mesmo endereço aparece ligado a mais de um documento, e é esse cruzamento que o `hash_endereco` sem o documento permite à gold. Os pares medidos antes da implementação são os com documento, e a tabela os reproduziu nas três fontes.

Nas versões da histórica, a maiúscula tirou 5 do beta (17.866 → 17.861) e nenhuma do alfa nem da gama; as filhas do beta caíram para 43.277 contatos e 18.657 endereços. A medição de antes da implementação previa −1 na gama e 0 no beta porque comparava só os campos simples. A identidade da versão inclui as listas (seção 6.3), e a versão da gama que ficaria igual difere nos contatos. Conferido na tabela: 1 versão da gama e 58 do beta diferem de outra só nas listas. A causa exata das 5 versões a menos no beta não foi isolada.

### 6.5 Desempate da versão atual: uma convenção arbitrária

Em 208 documentos (alfa 55, beta 73, gama 80, medido no commit d872a8d; antes da maiúscula eram 211, com beta 76), duas versões diferentes têm o mesmo documento, as mesmas datas de atualização e de entrega e o mesmo arquivo. Só a linha decide. A ordem completa está na seção 5.3; o último critério é `_linha DESC`, "o último registro escrito vale".

Essa regra é **arbitrária e determinística**. A posição da linha no arquivo não tem significado medido:
- o documento vem em ordem crescente em cerca de 50 % dos pares de linhas vizinhas, o que é o esperado de uma ordem sem relação com o documento;
- nos conflitos, o provedor reenvia depois tanto a linha de cima (alfa 6, beta 4, gama 4 vezes) quanto a de baixo (6, 5 e 7 vezes).

As alternativas eram `_linha ASC` e o próprio hash, igualmente arbitrárias. O autor ficou com `_linha DESC`, a regra que já estava em uso. Ela garante a mesma escolha a cada execução (p. 2), mas não diz qual conteúdo é verdadeiro. Isso é conflito cadastral (p. 3), e a gold, que "resolve conflitos" (AGENTS.md, "Camadas e nomes"), resolve os 208 com regra própria.

### 6.6 Prova da refatoração

Quando a `devedores` e a `devedores_contatos` passaram a sair da histórica (commit 5ef15a2), as 17 tabelas que já existiam ficaram idênticas às da versão anterior, em valores e em tipos (`EXCEPT` nos dois sentidos, com o banco anterior aberto isolado e exportado para Parquet). A única diferença é a coluna nova `devedores.hash_conteudo`.

| Tabela nova, no commit 5ef15a2 (antes da maiúscula) | alfa | beta | gama |
|---|---|---|---|
| `devedores_historico` | 18.587 | 17.866 | 18.564 |
| `devedores_historico_contatos` | — (colunas da histórica) | 43.288 | 45.311 |
| `devedores_historico_enderecos` | — (colunas da histórica) | 18.662 | — (colunas da histórica) |

A gama mediu 18.565 versões antes da implementação; a diferença é o cabeçalho repetido, que ficou fora da histórica.

## 7. Escolhas de formato

**Confirmadas pelo autor em 2026-11-09** (e já aplicadas):
- O documento "0" e o CPF zerado não são chave: viram `NULL` (seção 5.8).
- A data em epoch (ms) do beta é convertida em UTC−3, e as datas sem fuso valem como horário de Brasília (seção 5.11).
- O CNPJ de 12 caracteres é completado pela regra oficial da Receita (seção 5.13); antes ficava como veio.
- Os nomes de coluna da origem não mudam na silver (seção 5.9).
- A data 2025-09-01 fica como veio na ordenação (seção 5.4).
- O padrão estrito de endereço fica, e a ordem bairro → cidade é do provedor (seção 5.7).
- UF em maiúscula, com o que está fora das 27 UFs como `NULL` (seção 5.12).
- `vinculo_empresa_desde` é `DATE` no dia 01, com a descrição de que o valor é um mês (seção 5.10).

**Confirmadas pelo autor em 2026-11-10:**
- Texto livre (nomes, cargo, partes e texto original do endereço) em maiúscula, sem remover acentos; valores de domínio da gama como vieram (seção 6.4).
- O complemento entra na identidade do endereço (seção 6.4).
- O desempate final da versão atual é `_linha DESC`, declarado como convenção arbitrária (seção 6.5).

**Ainda a confirmar:**
- CPF com mais de 11 dígitos não é cortado.
- O telefone perde o `55` inicial só quando tem 12 ou 13 dígitos.
- Valor com vírgula usa a vírgula como separador decimal; sem vírgula, o ponto.
- O RG do beta fica com letras e dígitos, sem zeros repostos.

## 8. O que não foi verificado

- **O `hash_conteudo` e o `hash_endereco` não são portáveis entre motores.** O texto que o `CAST` gera (booleano, decimal, data) pode diferir entre DuckDB e PostgreSQL, e então o mesmo conteúdo daria outro hash. A deduplicação daria o mesmo resultado nos dois, porque compara o conteúdo do mesmo motor; a chave, não. Não há instância de PostgreSQL para testar. `MD5`, `STRING_AGG ... ORDER BY` e `COLLATE "C"` foram conferidos na documentação do PostgreSQL 18 e executados só no DuckDB.
- **962 x 1.416 documentos do beta com renda alterada.** A medição do desenho da gold, sobre os arquivos brutos com salário numérico, contou 962 documentos do beta com mudança de renda (e 1.984 no alfa); pela regra da pipeline (renda padronizada, versões da histórica), são 1.416 no beta (e 1.982 no alfa). Não reproduzi o 962; a seção 9.8 explica a maior parte da diferença (renda em texto no beta).
- **Acentos:** os acentos ficam como vieram na silver (seção 6.4). Para a gold, conferi depois na documentação do PostgreSQL 18 que o `unaccent` é uma extensão do `contrib`, e a comparação de nomes usa `TRANSLATE` (seção 9.6).

- **Versões PostgreSQL das macros.** As macros com `adapter.dispatch` têm uma versão DuckDB, executada e testada, e uma versão PostgreSQL escrita só a partir da documentação, nunca executada (não há instância PostgreSQL no projeto): `json_ou_nulo` (`IS JSON`, `CAST AS JSONB`), `data_iso_ou_nulo` e `timestamp_ou_nulo` (`pg_input_is_valid`, PostgreSQL 16 ou mais novo), `json_texto` e `json_abrir_lista` (`jsonb_array_elements ... WITH ORDINALITY`). `STRING_TO_ARRAY` com `UNNEST` existe nos dois motores, mas só rodou no DuckDB. As macros novas (`cnpj_*`, `uf_normalizada`, `mes_como_data`, `nulo_se_so_zeros`) usam só `ASCII`, `SUBSTRING`, `LPAD`, `UPPER`, `CASE`, o resto inteiro (`%`) e os operadores `~` e `!~`, que existem nos dois motores, mas também rodaram só no DuckDB. A junção `IS NOT DISTINCT FROM` do histórico de contatos não usa hash join no PostgreSQL.
- **Testes genéricos fora do lint.** O SQLFluff com o templater do dbt não analisa os arquivos de `{% test %}` em `tests/generic/`. O uso de `graph.sources` nesses testes foi verificado só pela execução, não na documentação do dbt.
- **Números dos commits que não reproduzi:** o 0 do alfa e o 35 da gama para a data 2025-09-01, e os 87 vencedores da gama que mudariam frente à ordem só por entrega (seção 5.4). Os números reproduzidos estão nas consultas de `analyses/`; o 60 de uma refeita anterior vinha dos 58 empates entre original e reenvio, já eliminados. Também não investiguei por que medi 8 nomes distintos sob o CPF zerado do beta (o plano dizia 5) e 81 tentativas da cobrança nos contatos sem documento (o plano dizia 79).
- **Fuso horário:** a origem não traz fuso, e o horário de Brasília é uma regra do projeto, não uma informação confirmada pelos provedores.
- **Desempenho:** os tempos (pipeline de cerca de 20 s com os testes, gravação em lote de 53 a 74 vezes mais rápida) foram medidos numa única máquina.

## 9. Gold: base única e régua de risco (decidida antes do código)

Esta seção registra as decisões da gold, tomadas pelo autor em 2026-11-09 e 2026-11-10, antes de qualquer modelo da camada ser escrito. Ela fecha a ponte que a seção 6 abriu: a silver passou a guardar as versões porque a gold pede o histórico de vínculo e de endereço.

- **Base:** o enunciado (p. 1 a 4), as convenções do `AGENTS.md` e as fontes externas citadas em cada decisão.
- **Números:** os do desenho (G1 a G7) foram medidos sobre os arquivos brutos de `contact_data/`; os da conferência contra a silver (pontos 1 a 9), sobre o banco da pipeline, em conexão só de leitura. As consultas foram descartáveis. Cada passo da execução mede de novo sobre a silver e põe as contagens finais no corpo do commit; uma contagem que divergir mais de 10% da que está aqui para a execução e volta para decisão.
- **Limites:** dados sintéticos (p. 2) e um mês de tentativas (setembro de 2026). As taxas abaixo descrevem estes dados; nenhuma vale como estimativa para dados reais.
- **Contato com terceiro**, em todas as taxas desta seção, é a tentativa com resultado `numero_errado` ou `nao_conhece_devedor`.

### 9.1 O papel da gold: o critério é o grão

A gold tem só tabelas `dim_` e `ft_` em que cada linha é uma entidade ou um evento derivado de registros recebidos, com as regras de negócio já aplicadas. Os agregados que respondem às perguntas do case (matriz de acertos, calibração, peso das variáveis, horário, provedor) são consultas em `analyses/`, com `ref()`, executadas com `dbt show`; as conclusões vão para o README.

Base: o enunciado separa a camada "confiável para uso operacional em cobrança" (p. 1) das análises que avaliam a régua (p. 2); a convenção do case diz que "cada linha corresponde a um registro recebido" (AGENTS.md); o guia de estrutura do dbt, na parte Marts, trata o que vem depois dos marts como métricas, e não como mais tabelas (cópia em `.context/converted/referencias-dbt-how-we-structure-4-marts.md`). Conferi no dbt Core 1.12.6, num projeto descartável, que as consultas de `analyses/` entram no manifesto com as dependências, aparecem no grafo da documentação e rodam com `dbt show` contra o banco construído. Sem exposures. Como `analyses/` não é materializado, a regra de materialização do AGENTS.md (Stack) não se aplica a ele.

| Opção | Ganho | Custo |
|---|---|---|
| **Só `dim_`/`ft_` na gold; agregados em `analyses/` (adotada)** | cada tabela tem um grão que vem da origem; o agregado não vira contrato | quem quer o agregado roda a consulta |
| Datasets derivados como views num schema `analises` (rascunho anterior) | o agregado fica pronto para um painel | um terceiro tipo de tabela, sem grão de registro recebido |

### 9.2 Tabelas, schema e nomes

Todas no schema `gold_devedores`. O schema da gold é o domínio de negócio, e não a fonte; o fato de monitoramento da ingestão (etapa seguinte) vai para outro `gold_<domínio>`. O nome `gold_cobranca` ficou de fora porque repete o nome da fonte `cobranca` (AGENTS.md, "Camadas e nomes").

| Tabela | Grão | Base |
|---|---|---|
| `dim_devedor` | uma pessoa identificada por CPF (seção 9.5) | silver `devedores` e `devedores_historico` das três fontes |
| `dim_contato` | CPF × contato normalizado; contato sem documento com `sk_devedor` `NULL`; guarda a régua | silver `devedores_contatos` das três fontes |
| `dim_endereco` | CPF × endereço padronizado distinto | silver `devedores_enderecos` das três fontes |
| `dim_empregador` | um CNPJ recebido; o enriquecimento pela Receita é de outra etapa | CNPJs das históricas |
| `ft_vinculo_empresa` | período contínuo de um mesmo vínculo, por documento e provedor | silver `devedores_historico` |
| `ft_tentativa_contato` | uma tentativa (`contato_id`) | silver `cobranca.contatos_realizados` |

**Dimensão ou fato.** O teste usado foi: aconteceu num momento ou descreve alguém? O par devedor × contato descreve o devedor, por isso é dimensão; a tentativa aconteceu num momento, e é o único fato de evento. `dim_contato` → `dim_devedor` é um floco pequeno, aceito.

**Endereço numa dimensão própria**, e não um endereço escolhido como atributo da `dim_devedor`: o beta manda 867 registros com dois endereços (um `atual`), e cerca de 2.030 dos 10.251 CPFs presentes em mais de um provedor têm CEPs diferentes entre eles (contagem aproximada, nos arquivos brutos). Escolher um endereço apagaria os outros.

**Contato sem documento (G2c′).** Os contatos das linhas sem documento utilizável (124 linhas recebidas, seção 5.8) entram na `dim_contato` com `sk_devedor` `NULL`, bloqueados. Assim a tentativa que chega a eles se liga a alguma coisa e não vira ponto cego (p. 1: "pontos cegos", "contato ligado a vários CPFs"). A consulta dos contatos de um devedor filtra `sk_devedor IS NOT NULL`.

**Canal e resultado (G2b).** `canal` (4 valores) e `resultado` (10 valores, conferidos na silver: 15.053 tentativas) ficam como colunas da `ft_tentativa_contato`, com as classificações derivadas num lugar só. Sem `dim_canal`, `dim_resultado` nem dimensão junk; uma dimensão só se justifica quando um segundo fato usar esses valores. As classes de `tipo_desfecho`:

| `tipo_desfecho` | `resultado` | Por quê |
|---|---|---|
| `contato_confirmado` | `pagamento`, `promessa_pagamento`, `reclamacao` | a reclamação também confirma que a pessoa certa foi alcançada |
| `terceiro` | `numero_errado`, `nao_conhece_devedor` | a pessoa alcançada diz não ser o devedor |
| `opt_out` | `opt_out` | pedido explícito |
| `falecido` | `falecido` | |
| `sem_confirmacao` | `entregue`, `lido`, `sem_resposta` | `lido` não confirma quem leu |

Um valor novo de `resultado` fora da lista reprova um teste `accepted_values`, para não cair numa classe por acaso.

**Provedor (G2d).** Linha montada a partir de vários provedores traz só `qt_provedores`. Sem uma flag por provedor, sem tabela ponte e sem a coluna de vários valores `desc_provedores_origem` que o AGENTS.md pedia antes (ela fere a primeira forma normal). A pergunta "qual provedor" é uma consulta em `analyses/` sobre `silver_cobranca.contatos_realizados_provedores`. O número de provedores é o sinal: nas tentativas de setembro, o contato visto por um provedor só teve 9,3% de contato com terceiro na gama, 6,3% no alfa e 4,0% no beta; o visto por dois ou mais, de 1,1% a 1,2%. Uma coluna de provedor só entra depois, como `fix:` com ganho medido.

**Nomes de coluna.** O substantivo que é o próprio identificador ou valor fica sem prefixo (`cpf`, `cnpj`, `cep`, `canal`, `contato`); os prefixos dizem o papel (`sk_`, `desc_`, `nome_`, `tipo_`, `situacao_`, `qt_`, `vl_`, `tx_`, `flag_`, `dt_`, `hr_`), e o nível vai por extenso (`nivel_risco`). Saíram `cod_`, `num_` e `sigla_`; `tp_` virou `tipo_`, e `sit_` vai por extenso. O `sk_` fica: nenhuma das fontes consultadas (Kimball, o guia de esquema estrela da Microsoft Learn, dbt-utils) prescreve um nome, e o prefixo evita confundir a chave substituta com identificadores da origem como `contato_id`. O texto está no AGENTS.md, "Colunas da gold".

**Sinais como colunas categóricas.** Sinais que respondem à mesma pergunta viram uma coluna `situacao_` ou `tipo_` com valores fechados, e não uma flag por sinal. O estado conhecido "sem sinal" tem valor próprio (`nenhum`, `exclusivo`), e `NULL` fica para dado ausente. Quando dois valores do mesmo grupo coexistem, vale a prioridade da seção 9.9; nada se perde, porque os eventos estão na `ft_tentativa_contato` e as contagens ficam em `qt_`. A gold tem uma flag só, `flag_possui_imovel`, que é dado recebido da gama, e não sinal.

### 9.3 Chave substituta

`INTEGER` por `ROW_NUMBER()` ordenado pela chave natural (`dim_devedor`: `cpf`; `dim_contato`: `cpf`, `tipo_contato`, `contato`; o mesmo padrão nas outras dimensões), com o frame declarado em `ROWS BETWEEN`, como pede o case. É determinística porque o banco é recriado a cada execução (p. 2) e não carrega o CPF.

| Opção | Ganho | Custo |
|---|---|---|
| **`ROW_NUMBER()` pela chave natural (adotada)** | determinística, compacta, não revela o CPF | muda se o conjunto de chaves mudar; não serve para carga incremental |
| `md5` da chave natural (`dbt_utils.generate_surrogate_key`) | estável entre cargas | reversível: medi 10 milhões de `md5` de CPFs possíveis em 3,1 s no DuckDB desta máquina, o que dá cerca de 5 minutos para todos os 10⁹ CPFs (extrapolação, não medido); o CPF se espalharia por toda tabela |
| Hash com sal | estável e não reversível | o sal é um segredo, fora do repositório, e a execução deixa de ser reproduzível só com o repositório |

Evolução para carga incremental em produção: uma tabela de chaves persistida ou um hash com sal guardado num cofre.

### 9.4 Premissa: os mesmos devedores, uma operação

Os três provedores falam dos mesmos devedores, e a cobrança é uma operação só. O `provedor_origem` de uma tentativa é a origem do contato discado, e não uma carteira separada.

Base: "dados cadastrais dos devedores todos os dias, de três provedores diferentes", "base cadastral única" e "consolidar" (p. 1); "cada provedor fornece o que tem disponível" (p. 2). Nos dados, 10.250 dos 20.106 CPFs válidos aparecem em dois ou mais provedores; nesses, cerca de 97% dos nomes são compatíveis (730 das 998 divergências são abreviações); e o contato confirmado por dois ou mais provedores erra 1,1%, contra 4% a 9% no de um só.

Nada é sobrescrito: a silver guarda cada provedor, e a `dim_contato`, a `dim_endereco` e a `ft_vinculo_empresa` guardam as linhas de cada provedor. Só o nome e o nascimento da `dim_devedor` guardam um valor escolhido. A premissa vai para o README.

### 9.5 Quem é o devedor: documentos ruidosos ligados a um CPF

A `dim_devedor` tem uma linha por **pessoa identificada por um CPF**. Todo documento recebido chega à gold, mas um documento ruidoso é **ligado a um devedor que já existe** quando a evidência é forte, em vez de virar uma segunda pessoa.

| Caso | Regra | Medido (arquivos brutos, 2026-11-10) | Resultado |
|---|---|---|---|
| 1. CPF inválido (dígito verificador falha pela macro `cpf_valido` da silver), não zerado | mesmo nome comparável **e** mesmo nascimento de **exatamente um** CPF válido **e** um dígito de diferença para ele | 372 documentos | ligado ao devedor desse CPF válido |
| 2. Documento marcado `RG` pelo beta | mesmo nome comparável **e** mesmo nascimento de **exatamente um** CPF válido (não há teste de dígito possível) | 30 documentos | ligado a esse devedor, como evidência mais fraca, marcada à parte |
| 3a. CPF inválido sem ligação (cerca de 100, contando 9 empates) | nenhuma ligação | — | linha própria com `situacao_cpf = 'invalido'`; continua sendo um CPF, e a chave natural continua `cpf`. Vale também para CPF com mais de 11 dígitos (0 hoje) |
| 3b. `RG` sem ligação (12 sem par, 1 empate) | nenhuma ligação | 13 documentos | não é devedor: os contatos entram na `dim_contato` com `sk_devedor` `NULL`, bloqueados, como os das linhas sem documento |
| CPF válido | chave natural | 20.106 documentos distintos | linha própria, `situacao_cpf = 'valido'` |
| Documento vazio ou zerado (seção 5.8) | não é devedor | 124 linhas recebidas | contatos na `dim_contato` com `sk_devedor` `NULL`, bloqueados |

O registro ligado contribui com os contatos, os endereços e os vínculos para o devedor a que foi ligado, e os atributos dele entram nas regras de escolha da seção 9.7 como os de qualquer outro registro desse devedor. A `dim_devedor` conta os documentos ligados em `qt_documentos_vinculados`; na `dim_contato`, `situacao_documento` diz por qual documento o contato chegou ao devedor (`cpf_valido`, `cpf_corrigido`, `rg_por_nome_nascimento`, `cpf_invalido`, `sem_documento`), com `documento_original` quando não é `cpf_valido`. Assim, toda contribuição ligada é rastreável e pode ser excluída com um filtro.

**Por quê.**
- p. 1: "base cadastral **única**": a cópia ruidosa de uma pessoa não pode virar uma segunda pessoa.
- p. 1: o risco central é contatar quem não deve. Fundir duas pessoas diferentes é o pior erro, por isso a regra é determinística e exige várias concordâncias independentes.
- p. 3: a avaliação pede "consistência no tratamento de **deduplicações**, conflitos cadastrais e dados incompletos ou **ruidosos**".
- p. 4: "transparência quanto aos **limites das inferências**": a regra, as contagens e o risco que sobra vão para o README.
- Convenção do case, "modelos não geram linhas que não existam na origem": nada é inventado; o registro ligado é um registro recebido preso a um devedor recebido.
- Cruzar fontes é da gold (seção 2; AGENTS.md, "Camadas e nomes").

**Evidência.** Medido com uma consulta descartável no DuckDB sobre todos os arquivos históricos e diários dos três provedores, com esta normalização: documento só com dígitos, completado com zeros à esquerda até 11; dígito verificador pelo módulo 11 nos dois dígitos, sequências de dígitos iguais rejeitadas; nome `UPPER(strip_accents(TRIM(nome)))`; nascimento `dd/mm/aaaa` convertido para ISO, senão os 10 primeiros caracteres.

| Grupo | Documentos | Mesmo nome e nascimento de um CPF válido | Exatamente um par | Diferença de dígitos para o CPF encontrado |
|---|---|---|---|---|
| CPF inválido | 481 | 381 (79%) | 372 (9 têm 2) | os 381 pares a exatamente 1 dígito; alguns outros pares a 7–11 dígitos |
| `RG` do beta | 42 (9 caracteres, máscara `NN.NNN.NNN-D`; nenhum aparece como CPF no alfa nem na gama) | 31 (74%) | 30 (1 tem 2) | não se aplica |
| Controle: CPF válido contra outro CPF válido | cerca de 20.100 | 415 (cerca de 2%) | — | — |

Leitura: um CPF inválido é quase sempre um **erro de um dígito** de uma pessoa que já está na base, exatamente a classe de erro que o dígito verificador foi feito para pegar. A diferença entre 79% e os 2% do controle mostra que a concordância de nome e nascimento não é acaso. Nenhuma das 15.053 tentativas de setembro vai para um CPF inválido.

**A regra, exatamente.**
1. Só um CPF válido, de qualquer provedor, pode receber um documento ruidoso; esse CPF é o par do documento.
2. Nome e nascimento são comparados depois da padronização da silver e do nome comparável (seção 9.6); os números acima são medidos de novo com essa chave na execução.
3. O caso 1 exige as três concordâncias: mesmo nome, mesmo nascimento e distância de Hamming 1 entre as cadeias de 11 dígitos.
4. O caso 2 exige mesmo nome e mesmo nascimento.
5. Os dois casos exigem **exatamente um** par. Empate nunca é resolvido: cai no caso 3.
6. As funções de janela permitidas pelo case bastam: `SUM(1)` com `ROWS BETWEEN` conta os pares de cada documento ruidoso, e ficam só as linhas em que a contagem é 1.

**Testes da execução.**
- Teste unitário do dbt para cada regra: erro de um dígito com par único é ligado; dois dígitos de diferença não é ligado; dois pares não é ligado; RG com nome e nascimento únicos é ligado; RG sem par fica de fora.
- Todo documento ligado aponta para um devedor com `situacao_cpf = 'valido'`.
- Nenhum CPF válido é ligado a outro documento.
- `cpf` e `sk_devedor` únicos.
- Contagem (aviso) de documentos ligados por caso e por provedor, no corpo do commit e no README.

**Opções.**

| Opção | Ganho | Custo |
|---|---|---|
| **Ligar o documento ruidoso quando a evidência é forte (adotada)** | uma pessoa, uma linha; os contatos do registro ruidoso servem ao devedor certo | risco de fundir duas pessoas (abaixo) |
| Todo documento vira linha própria, com a validade como coluna (primeira decisão) | nenhuma fusão | 372 pessoas contadas duas vezes, cada metade com parte dos contatos |
| Só CPFs válidos na `dim_devedor` (linha do resumo da silver) | dimensão limpa | o documento inválido sem ligação some da base cadastral |
| RG sem ligação como devedor, com chave (`tipo_documento`, `documento`) | nenhum registro fora da dimensão | a chave natural deixa de ser uma coluna só e a dimensão deixa de ser "pessoa identificada por CPF", por 13 documentos |

**Riscos e limites (README).**
- Duas pessoas diferentes com o mesmo nome, o mesmo nascimento e CPFs a um dígito de distância seriam fundidas. A exigência de par único torna isso improvável, mas **a probabilidade não foi medida**.
- O caso 2 não tem teste de dígito e é evidência mais fraca. As contribuições dele levam `situacao_documento = 'rg_por_nome_nascimento'`, e a régua as põe em `atencao` (seção 9.9).
- Dados sintéticos: a colisão de nome e nascimento entre CPFs válidos (cerca de 2%) mostra que nomes se repetem nestes dados; dados reais podem ser diferentes.
- Não verificado: o formato oficial do RG de qualquer estado (nenhuma fonte oficial consultada) e a validade dos números de RG (não há dígito verificador nacional).
- Evolução com mais tempo: ligação probabilística de registros (semelhança de nome, endereço, contatos em comum) em vez de igualdade exata.

### 9.6 Nome comparável

A macro da gold `nome_comparavel` é um `TRANSLATE` com o mapa dos acentos maiúsculos (`ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ` → `AAAAAEEEEIIIIOOOOOUUUUCN`), aplicado ao nome que a silver já passou para maiúscula (seção 6.4). É a chave de comparação de nomes da seção 9.5 e da 9.7; a coluna `nome_devedor` continua mostrando o nome recebido.

Medido sobre a histórica: o resultado é igual ao do `strip_accents` nos 21.650 nomes distintos, sem nenhum caractere fora do ASCII sobrando. O alfa manda nomes sem acento (0%), o beta e a gama em cerca de 38%; por isso os documentos com dois ou mais nomes entre as versões atuais dos provedores caem de 3.494 para 569 com a chave. Quando as formas diferem só no acento, a coluna mostra a forma acentuada. Um teste de aviso conta caracteres fora do ASCII que sobrem na chave, para pegar um acento fora do mapa.

| Opção | Ganho | Custo |
|---|---|---|
| **`TRANSLATE` com mapa fixo (adotada)** | existe no núcleo do PostgreSQL 18 e no DuckDB 2.0 (conferido nas duas documentações) | o mapa é fixo; um caractere fora dele passa (por isso o teste de aviso) |
| `strip_accents` | completo | só existe no DuckDB |
| `unaccent` | completo no PostgreSQL | é extensão do `contrib` (confiável, mas precisa ser instalada; documentação do PostgreSQL 18) e não existe no DuckDB |

### 9.7 Escolha de atributos e conflitos

**Atributos estáveis (nome, nascimento): maioria entre provedores**, um voto por provedor, a versão atual de cada um.
- Nome: abreviação não é conflito (mesmo primeiro e último nome e mesmas iniciais: fica a forma por extenso); depois, maioria das formas completas; empate, a mais recente.
- Nascimento: sentinelas (1900-01-01, datas futuras como 2031-05-10, datas inválidas) não votam; empate, inclusive dia e mês trocados, dá `NULL`. Medido: 52 linhas com 1900-01-01, 36 com 2031-05-10, 455 CPFs com duas ou mais datas válidas, 49 deles com dia e mês trocados.

**Atributos mutáveis (endereço, vínculo, renda): o mais recente.** `situacao_endereco = 'atual'` e `situacao_vinculo = 'atual'` saem da versão mais recente entre os provedores (no beta, o `atual` do endereço).

**Perfil da gama** (`estado_civil`, dependentes, `score_externo`, `escolaridade`, imóvel, `fonte_score`): só a gama manda (verificado: zero ocorrências nos arquivos do alfa e do beta). Vale a versão atual da gama, e quem a gama não manda fica com `NULL` estrutural, documentado na coluna.

**Recência.** A versão atual de cada fonte é a da silver (`devedores`), com a data de atualização como veio, inclusive 2025-09-01. A primeira versão desta regra tratava 2025-09-01 como ausente; ela foi substituída para a gold seguir a ordem da silver (seção 5.4).

**Datas recebidas.** A gold nunca troca uma data recebida por `NULL`: `dt_atualizacao` e as demais datas mostram o valor de origem. O `NULL` do nascimento por empate não contradiz isso: ali falta um valor confiável escolhido, e nenhuma data recebida é apagada.

**Conflito de identidade (G3c).** Primeiro ou último nome diferentes para o mesmo CPF marcam `identidade` em `tipo_conflito_cadastral`. Os atributos continuam seguindo a regra acima, e a régua decide o que fazer (seção 9.9). Medido: 998 CPFs com nomes divergentes (730 abreviações, 249 com primeiro ou último nome diferente, 19 só no nome do meio). Dos 249: 68 em três provedores, 144 em dois e 37 dentro de um provedor só, ao longo do tempo; 130 têm maioria entre provedores e 119 empatam; o nascimento também difere em 224 (90%). As 207 tentativas de setembro a esses CPFs tiveram 29,5% de contato com terceiro, contra 3,6% nos demais. A alternativa, atribuir cada contato à versão de onde veio, fica como evolução no README; os 37 casos dentro de um provedor ganham nota própria lá.

**Conflito de versões (ponto 4).** Nos 208 documentos com duas versões diferentes no mesmo arquivo e nas mesmas datas (seção 6.5), vale a escolha da silver (`_linha DESC`, declarada arbitrária), e a `dim_devedor` marca `versao` em `tipo_conflito_cadastral` (os dois juntos dão `identidade_e_versao`). O sinal fica como coluna, sem mudar o nível de risco agora. Contatos, endereços e vínculos não dependem da escolha, porque guardam todas as versões; ela decide só `situacao_endereco`, `situacao_vinculo`, o voto desse provedor e o perfil da gama. Numa definição mais larga (empate em qualquer posição: 83, 92 e 101 documentos, contra 55, 73 e 80 da silver), as diferenças são sobretudo de endereço (alfa 54, gama 53 no logradouro), de renda (34 e 33) e de contatos; de nome, 3, 5 e 3; de nascimento, 2, 0 e 2. As alternativas de desempate são igualmente arbitrárias (seção 6.5).

**Salário 0,00 do alfa.** Vira `vl_renda` `NULL` ("não informado"), pela convenção do case "ausência de dado é `NULL`, nunca zero". As 330 linhas (325 documentos) têm cargo e CNPJ; em 210 desses documentos outra versão do alfa traz salário maior que zero, e 155 têm renda maior que zero no beta. A silver guarda o 0,00, e a rastreabilidade leva até ele; a suposição vai para os limites do README. É diferente da data recebida: a data é um valor real, e o 0,00 com empregador é o "não sei" do provedor.

### 9.8 Vínculo e endereço

**`ft_vinculo_empresa`: um período por linha.** Uma linha por período contínuo do mesmo conteúdo de vínculo, por documento e provedor. As versões da histórica são ordenadas pela data de atualização como veio, depois entrega, arquivo e linha, e um vínculo que volta depois de outro abre uma linha nova (ilhas pela diferença de dois `ROW_NUMBER()`, sem `LAG`, que o case não permite). Conteúdo comparado: alfa `cnpj_empregador`, `cargo`, `salario_informado`; beta `vinculo_empresa_cnpj`, `vinculo_empresa_desde`, `renda_mensal`; gama `cnpj_empregador_raw`. Conteúdo todo vazio não vira linha, mas separa períodos (A → vazio → A dá dois períodos). `dt_inicio_vinculo` guarda o mês do vínculo, no dia 01 por convenção (seção 5.10), e `dt_atualizacao` é a da primeira versão do período, como veio.

Medido: 18.554, 17.821 e 18.523 versões (alfa, beta, gama) contra 13.840, 13.897 e 12.536 conteúdos de vínculo distintos (todo vazio: 1.819, 1.789 e 1.794); um vínculo A volta depois de B em 149 documentos do alfa e 157 do beta (podem incluir conflitos de versão, não separados). O contrato da silver diz "uma linha por versão" (`docs/contratos-de-dados.md`, seção 6.3); a gold refina isso em períodos.

| Opção | Ganho | Custo |
|---|---|---|
| **Um período contínuo por linha (adotada)** | o histórico de empregador e renda sem repetir a versão que só mudou a data | a regra de ilhas precisa de teste unitário (A → B → A dá três linhas; A → vazio → A dá duas) |
| Uma linha por versão recebida (primeira decisão) | direta | repete o vínculo nas versões que mudaram outro campo (13.840 conteúdos distintos em 18.554 versões no alfa) |
| Uma linha por CPF × CNPJ | compacta | perde a volta a um empregador e a mudança de renda |
| Vínculo escolhido como atributo da `dim_devedor` | simples | perde o histórico que o enunciado pede consolidar (p. 1) |
| SCD2 com data de fim | consulta "vigente em" direta | a data de fim pediria `LEAD`, fora das funções de janela permitidas pelo case |

**Renda alterada.** 1.982 documentos no alfa e 1.416 no beta, confirmados pela regra da pipeline. O 962 da medição do desenho contava só a renda do beta que veio como número JSON: 3.262 linhas do beta mandam texto (`"R$ 9.241,83"`), e, restrita aos valores numéricos, a conta dá 960. A consulta de reconciliação vai para `analyses/` no passo dos vínculos. Isso explica a diferença registrada na seção 8 (o 960 contra 962 restante não foi investigado).

**`dim_endereco`.** CPF × endereço distinto pelo `hash_endereco` da silver (sem o documento, igual nas três fontes, seção 6.4), com `qt_provedores`. Dois endereços do mesmo CPF iguais em tudo menos o complemento se juntam quando um dos complementos é `NULL`: fica o preenchido, a menor primeira entrega e a maior última entrega. Dois complementos diferentes continuam separados. Medido: 342 grupos (684 pares) na gama, todos `NULL` contra um valor; nenhum no alfa e no beta. A seção 6.4 fala em 221 pares na gama; a diferença é reconciliada na execução.

**Contatos truncados da gama.** Nenhum sinal sai da falta de um contato na versão atual: as 8 versões atuais da gama com a lista cortada (seção 6.3) não são "sem contato".

### 9.9 Régua de risco

**Três níveis, por par devedor × contato**, cada um com `desc_motivo_risco`:

| `nivel_risco` | O que a operação faz |
|---|---|
| `liberado` | contato com mensagem de cobrança |
| `atencao` | contato sem expor a dívida: mensagem neutra pedindo retorno ou confirmação de identidade antes de qualquer menção à dívida |
| `bloqueado` | sem contato; vai para a lista de não-contatar com o motivo |

Base: níveis e critérios "a seu critério", "aplicável a cada telefone e e-mail de cada devedor", e o risco de expor a dívida a um terceiro (p. 1); canais e mensagens por nível e a justificativa de cada sinal de bloqueio (p. 2); equilíbrio entre efetividade de cobrança e proteção a terceiros (p. 4). Textos legais lidos em planalto.gov.br em 2026-11-10: CDC art. 42 e art. 71 e LGPD art. 6º, I, III e VII, e art. 7º, X. O bloqueio por opt-out e por falecimento é a política de proteção desta régua; não verifiquei uma obrigação legal específica para eles.

**Princípio dos sinais.** `bloqueado` quando a evidência diz que o contato é de outra pessoa ou há um pedido explícito; `atencao` quando a dúvida é estatística ou de identidade; `liberado` nos demais.

| Sinal | Nível | Evidência nas tentativas de setembro (contato com terceiro) |
|---|---|---|
| contato sem devedor (seção 9.2) | `bloqueado` | não há a quem cobrar |
| `numero_errado` ou `nao_conhece_devedor` no histórico do par | `bloqueado` | nova tentativa depois de `numero_errado`: 57,1% de terceiro; depois de `nao_conhece_devedor`: 49,3% |
| `opt_out` no contato | `bloqueado` | pedido explícito; 77 tentativas depois de um opt-out |
| `falecido` em qualquer contato do devedor (bloqueia todos os pares dele) | `bloqueado` | 15 tentativas depois de um falecimento |
| contato que migrou (compartilhado e visto depois para outro CPF) | `bloqueado` | 34,0%, contra 2,3% |
| contato compartilhado sem migração | `atencao` | 14,4% |
| conflito de identidade (seção 9.7) | `atencao` | 29,5%, contra 3,6% |
| documento ligado por correção ou por RG (seção 9.5) | `atencao` | nenhuma tentativa vai a CPF inválido; a dúvida é de identidade |
| CPF inválido sem ligação | `atencao` | idem |
| só coluna, sem mudar o nível agora: provedor único, par ausente das entregas, contagens, conflito de versão | — | provedor único sozinho: 1,6% contra 1,1%; par ausente das entregas antes de 15/09: 5,3% contra 2,1% |

As taxas são descritivas, medidas nos arquivos brutos contra as tentativas de setembro, e não são a validação da régua (abaixo). Os sinais "só coluna" ficam guardados para o estudo de pontuação; as regras de combinação ficam para esse estudo.

**Colunas, e não o nível só.** Cada grupo de sinais é uma coluna categórica ou `qt_` na `dim_contato` (`situacao_documento`, `situacao_compartilhamento`, `tipo_alerta_historico`, `situacao_entrega`, `qt_provedores`, `qt_devedores_mesmo_contato`, `qt_tentativas`, `qt_tentativas_terceiro`), e o nível sai delas. Os sinais do devedor ficam só na `dim_devedor`, e a régua os lê pela chave. A evolução estudada nas análises é uma régua de quatro níveis e uma pontuação de 0 a 100 com rótulos por faixa; com os sinais já em colunas, ela se calcula sem remodelar.

| Opção | Ganho | Custo |
|---|---|---|
| **Três níveis por regra (adotada)** | cada nível tem uma ação clara e um motivo legível; é o exemplo do enunciado (p. 1) | sinais estatísticos fracos não mudam o nível |
| Quatro níveis | separa a dúvida forte da fraca | estudo nas análises |
| Pontuação de 0 a 100 com rótulos por faixa | ordena dentro de cada nível | estudo nas análises; os pesos dependem da calibração |

**Lista de não-contatar.** É a `dim_contato` filtrada por `nivel_risco = 'bloqueado'`, com a consulta no README; não há tabela nova. `desc_motivo_risco` guarda o motivo principal pela prioridade falecido > opt-out > disse não ser o devedor > contato migrado > contato sem devedor; os demais motivos ficam visíveis nas colunas de sinal, sem texto concatenado. O opt-out bloqueia o contato para todos os CPFs ligados a ele, porque quem pediu foi o titular do número; `numero_errado` e `nao_conhece_devedor` valem para o par. Uma tabela própria só se justifica quando um consumidor real precisar de um contrato próprio.

**Validação sem vazamento.** Um corte único D = 2026-09-15: os sinais são calculados só com entregas e tentativas até D e avaliados nas tentativas depois de D (cerca de 7.280 antes e 7.770 depois; taxa de terceiro de 3,5%–3,7% antes e 3,8%–4,4% depois). Uma macro só, `regua_de_risco(data_corte)`: a `dim_contato` a chama sem corte (régua de operação), a análise a chama com D, e a régua validada é a mesma que opera. A validação não depende de colunas de data guardadas: a macro recalcula cada sinal só com os dados até o corte. As datas da `dim_contato` (`dt_situacao_compartilhamento`, `dt_alerta_historico`) são informativas, e os sinais do devedor não têm data própria. Conferi no dbt Core 1.12.6, num projeto descartável, que uma macro chamada dentro de `analyses/` compila com o argumento e roda com `dbt show`. As métricas de validação e a calibração são da etapa de análises. Evolução no README: avaliar cada tentativa com a régua de sete dias antes, no mesmo dia da semana, `regua_de_risco(data_da_tentativa - 7 dias)`.

**Par ausente das entregas.** Calculado só na régua de operação (a última entrega do par é anterior à última entrega do provedor) e fora da validação em D, porque a silver guarda só a primeira e a última entrega de cada par. Evolução: uma tabela de presença por entrega na silver. Não verificado: se as entregas diárias são retratos completos ou atualizações parciais.

### 9.10 Horário de contato

O horário diz quando, e não com quem, e por isso nunca muda `nivel_risco`. A janela é única e conservadora, a interseção das duas regras lidas:

| Regra | Segunda a sexta | Sábado | Domingo e feriado |
|---|---|---|---|
| Lei SP 17.832/2023, art. 51 (em vigor; a ADI 2342591-64.2023 do TJSP derrubou só os art. 194 e 195) | 8h às 20h | 8h às 14h | proibido |
| SARB 27/2023, art. 32 ("salvo legislação específica"; e-mail em qualquer dia e hora) | 7h às 21h | 9h às 16h | — |
| **Janela adotada, todo canal exceto e-mail** | **8h às 20h** | **9h às 14h** | **proibido** |

`situacao_horario` na `ft_tentativa_contato` (`permitido`, `fora_do_horario`, `domingo`, `feriado`, `nao_se_aplica` para e-mail); o resumo de conformidade fica em `analyses/`. Os feriados nacionais ficam numa `var` do dbt, citando a Lei 662/1949 com a redação da Lei 10.607/2002 (7 de setembro; 2026-09-07 é uma segunda-feira), e não numa tabela gerada.

Medido nas tentativas de setembro fora de e-mail (domingo, 07/09, dia útil fora de 8h–20h, sábado fora de 8h–14h):

| Canal | Tentativas | Domingo | 07/09 | Dia útil fora da janela | Sábado fora de 8h–14h |
|---|---|---|---|---|---|
| ligação | 2.576 | 101 | 74 | 103 | 212 |
| SMS | 1.993 | 80 | 76 | 78 | 158 |
| WhatsApp | 4.781 | 237 | 158 | 196 | 344 |

A medição do sábado usou 8h–14h; a janela adotada começa às 9h, e a contagem final sai da execução.

Fontes lidas em 2026-11-10: al.sp.gov.br (Lei 17.832/2023), o PDF do Normativo SARB 27/2023 em autorregulacaobancaria.com.br, o relatório de autorregulação de 2024 da Febraban e planalto.gov.br (Lei 662/1949). Não verificado (limites do README): se SMS e WhatsApp contam como "telefonemas", o alcance territorial da lei de SP, se a operação é signatária da autorregulação da Febraban, feriados estaduais e municipais e o texto consolidado do SARB depois da alteração (o relatório da Febraban fala em contato fora do horário só com agendamento ou consentimento e num art. 32-A que proíbe ligar por dívida vencida há mais de cinco anos).

### 9.11 Rastreabilidade

As tabelas que vêm de um registro de um provedor (`dim_contato`, `dim_endereco`, `ft_vinculo_empresa`, `ft_tentativa_contato`, `dim_empregador`) terminam com `_arquivo`, `_linha` e `_hash_arquivo` da aparição mais recente, como na silver (seção 4). A `dim_devedor` não tem essas colunas: a linha junta até três provedores, e nenhum trio de arquivo e linha a descreve; a origem de cada atributo se acha pelas tabelas filhas e pela silver. `hash_conteudo` e `hash_endereco` são usados só dentro da pipeline e não viram coluna da gold, porque não são portáveis entre motores (seção 8).

A tentativa liga-se ao par (CPF, contato); sem par, ao contato sem devedor de mesmo valor; sem nenhum dos dois, as chaves ficam `NULL` (AGENTS.md, "Colunas da gold") e são contadas por motivo no passo das tentativas.

### 9.12 O que não foi verificado na gold

- A probabilidade de fundir duas pessoas pela regra da seção 9.5; o formato oficial do RG e a validade dos números de RG.
- O enquadramento de SMS e WhatsApp, o alcance da lei de SP, a adesão à autorregulação bancária, os feriados locais e o texto consolidado do SARB (seção 9.10).
- Uma obrigação legal específica para bloquear por opt-out e por falecimento (seção 9.9).
- Se as entregas diárias são retratos completos ou parciais (seção 9.9).
- Os 342 grupos de complemento contra os 221 pares da seção 6.4, e o 960 contra o 962 da renda do beta (seção 9.8).
- Todos os números desta seção vêm de consultas descartáveis; os finais saem da execução, no corpo de cada commit.
