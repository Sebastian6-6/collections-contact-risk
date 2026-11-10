# Decisões de modelagem: ingestão e silver

Este documento registra como os dados recebidos chegam até a silver e por quê: as camadas, as fontes, a ingestão, a rastreabilidade e as regras da silver. A gold (base única, régua de risco) é de outro tópico e só aparece aqui quando uma decisão da silver existe para servir a ela.

- **Base:** o enunciado (`.context/converted/case-tecnico-dados-cobranca.md`, citado pela página), as convenções do case no `AGENTS.md` e as fontes externas listadas na seção 4 e na seção 5.
- **Números:** medidos em 2026-11-09 sobre a carga completa (92 arquivos, 73.050 linhas recebidas). Cada número vem do corpo de um commit do tópico ou de uma consulta indicada aqui. Os dados são sintéticos (p. 2) e cobrem um mês de entregas diárias; nenhum número daqui vale como estimativa para dados reais.
- **O que não foi verificado** está reunido na seção 7.

O que se espera de cada provedor (nomes de coluna, formatos, valores sentinela) fica em [contratos-de-dados.md](contratos-de-dados.md).

## 1. Camadas

O banco tem três camadas: bronze, silver e gold. Não há pasta de pouso entre os arquivos recebidos e a bronze.

| Camada | Papel | Onde está o código |
|---|---|---|
| bronze | tudo o que foi recebido, como veio, uma linha por linha recebida | gravada pela ingestão (`ingestion/`); `models/bronze/` guarda só o contrato (fontes do dbt com descrição e testes) |
| silver | padroniza e deduplica cada fonte isoladamente | modelos dbt em `models/silver/<fonte>/` |
| gold | une as fontes, resolve conflitos, aplica a régua | `models/gold/` (próximo tópico) |

**Por que três e não quatro.** O enunciado avalia "a clareza da arquitetura das camadas (bronze, staging/silver, marts/gold)" (p. 3). A primeira versão deste tópico gravava um pouso em Parquet e expunha a bronze como view sobre ele. O pouso era uma cópia a mais dos mesmos bytes: `contact_data/` já é a zona bruta imutável, e o banco é recriado do zero a cada execução. A cópia não acrescentava informação, só um lugar a mais para manter. Ela foi descartada.

**Por que a ingestão grava a bronze.** A convenção do case diz que `ingestion/` faz a "leitura dos arquivos dos provedores, sem transformação" e que as transformações ficam em SQL em `models/` (AGENTS.md, convenções do case). Gravar o texto recebido numa tabela é leitura sem transformação. Já interpretar o JSON, converter tipos e deduplicar é transformação e fica na silver. Por isso `models/bronze/` não tem SQL: as tabelas são declaradas como fontes do dbt, com descrição e testes de integridade.

**Materialização.** Bronze e silver são views, e a gold vira tabela física (`dbt_project.yml`). A view não duplica dados, e o banco é refeito a cada execução.

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

Toda tabela da silver carrega `_arquivo`, `_linha` e `_hash_arquivo`, e um teste exige as três em toda tabela da camada. A regra vem da seção "Stack" do AGENTS.md: a rastreabilidade de cada linha vem do arquivo, da linha e do hash de origem. Numa tabela em que cada linha vem de uma linha da bronze (`devedores`, `devedores_enderecos`, `contatos_realizados`), são as colunas dessa linha. Numa tabela que agrega várias aparições, são as da aparição mais recente: em `devedores_contatos`, a última linha da bronze em que o par (documento, tipo_contato, contato) apareceu. Em `contatos_realizados_provedores`, são as da linha do contato realizado que originou o par (contato, provedor_origem).

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
| `silver_alfa.devedores` | documento | 11.458 |
| `silver_alfa.devedores_contatos` | documento, tipo_contato, contato | 22.978 (11.970 telefones, 11.008 e-mails; 63 com documento `NULL`) |
| `silver_beta.devedores` | documento_tipo, documento | 11.321 (11.279 CPF, 42 RG) |
| `silver_beta.devedores_contatos` | documento_tipo, documento, tipo_contato, contato | 28.701 (17.246 telefones, 11.455 e-mails; 96 com documento `NULL`) |
| `silver_beta.devedores_enderecos` | documento_tipo, documento, posicao | 11.849 |
| `silver_gama.devedores` | documento | 11.436 |
| `silver_gama.devedores_contatos` | documento, tipo_contato, contato | 29.936 (15.691 celulares, 2.466 fixos, 11.779 e-mails; 100 com documento `NULL`) |
| `silver_cobranca.contatos_realizados` | contato_id | 15.053 |
| `silver_cobranca.contatos_realizados_provedores` | contato_id, provedor_origem | 24.774 |

