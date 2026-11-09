"""Render the Markdown templates bundled with the skill."""

from __future__ import annotations

from pathlib import Path
from string import Template

TEMPLATE_DIR = Path(__file__).resolve().parents[2] / "templates"


def render(name: str, **values: str) -> str:
    text = (TEMPLATE_DIR / name).read_text(encoding="utf-8")
    # safe_substitute keeps unknown placeholders such as $ARGUMENTS intact.
    return Template(text).safe_substitute(values)
