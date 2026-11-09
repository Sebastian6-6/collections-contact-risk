---
name: qualidade-sql
description: Quality loop for any SQL or dbt change - correct first (grain, tests), then within the project's conventions (linter plus a configurable checker for rules no linter knows), then measurably faster (real query plan), each step proven by a command. Project-agnostic - the project's rules file and configuration decide the conventions. Use it whenever you write, edit, review, refactor or optimize SQL, a dbt model, macro, data test, unit test or schema YAML, even a one-line change, and whenever the user asks to lint SQL, check conventions, speed up a query, read a query plan, or asks whether a model is "good" or "ready".
metadata:
  version: 2.0.0
---

# qualidade-sql

Makes every SQL change pass the same loop: correct first, conventional second,
fast third, and each step proven by a command, not by reading the code and
feeling good about it.

## Which rule wins

1. **The project's rules file** (`AGENTS.md`, `CLAUDE.md` or equivalent) and the
   configuration it points to (`.sqlfluff`, `[tool.verificar_convencoes_sql]` in
   `pyproject.toml`). Read them before writing; they decide dialect, casing,
   indentation, naming and which constructs are forbidden.
2. **The project's style skill**, if it has one for SQL.
3. **This skill**, then any vendored dbt skills. Their examples may use a casing or
   layout the project forbids; the project wins.

When a tool and the project rules disagree, the rules win. Never silence a check
(`-- noqa`, a rule excluded, `--estrito` off) without telling the user why.

## The loop

Run the steps in order. Go back to step 3 after any change made in steps 4–5.

1. **Pin the grain.** Before writing, state in one sentence what one output row
   is ("one row per customer", "one row per customer × contact"). Every join and
   every deduplication is checked against this sentence.
2. **Write for the reader.**
   - One CTE per logical step, named after what it holds (never `cte2`).
   - Explicit column lists; `AS` always explicit; a blank line between logical
     groups of columns (keys, codes and descriptions, values, flags, dates,
     lineage) in long selects.
   - `CAST(x AS TYPE)`; in `UNION` branches, typed nulls: `CAST(NULL AS TYPE)`.
   - `UNION ALL` alone on its line, with a blank line before and after.
   - A multi-line item (`CASE ... END`) indented under its own item.
   - No trailing comma before `FROM` or after the last item of any list.
   - Engine-specific functions go into a macro, so the dialect difference lives in
     one place (`references/otimizacao-duckdb.md`, last section, for DuckDB vs
     PostgreSQL).
   - Editing existing SQL: keep its style and do not rename or reformat what is
     not part of the change; a reformatted file hides in the diff what really
     changed.
3. **Prove it is correct.** `dbt build --select <model>` runs the model and its
   tests. Logic with regex, date math, windows, many `CASE` branches or
   deduplication gets a unit test. Keys get `unique` + `not_null`; foreign keys get
   `relationships`. Compare row counts before and after each join that could fan
   out.
4. **Prove it follows the conventions.**
   - `sqlfluff lint <files>`; `sqlfluff fix <files>` only after reading what it
     will change.
   - `python .claude/skills/qualidade-sql/scripts/verificar_convencoes.py [paths]`
     for the rules the project configured and no linter knows (allowed window
     functions, mandatory frame, `SELECT *` by layer, zero as a missing value).
5. **Measure, then optimize.**
   - `dbt compile --select <model>`, then
     `python .claude/skills/qualidade-sql/scripts/explicar_modelo.py <model>`: the
     real plan (EXPLAIN ANALYZE) with cross products and non-equality joins
     flagged.
   - Walk `references/otimizacao-duckdb.md` and change the SQL only where the plan
     or the row counts show a reason. A rewrite that does not move the plan is
     noise: undo it and keep the clearer version. When a rewrite stays, record the
     before and after (time, rows, operator) so the gain is measured, not claimed.
6. **Report** what ran and what it showed: tests, lint, checker, plan alerts, row
   counts, and every assumption made about the requirement (for example whether
   "7 days" means 7 rows or 7 calendar days).

## Commands

| Goal | Command |
|---|---|
| Build one model and its tests | `dbt build --select <model>` |
| Model and everything downstream | `dbt build --select <model>+` |
| Lint / autofix | `sqlfluff lint <paths>` · `sqlfluff fix <paths>` |
| Rules no linter covers | `python .claude/skills/qualidade-sql/scripts/verificar_convencoes.py [paths]` |
| Real plan of a model | `python .claude/skills/qualidade-sql/scripts/explicar_modelo.py <model> [--banco <file.duckdb>]` |

Run everything from the repository root. The checker reads its rules from
`[tool.verificar_convencoes_sql]` in `pyproject.toml` (neutral without it), exits 1
on errors, and fails on warnings only with `--estrito`.

## References

| File | Read when |
|---|---|
| `references/configuracao.md` | Setting up `.sqlfluff` (dbt templater) or the checker's rules for a project |
| `references/otimizacao-duckdb.md` | Step 5; any question about plans, CTE cost, joins, window frames, dirty-text parsing, or DuckDB vs PostgreSQL differences |
