"""Pipeline: apaga o banco, roda a ingestão e só então o dbt."""

import duckdb
import pytest
import yaml
from apoio import entidade

import pipeline

PERFIL = """
collections_contact_risk:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: database/teste.duckdb
"""


@pytest.fixture
def raiz(tmp_path):
    (tmp_path / "profiles.yml").write_text(PERFIL, encoding="utf-8")
    (tmp_path / "dados").mkdir()
    (tmp_path / "dados" / "a.csv").write_text("id\n1\n", encoding="utf-8")
    return tmp_path


@pytest.fixture
def config(raiz):
    caminho = raiz / "fontes.yml"
    configuracao = {"fonte": {"pessoas": entidade("csv", ("dados", "*.csv"))}}
    caminho.write_text(yaml.safe_dump(configuracao), encoding="utf-8")
    return caminho


def test_o_caminho_do_banco_vem_do_profiles_yml(raiz):
    assert pipeline.caminho_do_banco(raiz) == raiz / "database" / "teste.duckdb"


def test_apaga_o_banco_e_o_arquivo_de_log_de_escrita(raiz):
    banco = pipeline.caminho_do_banco(raiz)
    banco.parent.mkdir()
    banco.write_bytes(b"velho")
    banco.with_name(banco.name + ".wal").write_bytes(b"velho")

    pipeline.apagar_banco(raiz)

    assert not banco.exists()
    assert not banco.with_name(banco.name + ".wal").exists()


def test_recria_o_banco_do_zero_e_roda_o_dbt_depois_da_ingestao(raiz, config):
    banco = pipeline.caminho_do_banco(raiz)
    banco.parent.mkdir()
    duckdb.connect(str(banco)).execute("CREATE TABLE sobra (x INTEGER)").close()
    chamadas = []

    def dbt_falso(raiz_do_projeto):
        conexao = duckdb.connect(str(banco), read_only=True)
        chamadas.append(conexao.execute("SELECT COUNT(*) FROM bronze_fonte.pessoas").fetchone())
        conexao.close()
        return True

    assert pipeline.main(raiz, config, dbt_falso) == 0

    assert chamadas == [(1,)]
    conexao = duckdb.connect(str(banco), read_only=True)
    consulta = conexao.execute("SELECT table_name FROM duckdb_tables()")
    tabelas = {linha[0] for linha in consulta.fetchall()}
    conexao.close()
    assert "sobra" not in tabelas


def test_ingestao_que_falha_impede_o_dbt(raiz, config):
    (raiz / "dados" / "a.csv").write_bytes(b"id\n\xe9\n")
    chamadas = []

    assert pipeline.main(raiz, config, lambda r: chamadas.append(r) or True) == 1
    assert chamadas == []


def test_dbt_que_falha_faz_a_pipeline_falhar(raiz, config):
    assert pipeline.main(raiz, config, lambda r: False) == 1
