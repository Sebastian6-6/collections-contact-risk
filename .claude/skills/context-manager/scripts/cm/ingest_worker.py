"""Docling conversion worker.

Runs inside the shared Docling environment (not the system Python), so it
imports nothing from the skill. Usage::

    python ingest_worker.py job.json result.json

``job.json``: ``{"ocr_langs": [...], "items": [{"id", "src", "out",
"image"}]}``
``result.json``: ``{"docling_version": str, "results": [{"id", "ok", "pages",
"out", "error"}]}``. One failing file never stops the batch.
"""

from __future__ import annotations

import importlib.util
import inspect
import json
import sys
import traceback
from importlib import metadata
from pathlib import Path
from typing import Any

PAGE_MARK = "<!-- page {n} -->"
PER_PAGE_LIMIT = 400  # above this, fall back to one export with page breaks


def _ocr_options(langs: list[str]) -> Any | None:
    """OCR options for ``langs`` across Docling versions (None = defaults)."""
    from docling.datamodel import pipeline_options as po

    if not langs:
        return None
    if hasattr(po, "OcrAutoOptions"):
        # Docling >= 2.1xx: engine-agnostic, takes BCP-47 tags behind "iso:".
        tags = [code if ":" in code else f"iso:{code}" for code in langs]
        return po.OcrAutoOptions(lang=tags)
    if importlib.util.find_spec("easyocr") is not None:
        return po.EasyOcrOptions(lang=[code.split(":")[-1] for code in langs])
    return None


def _converter(langs: list[str]) -> Any:
    from docling.document_converter import DocumentConverter

    try:
        from docling.datamodel.base_models import InputFormat
        from docling.datamodel.pipeline_options import PdfPipelineOptions
        from docling.document_converter import (
            ImageFormatOption,
            PdfFormatOption,
        )
    except ImportError:
        return DocumentConverter()

    options = PdfPipelineOptions()
    options.do_ocr = True
    ocr = _ocr_options(langs)
    if ocr is not None:
        options.ocr_options = ocr
    return DocumentConverter(
        format_options={
            InputFormat.PDF: PdfFormatOption(pipeline_options=options),
            InputFormat.IMAGE: ImageFormatOption(pipeline_options=options),
        }
    )


def _export_kwargs(doc: Any) -> dict[str, Any]:
    params = inspect.signature(doc.export_to_markdown).parameters
    kwargs: dict[str, Any] = {}
    if "image_mode" in params:
        try:
            from docling_core.types.doc import ImageRefMode

            kwargs["image_mode"] = ImageRefMode.PLACEHOLDER
        except ImportError:
            pass
    return kwargs


def _markdown(doc: Any) -> tuple[str, int]:
    pages = doc.num_pages() if hasattr(doc, "num_pages") else 0
    kwargs = _export_kwargs(doc)
    params = inspect.signature(doc.export_to_markdown).parameters
    if pages and pages <= PER_PAGE_LIMIT and "page_no" in params:
        parts = []
        for number in range(1, pages + 1):
            text = doc.export_to_markdown(page_no=number, **kwargs).strip()
            parts.append(
                PAGE_MARK.format(n=number) + ("\n" + text if text else "")
            )
        return "\n\n".join(parts), pages
    if pages and "page_break_placeholder" in params:
        marker = "\n<!-- context-manager-page-break -->\n"
        text = doc.export_to_markdown(page_break_placeholder=marker, **kwargs)
        chunks = text.split(marker)
        body = "\n\n".join(
            PAGE_MARK.format(n=i) + "\n" + chunk.strip()
            for i, chunk in enumerate(chunks, start=1)
        )
        return body, pages
    return doc.export_to_markdown(**kwargs), pages


def main(job_path: str, result_path: str) -> int:
    job = json.loads(Path(job_path).read_text(encoding="utf-8"))
    version = "unknown"
    for package in ("docling", "docling-slim"):
        try:
            version = metadata.version(package)
            break
        except metadata.PackageNotFoundError:
            continue
    langs = job.get("ocr_langs") or ["pt", "en"]
    converters: dict[str, Any] = {}

    def convert(src: str, kind: str) -> Any:
        # "langs" honours the configured OCR languages; "default" lets Docling
        # pick its own engine and model when no engine serves those languages.
        if kind not in converters:
            converters[kind] = _converter(langs if kind == "langs" else [])
        return converters[kind].convert(src).document

    results: list[dict[str, Any]] = []
    for item in job["items"]:
        print(f"converting {item['id']}", flush=True)
        warning = None
        try:
            try:
                doc = convert(item["src"], "langs")
            except Exception:  # noqa: BLE001 - retried with Docling defaults
                traceback.print_exc()
                doc = convert(item["src"], "default")
                warning = "OCR languages not available; Docling defaults used"
            markdown, pages = _markdown(doc)
            Path(item["out"]).write_text(markdown, encoding="utf-8")
            results.append(
                {
                    "id": item["id"],
                    "ok": True,
                    "pages": pages,
                    "out": item["out"],
                    "warning": warning,
                }
            )
        except Exception as error:  # noqa: BLE001 - one bad file only
            traceback.print_exc()
            results.append(
                {
                    "id": item["id"],
                    "ok": False,
                    "error": f"{type(error).__name__}: {error}"[:300],
                }
            )
    Path(result_path).write_text(
        json.dumps({"docling_version": version, "results": results}),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
