"""Leitores: dizem como ler um formato de arquivo, sem transformar nada.

Cada leitor devolve uma `Leitura` com uma `LinhaLida` por linha recebida. Uma linha que o
leitor não consegue separar em colunas (CSV malformado ou em branco) entra com o texto
original e o motivo, e nunca derruba a leitura nem some. Um byte fora do encoding, ao
contrário, interrompe a leitura com o arquivo e a linha no erro: não há como saber o que o
byte significava. Para registrar um formato novo, escreva a função aqui com
`@leitor("nome")` e use `formato: nome` na configuração.
"""

import csv
import re
from collections.abc import Callable, Iterator, Sequence
from dataclasses import dataclass
from io import StringIO
from pathlib import Path

from ingestion import ErroDeIngestao

# =============================================================================
# Tipos e registro
# =============================================================================


@dataclass(frozen=True)
class LinhaLida:
    """Uma linha recebida: onde começa, o texto original e, se legível, os campos em texto."""

    numero: int
    texto: str
    campos: dict[str, str] | None
    motivo_ilegivel: str | None


@dataclass(frozen=True)
class Leitura:
    """O que um arquivo contém: as colunas do próprio arquivo, o cabeçalho e as linhas."""

    colunas: list[str]
    cabecalho: str | None
    linhas: list[LinhaLida]


Leitor = Callable[[Path, str, str, Sequence[str] | None], Leitura]

LEITORES: dict[str, Leitor] = {}


def leitor(nome: str) -> Callable[[Leitor], Leitor]:
    """Registra a função como leitor do formato `nome`, o mesmo valor de `formato` no YAML."""

    def registrar(funcao: Leitor) -> Leitor:
        LEITORES[nome] = funcao
        return funcao

    return registrar


def obter_leitor(nome: str) -> Leitor:
    """Devolve o leitor registrado ou diz quais formatos existem."""
    if nome not in LEITORES:
        raise ErroDeIngestao(
            f"formato '{nome}' sem leitor registrado; disponíveis: {', '.join(sorted(LEITORES))}"
        )
    return LEITORES[nome]


# =============================================================================
# Texto das linhas
# =============================================================================

TERMINADOR = re.compile(r"\r\n|\n|\r")
TERMINADORES = ("\r\n", "\n", "\r")


def sem_terminador(texto: str) -> str:
    """Tira só o fim de linha final; o texto da linha continua como foi recebido."""
    for terminador in TERMINADORES:
        if texto.endswith(terminador):
            return texto[: -len(terminador)]
    return texto


def ler_texto(caminho: Path, encoding: str) -> str:
    """Decodifica o arquivo inteiro; um byte inválido interrompe com o arquivo e a linha.

    A linha do erro é contada a partir dos bytes que vêm antes dele, porque o decodificador
    em blocos não diz em que linha estava quando falhou.
    """
    conteudo = caminho.read_bytes()
    try:
        return conteudo.decode(encoding)
    except UnicodeDecodeError as erro:
        anterior = conteudo[: erro.start].decode(encoding, errors="replace")
        linha = len(TERMINADOR.findall(anterior)) + 1
        raise ErroDeIngestao(
            f"{caminho.name}: byte fora do encoding {encoding} na linha {linha}"
        ) from erro


def linhas_fisicas(texto: str) -> StringIO:
    """Percorre as linhas físicas sem converter o fim de linha (CRLF continua CRLF)."""
    return StringIO(texto, newline="")


# =============================================================================
# CSV
# =============================================================================


def _ler_registros_csv(texto: str, separador: str):
    """Gera (linha onde começa, texto original, campos ou None, motivo) por registro CSV.

    O leitor do `csv` consome uma ou mais linhas físicas por registro (campo entre aspas
    pode ter quebra de linha); guardar o que ele consumiu preserva o texto original. O modo
    estrito faz aspas abertas até o fim do arquivo (linha cortada) virarem erro, em vez de
    uma linha aparentemente completa.
    """
    consumidas: list[str] = []

    def alimentar() -> Iterator[str]:
        for linha_fisica in linhas_fisicas(texto):
            consumidas.append(linha_fisica)
            yield linha_fisica

    registros = csv.reader(alimentar(), delimiter=separador, strict=True)
    linha_atual = 0
    while True:
        try:
            campos, erro = next(registros), None
        except StopIteration:
            return
        except csv.Error as excecao:
            campos, erro = None, f"CSV malformado: {excecao}"
        inicio = linha_atual + 1
        linha_atual += len(consumidas)
        original = sem_terminador("".join(consumidas))
        consumidas.clear()
        yield inicio, original, campos, erro


