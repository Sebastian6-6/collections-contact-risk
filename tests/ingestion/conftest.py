"""Fixture dos testes de ingestão."""

from pathlib import Path

import pytest
from apoio import Projeto


@pytest.fixture
def projeto(tmp_path: Path) -> Projeto:
    return Projeto(tmp_path)
