---
name: convencoes-codigo-pessoal
description: Minhas convenções pessoais de código — Python (nomes em português, estrutura do módulo, docstrings, comentários, erros, logs, encoding) e SQL (formatação, CTEs, alinhamento) — e como evitar padrões de escrita genéricos de IA. Use sempre que estiver escrevendo, editando, reformatando ou revisando código Python ou SQL, neste ou em qualquer outro projeto meu.
---

# Convenções de código pessoal

Valem em todo código novo. Num projeto, as regras dele (AGENTS.md, CLAUDE.md, configuração das ferramentas) vêm antes destas: quando houver conflito, siga o projeto e mantenha daqui tudo o que não conflita.

**Arquivo existente com outro estilo** (aspas, recuo, ordem de imports): siga o do arquivo e não reformate o que não é objeto da mudança. Misturar estilos é pior que qualquer um dos dois, e reformatar esconde no diff o que mudou.

## Python

### Nomes
- Variável e função em português, `snake_case`, com verbo no infinitivo para funções (`buscar_chaves_primarias`, `criar_tabela`). Classe em `PascalCase`, substantivo. Constante de módulo em MAIÚSCULAS. Helper privado com `_` na frente.
- O nome descreve a transformação exata. Nada de `processar_dados`, `handle_utils`, `aux`.
- Inglês só para jargão de API e de ferramenta: `logger`, `schema`, `engine`, `commit`, chaves externas.
- Não reutilize um nome com outro significado nem sobrescreva parâmetro: cada etapa ganha nome novo (`df_lido` → `df_tipado`).

### Estrutura do módulo
- Blocos do módulo separados por um título de seção:
  ```python
  # ======================================================================================
  # Leitura dos arquivos
  # ======================================================================================
  ```
- Dentro de uma função longa, cada etapa ganha um marcador curto: `# ── Chaves primárias ─────────`.
- Imports um por linha, em grupos separados por linha em branco (biblioteca padrão, terceiros, SDK da plataforma, locais), ordem alfabética dentro do grupo. Sem `import *`. Sem import dentro de função, salvo ciclo justificado.
- Duas linhas em branco entre funções e classes do módulo; uma entre métodos.

### Estilo
- PEP 8, com 4 espaços de recuo e aspas duplas (simples só para evitar escape).
- Alinhar na vertical atribuições e argumentos relacionados é permitido quando a leitura vira uma tabela (vários campos do mesmo registro, chamadas repetidas com os mesmos parâmetros). Fora desses blocos, um espaço em volta do `=`.
- Sem limite rígido de linha: quebre quando a leitura piorar.
- Type hints na API pública (parâmetros e retorno), com a sintaxe moderna (`list[str]`, `str | None`). Não tipar toda variável local.
- `is None` / `is not None`, f-strings, retorno antecipado em vez de `if` aninhado.

### Docstrings e comentários
- Toda função pública tem docstring. A primeira linha diz direto o que faz ("Lê o arquivo e devolve as linhas com a origem."), sem repetir o nome da função em prosa e sem "Este método é responsável por…".
- Sem seção de parâmetros e retorno quando a assinatura tipada já diz tudo. Quando o tipo não basta (um `dict` com chaves conhecidas, uma tupla), descreva a forma do retorno, com um exemplo curto se ajudar.
- Explique só o porquê que não é óbvio. `Raises` só quando a falha não é óbvia.
- Comentário em português, curto, registrando uma decisão. Nunca narra a linha nem numera passos que o nome da função já diz. Código comentado não fica no arquivo.

### Erros, logs e saída
- Código que roda em produção, com I/O, rede ou banco: `try/except` do erro específico, `logger` no erro e `raise`. Proibido `except:` vazio e `except Exception: pass`. Nunca escreva segredo nem variável de ambiente inteira no log.
- Ferramenta local (gerador, conversor, script de conferência) para em vez de produzir errado: cada premissa vira `assert` com uma mensagem que diz o que foi encontrado (`assert len(partes) == 4, f"esperadas 4 partes, achadas {len(partes)}"`).
- Mensagem para quem roda com prefixo de status: `[OK]`, `[INFO]`, `[WARN]`, `[ERRO]`. Em log, a severidade acompanha o prefixo.
- Bibliotecas verbosas com o log silenciado no nível do projeto, para o que importa não se perder.

### Encoding
- Texto e arquivo sempre com `encoding="utf-8"` explícito (`open`, `read_text`, `write_text`): o padrão do sistema varia (cp1252 no Windows) e corrompe acentos. CSV aberto também com `newline=""`.
- CLI que imprime acento: `sys.stdout.reconfigure(encoding="utf-8")` no início.

### Exemplo

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

Estilo de leitura em colunas. Se o projeto exigir outro recuo ou outro padrão de nomes, siga o projeto e mantenha o resto.

1. Palavras-chave e funções em MAIÚSCULAS. Colunas e tabelas em `snake_case`.
2. Recuo com espaços, sem tab. A 1ª coluna fica na linha do `SELECT`; as seguintes começam com a vírgula à esquerda, alinhadas para as expressões ficarem numa coluna só.
3. `AS` sempre explícito e alinhado na vertical numa coluna fixa.
4. Linha em branco entre grupos lógicos de colunas (identificadores, códigos e descrições, datas, métricas, controle).
5. `FROM` alinhado pela direita com o `SELECT`; `JOIN` com o recuo das colunas, aliases alinhados, o `AND` da condição terminando junto com o `ON`.
6. `WHERE 1=1` e um `AND` por predicado; `GROUP BY` e `ORDER BY` com o 1º item na mesma linha e os seguintes com a vírgula à esquerda.
7. CTEs no padrão `tNomeCte` (`t` minúsculo + PascalCase, sem acento e sem `_`): `WITH tBase AS (`, depois `, tCalc AS (`. CTEs que não são objeto de uma mudança mantêm o nome.
8. `UNION ALL` sozinho na linha, com linha em branco antes e depois, no recuo da CTE em que está.
9. Item de várias linhas (`CASE ... END`) com as continuações recuadas sob o próprio item.
10. Em `UNION`, nulo tipado: `CAST(NULL AS TIPO)`. Literais UTF-8 diretos (sem `U&'...'`).
11. Nunca vírgula sobrando antes do `FROM` nem depois do último item de uma lista: alguns motores aceitam, outros não.

```sql
WITH tBase AS (
    SELECT id                                             AS id
         , valor                                          AS valor
      FROM origem_a
     WHERE 1=1
       AND ativo = TRUE
)

SELECT b.id                                               AS id
     , SUM(b.valor)                                       AS valor_total
  FROM tBase b
 GROUP BY b.id
```

## Sem padrão de escrita de IA

Nada de "este código implementa uma solução robusta e abrangente para…", nada de emoji em comentário, nada de resumo redundante no fim de um arquivo.
