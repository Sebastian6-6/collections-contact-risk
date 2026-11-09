"""Filesystem layout of a project managed by context-manager."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

SKILL_NAME = "context-manager"
CONTEXT_DIR = ".context"
SCRIPT_REL = f".claude/skills/{SKILL_NAME}/scripts/ctx.py"


@dataclass(frozen=True)
class Layout:
    """Every path the skill reads or writes, derived from the project root."""

    root: Path

    # -- .context ------------------------------------------------------------
    @property
    def context(self) -> Path:
        return self.root / CONTEXT_DIR

    @property
    def config(self) -> Path:
        return self.context / "config.json"

    @property
    def project_md(self) -> Path:
        return self.context / "PROJECT.md"

    @property
    def map_md(self) -> Path:
        return self.context / "MAP.md"

    @property
    def map_json(self) -> Path:
        return self.context / "map.json"

    @property
    def index_md(self) -> Path:
        return self.context / "index.md"

    @property
    def manifest(self) -> Path:
        return self.context / "manifest.json"

    @property
    def raw(self) -> Path:
        return self.context / "raw"

    @property
    def converted(self) -> Path:
        return self.context / "converted"

    @property
    def topics(self) -> Path:
        return self.context / "topics"

    @property
    def archive(self) -> Path:
        return self.context / "archive"

    # Machine-local state: never versioned.
    @property
    def local(self) -> Path:
        return self.context / "local"

    @property
    def locks(self) -> Path:
        return self.local / "locks"

    @property
    def map_cache(self) -> Path:
        return self.local / "map-cache.json"

    @property
    def hash_cache(self) -> Path:
        return self.local / "hash-cache.json"

    # -- .claude -------------------------------------------------------------
    @property
    def claude_dir(self) -> Path:
        return self.root / ".claude"

    @property
    def claude_md(self) -> Path:
        return self.claude_dir / "CLAUDE.md"

    @property
    def root_claude_md(self) -> Path:
        return self.root / "CLAUDE.md"

    @property
    def settings(self) -> Path:
        return self.claude_dir / "settings.json"

    @property
    def skills_dir(self) -> Path:
        return self.claude_dir / "skills"

    @property
    def skill_dir(self) -> Path:
        return self.skills_dir / SKILL_NAME

    def alias_dir(self, alias: str) -> Path:
        return self.skills_dir / alias

    # -- root ----------------------------------------------------------------
    @property
    def gitignore(self) -> Path:
        return self.root / ".gitignore"

    def rel(self, path: Path) -> str:
        """Return ``path`` relative to the root, always with ``/``."""
        try:
            return path.resolve().relative_to(self.root.resolve()).as_posix()
        except ValueError:
            return path.as_posix()


def _has_skill(folder: Path) -> bool:
    return (folder / ".claude" / "skills" / SKILL_NAME).is_dir()


def find_root(explicit: str | None = None) -> Path:
    """Locate the project root.

    Order: ``--root`` → ``$CLAUDE_PROJECT_DIR`` → nearest ancestor of the
    current directory holding ``.context/config.json`` → nearest ancestor
    holding the skill → nearest ancestor holding ``.git`` → current dir.
    """
    if explicit:
        return Path(explicit).resolve()
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env and Path(env).is_dir():
        return Path(env).resolve()

    cwd = Path.cwd().resolve()
    chain = [cwd, *cwd.parents]
    for test in (
        lambda p: (p / CONTEXT_DIR / "config.json").is_file(),
        _has_skill,
        lambda p: (p / ".git").exists(),
    ):
        for folder in chain:
            if test(folder):
                return folder
    return cwd


def docling_home() -> Path:
    """Machine-wide folder holding the shared Docling environment."""
    env = os.environ.get("CONTEXT_MANAGER_HOME")
    return Path(env) if env else Path.home() / ".context-manager"
