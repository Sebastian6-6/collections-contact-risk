---
topic: ingestao-e-padronizacao
status: active
created: 2026-11-09
updated: 2026-11-09 08:30
scope:
  - ingestion/
  - pipeline.py
  - tests/ingestion/
  - models/bronze/
  - models/silver/
  - macros/
  - scripts/
  - docs/decisoes-de-modelagem.md
---
# ingestao-e-padronizacao

## Goal
Land every line of the four sources without loss (generic landing + file manifest, config-driven) and standardize each source on its own up to silver (types, cleaning, dedup within the source). Detailed steps in PLAN.md.

## Plan
<!-- "- [ ]" todo · "- [x]" done · "- [~]" dropped (add " — reason"). Done and dropped items move to HISTORY.md on save. -->
- [ ] 2.1 Config-driven ingestion, manifest and pipeline.py (PLAN.md §4)
- [ ] 2.2 Bronze faithful to the source (PLAN.md §4)
- [ ] 2.3 Standardization macros (PLAN.md §4)
- [ ] 2.4 Silver alfa (PLAN.md §4)
- [ ] 2.5 Silver beta (PLAN.md §4)
- [ ] 2.6 Silver gama and contact attempts (PLAN.md §4)
- [ ] 2.7 Normalization libraries evaluation (entry rule) (PLAN.md §4)
- [ ] 2.8 CI runs the pipeline twice and requires tests on every model (PLAN.md §4)
- [ ] 2.9 Measured optimization, review and merge (PLAN.md §4)

## Where we stopped
- Not started. Detailed plan: `.context/topics/ingestao-e-padronizacao/PLAN.md`; master plan (order, agents, commits): `.context/topics/arquitetura-solucao/PLAN.md`.
- Execution starts only after the plan review and the owner's single approval.

## Pending
<!-- Unconfirmed questions: "- [?] question (where it came up, date)". Never treat them as a standard until the user answers. -->
- [?] D1 generic landing (landing.arquivos + landing.registros, CSV records as lossless header->value JSON, hash_registro per record) — awaiting the single approval after the plan review (2026-11-09)
- [?] D2 bronze = text views per entity with lineage — awaiting the single approval after the plan review (2026-11-09)
- [?] D3 silver entities per source + rejeitados — awaiting the single approval after the plan review (2026-11-09)
- [?] D4 silver uses the gold column prefixes — awaiting the single approval after the plan review (2026-11-09)
- [?] D5 dedup order (source update date with sentinel as NULL, file reference date, flag_reenvio, manifest position, line) — awaiting the single approval after the plan review (2026-11-09)
- [?] D6 resends and repeated records (beta 09-29 repeats 353 of 761 lines from 09-28 without _reenvio) detected by record hash; collapse in dedup — awaiting the single approval after the plan review (2026-11-09)
- [?] D7 zero meaning absence becomes NULL (alfa salario 0,00)
- [?] D8 2025-09-01 default-date cohort treated as a sentinel (NULL + flag) — awaiting the single approval after the plan review (2026-11-09)

## Decisions
<!-- Local to this topic, append-only: "- YYYY-MM-DD decision". -->
- 2026-11-09 Inherits the rules in AGENTS.md and the design decisions in arquitetura-solucao/STATE.md; PLAN.md is written in pt-BR because the owner reviews and presents it.

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
- case-tecnico-dados-cobranca (p.1-4): requirements and evaluation criteria (rule #1)
