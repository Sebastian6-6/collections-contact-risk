---
name: qualidade-sql
description: Quality loop for every SQL and dbt change in this repository (DuckDB engine, PostgreSQL-compatible SQL, case conventions from AGENTS.md). Covers correctness first (grain, dbt tests, unit tests), then convention checks (SQLFluff plus a checker for the window-function, frame and NULL-not-zero rules no linter knows), then measured optimization with EXPLAIN ANALYZE. Use it whenever you write, edit, review, refactor or optimize SQL, a dbt model, macro, data test, unit test or schema YAML under models/, macros/ or tests/, even for a one-line change, and whenever the user asks to lint SQL, check the conventions, speed up a query, look at a query plan, or asks whether a model is "good" or "ready".
metadata:
  version: 1.0.0
---

# qualidade-sql

Makes every SQL change in this repository pass the same loop: correct first,
conventional second, fast third, and each step proven by a command, not by
reading the code and feeling good about it.

## Which rule wins

1. **Case conventions** — `AGENTS.md`, section "Convenções do case", subsection SQL.
   They come with the case and are evaluated. Summary (the file is the source):
   PostgreSQL dialect; native functions and types in UPPER CASE; one CTE per
   logical step with a descriptive name; window functions only `ROW_NUMBER()` and
   `SUM()`, always with `ROWS BETWEEN`; missing data is `NULL`, never zero; models
   never create rows that do not exist in the source; no `SELECT *` in silver and
   gold; 2-space indentation.
2. **Project conventions** — `AGENTS.md`, "Convenções do projeto" (engine DuckDB,
   SQL kept in the PostgreSQL-compatible subset, naming decided for the project).
3. **This skill**, then the vendored dbt Labs skills (`using-dbt-for-analytics-engineering`,
   `adding-dbt-unit-test`, `running-dbt-commands`, `maintaining-dbt-documentation`).
   Their examples use lowercase SQL; in this repository write UPPER CASE.

When a tool and the case disagree, the case wins. Never silence a check
(`-- noqa`, `--estrito` off, rule excluded) without telling the user why.

## The loop

Run the steps in order. Go back to step 3 after any change made in steps 4–5.

1. **Pin the grain.** Before writing, state in one sentence what one output row
   is ("one row per debtor CPF", "one row per debtor × contact"). Every join and
   every deduplication is checked against this sentence.
2. **Write for the reader.** One CTE per logical step, named after what it holds
   (`devedores_validos`, not `cte2`). Explicit column lists. `CAST(x AS TYPE)`
   instead of `::`. Keep DuckDB-only functions out of models; when one is
   unavoidable, wrap it in a macro so the dialect difference lives in one place
   (see `references/otimizacao-duckdb.md`, section "PostgreSQL-compatible subset").
3. **Prove it is correct.** `dbt build --select <model>` runs the model and its
   tests. Logic with regex, date math, windows, many `CASE` branches or
   deduplication gets a dbt unit test (`adding-dbt-unit-test` skill). Keys get
   `unique` + `not_null`; foreign keys get `relationships`.
4. **Prove it follows the conventions.**
   - `sqlfluff lint <files>`; `sqlfluff fix <files>` only after reading what it will change.
   - `python .claude/skills/qualidade-sql/scripts/verificar_convencoes.py <files>`
     for the rules SQLFluff cannot see (allowed window functions, mandatory frame,
     zero as missing value, `SELECT *` by layer).
   - Mapping of each case rule to the check that enforces it:
     `references/convencoes-case.md`.
5. **Measure, then optimize.**
   - `dbt compile --select <model>` and
     `python .claude/skills/qualidade-sql/scripts/explicar_modelo.py <model>`.
     It prints the real plan (EXPLAIN ANALYZE) and flags cross products and
     non-equality joins.
   - Walk the checklist in `references/otimizacao-duckdb.md` and change the SQL only
     where the plan or the row counts show a reason. A rewrite that does not move
     the plan is noise: undo it and keep the clearer version.
6. **Report** what ran and what it showed: tests passed, lint result, plan alerts,
   row counts before and after each join that could fan out.

## Commands

| Goal | Command |
|---|---|
| Build one model and its tests | `dbt build --select <model>` |
| Model and everything downstream | `dbt build --select <model>+` |
| Lint / autofix | `sqlfluff lint <paths>` · `sqlfluff fix <paths>` |
| Case rules no linter covers | `python .claude/skills/qualidade-sql/scripts/verificar_convencoes.py [paths]` |
| Real plan of a model | `python .claude/skills/qualidade-sql/scripts/explicar_modelo.py <model> [--banco <file.duckdb>]` |

Run everything from the repository root. Without paths, `verificar_convencoes.py`
checks `models/`, `macros/` and `tests/`; it exits 1 on errors, and warnings
(heuristics) fail only with `--estrito`.

## References

| File | Read when |
|---|---|
| `references/convencoes-case.md` | Setting up or changing `.sqlfluff`, or a check fails and you need to know which case rule it enforces |
| `references/otimizacao-duckdb.md` | Step 5, or any question about performance, CTE cost, join strategy, or a DuckDB vs PostgreSQL difference |
