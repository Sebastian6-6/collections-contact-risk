"""Command-line interface: ``ctx.py <command>``. See SKILL.md for routing."""

from __future__ import annotations

import argparse
import contextlib
import sys
import time
from pathlib import Path

from . import config, docs, mapper, messages, reconcile, session, topics
from .fsutil import LockBusyError, read_text, stamp, try_create
from .paths import Layout, find_root
from .report import Report


def _session(value: str | None) -> str:
    if not value or value.startswith("${"):
        return "unknown"  # the placeholder was not substituted
    return value


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ctx.py", description="context-manager"
    )
    parser.add_argument("--root", help="project root (default: auto-detect)")
    parser.add_argument(
        "--json", action="store_true", help="machine-readable output"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="check, fix and update everything")
    run.add_argument("--confirm-init", action="store_true")
    run.add_argument("--session")
    run.add_argument("--topic", help="also resume this topic")
    run.add_argument("--read-only", action="store_true")
    run.add_argument("--take-over", action="store_true")

    resume = sub.add_parser("resume", help="open a topic")
    resume.add_argument("topic")
    resume.add_argument("--session")
    resume.add_argument("--read-only", action="store_true")
    resume.add_argument("--take-over", action="store_true")

    save = sub.add_parser("save", help="checkpoint")
    save.add_argument("--session")
    save.add_argument("--topic")
    save.add_argument("--finish", action="store_true")

    sub.add_parser("commands", help="list commands")
    sub.add_parser("hook", help="SessionStart status line")
    sub.add_parser("install-docling", help="install Docling once per machine")

    new = sub.add_parser("new", help="create a topic")
    new.add_argument("topic")

    for name in ("complete", "archive", "reopen"):
        cmd = sub.add_parser(name, help=f"{name} a topic")
        cmd.add_argument("topic")
        if name == "archive":
            cmd.add_argument("--force", action="store_true")

    ingest = sub.add_parser(
        "ingest", help="convert documents in .context/raw/"
    )
    ingest.add_argument("--force", nargs="*", default=[], metavar="ID_OR_FILE")

    module = sub.add_parser("module", help="list or toggle modules")
    module.add_argument("name", nargs="?", choices=config.MODULES)
    module.add_argument("state", nargs="?", choices=("on", "off"))

    describe = sub.add_parser(
        "describe", help="set a folder purpose in the map"
    )
    describe.add_argument("folder")
    describe.add_argument("text", nargs="+")

    tidy = sub.add_parser("tidy", help="consolidate the decision log")
    tidy.add_argument("--apply", metavar="FILE")
    tidy.add_argument("--expect")

    project = sub.add_parser("project", help="replace a PROJECT.md section")
    project.add_argument(
        "section", choices=(*session.PROJECT_SECTIONS, session.LEGACY_SECTION)
    )
    project.add_argument("--file")
    project.add_argument(
        "--drop",
        action="store_true",
        help="remove the legacy Conventions section",
    )

    forget = sub.add_parser(
        "forget", help="drop a document from the manifest and index"
    )
    forget.add_argument("id")

    doc = sub.add_parser("doc", help="set document metadata")
    doc.add_argument("id")
    doc.add_argument("--summary")
    doc.add_argument("--tags")
    doc.add_argument("--origin")
    doc.add_argument("--description-file")

    decision = sub.add_parser("decision", help="record a confirmed decision")
    decision.add_argument("topic")
    decision.add_argument(
        "--level", choices=("topic", "parent", "project"), default="topic"
    )
    decision.add_argument("text", nargs="+")

    history = sub.add_parser("history", help="append a history event")
    history.add_argument("topic")
    history.add_argument("kind", choices=("done", "drop", "pivot"))
    history.add_argument("text", nargs="+")
    return parser


def _require_init(layout: Layout) -> Report | None:
    if layout.config.exists():
        return None
    report = Report(title="context-manager")
    report.add(
        "warnings", "o context-manager ainda não foi configurado nesta pasta"
    )
    report.todo(
        "Run `ctx.py run --session <session>` first (it asks for one "
        "confirmation), then retry."
    )
    report.exit_code = 2
    return report


def _status(layout: Layout, cfg: dict, args: argparse.Namespace) -> Report:
    target = {
        "complete": "completed",
        "archive": "archived",
        "reopen": "active",
    }
    topic = topics.find(layout, args.topic, history=cfg["modules"]["history"])
    if topic is None:
        report = Report(title="context-manager")
        report.add("warnings", f"tópico '{args.topic}' não encontrado")
        report.exit_code = 2
        return report
    wanted = target[args.command]
    if (
        args.command == "reopen"
        and not topic.archived
        and topic.status == "active"
    ):
        report = Report(title="context-manager")
        report.add("status", f"'{topic.name}' já está ativo")
        return report
    topics.set_status(topic, wanted)
    force = {topic.name} if getattr(args, "force", False) else set()
    report = reconcile.run(layout, force=force)
    if wanted == "archived":
        still = topics.find(layout, topic.name, history=False)
        if still and not still.archived:
            topics.set_status(still, "completed")
            report.add(
                "warnings",
                f"'{topic.name}' não foi arquivado; status voltou "
                "para completed",
            )
    elif wanted == "completed":
        report.add("done", f"'{topic.name}' marcado como concluído")
        report.todo(
            "If `## Where we stopped` does not yet summarise the final "
            "outcome, "
            "add a one-paragraph final summary there."
        )
    return report


