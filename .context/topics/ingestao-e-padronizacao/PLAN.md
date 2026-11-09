# Plano — ingestão e padronização (refeito em 2026-11-09)

Substitui o plano anterior, que misturava deduplicação com ingestão e criava uma camada de pouso fora do desenho do case. O branch `feat/ingestao-e-padronizacao` é refeito a partir da `develop`, reaproveitando só o que era bom do componente anterior.

## 1. Objetivo e base no enunciado

Levar os dados recebidos até a silver:
- a **ingestão** grava na bronze tudo o que foi recebido, sem transformar;
- a **silver** padroniza cada fonte isoladamente e deduplica cada tabela pela sua chave.

Base no enunciado:
- "Ingerir os dados dos três provedores: a carga histórica até 31/08/2026 e os dados diários incrementais de setembro/2026" (p. 1);
- "três provedores diferentes, cada um no seu próprio formato" (p. 1): alfa, beta e gama são fontes distintas, e a fusão é da gold;
- "um número que mudou de dono ou um contato ligado a vários CPFs" (p. 1) e os "pontos cegos" da régua (p. 1): por isso a silver guarda o histórico da relação devedor–contato;
- código reprodutível (p. 2) e consistência em deduplicações, conflitos e dados ruidosos (p. 3);
- as convenções do case: `ingestion/` lê sem transformar, as transformações ficam em SQL em `models/`, ausência é `NULL`, nenhuma linha que não exista na origem, janelas só com `ROW_NUMBER()` e `SUM()` com `ROWS BETWEEN`.

## 2. Decisões (fechadas com o dono em 2026-11-09)

### Camadas
| # | Decisão |
|---|---|
| C1 | O banco tem exatamente três camadas: bronze, silver e gold. Não há pasta de pouso: a ingestão grava direto na bronze, e o banco é recriado do zero a cada execução. |
| C2 | Cada provedor é uma fonte: `alfa`, `beta`, `gama`. O histórico de contatos é a fonte `cobranca`, porque é gerado pelo time de Cobranças (p. 1). Schemas `bronze_<fonte>` e `silver_<fonte>`, tabela com o nome da entidade. |
| C3 | A silver trabalha dentro de uma fonte só: tipos, limpeza, normalização, abertura de listas em linhas e deduplicação. Toda tabela que muda de grão tem teste de chave primária. O que cruza fontes ou carrega regra de negócio fica na gold. |

### Ingestão e bronze
| # | Decisão |
|---|---|
| I1 | A cada execução, a ingestão lê **todos** os arquivos e grava na bronze. Não há modos de carga, chave nem manifesto persistente; o pulo de arquivo já carregado (por caminho e hash) é a evolução para produção e entra no README. |
| I2 | Tabelas: `bronze_alfa.devedores`, `bronze_beta.devedores`, `bronze_gama.devedores` e `bronze_cobranca.contatos_realizados`, uma linha por linha recebida. No CSV, as colunas são a união dos cabeçalhos de todos os arquivos da entidade, em texto; uma coluna que um arquivo não tem fica `NULL` (o alfa terá `cpf` e `documento`). No JSONL, a coluna `registro` guarda o texto da linha. |
| I3 | Rastreabilidade em toda tabela: `_arquivo` (caminho relativo), `_linha` (onde o registro começa), `_hash_arquivo` (sha256), `_linha_original` e `_motivo_ilegivel`. Registro de cargas em `bronze_<fonte>.arquivos`: arquivo, entidade, hash, bytes, linhas e cabeçalho. É o padrão dos carregadores consagrados (Snowflake, Fivetran, Databricks, dlt, Airbyte), sem o horário da carga, a data de modificação e o id aleatório, que quebrariam as execuções idênticas. A tabela de equivalência vai para `docs/decisoes-de-modelagem.md`. |
| I4 | Só é ilegível a linha que o leitor não consegue separar em colunas: um CSV malformado ou em branco. O JSONL entra sempre como texto, e a validação do JSON fica na silver. Um byte fora do encoding interrompe a fonte, com o arquivo e a linha no erro (hoje nenhum arquivo tem esse problema). |
| I5 | Uma API grava a resposta como arquivo numa pasta versionada antes de ser lida; a partir daí vale o mesmo leitor e a mesma rastreabilidade. |
| I6 | A configuração `ingestion/fontes.yml` tem, por fonte e entidade: `formato`, `origem` e a lista de `arquivos` (`caminho` e `padrao`); `encoding` e `separador` são opcionais. Uma entidade pode ter vários locais (o histórico em `contact_data/` e as entregas em `contact_data/entregas_diarias/<provedor>/`), e todos vão para a mesma tabela. Um arquivo que case com duas entradas é erro, para nunca ser carregado duas vezes. Uma entidade nova num formato conhecido é só uma entrada; um formato novo é uma função `@leitor`; uma origem nova é uma função `@conector`. |

