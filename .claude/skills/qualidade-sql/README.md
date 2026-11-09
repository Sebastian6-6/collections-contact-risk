# qualidade-sql

Ciclo de qualidade para SQL e modelos dbt, em qualquer projeto: primeiro correto, depois dentro das convenções do projeto, depois rápido, e cada etapa comprovada por um comando.

Criado por **Pedro Alexandre Piassi Silva** · [![LinkedIn: Pedro Piassi](https://img.shields.io/badge/LinkedIn-Pedro_Piassi-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/pedro-piassi6/)

## Por que existe

Um linter de SQL cuida do estilo, mas algumas regras de projeto ficam fora do alcance dele: lista de funções de janela permitidas, frame obrigatório, `SELECT *` proibido em certas camadas, zero usado como ausência. A skill não traz nenhuma regra de projeto. Ela traz o ciclo de trabalho e verificadores que leem as regras da configuração de cada projeto (`.sqlfluff` e `pyproject.toml`).

## O ciclo

| Etapa | O que comprova | Como |
|---|---|---|
| 1. Granularidade | o que é uma linha de saída | uma frase, antes de escrever |
| 2. Escrita | legibilidade | uma CTE por etapa, colunas explícitas, `CAST` |
| 3. Correção | a lógica está certa | `dbt build --select <modelo>` + testes unitários do dbt |
| 4. Convenções | as regras do projeto são seguidas | SQLFluff + `verificar_convencoes.py` |
| 5. Desempenho | a mudança melhora o plano real | `explicar_modelo.py` (EXPLAIN ANALYZE) + checklist |
| 6. Relato | o que rodou e o resultado | saída dos comandos |

## Scripts

| Script | O que faz |
|---|---|
| `scripts/verificar_convencoes.py` | Aponta o que o projeto configurou em `[tool.verificar_convencoes_sql]`: funções de janela fora da lista permitida, janela sem `ROWS BETWEEN`, `SELECT *` nas camadas proibidas e `COALESCE(x, 0)` como possível zero no lugar de `NULL`. Sem configuração, não aponta nada |
| `scripts/explicar_modelo.py` | Roda `EXPLAIN ANALYZE` no SQL compilado de um modelo e destaca produto cartesiano e joins sem igualdade |

Os dois têm testes (`scripts/test_*.py`) e passam no Ruff.

## Testes comparativos

Cada caso de teste roda com e sem a skill, no mesmo modelo (Sonnet 5.5, esforço medium), e um script confere critérios objetivos (lint, verificador, construções esperadas). Na primeira rodada (2 casos), a skill atendeu 20 de 21 critérios (95%), contra 19 de 21 (90%) sem ela. O critério perdido foi o lint de um modelo com macro própria, que o templater jinja do SQLFluff não enxerga; isso levou à recomendação do templater do dbt em `references/configuracao.md`. Na segunda rodada, o mesmo caso passou com 0 violações.

## Referências

- `references/configuracao.md`: como um projeto liga as próprias regras à skill (`.sqlfluff` com o templater do dbt e os parâmetros do verificador).
- `references/otimizacao-duckdb.md`: como ler o plano, checklist de otimização (incluindo o que um frame `ROWS` conta e como ler texto sujo), custo real das CTEs no DuckDB e as diferenças em relação ao PostgreSQL a evitar.

Base: documentação oficial do DuckDB 2.0 (CTEs, EXPLAIN ANALYZE, joins, guia de desempenho) e do SQLFluff 4.5.
