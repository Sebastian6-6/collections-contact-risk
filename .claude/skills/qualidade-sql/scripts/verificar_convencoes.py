#!/usr/bin/env python3
"""Confere as convenções SQL do case que nenhum linter cobre.

O SQLFluff garante maiúsculas, indentação e CTEs no lugar de subconsultas, mas
não conhece três regras do AGENTS.md: só ROW_NUMBER() e SUM() como funções de
janela, frame sempre declarado com ROWS BETWEEN, e ausência de dado como NULL,
nunca zero. Este script cobre essas três e o SELECT * nas camadas silver e gold.

Uso, a partir da raiz do projeto:
    python .claude/skills/qualidade-sql/scripts/verificar_convencoes.py [caminhos...]

Sem caminhos, verifica models/, macros/ e tests/. Sai com código 1 se houver erro.
Avisos (heurísticas) não mudam o código de saída, a menos que se use --estrito.
"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

FUNCOES_JANELA_PERMITIDAS = {"ROW_NUMBER", "SUM"}
CAMADAS_SEM_SELECT_ESTRELA = {"silver", "gold"}
CAMINHOS_PADRAO = ("models", "macros", "tests")

PADRAO_COMENTARIOS = re.compile(r"--[^\n]*|/\*.*?\*/|\{#.*?#\}", re.DOTALL)
PADRAO_OVER = re.compile(r"\bOVER\b", re.IGNORECASE)
PADRAO_NOME_FUNCAO = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*$")
PADRAO_SELECT_ESTRELA = re.compile(
    r"\bSELECT\s+(?:DISTINCT\s+)?(?:[A-Za-z_][A-Za-z0-9_]*\.)?\*", re.IGNORECASE
)
PADRAO_ZERO_COMO_AUSENCIA = re.compile(
    r"\b(?:COALESCE|IFNULL|NVL)\s*\((?:[^()]|\([^()]*\))*,\s*0(?:\.0+)?\s*\)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class Achado:
    """Uma violação encontrada, já com a linha onde aparece no arquivo original."""

    arquivo: Path
    linha: int
    regra: str
    mensagem: str
    gravidade: str  # "erro" ou "aviso"

    def formatar(self) -> str:
        return f"{self.arquivo}:{self.linha}: [{self.gravidade}:{self.regra}] {self.mensagem}"


def apagar_comentarios(sql: str) -> str:
    """Troca comentários SQL e Jinja por espaços, mantendo quebras de linha.

    Manter o comprimento e as quebras faz a posição de cada achado continuar
    apontando para a linha certa do arquivo original.
    """

    def em_branco(trecho: re.Match) -> str:
        return re.sub(r"[^\n]", " ", trecho.group(0))

    return PADRAO_COMENTARIOS.sub(em_branco, sql)


def linha_da_posicao(sql: str, posicao: int) -> int:
    return sql.count("\n", 0, posicao) + 1


def fechar_parenteses(sql: str, abertura: int) -> int:
    """Devolve a posição do parêntese que fecha o que abre em `abertura`, ou -1."""
    profundidade = 0
    for posicao in range(abertura, len(sql)):
        if sql[posicao] == "(":
            profundidade += 1
        elif sql[posicao] == ")":
            profundidade -= 1
            if profundidade == 0:
                return posicao
    return -1


def abrir_parenteses(sql: str, fechamento: int) -> int:
    """Devolve a posição do parêntese que abre o que fecha em `fechamento`, ou -1."""
    profundidade = 0
    for posicao in range(fechamento, -1, -1):
        if sql[posicao] == ")":
            profundidade += 1
        elif sql[posicao] == "(":
            profundidade -= 1
            if profundidade == 0:
                return posicao
    return -1


def nome_da_funcao_antes_do_over(sql: str, inicio_over: int) -> str | None:
    """Acha o nome da função cujo `(...)` termina logo antes de OVER."""
    antes = sql[:inicio_over].rstrip()
    if not antes.endswith(")"):
        return None
    abertura = abrir_parenteses(antes, len(antes) - 1)
    if abertura < 0:
        return None
    nome = PADRAO_NOME_FUNCAO.search(antes[:abertura])
    return nome.group(1).upper() if nome else None


def verificar_janelas(arquivo: Path, sql: str) -> list[Achado]:
    achados = []
    for ocorrencia in PADRAO_OVER.finditer(sql):
        linha = linha_da_posicao(sql, ocorrencia.start())
        funcao = nome_da_funcao_antes_do_over(sql, ocorrencia.start())
        if funcao and funcao not in FUNCOES_JANELA_PERMITIDAS:
            achados.append(
                Achado(
                    arquivo,
                    linha,
                    "janela-nao-permitida",
                    f"{funcao}() como janela; o case permite só ROW_NUMBER() e SUM()",
                    "erro",
                )
            )

        depois = sql[ocorrencia.end() :]
        abertura_relativa = len(depois) - len(depois.lstrip())
        if not depois[abertura_relativa:].startswith("("):
            achados.append(
                Achado(
                    arquivo,
                    linha,
                    "janela-nomeada",
                    "OVER sem parênteses (janela nomeada): declare o frame no próprio OVER",
                    "erro",
                )
            )
            continue
        abertura = ocorrencia.end() + abertura_relativa
        fechamento = fechar_parenteses(sql, abertura)
        clausula = sql[abertura : fechamento + 1] if fechamento > 0 else sql[abertura:]
        if not re.search(r"\bROWS\s+BETWEEN\b", clausula, re.IGNORECASE):
            achados.append(
                Achado(
                    arquivo,
                    linha,
                    "janela-sem-frame",
                    "OVER sem ROWS BETWEEN; o case exige o frame declarado",
                    "erro",
                )
            )
    return achados


def camada_do_arquivo(arquivo: Path) -> str | None:
    partes = [parte.lower() for parte in arquivo.parts]
    if "models" not in partes:
        return None
    indice = partes.index("models")
    return partes[indice + 1] if indice + 1 < len(partes) else None


def verificar_select_estrela(arquivo: Path, sql: str) -> list[Achado]:
    if camada_do_arquivo(arquivo) not in CAMADAS_SEM_SELECT_ESTRELA:
        return []
    return [
        Achado(
            arquivo,
            linha_da_posicao(sql, ocorrencia.start()),
            "select-estrela",
            "SELECT * não é permitido nas camadas silver e gold",
            "erro",
        )
        for ocorrencia in PADRAO_SELECT_ESTRELA.finditer(sql)
    ]


def verificar_zero_como_ausencia(arquivo: Path, sql: str) -> list[Achado]:
    return [
        Achado(
            arquivo,
            linha_da_posicao(sql, ocorrencia.start()),
            "zero-como-ausencia",
            "valor padrão 0 para dado ausente; o case pede NULL. Confirme se é uma contagem real",
            "aviso",
        )
        for ocorrencia in PADRAO_ZERO_COMO_AUSENCIA.finditer(sql)
    ]


def verificar_arquivo(arquivo: Path) -> list[Achado]:
    sql = apagar_comentarios(arquivo.read_text(encoding="utf-8"))
    return (
        verificar_janelas(arquivo, sql)
        + verificar_select_estrela(arquivo, sql)
        + verificar_zero_como_ausencia(arquivo, sql)
    )


def listar_arquivos_sql(caminhos: list[Path]) -> list[Path]:
    """Expande pastas em arquivos .sql, em ordem estável para a saída ser reproduzível."""
    arquivos = set()
    for caminho in caminhos:
        if caminho.is_dir():
            arquivos.update(caminho.rglob("*.sql"))  # reprodutivel: ordenado no return
        elif caminho.suffix.lower() == ".sql" and caminho.exists():
            arquivos.add(caminho)
    return sorted(arquivos)


def main(argumentos: list[str] | None = None) -> int:
    # Consoles do Windows usam cp1252 por padrão e quebrariam os acentos da saída.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    leitor = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    leitor.add_argument("caminhos", nargs="*", type=Path)
    leitor.add_argument("--estrito", action="store_true", help="avisos também falham")
    opcoes = leitor.parse_args(argumentos)

    caminhos = opcoes.caminhos or [Path(nome) for nome in CAMINHOS_PADRAO]
    achados = [
        achado
        for arquivo in listar_arquivos_sql(caminhos)
        for achado in verificar_arquivo(arquivo)
    ]
    for achado in achados:
        print(achado.formatar())

    erros = sum(achado.gravidade == "erro" for achado in achados)
    avisos = len(achados) - erros
    print(f"{erros} erro(s), {avisos} aviso(s)")
    falhou = erros > 0 or (opcoes.estrito and avisos > 0)
    return 1 if falhou else 0


if __name__ == "__main__":
    sys.exit(main())