### Silver
| # | Decisão |
|---|---|
| S1 | Tabelas: `silver_alfa` {`devedores`, `devedores_contatos`}; `silver_beta` {`devedores`, `devedores_contatos`, `devedores_enderecos`}; `silver_gama` {`devedores`, `devedores_contatos`}; `silver_cobranca` {`contatos_realizados`, `contatos_realizados_provedores`}. |
| S2 | Toda a padronização acontece antes da deduplicação. A deduplicação usa `ROW_NUMBER() OVER (PARTITION BY <chave> ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`. |
| S3 | `devedores`: uma linha por documento normalizado (CPF só com dígitos, com os zeros perdidos repostos; o RG do beta fica com o tipo de documento e não vira CPF). Vale a versão mais recente: data de atualização da fonte, depois data de entrega e depois linha. A data de entrega sai do nome do arquivo; o histórico usa a variável `data_carga_historica: 2026-08-31` (p. 1). A data 2025-09-01 aparece só nos históricos. **Correção da medição (revisão do passo 4.10):** tratá-la como ausente mudaria o vencedor em 5 devedores no alfa, 2 no beta e 5 na gama (consultas em `analyses/medicao_ordenacao_devedores_*.sql`); a frase anterior, "não muda a escolha", media outra coisa. A regra está pendente de decisão; até lá, a data fica como veio na ordenação. |
| S4 | `devedores_contatos`: uma linha por (documento, tipo, contato normalizado), com a primeira e a última data de entrega em que o par apareceu e os atributos do provedor (tipo, principal) da aparição mais recente. |
| S5 | `contatos_realizados`: uma linha por `contato_id`; `contatos_realizados_provedores`: uma linha por (`contato_id`, provedor), abrindo o `alfa\|beta\|gama`. |
| S6 | Nomes da origem na silver, mas fixos no modelo. Quando a fonte tem variantes, vale o último nome usado (alfa: `documento`), ou um nome escolhido e documentado quando as variantes convivem (beta), juntando as outras com `COALESCE`. Um teste falha se a bronze ganhar uma coluna não declarada. |
| S7 | O endereço em texto é separado só por padrão estrito, ancorado do início ao fim. O texto original fica sempre, as partes ficam `NULL` quando a linha não segue o padrão, e um teste de ida e volta exige que as partes recomponham o original. Cobertura medida em 2026-11-09: 100% no alfa e nos dois formatos de texto da gama. O beta tem lista: vai para `devedores_enderecos`, com o `atual` como veio. |
| S8 | Os `atributos_extra` da gama viram colunas. Vazio vira `NULL`; `0,00` fica `0.00`. Nenhuma marcação interpretativa: as datas sentinela ficam como vieram, e quem as trata é a gold. |
| S9 | Linha sem chave (ilegível, cabeçalho repetido, documento vazio) não entra na silver e continua na bronze. Um teste com `severity: warn` mostra quantas ficaram de fora, por fonte. |
| S10 | O que se espera de cada provedor fica em `docs/contratos-de-dados.md`: nomes de coluna, formatos de data, layout do endereço e valores sentinela. Os testes fiscalizam o que dá para verificar; o resto é obrigação do provedor no contrato. |

## 3. Reaproveitado do componente anterior (branch arquivado `arquivo/ingestao-v1`)
- O leitor de CSV que guarda o texto original e a linha malformada com o motivo (modo estrito, registro em várias linhas físicas).
- O registro de leitores e conectores por nome (`@leitor`, `@conector`) e a configuração em YAML.
- A gravação em lote pelo DuckDB (`UNNEST` de uma lista por coluna). O commit `ff2924f` registra que ela é cerca de 30 vezes mais rápida que gravar linha a linha; esse número não foi conferido nesta sessão e será medido de novo no passo 4.1.
- As colunas de rastreabilidade e as do registro de arquivos.
- Os testes de leitura (linha truncada, CRLF, cabeçalho renomeado, cabeçalho repetido).

Fica de fora: os modos de carga, o planejamento de remoção, as partições, o manifesto em Parquet, o sufixo de reenvio, o hash por registro, a validação de JSON e o aviso de dias sem arquivo, que vai para a etapa 8.

