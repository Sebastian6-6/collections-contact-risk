"""Topics: per-subject memory folders under ``.context/topics``.

A topic is a folder holding ``STATE.md`` (the present) and ``HISTORY.md``
(append-only past). One level of subtopics is supported:
``.context/topics/<parent>/<child>/STATE.md``.
"""

from __future__ import annotations

import fnmatch
import json
import re
import unicodedata
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from . import frontmatter, markdown
from .fsutil import (
    atomic_write_text,
    file_lock,
    now,
    read_text,
    sha256_text,
    stamp,
    today,
    try_create,
)
from .paths import Layout
from .templates import render

RESERVED = frozenset(
    {
        "save",
        "commands",
        "new",
        "complete",
        "archive",
        "reopen",
        "ingest",
        "module",
        "tidy",
        "describe",
        "help",
        "run",
        "status",
    }
)
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
STATUSES = ("active", "completed", "archived")
_PENDING = re.compile(r"^\s*-\s*\[\?\]\s*(.+?)\s*$", re.MULTILINE)
_PLAN_ITEM = re.compile(r"^\s*-\s*\[([ xX~])\]\s*(.+?)\s*$")


class TopicError(ValueError):
    """Invalid topic name or operation (message is user-facing, pt-BR)."""


# -- names ------------------------------------------------------------------
def check_name(name: str) -> None:
    parts = name.strip("/").split("/")
    if len(parts) > 2:
        raise TopicError(f"'{name}': só um nível de subtópico é permitido")
    for part in parts:
        if part in RESERVED:
            raise TopicError(f"'{part}' é um nome reservado de comando")
        if not NAME_RE.match(part):
            raise TopicError(
                f"'{part}' inválido: use minúsculas, números, '-' ou '_'"
            )


def slugify(text: str) -> str:
    ascii_text = (
        unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    )
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_text.lower()).strip("-")
    return slug[:64] or "topic"


# -- model ------------------------------------------------------------------
@dataclass
class Topic:
    name: str
    path: Path
    archived: bool
    meta: dict[str, Any] = field(default_factory=dict)
    body: str = ""

    @property
    def state_file(self) -> Path:
        return self.path / "STATE.md"

    @property
    def history_file(self) -> Path:
        return self.path / "HISTORY.md"

    @property
    def status(self) -> str:
        value = str(self.meta.get("status") or "active").strip().lower()
        return value if value in STATUSES else "active"

    @property
    def parent(self) -> str | None:
        return self.name.split("/")[0] if "/" in self.name else None

    @property
    def scope(self) -> list[str]:
        value = self.meta.get("scope") or []
        return (
            [str(v) for v in value]
            if isinstance(value, list)
            else [str(value)]
        )

    def text(self) -> str:
        return read_text(self.state_file)

    def save(self) -> None:
        atomic_write_text(
            self.state_file, frontmatter.join(self.meta, self.body)
        )


def load(name: str, path: Path, archived: bool) -> Topic:
    meta, body = frontmatter.split(read_text(path / "STATE.md"))
    return Topic(name=name, path=path, archived=archived, meta=meta, body=body)


@dataclass
class Discovery:
    topics: dict[str, Topic] = field(default_factory=dict)
    created: list[str] = field(default_factory=list)
    invalid: list[str] = field(default_factory=list)

    def active(self) -> list[Topic]:
        return [
            t
            for t in self.topics.values()
            if not t.archived and t.status == "active"
        ]

    def by_status(self, status: str) -> list[Topic]:
        return [t for t in self.topics.values() if t.status == status]


def _write_new(path: Path, name: str, history: bool) -> None:
    path.mkdir(parents=True, exist_ok=True)
    try_create(
        path / "STATE.md",
        render("STATE.md", topic=name, today=today(), stamp=stamp()),
    )
    if history:
        try_create(path / "HISTORY.md", render("HISTORY.md", topic=name))


def discover(
    layout: Layout, *, history: bool, materialize: bool = True
) -> Discovery:
    """Find topics; give new folders a STATE.md when ``materialize``."""
    found = Discovery()
    for base, archived in ((layout.topics, False), (layout.archive, True)):
        if not base.is_dir():
            continue
        for top in sorted(p for p in base.iterdir() if p.is_dir()):
            if top.name.startswith("."):
                continue
            _visit(
                found,
                top,
                top.name,
                archived=archived,
                history=history,
                materialize=materialize,
            )
            for sub in sorted(p for p in top.iterdir() if p.is_dir()):
                if sub.name.startswith("."):
                    continue
                _visit(
                    found,
                    sub,
                    f"{top.name}/{sub.name}",
                    archived=archived,
                    history=history,
                    materialize=materialize,
                )
                for deeper in (p for p in sub.iterdir() if p.is_dir()):
                    found.invalid.append(
                        f"{layout.rel(deeper)}: nível extra ignorado "
                        "(só um nível de subtópico)"
                    )
    return found


