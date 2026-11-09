---
topic: monitoramento-e-analises
status: active
created: 2026-11-09
updated: 2026-11-09 08:30
scope:
  - models/gold/
  - analyses/
  - tests/
  - docs/monitoramento.md
  - docs/analises.md
  - docs/perfil-das-fontes.md
---
# monitoramento-e-analises

## Goal
Answer the brief's data-analysis items with reproducible data: ingestion anomaly detection and daily monitoring (moving average), validation and calibration of the risk scale against contact history, value of CNPJ enrichment, do-not-contact policy. Detailed steps in PLAN.md.

## Plan
<!-- "- [ ]" todo · "- [x]" done · "- [~]" dropped (add " — reason"). Done and dropped items move to HISTORY.md on save. -->
- [ ] 4.1 Daily delivery monitoring with moving average and alerts (PLAN.md §4)
- [ ] 4.2 Investigation and monitoring architecture doc (PLAN.md §4)
- [ ] 4.3 Validation and calibration datasets (PLAN.md §4)
- [ ] 4.4 Risk scale calibration (measured fix) (PLAN.md §4)
- [ ] 4.5 CNPJ value, regenerated source profile (PLAN.md §4)
- [ ] 4.6 Analysis conclusions (PLAN.md §4)
- [ ] 4.7 Review and merge (PLAN.md §4)

## Where we stopped
- Not started. Detailed plan: `.context/topics/monitoramento-e-analises/PLAN.md`; master plan (order, agents, commits): `.context/topics/arquitetura-solucao/PLAN.md`.
- Execution starts only after the plan review and the owner's single approval.

## Pending
<!-- Unconfirmed questions: "- [?] question (where it came up, date)". Never treat them as a standard until the user answers. -->
- [?] D1 ft_entrega_diaria grain = provider x reference date that received a daily file (same-day files summed, historical load excluded), with repeated and late records — awaiting the single approval after the plan review (2026-11-09)
- [?] D2 gap detection with ROW_NUMBER self-join (no LAG) — awaiting the single approval after the plan review (2026-11-09)
- [?] D3 7-delivery moving average with CAST(SUM AS NUMERIC)/SUM(1); weekday baseline only if measured false alarms — awaiting the single approval after the plan review (2026-11-09)
- [?] D4 alert flags + dbt singular test with severity warn — awaiting the single approval after the plan review (2026-11-09)
- [?] D5 analysis datasets as views in schema analises + dbt analyses/ for one-off queries; profile regenerated from silver — awaiting the single approval after the plan review (2026-11-09)
- [?] D6 outcome classes — awaiting the single approval after the plan review (2026-11-09)

- [?] docs/perfil-das-fontes.md says the gama 09-15 resend has 309 lines; the file has 311 CSV records without the header (found by a skill-eval agent, recounted 2026-11-09). Fix it when the profile is regenerated from silver in step 4.5.

## Decisions
<!-- Local to this topic, append-only: "- YYYY-MM-DD decision". -->
- 2026-11-09 Inherits the rules in AGENTS.md and the design decisions in arquitetura-solucao/STATE.md; PLAN.md is written in pt-BR because the owner reviews and presents it.

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
- case-tecnico-dados-cobranca (p.1-4): requirements and evaluation criteria (rule #1)
