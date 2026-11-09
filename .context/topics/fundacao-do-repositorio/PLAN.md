# Plano — fundação do repositório

## 1. Objetivo e base no enunciado

Deixar o repositório pronto para construir a pipeline com segurança:
- git com `main` e `develop`;
- dependências travadas e ambiente reprodutível;
- esqueleto dbt com um schema por camada e por fonte;
- ferramentas de qualidade configuradas;
- skills testadas contra uma linha de base;
- agentes definidos;
- CI.

Base no enunciado:
- **Código reprodutível**, que produz exatamente os mesmos resultados a cada rodada (p. 2).
- **Stack aberta** (p. 2).
- **Entrega como repositório público no GitHub** (p. 3).
- **Uso de IA permitido**, desde que eu consiga explicar o que foi feito (p. 3). Os testes das skills são a prova de
  que elas ajudam de verdade.

## 2. Decisões herdadas

- `AGENTS.md`: convenções do case; seções "Stack", "Camadas e nomes" e "Commits e branches"; regra "Dependências".
- `arquitetura-solucao/STATE.md` (decisões de 2026-11-08 e 2026-11-09):
  - DuckDB 2.0 e dbt Core 1.12 com dbt-duckdb 1.11;
  - Python 3.14;
  - `uv pip compile --universal`;
  - CI com main e develop;
  - plano de skills;
  - testes das skills no começo do desenvolvimento;
  - commits sem coautoria.
- Plano mestre: `../arquitetura-solucao/PLAN.md` (agentes, orquestração, formato dos commits).

## 3. Decisões (todas fechadas com o dono em 2026-11-09)

| # | Decisão | Decidido | Por quê |
|---|---|---|---|
| D1 | Python 3.14 e `uv` | Instalados em 2026-11-09 com o `winget` (o Python do sistema não tem `pip`): `uv` 0.13.7 e `gh` 2.103.3; `uv python install 3.14` trouxe o CPython 3.14.10 | Mantém a decisão da etapa 2 e não mexe no Python do sistema |
| D2 | Onde fica o ambiente virtual | `.venv` padrão dentro do repositório, criado com `uv venv`, ignorado pelo git. O README avisa que, no Windows, o clone deve ficar numa pasta com menos de ~100 caracteres | Testado em 2026-11-09: com o `uv`, o dbt-core 1.12.6 e o dbt-duckdb 1.11.1 instalam dentro deste repositório, e o maior caminho fica com 215 dos 260 caracteres, sem ligar o suporte a caminho longo. A falha da etapa 2 era do `pip` numa pasta temporária mais funda |
| D3 | Formato da configuração da ingestão | YAML (`ingestion/fontes.yml`), lido com o PyYAML, declarado no `requirements.in` como dependência direta | Escolha do dono: é o formato que o dbt usa no projeto inteiro. O PyYAML já vem com o dbt-core, então o ambiente não ganha pacote novo |
| D4 | Nome do repositório, do projeto dbt e do banco | Repositório `collections-contact-risk`; projeto dbt `collections_contact_risk`; banco em `banco/collections_contact_risk.duckdb`, ignorado pelo git | Um nome só para tudo, em inglês, dizendo o que o projeto resolve (risco de contato na cobrança) sem revelar a origem do case. O banco é recriado a cada execução e não é versionado |
| D5 | Usuário do GitHub no `CODEOWNERS` | `@Sebastian6-6` (público, confirmado pelo dono) | O `CODEOWNERS` dá ao dono a aprovação obrigatória dos PRs de terceiros |
| D6 | Fim de linha dos dados | `.gitattributes` com `contact_data/** -text` (bytes intactos) e `* text=auto eol=lf` no resto (confirmado) | O hash de cada arquivo entra na rastreabilidade; se o git converter CRLF, o hash muda entre Windows e Linux e a reprodutibilidade quebra |

## 4. Sequência de execução

