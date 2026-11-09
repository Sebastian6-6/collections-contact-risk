## Estrutura

- `ingestion/`: leitura dos arquivos dos provedores, sem transformação.
- `models/`: transformações em SQL, organizadas por camada (`bronze/`, `silver/`, `gold/`).
- `docs/`: ERD, decisões de modelagem e dicionário de dados.

## SQL

- Dialeto padrão: PostgreSQL.
- Funções nativas e tipos de dado em UPPER CASE (`SELECT`, `COALESCE`, `NUMERIC`).
- Uma CTE por etapa lógica, com nome descritivo.
- Funções de janela: usar apenas `ROW_NUMBER()` e `SUM()`, sempre com o frame declarado em `ROWS BETWEEN`.
- Ausência de dado é `NULL`, nunca zero.
- Modelos não geram linhas que não existam na origem: cada linha corresponde a um registro recebido.
- Nunca usar `SELECT *` em modelos das camadas silver e gold.
- Indentação de 2 espaços.

## Commits

- Seguir Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
- Um commit por mudança lógica. Mensagens descrevem o porquê, não só o quê.