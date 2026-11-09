# Plano — ingestão e padronização

## 1. Objetivo e base no enunciado

Ler as quatro fontes sem perder nenhuma linha. São elas:
- a carga histórica dos três provedores;
- as entregas diárias de setembro;
- o histórico de contatos.

Depois, padronizar cada fonte isoladamente até a silver: tipos, limpeza e deduplicação dentro da fonte.

Base no enunciado:
- "Ingerir os dados dos três provedores: a carga histórica até 31/08/2026 e os dados diários incrementais de
  setembro/2026" (p. 1).
- "Consistência no tratamento de deduplicações, conflitos cadastrais e dados incompletos ou ruidosos" (p. 3).
- Código reprodutível (p. 2).
- As convenções do case:
  - `ingestion/` lê sem transformar;
  - as transformações ficam em SQL;
  - ausência é `NULL`;
  - nenhuma linha que não exista na origem.

## 2. Decisões herdadas

- `AGENTS.md`: convenções do case; "Camadas e nomes"; "Stack", incluindo a reprodutibilidade sem horário de
  execução.
- `arquitetura-solucao/STATE.md`:
  - os achados da etapa 1 (chaves, esquemas, incidentes);
  - a regra de entrada de bibliotecas;
  - silver só por fonte.
- `docs/perfil-das-fontes.md`: os casos reais que os testes precisam cobrir.
- Fundação: YAML para a configuração (D3), banco em `banco/collections_contact_risk.duckdb` (D4) e `.gitattributes` que preserva os bytes dos dados
  (D6).

## 3. Decisões abertas (para a aprovação única)

| # | Decisão | Proposta | Por quê |
|---|---|---|---|
| D1 | Forma da área de pouso (o que o Python grava) | Schema `landing` com duas tabelas genéricas para todas as fontes. `landing.arquivos` é o manifesto, uma linha por arquivo recebido. `landing.registros` tem uma linha por linha lida: fonte, arquivo, número da linha, texto do registro e a marcação de linha legível ou não. No CSV, o registro vira um objeto JSON cabeçalho→valor, montado com o cabeçalho **daquele** arquivo (que fica guardado no manifesto); no JSON Lines, a linha fica como chegou. Cada registro leva também `hash_registro`, o hash do conteúdo recebido. A conversão do CSV é sem perda e reversível: um teste reconstrói os campos originais a partir do JSON, e `docs/decisoes-de-modelagem.md` explica por que isso não é transformação | O cabeçalho do alfa muda (`cpf` → `documento` a partir de 12/09) e a gama traz JSON dentro do CSV. Uma estrutura sem esquema fixo aceita isso sem quebrar, e uma fonte nova vira só uma entrada de configuração (regra 3 da hierarquia) |
| D2 | O que a bronze faz | Uma view por entidade de cada fonte (`bronze_alfa.devedores`, `bronze_beta.devedores`, `bronze_gama.devedores`, `bronze_contatos.tentativas`, `bronze_controle.arquivos`). Ela extrai os campos como **texto**, com a rastreabilidade (arquivo, linha, hash), sem converter tipos | A bronze fica comparável 1:1 com o arquivo; qualquer número da gold pode ser rastreado até a linha de origem |
| D3 | Entidades da silver por fonte | `devedores` (a versão mais recente de cada documento), `telefones`, `emails`, `enderecos` e `vinculos`, com a primeira e a última vez em que cada valor foi visto. Registros sem documento válido vão para `rejeitados`, com o motivo | Se a silver ficasse só com o registro mais recente, perderia o histórico de contatos que alimenta os sinais de risco (número que passou para outro CPF: 25,1% de contato errado). `rejeitados` cumpre "nunca descartar em silêncio" |
| D4 | Nomes das colunas na silver | O mesmo padrão de prefixos da gold (`num_cpf`, `nome_devedor`, `dt_atualizacao`…) | A coluna mantém o nome e o significado da silver à gold, e a união na gold fica trivial |
| D5 | Deduplicação dentro da fonte | `ROW_NUMBER()` por documento, nesta ordem, todas decrescentes: data de atualização da origem (a data sentinela de D8 conta como `NULL` e vai por último), data de referência do arquivo, `flag_reenvio` (o reenvio vence o original do mesmo dia), posição do arquivo no manifesto e número da linha | Resolve as chegadas atrasadas (7 a 10% em D-1 e D-2) e garante que o reenvio da gama de 15/09 vença o arquivo truncado, sem depender da ordem de leitura |
| D6 | Reenvios e registros repetidos | O manifesto marca `flag_reenvio` pelo nome do arquivo e guarda o hash do arquivo. O `hash_registro` de D1 permite contar, por entrega, os registros já recebidos antes (`qt_registros_repetidos`). Todos colapsam na deduplicação | O beta de 29/09 não tem `_reenvio` no nome e repete 353 das suas 761 linhas do dia 28: só o hash por registro enxerga esse caso. Nenhuma regra especial por arquivo |
| D7 | Zero que significa ausência | `salario_informado = "0,00"` (alfa) e equivalentes viram `NULL` na silver, e o caso fica documentado | Convenção do case: ausência é `NULL`, nunca zero |
| D8 | Coorte com data padrão | A data de atualização 2025-09-01, que aparece em cerca de 370 linhas por fonte, é tratada como sentinela: vira `NULL` na silver, com `flag_data_padrao`, e um teste confere o tratamento | Uma data padrão não indica o registro mais recente; tratá-la como data real faria a deduplicação escolher o registro errado |

