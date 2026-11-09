"""Testes do verificar_convencoes.py com SQL mínimo para cada regra."""

from pathlib import Path

import pytest

from verificar_convencoes import verificar_arquivo


def gravar_modelo(pasta: Path, camada: str, sql: str) -> Path:
    arquivo = pasta / "models" / camada / "modelo.sql"
    arquivo.parent.mkdir(parents=True, exist_ok=True)
    arquivo.write_text(sql, encoding="utf-8")
    return arquivo


def regras_encontradas(arquivo: Path) -> list[str]:
    return sorted(achado.regra for achado in verificar_arquivo(arquivo))


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
    achados = verificar_arquivo(gravar_modelo(tmp_path, "silver", sql))
    assert [(achado.regra, achado.gravidade) for achado in achados] == [
        ("zero-como-ausencia", "aviso")
    ]


def test_comentarios_sao_ignorados_e_linha_e_preservada(tmp_path):
    sql = "-- LAG(x) OVER ()\n{# SELECT * #}\nSELECT\n  LAG(x) OVER (ORDER BY d) AS y\nFROM t"
    achados = verificar_arquivo(gravar_modelo(tmp_path, "gold", sql))
    assert {(achado.regra, achado.linha) for achado in achados} == {
        ("janela-nao-permitida", 4),
        ("janela-sem-frame", 4),
    }
