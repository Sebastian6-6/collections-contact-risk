# Ruff configuration

Ruff replaces flake8, black and isort with one tool: a linter (PEP 8 through the
pycodestyle rules, plus bug and simplification rules) and a formatter.

## `ruff.toml` validated for this project

Tested with Ruff 0.17.4 on the skill scripts (no findings, with an equivalent
`src` glob) and on Portuguese identifiers, strings and comments with accents (no
findings). Put it at the repository root.

```toml
line-length = 99
target-version = "py314"
src = [".", "ingestion", ".claude/skills/*/scripts"]

[lint]
select = ["E", "W", "F", "I", "B", "SIM", "UP", "N", "C90", "PTH", "DTZ", "RUF"]

[lint.mccabe]
max-complexity = 10

[format]
quote-style = "double"
```

## Why each choice

| Setting | Reason |
|---|---|
| `line-length = 99` | PEP 8 allows teams to agree on up to 99 characters; Ruff's default is 88. Long SQL strings and Portuguese names fit without hurting readability |
| `target-version = "py314"` | The project's Python version; enables modern syntax suggestions (UP) |
| `src` with the skills' `scripts/` folders | Ruff decides first- vs third-party imports from `src`; without it, the import sorting of the skills' tests changes with the directory Ruff runs from (observed) |
| `E`, `W` (pycodestyle) | PEP 8 |
| `F` (Pyflakes) | Unused imports and variables, undefined names |
| `I` (isort) | Import order |
| `B` (bugbear) | Likely bugs: mutable default arguments, loop variable capture |
| `SIM` (simplify) | Simpler equivalent constructs |
| `UP` (pyupgrade) | Modern syntax for the target version |
| `N` (pep8-naming) | snake_case functions and variables, CapWords classes; Portuguese names pass |
| `C90` (mccabe, max 10) | Flags functions with too many branches: a prompt to split them |
| `PTH` (use-pathlib) | `pathlib` instead of `os.path` |
| `DTZ` (datetimez) | Naive datetimes; complements the reproducibility check |
| `RUF` | Ruff's own rules (ambiguous characters, mutable class defaults) |

Rules not selected on purpose: `S` (bandit) and `PL` (pylint) add many findings
that do not fit a small data pipeline; `D` (docstrings) would demand docstrings on
private helpers, while the owner's convention asks them on public functions.