### 1.1 Repositório, proteção e ponto de partida
- **Quem:** orquestrador.
- **Ler:** este plano; o checklist privado de pré-publicação.
- **Fazer:**
  1. `git init -b main`, depois `git config core.autocrlf false`. Ligar o hook privado com `git config core.hooksPath`
     (o caminho fica só no `.git/config`).
  2. `.gitattributes` (D6) e acréscimos no `.gitignore`: `*.duckdb`, `*.duckdb.wal`, `target/`, `logs/`,
     `dbt_packages/`, `.venv/`, `.pytest_cache/`, `.ruff_cache/`.
  3. Rodar o checklist privado inteiro e registrar uma linha no log dele.
  4. **Commit A em `main`.** Entram `contact_data/`, o `AGENTS.md` **original** (a cópia de segurança privada,
     colocada no índice sem tocar no arquivo atual), `.gitattributes` e `.gitignore`.
  5. **Commits B e C em `main`.** B traz o `AGENTS.md` atual e `docs/`; o diff de B mostra que as 13 linhas originais
     do case continuam iguais. C traz `.claude/` e `.context/`.
  6. `git switch -c develop` e `git switch -c chore/fundacao-do-repositorio`.
- **Pronto quando:**
  - o hook bloqueia um teste com caminho absoluto;
  - `git ls-files` não lista nada de `.context/local/`;
  - a busca do checklist dá zero.
- **Commits:**
  - `chore: dados e convenções recebidos com o case` — o ponto de partida fica registrado exatamente como chegou,
    para qualquer mudança posterior aparecer no histórico.
  - `docs: convenções do projeto e perfil das fontes` — as regras do projeto e o que os dados mostraram ficam
    versionados antes da primeira linha de código, e o diff prova que as convenções do case não mudaram.
  - `chore: memória de contexto e skills do projeto` — o desenho da solução, as decisões e as ferramentas da IA
    ficam visíveis para quem quiser entender como o projeto foi construído.

### 1.2 Ambiente Python
- **Quem:** orquestrador.
- **Fazer:** `uv`, `gh` e Python 3.14 já instalados (D1). Criar o `.venv` com `uv venv .venv --python 3.14` (D2) e
  anotar as versões para o README. O `.venv` de teste criado em 2026-11-09 é apagado e recriado aqui, a partir do
  `requirements.txt`.
- **Pronto quando:** `.venv\Scripts\python --version` mostra 3.14.x.
- **Commit:** nenhum; o ambiente não é versionado.

### 1.3 Dependências e ferramentas de qualidade
- **Quem:** `engenheiro-python` (Sonnet 5.5 · medium).
- **Ler:**
  - `AGENTS.md` (Dependências, Stack);
  - `.claude/skills/qualidade-python/references/ruff.md`;
  - `.claude/skills/qualidade-sql/references/convencoes-case.md`.
- **Fazer:**
  1. `requirements.in` só com as dependências diretas e faixas de versão: `dbt-core` 1.12, `dbt-duckdb` 1.11,
     `duckdb` 2.0, `pyyaml`, `sqlfluff` 4.5, `ruff`, `pytest`.
  2. `requirements.txt` gerado com `uv pip compile requirements.in --universal --python-version 3.14`.
  3. Instalar no ambiente virtual com `uv pip install -r requirements.txt`.
  4. `ruff.toml` e `.sqlfluff` copiados das referências validadas das skills.
  5. Configuração do pytest no `pyproject.toml`, só com o necessário.
- **Pronto quando:**
  - `pip check` limpo;
  - `dbt --version` mostra 1.12.x com duckdb 1.11.x;
  - `ruff check .` e `ruff format --check .` limpos;
  - os 24 testes das skills passam com `python -m pytest -q`.
- **Se falhar:**
  - se alguma dependência não tiver wheel para 3.14, registrar qual é e aplicar o plano B de D1;
  - se o dbt-duckdb 1.11 quebrar com o DuckDB 2.0, usar o DuckDB 1.5 LTS (plano B da etapa 2) e registrar o motivo.
- **Commit:** `chore: dependências travadas e ferramentas de qualidade` — instalar a partir de um único arquivo com
  todas as versões fixas é o que torna a execução reproduzível em outra máquina.

### 1.4 Esqueleto dbt com schema por camada e fonte
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Ler:**
  - `AGENTS.md` (Camadas e nomes);
  - `.context/converted/referencias-dbt-how-we-structure-6-mapping-folders-to-warehouse.md`;
  - skill `using-dbt-for-analytics-engineering`.