Toda tabela tem teste de chave primária (`unique` ou `combinacao_unica`) e um teste `*_linhas_representadas`, que falha se uma linha da bronze não estiver representada: o documento em `devedores` ou, na linha sem documento, os contatos dela em `devedores_contatos`. Contagens de 2026-11-09, depois da segunda revisão da silver; nas tabelas de contatos, o `NULL` de `documento` é um valor da chave (seção 5.8).

### 5.2 Padronizar antes de deduplicar

Toda a padronização acontece numa etapa efêmera por fonte (`silver_<fonte>_devedores_padronizados`, que não vira tabela), antes de qualquer deduplicação. Deduplicar sobre o texto bruto trata como diferentes o mesmo CPF com e sem máscara, ou o mesmo telefone em formatos diferentes.

O exemplo medido é o alfa. Na fase de desenho, contei 3.279 pares (CPF, telefone) que só existiam em versões antigas do devedor. Essa contagem foi feita sobre o texto bruto e misturava formatos diferentes do mesmo número. Com o telefone normalizado, são 481 pares (commit 48507a8). A diferença é a razão desta regra.

As regras de formato ficam em macros (`macros/padronizacao/`), cada uma com teste singular em `tests/macros/`. Cada macro só ajusta o formato e devolve `NULL` para ausência. Nenhuma filtra linha nem decide regra de negócio; a validade do dígito verificador do CPF (`cpf_valido`) só informa.

### 5.3 Deduplicação pela chave de cada tabela

A deduplicação usa `ROW_NUMBER() OVER (PARTITION BY <chave> ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`, como pede a convenção do case para funções de janela. Em `devedores`, vale a versão mais recente:

```
ORDER BY <data de atualização> DESC NULLS LAST, data_entrega DESC NULLS LAST, _arquivo DESC, _linha DESC
```

A linha sem documento não entra em `devedores`: o filtro `documento IS NOT NULL` vem antes do `ROW_NUMBER`, para os `NULL` não formarem um grupo (seção 5.8).

- A data de atualização é a informada pelo provedor, com o nome que a fonte usa: `data_atualizacao` no alfa, `atualizado_em` no beta e `dt_ref` na gama (seção 5.9).
- `data_entrega` sai do nome do arquivo. O histórico não tem data no nome: só o arquivo configurado em `arquivo_historico` (nome exato) usa a variável `data_carga_historica: 2026-08-31`, a data em que o enunciado fixa a carga histórica (p. 1). Um arquivo diário sem data válida no nome fica com a data nula e o teste `entrega_diaria_sem_data_valida` reprova a pipeline.
- `_arquivo` e depois `_linha` desempatam: o original e o reenvio da mesma data (gama, 15/09) trazem a mesma linha, e sem o arquivo o vencedor era arbitrário. O resultado é determinístico porque (documento, atualização, entrega, arquivo, linha) não tem empate.

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

### 5.5 `devedores` e `devedores_contatos`, e por que não o histórico completo

Cada provedor gera duas tabelas de devedor:
- `devedores`: a versão mais recente de cada documento;
- `devedores_contatos`: uma linha por (documento, tipo_contato, contato normalizado) sobre **todas** as linhas da bronze, inclusive as de documento vazio ou zerado (com `documento` `NULL`, seção 5.8), com a primeira e a última data de entrega em que o par apareceu e os atributos do provedor (`tipo` do telefone, `principal`) da aparição mais recente.