## 4. Sequência de execução

### 2.1 Ingestão por configuração, manifesto e comando único
- **Quem:** `engenheiro-python` (Sonnet 5.5 · **high**, porque é onde moram os casos de borda).
- **Ler:**
  - `docs/perfil-das-fontes.md` (incidentes de entrega, esquemas);
  - skill `qualidade-python`;
  - as decisões D1 e D6.
- **Fazer, com o teste escrito antes do código:**
  1. `ingestion/fontes.yml`: para cada fonte, o padrão dos arquivos históricos e diários, o formato (csv ou jsonl),
     a expressão que tira a data do nome, a codificação e o separador. A fonte `contatos` entra do mesmo jeito.
  2. `ingestion/manifesto.py`: lista os arquivos em ordem, calcula o sha256 por blocos, a data de referência a
     partir do nome, `flag_reenvio`, a quantidade de bytes e de linhas e o texto do cabeçalho (que permite detectar
     mudança de esquema). A data vem do nome do arquivo, que é metadado da entrega, não um campo transformado.
  3. `ingestion/leitores.py`:
     - lê CSV com `newline=""` e JSON Lines;
     - uma linha que não dá para ler vira registro marcado, com o texto original e o motivo, e **nunca** derruba a
       leitura nem some.
  4. `ingestion/carga.py`: grava `landing.arquivos` e `landing.registros` no DuckDB, com o `hash_registro` (D1).
  5. `pipeline.py` na raiz: apaga o banco, roda a ingestão e roda `dbt build` pelo `dbtRunner`. É o comando único.
  6. Testes em `tests/ingestion/` com arquivos mínimos, um para cada caso:
     - linha truncada;
     - cabeçalho repetido no meio do arquivo;
     - CRLF;
     - cabeçalho renomeado;
     - JSON inválido;
     - nome com `_reenvio`;
     - dia sem arquivo;
     - CSV reconstruído a partir do JSON igual ao original (conversão reversível).
  7. Atualizar o AGENTS.md: o schema `landing`, o que conta como fonte (cada entrada do `fontes.yml`) e o passo a
     passo para incluir uma fonte nova.
- **Pronto quando:**
  - para cada arquivo, a soma das linhas lidas é igual à contagem do manifesto (zero linhas perdidas);
  - duas execuções geram `landing` idênticos;
  - `pytest`, `ruff` e `verificar_reprodutibilidade.py` limpos.
- **Commit:** `feat: ingestão por configuração com manifesto de arquivos` — cada linha recebida chega ao banco com a
  sua origem, inclusive as ilegíveis, e uma fonte nova entra pela configuração, sem código novo.

### 2.2 Bronze fiel à origem
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Ler:** D2; `.context/converted/referencias-dbt-how-we-structure-2-staging.md`; skill `qualidade-sql`.
- **Fazer:**
  1. `models/bronze/_fontes.yml` declarando `landing` como fonte.
  2. Um modelo por entidade (D2), com YAML de descrição e testes: `not_null` na rastreabilidade e unicidade de
     arquivo + linha.
  3. Campos extraídos como texto. Nenhuma conversão de tipo.
- **Pronto quando:**
  - a contagem por fonte na bronze bate com `landing.registros`;
  - SQLFluff e `verificar_convencoes.py` limpos;
  - `dbt build --select bronze` verde.
- **Commit:** `feat: bronze fiel à origem para alfa, beta, gama e contatos` — a bronze fica comparável linha a linha
  com o arquivo recebido, então qualquer valor da silver ou da gold pode ser rastreado até a origem.

