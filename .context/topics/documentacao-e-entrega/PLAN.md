# Plano — documentação e entrega

> **Rascunho não aprovado — não executar.** Escrito em 2026-11-09 por um agente que perdeu o contexto, junto com os demais planos e sem aprovação. Será refeito na sessão própria da etapa 10 (entrega), decisão por decisão. Partes já superadas pelo plano refeito da ingestão (`ingestao-e-padronizacao/PLAN.md`): a pasta de pouso `landing/`, o manifesto da ingestão, o schema `analises` e qualquer decisão que contradiga as decisões C1–C3, I1–I6 e S1–S10.


## 1. Objetivo e base no enunciado

Fechar os entregáveis do enunciado e publicar o repositório com segurança:
- o ERD;
- a justificativa dos tipos;
- o README;
- o AGENTS.md atualizado;
- a revisão final contra os critérios de avaliação;
- a publicação no GitHub, com as regras de branch.

Base no enunciado:
- **README principal** "com a visão geral do projeto, premissas adotadas, raciocínio das transformações, conclusões
  das análises, limites das respostas e o que você priorizaria construir com mais tempo" (p. 2).
- **ERD** "em formato acessível (imagem, Mermaid ou link para dbdiagram)" (p. 1 e 2).
- **Justificativas técnicas**: "os tipos de dados atribuídos a cada coluna e os ganhos de integridade ou eficiência
  obtidos" (p. 2).
- **"Manter o AGENTS.md atualizado"** (p. 1).
- **Entrega** num repositório público no GitHub (p. 3).
- "Use apenas o que você consegue explicar" (p. 3).

## 2. Decisões herdadas

- `AGENTS.md` inteiro.
- `arquitetura-solucao/STATE.md`:
  - README com o selo do LinkedIn, a origem do case neutra e a voz no singular ou impessoal;
  - o desvio consciente do `process_time`, documentado;
  - o aviso de caminho longo no Windows;
  - o modelo `main` + `develop` com as regras de branch;
  - Dagster como extra possível.
- Checklist privado de pré-publicação (pasta privada fora do repositório).
- Tópicos 2 a 4: `docs/decisoes-de-modelagem.md`, `docs/monitoramento.md` e `docs/analises.md`.

## 3. Decisões abertas (para a aprovação única)

| # | Decisão | Proposta | Por quê |
|---|---|---|---|
| D1 | Como o dicionário de dados é feito | `scripts/gerar_dicionario.py` lê o `manifest.json` e o `catalog.json` do dbt (descrições do YAML e tipos reais do banco) e gera `docs/dicionario-de-dados.md` uma vez, no fim. A justificativa de cada tipo fica na descrição da coluna, no YAML. Sem checagem no CI | O dicionário sai do modelo real, sem digitação manual de tipos, e pode ser regenerado quando o modelo mudar, sem custo de manutenção no CI |
| D2 | Formato do ERD | Mermaid em `docs/erd.md`: a estrela da gold completa, com chaves e cardinalidade, e uma visão por camada (pouso → bronze → silver por fonte → gold) | O GitHub renderiza Mermaid sem ferramenta externa, e o enunciado aceita o formato |
| D3 | Como criar o repositório no GitHub | O `gh` não está instalado. Proposta: o dono cria o repositório vazio pela web; o orquestrador faz o push com confirmação e entrega o passo a passo das regras de branch para aplicar na interface. Alternativa: instalar o `gh` e aplicar as regras pela API | Ação externa e irreversível em parte: fica sob controle do dono |
| D4 | Nome do repositório | `collections-contact-risk` (decidido com o dono em 2026-11-09, na fundação) | Em inglês, diz o que o projeto resolve e não identifica a origem do case |

## 4. Sequência de execução

### 5.1 ERD
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Ler:** os modelos e YAMLs; o rascunho do ERD do tópico 3.
- **Fazer:** `docs/erd.md` conforme D2, conferido contra o `manifest.json` (toda chave estrangeira do diagrama existe
  como teste de relacionamento).
- **Commit:** junto com o 5.2.

### 5.2 Dicionário de dados e justificativa dos tipos
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium); o `analista-dados` (Opus 5.5 · medium) revisa as justificativas.
- **Fazer:**
  1. Justificativa de tipo em cada coluna da silver e da gold, no YAML. Exemplos:
     - `num_cpf` como `VARCHAR`, para não perder zeros à esquerda;
     - `sk_` como `INTEGER`;
     - valores em `NUMERIC` com precisão declarada;
     - `flag_` como `BOOLEAN`;
     - datas como `DATE` ou `TIMESTAMP`.
  2. `scripts/gerar_dicionario.py` (D1).
  3. **Medir os ganhos de integridade e eficiência:**
     - tamanho em disco da gold tipada × a mesma tabela toda em texto;
     - tempo de junção com chave `INTEGER` × chave textual, com `explicar_modelo.py`;
     - quantos valores inválidos os tipos e testes barram.
