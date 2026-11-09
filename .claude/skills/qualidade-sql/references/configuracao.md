# Plugging a project's rules into this skill

The skill carries no project rule. A project states its rules in its rules file
(`AGENTS.md`, `CLAUDE.md` or equivalent) and hands the checkable part to the tools
through configuration at the repository root.

## 1. SQLFluff (`.sqlfluff`)

For a dbt project, lint with the **dbt templater**: it compiles each model the way
dbt does, so project macros, `ref`, `source` and `target` resolve. The plain jinja
templater (even with `apply_dbt_builtins`) fails on project macros with
"Undefined jinja template variable" and leaves the model unlinted (observed
2026-11-09). It needs the `sqlfluff-templater-dbt` package and a dbt profile that
compiles locally; DuckDB needs no server.

```ini
[sqlfluff]
dialect = postgres            # the dialect the SQL is written in
templater = dbt

[sqlfluff:templater:dbt]
project_dir = .
profiles_dir = .
```

Everything else is the project's style: indentation (`[sqlfluff:indentation]`),
comma position (`[sqlfluff:layout:type:comma] line_position = leading|trailing`),
capitalisation (CP01–CP05, `ignore_words_regex` for allowed exceptions),
`implicit_indents = allow` for `WHERE 1 = 1` followed by one `AND` per line. A
rule the project does not want is excluded in the config with a comment saying
why, never silenced inline without telling the user.

## 2. `verificar_convencoes.py` (`pyproject.toml`)

Checks the SQL rules no linter knows. Without configuration it is neutral (any
window function, `SELECT *` allowed, no zero warning). A project turns rules on:

```toml
[tool.verificar_convencoes_sql]
caminhos = ["models", "macros", "tests"]
funcoes_janela_permitidas = ["ROW_NUMBER", "SUM"]   # empty = any
exigir_frame_rows = true                            # every window declares ROWS BETWEEN
proibir_janela_nomeada = true                       # no WINDOW w AS (...)
camadas_sem_select_estrela = ["silver", "gold"]     # folder right after models/
alertar_zero_como_ausencia = true                   # warn on COALESCE(x, 0)
```

`--config <file>` points to another TOML. Exit code 1 on errors; warnings fail
only with `--estrito`.

## 3. Where the mapping lives

Each project keeps its own table "rule → origin → check" in its docs (for example
`docs/qualidade-e-convencoes.md`), so a reviewer sees which tool enforces which
rule without opening the skill.