### 2.3 Macros de padronização
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Ler:** a seção "PostgreSQL-compatible subset" de `qualidade-sql/references/otimizacao-duckdb.md`.
- **Fazer:** macros portáveis (PostgreSQL e DuckDB). O teste unitário do dbt testa modelos, não macros, por isso cada
  macro ganha um teste singular em `tests/macros/`: uma consulta que aplica a macro a entradas fixas e devolve as
  linhas em que o resultado difere do esperado. As macros:
  - `somente_digitos`;
  - `cpf_valido` (dígito verificador, módulo 11);
  - `cnpj_valido` (inclusive o CNPJ alfanumérico);
  - `normalizar_telefone` (DDI, DDD, nono dígito);
  - `normalizar_email`;
  - `data_flexivel` (ISO, `dd/mm/aaaa` e epoch em milissegundos, sem `strptime`);
  - `valor_monetario` (`"R$ 1.234,56"`, número ou vazio, com o zero tratado como ausência quando a fonte usa zero
    para isso, D7).
- **Pronto quando:** os testes singulares cobrem os formatos reais do perfil, e as macros rodam no DuckDB sem usar
  função exclusiva dele.
- **Commit:** `feat: macros de padronização de documento, telefone, e-mail, data e valor` — a mesma regra aplicada
  nas três fontes evita que o mesmo CPF pareça diferente só pelo formato.

### 2.4 Silver alfa
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** as entidades de D3 para o alfa, com a deduplicação D5, D7 e o cabeçalho que muda (`cpf` ou
  `documento`). CPF que perdeu os zeros à esquerda é completado até 11 dígitos só quando o tipo é CPF. A data sentinela
  (D8) é tratada aqui. Este commit também registra no AGENTS.md que a silver usa os mesmos prefixos de coluna da gold
  (D4).
- **Pronto quando:**
  - toda linha da bronze está numa entidade ou em `rejeitados`;
  - os testes do dbt passam (unicidade da chave, valores aceitos);
  - as convenções estão limpas.
- **Commit:** `feat: silver alfa com documento corrigido e histórico de contatos` — o alfa perde zeros do CPF e troca o
  nome da coluna no meio do mês; corrigir isso na fonte evita que o mesmo devedor apareça duas vezes na gold.

### 2.5 Silver beta
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · **high**: 12 variantes de JSON).
- **Fazer:** as mesmas entidades. As variantes:
  - `cpf` ou `documento{tipo,valor}`;
  - três nomes para o campo de nome;
  - endereço em lista ou objeto;
  - e-mail em lista ou texto;
  - telefone em texto ou objeto;
  - data em ISO ou epoch;
  - renda em número, texto "R$" ou nula.

  Os 24 registros com RG não viram CPF.
- **Pronto quando:** igual a 2.4, e cada variante está coberta por um teste unitário.
- **Commit:** `feat: silver beta unificando as variantes de JSON` — doze formatos para a mesma informação viram uma
  estrutura só, e o RG deixa de ser confundido com CPF.

### 2.6 Silver gama e tentativas de contato
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:**
  1. Gama: JSON dentro do CSV, com 3 formatos de endereço, CEP numérico e o cabeçalho repetido, que vai para
     `rejeitados` com o motivo. Os 22 JSON truncados viram contato ilegível, sinalizado.
  2. `silver_contatos.tentativas`: tipos, destino normalizado com as mesmas macros (para cruzar com os contatos
     cadastrados) e os provedores de origem.
- **Pronto quando:** igual a 2.4.
- **Commit:** `feat: silver gama e histórico de tentativas de contato` — o histórico de tentativas passa a usar a mesma
  normalização do cadastro, sem a qual não daria para validar a régua.

### 2.7 Avaliação das bibliotecas de normalização
- **Quem:** `analista-dados` (Opus 5.5 · medium). Os scripts de medição ficam fora do repositório.
- **Ler:**
  - a regra de entrada e as bibliotecas propostas (etapa 5 em `arquitetura-solucao/STATE.md`);
  - a documentação oficial de cada biblioteca, na versão atual.
- **Fazer:** comparar, nos dados reais da silver, só os dois casos em que a decisão de negócio pode mudar (e-mail e
  documento já são resolvidos pelas macros do 2.3):
  - `phonenumbers` × regra de DDD e nono dígito, confrontada com os desfechos `numero_errado`;
  - `rapidfuzz` × similaridade **portável** em SQL nos 510 CPFs com nomes diferentes entre provedores. A versão
    portável compara tokens normalizados (primeiro e último nome, sobreposição de nomes); `jaro_winkler_similarity`
    é exclusiva do DuckDB e fere o dialeto do case.

  Também decidir onde uma biblioteca rodaria, se entrar: modelo Python do dbt-duckdb ou nada. Isso fecha a pendência
  do desenho. A página da documentação do dbt-duckdb sobre modelos Python é arquivada em `.context/raw/referencias/`.