- **Fazer:**
  1. `dbt_project.yml`: projeto `collections_contact_risk`; bronze e silver como `view`, gold como `table`.
  2. `profiles.yml` na raiz, apontando para `banco/collections_contact_risk.duckdb` por caminho relativo.
  3. Macros `generate_schema_name` e `generate_alias_name`. O schema sai da pasta (`bronze/alfa` → `bronze_alfa`;
     `gold/...` → `gold`) e o nome da tabela sai do arquivo sem o prefixo de camada e fonte.
  4. Pastas `models/bronze`, `models/silver`, `models/gold`, `macros/` e `tests/`.
- **Pronto quando:** num teste descartável, fora do repositório e apagado depois, três modelos de exemplo viram
  `bronze_alfa.devedores`, `silver_alfa.devedores` e `gold.dim_exemplo`. `dbt parse --use-v2-parser` também passa.
- **Commit:** `feat: esqueleto dbt com schema por camada e fonte` — quem consulta o banco vê nomes limpos
  (`bronze_alfa.devedores`) e o dbt continua com nomes de modelo únicos, sem configurar nada à mão em cada modelo.

### 1.5 Agentes do projeto
- **Quem:** orquestrador.
- **Ler:** a seção 3 do plano mestre; a documentação de subagentes do Claude Code (campos `model`, `effort`,
  `skills`, `tools`), conferida na fonte oficial antes de escrever.
- **Fazer:**
  1. Criar `.claude/agents/engenheiro-python.md`, `engenheiro-sql.md`, `analista-dados.md`, `revisor.md` e
     `verificador.md`. O `revisor` e o `verificador` não recebem ferramentas de edição.
  2. Arquivar em `.context/raw/referencias/claude/`, conforme a regra de documentação de referência, as seções usadas
     da documentação de subagentes do Claude Code e do guia de escolha de modelos, e ingerir com `ctx.py ingest`.
- **Pronto quando:** `/agents` lista os cinco. Se não listar sem reiniciar, vale o plano B do plano mestre.
- **Commit:** `chore: agentes do projeto com modelo e esforço por papel` — cada tipo de tarefa usa o modelo mais
  barato que dá conta dela.

### 1.6 Testes comparativos das skills
- **Quem:** orquestrador, com 8 agentes `general-purpose` (Sonnet 5.5 · medium, o mesmo modelo que vai usar as skills)
  em paralelo e o Haiku 5.5 · low para corrigir os critérios de texto.
- **Ler:** `.claude/skills/qualidade-sql/evals/evals.json`, `.claude/skills/qualidade-python/evals/evals.json` e o
  roteiro da skill-creator.
- **Fazer:**
  1. **Rodadas:** 4 casos × (com a skill, sem a skill), num espaço de trabalho **fora do repositório**. Tempo e
     tokens de cada rodada são anotados.
  2. **Critérios objetivos**, enquanto as rodadas correm:
     - **SQL 1** (`silver_beta_devedores`):
       - `verificar_convencoes.py` sem erro e SQLFluff limpo;
       - uma CTE por etapa;
       - nenhum `SELECT *`;
       - RG não vira CPF com zeros à esquerda;
       - data em epoch e em ISO tratadas;
       - deduplicação com `ROW_NUMBER()` e `ROWS BETWEEN`;
       - renda ausente fica `NULL`, não zero;
       - JSON inválido sinalizado, nunca descartado em silêncio.
     - **SQL 2** (média móvel):
       - `SUM/SUM(1)` com `ROWS BETWEEN`, sem `AVG` e sem `LAG`;
       - o plano conferido com `EXPLAIN ANALYZE`.
     - **Python 1** (manifesto):
       - listagem ordenada;
       - hash por blocos;
       - `encoding="utf-8"`;
       - nenhum `datetime.now`;
       - testes escritos;
       - Ruff limpo;
       - `verificar_reprodutibilidade.py` sem achados.
     - **Python 2** (refatoração da gama):
       - sai o `loaded_at` com relógio;
       - nenhum `except` vazio;
       - listagem ordenada;
       - o cabeçalho repetido continua como registro;
       - o `json.loads` sai da ingestão.
  3. **Correção** por script sempre que possível; o Haiku só para o que é texto.
  4. Agregar com o `aggregate_benchmark` da skill-creator.
  5. Gerar o visualizador estático e **pausar** para o retorno do dono.
  6. Ajustar as skills com base no retorno e nas falhas. Uma segunda rodada, só nos casos afetados, é opcional e fica
     fora do caminho crítico.
  7. Um resumo sem caminhos (taxas de acerto, tempo, tokens) entra no README de cada skill.