## 4. Sequência de execução

Cada passo roda com o agente indicado, que lê este plano e o AGENTS.md. Os commits listados são os autorizados; o que a revisão do passo 4.10 apontar entra como commit próprio.

### 4.0 Git (orquestrador, com confirmação do dono)
- Renomear o branch atual para `arquivo/ingestao-v1` (só local, para consulta; o dono decide quando apagar).
- Criar `feat/ingestao-e-padronizacao` a partir da `develop`, levando a memória do `.context/` (inclusive o fechamento da fundação, que estava no commit `15e65a2`).
- Apagar `landing/` (fora do git, recriável).

### 4.1 Ingestão grava a bronze
- **Quem:** `engenheiro-python` (Sonnet 5.5 · high).
- **Fazer, com teste antes do código:** `ingestion/fontes.yml`, `leitores.py`, `conectores.py` e `main.py` conforme I1–I6. O `pipeline.py` apaga o banco, roda a ingestão e o `dbt build`. Tirar `landing/` do `.gitignore`. Atualizar o AGENTS.md (texto aprovado pelo dono).
- **Testes:** toda linha física de cada arquivo coberta; `arquivos.linhas` igual às linhas da tabela, por arquivo; arquivo só com cabeçalho registrado com 0 linhas; CSV malformado mantido com o motivo; JSONL inválido entra como texto; byte inválido interrompe com o arquivo e a linha; união de cabeçalhos (`cpf` e `documento`); histórico e entregas de locais diferentes na mesma tabela; arquivo que casa com duas entradas gera erro; um leitor novo registrado sem mexer no `main`; duas execuções geram tabelas idênticas.
- **Pronto quando:** carga real com zero linhas perdidas, `pytest`, `ruff check` e `verificar_reprodutibilidade.py` limpos.
- **Commit:** `feat: ingestão grava na bronze tudo o que foi recebido`.

### 4.2 Contrato da bronze
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** `models/bronze/<fonte>/_fontes.yml` com as tabelas como fontes do dbt, a descrição de cada coluna e os testes: rastreabilidade não nula, (`_arquivo`, `_linha`) único, linhas por arquivo iguais a `arquivos.linhas` e o teste de coluna não declarada (S6).
- **Commit:** `feat: contrato da bronze com descrição e testes de integridade`.

### 4.3 Macros de padronização
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** macros no subconjunto compatível com PostgreSQL, cada uma com teste singular: `somente_digitos`, `cpf_normalizado`, `cnpj_normalizado` (com o alfanumérico), `telefone_normalizado`, `email_normalizado`, `data_flexivel` (ISO, `dd/mm/aaaa`, epoch em ms), `valor_monetario` (S8), `data_do_nome_do_arquivo`.
- **Commit:** `feat: macros de padronização de documento, contato, data e valor`.

### 4.4 Silver alfa · 4.5 Silver beta · 4.6 Silver gama · 4.7 Silver cobrança
- **Quem:** `engenheiro-sql` (Sonnet 5.5; **high** no beta, por causa das 12 variantes de JSON).
- **Fazer:** as tabelas de S1 conforme S2–S9, cada uma com descrição, teste de chave primária e os testes do passo (o de ida e volta do endereço no alfa e na gama; a medição da data sentinela no beta).
- **Pronto quando:** toda linha da bronze com chave está representada, as chaves são únicas e as convenções estão limpas.
- **Commits:** `feat: silver alfa com devedores e histórico de contatos`; `feat: silver beta unificando as variantes de JSON`; `feat: silver gama com atributos extras e endereços`; `feat: silver cobrança com tentativas e provedores de origem`.

### 4.8 Documentação das decisões
- **Quem:** `analista-dados` (Opus 5.5 · medium).
- **Fazer:** criar `docs/decisoes-de-modelagem.md` (camadas, ingestão, a equivalência da rastreabilidade, o desvio de não guardar horário de execução, a deduplicação por chave, o histórico de contatos, por que a fusão é na gold, com os números medidos) e `docs/contratos-de-dados.md` (S10).
- **Commit:** `docs: decisões da ingestão e da silver e contratos de dados dos provedores`.

### 4.9 CI com a pipeline completa
- **Quem:** `engenheiro-python` (Sonnet 5.5 · medium).
- **Fazer:** `scripts/verificar_execucoes_identicas.py`, que roda a pipeline duas vezes e compara tabela a tabela; o CI passa a rodar a pipeline e esse script.
- **Commit:** `chore: CI roda a pipeline e prova que duas execuções dão o mesmo resultado`.

