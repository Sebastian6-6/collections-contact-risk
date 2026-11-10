"""Extrato dos dados abertos do CNPJ (Receita Federal): baixa os zips e guarda só o necessário.

A Receita publica por mês 37 zips (7,8 GB) com o cadastro de todas as empresas do país. O
projeto precisa só das empresas recebidas dos provedores. Este módulo baixa os zips para um
cache fora do git, confere tamanho e CRC, calcula o sha256 e grava numa pasta versionada:

- as tabelas de domínio (`completas`) inteiras;
- das demais (`filtradas`), os registros cuja raiz de CNPJ (8 primeiros caracteres) foi
  recebida, sem mexer num byte do registro (os arquivos são ISO-8859-1, sem cabeçalho, com
  aspas e, em Estabelecimentos, quebra de linha dentro de campo);
- `ORIGEM.md`, com a URL, o mês, os bytes e o sha256 de cada arquivo baixado, o que o extrato
  tem e a lista de raízes. A Receita não publica checksum, então o hash é calculado aqui.

A pipeline e o CI leem só a pasta versionada; este módulo roda quando chamado
(`python -m ingestion.main --baixar receita`). Nada no resultado depende do horário.
"""

import hashlib
import re
import zipfile
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

import duckdb

from ingestion import ErroDeIngestao
from ingestion.webdav import ArquivoRemoto

# =============================================================================
# Constantes
# =============================================================================

TAMANHO_DA_RAIZ = 8
TAMANHO_DO_CNPJ = 14
BLOCO_DE_LEITURA = 8 * 1024 * 1024
NOME_DA_ORIGEM = "ORIGEM.md"
PADRAO_DO_ZIP = re.compile(r"([A-Za-z]+)(\d*)\.zip")
PADRAO_DO_MES = re.compile(r"\d{4}-\d{2}")
PADRAO_DE_TABELA = re.compile(r"[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*")
PADRAO_DE_COLUNA = re.compile(r"[a-z_][a-z0-9_]*")

CAMPOS_OBRIGATORIOS = (
    "mes",
    "url_compartilhamento",
    "url_webdav",
    "token",
    "cache",
    "completas",
    "filtradas",
    "raizes_de",
)

LICENCA = (
    "Creative Commons Attribution (campo de licença do conjunto no dados.gov.br, sem a versão; "
    "consultado em 2026-11-10)"
)
LAYOUT = "https://www.gov.br/receitafederal/dados/cnpj-metadados.pdf (02/12/2021)"

# =============================================================================
# Configuração
# =============================================================================


@dataclass(frozen=True)
class OrigemDeRaizes:
    """Uma coluna de CNPJ completo (14 caracteres) de onde sai a lista de raízes."""

    tabela: str
    coluna: str


@dataclass(frozen=True)
class ParametrosReceita:
    """O que o bloco `_baixar` da Receita em `fontes.yml` configura."""

    mes: str
    url_compartilhamento: str
    url_webdav: str
    token: str
    cache: str
    completas: tuple[str, ...]
    filtradas: tuple[str, ...]
    raizes_de: tuple[OrigemDeRaizes, ...]


def ler_parametros(brutos: object) -> ParametrosReceita:
    """Valida o mapa de parâmetros e o devolve tipado; o erro diz qual campo está errado."""
    if not isinstance(brutos, dict):
        raise ErroDeIngestao("receita: 'parametros' é um mapa")
    if desconhecidos := sorted(set(brutos) - set(CAMPOS_OBRIGATORIOS)):
        raise ErroDeIngestao(f"receita: parâmetro(s) desconhecido(s): {', '.join(desconhecidos)}")
    if ausentes := [campo for campo in CAMPOS_OBRIGATORIOS if campo not in brutos]:
        raise ErroDeIngestao(f"receita: parâmetro(s) ausente(s): {', '.join(ausentes)}")
    parametros = ParametrosReceita(
        mes=str(brutos["mes"]),
        url_compartilhamento=str(brutos["url_compartilhamento"]),
        url_webdav=str(brutos["url_webdav"]),
        token=str(brutos["token"]),
        cache=str(brutos["cache"]),
        completas=_nomes(brutos["completas"], "completas"),
        filtradas=_nomes(brutos["filtradas"], "filtradas"),
        raizes_de=_origens_de_raizes(brutos["raizes_de"]),
    )
    _conferir(parametros)
    return parametros


