"""Testes do verificar_reprodutibilidade.py com trechos mínimos para cada regra."""

from pathlib import Path

import pytest

from verificar_reprodutibilidade import (
    carregar_caminhos,
    listar_arquivos_python,
    main,
    verificar_codigo,
)


def regras(codigo: str) -> list[str]:
    return sorted(achado.regra for achado in verificar_codigo(Path("x.py"), codigo))


@pytest.mark.parametrize(
    "chamada",
    ["datetime.now()", "datetime.datetime.now()", "date.today()", "time.time()"],
)
def test_relogio(chamada):
    assert regras(f"valor = {chamada}\n") == ["relogio"]


@pytest.mark.parametrize("importacao", ["import random", "from uuid import uuid4"])
def test_sorteio(importacao):
    assert regras(f"{importacao}\n") == ["sorteio"]


def test_listagem_sem_ordem():
    assert regras("arquivos = list(pasta.glob('*.csv'))\n") == ["ordem-de-arquivos"]


def test_listagem_ordenada_passa():
    assert regras("arquivos = sorted(pasta.glob('*.csv'))\n") == []
    assert regras("arquivos = sorted(p for p in pasta.rglob('*.csv'))\n") == []


def test_liberacao_explicita():
    codigo = "inicio = time.time()  # reprodutivel: só mede duração, não vai para os dados\n"
    assert regras(codigo) == []


def test_codigo_limpo_passa():
    codigo = "def somar(a: int, b: int) -> int:\n    return a + b\n"
    assert regras(codigo) == []


def test_pastas_de_teste_ficam_de_fora(tmp_path):
    (tmp_path / "ingestion" / "tests").mkdir(parents=True)
    (tmp_path / "ingestion" / "ler.py").write_text("x = 1\n", encoding="utf-8")
    (tmp_path / "ingestion" / "tests" / "test_ler.py").write_text("x = 1\n", encoding="utf-8")
    nomes = [arquivo.name for arquivo in listar_arquivos_python([tmp_path / "ingestion"])]
    assert nomes == ["ler.py"]


def test_ast_walk_nao_e_listagem_de_arquivos():
    assert regras("import ast\nnos = list(ast.walk(arvore))\n") == []
    assert regras("import os\nfor raiz, _, nomes in os.walk(pasta):\n    pass\n") == [
        "ordem-de-arquivos"
    ]


def test_listagem_ignora_venv_ocultas_e_arquivos_de_teste(tmp_path):
    for pasta in (".venv", "venv", ".oculta", "__pycache__", "pacote"):
        (tmp_path / pasta).mkdir()
        (tmp_path / pasta / "a.py").write_text("x = 1\n", encoding="utf-8")
    (tmp_path / "pacote" / "test_a.py").write_text("x = 1\n", encoding="utf-8")
    nomes = [str(a.relative_to(tmp_path)) for a in listar_arquivos_python([tmp_path])]
    assert nomes == [str(Path("pacote") / "a.py")]


def test_sem_configuracao_o_padrao_e_a_raiz(tmp_path):
    assert carregar_caminhos(None, tmp_path) == [Path()]


def test_carrega_caminhos_do_pyproject(tmp_path):
    (tmp_path / "pyproject.toml").write_text(
        '[tool.verificar_reprodutibilidade]\ncaminhos = ["ingestion", "pipeline.py"]\n',
        encoding="utf-8",
    )
    fundo = tmp_path / "x"
    fundo.mkdir()
    assert carregar_caminhos(None, fundo) == [Path("ingestion"), Path("pipeline.py")]


def test_flag_config_usa_o_arquivo_indicado(tmp_path, capsys):
    configuracao = tmp_path / "outra.toml"
    configuracao.write_text(
        f'[tool.verificar_reprodutibilidade]\ncaminhos = ["{tmp_path.as_posix()}"]\n',
        encoding="utf-8",
    )
    (tmp_path / "m.py").write_text("import random\n", encoding="utf-8")
    assert main(["--config", str(configuracao)]) == 1
    assert "sorteio" in capsys.readouterr().out
