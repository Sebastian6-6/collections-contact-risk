---
name: qualidade-python
description: Quality loop for any Python change - test first with pytest, the smallest code that passes written in the owner's style (skill convencoes-codigo-pessoal), then the project's linter, a configurable reproducibility check (no clock, randomness or OS-dependent file order where the project forbids them) and a deliberate simplification pass, reporting done only with command output as evidence. Project-agnostic - the project's rules file and configuration decide the rules. Use it whenever you write, edit, refactor, review or debug Python, even a small function or a one-line fix, and whenever the user asks to clean up, simplify, test or "make the code better".
metadata:
  version: 2.0.0
---

# qualidade-python

Makes every Python change pass the same loop: a failing test first, the smallest
code that passes it, tools that check what reading misses, then a deliberate pass
to make the code simpler. Done means the commands ran and passed, not that the
code looks right.

## Which rule wins

1. **The project's rules file** (`AGENTS.md`, `CLAUDE.md` or equivalent) and its
   configuration (`ruff.toml`/`pyproject.toml`, `[tool.verificar_reprodutibilidade]`).
   They decide what the code may do (for example whether data code may read the
   clock) and which tools gate a change.
2. **The owner's style** — skill `convencoes-codigo-pessoal`: names, module
   layout, docstrings, comments, errors, logs, encoding. Load it before writing
   code; this skill does not repeat it.
3. **This skill.**

## The loop

1. **Write the test first.** Describe the behaviour as a pytest test and run it to
   see it fail for the right reason (an import error of the missing module counts;
   a typo does not). Cover the edge cases the real input is known to have; if the
   project documents its data, take them from there. If the
   `superpowers:test-driven-development` skill is available, follow it.
2. **Write the smallest code that passes**, in the owner's style.
   - Data in, data out: keep reading and writing at the edges and the
     transformation in pure functions.
   - Never lose input silently: a record that cannot be read becomes a recorded,
     countable case, not a `continue` inside a broad `except`.
   - Behaviour that varies by source or client goes into configuration, not into
     a new function per case.
3. **Run the tests**: `python -m pytest -q`. Repeat 2–3 until green.
4. **Let the tools speak**:
   - `ruff check .` (with `--fix` only after reading what it will change). Run
     `ruff format` only if the project uses the formatter; some projects allow
     manual vertical alignment, which a formatter would undo.
   - `python .claude/skills/qualidade-python/scripts/verificar_reprodutibilidade.py`
     flags clock reads, random values and file listings without `sorted()` in the
     paths the project configured. Fix it, or keep it with an inline reason:
     `# reprodutivel: <why this does not reach the data>`.
5. **Simplify on purpose.** Walk `references/simplificacao.md` against the diff.
   Re-run steps 3 and 4 after any change.
6. **Report with evidence**: the last lines of pytest, ruff and the
   reproducibility check, plus every assumption made about the requirement. If
   something was skipped, say so.

When editing an existing file, keep its style and leave alone what is not part of
the change: the diff must show only what changed.

## Commands

| Goal | Command |
|---|---|
| Tests | `python -m pytest -q` |
| Lint (autofix after reading) | `ruff check .` · `ruff check --fix .` |
| Format, if the project uses it | `ruff format .` · `ruff format --check .` |
| Reproducibility hazards | `python .claude/skills/qualidade-python/scripts/verificar_reprodutibilidade.py [paths]` |

Run everything from the repository root. The reproducibility checker reads its
paths from `[tool.verificar_reprodutibilidade]` in `pyproject.toml` (default: the
whole repository, skipping virtual environments, tests and hidden folders).

## References

| File | Read when |
|---|---|
| `references/simplificacao.md` | Step 5, or when the user asks to simplify, refactor or review code |
| `references/ruff.md` | Creating or changing a Ruff configuration, or a Ruff rule needs explaining |
