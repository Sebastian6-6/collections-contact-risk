#!/usr/bin/env python3
"""Confere convenções SQL que nenhum linter cobre, conforme as regras do projeto.

O SQLFluff garante maiúsculas, indentação e CTEs, mas não conhece regras como
restringir as funções de janela, exigir o frame com ROWS BETWEEN, tratar ausência
de dado como NULL e não usar SELECT * em certas camadas. Este script cobre essas
regras, e cada uma só vale se o projeto a ligar em `[tool.verificar_convencoes_sql]`
do `pyproject.toml` (procurado subindo a partir da pasta atual, ou indicado com
`--config`). Sem configuração, nada é cobrado além da leitura dos arquivos.

Parâmetros: caminhos, funcoes_janela_permitidas, exigir_frame_rows,
proibir_janela_nomeada, camadas_sem_select_estrela, alertar_zero_como_ausencia.

Uso, a partir da raiz do projeto:
    python .claude/skills/qualidade-sql/scripts/verificar_convencoes.py [caminhos...]
    (opção --config arquivo para indicar outro pyproject.toml)

Sem caminhos, usa o parâmetro `caminhos` (padrão: models, macros e tests). Sai com
código 1 se houver erro. Avisos (heurísticas) não mudam o código de saída, a menos
que se use --estrito.
"""

import argparse
import re
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path

TABELA_CONFIG = "verificar_convencoes_sql"

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
class Parametros:
    """Regras do projeto lidas do pyproject.toml; o padrão não cobra nada."""

    caminhos: tuple[str, ...] = ("models", "macros", "tests")
    funcoes_janela_permitidas: tuple[str, ...] = ()
    exigir_frame_rows: bool = False
    proibir_janela_nomeada: bool = False
    camadas_sem_select_estrela: tuple[str, ...] = ()
    alertar_zero_como_ausencia: bool = False


def localizar_pyproject(inicio: Path) -> Path | None:
    """Sobe a partir de `inicio` até achar um pyproject.toml; None se não houver."""
    inicio = inicio.resolve()
    for pasta in (inicio, *inicio.parents):
        arquivo_config = pasta / "pyproject.toml"
        if arquivo_config.is_file():
            return arquivo_config
    return None


def carregar_parametros(config: Path | None, inicio: Path) -> Parametros:
    """Lê `[tool.verificar_convencoes_sql]` de `config` ou do pyproject mais próximo.

    Chave ausente fica no padrão neutro, para o script valer em qualquer projeto.
    """
    arquivo = config or localizar_pyproject(inicio)
    if arquivo is None:
        return Parametros()
    with arquivo.open("rb") as aberto:
        tabela = tomllib.load(aberto).get("tool", {}).get(TABELA_CONFIG, {})
    padrao = Parametros()
    return Parametros(
        caminhos=tuple(tabela.get("caminhos", padrao.caminhos)),
        funcoes_janela_permitidas=tuple(
            nome.upper() for nome in tabela.get("funcoes_janela_permitidas", ())
        ),
        exigir_frame_rows=tabela.get("exigir_frame_rows", padrao.exigir_frame_rows),
        proibir_janela_nomeada=tabela.get("proibir_janela_nomeada", padrao.proibir_janela_nomeada),
        camadas_sem_select_estrela=tuple(
            camada.lower() for camada in tabela.get("camadas_sem_select_estrela", ())
        ),
        alertar_zero_como_ausencia=tabela.get(
            "alertar_zero_como_ausencia", padrao.alertar_zero_como_ausencia
        ),
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


def verificar_janelas(arquivo: Path, sql: str, parametros: Parametros) -> list[Achado]:
    achados = []
    permitidas = parametros.funcoes_janela_permitidas
    for ocorrencia in PADRAO_OVER.finditer(sql):
        linha = linha_da_posicao(sql, ocorrencia.start())
        funcao = nome_da_funcao_antes_do_over(sql, ocorrencia.start())
        if funcao and permitidas and funcao not in permitidas:
            lista = ", ".join(f"{nome}()" for nome in permitidas)
            achados.append(
                Achado(
                    arquivo,
                    linha,
                    "janela-nao-permitida",
                    f"{funcao}() como janela; a regra do projeto (pyproject.toml) "
                    f"permite só {lista}",
                    "erro",
                )
            )

        depois = sql[ocorrencia.end() :]
        abertura_relativa = len(depois) - len(depois.lstrip())
        if not depois[abertura_relativa:].startswith("("):
            if parametros.proibir_janela_nomeada:
                achados.append(
                    Achado(
                        arquivo,
                        linha,
                        "janela-nomeada",
                        "OVER sem parênteses (janela nomeada): a regra do projeto "
                        "(pyproject.toml) pede o frame no próprio OVER",
                        "erro",
                    )
                )
            continue
        abertura = ocorrencia.end() + abertura_relativa
        fechamento = fechar_parenteses(sql, abertura)
        clausula = sql[abertura : fechamento + 1] if fechamento > 0 else sql[abertura:]
        sem_frame = not re.search(r"\bROWS\s+BETWEEN\b", clausula, re.IGNORECASE)
        if parametros.exigir_frame_rows and sem_frame:
            achados.append(
                Achado(
                    arquivo,
                    linha,
                    "janela-sem-frame",
                    "OVER sem ROWS BETWEEN; a regra do projeto (pyproject.toml) "
                    "exige o frame declarado",
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


def verificar_select_estrela(arquivo: Path, sql: str, parametros: Parametros) -> list[Achado]:
    if camada_do_arquivo(arquivo) not in parametros.camadas_sem_select_estrela:
        return []
    return [
        Achado(
            arquivo,
            linha_da_posicao(sql, ocorrencia.start()),
            "select-estrela",
            "SELECT * não é permitido nesta camada pela regra do projeto (pyproject.toml)",
            "erro",
        )
        for ocorrencia in PADRAO_SELECT_ESTRELA.finditer(sql)
    ]


def verificar_zero_como_ausencia(arquivo: Path, sql: str, parametros: Parametros) -> list[Achado]:
    if not parametros.alertar_zero_como_ausencia:
        return []
    return [
        Achado(
            arquivo,
            linha_da_posicao(sql, ocorrencia.start()),
            "zero-como-ausencia",
            "valor padrão 0 para dado ausente; a regra do projeto (pyproject.toml) "
            "pede NULL. Confirme se é uma contagem real",
            "aviso",
        )
        for ocorrencia in PADRAO_ZERO_COMO_AUSENCIA.finditer(sql)
    ]


def verificar_arquivo(arquivo: Path, parametros: Parametros) -> list[Achado]:
    sql = apagar_comentarios(arquivo.read_text(encoding="utf-8"))
    return (
        verificar_janelas(arquivo, sql, parametros)
        + verificar_select_estrela(arquivo, sql, parametros)
        + verificar_zero_como_ausencia(arquivo, sql, parametros)
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
    leitor.add_argument("--config", type=Path, help="pyproject.toml com os parâmetros")
    leitor.add_argument("--estrito", action="store_true", help="avisos também falham")
    opcoes = leitor.parse_args(argumentos)

    parametros = carregar_parametros(opcoes.config, Path.cwd())
    caminhos = opcoes.caminhos or [Path(nome) for nome in parametros.caminhos]
    achados = [
        achado
        for arquivo in listar_arquivos_sql(caminhos)
        for achado in verificar_arquivo(arquivo, parametros)
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