def _visit(
    found: Discovery,
    path: Path,
    name: str,
    *,
    archived: bool,
    history: bool,
    materialize: bool,
) -> None:
    try:
        check_name(name)
    except TopicError as error:
        found.invalid.append(f"{name}: {error}")
        return
    if not (path / "STATE.md").exists():
        if archived or not materialize:
            return
        _write_new(path, name, history)
        found.created.append(name)
    elif history and not archived and not (path / "HISTORY.md").exists():
        try_create(path / "HISTORY.md", render("HISTORY.md", topic=name))
    key = name if name not in found.topics else f"{name} (archive)"
    found.topics[key] = load(name, path, archived)


def create(layout: Layout, name: str, *, history: bool) -> list[str]:
    """Create a topic (and its parent when needed). Returns created names."""
    name = name.strip("/")
    check_name(name)
    created: list[str] = []
    parts = name.split("/")
    if (layout.archive / parts[0]).exists():
        raise TopicError(f"'{parts[0]}' está arquivado; use reopen")
    for depth in range(1, len(parts) + 1):
        current = "/".join(parts[:depth])
        folder = layout.topics.joinpath(*parts[:depth])
        if not (folder / "STATE.md").exists():
            _write_new(folder, current, history)
            created.append(current)
    if not created:
        raise TopicError(f"o tópico '{name}' já existe")
    return created


def find(layout: Layout, name: str, *, history: bool) -> Topic | None:
    name = name.strip("/")
    for base, archived in ((layout.topics, False), (layout.archive, True)):
        folder = base.joinpath(*name.split("/"))
        if (folder / "STATE.md").exists():
            return load(name, folder, archived)
    return None


# -- status transitions -----------------------------------------------------
def set_status(topic: Topic, status: str) -> None:
    topic.meta["status"] = status
    topic.meta["updated"] = stamp()
    if status == "completed":
        topic.meta.setdefault("completed", today())
    elif status == "active":
        topic.meta.pop("completed", None)
    topic.save()


def references(layout: Layout, topic: Topic) -> list[str]:
    """Files outside the topic that point at its folder."""
    needle = f"topics/{topic.name}"
    hits: list[str] = []
    candidates = [layout.project_md, layout.claude_md, layout.root_claude_md]
    if layout.topics.is_dir():
        candidates += list(layout.topics.rglob("*.md"))
    for path in candidates:
        if not path.is_file() or topic.path in path.parents:
            continue
        if needle in read_text(path):
            hits.append(layout.rel(path))
    return sorted(set(hits))


def children(found: Discovery, parent: str) -> list[Topic]:
    return [t for t in found.topics.values() if t.parent == parent]


# -- pending questions ------------------------------------------------------
def pending(topic: Topic) -> list[str]:
    section = markdown.get_section(topic.body, "Pending")
    return [m.group(1) for m in _PENDING.finditer(section)]


def goal_hash(topic: Topic) -> str:
    return sha256_text(markdown.get_section(topic.body, "Goal").strip())


# -- scope ------------------------------------------------------------------
def scope_matches(entry: str, rel_path: str) -> bool:
    entry = entry.strip().lstrip("./").replace("\\", "/")
    if not entry:
        return False
    if any(ch in entry for ch in "*?["):
        return fnmatch.fnmatch(rel_path, entry) or fnmatch.fnmatch(
            rel_path, entry.rstrip("/") + "/*"
        )
    if entry.endswith("/"):
        return rel_path.startswith(entry)
    return rel_path == entry or rel_path.startswith(entry + "/")


def in_scope(topic: Topic, rel_path: str) -> bool:
    return any(scope_matches(entry, rel_path) for entry in topic.scope)


def scope_base(entry: str) -> str:
    """Folder part of a scope entry, before any wildcard."""
    entry = entry.strip().lstrip("./").replace("\\", "/")
    cut = min((entry.find(ch) for ch in "*?[" if ch in entry), default=-1)
    if cut != -1:
        entry = entry[:cut]
        return entry[: entry.rfind("/") + 1]
    if entry.endswith("/"):
        return entry
    return entry.rsplit("/", 1)[0] + "/" if "/" in entry else entry + "/"


