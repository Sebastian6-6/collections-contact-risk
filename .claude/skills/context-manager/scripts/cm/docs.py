"""Documents: Docling environment, ingestion, manifest and index.

Originals live in ``.context/raw/`` (machine-local, never versioned).
Each one becomes ``.context/converted/<id>.md`` with page markers, and
``manifest.json`` remembers its hash so only new or changed files are
converted again. ``index.md`` is generated from the manifest.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from . import frontmatter
from .fsutil import (
    atomic_write_text,
    file_lock,
    read_json,
    read_text,
    sha256_file,
    stamp,
    try_create,
    write_json,
)
from .paths import Layout, docling_home
from .topics import slugify

IMAGE_EXT = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp", ".webp"}
DOCLING_EXT = {
    ".pdf",
    ".docx",
    ".pptx",
    ".xlsx",
    ".html",
    ".htm",
    ".csv",
    ".adoc",
    ".asciidoc",
    *IMAGE_EXT,
}
PLAIN_EXT = {".md", ".markdown", ".txt"}
LEGACY_EXT = {".doc": ".docx", ".ppt": ".pptx", ".xls": ".xlsx"}
# EasyOCR ships a Portuguese model; the default RapidOCR install does not.
# $CONTEXT_MANAGER_DOCLING_SPEC pins another requirement if needed.
DOCLING_SPEC = os.environ.get(
    "CONTEXT_MANAGER_DOCLING_SPEC", "docling[easyocr]>=2.100,<3"
)
WORKER = Path(__file__).resolve().parent / "ingest_worker.py"
_PROBE = (
    "import docling, importlib.metadata as m\n"
    "for name in ('docling', 'docling-slim'):\n"
    "    try:\n"
    "        print(m.version(name)); break\n"
    "    except m.PackageNotFoundError:\n"
    "        pass\n"
)
MIN_IMAGE_TEXT = 40
LARGE_MD = 300_000


# -- Docling environment (one per machine) ----------------------------------
def venv_python(home: Path) -> Path:
    if os.name == "nt":
        return home / "venv" / "Scripts" / "python.exe"
    return home / "venv" / "bin" / "python"


def docling_python() -> Path | None:
    override = os.environ.get("CONTEXT_MANAGER_DOCLING_PYTHON")
    if override:
        return Path(override)
    python = venv_python(docling_home())
    return python if python.exists() else None


def docling_version() -> str | None:
    """Installed Docling version, read from the state file (no import)."""
    if os.environ.get("CONTEXT_MANAGER_DOCLING_PYTHON"):
        return "custom"
    if docling_python() is None:
        return None
    state = read_json(docling_home() / "state.json", default={}) or {}
    return state.get("docling_version")


def install_docling() -> tuple[bool, str]:
    """Create the shared environment and install Docling into it."""
    home = docling_home()
    home.mkdir(parents=True, exist_ok=True)
    lock = home / "install.lock"
    if lock.exists() and time.time() - lock.stat().st_mtime > 2 * 3600:
        lock.unlink(missing_ok=True)  # left behind by a crashed install
    if not try_create(lock, stamp()):
        return (
            False,
            "já está sendo instalado por outra sessão; espere terminar",
        )
    try:
        return _install(home)
    finally:
        lock.unlink(missing_ok=True)


def _install(home: Path) -> tuple[bool, str]:
    log_path = home / "install.log"
    python = venv_python(home)
    uv = shutil.which("uv")
    steps: list[list[str]] = []
    if not python.exists():
        steps.append(
            [uv, "venv", str(home / "venv"), "--python", sys.executable]
            if uv
            else [sys.executable, "-m", "venv", str(home / "venv")]
        )
    if uv:
        steps.append(
            [uv, "pip", "install", "--python", str(python), DOCLING_SPEC]
        )
    else:
        steps.append([str(python), "-m", "pip", "install", "--upgrade", "pip"])
        steps.append([str(python), "-m", "pip", "install", DOCLING_SPEC])

    with log_path.open("a", encoding="utf-8") as log:
        for step in steps:
            log.write(f"\n$ {' '.join(step)}\n")
            log.flush()
            result = subprocess.run(
                step, stdout=log, stderr=subprocess.STDOUT, check=False
            )
            if result.returncode != 0:
                return (
                    False,
                    f"falhou: {' '.join(step[:3])}… (veja {log_path})",
                )

    probe = subprocess.run(
        [str(python), "-c", _PROBE],
        capture_output=True,
        text=True,
        check=False,
    )
    if probe.returncode != 0:
        return False, f"Docling não importou após instalar (veja {log_path})"
    version = probe.stdout.strip()
    write_json(
        home / "state.json",
        {
            "docling_version": version,
            "installed": stamp(),
            "python": str(python),
        },
    )
    return True, version


# -- manifest ---------------------------------------------------------------
def load_manifest(layout: Layout) -> dict[str, Any]:
    data = read_json(layout.manifest, default={}) or {}
    data.setdefault("version", 1)
    data.setdefault("documents", {})
    return data


def _manifest_lock(layout: Layout) -> Path:
    return layout.locks / "write-manifest.lock"


def save_manifest(layout: Layout, data: dict[str, Any]) -> None:
    write_json(layout.manifest, data)


def raw_files(layout: Layout) -> list[Path]:
    if not layout.raw.is_dir():
        return []
    files = []
    for path in sorted(layout.raw.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(layout.raw)
        # Skip hidden files and Office owner/lock files ("~$report.docx").
        if any(part.startswith((".", "~$")) for part in rel.parts):
            continue
        files.append(path)
    return files


@dataclass
class Scan:
    todo: list[tuple[Path, str, str]] = field(
        default_factory=list
    )  # path, id, sha
    unsupported: list[str] = field(default_factory=list)
    missing_source: list[str] = field(default_factory=list)
    total: int = 0


def _hash_cached(layout: Layout, path: Path, cache: dict[str, Any]) -> str:
    rel = path.relative_to(layout.raw).as_posix()
    stat = path.stat()
    hit = cache.get(rel)
    if (
        hit
        and hit["size"] == stat.st_size
        and hit["mtime_ns"] == stat.st_mtime_ns
    ):
        return hit["sha"]
    sha = sha256_file(path)
    cache[rel] = {
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
        "sha": sha,
    }
    return sha


def _new_id(source: str, documents: dict[str, Any]) -> str:
    base = slugify(
        Path(source.removeprefix("raw/")).with_suffix("").as_posix()
    )
    candidate, n = base, 2
    while (
        candidate in documents and documents[candidate].get("source") != source
    ):
        candidate, n = f"{base}-{n}", n + 1
    return candidate


def scan(layout: Layout, force: set[str] | None = None) -> Scan:
    """Compare ``raw/`` with the manifest. Cheap: hashes are cached."""
    force = force or set()
    manifest = load_manifest(layout)
    documents = manifest["documents"]
    by_source = {d.get("source"): i for i, d in documents.items()}
    cache = read_json(layout.hash_cache, default={}) or {}
    result = Scan()
    present = set()
    for path in raw_files(layout):
        source = "raw/" + path.relative_to(layout.raw).as_posix()
        present.add(source)
        ext = path.suffix.lower()
        if ext not in DOCLING_EXT | PLAIN_EXT:
            hint = LEGACY_EXT.get(ext)
            result.unsupported.append(
                source + (f" (salve como {hint})" if hint else "")
            )
            continue
        result.total += 1
        sha = _hash_cached(layout, path, cache)
        doc_id = by_source.get(source) or _new_id(source, documents)
        entry = documents.get(doc_id, {})
        converted = layout.context / entry.get(
            "converted", f"converted/{doc_id}.md"
        )
        if (
            entry.get("sha256") != sha
            or entry.get("status") == "error"
            or not converted.exists()
            or doc_id in force
            or source in force
            or path.name in force
        ):
            result.todo.append((path, doc_id, sha))
    write_json(layout.hash_cache, cache)
    result.missing_source = sorted(
        i for i, d in documents.items() if d.get("source") not in present
    )
    return result


# -- conversion -------------------------------------------------------------
def _write_converted(
    layout: Layout, doc_id: str, entry: dict[str, Any], body: str
) -> None:
    meta = {
        "id": doc_id,
        "source": entry["source"],
        "origin": entry.get("origin") or "",
        "sha256": entry["sha256"],
        "converter": entry["converter"],
        "converted": entry["converted_at"],
        "pages": entry.get("pages", 0),
        "kind": entry["kind"],
    }
    atomic_write_text(
        layout.context / entry["converted"],
        frontmatter.join(meta, body.strip() + "\n"),
    )


def _base_entry(
    layout: Layout, path: Path, sha: str, old: dict[str, Any]
) -> dict:
    source = "raw/" + path.relative_to(layout.raw).as_posix()
    # A changed file keeps its tags and origin, but its summary must be redone.
    kept = (
        ("tags", "origin")
        if old.get("sha256") != sha
        else ("summary", "tags", "origin")
    )
    return {
        **{k: old[k] for k in kept if k in old},
        "source": source,
        "sha256": sha,
        "size": path.stat().st_size,
        "kind": "image" if path.suffix.lower() in IMAGE_EXT else "document",
        "converted_at": stamp(),
    }


def ingest(
    layout: Layout, cfg: dict[str, Any], force: set[str] | None = None
) -> dict[str, Any]:
    """Convert new/changed originals. Returns a report dictionary."""
    found = scan(layout, force)
    report: dict[str, Any] = {
        "converted": [],
        "failed": [],
        "large": [],
        "notes": [],
        "needs_description": [],
        "unsupported": found.unsupported,
        "skipped": 0,
    }
    if not found.todo:
        return report

    plain = [t for t in found.todo if t[0].suffix.lower() in PLAIN_EXT]
    heavy = [t for t in found.todo if t[0].suffix.lower() not in PLAIN_EXT]
    results: dict[str, dict[str, Any]] = {}

    for path, doc_id, _sha in plain:
        _, body = frontmatter.split(read_text(path))
        results[doc_id] = {
            "ok": True,
            "markdown": body,
            # Markdown that already carries page markers keeps its pagination.
            "pages": len(re.findall(r"^<!-- page \d+ -->$", body, re.M)),
            "converter": "plain",
        }

    if heavy:
        python = docling_python()
        if python is None:
            report["docling_missing"] = len(heavy)
        else:
            results.update(_run_worker(layout, python, heavy, cfg))

    with file_lock(_manifest_lock(layout), timeout=30):
        manifest = load_manifest(layout)
        documents = manifest["documents"]
        for path, doc_id, sha in found.todo:
            outcome = results.get(doc_id)
            if outcome is None:
                report["skipped"] += 1
                continue
            entry = _base_entry(layout, path, sha, documents.get(doc_id, {}))
            entry["converted"] = f"converted/{doc_id}.md"
            if not outcome.get("ok"):
                entry.update(
                    status="error",
                    error=outcome.get("error", "?"),
                    converter="docling",
                    pages=0,
                )
                documents[doc_id] = entry
                report["failed"].append(f"{entry['source']}: {entry['error']}")
                continue
            entry.update(
                status="ok",
                error=None,
                pages=outcome.get("pages", 0),
                converter=outcome.get("converter", "docling"),
            )
            if outcome.get("warning"):
                report["notes"].append(
                    f"{entry['source']}: {outcome['warning']}"
                )
            body = outcome["markdown"]
            if entry["kind"] == "image":
                entry["needs_description"] = len(body.strip()) < MIN_IMAGE_TEXT
                if entry["needs_description"]:
                    report["needs_description"].append(doc_id)
                body = "## Extracted text (OCR)\n\n" + (
                    body.strip() or "_none_"
                )
            documents[doc_id] = entry
            _write_converted(layout, doc_id, entry, body)
            report["converted"].append(doc_id)
            if len(body) > LARGE_MD:
                report["large"].append(doc_id)
        save_manifest(layout, manifest)
    write_index(layout)
    return report


def _run_worker(
    layout: Layout,
    python: Path,
    items: list[tuple[Path, str, str]],
    cfg: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    layout.local.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=layout.local) as tmp:
        tmp_dir = Path(tmp)
        job = {
            "ocr_langs": cfg["language"]["ocr"],
            "items": [
                {
                    "id": doc_id,
                    "src": str(path),
                    "out": str(tmp_dir / f"{doc_id}.md"),
                    "image": path.suffix.lower() in IMAGE_EXT,
                }
                for path, doc_id, _ in items
            ],
        }
        job_path, result_path = tmp_dir / "job.json", tmp_dir / "result.json"
        job_path.write_text(json.dumps(job), encoding="utf-8")
        log_path = layout.local / "ingest.log"
        with log_path.open("a", encoding="utf-8") as log:
            log.write(f"\n== {stamp()} · {len(items)} file(s)\n")
            log.flush()
            proc = subprocess.run(
                [
                    str(python),
                    "-X",
                    "utf8",
                    str(WORKER),
                    str(job_path),
                    str(result_path),
                ],
                stdout=log,
                stderr=subprocess.STDOUT,
                check=False,
            )
        if not result_path.exists():
            error = (
                f"o conversor terminou com código {proc.returncode} "
                f"(veja {layout.rel(log_path)})"
            )
            return {
                doc_id: {"ok": False, "error": error} for _, doc_id, _ in items
            }
        data = json.loads(result_path.read_text(encoding="utf-8"))
        version = data.get("docling_version", "?")
        results: dict[str, dict[str, Any]] = {}
        for item in data.get("results", []):
            if item.get("ok"):
                item["markdown"] = Path(item["out"]).read_text(
                    encoding="utf-8"
                )
                item["converter"] = f"docling {version}"
            results[item["id"]] = item
        return results


# -- metadata set by Claude -------------------------------------------------
def set_meta(
    layout: Layout,
    doc_id: str,
    *,
    summary: str | None = None,
    tags: list[str] | None = None,
    origin: str | None = None,
    description: str | None = None,
) -> dict[str, Any]:
    with file_lock(_manifest_lock(layout), timeout=30):
        manifest = load_manifest(layout)
        entry = manifest["documents"].get(doc_id)
        if entry is None:
            raise KeyError(doc_id)
        if summary is not None:
            entry["summary"] = " ".join(summary.split())
        if tags is not None:
            entry["tags"] = [t.strip() for t in tags if t.strip()]
        if origin is not None:
            entry["origin"] = origin.strip()
        if description is not None:
            path = layout.context / entry["converted"]
            meta, body = frontmatter.split(read_text(path))
            ocr = body.split("## Extracted text (OCR)", 1)
            ocr_part = (
                "## Extracted text (OCR)" + ocr[1] if len(ocr) == 2 else ""
            )
            new_body = f"## Description\n\n{description.strip()}\n\n{ocr_part}"
            meta["origin"] = entry.get("origin", "")
            atomic_write_text(
                path, frontmatter.join(meta, new_body.strip() + "\n")
            )
            entry["needs_description"] = False
        elif origin is not None and entry.get("converted"):
            path = layout.context / entry["converted"]
            if path.exists():
                meta, body = frontmatter.split(read_text(path))
                meta["origin"] = entry["origin"]
                atomic_write_text(path, frontmatter.join(meta, body))
        save_manifest(layout, manifest)
    write_index(layout)
    return entry


# -- index ------------------------------------------------------------------
def write_index(layout: Layout) -> dict[str, int]:
    documents = load_manifest(layout)["documents"]
    lines = [
        "# Document index",
        "<!-- generated by context-manager from manifest.json: do not edit. "
        "Summaries and tags are set with `ctx.py doc`. -->",
        "",
        "| id | summary | tags | pages | converted |",
        "|---|---|---|---|---|",
    ]
    stats = {"total": 0, "no_summary": 0, "errors": 0, "needs_description": 0}
    for doc_id in sorted(documents):
        entry = documents[doc_id]
        stats["total"] += 1
        if entry.get("status") == "error":
            stats["errors"] += 1
            summary = f"⚠ conversion failed: {entry.get('error', '')}"
        elif entry.get("summary"):
            summary = entry["summary"]
        else:
            stats["no_summary"] += 1
            summary = "_pending summary_"
        if entry.get("needs_description"):
            stats["needs_description"] += 1
        tags = ", ".join(entry.get("tags") or [])
        pages = entry.get("pages") or "—"
        path = f".context/{entry.get('converted', '')}"
        cells = [f"`{doc_id}`", summary, tags, str(pages), f"`{path}`"]
        lines.append(
            "| " + " | ".join(c.replace("|", "\\|") for c in cells) + " |"
        )
    if not documents:
        lines.append(
            "| — | _no documents yet: put files in `.context/raw/`_ | | | |"
        )
    text = "\n".join(lines) + "\n"
    if read_text(layout.index_md) != text:
        atomic_write_text(layout.index_md, text)
    return stats


# -- forget -----------------------------------------------------------------
def forget(layout: Layout, doc_id: str) -> dict[str, Any]:
    """Drop a document: manifest entry, converted Markdown and index row.

    The original in ``raw/`` is left alone (it is the user's file); if it is
    still there, the next scan converts it again.
    """
    with file_lock(_manifest_lock(layout), timeout=30):
        manifest = load_manifest(layout)
        entry = manifest["documents"].pop(doc_id, None)
        if entry is None:
            raise KeyError(doc_id)
        converted = layout.context / entry.get(
            "converted", f"converted/{doc_id}.md"
        )
        converted.unlink(missing_ok=True)
        save_manifest(layout, manifest)
    write_index(layout)
    source = layout.context / entry.get("source", "")
    entry["source_present"] = bool(entry.get("source")) and source.is_file()
    return entry
