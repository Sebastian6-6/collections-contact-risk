---
topic: fundacao-do-repositorio
status: active
created: 2026-11-09
updated: 2026-11-09 08:30
scope:
  - .gitattributes
  - .gitignore
  - requirements.in
  - requirements.txt
  - ruff.toml
  - .sqlfluff
  - pyproject.toml
  - dbt_project.yml
  - profiles.yml
  - macros/
  - models/
  - .claude/agents/
  - .claude/skills/qualidade-*/
  - .github/
---
# fundacao-do-repositorio

## Goal
Prepare the repository for building the pipeline safely: git with main/develop and the private commit hook, pinned dependencies, dbt skeleton with one schema per layer and source, quality tools, skills tested against a baseline, project agents and CI. Detailed steps in PLAN.md (pt-BR, reviewed by the owner).

## Plan
<!-- "- [ ]" todo · "- [x]" done · "- [~]" dropped (add " — reason"). Done and dropped items move to HISTORY.md on save. -->
- [x] 1.1 Repository, private hook and starting point (2 commits on main) (PLAN.md §4)
- [x] 1.2 Python environment (asks before installing uv + Python 3.14) (PLAN.md §4)
- [x] 1.3 Dependencies and quality tools (PLAN.md §4)
- [x] 1.4 dbt skeleton with schema per layer and source (PLAN.md §4)
- [x] 1.5 Project agents (PLAN.md §4)
- [x] 1.6 Skill comparison tests (pause for the viewer) (PLAN.md §4)
- [x] 1.7 CI on GitHub Actions (PLAN.md §4)
- [x] 1.8 Review, verification and merge into develop (PLAN.md §4)

## Where we stopped
- Topic complete 2026-11-09 and merged into develop with --no-ff (chore: integra fundacao-do-repositorio na develop). main holds the 3 starting commits; develop holds the foundation.
- Delivered: git + private hook; pinned deps (uv, Python 3.14.10); dbt skeleton (schema/alias from folders, errors for explicit schema and loose models); 5 project agents; project-agnostic quality skills with rules in .sqlfluff / ruff.toml / pyproject [tool.*]; personal style merged into convencoes-codigo-pessoal; CI (ruff check, SQLFluff dbt templater, both checkers, pytest, dbt parse v1/v2) with minimal permissions and SHA-pinned actions; context-manager security fix.
- Skill evals: iteration-1 98% vs 91% (8 runs, Sonnet 5.5 medium); iteration-2 verification of the failing case: 0 lint violations. Review: 15 findings, all handled (4 fix commits); verificador green.
- Style decisions with the owner: tNomeCte CTEs, leading commas, WHERE 1 = 1, AS only for renamed/derived columns (AL09), first column below SELECT (required by LT02, which enforces the case's 2-space rule), Python vertical alignment allowed (no ruff format), 99-column limit kept; author e-mail stays public by the owner's choice.
- Open for later topics: GitHub Actions only runs after the push (topic 5); confirm setup-python serves 3.14 on the first run; checker paths ingestion/, pipeline.py, scripts/ appear in topic 2.

## Pending
<!-- Unconfirmed questions: "- [?] question (where it came up, date)". Never treat them as a standard until the user answers. -->


## Decisions
<!-- Local to this topic, append-only: "- YYYY-MM-DD decision". -->
- 2026-11-09 Inherits the rules in AGENTS.md and the design decisions in arquitetura-solucao/STATE.md; PLAN.md is written in pt-BR because the owner reviews and presents it.
- 2026-11-09 D1 decided (user): Python 3.14 via uv. Installed 2026-11-09 with winget: uv 0.13.7, GitHub CLI 2.103.3; uv python install 3.14 -> CPython 3.14.10 (system python has no pip, so winget was used).
- 2026-11-09 D5 decided (user): CODEOWNERS uses @Sebastian6-6 (public).
- 2026-11-09 D2 decided (user): standard .venv inside the repo (uv venv, git-ignored); tested 2026-11-09: dbt-core 1.12.6 + dbt-duckdb 1.11.1 install with uv here, longest path 215/260 chars with LongPathsEnabled=0; README warns Windows clones need a folder under ~100 chars.
- 2026-11-09 D3 decided (user): ingestion config in YAML (ingestion/fontes.yml) with PyYAML as a direct dependency (already pulled by dbt-core).
- 2026-11-09 D4 decided (user): repository collections-contact-risk; dbt project collections_contact_risk; database banco/collections_contact_risk.duckdb (git-ignored).
- 2026-11-09 D6 decided (user): .gitattributes with contact_data/** -text (data bytes intact, stable hashes) and * text=auto eol=lf elsewhere. All foundation decisions closed.
- 2026-11-09 Security fix applied (owner agreed): context-manager rebuilds converted paths from validated ids and skips links/paths resolving outside raw/ (docs.py, mapper.py); tested on a throwaway copy (tampered manifest no longer deletes outside .context; a directory junction in raw/ no longer leaks an outside file). No other local copy of the skill exists to patch (only a claude.ai-synced folder).
- 2026-11-09 Skills must be project-agnostic (user direction 2026-11-09): reusable how-to-work loops (SQL quality, Python quality, tooling usage) live in skills; every project-specific rule (case conventions, window-function whitelist, NULL-not-zero, ingestion-without-transformation, PostgreSQL subset on DuckDB, layer/naming rules) lives in AGENTS.md and project config files (.sqlfluff, ruff.toml, checker parameters). Skills read the project's rules file and config and defer to them. The owner will share personal skills to mine for good generic practices before the skill-fix commit.

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
- case-tecnico-dados-cobranca (p.1-4): requirements and evaluation criteria (rule #1)
