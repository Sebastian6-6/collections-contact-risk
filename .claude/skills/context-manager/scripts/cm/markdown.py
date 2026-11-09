"""Helpers to read and edit ``## Section`` blocks of Markdown documents."""

from __future__ import annotations

import re


def _heading(name: str) -> re.Pattern[str]:
    return re.compile(
        rf"^##\s+{re.escape(name)}\s*$", re.MULTILINE | re.IGNORECASE
    )


_ANY_H2 = re.compile(r"^##\s+", re.MULTILINE)


def section_span(text: str, name: str) -> tuple[int, int] | None:
    """Character span of a section's body (after its heading line)."""
    match = _heading(name).search(text)
    if not match:
        return None
    start = match.end() + 1 if match.end() < len(text) else match.end()
    nxt = _ANY_H2.search(text, start)
    return start, (nxt.start() if nxt else len(text))


def get_section(text: str, name: str) -> str:
    span = section_span(text, name)
    return text[span[0] : span[1]].strip("\n") if span else ""


def append_to_section(text: str, name: str, line: str) -> str:
    """Append ``line`` at the end of a section, creating it if missing."""
    span = section_span(text, name)
    if span is None:
        base = text.rstrip("\n")
        return f"{base}\n\n## {name}\n{line}\n"
    start, end = span
    body = text[start:end].rstrip("\n")
    new_body = (body + "\n" if body else "") + line + "\n"
    tail = text[end:]
    separator = "\n" if tail else ""
    return text[:start] + new_body + separator + tail


def replace_section(text: str, name: str, body: str) -> str:
    span = section_span(text, name)
    if span is None:
        return f"{text.rstrip(chr(10))}\n\n## {name}\n{body.strip(chr(10))}\n"
    start, end = span
    tail = text[end:]
    return (
        text[:start] + body.strip("\n") + "\n" + ("\n" if tail else "") + tail
    )


def list_items(section: str) -> list[str]:
    return [
        m.group(1).strip()
        for m in re.finditer(r"^\s*-\s+(.+)$", section, re.M)
    ]


def remove_section(text: str, name: str) -> str:
    """Drop a ``## name`` section (heading and body); no-op when missing."""
    match = _heading(name).search(text)
    if not match:
        return text
    nxt = _ANY_H2.search(text, match.end())
    end = nxt.start() if nxt else len(text)
    result = text[: match.start()] + text[end:]
    return re.sub(r"\n{3,}", "\n\n", result).rstrip("\n") + "\n"


def insert_section_before(text: str, name: str, body: str, before: str) -> str:
    """Add ``## name`` right before section ``before`` (or at the end)."""
    block = f"## {name}\n{body.strip(chr(10))}\n\n"
    match = _heading(before).search(text)
    if not match:
        return replace_section(text, name, body)
    return text[: match.start()] + block + text[match.start() :]