# -- appends (always under a write lock) ------------------------------------
def _lock_for(layout: Layout, path: Path) -> Path:
    return layout.locks / f"write-{sha256_text(layout.rel(path))[:16]}.lock"


def append_section_line(
    layout: Layout, path: Path, section: str, line: str
) -> None:
    with file_lock(_lock_for(layout, path)):
        atomic_write_text(
            path, markdown.append_to_section(read_text(path), section, line)
        )


def append_history(layout: Layout, topic: Topic, kind: str, text: str) -> None:
    if kind not in ("done", "drop", "pivot"):
        raise TopicError("tipo de histórico deve ser done, drop ou pivot")
    line = f"{today()} {kind:<5} {' '.join(text.split())}"
    path = topic.history_file
    with file_lock(_lock_for(layout, path)):
        current = read_text(path) or render("HISTORY.md", topic=topic.name)
        if not current.endswith("\n"):
            current += "\n"
        atomic_write_text(path, current + line + "\n")


def append_decision(
    layout: Layout, topic: Topic, level: str, text: str
) -> str:
    """Record a decision at ``topic``, ``parent`` or ``project`` level."""
    text = " ".join(text.split())
    if level == "topic":
        append_section_line(
            layout, topic.state_file, "Decisions", f"- {today()} {text}"
        )
        return layout.rel(topic.state_file)
    if level == "parent":
        if not topic.parent:
            raise TopicError("este tópico não tem tópico-pai")
        parent_state = topic.path.parent / "STATE.md"
        child = topic.name.split("/")[1]
        append_section_line(
            layout,
            parent_state,
            "Shared decisions",
            f"- {today()} [{child}] {text}",
        )
        return layout.rel(parent_state)
    if level == "project":
        append_section_line(
            layout,
            layout.project_md,
            "Decision log",
            f"- {today()} [{topic.name}] {text}",
        )
        return layout.rel(layout.project_md)
    raise TopicError("nível deve ser topic, parent ou project")


# -- plan housekeeping on save ----------------------------------------------
def harvest_plan(topic: Topic) -> list[tuple[str, str]]:
    """Remove done/dropped plan items; return them as history entries."""
    span = markdown.section_span(topic.body, "Plan")
    if span is None:
        return []
    kept: list[str] = []
    events: list[tuple[str, str]] = []
    for line in topic.body[span[0] : span[1]].split("\n"):
        match = _PLAN_ITEM.match(line)
        if match and match.group(1) in "xX":
            events.append(("done", match.group(2)))
        elif match and match.group(1) == "~":
            events.append(("drop", match.group(2)))
        else:
            kept.append(line)
    if events:
        topic.body = (
            topic.body[: span[0]] + "\n".join(kept) + topic.body[span[1] :]
        )
    return events


# -- session locks (one open session per topic) -----------------------------
def _session_lock(layout: Layout, name: str) -> Path:
    return layout.locks / f"topic-{name.replace('/', '__')}.json"


def _stale(info: dict[str, Any], ttl_hours: float) -> bool:
    try:
        started = datetime.fromisoformat(info["started"])
    except (KeyError, ValueError, TypeError):
        return True
    return now() - started > timedelta(hours=ttl_hours)


def read_lock(
    layout: Layout, name: str, ttl_hours: float
) -> dict[str, Any] | None:
    path = _session_lock(layout, name)
    try:
        info = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, ValueError):
        return None
    if _stale(info, ttl_hours):
        path.unlink(missing_ok=True)
        return None
    return info


def acquire(
    layout: Layout,
    topic: Topic,
    session: str,
    ttl_hours: float,
    *,
    take_over: bool = False,
    project_sha: str = "",
) -> dict[str, Any] | None:
    """Open ``topic`` for ``session``; return the conflicting holder."""
    info = {
        "topic": topic.name,
        "session": session,
        "started": now().isoformat(timespec="seconds"),
        "project_sha": project_sha,
        "goal_sha": goal_hash(topic),
    }
    path = _session_lock(layout, topic.name)
    if try_create(path, json.dumps(info)):
        return None
    holder = read_lock(layout, topic.name, ttl_hours)
    if holder and holder.get("session") != session and not take_over:
        return holder
    atomic_write_text(path, json.dumps(info))
    return None


def release(layout: Layout, name: str) -> None:
    _session_lock(layout, name).unlink(missing_ok=True)


def all_locks(layout: Layout, ttl_hours: float) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    if not layout.locks.is_dir():
        return result
    for path in layout.locks.glob("topic-*.json"):
        name = path.stem[len("topic-") :].replace("__", "/")
        info = read_lock(layout, name, ttl_hours)
        if info:
            result[name] = info
    return result
