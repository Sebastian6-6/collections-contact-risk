"""Saída dos pontos de entrada: com a saída redirecionada, o texto sai em UTF-8."""

import os
import subprocess
import sys
from pathlib import Path

import yaml
from apoio import entidade

RAIZ_DO_REPOSITORIO = Path(__file__).resolve().parents[2]
ILEGIVEL_EM_UTF8 = "ilegível".encode()

PERFIL = """
collections_contact_risk:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: database/teste.duckdb
"""

# Roda pipeline.py como `__main__` apontando a ingestão para uma raiz temporária sem fontes.yml.
SCRIPT_DA_PIPELINE = """
import runpy, sys
from pathlib import Path
import ingestion.main as principal
principal.RAIZ_PADRAO = Path(sys.argv[1])
principal.CONFIGURACAO_PADRAO = Path(sys.argv[1]) / "inexistente.yml"
runpy.run_path("pipeline.py", run_name="__main__")
"""


def _rodar_com_saida_redirecionada(argumentos: list[str]) -> bytes:
    """Roda o Python com a saída em pipe e sem as variáveis que forçam UTF-8."""
    ambiente = {
        chave: valor
        for chave, valor in os.environ.items()
        if chave not in {"PYTHONUTF8", "PYTHONIOENCODING"}
    }
    resultado = subprocess.run(
        [sys.executable, *argumentos], cwd=RAIZ_DO_REPOSITORIO, env=ambiente, capture_output=True
    )
    return resultado.stdout


def test_a_ingestao_escreve_ilegivel_em_utf8(tmp_path):
    (tmp_path / "dados").mkdir()
    (tmp_path / "dados" / "a.csv").write_text("id\n1\n", encoding="utf-8")
    config = tmp_path / "fontes.yml"
    config.write_text(
        yaml.safe_dump({"fonte": {"pessoas": entidade("csv", ("dados", "*.csv"))}}),
        encoding="utf-8",
    )

    saida = _rodar_com_saida_redirecionada(
        [
            "-m", "ingestion.main",
            "--config", str(config),
            "--raiz", str(tmp_path),
            "--banco", str(tmp_path / "database" / "teste.duckdb"),
        ]
    )  # fmt: skip

    assert ILEGIVEL_EM_UTF8 in saida


def test_a_pipeline_escreve_acentos_em_utf8(tmp_path):
    (tmp_path / "profiles.yml").write_text(PERFIL, encoding="utf-8")

    saida = _rodar_com_saida_redirecionada(["-c", SCRIPT_DA_PIPELINE, str(tmp_path)])

    assert ILEGIVEL_EM_UTF8 in saida

