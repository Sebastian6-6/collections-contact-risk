"""Prova de execuções idênticas: resumo por tabela e comparação entre duas rodadas."""

from pathlib import Path

import duckdb

from scripts import verificar_execucoes_identicas as verificacao


def criar_banco(caminho: Path, linhas_alfa: list[tuple], criar_gold: bool = True) -> Path:
    conexao = duckdb.connect(str(caminho))
    conexao.execute("CREATE SCHEMA bronze_alfa")
    conexao.execute("CREATE SCHEMA silver_alfa")
    conexao.execute("CREATE SCHEMA externo")
    conexao.execute("CREATE TABLE bronze_alfa.devedores (id VARCHAR, valor DOUBLE)")
    conexao.executemany("INSERT INTO bronze_alfa.devedores VALUES (?, ?)", linhas_alfa)
    conexao.execute("CREATE VIEW silver_alfa.devedores AS SELECT id FROM bronze_alfa.devedores")
    conexao.execute("CREATE TABLE externo.ignorada (x INTEGER)")
    if criar_gold:
        conexao.execute("CREATE SCHEMA gold")
        conexao.execute("CREATE TABLE gold.dim_devedor (sk INTEGER)")
    conexao.close()
    return caminho


def test_resume_so_os_schemas_de_bronze_silver_e_gold(tmp_path):
    banco = criar_banco(tmp_path / "a.duckdb", [("1", 1.5), ("2", None)])

    resumo = verificacao.resumir_banco(banco)

    assert set(resumo) == {"bronze_alfa.devedores", "silver_alfa.devedores", "gold.dim_devedor"}
    assert resumo["bronze_alfa.devedores"][0] == 2
    assert resumo["gold.dim_devedor"][0] == 0


def test_gold_ausente_nao_e_erro(tmp_path):
    banco = criar_banco(tmp_path / "a.duckdb", [("1", 1.0)], criar_gold=False)

    assert "gold.dim_devedor" not in verificacao.resumir_banco(banco)


def test_a_ordem_das_linhas_nao_muda_o_resumo(tmp_path):
    um = criar_banco(tmp_path / "primeiro.duckdb", [("1", 1.0), ("2", 2.0)])
    outro = criar_banco(tmp_path / "segundo.duckdb", [("2", 2.0), ("1", 1.0)])

    assert verificacao.resumir_banco(um) == verificacao.resumir_banco(outro)


def test_conteudo_diferente_muda_o_resumo(tmp_path):
    um = criar_banco(tmp_path / "primeiro.duckdb", [("1", 1.0)])
    outro = criar_banco(tmp_path / "segundo.duckdb", [("1", 1.1)])

    divergentes = verificacao.achar_divergencias(
        verificacao.resumir_banco(um), verificacao.resumir_banco(outro)
    )

    assert divergentes == ["bronze_alfa.devedores"]


def test_tabela_presente_em_uma_so_rodada_diverge():
    primeira = {"gold.a": (1, 10), "gold.b": (2, 20)}
    segunda = {"gold.a": (1, 10)}

    assert verificacao.achar_divergencias(primeira, segunda) == ["gold.b"]


def test_rodadas_iguais_nao_divergem():
    resumo = {"gold.a": (1, 10)}

    assert verificacao.achar_divergencias(resumo, dict(resumo)) == []


def test_main_passa_quando_as_duas_rodadas_sao_iguais(tmp_path, capsys):
    resumos = iter([{"gold.a": (1, 10)}, {"gold.a": (1, 10)}])

    codigo = verificacao.main(tmp_path, lambda raiz: True, lambda raiz: next(resumos))

    assert codigo == 0
    assert "[OK]" in capsys.readouterr().out


def test_main_falha_e_diz_qual_tabela_divergiu(tmp_path, capsys):
    resumos = iter([{"gold.a": (1, 10)}, {"gold.a": (1, 11)}])

    codigo = verificacao.main(tmp_path, lambda raiz: True, lambda raiz: next(resumos))

    assert codigo == 1
    assert "gold.a" in capsys.readouterr().out


def test_main_falha_se_a_pipeline_falhar(tmp_path):
    chamadas = []

    codigo = verificacao.main(tmp_path, lambda raiz: False, lambda raiz: chamadas.append(raiz))

    assert codigo == 1
    assert chamadas == []
