---
topic: modelo-gold-e-regua
status: active
created: 2026-11-09
updated: 2026-11-09 08:30
scope:
  - models/gold/
  - ingestion/cnpj/
  - dados_externos/
  - docs/decisoes-de-modelagem.md
  - .context/raw/referencias/receita/
---
# modelo-gold-e-regua

## Goal
Merge the sources into a single trusted debtor registry as a star schema, apply the contact-risk scale to every debtor x phone/e-mail pair, build the do-not-contact list and enrich employment links with Receita Federal CNPJ open data. Detailed steps in PLAN.md.

## Plan
<!-- "- [ ]" todo · "- [x]" done · "- [~]" dropped (add " — reason"). Done and dropped items move to HISTORY.md on save. -->
- [ ] 3.1 Gold, risk scale and safeguards design (analyst) (PLAN.md §4)
- [ ] 3.2 Single debtor registry with conflict resolution (PLAN.md §4)
- [ ] 3.3 Contacts, debtor-contact fact and risk scale (PLAN.md §4)
- [ ] 3.4 Contact attempts in the model (PLAN.md §4)
- [ ] 3.5 Do-not-contact list (PLAN.md §4)
- [ ] 3.6 Reproducible CNPJ extract (PLAN.md §4)
- [ ] 3.7 Employment link enriched with CNPJ (PLAN.md §4)
- [ ] 3.8 Measured optimization, review and merge (PLAN.md §4)

## Where we stopped
- Not started. Detailed plan: `.context/topics/modelo-gold-e-regua/PLAN.md`; master plan (order, agents, commits): `.context/topics/arquitetura-solucao/PLAN.md`.
- Execution starts only after the plan review and the owner's single approval.

## Pending
<!-- Unconfirmed questions: "- [?] question (where it came up, date)". Never treat them as a standard until the user answers. -->
- [?] D1 star: dims devedor/contato/empregador/provedor/canal/desfecho; facts devedor_contato/devedor_vinculo/tentativa_contato — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D2 only valid CPF enters dim_devedor — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D3 conflict resolution rules + flag_conflito_identidade — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D4 three levels and candidate signals — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D5 single temporal cut D; risk logic in one macro regua_de_risco(data_corte) reused by topic 4 — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D6 INTEGER surrogate keys via ROW_NUMBER — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D7 derived datasets in their own schema `analises` (models/analises/), first one analises.lista_nao_contatar; gold keeps only dim_/ft_ — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D8 scripts/extrair_receita_cnpj.py: pinned, filtered (CNPJ list + its hash in ORIGEM.md), versioned extract in dados_externos/; pipeline stays offline — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] Contact-hour legal texts: confirm primary sources (from arquitetura-solucao) — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)

## Decisions
<!-- Local to this topic, append-only: "- YYYY-MM-DD decision". -->
- 2026-11-09 Inherits the rules in AGENTS.md and the design decisions in arquitetura-solucao/STATE.md; PLAN.md is written in pt-BR because the owner reviews and presents it.
- 2026-11-09 User direction on D7: the derived-datasets layer gets an English name like bronze/silver/gold, and is defined as the layer that feeds panels and dashboards directly from the data products. Exact name to be chosen when this topic's decisions are discussed.
- 2026-11-09 Inherited from ingestao-e-padronizacao decisions (2026-11-09): gold chooses the current version of each record (rule from D5), treats the 2025-09-01 default date (D8), interprets alfa salary 0.00 with evidence (D7); the multi-valued 'desc_provedores_origem' is replaced by a debtor x provider relation and the AGENTS.md 'Colunas da gold' rule is reworded accordingly (1NF); the CNPJ source enters through a new 'api_gov' connector as the proof that adding a source is easy, with the size of the change measured in the commit (check first whether the dados.gov.br API needs an access key).

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
- case-tecnico-dados-cobranca (p.1-4): requirements and evaluation criteria (rule #1)
