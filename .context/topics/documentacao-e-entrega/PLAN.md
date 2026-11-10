# Plano — documentação e entrega (etapa 10, aprovado em 2026-11-10)

Substitui o rascunho de 2026-11-09. Decisões aprovadas em bloco na rodada de fechamento (STATE.md, Decisions).

## 1. Base no enunciado (p. 2–3)
O README traz: visão geral, premissas, raciocínio das transformações, conclusões das análises, limites das respostas e o que eu priorizaria com mais tempo. Além dele: o ERD num formato acessível, a justificativa do tipo de cada coluna com os ganhos, o AGENTS.md atualizado e o repositório público no GitHub.

## 2. Decisões
- **D1. Dicionário:** `scripts/gerar_dicionario.py` lê o `manifest.json` e o `catalog.json` e gera `docs/dicionario-de-dados.md`. A justificativa do tipo vai na descrição de cada coluna, no YAML; uma seção traz os ganhos medidos (por exemplo: `DATE` contra texto, chave `INTEGER` contra `md5`, a G6).
- **D2. ERD:** `docs/erd.md`, em Mermaid. Traz a estrela da gold completa (`gold_devedores` e `gold_monitoramento`, com as chaves e as cardinalidades) e a visão por camada: bronze → silver por fonte → gold.
- **D3. Limites:**
  - (a) PostgreSQL nunca foi executado: declarado no README; um job de CI com serviço Postgres vai para "com mais tempo";
  - (b) o CI no GitHub é conferido no primeiro push;
  - (c) as 5 versões a menos do beta: tento isolar a causa por até 30 minutos; se não der, declaro;
  - mais os limites que vierem dos outros tópicos: hipóteses do loop vistas depois do corte, um mês de histórico, horário (SMS/WhatsApp, alcance da lei de SP e a ADI, signatária da Febraban), dados sintéticos e CNPJ alfanumérico.
- **D4. Referências:** cópia em `.context/raw/referencias/` só do que a licença permite: as leis (CDC, LGPD, Lei SP 17.832/2023, Leis 662/1949, 6.802/1980 e 14.759/2023), pela Lei 9.610/1998, art. 8º, IV; e as páginas do dbt, sob Apache 2.0. Cada cópia leva o cabeçalho de origem e é convertida com `ctx.py ingest`. Kimball, Microsoft Learn e Febraban SARB entram só como nota com link (`referencias/padroes-de-mercado/`). A fonte das licenças é `enriquecimento-cnpj/pesquisa-receita.md`, parte B.
- **D5. Publicação:**
  - rodo o checklist privado de pré-publicação (fora do repositório);
  - `gh repo create collections-contact-risk --private`, push da `develop` e da `main`;
  - a `main` recebe a `develop` por merge `--no-ff` só com tudo verde;
  - o primeiro run do CI é conferido, e cada falha é corrigida na `develop` num commit `fix:`;
  - com o CI verde, o checklist completo e nada vazando, o repositório passa a público (autorizado pelo dono em 2026-11-10).

## 3. Sequência
Branch `docs/documentacao-e-entrega` a partir da `develop`, depois dos outros três merges.

### 10.0 Padronização da estrutura (pedido do dono, 2026-11-10)
- **Quando:** depois dos três merges e antes do 10.2, num branch próprio `refactor/padroniza-estrutura` a partir da `develop`, para entrar de forma atômica.
- **Quem:** `engenheiro-python` (Sonnet 5.5 · medium).
- **Fazer:** nomes das pastas da raiz num só idioma, o inglês, que é o da maioria (por exemplo, `banco/` → `database/` e `dados_externos/` → `external_data/`); `contact_data/` fica, porque veio com o case. Atualizar todas as referências: código, `fontes.yml`, `profiles.yml`, CI, `.gitignore`, docs e AGENTS.md. Conferir a consistência do resto: pastas vazias, nomes duplicados e arquivos sem uso; juntar dois arquivos ou pastas que fazem a mesma coisa, quando isso não dificultar; dar nomes mais claros aos arquivos. O objetivo é facilitar a vida de quem abre o repositório para analisar o projeto. Menos é mais. Tudo dentro das convenções do case (AGENTS.md, 'Estrutura'): `ingestion/`, `models/bronze|silver|gold/` e `docs/` não mudam de nome nem de papel; as convenções do case prevalecem sobre qualquer renomeação.
- **Prova:** `verificador` APROVADO.
- **Commit:** `refactor: nomes de pasta num só padrão`, com o porquê.

### 10.1 Referências (pode correr antes, em paralelo, porque só toca em `.context/raw/referencias/`)
- **Quem:** `general-purpose` (Haiku 5.5).
- **Fazer:** D4.
- **Commit:** `docs: cópias das leis e do guia do dbt usados nas decisões`.

### 10.2 Dicionário e tipos
- **Quem:** `engenheiro-python` (Sonnet 5.5 · medium) escreve o script; `engenheiro-sql` (Sonnet 5.5 · medium) completa as descrições do YAML.
- **Commit:** `docs: dicionário de dados gerado do dbt com a justificativa dos tipos`.

### 10.3 ERD
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · low).
- **Commit:** `docs: ERD das camadas em Mermaid`.

### 10.4 README
- **Quem:** `analista-dados` (Opus 5.5 · medium).
- **Fazer:** todas as seções da p. 2, com as conclusões de `docs/analises.md`, as premissas (G e C) e os limites da D3. O componente de ingestão multi-fonte aparece como diferencial.
- **Estilo (pedido do dono, 2026-11-10):** só a estilização de `.claude/skills/context-manager/README.md`: linha "Criado por" com o badge do LinkedIn no topo, badges do shields.io com a stack (DuckDB, dbt, Python, CI) e o bloco de contato com o LinkedIn no fim. O conteúdo é o deste projeto.
- **Commit:** `docs: README com visão geral, premissas, conclusões e limites`.

### 10.5 Verificação final e merge
- `verificador` APROVADO e `revisor` sem achado que bloqueie, olhando o repositório inteiro contra o enunciado. Depois, merge `--no-ff` na `develop` e da `develop` na `main`, e a publicação (D5).

## 4. Quando chamar o dono
As mesmas condições do plano do `enriquecimento-cnpj`. Se aparecer algo no caminho, escolho a solução que mais se adequa ao case e que tem menor atrito com as decisões já tomadas, e a registro.