### 4.10 Revisão e fechamento
- `revisor` (Opus 5.5 · medium) lê o diff contra o enunciado, o AGENTS.md e este plano; `verificador` (Haiku 5.5 · low) roda tudo do zero.
- As correções viram commits próprios; depois, a memória do tópico e o merge `--no-ff` com `chore: integra ingestao-e-padronizacao na develop`.

## 5. Fora deste tópico
- A avaliação das bibliotecas Python (phonenumbers, rapidfuzz), que era o passo 2.7, sai deste tópico (decisão do dono, 2026-11-09). Com a silver em SQL, uma biblioteca Python só rodaria como modelo Python do dbt, e as regras nativas cobrem a padronização; a comparação de nomes entre provedores é trabalho da gold. Ela vai para o README como "o que eu faria".

## Anexo A — texto do AGENTS.md aprovado pelo dono (aplicado no commit do passo 4.1)

### A. Seção nova, depois de "Estilo do código"

#### Ingestão  (no AGENTS.md, título de nível `###`)

- **A ingestão grava a bronze.** `python -m ingestion.main` (ou `python pipeline.py`, que também recria o banco e roda o dbt) lê **todos** os arquivos recebidos a cada execução e grava uma linha por linha recebida em `bronze_<fonte>.<entidade>`, sem transformar. `contact_data/` é a zona bruta imutável. Não há cópia intermediária nem modos de carga: o banco é recriado do zero, então reler tudo é o que garante execuções idênticas.
- **Colunas.** No CSV, a união dos cabeçalhos de todos os arquivos da entidade, em texto (`NULL` onde o arquivo não tem a coluna); no JSON Lines, `registro` com o texto da linha. Em toda tabela: `_arquivo` (caminho relativo), `_linha`, `_hash_arquivo`, `_linha_original` e `_motivo_ilegivel`. O registro de cargas fica em `bronze_<fonte>.arquivos`.
- **Ilegível** é só a linha que o leitor não consegue separar em colunas; ela entra com o texto e o motivo, e nenhuma linha é descartada. Um byte fora do encoding interrompe a fonte, com o arquivo e a linha no erro.
- **Sem horário de execução, data de modificação ou id aleatório**: a rastreabilidade vem do arquivo, da linha e do hash.
- **Fonte nova.** Cada provedor ou sistema que produz dados é uma fonte. Para acrescentar:
  1. Formato e origem já existem: uma entrada em `ingestion/fontes.yml`.
  2. Formato novo: uma função em `ingestion/leitores.py` com `@leitor("nome")`.
  3. Origem nova (API, bucket): uma função em `ingestion/conectores.py` com `@conector("nome")`. Uma API grava a resposta como arquivo numa pasta versionada antes de ser lida.
  4. Declarar a tabela em `models/bronze/<fonte>/_fontes.yml`. O `main.py` não muda.

### B. Seção "Camadas e nomes": troca dos três primeiros itens e do item do dbt

Antes:
> - **bronze:** fiel à origem.
> - **silver:** padroniza cada fonte isoladamente: tipos, limpeza e deduplicação dentro da fonte.
> - **gold:** une as fontes, resolve conflitos e expõe o modelo dimensional.
> ...
> - O dbt exige nomes de modelo únicos, por isso o arquivo leva camada e fonte (`models/bronze/alfa/bronze_alfa_devedores.sql`). ...

Depois:
> - O banco tem três camadas:
>   - **bronze:** tudo o que foi recebido, como veio, gravado pela ingestão. `models/bronze/` guarda o contrato dessas tabelas (fontes do dbt, com descrição e testes), sem SQL.
>   - **silver:** trabalha dentro de uma fonte só: tipos, limpeza, normalização, listas abertas em linhas e deduplicação de cada tabela pela sua chave, com `ROW_NUMBER()`. Toda a padronização vem antes da deduplicação, e toda tabela que muda de grão tem teste de chave primária.
>   - **gold:** une as fontes, resolve conflitos, aplica as regras de negócio e expõe o modelo dimensional.
> - Cada provedor é uma fonte (`alfa`, `beta`, `gama`); o histórico de contatos é a fonte `cobranca`.
> ...
> - O dbt exige nomes de modelo únicos, por isso o arquivo leva camada e fonte (`models/silver/alfa/silver_alfa_devedores.sql`). ...
