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
- [ ] 1.1 Repository, private hook and starting point (2 commits on main) (PLAN.md §4)
- [ ] 1.2 Python environment (asks before installing uv + Python 3.14) (PLAN.md §4)
- [ ] 1.3 Dependencies and quality tools (PLAN.md §4)
- [ ] 1.4 dbt skeleton with schema per layer and source (PLAN.md §4)
- [ ] 1.5 Project agents (PLAN.md §4)
- [ ] 1.6 Skill comparison tests (pause for the viewer) (PLAN.md §4)
- [ ] 1.7 CI on GitHub Actions (PLAN.md §4)
- [ ] 1.8 Review, verification and merge into develop (PLAN.md §4)

## Where we stopped
- All decisions D1-D6 closed with the owner on 2026-11-09 (table in PLAN.md §3); ready to execute from step 1.1.
- Already done for step 1.2: uv 0.13.7, gh 2.103.3 and CPython 3.14.10 installed (winget + `uv python install 3.14`). The test .venv was deleted before the folder rename; recreate it in 1.2 with `uv venv .venv --python 3.14`.
- Before starting: confirm the folder is now `collections-contact-risk` (rename log in the private folder), run `/c`, and check `gh auth status` (the owner runs `gh auth login`; needed only for publication in topic 5).
- Pause points in this topic: the skill-eval viewer (1.6). Commits follow PLAN.md; git identity global (Sebastian6-6), no co-author trailer; the private hook must be enabled right after `git init` (1.1).

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

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
- case-tecnico-dados-cobranca (p.1-4): requirements and evaluation criteria (rule #1)
