"""Ingestão: lê todos os arquivos recebidos e grava a bronze no DuckDB, sem transformar.

Uso, a partir da raiz do repositório:
    python -m ingestion.main                # todas as fontes
    python -m ingestion.main --fonte alfa   # só uma
    python -m ingestion.main --baixar receita   # grava o extrato de uma fonte externa

Cada entrada de `ingestion/fontes.yml` (fonte + entidade) vira uma tabela
`bronze_<fonte>.<entidade>` com uma linha por linha recebida, e cada fonte ganha o registro
`bronze_<fonte>.arquivos`. O banco é recriado do zero a cada execução da pipeline, então
reler tudo é o que garante execuções idênticas: a rastreabilidade vem do arquivo, da linha e
do hash, nunca de um horário. O que muda de uma fonte para outra fica no YAML; só um formato
novo exige uma função em `leitores.py` e só uma origem nova exige uma em `conectores.py`.
"""

import argparse
import codecs
import hashlib
import inspect
import re
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

import duckdb
import yaml

from ingestion import ErroDeIngestao
from ingestion.conectores import Baixa, Conector, Local, obter_baixador, obter_conector
from ingestion.leitores import Leitura, obter_leitor, validar_colunas

# =============================================================================
# Constantes
# =============================================================================

PASTA_DO_COMPONENTE = Path(__file__).resolve().parent
RAIZ_PADRAO = PASTA_DO_COMPONENTE.parent
CONFIGURACAO_PADRAO = PASTA_DO_COMPONENTE / "fontes.yml"
PERFIL_DO_DBT = "collections_contact_risk"

ENCODING_PADRAO = "utf-8"
SEPARADOR_PADRAO = ","
NOME_DO_REGISTRO = "arquivos"
PADRAO_DE_NOME = re.compile(r"[a-z][a-z0-9_]*")

CAMPOS_OBRIGATORIOS = ("origem", "formato", "arquivos")
CAMPOS_OPCIONAIS = ("encoding", "separador", "colunas")
CHAVE_DE_BAIXA = "_baixar"
CAMPOS_DA_BAIXA = ("origem", "destino", "parametros")

# Colunas que a ingestão acrescenta às do próprio arquivo; nenhuma delas interpreta o dado.
COLUNAS_DE_RASTREABILIDADE = (
    ("_arquivo", "VARCHAR"),
    ("_linha", "BIGINT"),
    ("_hash_arquivo", "VARCHAR"),
    ("_linha_original", "VARCHAR"),
    ("_motivo_ilegivel", "VARCHAR"),
)

ESQUEMA_DO_REGISTRO = (
    ("arquivo", "VARCHAR"),
    ("entidade", "VARCHAR"),
    ("hash_arquivo", "VARCHAR"),
    ("bytes", "BIGINT"),
    ("linhas", "BIGINT"),
    ("cabecalho", "VARCHAR"),
)

# =============================================================================
# Tipos
# =============================================================================


@dataclass(frozen=True)
class Entidade:
    """Uma tabela da bronze: de onde vêm os arquivos e como lê-los."""

    fonte: str
    nome: str
    origem: str
    formato: str
    locais: tuple[Local, ...]
    encoding: str = ENCODING_PADRAO
    separador: str = SEPARADOR_PADRAO
    colunas: tuple[str, ...] | None = None

    @property
    def rotulo(self) -> str:
        """Nome curto `fonte.entidade`, usado nas mensagens de erro."""
        return f"{self.fonte}.{self.nome}"


@dataclass(frozen=True)
class ArquivoLido:
    """Um arquivo recebido: caminho relativo à raiz, hash e tamanho dos bytes e o conteúdo."""

    caminho: str
    hash_arquivo: str
    tamanho: int
    leitura: Leitura


@dataclass(frozen=True)
class TabelaLida:
    """Tudo o que uma entidade recebeu: a união das colunas e os arquivos lidos."""

    entidade: Entidade
    colunas: list[str]
    arquivos: list[ArquivoLido]


# =============================================================================
# Configuração
# =============================================================================


