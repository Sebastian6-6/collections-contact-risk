#!/usr/bin/env python3
"""Aponta, no código Python, o que pode quebrar a reprodutibilidade.

Uma pipeline reprodutível roda do estado inicial e produz exatamente os mesmos
resultados a cada rodada. Três coisas costumam quebrar isso sem que
nenhum linter reclame: ler o relógio, sortear valores e percorrer arquivos numa
ordem que depende do sistema operacional. O Ruff não trata nenhuma das três como
erro de projeto; este script trata.

Uso, a partir da raiz do projeto:
    python .claude/skills/qualidade-python/scripts/verificar_reprodutibilidade.py [caminhos...]
    (opção --config arquivo para indicar outro pyproject.toml)

Sem caminhos, usa `caminhos` de `[tool.verificar_reprodutibilidade]` no
`pyproject.toml` (procurado subindo a partir da pasta atual, ou indicado com
`--config`); esses caminhos valem a partir da pasta do pyproject.toml, e os
informados na linha de comando, a partir da pasta atual. Sem configuração,
verifica a pasta atual. Pastas `.venv`, `venv`, `tests`, `__pycache__`, ocultas
e arquivos `test_*.py` ficam sempre de fora.
Sai com código 1 se houver achado. Um caminho configurado que não existe vira
aviso e só muda o código de saída com --estrito. Se nenhum arquivo foi
verificado, a última linha diz isso.
Uma linha pode ser liberada com o comentário `# reprodutivel: <motivo>`.
"""

import argparse
import ast
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path

TABELA_CONFIG = "verificar_reprodutibilidade"
PASTAS_IGNORADAS = {".venv", "venv", "tests", "__pycache__"}
MARCA_LIBERACAO = "# reprodutivel:"

CHAMADAS_DE_RELOGIO = {
    "datetime.now",
    "datetime.utcnow",
    "datetime.today",
    "date.today",
    "time.time",
    "time.time_ns",
    "time.localtime",
}
MODULOS_DE_SORTEIO = {"random", "secrets", "uuid"}
METODOS_DE_LISTAGEM = {"glob", "rglob", "iglob", "iterdir", "listdir", "scandir"}
FUNCOES_DE_LISTAGEM = {"os.walk"}


@dataclass(frozen=True)
class Achado:
    """Um trecho que pode fazer duas execuções darem resultados diferentes."""

    arquivo: Path
    linha: int
    regra: str
    mensagem: str

    def formatar(self) -> str:
        return f"{self.arquivo}:{self.linha}: [{self.regra}] {self.mensagem}"


def nome_qualificado(no: ast.expr) -> str:
    """Transforma `datetime.datetime.now` em texto; devolve '' para expressões complexas."""
    if isinstance(no, ast.Name):
        return no.id
    if isinstance(no, ast.Attribute):
        prefixo = nome_qualificado(no.value)
        return f"{prefixo}.{no.attr}" if prefixo else ""
    return ""


def chamadas_dentro_de_sorted(arvore: ast.AST) -> set[int]:
    """Ids das chamadas que já estão envolvidas por sorted(...), e portanto têm ordem fixa."""
    protegidas = set()
    for no in ast.walk(arvore):
        if isinstance(no, ast.Call) and nome_qualificado(no.func) == "sorted":
            for argumento in no.args:
                protegidas.update(id(filho) for filho in ast.walk(argumento))
    return protegidas


def verificar_codigo(arquivo: Path, codigo: str) -> list[Achado]:
    arvore = ast.parse(codigo, filename=str(arquivo))
    linhas = codigo.splitlines()
    protegidas = chamadas_dentro_de_sorted(arvore)
    achados = []

    for no in ast.walk(arvore):
        if isinstance(no, ast.Import | ast.ImportFrom):
            modulos = (
                [no.module or ""] if isinstance(no, ast.ImportFrom) else [a.name for a in no.names]
            )
            for modulo in modulos:
                if modulo.split(".")[0] in MODULOS_DE_SORTEIO:
                    achados.append(
                        Achado(
                            arquivo,
                            no.lineno,
                            "sorteio",
                            f"import de {modulo}: valores sorteados mudam a cada execução",
                        )
                    )
        if not isinstance(no, ast.Call):
            continue
        nome = nome_qualificado(no.func)
        if any(nome == chamada or nome.endswith(f".{chamada}") for chamada in CHAMADAS_DE_RELOGIO):
            achados.append(
                Achado(
                    arquivo,
                    no.lineno,
                    "relogio",
                    f"{nome}(): horário de execução nos dados muda a cada rodada",
                )
            )
        lista_arquivos = (
            nome.rsplit(".", 1)[-1] in METODOS_DE_LISTAGEM or nome in FUNCOES_DE_LISTAGEM
        )
        if lista_arquivos and id(no) not in protegidas:
            achados.append(
                Achado(
                    arquivo,
                    no.lineno,
                    "ordem-de-arquivos",
                    f"{nome}() sem sorted(): a ordem depende do sistema operacional",
                )
            )

    return sorted(
        (achado for achado in achados if MARCA_LIBERACAO not in linhas[achado.linha - 1]),
        key=lambda achado: (achado.linha, achado.regra),
    )


