"""Thin, failure-tolerant wrappers around the ``git`` CLI.

Every function degrades gracefully when git is missing or the folder is
not a repository: the skill must work in both cases.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


def _git(root: Path, *args: str) -> subprocess.CompletedProcess[str] | None:
    if shutil.which("git") is None:
        return None
    try:
        return subprocess.run(
            ["git", *args],
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None


def is_repo(root: Path) -> bool:
    result = _git(root, "rev-parse", "--is-inside-work-tree")
    return bool(
        result and result.returncode == 0 and result.stdout.strip() == "true"
    )


def is_tracked(root: Path, path: Path) -> bool:
    result = _git(root, "ls-files", "--error-unmatch", "--", str(path))
    return bool(result and result.returncode == 0)


def tracked_ignored(root: Path, prefix: str) -> list[str]:
    """Files under ``prefix`` that are tracked but now match .gitignore."""
    result = _git(root, "ls-files", "-ci", "--exclude-standard", "--", prefix)
    if not result or result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line.strip()]


def move(root: Path, src: Path, dst: Path) -> None:
    """Move a folder, keeping git history when its files are tracked."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    if is_repo(root) and is_tracked(root, src):
        result = _git(root, "mv", "-k", str(src), str(dst))
        if result and result.returncode == 0 and not src.exists():
            return
        if dst.exists() and src.exists():
            # Mixed tracked/untracked content: finish with a plain move.
            for item in src.iterdir():
                shutil.move(str(item), str(dst / item.name))
            src.rmdir()
            return
    shutil.move(str(src), str(dst))


def changed_files(root: Path) -> list[str]:
    """Modified, added and untracked files (``/``-separated, root-relative)."""
    result = _git(
        root, "status", "--porcelain=v1", "-z", "--untracked-files=all"
    )
    if not result or result.returncode != 0:
        return []
    files: list[str] = []
    entries = result.stdout.split("\0")
    skip_next = False
    for entry in entries:
        if skip_next:
            skip_next = False
            continue
        if len(entry) < 4:
            continue
        status, path = entry[:2], entry[3:]
        if "R" in status or "C" in status:
            skip_next = True  # the next entry is the rename source
        files.append(path)
    return files


def has_changes(root: Path, prefix: str) -> bool:
    result = _git(root, "status", "--porcelain", "--", prefix)
    return bool(result and result.returncode == 0 and result.stdout.strip())


def commit_paths(root: Path, prefix: str, message: str) -> tuple[bool, str]:
    """Commit only ``prefix``; other staged work is left untouched."""
    if not is_repo(root):
        return False, "not a git repository"
    if not has_changes(root, prefix):
        return True, "nothing to commit"
    add = _git(root, "add", "-A", "--", prefix)
    if not add or add.returncode != 0:
        return False, (add.stderr.strip() if add else "git unavailable")
    commit = _git(root, "commit", "--only", "-m", message, "--", prefix)
    if not commit or commit.returncode != 0:
        detail = (commit.stderr or commit.stdout).strip() if commit else ""
        return False, detail or "git commit failed"
    return True, "committed"
