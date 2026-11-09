"""Testes do verificar_convencoes.py com SQL mínimo para cada regra."""

from pathlib import Path

import pytest

from verificar_convencoes import Parametros, carregar_parametros, main, verificar_arquivo

PROJETO = Parametros(
    funcoes_janela_permitidas=("ROW_NUMBER", "SUM"),
    exigir_frame_rows=True,
    proibir_janela_nomeada=True,
    camadas_sem_select_estrela=("silver", "gold"),
    alertar_zero_como_ausencia=True,
)


def gravar_modelo(pasta: Path, camada: str, sql: str) -> Path:
    arquivo = pasta / "models" / camada / "modelo.sql"
    arquivo.parent.mkdir(parents=True, exist_ok=True)
    arquivo.write_text(sql, encoding="utf-8")
    return arquivo


def regras_encontradas(arquivo: Path, parametros: Parametros = PROJETO) -> list[str]:
    return sorted(achado.regra for achado in verificar_arquivo(arquivo, parametros))


def test_janela_permitida_com_frame_passa(tmp_path):
    sql = """
    SELECT
      ROW_NUMBER() OVER (
        PARTITION BY a ORDER BY b ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS n,
      SUM(v) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS soma
    FROM t
    """
    assert regras_encontradas(gravar_modelo(tmp_path, "gold", sql)) == []


@pytest.mark.parametrize("funcao", ["LAG(x)", "AVG(x)", "count(*)", "RANK()"])
def test_funcao_de_janela_proibida(tmp_path, funcao):
    sql = f"SELECT {funcao} OVER (ORDER BY d ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS c FROM t"
    assert regras_encontradas(gravar_modelo(tmp_path, "gold", sql)) == ["janela-nao-permitida"]


def test_janela_sem_frame(tmp_path):
    sql = "SELECT ROW_NUMBER() OVER (PARTITION BY a ORDER BY b) AS n FROM t"
    assert regras_encontradas(gravar_modelo(tmp_path, "silver", sql)) == ["janela-sem-frame"]


def test_janela_com_subconsulta_no_argumento(tmp_path):
    sql = (
        "SELECT SUM(COALESCE(v, (1))) OVER (ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS s FROM t"
    )
    assert regras_encontradas(gravar_modelo(tmp_path, "gold", sql)) == []


def test_janela_nomeada(tmp_path):
    sql = "SELECT SUM(v) OVER w AS s FROM t WINDOW w AS (ORDER BY d)"
    assert regras_encontradas(gravar_modelo(tmp_path, "gold", sql)) == ["janela-nomeada"]


def test_select_estrela_so_vale_para_silver_e_gold(tmp_path):
    sql = "SELECT * FROM {{ ref('x') }}"
    assert regras_encontradas(gravar_modelo(tmp_path, "bronze", sql)) == []
    assert regras_encontradas(gravar_modelo(tmp_path, "silver", sql)) == ["select-estrela"]
    assert regras_encontradas(gravar_modelo(tmp_path, "gold", "SELECT t.* FROM t")) == [
        "select-estrela"
    ]


def test_count_estrela_nao_e_select_estrela(tmp_path):
    sql = "SELECT COUNT(*) AS qt_linhas FROM t"
    assert regras_encontradas(gravar_modelo(tmp_path, "gold", sql)) == []


def test_zero_como_ausencia_e_aviso(tmp_path):
    sql = "SELECT COALESCE(vl_renda, 0) AS vl_renda, COALESCE(nome, 'x') AS nome FROM t"
    achados = verificar_arquivo(gravar_modelo(tmp_path, "silver", sql), PROJETO)
    assert [(achado.regra, achado.gravidade) for achado in achados] == [
        ("zero-como-ausencia", "aviso")
    ]


def test_comentarios_sao_ignorados_e_linha_e_preservada(tmp_path):
    sql = "-- LAG(x) OVER ()\n{# SELECT * #}\nSELECT\n  LAG(x) OVER (ORDER BY d) AS y\nFROM t"
    achados = verificar_arquivo(gravar_modelo(tmp_path, "gold", sql), PROJETO)
    assert {(achado.regra, achado.linha) for achado in achados} == {
        ("janela-nao-permitida", 4),
        ("janela-sem-frame", 4),
    }


def test_sem_configuracao_o_comportamento_e_neutro(tmp_path):
    sql = "SELECT *, LAG(x) OVER w, COALESCE(v, 0) FROM t WINDOW w AS (ORDER BY d)"
    modelo = gravar_modelo(tmp_path, "gold", sql)
    assert verificar_arquivo(modelo, Parametros()) == []


def test_parametros_padrao_dos_caminhos():
    assert Parametros().caminhos == ("models", "macros", "tests")


def escrever_pyproject(pasta: Path) -> Path:
    arquivo = pasta / "pyproject.toml"
    arquivo.write_text(
        "[tool.verificar_convencoes_sql]\n"
        'caminhos = ["sql"]\n'
        'funcoes_janela_permitidas = ["SUM"]\n'
        "exigir_frame_rows = true\n"
        'camadas_sem_select_estrela = ["gold"]\n',
        encoding="utf-8",
    )
    return arquivo


def test_carrega_parametros_do_pyproject_subindo_pastas(tmp_path):
    escrever_pyproject(tmp_path)
    fundo = tmp_path / "a" / "b"
    fundo.mkdir(parents=True)
    parametros = carregar_parametros(None, fundo)
    assert parametros.caminhos == ("sql",)
    assert parametros.funcoes_janela_permitidas == ("SUM",)
    assert parametros.exigir_frame_rows is True
    assert parametros.proibir_janela_nomeada is False
    assert parametros.camadas_sem_select_estrela == ("gold",)


def test_flag_config_usa_o_arquivo_indicado(tmp_path, capsys):
    configuracao = escrever_pyproject(tmp_path)
    gravar_modelo(tmp_path, "gold", "SELECT * FROM t")
    codigo = main(["--config", str(configuracao), str(tmp_path / "models")])
    assert codigo == 1
    assert "select-estrela" in capsys.readouterr().out


def test_caminhos_configurados_valem_a_partir_da_pasta_do_pyproject(tmp_path, monkeypatch, capsys):
    configuracao = escrever_pyproject(tmp_path)
    modelo = tmp_path / "sql" / "models" / "gold" / "m.sql"
    modelo.parent.mkdir(parents=True)
    modelo.write_text("SELECT * FROM t", encoding="utf-8")
    outra_pasta = tmp_path / "outra"
    outra_pasta.mkdir()
    monkeypatch.chdir(outra_pasta)
    assert main(["--config", str(configuracao)]) == 1
    assert "select-estrela" in capsys.readouterr().out


def test_caminho_configurado_inexistente_vira_aviso(tmp_path, monkeypatch, capsys):
    configuracao = escrever_pyproject(tmp_path)
    monkeypatch.chdir(tmp_path)
    assert main(["--config", str(configuracao)]) == 0
    saida = capsys.readouterr().out
    assert "[aviso] caminho configurado não existe: sql" in saida
    assert "nenhum arquivo verificado" in saida


def test_estrito_falha_com_caminho_configurado_inexistente(tmp_path, monkeypatch):
    configuracao = escrever_pyproject(tmp_path)
    monkeypatch.chdir(tmp_path)
    assert main(["--config", str(configuracao), "--estrito"]) == 1
