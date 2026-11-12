---
name: convencoes-codigo-pessoal
description: The owner's personal coding conventions — Python (names in Portuguese, module layout, docstrings, comments, errors, logs, encoding) and SQL (formatting, CTEs, alignment) — and how to avoid generic AI writing patterns. Use whenever writing, editing, reformatting or reviewing Python or SQL code, in this or any other of the owner's projects.
---

# Personal coding conventions

They apply to all new code. In a project, its own rules (AGENTS.md, CLAUDE.md, tool configuration) come before these: on a conflict, follow the project and keep everything from here that does not conflict.

**Existing file with another style** (quotes, indentation, import order): follow the file's style and do not reformat what the change is not about. Mixing styles is worse than either one, and reformatting hides in the diff what changed.

## Python

### Names
- Variables and functions in Portuguese, `snake_case`, with an infinitive verb for functions (`buscar_chaves_primarias`, `criar_tabela`). Classes in `PascalCase`, a noun. Module constants in UPPER CASE. Private helpers with a leading `_`.
- The name describes the exact transformation. No `processar_dados`, `handle_utils`, `aux`.
- English only for API and tool jargon: `logger`, `schema`, `engine`, `commit`, external keys.
- Do not reuse a name with another meaning or overwrite a parameter: each step gets a new name (`df_lido` → `df_tipado`).

### Module layout
- Module blocks separated by a section title:
  ```python
  # ======================================================================================
  # Leitura dos arquivos
  # ======================================================================================
  ```
- Inside a long function, each step gets a short marker: `# ── Chaves primárias ─────────`.
- One import per line, in groups separated by a blank line (standard library, third party, platform SDK, local), alphabetical within the group. No `import *`. No import inside a function, except for a justified cycle.
- Two blank lines between module functions and classes; one between methods.

### Style
- PEP 8, except the vertical alignment and the line limit described below, with 4-space indentation and double quotes (single only to avoid escaping).
- Vertically aligning related assignments and arguments is allowed when the code reads like a table (several fields of the same record, repeated calls with the same parameters). Outside those blocks, one space around `=`.
- No hard line limit: break when readability gets worse.
- Type hints on the public API (parameters and return), with the modern syntax (`list[str]`, `str | None`). Do not type every local variable.
- `is None` / `is not None`, f-strings, early return instead of nested `if`.

### Docstrings and comments
- Every public function has a docstring. The first line says directly what it does ("Lê o arquivo e devolve as linhas com a origem."), without repeating the function name in prose and without "Este método é responsável por…".
- No parameters and returns section when the typed signature already says it all. When the type is not enough (a `dict` with known keys, a tuple), describe the shape of the return, with a short example if it helps.
- Explain only the non-obvious why. `Raises` only when the failure is not obvious.
- Comments in Portuguese, short, recording a decision. Never narrate the line or number steps the function name already states. Commented-out code does not stay in the file.

### Errors, logs and output
- Code that runs in production, with I/O, network or database: `try/except` on the specific error, `logger` on the error and `raise`. Bare `except:` and `except Exception: pass` are forbidden. Never write a secret or a whole environment variable to the log.
- A local tool (generator, converter, check script) stops instead of producing something wrong: each assumption becomes an `assert` with a message saying what was found (`assert len(partes) == 4, f"esperadas 4 partes, achadas {len(partes)}"`).
- Messages for whoever runs the code carry a status prefix: `[OK]`, `[INFO]`, `[WARN]`, `[ERRO]`. In logs, the severity matches the prefix.
- Verbose libraries have their logging silenced at project level, so what matters is not lost.

### Encoding
- Text and files always with an explicit `encoding="utf-8"` (`open`, `read_text`, `write_text`): the system default varies (cp1252 on Windows) and corrupts accents. CSV files are also opened with `newline=""`.
- A CLI that prints accents: `sys.stdout.reconfigure(encoding="utf-8")` at the start.

### Example

```python
# RUIM
import os, json
def process(path):
    """Este método é responsável por processar os dados."""
    # 1. ler arquivo
    data=json.loads(open(path).read())
    try:
        save(data)
    except Exception:
        pass

# BOM
import json
from pathlib import Path


def ler_configuracao(caminho: Path) -> dict[str, str]:
    """Lê a configuração. Arquivo ausente é erro: rodar com padrão escondido daria outro resultado."""
    texto_lido = caminho.read_text(encoding="utf-8")
    return json.loads(texto_lido)


def gravar_resumo(resumo: dict[str, int], destino: Path) -> None:
    """Grava o resumo. Falha de escrita sobe depois do log."""
    try:
        destino.write_text(json.dumps(resumo, ensure_ascii=False), encoding="utf-8")
    except OSError as erro:
        logger.error(f"[ERRO] Falha ao gravar {destino}: {erro}")
        raise
    print(f"[OK] Resumo gravado em {destino.name}")
```

## SQL

Column-reading style. If the project requires another indentation or another naming pattern, follow the project and keep the rest.

1. Keywords and functions in UPPER CASE. Columns and tables in `snake_case`.
2. Indentation with spaces, no tabs. The 1st column stays on the `SELECT` line; the following ones start with the comma on the left, aligned so the expressions form a single column.
3. `AS` only when the column is renamed or is an expression (`CAST(valor AS NUMERIC(14, 2)) AS vl_total`). A column passed through unchanged takes no `AS`: the self-alias `id AS id` only repeats the name. When there is an `AS`, it is aligned vertically in a fixed column.
4. A blank line between logical groups of columns (identifiers, codes and descriptions, dates, metrics, control).
5. `FROM` right-aligned with the `SELECT`; `JOIN` at the column indentation, aliases aligned, the `AND` of the condition ending flush with the `ON`.
6. `WHERE 1 = 1` and one `AND` per predicate; `GROUP BY` and `ORDER BY` with the 1st item on the same line and the following ones with the comma on the left.
7. CTEs in the `tNomeCte` pattern (lowercase `t` + PascalCase, no accents and no `_`): `WITH tBase AS (`, then `, tCalc AS (`. CTEs the change is not about keep their names.
8. `UNION ALL` alone on its line, with a blank line before and after, at the indentation of the CTE it is in.
9. A multi-line item (`CASE ... END`) with its continuation lines indented under the item itself.
10. In a `UNION`, a typed null: `CAST(NULL AS TIPO)`. UTF-8 literals written directly (no `U&'...'`).
11. Never a trailing comma before `FROM` or after the last item of a list: some engines accept it, others do not.

```sql
WITH tBase AS (
    SELECT id
         , CAST(valor AS NUMERIC(14, 2))                  AS valor
      FROM origem_a
     WHERE 1 = 1
       AND ativo = TRUE
)

SELECT b.id
     , SUM(b.valor)                                       AS valor_total
  FROM tBase b
 GROUP BY b.id
```

## No AI writing patterns

No "este código implementa uma solução robusta e abrangente para…", no emoji in comments, no redundant summary at the end of a file.
