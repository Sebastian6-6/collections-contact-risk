# Case SQL conventions → the check that enforces each one

Source of the rules: `AGENTS.md`, "Convenções do case" → SQL. This file only maps
them to tooling; if they ever differ, `AGENTS.md` wins.

| Case rule | Enforced by | Notes |
|---|---|---|
| PostgreSQL dialect | SQLFluff `dialect = postgres` (parse errors) + review | SQLFluff checks syntax, not function names: a DuckDB-only function still parses. Keep the list in `otimizacao-duckdb.md` in mind |
| Native functions and data types in UPPER CASE | SQLFluff CP01 (keywords), CP03 (functions), CP05 (types), CP04 (`NULL`, `TRUE`) | Identifiers (columns, tables) stay lowercase snake_case |
| One CTE per logical step, descriptive name | SQLFluff ST05 (no subquery in `FROM`/`JOIN`) + review | Naming quality is a review item: the name says what the CTE holds |
| Window functions: only `ROW_NUMBER()` and `SUM()` | `verificar_convencoes.py` → `janela-nao-permitida` | No linter knows this rule. Moving average = `SUM(x) OVER (...)` / `SUM(1) OVER (...)` with the same frame; gaps between days use `ROW_NUMBER()` and a self-join instead of `LAG()` |
| Window frame always declared with `ROWS BETWEEN` | `verificar_convencoes.py` → `janela-sem-frame`, `janela-nomeada` | Applies to `ROW_NUMBER()` too (engines ignore the frame there, but the rule is explicit) |
| Missing data is `NULL`, never zero | `verificar_convencoes.py` → `zero-como-ausencia` (warning) + review | Heuristic: flags `COALESCE(x, 0)`. A real count of zero is fine; a missing value turned into zero is not |
| Models never create rows that do not exist in the source | dbt tests + review | No generated calendar, no zero-filled days, no "unknown" member rows. Row counts per step are compared in the plan review |
| No `SELECT *` in silver and gold | `verificar_convencoes.py` → `select-estrela` | Layer comes from the folder (`models/silver/…`, `models/gold/…`). SQLFluff AM04 is excluded so the rule is not reported twice and bronze stays allowed |
| 2-space indentation | SQLFluff LT02 with `tab_space_size = 2` | |
| (project) `CAST(x AS T)` instead of `x::T` | SQLFluff CV11 `preferred_type_casting_style = cast` | Both work in PostgreSQL; `CAST` is the ANSI form and reads better |

## `.sqlfluff` validated for these rules

Tested with SQLFluff 4.5.0 against a compliant model (no findings) and a model
breaking every rule (each one reported). Put it at the repository root.

```ini
[sqlfluff]
dialect = postgres
templater = jinja
max_line_length = 99
exclude_rules = AM04

[sqlfluff:templater:jinja]
apply_dbt_builtins = True

[sqlfluff:indentation]
indent_unit = space
tab_space_size = 2

[sqlfluff:rules:capitalisation.keywords]
capitalisation_policy = upper

[sqlfluff:rules:capitalisation.functions]
extended_capitalisation_policy = upper

[sqlfluff:rules:capitalisation.types]
extended_capitalisation_policy = upper

[sqlfluff:rules:capitalisation.literals]
capitalisation_policy = upper

[sqlfluff:rules:convention.casting_style]
preferred_type_casting_style = cast

[sqlfluff:rules:structure.subquery]
forbid_subquery_in = both
```

Why the `jinja` templater and not `dbt`: SQLFluff recommends its dbt templater,
but it compiles the project and needs the database. The `jinja` templater with
`apply_dbt_builtins = True` renders `ref()`/`source()` with placeholders and
checks style without a database, which is all these rules need and keeps CI fast.