def localizar_pyproject(inicio: Path) -> Path | None:
    """Sobe a partir de `inicio` até achar um pyproject.toml; None se não houver."""
    inicio = inicio.resolve()
    for pasta in (inicio, *inicio.parents):
        arquivo_config = pasta / "pyproject.toml"
        if arquivo_config.is_file():
            return arquivo_config
    return None


def carregar_caminhos(config: Path | None, inicio: Path) -> list[Path]:
    """Lê `caminhos` de `[tool.verificar_reprodutibilidade]`; o padrão é a pasta atual."""
    arquivo = config or localizar_pyproject(inicio)
    if arquivo is None:
        return [Path()]
    with arquivo.open("rb") as aberto:
        tabela = tomllib.load(aberto).get("tool", {}).get(TABELA_CONFIG, {})
    base = arquivo.resolve().parent
    return [relativo_a_pasta_atual(base / nome) for nome in tabela.get("caminhos", ["."])]


def relativo_a_pasta_atual(caminho: Path) -> Path:
    """Devolve `caminho` relativo à pasta atual se estiver dentro dela, para a saída ser curta."""
    try:
        return caminho.relative_to(Path.cwd().resolve())
    except ValueError:
        return caminho


def deve_ignorar(arquivo: Path, bases: list[Path]) -> bool:
    """True para testes, ambientes virtuais, caches e pastas ocultas.

    Só as pastas abaixo do caminho pedido contam, para não excluir um projeto
    inteiro por causa da pasta onde ele está.
    """
    if arquivo.name.startswith("test_"):
        return True
    partes = arquivo.parts
    for base in bases:
        if base.is_dir() and base in arquivo.parents:
            partes = arquivo.relative_to(base).parts
            break
    return any(parte in PASTAS_IGNORADAS or parte.startswith(".") for parte in partes[:-1])


def listar_arquivos_python(caminhos: list[Path]) -> list[Path]:
    arquivos = set()
    for caminho in caminhos:
        if caminho.is_dir():
            arquivos.update(caminho.rglob("*.py"))  # reprodutivel: ordenado no return
        elif caminho.suffix == ".py" and caminho.exists():
            arquivos.add(caminho)
    return sorted(arquivo for arquivo in arquivos if not deve_ignorar(arquivo, caminhos))


def main(argumentos: list[str] | None = None) -> int:
    # Consoles do Windows usam cp1252 por padrão e quebrariam os acentos da saída.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    leitor = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    leitor.add_argument("caminhos", nargs="*", type=Path)
    leitor.add_argument("--config", type=Path, help="pyproject.toml com os parâmetros")
    leitor.add_argument("--estrito", action="store_true", help="avisos também falham")
    opcoes = leitor.parse_args(argumentos)

    caminhos = opcoes.caminhos or carregar_caminhos(opcoes.config, Path.cwd())
    avisos = [
        f"[aviso] caminho configurado não existe: {caminho}"
        for caminho in caminhos
        if not opcoes.caminhos and not caminho.exists()
    ]
    arquivos = listar_arquivos_python(caminhos)
    achados = [
        achado
        for arquivo in arquivos
        for achado in verificar_codigo(arquivo, arquivo.read_text(encoding="utf-8"))
    ]
    for aviso in avisos:
        print(aviso)
    for achado in achados:
        print(achado.formatar())
    vazio = "; nenhum arquivo verificado" if not arquivos else ""
    print(f"{len(achados)} achado(s){vazio}")
    return 1 if achados or (opcoes.estrito and avisos) else 0


if __name__ == "__main__":
    sys.exit(main())