def _ingest(layout: Layout, cfg: dict, force: list[str]) -> Report:
    report = Report(title="context-manager · ingest")
    if not cfg["modules"]["ingest"]:
        report.add(
            "status",
            f"ingest está desligado — ligue com /{cfg['alias']} "
            "module ingest on",
        )
        return report
    lock = layout.locks / "ingest.lock"
    if not try_create(lock, stamp()):
        if time.time() - lock.stat().st_mtime < 6 * 3600:
            report.add(
                "warnings",
                "outra sessão já está convertendo documentos; "
                "espere ela terminar",
            )
            return report
        lock.unlink(missing_ok=True)
        try_create(lock, stamp())
    try:
        result = docs.ingest(layout, cfg, set(force))
    finally:
        lock.unlink(missing_ok=True)
    if result.get("docling_missing"):
        report.add(
            "warnings",
            f"{result['docling_missing']} arquivo(s) precisam do "
            "Docling, que não está instalado neste computador",
        )
        report.todo(
            "Run `ctx.py install-docling` (600000 ms timeout), then "
            "`ctx.py ingest` again."
        )
    if result["converted"]:
        report.add(
            "done",
            f"{len(result['converted'])} documento(s) convertido(s): "
            + ", ".join(result["converted"][:10]),
        )
    report.extend("warnings", [f"falhou: {f}" for f in result["failed"]])
    report.extend("warnings", [f"aviso: {n}" for n in result["notes"]])
    report.extend(
        "warnings", [f"não suportado: {u}" for u in result["unsupported"]]
    )
    if result["large"]:
        report.add(
            "status",
            "grandes (leia por página): " + ", ".join(result["large"]),
        )
    if (
        not result["converted"]
        and not result["failed"]
        and not result.get("docling_missing")
    ):
        report.add("status", "nada novo para converter")
    stats = docs.write_index(layout)
    if stats["no_summary"]:
        report.todo(
            "Documents without summary in .context/index.md: for each, read "
            "only the first ~150 lines of its converted file and run "
            '`ctx.py doc <id> --summary "<one English sentence>" --tags '
            '"a,b,c"`.'
        )
    if result["needs_description"]:
        report.todo(
            "These images have little text: "
            + ", ".join(result["needs_description"])
            + ". View each original in .context/raw/ "
            "and run `ctx.py doc <id> --description-file <tmp.md>` with a "
            "short "
            "English description."
        )
    return report


def _install() -> Report:
    report = Report(title="context-manager · Docling")
    version = docs.docling_version()
    if version:
        report.add(
            "status", f"Docling {version} já instalado neste computador"
        )
        return report
    ok, detail = docs.install_docling()
    if ok:
        report.add(
            "done", f"Docling {detail} instalado (uma vez por computador)"
        )
    else:
        report.add("warnings", f"instalação do Docling {detail}")
        report.exit_code = 1
    return report


def _module(layout: Layout, cfg: dict, args: argparse.Namespace) -> Report:
    if not args.name:
        report = Report(title="context-manager · módulos")
        report.add("status", messages.modules_line(cfg))
        return report
    if not args.state:
        report = Report(title="context-manager · módulos")
        state = "on" if cfg["modules"][args.name] else "off"
        report.add("status", f"{args.name}: {state}")
        return report
    value = args.state == "on"
    config.update(layout, lambda c: c["modules"].__setitem__(args.name, value))
    report = reconcile.run(layout)
    report.add(
        "done", f"módulo {args.name} {'ligado' if value else 'desligado'}"
    )
    return report


def _doc(layout: Layout, args: argparse.Namespace) -> Report:
    report = Report(title="context-manager · documento")
    description = None
    if args.description_file:
        description = read_text(Path(args.description_file))
    tags = args.tags.split(",") if args.tags is not None else None
    try:
        docs.set_meta(
            layout,
            args.id,
            summary=args.summary,
            tags=tags,
            origin=args.origin,
            description=description,
        )
    except KeyError:
        report.add("warnings", f"documento '{args.id}' não está no manifest")
        report.exit_code = 2
        return report
    report.add("done", f"{args.id}: metadados atualizados")
    return report