O motivo é o risco do enunciado: "um número que mudou de dono ou um contato ligado a vários CPFs" (p. 1). A versão atual do devedor perde os contatos que saíram dela, e são justamente esses que mostram a troca de dono. Medido: 481 telefones do alfa e 922 telefones e 91 e-mails do beta só aparecem em versões anteriores à atual (commits 48507a8 e ddc2107). Na análise exploratória, telefones que passaram para outro CPF entre o histórico e as entregas tiveram 25,1% de contato errado em 1.014 tentativas ([perfil-das-fontes.md](perfil-das-fontes.md)).

| Opção | Ganho | Custo |
|---|---|---|
| Versão atual + histórico da relação devedor–contato (adotada) | guarda exatamente o que a régua usa (quando cada contato apareceu e sumiu) | os outros atributos (nome, renda, endereço) ficam só na versão atual |
| Histórico completo do registro (SCD tipo 2, como os snapshots do dbt) | toda mudança de qualquer atributo | nenhuma pergunta do enunciado precisa dele; o snapshot do dbt depende de estado persistido, e o banco é recriado a cada execução |
| Só a versão atual | mais simples | perde os 481 + 922 telefones e 91 e-mails acima |

O desenho adotado é próximo do que o Data Vault chama de satélite de efetividade num link: o histórico da relação, e não do registro inteiro. As fontes são a documentação de snapshots do dbt (cópia em `.context/raw/referencias/dbt/snapshots.md`, Apache 2.0) e, como referência secundária, https://www.wikiwand.com/en/Data_vault_modeling.

No beta, os endereços vêm em lista e vão para `devedores_enderecos`, com a lista da versão atual e o campo `atual` como veio. O objeto `endereco` único vira a posição 1.

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

### 5.8 Linhas sem chave e documento que não identifica ninguém

Uma linha sem chave (ilegível, cabeçalho repetido) não entra na silver e continua na bronze. Documento vazio ou só com zeros (`0`, `000.000.000-00`, `00000000000`) é ausência de chave: `documento` fica `NULL` antes de qualquer deduplicação, e a linha nunca vira devedor. O autor decidiu isso em 2026-11-09, a partir de "ausência é `NULL`, nunca zero" (AGENTS.md, convenções do case).

| Opção | Ganho | Custo |
|---|---|---|
| `NULL`, fora de `devedores`, com os contatos em `devedores_contatos` com `documento` `NULL` (adotada) | nenhuma pessoa é fundida sob um documento falso; os contatos dessas linhas continuam disponíveis | a chave de `devedores_contatos` tem de tratar `NULL` como valor |
| Manter o documento zerado como chave (como estava) | nada a mudar | juntava pessoas diferentes: 3 nomes distintos em 3 linhas do alfa e 8 em 9 linhas do beta (por nome, sem normalizar) ficavam num único devedor |
| Descartar a linha inteira (como era com o documento vazio) | simples | perdia os contatos dessas linhas |

O plano falava em 5 pessoas diferentes no CPF zerado do beta; medi 8 nomes distintos em 9 linhas e não investiguei a diferença.

**Como funciona.**
- `cpf_normalizado` devolve `NULL` para documento vazio ou só com zeros, e o RG do beta passa pela macro `nulo_se_so_zeros`. No beta, `documento_tipo` também fica `NULL` quando não há documento. O mesmo vale para o `cpf_alvo` da cobrança (nenhuma linha cai nisso hoje; o teste `documento_que_nao_identifica_ninguem` confere todas as tabelas).
- `devedores` filtra `documento IS NOT NULL` antes do `ROW_NUMBER`, para os `NULL` não formarem um grupo.
- `devedores_contatos` recebe os contatos dessas linhas. O `GROUP BY` e o `ROW_NUMBER` agrupam `NULL` com `NULL`, então esses contatos são deduplicados só por (`tipo_contato`, `contato`) entre as linhas sem documento, com a primeira e a última entrega e a rastreabilidade da aparição mais recente. A junção que devolve essa rastreabilidade usa `IS NOT DISTINCT FROM`, e um par sem documento nunca se junta a um par de documento válido (teste unitário nas três fontes).
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

