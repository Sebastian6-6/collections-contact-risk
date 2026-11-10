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
- **Commit:** `docs: README com visão geral, premissas, conclusões e limites`.

### 10.5 Verificação final e merge
- `verificador` APROVADO e `revisor` sem achado que bloqueie, olhando o repositório inteiro contra o enunciado. Depois, merge `--no-ff` na `develop` e da `develop` na `main`, e a publicação (D5).

## 4. Quando chamar o dono
As mesmas condições do plano do `enriquecimento-cnpj`. Se aparecer algo no caminho, escolho a solução que mais se adequa ao case e que tem menor atrito com as decisões já tomadas, e a registro.
