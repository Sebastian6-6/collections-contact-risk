---
name: qualidade-python
description: Quality loop for every Python change in this repository (ingestion, pipeline entry point, tests, helper scripts). Test first with pytest, write the code with the owner's conventions (skill convencoes-codigo-pessoal - Portuguese names, docstrings, PEP 8, no generic AI phrasing), then Ruff lint and format, a reproducibility check (no clock, randomness or OS-dependent file order in the data path) and a simplification pass, and only then report done with the command output as evidence. Use it whenever you write, edit, refactor, review or debug Python here, even a small function or a one-line fix, and whenever the user asks to clean up, simplify, test or "make the code better".
metadata:
  version: 1.0.0
---

# qualidade-python

Makes every Python change pass the same loop: a failing test first, the
smallest code that passes it written in the owner's style, then tools that check
what humans miss, then a deliberate pass to make the code simpler. Done means the
commands ran and passed, not that the code looks right.

## Which rule wins

1. **`AGENTS.md`** — case and project conventions (ingestion reads files without
   transforming them, reproducible execution, pinned dependencies).
2. **`convencoes-codigo-pessoal`** — the owner's Python conventions: names in
   Portuguese that say exactly what the code does, docstrings on public functions
   (what goes in, what comes out, why it exists), PEP 8, comments only for
   non-obvious decisions, no generic AI phrasing, type hints where they help
   reading. Load that skill before writing code; this one does not repeat it.
3. **This skill.**

## The loop

1. **Write the test first.** Describe the behaviour as a pytest test that fails
   for the right reason (run it and see it fail). Cover the edge cases the data
   is known to have — see `docs/perfil-das-fontes.md` for real ones: masked and
   unmasked CPF, lost leading zeros, truncated JSON lines, a header repeated in
   the middle of a file, CRLF line endings, epoch vs ISO dates. If the
   `superpowers:test-driven-development` skill is available, follow it.
2. **Write the smallest code that passes**, following `convencoes-codigo-pessoal`.
3. **Run the tests**: `python -m pytest -q`. Repeat 2–3 until green.
4. **Let the tools speak**:
   - `ruff check --fix .` then `ruff format .` — read the diff of every autofix.
   - `python .claude/skills/qualidade-python/scripts/verificar_reprodutibilidade.py`
     flags clock reads, random values and file listings without `sorted()` in
     `ingestion/` and `pipeline.py`. Fix it, or keep it with an inline reason:
     `# reprodutivel: <why this does not reach the data>`.
5. **Simplify on purpose.** Walk `references/simplificacao.md` against the diff.
   Re-run step 3 and 4 after any change.
6. **Report with evidence**: paste the last lines of pytest, ruff and the
   reproducibility check. If something was skipped, say so.

## Rules specific to this project

- **Reproducibility comes first.** The brief requires the pipeline to produce
  exactly the same results on every run from the initial state (p. 2). No
  execution timestamps or random ids in data; iterate files in sorted order; read
  and write with explicit `encoding="utf-8"`; open CSV files with `newline=""`.
- **Ingestion does not transform.** Code in `ingestion/` reads files and lands
  every received line, valid or not, with its lineage (file, line number, file
  hash). Parsing, typing and cleaning belong to the dbt models.
- **Never drop data silently.** An unreadable line becomes a recorded,
  countable row, not a `continue` inside a bare `except`.
- **Configuration over code.** A new table in an existing source should be a
  config entry, not a new function (`AGENTS.md`, rule hierarchy item 3).
- **Libraries in the treatment stage** enter only if they work offline, are
  deterministic at a pinned version, and change a business decision; the gain is
  measured on this data.
- **Windows is a supported platform.** Use `pathlib`; reconfigure
  `sys.stdout`/`sys.stderr` to UTF-8 in CLIs that print accents.

## Commands

| Goal | Command |
|---|---|
| Tests | `python -m pytest -q` |
| Lint with autofix · format | `ruff check --fix .` · `ruff format .` |
| Check only (CI) | `ruff check .` · `ruff format --check .` |
| Reproducibility hazards | `python .claude/skills/qualidade-python/scripts/verificar_reprodutibilidade.py [paths]` |

Run everything from the repository root.

## References

| File | Read when |
|---|---|
| `references/simplificacao.md` | Step 5, or when the user asks to simplify, refactor or review code |
| `references/ruff.md` | Creating or changing `ruff.toml`, or a Ruff rule needs explaining |
