"""Medição da régua: leitura da linha de métricas, formatação e o laço dos cortes."""

import subprocess
from pathlib import Path

import duckdb

from scripts import medir_regua

METRICAS = {
    "dt_corte": "2026-09-15",
    "qt_risco": 540,
    "qt_risco_pego": 228,
    "qt_terceiro": 327,
    "qt_terceiro_pego": 201,
    "qt_confirmado": 944,
    "qt_confirmado_liberado": 674,
    "fracao_risco_pego": 0.4222,
    "fracao_terceiro_pego": 0.6147,
    "fracao_confirmado_liberado": 0.714,
    "acuracia_balanceada": 0.5681,
}


def test_executar_devolve_a_linha_como_dicionario(tmp_path):
    banco = tmp_path / "a.duckdb"
    duckdb.connect(str(banco)).close()

    linha = medir_regua.executar_metricas(banco, "SELECT 1 AS um, 'b' AS letra")

    assert linha == {"um": 1, "letra": "b"}


def test_formata_quantidades_e_frações_com_vírgula():
    texto = medir_regua.formatar_metricas(METRICAS)

    assert "Corte 2026-09-15" in texto
    assert "acurácia balanceada: 0,5681" in texto
    assert "terceiros pegos: 201 de 327 (61,47%)" in texto
    assert "confirmados liberados: 674 de 944 (71,40%)" in texto


def test_sem_base_não_vira_zero():
    vazias = {**METRICAS, "qt_terceiro": 0, "qt_terceiro_pego": 0, "fracao_terceiro_pego": None}

    assert "terceiros pegos: 0 de 0 (sem base)" in medir_regua.formatar_metricas(vazias)


def test_main_mede_os_dois_cortes_em_ordem(tmp_path, capsys):
    (tmp_path / "profiles.yml").write_text(
        "collections_contact_risk:\n  target: dev\n  outputs:\n    dev:\n      path: b.duckdb\n",
        encoding="utf-8",
    )
    cortes_compilados: list[str] = []

    def compilar(raiz: Path, data_corte: str) -> str:
        cortes_compilados.append(data_corte)
        return data_corte

    def executar(banco: Path, sql: str) -> dict:
        return {**METRICAS, "dt_corte": sql}

    codigo = medir_regua.main(tmp_path, compilar, executar)

    saida = capsys.readouterr().out
    assert codigo == 0
    assert cortes_compilados == ["2026-09-15", "2026-09-22"]
    assert saida.index("Corte 2026-09-15") < saida.index("Corte 2026-09-22")


def test_main_para_com_erro_quando_o_dbt_nao_compila(tmp_path, capsys):
    (tmp_path / "profiles.yml").write_text(
        "collections_contact_risk:\n  target: dev\n  outputs:\n    dev:\n      path: b.duckdb\n",
        encoding="utf-8",
    )

    def compilar(raiz: Path, data_corte: str) -> str:
        raise RuntimeError("falhou")

    assert medir_regua.main(tmp_path, compilar, lambda banco, sql: METRICAS) == 1
    assert "[ERRO] falhou" in capsys.readouterr().out


def test_compilar_le_a_saida_do_dbt_em_utf8_sem_quebrar_em_byte_solto(tmp_path, monkeypatch):
    chamadas: dict = {}

    def processo_falso(comando, **opcoes):
        chamadas.update(opcoes)
        compilado = tmp_path / "target" / "compiled" / medir_regua.PROJETO_DBT / "analyses"
        compilado.mkdir(parents=True)
        (compilado / f"{medir_regua.ANALISE}.sql").write_text("SELECT 1", encoding="utf-8")
        return subprocess.CompletedProcess(comando, 0, stdout="", stderr="")

    monkeypatch.setattr(medir_regua.subprocess, "run", processo_falso)

    assert medir_regua.compilar_metricas(tmp_path, "2026-09-15") == "SELECT 1"
    assert chamadas["encoding"] == "utf-8"
    assert chamadas["errors"] == "replace"
    assert chamadas["env"]["PYTHONUTF8"] == "1"