- **Pronto quando:** cada biblioteca tem uma decisão (entra ou não) com o número que a sustenta, e a similaridade de
  nome que o tópico 3 vai usar está definida.
- **Commit:** `docs: decisões de ingestão, padronização e bibliotecas`, que inaugura `docs/decisoes-de-modelagem.md`
  com:
  - pouso genérico;
  - sem horário de execução (o desvio consciente do `process_time` comum);
  - manifesto e reenvios;
  - deduplicação;
  - `rejeitados`;
  - zero como ausência e data sentinela;
  - bibliotecas.

  Se uma biblioteca entrar, um commit a mais: `feat: <biblioteca> na padronização de <campo>`, com a dependência no
  `requirements.in`, o modelo que a usa e o ganho medido no corpo.

### 2.8 CI com a pipeline completa
- **Quem:** `engenheiro-python` (Sonnet 5.5 · medium).
- **Fazer:**
  1. `scripts/verificar_execucoes_identicas.py`: roda a pipeline duas vezes, em dois bancos, e compara tabela a
     tabela (contagem e hash das linhas ordenadas).
  2. `scripts/verificar_estrutura_dbt.py`: lê `target/manifest.json` e exige descrição e pelo menos um teste em
     todo modelo.
  3. Os dois entram no `ci.yml`, junto com o SQLFluff sobre `models/`.
  4. A pasta `scripts/` entra no AGENTS.md (scripts de verificação do projeto).
- **Pronto quando:** os scripts têm testes e os dois passam localmente.
- **Commit:** `chore: CI roda a pipeline duas vezes e exige teste em todo modelo` — a reprodutibilidade que o enunciado
  pede deixa de ser promessa e vira verificação a cada PR.

### 2.9 Revisão, otimização medida e fechamento
- **Quem:**
  - `engenheiro-sql`: passada de desempenho da skill `qualidade-sql` nos 3 modelos mais pesados, com
    `explicar_modelo.py`;
  - `revisor` (Opus 5.5 · medium);
  - `verificador` (Haiku 5.5 · low).
- **Fazer:**
  1. Reescrever só o que mudar o plano real. Cada reescrita vira um `refactor:` com o ganho medido.
  2. Correções da revisão pelo agente que fez o trabalho, como commits próprios (plano mestre, seção 5).
  3. Merge `--no-ff` com `chore: integra ingestao-e-padronizacao na develop`.
  4. `/c save` e capítulo 2 do storytelling.

## 5. Ganhos a medir

| O quê | Como | Onde entra |
|---|---|---|
| Linhas perdidas na ingestão | manifesto × `landing.registros` × bronze, por arquivo | corpo do commit 2.1 e storytelling |
| Registros rejeitados por motivo e por fonte | contagem em `silver_<fonte>.rejeitados` | `docs/decisoes-de-modelagem.md` |
| CPFs recuperados pela padronização | documentos válidos antes e depois das macros | corpo do commit 2.3 |
| Tempo de execução e plano dos modelos pesados | `explicar_modelo.py`, antes e depois | corpo de cada `refactor:` |
| Ganho de cada biblioteca sobre a alternativa nativa | acerto contra os desfechos | `docs/decisoes-de-modelagem.md` |

## 6. Riscos e plano B

| Risco | Plano B |
|---|---|
| Gravar linha a linha no DuckDB fica lento | inserção em lote; o ganho medido vira `refactor:` |
| Alguma variante do beta não cabe numa macro portável | isolar numa macro com a diferença documentada |
| Codificação diferente de UTF-8 num arquivo | a codificação vem da configuração da fonte; o caso é registrado |

## 7. Pronto do tópico e capítulo do storytelling

**Pronto:**
- `python pipeline.py` do zero, verde;
- execuções idênticas;
- zero linhas perdidas;
- todo modelo com descrição e teste;
- `verificador` verde;
- merge na `develop`.

**Capítulo "Receber sem perder nada":**
- os incidentes reais de entrega e como cada um foi tratado;
- por que o pouso é genérico;
- os números de rejeição;
- o que as bibliotecas trouxeram ou por que ficaram de fora.