Colunas criadas, com nome próprio: `tipo_contato`, `contato` (o valor normalizado, que junta campos diferentes de telefone e e-mail), `data_entrega`, `data_primeira_entrega`, `data_ultima_entrega`, `posicao`, e as partes do endereço do alfa.

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

Rastreabilidade: `_linha` é `BIGINT` e `_arquivo` e `_hash_arquivo` são texto.

### 5.11 Fuso horário: Brasília

Decisão do autor (2026-11-09; AGENTS.md, "Ingestão"): datas e horas que chegam sem fuso são tratadas como horário de Brasília, e os valores em epoch são convertidos para esse fuso (UTC−3, sem horário de verão desde o Decreto 9.772/2019). Aplica-se ao `atualizado_em` do beta em epoch (2.784 valores, todos entre 09:00 e 23:59 UTC, medidos em 2026-11-09: nenhum muda de dia na conversão), às datas ISO e `dd/mm/aaaa` e à `data_hora` da cobrança. Uma data escrita com fuso explícito (`2026-09-02T10:30:00-03:00`) vale a data local escrita. O fuso é a regra do projeto, e não uma informação confirmada pelos provedores.

### 5.12 UF

Todas as colunas de UF da silver (`silver_alfa.devedores`, `silver_beta.devedores_enderecos`, `silver_gama.devedores`) passam por `uf_normalizada`: `UPPER(TRIM(valor))`, e só vale se for uma das 27 UFs; vazio ou fora do domínio dá `NULL`. Medido na versão atual de cada devedor: no alfa, 343 UFs fora do padrão de maiúscula (`sp` 98 passou a `SP`, e o total de SP foi de 2.902 para 3.000) e 27 `XX` que viraram `NULL`; beta e gama já vinham no domínio. O `XX` é o preenchimento do provedor para UF desconhecida e está no contrato ([contratos-de-dados.md](contratos-de-dados.md)).

### 5.13 CNPJ do empregador

Regra (macro `cnpj_normalizado`, sobre o CNPJ sem máscara de `cnpj_sem_mascara`): só letras e dígitos, em maiúsculas. Com 14 caracteres, fica. Com menos, completa com zeros à esquerda se o resultado tiver dígitos verificadores válidos. Com 12 caracteres e sem essa possibilidade, calcula os dois dígitos pela regra oficial da Receita: cada caractere vale o código ASCII menos 48, os pesos vão de 2 a 9 da direita para a esquerda e recomeçam, resto 0 ou 1 dá dígito 0 e senão o dígito é 11 menos o resto, e o segundo dígito usa o primeiro anexado (https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj/manual-dv-cnpj.pdf, acessado em 2026-11-09). A macro foi conferida com 00.000.000/0001-91 (dígitos 91) e com o exemplo alfanumérico do manual, 12.ABC.345/01DE (dígitos 35).

Medido sobre as linhas recebidas: 14 caracteres em 46.276 linhas, todas válidas, 13 CNPJs distintos; 12 caracteres em 980 linhas, que completam sempre num dos mesmos 13; 13 caracteres em 1.528 linhas do alfa (2 valores, completam com um zero), 3 caracteres em 784 linhas do alfa (`191`, que completa para `00000000000191`) e um valor de 17 caracteres na gama, que é o texto do cabeçalho repetido (`cnpj_empregador_raw`). Na silver (versão atual de cada devedor, 29.300 com CNPJ preenchido) os CNPJs válidos de 14 caracteres passaram de 28.723 para 29.300 (os 577 de 12 caracteres: alfa 507, beta 41, gama 29) e os valores distintos por fonte, de 26, 24 e 22 para 13, 13 e 13.

