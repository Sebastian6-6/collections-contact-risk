---
topic: ingestao-e-padronizacao
status: active
created: 2026-11-09
updated: 2026-11-09 14:48
scope:
  - ingestion/
  - pipeline.py
  - tests/ingestion/
  - models/bronze/
  - models/silver/
  - macros/
  - scripts/
  - docs/decisoes-de-modelagem.md
  - docs/contratos-de-dados.md
---
# ingestao-e-padronizacao

## Goal
Ingestion writes everything received straight into bronze (one row per received line, lineage, no transformation); silver standardizes each source on its own and deduplicates each table by its own key. Plan redone with the owner on 2026-11-09; detailed steps and the approved AGENTS.md text (Annex A) in PLAN.md.

## Plan
<!-- "- [ ]" todo · "- [x]" done · "- [~]" dropped (add " — reason"). Done and dropped items move to HISTORY.md on save. -->
- [ ] 4.0 Git: rename current branch to arquivo/ingestao-v1, recreate feat/ingestao-e-padronizacao from develop carrying .context/, delete landing/ (owner confirms each action)
- [ ] 4.1 Ingestion writes bronze + AGENTS.md Annex A (PLAN.md §4)
- [ ] 4.2 Bronze contract: dbt sources, descriptions, tests (PLAN.md §4)
- [ ] 4.3 Standardization macros (PLAN.md §4)
- [ ] 4.4-4.7 Silver alfa, beta, gama, cobranca (PLAN.md §4)
- [ ] 4.8 docs/decisoes-de-modelagem.md + docs/contratos-de-dados.md (PLAN.md §4)
- [ ] 4.9 CI runs the pipeline twice and compares (PLAN.md §4)
- [ ] 4.10 Review, verification, merge (PLAN.md §4)
- [~] 2.7 Normalization libraries evaluation — dropped by the owner 2026-11-09, goes to README "o que eu faria"

## Where we stopped
- 2026-11-09: the first execution (old step 2.1, commit ff2924f, Parquet landing with 4 load modes) was judged wrong by the owner and is being redone; see arquitetura-solucao/STATE.md for the diagnosis. PLAN.md was rewritten and approved by the owner.
- Facts still valid from that run (re-check after 4.1): 92 files, 73,050 received lines; 16 unreadable lines (15 truncated JSON in beta historical, 1 cut line in gama 09-15); 1 repeated header in gama historical; missing days alfa 09-22 and beta 09-24/25; alfa deliveries: 11 files with header `cpf`, 18 with `documento`; CRLF in alfa/gama deliveries.
- Next: step 4.0 (needs the owner's confirmation per action), then execute from 4.1.
- For the 4.10 review: the personal style asks for sys.stdout.reconfigure(encoding="utf-8") in entry points (accents break when stdout is redirected on Windows).

## Pending
<!-- Unconfirmed questions: "- [?] question (where it came up, date)". Never treat them as a standard until the user answers. -->
- (none: the two agent choices from the old step 2.1 are void — load modes and the contatos dt_referencia no longer exist)

## Decisions
<!-- Local to this topic, append-only: "- YYYY-MM-DD decision". -->
- 2026-11-09 Inherits the rules in AGENTS.md and the design decisions in arquitetura-solucao/STATE.md; PLAN.md is written in pt-BR because the owner reviews and presents it.
- 2026-11-09 D1 decided (user, 2026-11-09): ingestion is one generic component. ingestion/main.py runs one data set per call (idempotent: a file already landed with the same sha256 is skipped) and ignores other sources' code; connectors (where data comes from: 'pasta' now, 'api_gov' in topic 3) live in ingestion/conectores.py and readers (how to read: csv, jsonl) in ingestion/leitores.py, each registered by name with a decorator, so a new function makes the connection exist without editing main. One data set = one table. Config ingestion/conjuntos.yml per data set (not per provider): origem, caminho, padrao, formato, modo_carga, chave (list, composite allowed; the content hash is always added for versions), data_no_nome as a mask like 'YYYY-MM-DD' (also YYYYMMDD, DD-MM-YYYY); schema/table by convention (landing, data set name); encoding/delimiter optional. modo_carga: full, snapshot (needs retencao), append, incremental (needs chave; optional coluna_operacao for CDC deletes, not implemented). Landing in Parquet: landing/<conjunto>/dt_referencia=YYYY-MM-DD/<arquivo>.parquet (hive style, key=value, chosen over plain YYYY/MM/DD because DuckDB/BigQuery only recognize key=value as a column and prune on it; dt_referencia over dt for clarity), one row per received line with the file's own columns as text plus the original line and lineage; contact_data/ stays the immutable raw zone. Bronze, silver and gold stay in DuckDB (option A: dbt-duckdb external materialization does not support incremental models yet). Each data set can be scheduled at its own pace; dbt runs must be serialized (DuckDB single writer).
- 2026-11-09 D2 decided (user): bronze = one view per data set, fields as text, with lineage; read from the Parquet landing via dbt-duckdb external_location (read_parquet with hive_partitioning and union_by_name).
- 2026-11-09 D3 decided (user): silver keeps every distinct version of each record, key (natural key, content hash); identical repeats collapse with first/last delivery date and count; lists become child tables keyed by (natural key, content hash, position) (measured: beta phones 1-3, addresses 1-2, gama contacts 2-4); composite fields are split into atomic columns (alfa endereco -> logradouro, numero, bairro, cidade; contatos provedor_origem 'alfa|beta|gama' -> child table tentativa x provedor); unparseable records go to silver_<fonte>.rejeitados with the reason; gama atributos_extra are kept.
- 2026-11-09 D4 decided (user): silver keeps the source column names (typed and cleaned); gold renames to the project prefixes.
- 2026-11-09 D5 decided (user): no ordering or 'current version' marker in silver; the current-version rule (source update date, file date, resend, file position, line) lives in gold.
- 2026-11-09 D6 decided (user): no special resend rule; the landing keeps both files, the manifest records the delivery type from a configurable name suffix, the truncated line goes to rejeitados and identical lines collapse by the silver key; sizes go to monitoring (topic 4).
- 2026-11-09 D7 decided (user, from the brief p.2 'cada provedor fornece o que tem disponível' and the case rule 'ausência é NULL, nunca zero'): silver turns empty into NULL and keeps a received '0,00' as 0.00 (measured: alfa sends empty 2843 times and 0,00 341 times; beta never sends zero, uses null 4418 times); gold decides with evidence whether 0.00 means no income or not informed.
- 2026-11-09 D8 decided (user): silver adds no interpretive flags; the 2025-09-01 default-date cohort is kept as received in silver and handled in gold.
- 2026-11-09 SUPERSEDES D1-D8 above (they were recorded as owner decisions by an agent that lost context; the owner never saw the load modes). Redesign closed with the owner in an arquitetura-solucao session: decisions C1-C3 (three layers, providers as sources + cobranca, silver works inside one source), I1-I6 (ingestion writes bronze directly with every file each run, no landing/modes/manifest; universal lineage columns; only unsplittable CSV lines are unreadable; API responses saved as files; ingestion/fontes.yml with a list of locations per entity) and S1-S10 (silver tables, standardize then dedup by each table's key with ROW_NUMBER, devedores latest + devedores_contatos history, contatos_realizados + provedores bridge, fixed column names, strict address split with round-trip test, no rejeitados table, data contracts) are in PLAN.md section 2. Python library evaluation dropped from this topic (README).

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
- case-tecnico-dados-cobranca (p.1-4): requirements and evaluation criteria (rule #1)