def _nomes(bruto: object, campo: str) -> tuple[str, ...]:
    if not isinstance(bruto, list) or not all(isinstance(nome, str) for nome in bruto):
        raise ErroDeIngestao(f"receita: '{campo}' é uma lista de nomes de tabela")
    return tuple(bruto)


def _origens_de_raizes(bruto: object) -> tuple[OrigemDeRaizes, ...]:
    if not isinstance(bruto, list) or not bruto:
        raise ErroDeIngestao("receita: 'raizes_de' precisa de ao menos uma tabela e coluna")
    origens = []
    for item in bruto:
        if not isinstance(item, dict) or set(item) != {"tabela", "coluna"}:
            raise ErroDeIngestao("receita: cada item de 'raizes_de' tem 'tabela' e 'coluna'")
        origens.append(OrigemDeRaizes(tabela=str(item["tabela"]), coluna=str(item["coluna"])))
    return tuple(origens)


def _conferir(parametros: ParametrosReceita) -> None:
    if not PADRAO_DO_MES.fullmatch(parametros.mes):
        raise ErroDeIngestao(f"receita: mes '{parametros.mes}' não é AAAA-MM")
    if not parametros.filtradas:
        raise ErroDeIngestao("receita: 'filtradas' precisa de ao menos uma tabela")
    if repetidas := sorted(set(parametros.completas) & set(parametros.filtradas)):
        raise ErroDeIngestao(f"receita: {', '.join(repetidas)} está em 'completas' e 'filtradas'")
    for origem in parametros.raizes_de:
        if not PADRAO_DE_TABELA.fullmatch(origem.tabela):
            raise ErroDeIngestao(f"receita: tabela '{origem.tabela}' de 'raizes_de' inválida")
        if not PADRAO_DE_COLUNA.fullmatch(origem.coluna):
            raise ErroDeIngestao(f"receita: coluna '{origem.coluna}' de 'raizes_de' inválida")


# =============================================================================
# Raízes de CNPJ recebidas
# =============================================================================


def raizes_dos_cnpjs(banco: Path, origens: Sequence[OrigemDeRaizes]) -> list[str]:
    """Devolve, em ordem e sem repetir, os 8 primeiros caracteres dos CNPJs das colunas dadas.

    O CNPJ completo tem 14 caracteres (a raiz tem 8); um valor de outro tamanho é erro,
    porque a raiz dele seria um palpite. Valor nulo é ignorado: nem todo devedor tem
    empregador.
    """
    if not banco.exists():
        raise ErroDeIngestao(f"banco '{banco.name}' não existe; rode a pipeline antes")
    raizes: set[str] = set()
    conexao = duckdb.connect(str(banco), read_only=True)
    try:
        for origem in origens:
            raizes |= _raizes_da_coluna(conexao, origem.tabela, origem.coluna)
    finally:
        conexao.close()
    return sorted(raizes)


def _raizes_da_coluna(conexao: duckdb.DuckDBPyConnection, tabela: str, coluna: str) -> set[str]:
    try:
        valores = conexao.execute(
            f"SELECT DISTINCT {coluna} FROM {tabela} WHERE {coluna} IS NOT NULL"
        ).fetchall()
    except duckdb.Error as erro:
        raise ErroDeIngestao(f"{tabela}.{coluna}: não consegui ler os CNPJs ({erro})") from erro
    invalidos = sorted(str(valor) for (valor,) in valores if len(str(valor)) != TAMANHO_DO_CNPJ)
    if invalidos:
        raise ErroDeIngestao(
            f"{tabela}.{coluna}: CNPJ sem {TAMANHO_DO_CNPJ} caracteres: {', '.join(invalidos[:5])}"
        )
    return {str(valor)[:TAMANHO_DA_RAIZ] for (valor,) in valores}


# =============================================================================
# Leitura de um zip
# =============================================================================


@dataclass(frozen=True)
class ResultadoZip:
    """O que um zip tem: identidade do arquivo, registros lidos e os que ficaram no extrato."""

    bytes: int
    sha256: str
    registros: int
    mantidos: int
    sem_raiz: int
    por_raiz: dict[str, int]
    selecionado: bytes


