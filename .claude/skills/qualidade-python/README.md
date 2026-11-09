# qualidade-python

Ciclo de qualidade para código Python, em qualquer projeto: teste antes, código no meu estilo, ferramentas que pegam o que passa na leitura e uma passada deliberada de simplificação.

Criado por **Pedro Alexandre Piassi Silva** · [![LinkedIn: Pedro Piassi](https://img.shields.io/badge/LinkedIn-Pedro_Piassi-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/pedro-piassi6/)

## Por que existe

A skill `convencoes-codigo-pessoal` diz **como** escrevo código. Esta skill diz **em que ordem** o trabalho acontece e **como provar** que terminou. Ela também cobre um risco que o Ruff não conhece: código que lê o relógio, sorteia valores ou percorre arquivos numa ordem que depende do sistema operacional produz resultados diferentes a cada execução. O verificador dessa parte vigia as pastas que o projeto configurar em `[tool.verificar_reprodutibilidade]`.

## O ciclo

| Etapa | Como |
|---|---|
| 1. Teste que falha | pytest, com os casos reais de `docs/perfil-das-fontes.md` |
| 2. Menor código que passa | seguindo `convencoes-codigo-pessoal` |
| 3. Testes verdes | `python -m pytest -q` |
| 4. Ferramentas | `ruff check` (e `ruff format`, se o projeto usar formatador), `verificar_reprodutibilidade.py` |
| 5. Simplificação | checklist em `references/simplificacao.md` |
| 6. Relato com evidência | saída dos comandos |

## Scripts

| Script | O que faz |
|---|---|
| `scripts/verificar_reprodutibilidade.py` | Aponta leitura de relógio, módulos de sorteio e listagem de arquivos sem `sorted()` nas pastas configuradas pelo projeto. Um trecho legítimo é liberado com `# reprodutivel: <motivo>`, que deixa a decisão registrada no código |

Tem testes (`scripts/test_verificar_reprodutibilidade.py`) e passa no Ruff.

## Referências

- `references/simplificacao.md`: checklist de simplificação (estrutura, expressões, biblioteca padrão, erros, limpeza).
- `references/ruff.md`: um `ruff.toml` validado como ponto de partida, o porquê de cada regra e quando dispensar o formatador.
