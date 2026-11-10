---
topic: monitoramento-e-analises
status: completed
created: 2026-11-09
updated: 2026-11-10 10:20
completed: 2026-11-10
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
- [?] Inputs from the stage-6 gold design (modelo-gold-e-regua/PLAN.md, approved 2026-11-10), to take into D1-D6 when this topic is designed: (a) G1: aggregates that answer the brief are dbt analyses/ (compiled, not materialized), so D5 'datasets as views in schema analises' must be re-decided against G1; if a dataset is kept, cite the AGENTS.md Stack rule (analises is outside the table rule, H6); (b) the ingestion-monitoring fact goes to its own gold_<domain> schema (G2 schema), never gold_cobranca; (c) validation uses the single cut D = 2026-09-15 and the macro regua_de_risco(data_corte) built in the gold (G4c); 'pair missing from deliveries' is out of the point-in-time validation (gold point 7); (d) outcome classes (D6) are the gold column ft_tentativa_contato.tipo_desfecho, approved in the gold plan (contato_confirmado, terceiro, opt_out, falecido, sem_confirmacao); (e) the gold plan hands to this topic (stage 9) the validation at D, the accuracy matrix and the calibration; the measured refinement loop of the scale is planned back in modelo-gold-e-regua once this topic defines the metric (2026-11-10)
- [?] D1 ft_entrega_diaria grain = provider x reference date that received a daily file (same-day files summed, historical load excluded), with repeated and late records — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D2 gap detection with ROW_NUMBER self-join (no LAG) — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D3 7-delivery moving average with CAST(SUM AS NUMERIC)/SUM(1); weekday baseline only if measured false alarms — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D4 alert flags + dbt singular test with severity warn — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D5 analysis datasets as views in schema analises + dbt analyses/ for one-off queries; profile regenerated from silver — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [x] (resolved 2026-11-10 by the gold plan, G2b: tipo_desfecho = contato_confirmado, terceiro, opt_out, falecido, sem_confirmacao) D6 outcome classes — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)

- [?] docs/perfil-das-fontes.md says the gama 09-15 resend has 309 lines; the file has 311 CSV records without the header (found by a skill-eval agent, recounted 2026-11-09). Fix it when the profile is regenerated from silver in step 4.5.

## Decisions
<!-- Local to this topic, append-only: "- YYYY-MM-DD decision". -->
- 2026-11-09 Inherits the rules in AGENTS.md and the design decisions in arquitetura-solucao/STATE.md; PLAN.md is written in pt-BR because the owner reviews and presents it.
- 2026-11-10 Owner 2026-11-10 (closing round, bulk approval): D1 gold_monitoramento.ft_entrega_diaria, grain provider x reference day with >=1 daily file (historical load out); D2 gap via ROW_NUMBER self-join -> qt_dias_desde_entrega_anterior; D3 moving average by day type (weekday vs weekend) in PARTITION BY, SUM/SUM(1) ROWS BETWEEN n PRECEDING AND 1 PRECEDING (measured: plain 7-delivery MA gives 13 weekend false alarms at +-50%, day-type baseline 0, both true peaks kept); window/threshold tuned by Claude with acceptance: 6 known incidents detected, false alarms counted; D4 one categorical/qt_ column per question, no flags (situacao_volume, qt_arquivos, situacao_cabecalho, qt_registros_repetidos, qt_registros_atrasados, qt_linhas_ilegiveis) + singular warn test on the latest delivery; D5 no analises schema at all, everything in analyses/ (G1), profile regenerated from silver (fix 309 -> 311); validation at D with regua_de_risco(D) covering brief p.2 (accuracy matrix, calibration, signal weights with counts, error patterns, blind spots, false blocks, segmentation and channel strategy). Logic details are Claude's call during execution, same conventions.
- 2026-11-10 Owner 2026-11-10: OPTIONAL, only if time is left AFTER publication, in parallel: simplest possible e-mail alert when the pipeline fails (error or failing/warning tests). Design: scripts/notificar_falha.py with smtplib from the standard library, SMTP settings only from environment variables (never in the repo), called by pipeline.py when ingestion or dbt fails or a test fails/warns; tested with pytest against a local fake SMTP server (no real send). A real send needs the owner's credentials -> owner sets the env vars; documented in docs/monitoramento.md and README. Own branch feat/alerta-por-email, verificador before merge.

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
- case-tecnico-dados-cobranca (p.1-4): requirements and evaluation criteria (rule #1)