def _ler_fontes(caminho: Path) -> dict:
    try:
        bruto = yaml.safe_load(caminho.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as erro:
        raise ErroDeIngestao(f"configuração ilegível ({caminho.name}): {erro}") from erro
    if not isinstance(bruto, dict) or not bruto:
        raise ErroDeIngestao(f"{caminho.name}: esperava um mapa de fontes")
    for fonte, tabelas in bruto.items():
        _validar_nome(fonte, "fonte")
        if not isinstance(tabelas, dict) or not tabelas:
            raise ErroDeIngestao(f"fonte '{fonte}': esperava um mapa de entidades")
    return bruto


def carregar_entidades(caminho: Path) -> list[Entidade]:
    """Lê o YAML e valida todas as entidades antes de qualquer leitura de dados.

    O bloco `_baixar` de uma fonte não é entidade: descreve como trazer os arquivos de fora
    e só é lido por `carregar_baixas`.
    """
    return [
        validar_entidade(fonte, nome, campos)
        for fonte, tabelas in _ler_fontes(caminho).items()
        for nome, campos in tabelas.items()
        if nome != CHAVE_DE_BAIXA
    ]


def carregar_baixas(caminho: Path) -> dict[str, Baixa]:
    """Lê o bloco `_baixar` de cada fonte que o tem: origem, pasta de destino e parâmetros."""
    baixas = {}
    for fonte, tabelas in _ler_fontes(caminho).items():
        if CHAVE_DE_BAIXA not in tabelas:
            continue
        campos = tabelas[CHAVE_DE_BAIXA]
        rotulo = f"{fonte}.{CHAVE_DE_BAIXA}"
        if not isinstance(campos, dict) or not {"origem", "destino"} <= set(campos) <= {
            *CAMPOS_DA_BAIXA
        }:
            raise ErroDeIngestao(f"{rotulo}: esperava 'origem' e 'destino' (e 'parametros')")
        obter_baixador(campos["origem"])
        baixas[fonte] = Baixa(
            fonte=fonte,
            origem=campos["origem"],
            destino=str(campos["destino"]),
            parametros=campos.get("parametros", {}),
        )
    return baixas


def _validar_nome(nome: object, tipo: str) -> None:
    if not isinstance(nome, str) or not PADRAO_DE_NOME.fullmatch(nome):
        raise ErroDeIngestao(
            f"{tipo} '{nome}': use minúsculas, dígitos e '_', começando por letra"
        )


def validar_entidade(fonte: str, nome: str, campos: object) -> Entidade:
    """Confere os campos da entidade e devolve a `Entidade`; o erro diz qual campo."""
    _validar_nome(nome, "entidade")
    rotulo = f"{fonte}.{nome}"
    if nome == NOME_DO_REGISTRO:
        raise ErroDeIngestao(f"{rotulo}: '{NOME_DO_REGISTRO}' é o nome do registro de cargas")
    if not isinstance(campos, dict):
        raise ErroDeIngestao(f"{rotulo}: esperava um mapa de campos")
    if desconhecidos := sorted(set(campos) - {*CAMPOS_OBRIGATORIOS, *CAMPOS_OPCIONAIS}):
        raise ErroDeIngestao(f"{rotulo}: campo(s) desconhecido(s): {', '.join(desconhecidos)}")
    if ausentes := [campo for campo in CAMPOS_OBRIGATORIOS if campo not in campos]:
        raise ErroDeIngestao(f"{rotulo}: campo(s) ausente(s): {', '.join(ausentes)}")
    entidade = Entidade(
        fonte=fonte,
        nome=nome,
        origem=campos["origem"],
        formato=campos["formato"],
        locais=_validar_locais(rotulo, campos["arquivos"]),
        encoding=campos.get("encoding", ENCODING_PADRAO),
        separador=campos.get("separador", SEPARADOR_PADRAO),
        colunas=_validar_colunas(rotulo, campos.get("colunas")),
    )
    _validar_leitura(entidade)
    return entidade


def _validar_locais(rotulo: str, brutos: object) -> tuple[Local, ...]:
    if not isinstance(brutos, list) or not brutos:
        raise ErroDeIngestao(f"{rotulo}: 'arquivos' precisa de ao menos um local")
    locais = []
    for bruto in brutos:
        if not isinstance(bruto, dict) or set(bruto) != {"caminho", "padrao"}:
            raise ErroDeIngestao(f"{rotulo}: cada local de 'arquivos' tem 'caminho' e 'padrao'")
        locais.append(Local(caminho=str(bruto["caminho"]), padrao=str(bruto["padrao"])))
    return tuple(locais)


def _validar_colunas(rotulo: str, brutas: object) -> tuple[str, ...] | None:
    """Confere a lista de colunas de um arquivo sem cabeçalho; `None` se não foi declarada."""
    if brutas is None:
        return None
    if not isinstance(brutas, list):
        raise ErroDeIngestao(f"{rotulo}: 'colunas' é uma lista de nomes")
    if not all(isinstance(coluna, str) for coluna in brutas):
        raise ErroDeIngestao(f"{rotulo}: cada nome de 'colunas' é um texto")
    validar_colunas(rotulo, brutas, "em 'colunas'")
    return tuple(brutas)


def _validar_leitura(entidade: Entidade) -> None:
    obter_conector(entidade.origem)
    leitor = obter_leitor(entidade.formato)
    if entidade.colunas and "colunas" not in inspect.signature(leitor).parameters:
        raise ErroDeIngestao(
            f"{entidade.rotulo}: o formato '{entidade.formato}' não aceita 'colunas'"
        )
    try:
        codecs.lookup(entidade.encoding)
    except LookupError as erro:
        raise ErroDeIngestao(
            f"{entidade.rotulo}: encoding '{entidade.encoding}' desconhecido"
        ) from erro
    if not isinstance(entidade.separador, str) or len(entidade.separador) != 1:
        raise ErroDeIngestao(f"{entidade.rotulo}: 'separador' é um único caractere")


def caminho_do_banco(raiz: Path) -> Path:
    """Lê do `profiles.yml` o arquivo DuckDB, para o caminho ficar num lugar só."""
    perfis = yaml.safe_load((raiz / "profiles.yml").read_text(encoding="utf-8"))
    perfil = perfis[PERFIL_DO_DBT]
    return raiz / perfil["outputs"][perfil["target"]]["path"]


# =============================================================================
# Localização dos arquivos
# =============================================================================


def caminho_relativo(arquivo: Path, raiz: Path) -> str:
    """Caminho do arquivo a partir da raiz, com `/`; só o relativo é gravado na bronze."""
    try:
        return arquivo.resolve().relative_to(raiz.resolve()).as_posix()
    except ValueError as erro:
        raise ErroDeIngestao(f"'{arquivo.name}' está fora da raiz do repositório") from erro


def localizar_arquivos(entidades: Sequence[Entidade], raiz: Path) -> dict[Entidade, list[Path]]:
    """Lista os arquivos de cada entidade e recusa o que casaria com duas entradas.

    Um arquivo carregado duas vezes duplicaria linhas sem aviso; por isso o erro vem antes
    de qualquer leitura.
    """
    entradas_do_arquivo: dict[str, list[str]] = {}
    localizados: dict[Entidade, list[Path]] = {}
    for entidade in entidades:
        conector = obter_conector(entidade.origem)
        arquivos: list[Path] = []
        for local in entidade.locais:
            encontrados = _listar_local(entidade, local, raiz, conector)
            for arquivo in encontrados:
                entrada = f"{entidade.rotulo} ({local.caminho}/{local.padrao})"
                entradas_do_arquivo.setdefault(caminho_relativo(arquivo, raiz), []).append(entrada)
            arquivos += encontrados
        if not arquivos:
            raise ErroDeIngestao(f"{entidade.rotulo}: nenhum arquivo casa com a configuração")
        localizados[entidade] = arquivos
    repetidos = [
        f"{caminho} casa com mais de uma entrada: {'; '.join(entradas)}"
        for caminho, entradas in sorted(entradas_do_arquivo.items())
        if len(entradas) > 1
    ]
    if repetidos:
        raise ErroDeIngestao("; ".join(repetidos))
    return localizados


def _listar_local(
    entidade: Entidade, local: Local, raiz: Path, conector: Conector
) -> list[Path]:
    try:
        return conector(local, raiz)
    except ErroDeIngestao as erro:
        raise ErroDeIngestao(f"{entidade.rotulo}: {erro}") from erro


# =============================================================================
# Leitura
# =============================================================================


def unir_colunas(rotulo: str, leituras: Sequence[Leitura]) -> list[str]:
    """Une as colunas dos arquivos na ordem em que aparecem; confere nomes reservados e caixa.

    O DuckDB não distingue maiúsculas de minúsculas nos nomes de coluna, então `CPF` e `cpf`
    seriam a mesma coluna; unir os dois seria uma decisão de limpeza, que é da silver.
    """
    reservadas = {nome for nome, _ in COLUNAS_DE_RASTREABILIDADE}
    unidas: list[str] = []
    for leitura in leituras:
        for coluna in leitura.colunas:
            if coluna in reservadas:
                raise ErroDeIngestao(f"{rotulo}: coluna '{coluna}' tem nome reservado da ingestão")
            if coluna not in unidas:
                unidas.append(coluna)
    por_caixa: dict[str, str] = {}
    for coluna in unidas:
        if por_caixa.setdefault(coluna.casefold(), coluna) != coluna:
            raise ErroDeIngestao(
                f"{rotulo}: colunas '{por_caixa[coluna.casefold()]}' e '{coluna}' só diferem "
                "na caixa"
            )
    return unidas


def ler_entidade(entidade: Entidade, arquivos: Sequence[Path], raiz: Path) -> TabelaLida:
    """Lê os arquivos da entidade, na ordem recebida, e une as colunas dos cabeçalhos."""
    leitor = obter_leitor(entidade.formato)
    lidos = []
    for arquivo in arquivos:
        conteudo = arquivo.read_bytes()
        opcoes = {"colunas": entidade.colunas} if entidade.colunas else {}
        leitura = leitor(arquivo, entidade.encoding, entidade.separador, **opcoes)
        lidos.append(
            ArquivoLido(
                caminho=caminho_relativo(arquivo, raiz),
                hash_arquivo=hashlib.sha256(conteudo).hexdigest(),
                tamanho=len(conteudo),
                leitura=leitura,
            )
        )
    colunas = unir_colunas(entidade.rotulo, [lido.leitura for lido in lidos])
    return TabelaLida(entidade=entidade, colunas=colunas, arquivos=lidos)


# =============================================================================
# Gravação
# =============================================================================


def identificador_sql(nome: str) -> str:
    """Põe o nome entre aspas, para aceitar qualquer cabeçalho recebido."""
    return '"' + nome.replace('"', '""') + '"'


def valores_da_tabela(tabela: TabelaLida) -> tuple[list[tuple[str, str]], list[list]]:
    """Monta o esquema e uma lista de valores por coluna, na ordem em que as linhas chegaram.

    As colunas do arquivo vêm em texto, como recebidas (`NULL` onde o arquivo não tem a
    coluna ou a linha é ilegível), seguidas da rastreabilidade.
    """
    registros = [(a, linha) for a in tabela.arquivos for linha in a.leitura.linhas]
    esquema = [(nome, "VARCHAR") for nome in tabela.colunas] + list(COLUNAS_DE_RASTREABILIDADE)
    valores = [
        [(linha.campos or {}).get(nome) for _, linha in registros] for nome in tabela.colunas
    ]
    valores += [
        [arquivo.caminho for arquivo, _ in registros],
        [linha.numero for _, linha in registros],
        [arquivo.hash_arquivo for arquivo, _ in registros],
        [linha.texto for _, linha in registros],
        [linha.motivo_ilegivel for _, linha in registros],
    ]
    return esquema, valores


def gravar_lote(
    conexao: duckdb.DuckDBPyConnection,
    destino: str,
    esquema: Sequence[tuple[str, str]],
    colunas: list[list],
) -> None:
    """Recria a tabela `destino` e grava as linhas de uma vez, com uma lista por coluna.

    A gravação em lote (`UNNEST` de uma lista por coluna) é bem mais rápida que inserir linha
    a linha; o ganho medido está no corpo do commit que a introduziu.
    """
    definicao = ", ".join(f"{identificador_sql(nome)} {tipo}" for nome, tipo in esquema)
    conexao.execute(f"CREATE OR REPLACE TABLE {destino} ({definicao})")
    if colunas and colunas[0]:
        expansao = ", ".join(f"UNNEST(CAST(? AS {tipo}[]))" for _, tipo in esquema)
        conexao.execute(f"INSERT INTO {destino} SELECT {expansao}", colunas)


def gravar_tabela(conexao: duckdb.DuckDBPyConnection, tabela: TabelaLida) -> int:
    """Grava a tabela da entidade e confere, arquivo a arquivo, que nenhuma linha se perdeu."""
    entidade = tabela.entidade
    destino = f"bronze_{entidade.fonte}.{entidade.nome}"
    esquema, valores = valores_da_tabela(tabela)
    gravar_lote(conexao, destino, esquema, valores)
    gravadas = dict(
        conexao.execute(f"SELECT _arquivo, COUNT(*) FROM {destino} GROUP BY _arquivo").fetchall()
    )
    esperadas = {a.caminho: len(a.leitura.linhas) for a in tabela.arquivos if a.leitura.linhas}
    if gravadas != esperadas:
        raise ErroDeIngestao(f"{destino}: gravadas {gravadas}, lidas {esperadas}")
    total = sum(esperadas.values())
    ilegiveis = sum(
        1 for a in tabela.arquivos for linha in a.leitura.linhas if linha.motivo_ilegivel
    )
    print(
        f"[OK] {destino}: {total} linha(s) de {len(tabela.arquivos)} arquivo(s), "
        f"{ilegiveis} ilegível(is)"
    )
    return total


def gravar_registro(
    conexao: duckdb.DuckDBPyConnection, fonte: str, tabelas: list[TabelaLida]
) -> None:
    """Grava `bronze_<fonte>.arquivos`: um registro por arquivo lido, com o hash e as linhas."""
    arquivos = [(t.entidade.nome, a) for t in tabelas for a in t.arquivos]
    valores = [
        [a.caminho for _, a in arquivos],
        [entidade for entidade, _ in arquivos],
        [a.hash_arquivo for _, a in arquivos],
        [a.tamanho for _, a in arquivos],
        [len(a.leitura.linhas) for _, a in arquivos],
        [a.leitura.cabecalho for _, a in arquivos],
    ]
    gravar_lote(conexao, f"bronze_{fonte}.{NOME_DO_REGISTRO}", ESQUEMA_DO_REGISTRO, valores)


def gravar_fonte(banco: Path, fonte: str, tabelas: list[TabelaLida]) -> None:
    """Grava todas as tabelas da fonte numa transação: ou entra tudo, ou nada."""
    banco.parent.mkdir(parents=True, exist_ok=True)
    conexao = duckdb.connect(str(banco))
    try:
        conexao.execute("BEGIN")
        conexao.execute(f"CREATE SCHEMA IF NOT EXISTS bronze_{fonte}")
        for tabela in tabelas:
            gravar_tabela(conexao, tabela)
        gravar_registro(conexao, fonte, tabelas)
        conexao.execute("COMMIT")
    finally:
        conexao.close()


# =============================================================================
# Execução
# =============================================================================


def executar(entidades: Sequence[Entidade], raiz: Path, banco: Path) -> int:
    """Lê e grava as fontes em ordem; o erro de uma fonte não impede as demais.

    Devolve 0 se tudo entrou e 1 se alguma fonte (ou a configuração dos arquivos) falhou.
    """
    try:
        localizados = localizar_arquivos(entidades, raiz)
    except ErroDeIngestao as erro:
        print(f"[ERRO] {erro}")
        return 1
    codigo = 0
    for fonte in dict.fromkeys(entidade.fonte for entidade in entidades):
        try:
            tabelas = [
                ler_entidade(entidade, arquivos, raiz)
                for entidade, arquivos in localizados.items()
                if entidade.fonte == fonte
            ]
            gravar_fonte(banco, fonte, tabelas)
        except ErroDeIngestao as erro:
            print(f"[ERRO] {fonte}: {erro}")
            codigo = 1
    return codigo


def baixar(opcoes: argparse.Namespace) -> int:
    """Roda o baixador da fonte pedida e lista o que gravou; devolve 0 se deu certo."""
    try:
        baixas = carregar_baixas(opcoes.config)
        if opcoes.baixar not in baixas:
            existentes = ", ".join(sorted(baixas)) or "nenhuma"
            raise ErroDeIngestao(
                f"fonte '{opcoes.baixar}' sem bloco '{CHAVE_DE_BAIXA}' em "
                f"{opcoes.config.name}; com bloco: {existentes}"
            )
        baixa = baixas[opcoes.baixar]
        banco = opcoes.banco or caminho_do_banco(opcoes.raiz)
        arquivos = obter_baixador(baixa.origem)(baixa, opcoes.raiz, banco)
    except ErroDeIngestao as erro:
        print(f"[ERRO] {erro}")
        return 1
    for arquivo in arquivos:
        print(f"[OK] {caminho_relativo(arquivo, opcoes.raiz)}")
    return 0


def main(argumentos: Sequence[str] | None = None) -> int:
    """Ponto de entrada da linha de comando; devolve 0 se tudo entrou e 1 se algo falhou."""
    analisador = argparse.ArgumentParser(description="Grava os arquivos recebidos na bronze.")
    analisador.add_argument("--fonte", help="só esta fonte de ingestion/fontes.yml")
    analisador.add_argument(
        "--baixar", help="traz os arquivos de uma fonte externa (bloco _baixar) e não ingere"
    )
    analisador.add_argument("--config", type=Path, default=CONFIGURACAO_PADRAO)
    analisador.add_argument("--raiz", type=Path, default=RAIZ_PADRAO)
    analisador.add_argument("--banco", type=Path, help="padrão: o caminho do profiles.yml")
    opcoes = analisador.parse_args(argumentos)
    if opcoes.baixar:
        return baixar(opcoes)
    try:
        entidades = carregar_entidades(opcoes.config)
        if opcoes.fonte:
            entidades = [e for e in entidades if e.fonte == opcoes.fonte]
            if not entidades:
                raise ErroDeIngestao(f"fonte '{opcoes.fonte}' não existe em {opcoes.config.name}")
        banco = opcoes.banco or caminho_do_banco(opcoes.raiz)
    except ErroDeIngestao as erro:
        print(f"[ERRO] {erro}")
        return 1
    return executar(entidades, opcoes.raiz, banco)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