def _linhas(fluxo) -> Iterator[bytes]:
    """Gera as linhas físicas, sem o `\\n`, lendo o fluxo em blocos."""
    resto = b""
    while bloco := fluxo.read(BLOCO_DE_LEITURA):
        *completas, resto = (resto + bloco).split(b"\n")
        yield from completas
    if resto:
        yield resto


def _registros(fluxo, nome: str) -> Iterator[bytes]:
    """Agrupa as linhas físicas em registros, respeitando a quebra de linha entre aspas.

    Todos os campos vêm entre aspas e uma aspa dentro do campo vem dobrada, então a paridade
    do número de aspas diz se o registro continua na linha seguinte.
    """
    pendente: list[bytes] = []
    entregues = 0
    for linha in _linhas(fluxo):
        aspas_impares = linha.count(b'"') % 2 == 1
        if not pendente and not aspas_impares:
            entregues += 1
            yield linha
            continue
        pendente.append(linha)
        if aspas_impares == (len(pendente) > 1):
            entregues += 1
            yield b"\n".join(pendente)
            pendente = []
    if pendente:
        raise ErroDeIngestao(
            f"{nome}: aspas abertas até o fim do arquivo, no registro {entregues + 1}"
        )


def _abrir_membro(zip_aberto: zipfile.ZipFile, nome: str) -> zipfile.ZipInfo:
    membros = zip_aberto.infolist()
    if len(membros) != 1:
        raise ErroDeIngestao(f"{nome}: esperava 1 arquivo no zip, tem {len(membros)} arquivos")
    return membros[0]


def filtrar_zip(caminho: Path, raizes: frozenset[str] | None) -> ResultadoZip:
    """Lê o zip inteiro e guarda os registros das `raizes` (todos, se `raizes` for `None`).

    A raiz é o primeiro campo do registro. Um registro sem raiz de 8 caracteres não entra
    no extrato mas é contado em `sem_raiz`, para a perda ficar visível. O registro sai
    byte a byte como veio, com `\\n` no fim. O CRC do zip é conferido ao fim da leitura.
    """
    alvo = None if raizes is None else {raiz.encode() for raiz in raizes}
    selecionados: list[bytes] = []
    por_raiz: dict[bytes, int] = {}
    registros = sem_raiz = 0
    try:
        with zipfile.ZipFile(caminho) as zip_aberto:
            membro = _abrir_membro(zip_aberto, caminho.name)
            with zip_aberto.open(membro) as fluxo:
                for registro in _registros(fluxo, caminho.name):
                    registros += 1
                    if alvo is None:
                        selecionados.append(registro)
                        continue
                    raiz = registro.partition(b";")[0].strip(b'"')
                    if len(raiz) != TAMANHO_DA_RAIZ:
                        sem_raiz += 1
                    elif raiz in alvo:
                        selecionados.append(registro)
                        por_raiz[raiz] = por_raiz.get(raiz, 0) + 1
    except (zipfile.BadZipFile, EOFError) as erro:
        raise ErroDeIngestao(f"{caminho.name}: zip corrompido ({erro})") from erro
    with caminho.open("rb") as arquivo:
        sha256 = hashlib.file_digest(arquivo, "sha256").hexdigest()
    return ResultadoZip(
        bytes=caminho.stat().st_size,
        sha256=sha256,
        registros=registros,
        mantidos=len(selecionados),
        sem_raiz=sem_raiz,
        por_raiz={raiz.decode(): total for raiz, total in sorted(por_raiz.items())},
        selecionado=b"".join(registro + b"\n" for registro in selecionados),
    )


# =============================================================================
# Extrato
# =============================================================================


class Cliente(Protocol):
    """O que o extrato pede do acesso remoto; `ClienteWebDav` cumpre, e o teste usa um falso."""

    def listar(self, pasta: str) -> list[ArquivoRemoto]: ...

    def baixar(self, pasta: str, arquivo: ArquivoRemoto, destino: Path) -> None: ...


@dataclass(frozen=True)
class ArquivoDoExtrato:
    """Um arquivo da pasta versionada: o que tem e a identidade dos bytes gravados."""

    nome: str
    registros: int
    bytes: int
    sha256: str


def _entidade_e_ordem(nome: str) -> tuple[str, int] | None:
    achado = PADRAO_DO_ZIP.fullmatch(nome)
    if achado is None:
        return None
    return achado.group(1).lower(), int(achado.group(2) or 0)