def dispatch(args: argparse.Namespace) -> Report:
    layout = Layout(find_root(args.root))
    if args.command == "hook":
        report = Report(title="")
        report.block("", reconcile.hook_line(layout))
        return report
    if args.command == "install-docling":
        return _install()
    if args.command == "run":
        report = reconcile.run(layout, confirm_init=args.confirm_init)
        if args.topic and report.exit_code == 0:
            cfg, _ = config.load(layout)
            opened = session.resume(
                layout,
                cfg,
                args.topic,
                _session(args.session),
                read_only=args.read_only,
                take_over=args.take_over,
            )
            # run already listed every pending question with its topic.
            opened.sections.pop("questions", None)
            report.merge(opened)
        return report

    pending_init = _require_init(layout)
    if pending_init:
        return pending_init
    cfg, _ = config.load(layout)
    cmd = args.command

    if cmd == "commands":
        report = Report(title="")
        report.block("COMANDOS", messages.commands(cfg))
        report.todo("Show the COMANDOS block to the user exactly as printed.")
        return report
    if cmd == "resume":
        return session.resume(
            layout,
            cfg,
            args.topic,
            _session(args.session),
            read_only=args.read_only,
            take_over=args.take_over,
        )
    if cmd == "save":
        handler = session.save_finish if args.finish else session.save_prep
        return handler(layout, cfg, _session(args.session), args.topic)
    if cmd == "new":
        report = Report(title="context-manager · novo tópico")
        created = topics.create(
            layout, args.topic, history=cfg["modules"]["history"]
        )
        report.extend(
            "done",
            [f"tópico criado: {n} (.context/topics/{n}/)" for n in created],
        )
        report.todo(
            "Ask the user in one line for the goal of the new topic (unless "
            "already clear) and write it under `## Goal` in its STATE.md; add "
            "`scope:` paths if known."
        )
        return report
    if cmd in ("complete", "archive", "reopen"):
        return _status(layout, cfg, args)
    if cmd == "ingest":
        return _ingest(layout, cfg, args.force)
    if cmd == "module":
        return _module(layout, cfg, args)
    if cmd == "describe":
        report = Report(title="context-manager · mapa")
        folder = mapper.set_purpose(layout, args.folder, " ".join(args.text))
        if cfg["modules"]["map"]:
            mapper.build(layout, cfg)
        report.add("done", f"descrição de '{folder or './'}' salva no mapa")
        return report
    if cmd == "tidy":
        if args.apply:
            if not args.expect:
                raise topics.TopicError("--apply exige --expect <versão>")
            body = read_text(Path(args.apply))
            return session.tidy_apply(layout, body, args.expect)
        return session.tidy_show(layout, cfg)
    if cmd == "doc":
        return _doc(layout, args)
    if cmd == "project":
        if args.section == session.LEGACY_SECTION:
            if not args.drop:
                raise topics.TopicError(
                    "Conventions saiu do PROJECT.md: as regras ficam em "
                    f"{config.rules_path(cfg)}; use --drop para remover a "
                    "seção antiga"
                )
            return session.project_drop_legacy(layout)
        if args.drop or not args.file:
            raise topics.TopicError("use --file <arquivo> com esta seção")
        body = read_text(Path(args.file))
        return session.project_set(layout, args.section, body)
    if cmd == "forget":
        report = Report(title="context-manager · documento")
        try:
            entry = docs.forget(layout, args.id)
        except KeyError:
            report.add("warnings", f"documento '{args.id}' não está no manifest")
            report.exit_code = 2
            return report
        report.add(
            "done",
            f"{args.id}: removido do manifest, do índice e de converted/",
        )
        if entry["source_present"]:
            report.add(
                "warnings",
                f"o original {entry['source']} continua em raw/ e será "
                "convertido de novo no próximo ingest",
            )
        return report
    if cmd in ("decision", "history"):
        topic = topics.find(layout, args.topic, history=False)
        if topic is None:
            raise topics.TopicError(f"tópico '{args.topic}' não encontrado")
        report = Report(title="context-manager")
        text = " ".join(args.text)
        if cmd == "decision":
            where = topics.append_decision(layout, topic, args.level, text)
            report.add("done", f"decisão registrada em {where}")
        else:
            topics.append_history(layout, topic, args.kind, text)
            report.add("done", f"histórico de {topic.name}: {args.kind}")
        return report
    raise AssertionError(cmd)  # pragma: no cover - argparse guards this


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        with contextlib.suppress(AttributeError, ValueError):
            stream.reconfigure(encoding="utf-8", errors="replace")
    args = _parser().parse_args(argv)
    try:
        report = dispatch(args)
    except topics.TopicError as error:
        report = Report(title="context-manager")
        report.add("warnings", str(error))
        report.exit_code = 2
    except LockBusyError as error:
        report = Report(title="context-manager")
        report.add(
            "warnings",
            f"arquivo ocupado por outra sessão ({error}); tente "
            "de novo em instantes",
        )
        report.exit_code = 6
    except Exception as error:
        if args.command == "hook":
            return 0
        raise error
    if args.command == "hook":
        line = report.blocks[0][1] if report.blocks else ""
        if line:
            print(line)
        return 0
    print(report.to_json() if args.json else report.render(), end="")
    return report.exit_code
