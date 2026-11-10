"""Conectores: dizem de onde vêm os arquivos de uma entidade.

Um conector recebe um `Local` (uma entrada da lista `arquivos` da configuração) e a raiz do
repositório e devolve os arquivos a ler. Para uma origem nova (uma API, um bucket), escreva a
função aqui com `@conector("nome")` e use `origem: nome` na configuração; o `main` não muda.
Uma API grava a resposta como arquivo numa pasta versionada antes de ser lida, e a partir daí
vale o mesmo leitor e a mesma rastreabilidade.

Quem faz essa gravação é o baixador (`@baixador("nome")`), que roda só quando chamado
(`python -m ingestion.main --baixar <fonte>`), nunca na pipeline: a pipeline e o CI leem a
pasta versionada com o conector `pasta`, sem rede.
"""

from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from ingestion import ErroDeIngestao
from ingestion.receita import ler_parametros, montar_extrato, raizes_dos_cnpjs
from ingestion.webdav import ClienteWebDav

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


# =============================================================================
# Baixadores: gravam numa pasta versionada o que vem de fora
# =============================================================================


@dataclass(frozen=True)
class Baixa:
    """O bloco `_baixar` de uma fonte: o baixador, a pasta de destino e os parâmetros dele."""

    fonte: str
    origem: str
    destino: str
    parametros: dict


type Baixador = Callable[[Baixa, Path, Path], list[Path]]

BAIXADORES: dict[str, Baixador] = {}


def baixador(nome: str) -> Callable[[Baixador], Baixador]:
    """Registra a função como baixador da origem `nome`, o `origem` do bloco `_baixar`.

    A função recebe a `Baixa`, a raiz do repositório e o banco da pipeline (de onde sai, por
    exemplo, a lista do que baixar) e devolve os arquivos gravados.
    """

    def registrar(funcao: Baixador) -> Baixador:
        BAIXADORES[nome] = funcao
        return funcao

    return registrar


def obter_baixador(nome: str) -> Baixador:
    """Devolve o baixador registrado ou diz quais origens existem."""
    if nome not in BAIXADORES:
        existentes = ", ".join(sorted(BAIXADORES))
        raise ErroDeIngestao(f"origem '{nome}' sem baixador registrado; disponíveis: {existentes}")
    return BAIXADORES[nome]


def _dentro_da_raiz(raiz: Path, relativo: str) -> Path:
    caminho = (raiz / relativo).resolve()
    if not caminho.is_relative_to(raiz.resolve()):
        raise ErroDeIngestao(f"'{relativo}' está fora da raiz do repositório")
    return caminho


@baixador("receita")
def baixar_receita(baixa: Baixa, raiz: Path, banco: Path) -> list[Path]:
    """Baixa os dados abertos do CNPJ da Receita e grava o extrato das empresas recebidas.

    As raízes de CNPJ vêm das colunas `raizes_de` do banco da pipeline, que precisa ter rodado.
    O acesso é o WebDAV público do compartilhamento oficial (token como usuário).
    """
    parametros = ler_parametros(baixa.parametros)
    raizes = raizes_dos_cnpjs(banco, parametros.raizes_de)
    cliente = ClienteWebDav(parametros.url_webdav, parametros.token)
    return montar_extrato(
        cliente,
        parametros,
        raizes,
        _dentro_da_raiz(raiz, baixa.destino),
        _dentro_da_raiz(raiz, parametros.cache),
    )