def _agrupar(
    remotos: Sequence[ArquivoRemoto], parametros: ParametrosReceita
) -> dict[str, list[ArquivoRemoto]]:
    """Separa os zips por entidade, na ordem numérica; o que sobra ou falta é erro."""
    esperadas = [*parametros.completas, *parametros.filtradas]
    por_entidade: dict[str, list[tuple[int, ArquivoRemoto]]] = {}
    fora = []
    for arquivo in remotos:
        chave = _entidade_e_ordem(arquivo.nome)
        if chave is None or chave[0] not in esperadas:
            fora.append(arquivo.nome)
        else:
            por_entidade.setdefault(chave[0], []).append((chave[1], arquivo))
    if fora:
        raise ErroDeIngestao(f"arquivo(s) da origem fora da configuração: {', '.join(fora)}")
    if faltam := [entidade for entidade in esperadas if entidade not in por_entidade]:
        raise ErroDeIngestao(f"entidade(s) configurada(s) sem arquivo na origem: {faltam}")
    return {
        entidade: [arquivo for _, arquivo in sorted(por_entidade[entidade], key=lambda x: x[0])]
        for entidade in esperadas
    }


def _baixar_para_o_cache(
    cliente: Cliente, mes: str, arquivos: Sequence[ArquivoRemoto], cache: Path
) -> dict[str, Path]:
    """Baixa o que o cache não tem com o tamanho anunciado; devolve o caminho de cada zip."""
    pasta = cache / mes
    pasta.mkdir(parents=True, exist_ok=True)
    caminhos = {}
    for arquivo in arquivos:
        caminho = pasta / arquivo.nome
        if not caminho.exists() or caminho.stat().st_size != arquivo.bytes:
            print(f"[BAIXANDO] {arquivo.nome} ({arquivo.bytes} bytes)", flush=True)
            cliente.baixar(mes, arquivo, caminho)
        caminhos[arquivo.nome] = caminho
    return caminhos


def montar_extrato(
    cliente: Cliente,
    parametros: ParametrosReceita,
    raizes: Sequence[str],
    destino: Path,
    cache: Path,
) -> list[Path]:
    """Baixa os zips do mês, filtra pelas `raizes` e grava o extrato e o `ORIGEM.md`.

    Tudo é conferido antes de gravar: se um zip falha, a pasta `destino` fica como estava.
    Devolve os arquivos gravados, com o `ORIGEM.md` por último.
    """
    if not raizes:
        raise ErroDeIngestao("nenhuma raiz de CNPJ recebida; rode a pipeline antes de baixar")
    por_entidade = _agrupar(cliente.listar(parametros.mes), parametros)
    todos = [arquivo for arquivos in por_entidade.values() for arquivo in arquivos]
    caminhos = _baixar_para_o_cache(cliente, parametros.mes, todos, cache)
    filtro = frozenset(raizes)
    resultados: dict[str, list[ResultadoZip]] = {}
    for entidade, arquivos in por_entidade.items():
        alvo = None if entidade in parametros.completas else filtro
        print(f"[LENDO] {entidade}: {len(arquivos)} zip(s)", flush=True)
        resultados[entidade] = [filtrar_zip(caminhos[arquivo.nome], alvo) for arquivo in arquivos]
    conteudos = {
        entidade: b"".join(resultado.selecionado for resultado in lidos)
        for entidade, lidos in resultados.items()
    }
    destino.mkdir(parents=True, exist_ok=True)
    escritos = []
    extrato = []
    for entidade, conteudo in conteudos.items():
        arquivo = destino / f"{entidade}.csv"
        arquivo.write_bytes(conteudo)
        escritos.append(arquivo)
        extrato.append(
            ArquivoDoExtrato(
                nome=arquivo.name,
                registros=sum(resultado.mantidos for resultado in resultados[entidade]),
                bytes=len(conteudo),
                sha256=hashlib.sha256(conteudo).hexdigest(),
            )
        )
    origem = destino / NOME_DA_ORIGEM
    origem.write_text(
        _texto_da_origem(parametros, por_entidade, resultados, list(raizes), extrato),
        encoding="utf-8",
        newline="\n",
    )
    return [*escritos, origem]


# =============================================================================
# ORIGEM.md
# =============================================================================


def _linha(*colunas: object) -> str:
    return "| " + " | ".join(str(coluna) for coluna in colunas) + " |"


