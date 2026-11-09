"""Small, portable filesystem primitives: atomic writes, locks, hashing.

Everything here works the same on Windows, Linux and macOS. Locks use
exclusive file creation (``O_CREAT | O_EXCL``), which is atomic on every
local filesystem, instead of ``fcntl``/``msvcrt``.
"""

from __future__ import annotations

import contextlib
import hashlib
import json
import os
import time
import uuid
from collections.abc import Iterator
from datetime import datetime
from pathlib import Path
from typing import Any

ENCODING = "utf-8"


# -- time -------------------------------------------------------------------
def now() -> datetime:
    return datetime.now().astimezone()


def today() -> str:
    return now().strftime("%Y-%m-%d")


def stamp() -> str:
    return now().strftime("%Y-%m-%d %H:%M")


# -- reading / writing ------------------------------------------------------
def read_raw(path: Path, default: str = "") -> str:
    """Read without newline translation, so CRLF files keep their endings."""
    try:
        with path.open(
            encoding=ENCODING, errors="replace", newline=""
        ) as handle:
            return handle.read()
    except FileNotFoundError:
        return default


def read_text(path: Path, default: str = "") -> str:
    try:
        return path.read_text(encoding=ENCODING)
    except FileNotFoundError:
        return default
    except UnicodeDecodeError:
        return path.read_text(encoding=ENCODING, errors="replace")


def atomic_write_text(path: Path, text: str, *, newline: str = "\n") -> None:
    """Write ``text`` so readers never observe a half-written file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{uuid.uuid4().hex[:8]}.tmp")
    with tmp.open("w", encoding=ENCODING, newline=newline) as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
    for attempt in range(20):
        try:
            tmp.replace(path)
            return
        except PermissionError:
            # Windows refuses to replace a file another process has open.
            time.sleep(0.05 * (attempt + 1))
    tmp.unlink(missing_ok=True)
    raise PermissionError(f"could not replace {path}")


def read_json(path: Path, default: Any = None) -> Any:
    text = read_text(path)
    if not text.strip():
        return default
    return json.loads(text)


def write_json(path: Path, data: Any) -> None:
    atomic_write_text(
        path, json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    )


def append_line(path: Path, line: str) -> None:
    """Append one line, adding a separating newline when needed."""
    current = read_text(path)
    if current and not current.endswith("\n"):
        current += "\n"
    atomic_write_text(path, current + line.rstrip("\n") + "\n")


# -- hashing ----------------------------------------------------------------
def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while block := handle.read(chunk):
            digest.update(block)
    return digest.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode(ENCODING)).hexdigest()


# -- locks ------------------------------------------------------------------
class LockBusyError(RuntimeError):
    """Raised when a lock stays busy longer than the allowed wait."""


@contextlib.contextmanager
def file_lock(
    path: Path, *, timeout: float = 10.0, stale_after: float = 120.0
) -> Iterator[None]:
    """Hold an exclusive lock file for the duration of the block.

    A lock older than ``stale_after`` seconds is assumed to belong to a
    crashed process and is broken.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + timeout
    while True:
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
            break
        except FileExistsError:
            with contextlib.suppress(FileNotFoundError):
                if time.time() - path.stat().st_mtime > stale_after:
                    path.unlink(missing_ok=True)
                    continue
            if time.monotonic() > deadline:
                raise LockBusyError(str(path)) from None
            time.sleep(0.05)
    try:
        os.write(fd, f"{os.getpid()} {stamp()}".encode(ENCODING))
        os.close(fd)
        yield
    finally:
        path.unlink(missing_ok=True)


def try_create(path: Path, content: str) -> bool:
    """Atomically create ``path`` with ``content``; False if it exists."""
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
    except FileExistsError:
        return False
    with os.fdopen(fd, "w", encoding=ENCODING) as handle:
        handle.write(content)
    return True


# -- misc -------------------------------------------------------------------
def human_size(size: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return (
                f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
            )
        size /= 1024
    return f"{size:.1f} TB"  # pragma: no cover - unreachable
