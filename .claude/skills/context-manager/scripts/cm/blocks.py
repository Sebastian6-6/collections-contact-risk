"""Managed blocks: the only parts of user files the skill rewrites.

A block is delimited by begin/end markers so the skill can update its own
lines without touching anything around them. Line endings (LF or CRLF) of
the host file are preserved.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

TAG = "context-manager"


@dataclass(frozen=True)
class Style:
    begin: str
    end: str


HASH = Style(
    begin=f"# >>> {TAG} (managed block — delete the whole block to opt "
    "out) >>>",
    end=f"# <<< {TAG} <<<",
)
HTML = Style(
    begin=f"<!-- >>> {TAG} (managed by the {TAG} skill — edits inside are "
    "overwritten) >>> -->",
    end=f"<!-- <<< {TAG} <<< -->",
)

_BEGIN = re.compile(rf"^.*>>> {re.escape(TAG)}\b.*$", re.MULTILINE)
_END = re.compile(rf"^.*<<< {re.escape(TAG)} <<<.*$", re.MULTILINE)


def _span(text: str) -> tuple[int, int] | None:
    begin = _BEGIN.search(text)
    if not begin:
        return None
    end = _END.search(text, begin.end())
    if not end:
        return None
    stop = end.end()
    if stop < len(text) and text[stop] == "\n":
        stop += 1
    return begin.start(), stop


def has_block(text: str) -> bool:
    return _span(text.replace("\r\n", "\n")) is not None


def get_body(text: str) -> str | None:
    normalized = text.replace("\r\n", "\n")
    span = _span(normalized)
    if span is None:
        return None
    lines = normalized[span[0] : span[1]].rstrip("\n").split("\n")
    return "\n".join(lines[1:-1]).strip("\n")


def upsert(text: str, body: str, style: Style) -> str:
    """Insert or replace the block; returns the new file content."""
    crlf = "\r\n" in text
    normalized = text.replace("\r\n", "\n")
    block = f"{style.begin}\n{body.strip(chr(10))}\n{style.end}\n"
    span = _span(normalized)
    if span:
        result = normalized[: span[0]] + block + normalized[span[1] :]
    elif normalized.strip():
        result = normalized.rstrip("\n") + "\n\n" + block
    else:
        result = block
    return result.replace("\n", "\r\n") if crlf else result


def remove(text: str) -> str:
    crlf = "\r\n" in text
    normalized = text.replace("\r\n", "\n")
    span = _span(normalized)
    if not span:
        return text
    result = normalized[: span[0]] + normalized[span[1] :]
    result = re.sub(r"\n{3,}", "\n\n", result).strip("\n")
    result = result + "\n" if result else ""
    return result.replace("\n", "\r\n") if crlf else result