@leitor("csv")
def ler_csv(
    caminho: Path, encoding: str, separador: str, colunas: Sequence[str] | None = None
) -> Leitura:
    """Lê um CSV com todos os valores em texto; sem `colunas`, o cabeçalho é a 1ª linha.

    Com `colunas` (arquivo sem cabeçalho, como os da Receita), os nomes vêm da configuração e
    a 1ª linha já é um registro. Linha com número de campos diferente do das colunas,
    malformada ou em branco fica ilegível, com os campos nulos e o texto original guardado.
    """
    registros = _ler_registros_csv(ler_texto(caminho, encoding), separador)
    if colunas is not None:
        nomes = list(colunas)
        validar_colunas(caminho.name, nomes, "na configuração")
        return Leitura(colunas=nomes, cabecalho=None, linhas=_classificar(registros, nomes))
    primeiro = next(registros, None)
    if primeiro is None:
        return Leitura(colunas=[], cabecalho=None, linhas=[])
    _, cabecalho, nomes, erro = primeiro
    if erro or not nomes:
        raise ErroDeIngestao(f"{caminho.name}: cabeçalho ilegível ({erro or 'em branco'})")
    validar_colunas(caminho.name, nomes, "no cabeçalho")
    return Leitura(colunas=nomes, cabecalho=cabecalho, linhas=_classificar(registros, nomes))


def validar_colunas(origem: str, colunas: Sequence[str], onde: str) -> None:
    """Recusa lista de colunas vazia, com nome repetido ou sem nome; `origem` abre o erro."""
    if not colunas:
        raise ErroDeIngestao(f"{origem}: esperava ao menos uma coluna {onde}")
    repetidas = sorted({coluna for coluna in colunas if colunas.count(coluna) > 1})
    if repetidas:
        raise ErroDeIngestao(f"{origem}: colunas duplicadas {onde}: {repetidas}")
    if "" in colunas:
        raise ErroDeIngestao(f"{origem}: coluna sem nome {onde}")


def _classificar(registros, colunas: list[str]) -> list[LinhaLida]:
    return [
        _classificar_linha_csv(inicio, original, campos, erro, colunas)
        for inicio, original, campos, erro in registros
    ]


def _classificar_linha_csv(
    inicio: int,
    original: str,
    campos: list[str] | None,
    erro: str | None,
    colunas: list[str],
) -> LinhaLida:
    motivo = erro
    if motivo is None and campos == []:
        motivo = "linha em branco"
    if motivo is None and len(campos) != len(colunas):
        motivo = f"{len(campos)} campos, o cabeçalho tem {len(colunas)}"
    if motivo:
        return LinhaLida(inicio, original, None, motivo)
    return LinhaLida(inicio, original, dict(zip(colunas, campos, strict=True)), None)


# =============================================================================
# JSON Lines
# =============================================================================

COLUNA_JSONL = "registro"


@leitor("jsonl")
def ler_jsonl(
    caminho: Path, encoding: str, separador: str, colunas: Sequence[str] | None = None
) -> Leitura:
    """Lê um JSON Lines guardando o texto de cada linha na coluna `registro`.

    O JSON não é interpretado nem validado: as variantes de esquema e o JSON inválido são
    tratados na silver. `separador` existe só para casar com o contrato dos leitores, e
    `colunas` é recusada: o JSON Lines não tem colunas a nomear.
    """
    if colunas is not None:
        raise ErroDeIngestao(f"{caminho.name}: o formato 'jsonl' não aceita 'colunas'")
    textos = [sem_terminador(bruto) for bruto in linhas_fisicas(ler_texto(caminho, encoding))]
    linhas = [
        LinhaLida(numero, texto, {COLUNA_JSONL: texto}, None)
        for numero, texto in enumerate(textos, start=1)
    ]
    return Leitura(colunas=[COLUNA_JSONL], cabecalho=None, linhas=linhas)
