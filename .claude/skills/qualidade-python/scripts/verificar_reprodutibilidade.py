#!/usr/bin/env python3
"""Aponta, no código Python da pipeline, o que pode quebrar a reprodutibilidade.

O enunciado exige que a pipeline rode do estado inicial e produza exatamente os
mesmos resultados a cada rodada. Três coisas costumam quebrar isso sem que
nenhum linter reclame: ler o relógio, sortear valores e percorrer arquivos numa
ordem que depende do sistema operacional. O Ruff não trata nenhuma das três como
erro de projeto; este script trata.

Uso, a partir da raiz do projeto:
    python .claude/skills/qualidade-python/scripts/verificar_reprodutibilidade.py [caminhos...]

Sem caminhos, verifica ingestion/ e pipeline.py. Sai com código 1 se houver achado.
Uma linha pode ser liberada com o comentário `# reprodutivel: <motivo>`.
"""

import argparse
import ast
import sys
from dataclasses import dataclass
from pathlib import Path

CAMINHOS_PADRAO = ("ingestion", "pipeline.py")
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


def listar_arquivos_python(caminhos: list[Path]) -> list[Path]:
    arquivos = set()
    for caminho in caminhos:
        if caminho.is_dir():
            arquivos.update(caminho.rglob("*.py"))  # reprodutivel: ordenado no return
        elif caminho.suffix == ".py" and caminho.exists():
            arquivos.add(caminho)
    return sorted(arquivo for arquivo in arquivos if "tests" not in arquivo.parts)


def main(argumentos: list[str] | None = None) -> int:
    # Consoles do Windows usam cp1252 por padrão e quebrariam os acentos da saída.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    leitor = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    leitor.add_argument("caminhos", nargs="*", type=Path)
    opcoes = leitor.parse_args(argumentos)

    caminhos = opcoes.caminhos or [Path(nome) for nome in CAMINHOS_PADRAO]
    achados = [
        achado
        for arquivo in listar_arquivos_python(caminhos)
        for achado in verificar_codigo(arquivo, arquivo.read_text(encoding="utf-8"))
    ]
    for achado in achados:
        print(achado.formatar())
    print(f"{len(achados)} achado(s)")
    return 1 if achados else 0


if __name__ == "__main__":
    sys.exit(main())
