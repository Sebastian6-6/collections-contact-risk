"""Testes do verificar_reprodutibilidade.py com trechos mínimos para cada regra."""

from pathlib import Path

import pytest

from verificar_reprodutibilidade import listar_arquivos_python, verificar_codigo


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