def _tabela_de_zips(
    por_entidade: dict[str, list[ArquivoRemoto]], resultados: dict[str, list[ResultadoZip]]
) -> list[str]:
    return [
        _linha(arquivo.nome, arquivo.bytes, arquivo.modificado, lido.sha256, lido.registros)
        for entidade, arquivos in por_entidade.items()
        for arquivo, lido in zip(arquivos, resultados[entidade], strict=True)
    ]


def _registros_por_raiz(
    parametros: ParametrosReceita, resultados: dict[str, list[ResultadoZip]], raizes: list[str]
) -> dict[str, list[int]]:
    """Quantos registros cada raiz tem em cada tabela filtrada, na ordem da configuração."""
    return {
        raiz: [
            sum(lido.por_raiz.get(raiz, 0) for lido in resultados[entidade])
            for entidade in parametros.filtradas
        ]
        for raiz in raizes
    }


def _texto_da_origem(
    parametros: ParametrosReceita,
    por_entidade: dict[str, list[ArquivoRemoto]],
    resultados: dict[str, list[ResultadoZip]],
    raizes: list[str],
    extrato: list[ArquivoDoExtrato],
) -> str:
    """Monta o `ORIGEM.md`: sem horário e sem caminho da máquina, para ser reproduzível."""
    zips = _tabela_de_zips(por_entidade, resultados)
    por_raiz = _registros_por_raiz(parametros, resultados, raizes)
    encontradas = sum(1 for totais in por_raiz.values() if any(totais))
    sem_raiz = sum(lido.sem_raiz for lidos in resultados.values() for lido in lidos)
    total = sum(arquivo.bytes for arquivos in por_entidade.values() for arquivo in arquivos)
    hash_das_raizes = hashlib.sha256("\n".join(raizes).encode()).hexdigest()
    domino = "`, `".join(parametros.completas)
    linhas = [
        f"# Origem do extrato dos dados abertos do CNPJ, mês {parametros.mes}",
        "",
        "Gerado por `python -m ingestion.main --baixar receita`; não edite à mão. Mesma origem",
        "e mesmo mês dão os mesmos arquivos.",
        "",
        f"- Compartilhamento oficial da Receita Federal: {parametros.url_compartilhamento}",
        f"- Pasta baixada (WebDAV público): {parametros.url_webdav.rstrip('/')}/{parametros.mes}/",
        f"- Mês: {parametros.mes}",
        f"- Licença: {LICENCA}",
        f"- Layout das colunas: {LAYOUT}",
        "- Formato dos arquivos: sem cabeçalho, separador `;`, campos entre aspas, ISO-8859-1",
        "  (`latin-1`), quebra de linha dentro de campo em Estabelecimentos. Cada registro está",
        "  byte a byte como a Receita publicou.",
        "",
        f"## Arquivos baixados ({len(zips)} zips, {total} bytes)",
        "",
        "A Receita não publica checksum; o sha256 foi calculado aqui. `registros` é a contagem",
        "de registros do arquivo (uma quebra de linha dentro de campo não conta como registro).",
        "",
        _linha("arquivo", "bytes", "modificado no servidor", "sha256", "registros"),
        _linha("---", "---:", "---", "---", "---:"),
        *zips,
        "",
        "## Extrato gravado nesta pasta",
        "",
        f"Tabelas de domínio inteiras (`{domino}`); das demais, só os registros das raízes",
        "de CNPJ listadas abaixo.",
        "",
        _linha("arquivo", "registros", "bytes", "sha256"),
        _linha("---", "---:", "---:", "---"),
        *(_linha(a.nome, a.registros, a.bytes, a.sha256) for a in extrato),
        "",
        f"Registros sem raiz de 8 caracteres, fora do extrato: {sem_raiz}.",
        "",
        f"## Raízes de CNPJ recebidas ({len(raizes)})",
        "",
        f"sha256 da lista (raízes em ordem, uma por linha, sem linha final): {hash_das_raizes}",
        "",
        f"Encontradas na Receita: {encontradas} de {len(raizes)} raízes (as que têm ao menos um",
        "registro no extrato). Registros por raiz e tabela:",
        "",
        _linha("raiz", *parametros.filtradas),
        _linha("---", *("---:" for _ in parametros.filtradas)),
        *(_linha(raiz, *totais) for raiz, totais in por_raiz.items()),
        "",
    ]
    return "\n".join(linhas)