- **Pronto quando:** toda coluna tem descrição e tipo justificado, e o dicionário é regenerado sem diferença.
- **Commit:** `docs: ERD e dicionário de dados com justificativa dos tipos`, com "Ganho medido: ..." no corpo para o
  tamanho e para o tempo de junção.

### 5.3 README principal
- **Quem:** orquestrador (Opus 5.5), que tem o contexto do projeto inteiro.
- **Fazer:** o README em pt-BR, na primeira pessoa do singular ou impessoal, com:
  1. visão geral e arquitetura (camadas, diagrama curto);
  2. **premissas**;
  3. **raciocínio das transformações**, por camada;
  4. **conclusões das análises** (de `docs/analises.md`);
  5. **limites das respostas**;
  6. **o que eu priorizaria com mais tempo**;
  7. como rodar: requisitos, caminho curto no Windows, `uv`, `python pipeline.py`;
  8. qualidade: CI, testes, convenções;
  9. como usei IA: memória de contexto, skills e testes comparativos, agentes com modelo e esforço;
  10. o desvio consciente de não gravar horário de execução;
  11. autor, com o selo do LinkedIn.

  A origem do case aparece como "case técnico de dados (enunciado anonimizado)".
- **Pronto quando:** cada item do enunciado (p. 2) tem uma seção.
- **Commit:** `docs: README com premissas, conclusões, limites e próximos passos` — é a porta de entrada do projeto e
  responde, na ordem, a cada item que o enunciado pede para o README.

### 5.4 AGENTS.md final
- **Quem:** orquestrador.
- **Fazer:** registrar os padrões operacionais que surgiram na execução:
  - como adicionar uma fonte nova (entrada no `fontes.yml` → bronze → silver);
  - como rodar e verificar;
  - o monitoramento.

  Conferir que as 13 linhas originais do case continuam idênticas à cópia privada.
- **Commit:** `docs: AGENTS.md com as convenções finais e o passo a passo para uma fonte nova` — consolida as regras que
  nasceram durante a execução, para que outra pessoa ou outro agente continue o projeto sem quebrar o padrão.

### 5.5 Revisão final contra o enunciado
- **Quem:**
  - `revisor` (Opus 5.5 · **high**), sobre o repositório inteiro;
  - `verificador` (Haiku 5.5 · low), com a pipeline num clone limpo.
- **Fazer:**
  1. Tabela "pedido do enunciado → onde está a resposta", página a página, e os cinco critérios de avaliação.
  2. Clone local limpo → `python pipeline.py` → execuções idênticas. É a prova de reprodutibilidade a partir do
     estado inicial.
  3. Correções pelo agente responsável, com o commit do tipo certo.
- **Pronto quando:** nenhum pedido do enunciado fica sem resposta, e o clone limpo reproduz tudo.

### 5.6 Publicação (pede confirmação)
- **Quem:** orquestrador.
- **Fazer:**
  1. Checklist privado inteiro, mais a lista privada aplicada a todo o `git log -p`. Uma linha no log do checklist.
  2. Com a confirmação do dono: repositório (D3, D4), push de `main` e `develop`, e conferir o CI verde no GitHub.
  3. **Regras de branch:**
     - `develop`: PR obrigatório, 1 aprovação, aprovação do `CODEOWNERS` e CI verde;
     - `main`: bloqueada para todos, com exceção só para o administrador.
  4. O merge de `develop` para `main` fica com o dono.
- **Pronto quando:** CI verde no GitHub, regras ativas e checklist registrado.

### 5.7 Fechamento do projeto
- **Quem:** orquestrador.
- **Fazer:**
  1. Storytelling final: o resumo inicial completo (as respostas ao enunciado) e a seção "o que faltou e o que eu
     faria". Entram, por exemplo: Dagster para acompanhar as execuções, carga incremental com chave por hash, validação
     de telefone pelo plano de numeração oficial e um painel para a operação.
  2. `ctx.py complete` nos tópicos e `/c save`.
  3. Apagar os espaços de trabalho temporários.

## 5. Ganhos a medir

| O quê | Como | Onde entra |
|---|---|---|
| Espaço em disco com tipos × tudo em texto | tamanho das tabelas no DuckDB | commit 5.2 e README |
| Junção por chave `INTEGER` × textual | `explicar_modelo.py` | commit 5.2 e README |
| Reprodutibilidade a partir de um clone limpo | `verificar_execucoes_identicas.py` | README e storytelling |

## 6. Riscos e plano B

| Risco | Plano B |
|---|---|
| A busca privada acha algo já commitado | reescrever o histórico antes do primeiro push (o checklist exige isso) |
| CI falha só no Linux | rodar o mesmo comando com o caminho em POSIX e corrigir antes de publicar |
| README fica longo demais | detalhes para `docs/`, e o README só com o essencial e os links |

## 7. Pronto do tópico e capítulo do storytelling

**Pronto:**
- entregáveis do enunciado completos;
- repositório publicado com as regras ativas;
- checklist final registrado;
- storytelling completo.

**Capítulo "Entregar o que eu consigo explicar":**
- como a revisão final conferiu cada pedido;
- o que ficou de fora;
- por que ficou de fora.
