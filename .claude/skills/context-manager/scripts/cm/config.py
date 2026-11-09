"""Project configuration (``.context/config.json``): defaults, checks."""

from __future__ import annotations

import copy
import re
from typing import Any

from . import __version__
from .fsutil import file_lock, read_json, write_json
from .paths import Layout

MODULES = ("ingest", "map", "history", "status_hook")
GIT_PROFILES = ("complete", "minimal", "none", "full")
# Where the project's normative rules live. PROJECT.md is memory only.
RULES_FILES = {"claude": ".claude/CLAUDE.md", "agents": "AGENTS.md"}
ALIAS_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,19}$")

DEFAULTS: dict[str, Any] = {
    "skill_version": __version__,
    "alias": "c",
    "git_profile": "complete",
    "save_commit": False,
    "rules_file": "claude",
    "modules": dict.fromkeys(MODULES, True),
    "language": {"memory": "en", "output": "pt-BR", "ocr": ["pt", "en"]},
    "large_file_threshold": {"lines": 2000, "bytes": 1_048_576},
    "skip_dirs": [
        ".git",
        ".venv",
        "venv",
        "env",
        "node_modules",
        "__pycache__",
        ".mypy_cache",
        ".pytest_cache",
        ".ruff_cache",
        ".ipynb_checkpoints",
        "dist",
        "build",
        "target",
        ".idea",
        ".vscode",
        "site-packages",
    ],
    "map": {"max_depth": 4, "max_rows": 200},
    "lock_ttl_hours": 8,
    "known_topics": [],
    # Records what the skill already applied once, so a deliberate opt-out
    # (e.g. removing the .gitignore block) is respected afterwards.
    "applied": {"gitignore": False},
}


def _merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = _merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def validate(cfg: dict[str, Any]) -> list[str]:
    """Fix invalid values in place; return human-readable problems (pt-BR)."""
    problems: list[str] = []
    if (
        not isinstance(cfg.get("alias"), str)
        or not ALIAS_RE.match(cfg["alias"])
        or cfg["alias"] == "context-manager"
    ):
        problems.append(f"alias inválido {cfg.get('alias')!r} → usando 'c'")
        cfg["alias"] = "c"
    if cfg.get("git_profile") not in GIT_PROFILES:
        problems.append(
            f"git_profile inválido {cfg.get('git_profile')!r} → "
            "usando 'complete'"
        )
        cfg["git_profile"] = "complete"
    for name in MODULES:
        if not isinstance(cfg["modules"].get(name), bool):
            problems.append(
                f"modules.{name} deve ser true/false → usando true"
            )
            cfg["modules"][name] = True
    if cfg.get("rules_file") not in RULES_FILES:
        problems.append(
            f"rules_file inválido {cfg.get('rules_file')!r} → usando 'claude'"
        )
        cfg["rules_file"] = "claude"
    if not isinstance(cfg.get("save_commit"), bool):
        problems.append("save_commit deve ser true/false → usando false")
        cfg["save_commit"] = False
    ocr = cfg["language"].get("ocr")
    if not isinstance(ocr, list) or not all(isinstance(x, str) for x in ocr):
        problems.append(
            "language.ocr deve ser uma lista → usando ['pt', 'en']"
        )
        cfg["language"]["ocr"] = ["pt", "en"]
    return problems


def load(layout: Layout) -> tuple[dict[str, Any], list[str]]:
    """Load the config merged over defaults, plus any validation problems."""
    raw = read_json(layout.config, default={}) or {}
    if not isinstance(raw, dict):
        return copy.deepcopy(DEFAULTS), ["config.json não é um objeto JSON"]
    cfg = _merge(DEFAULTS, raw)
    return cfg, validate(cfg)


def rules_path(cfg: dict[str, Any]) -> str:
    """Repo-relative path of the file holding the project's rules."""
    return RULES_FILES[cfg["rules_file"]]


def save(layout: Layout, cfg: dict[str, Any]) -> None:
    with file_lock(layout.locks / "write-config.lock"):
        write_json(layout.config, cfg)


def update(layout: Layout, mutate) -> dict[str, Any]:
    """Read-modify-write the config under its lock."""
    with file_lock(layout.locks / "write-config.lock"):
        cfg, _ = load(layout)
        mutate(cfg)
        write_json(layout.config, cfg)
    return cfg
