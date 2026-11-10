# Qualidade e convenções: de onde vem cada regra e o que a garante

As regras deste repositório estão no [AGENTS.md](../AGENTS.md). Este documento só liga cada regra à checagem automática que a faz valer. Se os dois divergirem, vale o AGENTS.md.

As skills de qualidade (`.claude/skills/qualidade-sql` e `.claude/skills/qualidade-python`) são genéricas: trazem o ciclo de trabalho e os verificadores. As regras deste projeto chegam a elas pela configuração da raiz:
- `.sqlfluff`: estilo e sintaxe do SQL;
- `pyproject.toml`, seções `[tool.verificar_convencoes_sql]` e `[tool.verificar_reprodutibilidade]`;
- `ruff.toml`: estilo do Python.

## SQL

| Regra | Origem | Checagem |
|---|---|---|
| Dialeto PostgreSQL | case | SQLFluff com `dialect = postgres` (erro de sintaxe). Função exclusiva do DuckDB ainda passa no parser; por isso, quando uma é inevitável, ela fica isolada numa macro |
| Funções nativas e tipos em UPPER CASE | case | SQLFluff CP01 (palavras-chave), CP03 (funções), CP05 (tipos), CP04 (`NULL`, `TRUE`) |
| Uma CTE por etapa lógica, com nome descritivo | case | SQLFluff ST05 (nenhuma subconsulta no `FROM` ou no `JOIN`) e revisão do nome |
| Funções de janela: só `ROW_NUMBER()` e `SUM()` | case | `verificar_convencoes.py` → `janela-nao-permitida`. Média móvel = `SUM(x)` / `SUM(1)` com o mesmo frame; buraco entre datas com `ROW_NUMBER()` e autojunção no lugar de `LAG()` |
| Janela sempre com `ROWS BETWEEN` | case | `verificar_convencoes.py` → `janela-sem-frame` e `janela-nomeada` |
| Ausência é `NULL`, nunca zero | case | `verificar_convencoes.py` → `zero-como-ausencia` (aviso para `COALESCE(x, 0)`) e revisão |
| Nenhuma linha que não exista na origem | case | testes do dbt e revisão: sem calendário gerado, sem dia preenchido com zero, sem membro "desconhecido" |
| Nada de `SELECT *` na silver e na gold | case | `verificar_convencoes.py` → `select-estrela`, com a camada lida pela pasta. A regra AM04 do SQLFluff fica desligada para não repetir o aviso e para a bronze poder usar `SELECT *` |
| Indentação de 2 espaços | case | SQLFluff LT02 com `tab_space_size = 2` |
| `CAST(x AS TIPO)` no lugar de `x::TIPO` | projeto | SQLFluff CV11 |
| Vírgula no começo da linha | projeto (estilo do dono) | SQLFluff LT04 com `line_position = leading` |
| 1ª coluna na linha de baixo do `SELECT` | projeto (exigência do lint da indentação do case) | SQLFluff LT09 e LT02: a regra que verifica os 2 espaços pede essa quebra |
| `AS` só em coluna renomeada ou expressão; sem autoalias (`id AS id`) | projeto (estilo do dono) | SQLFluff AL09 |
| `WHERE 1 = 1` e um `AND` por linha | projeto (estilo do dono) | SQLFluff com `implicit_indents = allow` |
| Identificadores em snake_case minúsculo; CTEs no padrão `tNomeCte` | projeto | SQLFluff CP02 com `ignore_words_regex = ^t[A-Z][A-Za-z0-9]*$`. O case pede só um nome descritivo para a CTE; o padrão `tNomeCte` não conflita com ele, e o PostgreSQL aceita o nome sem aspas (guarda em minúsculas) |
| Macros do projeto visíveis no lint | projeto | SQLFluff com o templater do dbt, que compila o modelo como o dbt |
| Estilo do SQL dos testes genéricos (`tests/generic/`) | projeto | **Lacuna.** O SQLFluff com o templater do dbt pula os arquivos `{% test %}` ("Skipped file ... because it is a macro", medido em 2026-11-09 com `sqlfluff lint tests/generic`), e o CI só passa `models` ao linter (`sqlfluff lint models`). Cobertura que existe: `verificar_convencoes.py` lê `models`, `macros` e `tests` (janelas, `ROWS BETWEEN`, `SELECT *` por camada, zero como ausência), mas não o estilo (caixa, vírgulas, indentação, ordem das colunas). Os testes singulares de `tests/` e as macros passam no `sqlfluff lint tests macros` rodado à mão, que o CI não roda. Os três testes genéricos têm revisão manual |

## Python

| Regra | Origem | Checagem |
|---|---|---|
| PEP 8 (exceto o alinhamento vertical), linha de até 99 colunas, imports ordenados, nomes, simplificação | projeto | `ruff check` (`ruff.toml`). O `ruff format` não roda, porque desfaria o alinhamento vertical permitido pelo estilo |
| Nada de relógio, sorteio ou ordem de arquivos do sistema operacional no caminho dos dados | case (código reprodutível, p. 2) | `verificar_reprodutibilidade.py`, nas pastas listadas no `pyproject.toml` |
| Testes | projeto | `pytest` |

## Quando cada checagem roda

- **Durante o trabalho:** o agente roda as checagens no ciclo das skills de qualidade.
- **A cada push e pull request:** o CI no GitHub Actions roda todas. Um PR que quebre qualquer regra acima não entra na `develop`.