Limitação da base: o que não encaixa em nenhuma regra (mais de 14 caracteres, ou menos de 14 sem regra que o complete) fica como veio. Hoje nenhum valor da silver cai aí (o único de 17 caracteres é o cabeçalho repetido, que não está em nenhuma tabela); o aviso `cnpj_do_empregador_fora_da_regra` o mostra se aparecer, e o teste `cnpj_do_empregador_com_digito_verificador_valido` reprova a pipeline se algum CNPJ de 14 caracteres tiver dígitos inválidos. Completar com zeros e calcular os dígitos recompõem o que a origem escreveu sem os zeros à esquerda ou sem os dígitos; nenhuma delas adivinha um empregador, mas a regra supõe que o provedor mandou a base certa. Custo: reler as três colunas de CNPJ da silver foi de 0,37 s para 0,65 s (mediana de 7 execuções).

## 6. Escolhas de formato

**Confirmadas pelo autor em 2026-11-09** (e já aplicadas):
- O documento "0" e o CPF zerado não são chave: viram `NULL` (seção 5.8).
- A data em epoch (ms) do beta é convertida em UTC−3, e as datas sem fuso valem como horário de Brasília (seção 5.11).
- O CNPJ de 12 caracteres é completado pela regra oficial da Receita (seção 5.13); antes ficava como veio.
- Os nomes de coluna da origem não mudam na silver (seção 5.9).
- A data 2025-09-01 fica como veio na ordenação (seção 5.4).
- O padrão estrito de endereço fica, e a ordem bairro → cidade é do provedor (seção 5.7).
- UF em maiúscula, com o que está fora das 27 UFs como `NULL` (seção 5.12).
- `vinculo_empresa_desde` é `DATE` no dia 01, com a descrição de que o valor é um mês (seção 5.10).

**Ainda a confirmar:**
- CPF com mais de 11 dígitos não é cortado.
- O telefone perde o `55` inicial só quando tem 12 ou 13 dígitos.
- Valor com vírgula usa a vírgula como separador decimal; sem vírgula, o ponto.
- O RG do beta fica com letras e dígitos, sem zeros repostos.

## 7. O que não foi verificado

- **Versões PostgreSQL das macros.** As macros com `adapter.dispatch` têm uma versão DuckDB, executada e testada, e uma versão PostgreSQL escrita só a partir da documentação, nunca executada (não há instância PostgreSQL no projeto): `json_ou_nulo` (`IS JSON`, `CAST AS JSONB`), `data_iso_ou_nulo` e `timestamp_ou_nulo` (`pg_input_is_valid`, PostgreSQL 16 ou mais novo), `json_texto` e `json_abrir_lista` (`jsonb_array_elements ... WITH ORDINALITY`). `STRING_TO_ARRAY` com `UNNEST` existe nos dois motores, mas só rodou no DuckDB. As macros novas (`cnpj_*`, `uf_normalizada`, `mes_como_data`, `nulo_se_so_zeros`) usam só `ASCII`, `SUBSTRING`, `LPAD`, `UPPER`, `CASE`, o resto inteiro (`%`) e os operadores `~` e `!~`, que existem nos dois motores, mas também rodaram só no DuckDB. A junção `IS NOT DISTINCT FROM` do histórico de contatos não usa hash join no PostgreSQL.
- **Testes genéricos fora do lint.** O SQLFluff com o templater do dbt não analisa os arquivos de `{% test %}` em `tests/generic/`. O uso de `graph.sources` nesses testes foi verificado só pela execução, não na documentação do dbt.
- **Números dos commits que não reproduzi:** o 0 do alfa e o 35 da gama para a data 2025-09-01, e os 87 vencedores da gama que mudariam frente à ordem só por entrega (seção 5.4). Os números reproduzidos estão nas consultas de `analyses/`; o 60 de uma refeita anterior vinha dos 58 empates entre original e reenvio, já eliminados. Também não investiguei por que medi 8 nomes distintos sob o CPF zerado do beta (o plano dizia 5) e 81 tentativas da cobrança nos contatos sem documento (o plano dizia 79).
- **Fuso horário:** a origem não traz fuso, e o horário de Brasília é uma regra do projeto, não uma informação confirmada pelos provedores.
- **Desempenho:** os tempos (pipeline de cerca de 20 s com os testes, gravação em lote de 53 a 74 vezes mais rápida) foram medidos numa única máquina.
