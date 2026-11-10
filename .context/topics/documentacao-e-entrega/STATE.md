---
topic: documentacao-e-entrega
status: active
created: 2026-11-09
updated: 2026-11-09 08:30
scope:
  - README.md
  - AGENTS.md
  - docs/
  - scripts/gerar_dicionario.py
  - .github/
---
# documentacao-e-entrega

## Goal
Close the brief's deliverables (ERD, type justifications, README, AGENTS.md), run the final review against the evaluation criteria and publish the repository safely with branch rules. Detailed steps in PLAN.md.

## Plan
<!-- "- [ ]" todo · "- [x]" done · "- [~]" dropped (add " — reason"). Done and dropped items move to HISTORY.md on save. -->
- [ ] 5.1 ERD in Mermaid (PLAN.md §4)
- [ ] 5.2 Data dictionary and type justifications (measured gains) (PLAN.md §4)
- [ ] 5.3 Main README (PLAN.md §4)
- [ ] 5.4 Final AGENTS.md (PLAN.md §4)
- [ ] 5.5 Final review against the brief + clean-clone reproducibility (PLAN.md §4)
- [ ] 5.6 Publication (asks for confirmation) (PLAN.md §4)
- [ ] 5.7 Project close and final storytelling (PLAN.md §4)

## Where we stopped
- Not started. Detailed plan: `.context/topics/documentacao-e-entrega/PLAN.md`; master plan (order, agents, commits): `.context/topics/arquitetura-solucao/PLAN.md`.
- Execution starts only after the plan review and the owner's single approval.

## Pending
<!-- Unconfirmed questions: "- [?] question (where it came up, date)". Never treat them as a standard until the user answers. -->
- [?] D1 dictionary generated from dbt manifest/catalog — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] D2 ERD in Mermaid (gold star + per-layer view) — to close one by one with the owner in an arquitetura-solucao session before this topic runs (2026-11-09)
- [?] To verify or declare in README "limites" (handed over by ingestao-e-padronizacao, 2026-11-10): (a) PostgreSQL `default__` versions of the dispatched macros (json_*, data_iso_ou_nulo, timestamp_ou_nulo, cnpj_*, uf_normalizada, mes_como_data) and `upper` with accents were never executed (no PG instance); hash_conteudo/hash_endereco text is not portable across engines (CAST text may differ) while the dedup result should be — run on a PG 16+ instance or declare; (b) CI never ran on GitHub Actions (local only; clean-runner needs like `dbt deps` unverified) — check on the first push; (c) upper case removed 5 beta history versions (17,866 -> 17,861) and the exact cause was not isolated — isolate or declare.

## Decisions
<!-- Local to this topic, append-only: "- YYYY-MM-DD decision". -->
- 2026-11-09 Inherits the rules in AGENTS.md and the design decisions in arquitetura-solucao/STATE.md; PLAN.md is written in pt-BR because the owner reviews and presents it.
- 2026-11-09 D3 decided (user): gh is installed and the orchestrator does ALL repository configuration (create repo, push, rulesets) via gh, each external action still confirmed. gh auth login must be run by the user once. Repository name (D4) still to be discussed: user finds contato-seguro-cobranca weak; consider an English name or a more intuitive Portuguese one.

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
- case-tecnico-dados-cobranca (p.1-4): requirements and evaluation criteria (rule #1)
