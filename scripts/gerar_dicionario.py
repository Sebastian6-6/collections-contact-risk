"""Gera `docs/dicionario-de-dados.md` a partir do manifest e do catalog do dbt.

Uso, a partir da raiz do repositório, depois de `python pipeline.py`:
    dbt docs generate
    python scripts/gerar_dicionario.py

O manifest (`target/manifest.json`) traz a descrição de cada tabela e coluna escrita nos YAML; o
catalog (`target/catalog.json`) traz o tipo real que o DuckDB gravou. A justificativa do tipo fica
na descrição do YAML, então o dicionário nunca diverge do banco. Modelos efêmeros não existem no
banco e ficam de fora. Os datasets do schema `analises` também.
"""

import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CAMADAS = (("bronze", "Camada bronze"), ("silver", "Camada silver"), ("gold", "Camada gold"))
SEM_DESCRICAO = "sem descrição"

ABERTURA = """\
Gerado por `scripts/gerar_dicionario.py` a partir de `target/manifest.json` (descrições dos YAML) \
e `target/catalog.json` (tipos reais do DuckDB). Não editar à mão: a descrição de cada coluna e a \
justificativa do tipo moram no YAML de `models/`.

## Ganhos medidos dos tipos

Medidas no DuckDB embutido desta máquina, 4 threads, 5 milhões de linhas, melhor de 3 execuções.

| Escolha | Alternativa | Medida |
|---|---|---|
| Chave substituta `INTEGER` | `md5` da chave natural | junção da tabela com ela mesma: 0,204 s \
contra 0,279 s. O `md5` ainda é reversível: 10 milhões de hashes de CPF em 3,1 s (G6, \
`docs/decisoes-de-modelagem.md`), e o CPF se espalharia por toda tabela. Tamanho em disco: não \
medido (4 bytes contra 32 caracteres, por construção) |
| `DATE` | texto `dd/mm/aaaa` | filtro de um ano: 0,004 s contra 0,076 s, porque o texto precisa \
de `strptime` a cada linha; o texto ainda aceita datas inválidas |
| `NUMERIC(18,2)` no capital | `DOUBLE` | soma de 5 milhões de valores com 2 casas: \
o `NUMERIC` dá 1782482175000,00 exato e o `DOUBLE` se afasta em cerca de 0,0001. \
Contra texto convertido a cada consulta: 0,002 s contra 0,039 s |
"""


def juntar_tabelas(manifest: dict, catalog: dict) -> list[dict]:
    """Cruza o catalog (tipos) com o manifest (descrições) e devolve as tabelas ordenadas.

    Cada tabela vira `{schema, nome, descricao, colunas}` com as colunas na ordem do banco. A
    ordem das tabelas é bronze, silver e gold, e dentro da camada por schema e nome. Entra só o
    que está no catalog, isto é, o que existe no banco.
    """
    descricoes = {**manifest.get("nodes", {}), **manifest.get("sources", {})}
    tabelas = []
    for grupo in ("nodes", "sources"):
        for id_unico, item in catalog.get(grupo, {}).items():
            schema = item["metadata"]["schema"]
            ordem = next(
                (i for i, (prefixo, _) in enumerate(CAMADAS) if schema.startswith(prefixo)), None
            )
            if ordem is None:
                continue
            origem = descricoes.get(id_unico, {})
            colunas_yaml = origem.get("columns", {})
            colunas = [
                {
                    "nome": nome,
                    "tipo": coluna["type"],
                    "descricao": colunas_yaml.get(nome, {}).get("description", "").strip(),
                }
                for nome, coluna in sorted(
                    item["columns"].items(), key=lambda par: par[1]["index"]
                )
            ]
            tabelas.append(
                {
                    "ordem": ordem,
                    "schema": schema,
                    "nome": item["metadata"]["name"],
                    "descricao": origem.get("description", "").strip(),
                    "colunas": colunas,
                }
            )
    tabelas.sort(key=lambda t: (t["ordem"], t["schema"], t["nome"]))
    return tabelas


def _celula(texto: str) -> str:
    """Deixa o texto numa linha só de tabela Markdown, escapando a barra vertical."""
    return " ".join(texto.split()).replace("|", r"\|")


def gerar_markdown(tabelas: list[dict], abertura: str) -> str:
    """Monta o Markdown: abertura, depois uma seção por camada e uma tabela por tabela."""
    linhas = ["# Dicionário de dados", "", abertura.rstrip(), ""]
    for ordem, (_, titulo) in enumerate(CAMADAS):
        da_camada = [t for t in tabelas if t["ordem"] == ordem]
        if not da_camada:
            continue
        linhas += [f"## {titulo}", ""]
        for tabela in da_camada:
            linhas += [f"### `{tabela['schema']}.{tabela['nome']}`", ""]
            if tabela["descricao"]:
                linhas += [_celula(tabela["descricao"]), ""]
            linhas += ["| Coluna | Tipo | Descrição |", "|---|---|---|"]
            for coluna in tabela["colunas"]:
                descricao = _celula(coluna["descricao"]) or SEM_DESCRICAO
                linhas.append(f"| `{coluna['nome']}` | `{coluna['tipo']}` | {descricao} |")
            linhas.append("")
    return "\n".join(linhas)


def main() -> None:
    """Lê os JSON do dbt em `target/` e grava `docs/dicionario-de-dados.md`."""
    manifest = json.loads((RAIZ / "target" / "manifest.json").read_text(encoding="utf-8"))
    catalog = json.loads((RAIZ / "target" / "catalog.json").read_text(encoding="utf-8"))
    texto = gerar_markdown(juntar_tabelas(manifest, catalog), ABERTURA)
    (RAIZ / "docs" / "dicionario-de-dados.md").write_text(texto, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
