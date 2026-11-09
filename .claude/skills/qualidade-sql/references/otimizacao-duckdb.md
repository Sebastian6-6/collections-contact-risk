# Optimizing SQL on DuckDB without leaving the PostgreSQL subset

Based on the DuckDB 2.0 documentation (CTE materialization, EXPLAIN ANALYZE,
join operations, performance guide, PostgreSQL compatibility page). Applies to any
project that runs on DuckDB and wants its SQL to stay portable to PostgreSQL.

On small data the point is not saving seconds; it is keeping the habits that
matter when the same models run on large volumes.

## Contents
1. How to read the plan
2. Checklist
3. CTEs: when they cost something
4. Joins
5. PostgreSQL-compatible subset

## 1. How to read the plan

`EXPLAIN ANALYZE` executes the query and shows, per operator, the real number of
rows produced and the time spent. Times are cumulative per operator; with
parallel threads the total can be lower than the sum. Read it bottom-up:

- **Row counts** are the first thing to check. A join whose output has more rows
  than its larger input is a fan-out: either the grain sentence was wrong or a
  key is not unique.
- **Operator names**: `Hash Join` is the normal equality join. `Piecewise Merge
  Join`, `Blockwise NL Join`, `Nested Loop Join` mean the condition has no
  equality (or not one DuckDB can hash). `Cross Product` means no condition at all.
  `explicar_modelo.py` flags these.
- **Where the time goes**: optimize the operator that dominates, nothing else.

## 2. Checklist

Go through it after the model is correct and lint-clean. Change only what the
plan or the counts justify.

- [ ] **Grain holds at every join.** Count rows before and after each join that
      could multiply rows; back it with a `unique` test on the key.
- [ ] **Deduplicate with `ROW_NUMBER()`, not `DISTINCT`.** `DISTINCT` hides the
      question "which row wins?"; `ROW_NUMBER() OVER (PARTITION BY key ORDER BY
      rule)` makes the rule explicit and testable (add a frame clause if the
      project's rules require one on every window).
- [ ] **Join keys have the same type on both sides.** Comparing `VARCHAR` with
      `INTEGER` relies on DuckDB's implicit cast, which PostgreSQL rejects, and can
      prevent a hash join. Cast once, in the CTE that prepares the key.
- [ ] **Filter and select columns in the first CTE that can.** DuckDB pushes
      filters and projections down on its own, so this is mostly for the reader:
      the CTE that reads a source says what it keeps.
- [ ] **No correlated subqueries.** Use a CTE plus a join (also enforced by ST05 in
      `FROM`/`JOIN`).
- [ ] **No function on a join key** (`ON UPPER(a.x) = b.x`): normalize the key in
      the silver layer, once, and join on the stored value.
- [ ] **Aggregations at the grain they are needed.** Aggregate before joining when
      the join only needs one row per key.
- [ ] **Say what a window frame counts.** `ROWS BETWEEN 6 PRECEDING AND CURRENT
      ROW` covers the last 7 *rows*, not the last 7 calendar days: with missing
      days it reaches further back. Write down which one the requirement means.
      Calendar days without generating rows: a self-join on a date range (an
      inequality join, so check the plan). When a project restricts window
      functions, the portable forms are: moving average as
      `CAST(SUM(x) OVER (...) AS NUMERIC) / SUM(1) OVER (...)` with the same frame
      written inside both `OVER (...)` (some projects forbid named windows), and gaps
      between dates with `ROW_NUMBER()` per series plus a self-join on `n = n + 1`
      instead of `LAG()`.
- [ ] **Parse dirty text defensively.** DuckDB may evaluate a `CAST` before the
      `WHERE` that was meant to filter the bad rows out: one truncated JSON line
      made `CAST(linha AS JSON)` abort the whole query (observed on DuckDB 2.0,
      2026-11-09). Use `TRY_CAST` inside a macro (with the PostgreSQL equivalent,
      `IS JSON` from version 16, in the same macro) so dirty rows become `NULL`.

## 3. CTEs: when they cost something

From the DuckDB 2.0 docs (`WITH` clause, "CTE Materialization"): CTEs are
materialized by default, but DuckDB **inlines** a CTE when all of these hold:

- it is referenced only once;
- it has no `VOLATILE` function;
- it does not perform a grouped aggregation;
- it is not marked `AS MATERIALIZED`.

Consequence for "one CTE per logical step": a chain of CTEs each used once costs
nothing; the optimizer sees one query. A CTE referenced several
times is computed once and reused, which is usually what you want. Use
`AS MATERIALIZED` / `AS NOT MATERIALIZED` (valid in PostgreSQL 12+ too) only when
the plan shows that the default choice is the slow part.

## 4. Joins

- DuckDB's optimizer picks the join order from table statistics; with fewer than
  12 tables in one join it searches the order exactly. Do not reorder joins for
  speed by hand; reorder them for readability.
- Forcing an order (disabling the join-order optimizer, temporary tables) exists
  for diagnosis. Do not leave it in a model.
- Inequality joins (ranges, `BETWEEN` dates) are legitimate but get a non-hash
  operator; when the plan shows one, confirm it is intended and that the inputs
  were reduced first.

## 5. PostgreSQL-compatible subset

When the SQL must stay valid PostgreSQL while the engine is DuckDB, avoid the
differences DuckDB documents:

| Difference | Write instead |
|---|---|
| `1 / 2` is `0.5` in DuckDB and `0` in PostgreSQL | Cast explicitly: `CAST(a AS NUMERIC) / b`; never rely on integer division |
| Implicit casts on equality (`'1' = 1` works only in DuckDB) | Compare values of the same type; cast once upstream |
| Regex extraction has no common form: `REGEXP_EXTRACT` is DuckDB-only (and returns `''`, not `NULL`, on no match); PostgreSQL's `REGEXP_SUBSTR` does not exist in DuckDB 2.0 (checked) | Prefer forms both accept (checked on DuckDB 2.0): `REGEXP_REPLACE(x, '[^0-9]', '', 'g')` to keep digits, `x ~ 'pattern'` to test. When extraction is unavoidable, put it in a macro and wrap it in `NULLIF(..., '')` |
| No `TO_DATE` in DuckDB; `STRPTIME` does not exist in PostgreSQL | Rebuild an ISO string and `CAST(... AS DATE)`, or isolate the parse in a macro |
| `GROUP BY` does not use functional dependencies in DuckDB | List every non-aggregated column in `GROUP BY` |
| Quoted identifiers keep case in DuckDB | Never quote identifiers. Unquoted names are case-insensitive in both engines (PostgreSQL stores them in lowercase), so a mixed-case CTE name works but is only cosmetic |
| `==` works only in DuckDB | Always `=` |

When a DuckDB-only function is genuinely needed (for example `TRY_CAST` to
survive dirty values), put it in a macro under `macros/`. The difference then lives
in one documented place and a PostgreSQL version of the macro is a one-file change.
