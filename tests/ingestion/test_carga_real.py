"""Carga real: os arquivos de `contact_data/` entram inteiros, sem perder nenhuma linha."""

from pathlib import Path

import pytest
from apoio import consultar, faltam_linhas

from ingestion.main import main

RAIZ = Path(__file__).resolve().parents[2]
TABELAS = {
    "bronze_alfa.devedores": "alfa",
    "bronze_beta.devedores": "beta",
    "bronze_gama.devedores": "gama",
    "bronze_cobranca.contatos_realizados": "cobranca",
}


@pytest.fixture(scope="module")
def bancos(tmp_path_factory):
    """Roda a carga real duas vezes, cada uma num banco novo."""
    pasta = tmp_path_factory.mktemp("carga_real")
    caminhos = [pasta / "primeira.duckdb", pasta / "segunda.duckdb"]
    for caminho in caminhos:
        assert main(["--banco", str(caminho)]) == 0
    return caminhos


def _texto(caminho_relativo: str) -> str:
    return (RAIZ / caminho_relativo).read_bytes().decode("utf-8")


def test_todo_arquivo_recebido_esta_no_registro_da_sua_fonte(bancos):
    recebidos = {
        arquivo.relative_to(RAIZ).as_posix()
        for arquivo in (RAIZ / "contact_data").rglob("*")
        if arquivo.is_file()
    }

    registrados = set()
    for fonte in ("alfa", "beta", "gama", "cobranca"):
        linhas = consultar(bancos[0], f"SELECT arquivo FROM bronze_{fonte}.arquivos")
        registrados |= {x["arquivo"] for x in linhas}

    assert recebidos == registrados


@pytest.mark.parametrize(("tabela", "fonte"), TABELAS.items())
def test_linhas_do_registro_batem_com_as_da_tabela_por_arquivo(bancos, tabela, fonte):
    divergencias = consultar(
        bancos[0],
        f"""
        SELECT a.arquivo, a.linhas AS no_registro, COUNT(t._arquivo) AS na_tabela
        FROM bronze_{fonte}.arquivos AS a
        LEFT JOIN {tabela} AS t ON t._arquivo = a.arquivo
        GROUP BY a.arquivo, a.linhas
        HAVING a.linhas <> COUNT(t._arquivo)
        """,
    )
    total = consultar(bancos[0], f"SELECT COUNT(*) AS n FROM {tabela}")[0]["n"]
    registrado = consultar(bancos[0], f"SELECT SUM(linhas) AS n FROM bronze_{fonte}.arquivos")
    assert divergencias == []
    assert total == registrado[0]["n"] > 0


@pytest.mark.parametrize(("tabela", "fonte"), TABELAS.items())
def test_toda_linha_fisica_de_cada_arquivo_fica_coberta(bancos, tabela, fonte):
    arquivos = consultar(bancos[0], f"SELECT arquivo, cabecalho FROM bronze_{fonte}.arquivos")
    falhas = {}
    for arquivo in arquivos:
        registros = consultar(
            bancos[0],
            f"SELECT _linha, _linha_original FROM {tabela} "
            f"WHERE _arquivo = '{arquivo['arquivo']}'",
        )
        problema = faltam_linhas(registros, arquivo["cabecalho"], _texto(arquivo["arquivo"]))
        if problema:
            falhas[arquivo["arquivo"]] = problema
    assert falhas == {}


def test_o_alfa_junta_cpf_e_documento_na_mesma_tabela(bancos):
    colunas = {
        x["column_name"]
        for x in consultar(
            bancos[0],
            "SELECT column_name FROM duckdb_columns() "
            "WHERE schema_name = 'bronze_alfa' AND table_name = 'devedores'",
        )
    }
    assert {"cpf", "documento"} <= colunas


def test_duas_execucoes_geram_tabelas_identicas(bancos):
    tabelas = consultar(
        bancos[0],
        "SELECT schema_name || '.' || table_name AS nome FROM duckdb_tables() ORDER BY ALL",
    )
    nomes = [x["nome"] for x in tabelas]
    assert "bronze_alfa.arquivos" in nomes
    for nome in nomes:
        primeira = consultar(bancos[0], f"SELECT * FROM {nome} ORDER BY ALL")
        segunda = consultar(bancos[1], f"SELECT * FROM {nome} ORDER BY ALL")
        assert primeira == segunda, nome
