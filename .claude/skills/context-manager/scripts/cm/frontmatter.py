"""Minimal YAML front matter for the skill's own Markdown files.

Only the subset the skill writes is supported: ``key: scalar``,
``key: [a, b]`` and block lists (``key:`` followed by ``  - item``).
Using the standard library keeps the core free of dependencies.
"""

from __future__ import annotations

import re
from typing import Any

FENCE = "---"
_KEY = re.compile(r"^([A-Za-z_][\w-]*):\s*(.*)$")
_ITEM = re.compile(r"^\s+-\s*(.*)$")
_ORDER = ("topic", "status", "created", "updated", "completed", "scope")


def _scalar(raw: str) -> str:
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'":
        return raw[1:-1]
    return raw


def split(text: str) -> tuple[dict[str, Any], str]:
    """Return ``(meta, body)``; ``meta`` is empty when there is no fence."""
    normalized = text.replace("\r\n", "\n")
    if not normalized.startswith(FENCE + "\n"):
        return {}, text
    end = normalized.find("\n" + FENCE, len(FENCE))
    if end == -1:
        return {}, text
    header = normalized[len(FENCE) + 1 : end]
    body = normalized[end + len(FENCE) + 1 :].lstrip("\n")

    meta: dict[str, Any] = {}
    current: str | None = None
    for line in header.split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        item = _ITEM.match(line)
        if item and current is not None:
            if not isinstance(meta.get(current), list):
                meta[current] = []
            meta[current].append(_scalar(item.group(1)))
            continue
        key = _KEY.match(line)
        if not key:
            continue
        current, value = key.group(1), key.group(2).strip()
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            meta[current] = (
                [_scalar(v) for v in inner.split(",")] if inner else []
            )
        elif value == "":
            meta[current] = []
        else:
            meta[current] = _scalar(value)
    return meta, body


def _dump_value(value: Any) -> str:
    if isinstance(value, list):
        if not value:
            return " []"
        return "".join(f"\n  - {item}" for item in value)
    text = str(value)
    if (
        text == ""
        or text[0] in "[{&*!|>%@`\"'"
        or ": " in text
        or " #" in text
    ):
        text = '"' + text.replace('"', '\\"') + '"'
    return f" {text}"


def join(meta: dict[str, Any], body: str) -> str:
    """Render ``meta`` and ``body`` back into a Markdown document."""
    keys = [k for k in _ORDER if k in meta] + [
        k for k in meta if k not in _ORDER
    ]
    lines = [f"{key}:{_dump_value(meta[key])}" for key in keys]
    return f"{FENCE}\n" + "\n".join(lines) + f"\n{FENCE}\n" + body.lstrip("\n")