- **Pronto quando:** a versão final de cada skill tem taxa de acerto maior que a linha de base, ou o motivo de não ter
  está registrado.
- **Commit:** `fix: ajustes nas skills após os testes comparativos`, com o corpo no formato:
  "Ganho medido: critérios atendidos X% sem a skill, Y% com a v1, Z% com a v2 (8 rodadas, mesmo modelo)". Se nada
  precisar mudar, o commit vira `docs: resultado dos testes comparativos das skills`.

### 1.7 CI no GitHub Actions
- **Quem:** `engenheiro-python` (Sonnet 5.5 · medium).
- **Fazer:**
  1. `.github/workflows/ci.yml`, em push e pull request para `develop` e `main`, Ubuntu e Python 3.14. Passos:
     instalar pelo `requirements.txt`, `ruff check`, `ruff format --check`,
     `.claude/skills/qualidade-sql/scripts/verificar_convencoes.py`,
     `.claude/skills/qualidade-python/scripts/verificar_reprodutibilidade.py`, `pytest` e `dbt parse --use-v2-parser`.
  2. `.github/CODEOWNERS` (D5).
- **Pronto quando:**
  - o YAML é válido;
  - cada comando do workflow roda localmente, no ambiente virtual, com saída limpa.

  O GitHub Actions só roda de verdade depois do push, no tópico 5.
- **Commit:** `chore: CI no GitHub Actions e dono do código` — quem abrir um PR com uma tabela nova sem teste ou fora
  das convenções é barrado antes do merge.

### 1.8 Revisão e fechamento
- **Quem:**
  - `revisor` (Opus 5.5 · medium), sobre o diff `develop...chore/fundacao-do-repositorio`;
  - correções pelo agente que fez o trabalho, via `SendMessage`;
  - `verificador` (Haiku 5.5 · low), para todos os comandos de checagem.
- **Fazer:**
  1. Correções da revisão como commits próprios (plano mestre, seção 5).
  2. Merge `--no-ff` na `develop` com a mensagem `chore: integra fundacao-do-repositorio na develop`.
  3. `/c save` deste tópico.
  4. Escrever o capítulo 1 do storytelling.
  5. Apagar o ambiente descartável usado no desenho.

## 5. Ganhos a medir

| O quê | Como | Onde entra |
|---|---|---|
| Taxa de acerto das skills (com e sem a skill, v1 e v2) | critérios do passo 1.6, corrigidos por script | corpo do commit 1.6 e README das skills |
| Tempo e tokens por rodada, com e sem a skill | notificação de cada agente, agregada | README das skills e storytelling |

## 6. Riscos e plano B

| Risco | Plano B |
|---|---|
| Alguma dependência sem wheel para Python 3.14 | Python 3.13 (D1) |
| Caminho longo no Windows quebra a instalação | ambiente virtual em caminho curto (D2); README explica |
| Agentes novos só aparecem depois de reiniciar a sessão | `general-purpose` com o mesmo modelo, esforço e skills |
| Hook bloqueia um commit legítimo | ajustar o termo na lista privada, nunca pular o hook |

## 7. Pronto do tópico e capítulo do storytelling

**Pronto:**
- `develop` com os commits deste plano;
- `verificador` verde;
- checklist privado registrado;
- nenhum caminho absoluto no histórico (`git log -p` passado pela lista privada).

**Capítulo "A fundação":**
- por que comecei pelo dado exatamente como recebido;
- como o hook protege o histórico;
- o que os testes das skills mostraram, com números;
- por que cada agente tem o modelo que tem.
