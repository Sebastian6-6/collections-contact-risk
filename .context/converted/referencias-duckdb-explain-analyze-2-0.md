---
id: referencias-duckdb-explain-analyze-2-0
source: raw/referencias/duckdb/explain_analyze-2.0.md
origin: https://github.com/duckdb/duckdb-web/blob/main/docs/stable/guides/meta/explain_analyze.md · acesso 2026-11-09
sha256: 1d36a904fa23a981f8134567c140202e10a8a829288256a3dd2dfb960ddf5393
converter: plain
converted: 2026-11-09 07:43
pages: 0
kind: document
---
Prepending a query with `EXPLAIN ANALYZE` both pretty-prints the query plan,
and executes it, providing run-time performance numbers and the actual cardinality (number of rows produced) for every operator.

```sql
EXPLAIN ANALYZE SELECT * FROM tbl;
```

Note that the **cumulative** wall-clock time that is spent on every operator is shown. When multiple threads are processing the query in parallel, the total processing time of the query may be lower than the sum of all the times spent on the individual operators.

For multi-file reads (e.g., reading multiple Parquet files), the output includes the file names being read.

Below is an example of running `EXPLAIN ANALYZE` on a query:

```sql
CREATE TABLE students (name VARCHAR, sid INTEGER);
CREATE TABLE exams (eid INTEGER, subject VARCHAR, sid INTEGER);
INSERT INTO students VALUES ('Mark', 1), ('Joe', 2), ('Matthew', 3);
INSERT INTO exams VALUES (10, 'Physics', 1), (20, 'Chemistry', 2), (30, 'Literature', 3);

EXPLAIN ANALYZE
    SELECT name
    FROM students
    JOIN exams USING (sid)
    WHERE name LIKE 'Ma%';
```

```text
╭─ Summary ───────────╮
│ Total Time: 0.0015s │
╰─────────────────────╯
╭─ Projection ────────────────────────────────────────────╮
│ Projections: name                                       │
│ 2 rows                                              0µs │
╰────────────────────────────┒┎───────────────────────────╯
╭─ Hash Join ────────────────┚┖───────────────────────────╮
│ Join Type: INNER                                        │
│ Conditions: sid = sid                                   │
│ 2 rows                                              0µs │
╰────────────────────────────┰┰───────────────────────────╯
                             ┃┠─────────────────────────────────────────────┰┒
╭─ Table Scan ───────────────┚┖───────────────────────────╮  ╭─ Table Scan ─┚┖─────────────╮
│ Table: memory.main.exams                                │  │ Table: memory.main.students │
│ Type: Sequential Scan                                   │  │ Type: Sequential Scan       │
│ Projections: sid                                        │  │ Projections: sid, name      │
│ Dynamic Filters:                                        │  │ Filters: name >= 'Ma'       │
│ optional: (sid IN (1, 3)) AND optional: sid IN PRF(sid) │  │ Row Groups Scanned: 1 / 1   │
│ Row Groups Scanned: 1 / 1                               │  │ 2 rows                  0µs │
│ 2 rows                                              0µs │  ╰─────────────────────────────╯
╰─────────────────────────────────────────────────────────╯
```

Each operator shows the number of rows it produced and the time spent in it. Scan operators also show the number of row groups scanned and any _dynamic filters_ that were pushed into them at runtime, e.g., by the hash join.

## See Also

For more information, see the [”Profiling” page]({% link docs/2.0/dev/profiling.md %}).
