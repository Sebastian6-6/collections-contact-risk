# qualidade-sql

Ciclo de qualidade para todo SQL e todo modelo dbt deste repositório: primeiro correto, depois dentro das convenções, depois rápido, e cada etapa comprovada por um comando.

Criado por **Pedro Alexandre Piassi Silva** · [![LinkedIn: Pedro Piassi](https://img.shields.io/badge/LinkedIn-Pedro_Piassi-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/pedro-piassi6/)

## Por que existe

As convenções SQL do case são avaliadas, e três delas nenhum linter conhece: só `ROW_NUMBER()` e `SUM()` como funções de janela, frame `ROWS BETWEEN` obrigatório e "ausência de dado é `NULL`, nunca zero". O SQL também precisa rodar no DuckDB sem sair do dialeto PostgreSQL. A skill junta tudo isso num ciclo único, que o agente segue a cada mudança.

## O ciclo

| Etapa | O que comprova | Como |
|---|---|---|
| 1. Granularidade | o que é uma linha de saída | uma frase, antes de escrever |
| 2. Escrita | legibilidade | uma CTE por etapa, colunas explícitas, `CAST` |
| 3. Correção | a lógica está certa | `dbt build --select <modelo>` + testes unitários do dbt |
| 4. Convenções | o case é seguido | SQLFluff + `verificar_convencoes.py` |
| 5. Desempenho | a mudança melhora o plano real | `explicar_modelo.py` (EXPLAIN ANALYZE) + checklist |
| 6. Relato | o que rodou e o resultado | saída dos comandos |

## Scripts

| Script | O que faz |
|---|---|
| `scripts/verificar_convencoes.py` | Aponta funções de janela fora de `ROW_NUMBER()`/`SUM()`, janela sem `ROWS BETWEEN`, `SELECT *` na silver e na gold, e `COALESCE(x, 0)` como possível zero no lugar de `NULL` |
| `scripts/explicar_modelo.py` | Roda `EXPLAIN ANALYZE` no SQL compilado de um modelo e destaca produto cartesiano e joins sem igualdade |

Os dois têm testes (`scripts/test_*.py`) e passam no Ruff.

## Referências

- `references/convencoes-case.md`: cada regra do case ligada à verificação que a garante, mais o `.sqlfluff` validado.
- `references/otimizacao-duckdb.md`: como ler o plano, checklist de otimização, custo real das CTEs no DuckDB e as diferenças em relação ao PostgreSQL a evitar.

Base: documentação oficial do DuckDB 2.0 (CTEs, EXPLAIN ANALYZE, joins, guia de desempenho) e do SQLFluff 4.5.
