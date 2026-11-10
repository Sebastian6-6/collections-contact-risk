"""Conectores: dizem de onde vêm os arquivos de uma entidade.

Um conector recebe um `Local` (uma entrada da lista `arquivos` da configuração) e a raiz do
repositório e devolve os arquivos a ler. Para uma origem nova (uma API, um bucket), escreva a
função aqui com `@conector("nome")` e use `origem: nome` na configuração; o `main` não muda.
Uma API grava a resposta como arquivo numa pasta versionada antes de ser lida, e a partir daí
vale o mesmo leitor e a mesma rastreabilidade.
"""

from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from ingestion import ErroDeIngestao

# =============================================================================
# Tipos e registro
# =============================================================================


@dataclass(frozen=True)
class Local:
    """Um lugar onde a entidade recebe arquivos: a pasta e o padrão do nome."""

    caminho: str
    padrao: str


type Conector = Callable[[Local, Path], list[Path]]

CONECTORES: dict[str, Conector] = {}


def conector(nome: str) -> Callable[[Conector], Conector]:
    """Registra a função como conector da origem `nome`, o mesmo valor de `origem` no YAML."""

    def registrar(funcao: Conector) -> Conector:
        CONECTORES[nome] = funcao
        return funcao

    return registrar


def obter_conector(nome: str) -> Conector:
    """Devolve o conector registrado ou diz quais origens existem."""
    if nome not in CONECTORES:
        existentes = ", ".join(sorted(CONECTORES))
        raise ErroDeIngestao(f"origem '{nome}' sem conector registrado; disponíveis: {existentes}")
    return CONECTORES[nome]


# =============================================================================
# Pasta local
# =============================================================================


@conector("pasta")
def listar_pasta(local: Local, raiz: Path) -> list[Path]:
    """Lista os arquivos de `caminho` que casam com `padrao`, em ordem de nome.

    `caminho` vale a partir da raiz do repositório e a busca não desce em subpastas. A ordem
    fixa, pelo caminho em texto e não pela comparação de `Path` (que ignora maiúsculas no
    Windows), deixa a tabela igual em qualquer sistema operacional.
    """
    pasta = raiz / local.caminho
    if not pasta.is_dir():
        raise ErroDeIngestao(f"pasta '{local.caminho}' não existe")
    return sorted(
        (arquivo for arquivo in pasta.glob(local.padrao) if arquivo.is_file()),
        key=lambda arquivo: arquivo.as_posix(),
    )
