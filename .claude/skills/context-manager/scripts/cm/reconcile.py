"""``/c``: bring the repository to the state described by its files.

Order: first-run setup → config → structure → managed files (.gitignore,
CLAUDE.md block, alias, hook) → topics and status moves → documents →
map → pending questions → summary. Skill-owned artefacts are repaired;
user content is only reported.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from . import (
    __version__,
    config,
    docs,
    gitutil,
    integration,
    mapper,
    markdown,
    messages,
    session,
    topics,
)
from .fsutil import read_json, read_text, try_create, write_json
from .paths import Layout
from .report import Report
from .templates import render
from .topics import Discovery, Topic

CTX = "ctx.py"  # SKILL.md explains how to invoke it on this machine


# -- first run --------------------------------------------------------------
def _detect_dbt(root: Path, skip: set[str]) -> list[str]:
    found: list[str] = []
    for current, dirnames, filenames in os.walk(root):
        rel = Path(current).relative_to(root)
        dirnames[:] = [
            d for d in dirnames if not d.startswith(".") and d not in skip
        ]
        if len(rel.parts) >= 3:
            dirnames[:] = []
        if "dbt_project.yml" in filenames:
            found.append((rel / "dbt_project.yml").as_posix())
    return sorted(found)


def _data_sources(root: Path, cfg: dict[str, Any]) -> str:
    dbt = _detect_dbt(root, set(cfg["skip_dirs"]))
    if not dbt:
        return "_TBD_"
    return "\n".join(
        f"- Table docs: dbt project `{path}`; models are documented in its "
        "`schema.yml` files. Point to them, do not duplicate them here."
        for path in dbt
    )


def _detect_rules_file(layout: Layout) -> str:
    """``agents`` when the project already keeps its rules in AGENTS.md."""
    return "agents" if (layout.root / "AGENTS.md").is_file() else "claude"


def _plan(layout: Layout, cfg: dict[str, Any]) -> Report:
    report = Report(
        title=f"context-manager · primeira execução em {layout.root.name}"
    )
    report.extend(
        "next",
        [
            "Vou criar `.context/` (config, PROJECT.md, mapa, índice, "
            "topics/, archive/, raw/)",
            f"Bloco no `.gitignore` (perfil '{cfg['git_profile']}': "
            f"{integration.GITIGNORE_LABEL[cfg['git_profile']]})",
            "Bloco de regras em `.claude/CLAUDE.md`",
            (
                "Regras do projeto no `AGENTS.md` que já existe (importado "
                "pelo `.claude/CLAUDE.md` com `@../AGENTS.md`; a skill nunca "
                "escreve nele); `PROJECT.md` fica só como memória"
                if _detect_rules_file(layout) == "agents"
                else "Regras do projeto no `.claude/CLAUDE.md`, fora do "
                "bloco da skill; `PROJECT.md` fica só como memória"
            ),
            f"Atalho `/{cfg['alias']}` em `.claude/skills/{cfg['alias']}/`",
            "Hook de status no início de cada sessão "
            "(`.claude/settings.json`)",
        ],
    )
    if cfg["modules"]["ingest"] and docs.docling_version() is None:
        report.add(
            "next",
            "Instalar o Docling uma vez neste computador "
            "(~1 GB, alguns minutos) em ~/.context-manager/venv",
        )
    if not gitutil.is_repo(layout.root):
        report.add(
            "warnings",
            "esta pasta não é um repositório git: tudo funciona, "
            "mas archive não preserva histórico e o save não sugere escopo",
        )
    report.todo(
        "First run in this folder. Show this plan to the user in their "
        "language and "
        "ask for ONE confirmation (if a different rules file is wanted, "
        "the user can change `rules_file` in config.json afterwards). "
        "If they agree, run "
        f"`{CTX} run --confirm-init --session <session>`. Create nothing "
        "before that."
    )
    return report


def _init(layout: Layout, cfg: dict[str, Any]) -> None:
    cfg["rules_file"] = _detect_rules_file(layout)
    for folder in (
        layout.raw,
        layout.converted,
        layout.topics,
        layout.archive,
        layout.locks,
    ):
        folder.mkdir(parents=True, exist_ok=True)
    write_json(layout.config, cfg)


# -- structure --------------------------------------------------------------
def _ensure_structure(
    layout: Layout, cfg: dict[str, Any], report: Report, quiet: bool
) -> None:
    for folder in (
        layout.raw,
        layout.converted,
        layout.topics,
        layout.archive,
        layout.locks,
    ):
        if not folder.is_dir():
            folder.mkdir(parents=True, exist_ok=True)
            if not quiet and folder != layout.locks:
                report.add("fixed", f"pasta recriada: {layout.rel(folder)}/")
    created = try_create(
        layout.project_md,
        render(
            "PROJECT.md",
            project=layout.root.name,
            rules=session.rules_pointer(cfg),
            data_sources=_data_sources(layout.root, cfg),
        ),
    )
    if created and not quiet:
        report.add(
            "fixed", "PROJECT.md não existia: recriado a partir do modelo"
        )
    if not layout.manifest.exists():
        write_json(layout.manifest, {"version": 1, "documents": {}})
    if not layout.map_json.exists():
        write_json(layout.map_json, {"folders": {}})


def _rules(layout: Layout, cfg: dict[str, Any], report: Report) -> None:
    """Keep PROJECT.md pointing at the rules file; report what needs a human.

    The rules file itself is user content: it is never written here.
    """
    if session.ensure_rules_pointer(layout, cfg):
        report.add(
            "fixed",
            f"PROJECT.md: seção Rules aponta para `{config.rules_path(cfg)}`",
        )
    agents_md = layout.root / "AGENTS.md"
    if cfg["rules_file"] == "agents" and not agents_md.is_file():
        report.add(
            "warnings",
            "rules_file é 'agents', mas não há AGENTS.md na raiz",
        )
    legacy = markdown.get_section(read_text(layout.project_md), "Conventions")
    if session.has_content(legacy):
        report.add(
            "warnings",
            "PROJECT.md ainda tem `## Conventions`: regras agora ficam em "
            f"`{config.rules_path(cfg)}`",
        )
        report.todo(
            "PROJECT.md has a legacy `## Conventions` section. Show it to the "
            "user and, only with their consent, merge those rules by hand into "
            f"`{config.rules_path(cfg)}` (outside any managed block, without "
            "touching rules already there); then run "
            f"`{CTX} project Conventions --drop`."
        )


def _sync_config(layout: Layout, cfg: dict[str, Any], report: Report) -> None:
    on_disk = read_json(layout.config, default={}) or {}
    if (
        "rules_file" not in on_disk
        and on_disk
        and _detect_rules_file(layout) == "agents"
    ):
        report.todo(
            "This project has an AGENTS.md but config.json predates "
            "`rules_file` (now 'claude'). Ask the user whether project rules "
            'should live in AGENTS.md; if yes set `"rules_file": "agents"` in '
            f".context/config.json and run `{CTX} run`."
        )
    if cfg.get("skill_version") != __version__:
        report.add(
            "fixed", f"config atualizado para a versão {__version__} da skill"
        )
        cfg["skill_version"] = __version__
    if json.dumps(on_disk, sort_keys=True) != json.dumps(cfg, sort_keys=True):
        config.save(layout, cfg)


# -- topics -----------------------------------------------------------------
def _unique(path: Path) -> Path:
    candidate, n = path, 2
    while candidate.exists():
        candidate, n = path.with_name(f"{path.name}-{n}"), n + 1
    return candidate


def apply_statuses(
    layout: Layout,
    found: Discovery,
    report: Report,
    force: set[str] | None = None,
) -> bool:
    """Move folders whose ``status`` changed; True if anything moved."""
    force = force or set()
    moved = False
    for topic in list(found.topics.values()):
        if topic.archived:
            if topic.parent is None and topic.status != "archived":
                dest = layout.topics / topic.name
                if dest.exists():
                    report.add(
                        "warnings",
                        f"não reabri '{topic.name}': já existe "
                        f"{layout.rel(dest)}/",
                    )
                    continue
                gitutil.move(layout.root, topic.path, dest)
                report.add(
                    "fixed", f"reaberto: {topic.name} (voltou para topics/)"
                )
                moved = True
            elif topic.parent and topic.status == "active":
                parent = found.topics.get(
                    f"{topic.parent} (archive)"
                ) or found.topics.get(topic.parent)
                if parent and parent.archived and parent.status == "archived":
                    report.add(
                        "warnings",
                        f"'{topic.name}' está ativo dentro de um "
                        f"tópico arquivado: reabra '{topic.parent}'",
                    )
            continue
        if topic.status == "archived":
            moved |= _archive(
                layout, found, topic, report, topic.name in force
            )
        elif topic.status == "completed" and topic.parent is None:
            open_kids = [
                c.name
                for c in topics.children(found, topic.name)
                if c.status == "active"
            ]
            if open_kids:
                report.add(
                    "warnings",
                    f"'{topic.name}' concluído com subtópicos "
                    f"ativos: {', '.join(open_kids)}",
                )
    return moved


def _archive(
    layout: Layout, found: Discovery, topic: Topic, report: Report, force: bool
) -> bool:
    if topic.parent:
        report.add(
            "warnings",
            f"'{topic.name}': subtópicos são arquivados junto com "
            f"o tópico-pai '{topic.parent}'; nada foi movido",
        )
        return False
    open_kids = [
        c.name
        for c in topics.children(found, topic.name)
        if c.status == "active"
    ]
    if open_kids:
        report.add(
            "warnings",
            f"arquivamento de '{topic.name}' pausado: subtópicos "
            f"ativos ({', '.join(open_kids)})",
        )
        return False
    refs = topics.references(layout, topic)
    if refs and not force:
        report.add(
            "warnings",
            f"arquivamento de '{topic.name}' pausado: referenciado "
            f"em {', '.join(refs)}",
        )
        report.todo(
            f"Ask the user whether to archive '{topic.name}' anyway (it is "
            f"referenced in {', '.join(refs)}). If yes, run "
            f"`{CTX} archive {topic.name} --force`."
        )
        return False
    dest = _unique(layout.archive / topic.name)
    gitutil.move(layout.root, topic.path, dest)
    report.add("fixed", f"arquivado: {topic.name} → {layout.rel(dest)}/")
    return True


def _topics(
    layout: Layout,
    cfg: dict[str, Any],
    report: Report,
    force: set[str] | None = None,
) -> Discovery:
    history = cfg["modules"]["history"]
    found = topics.discover(layout, history=history)
    for name in found.created:
        report.add("fixed", f"tópico novo detectado: {name} (STATE.md criado)")
        report.todo(
            f"New topic '{name}': ask the user in one line what its goal is "
            f"(skip if obvious from the conversation) and write it under "
            f"`## Goal` in its STATE.md."
        )
    report.extend("warnings", found.invalid)
    if apply_statuses(layout, found, report, force):
        found = topics.discover(layout, history=history, materialize=False)
    known = sorted({t.name for t in found.topics.values()})
    if known != cfg.get("known_topics"):
        config.update(layout, lambda c: c.__setitem__("known_topics", known))
        cfg["known_topics"] = known
    return found


# -- documents --------------------------------------------------------------
def _documents(layout: Layout, cfg: dict[str, Any], report: Report) -> str:
    scan = docs.scan(layout)
    stats = docs.write_index(layout)
    report.extend(
        "warnings", [f"formato não suportado: {u}" for u in scan.unsupported]
    )
    if not cfg["modules"]["ingest"]:
        if scan.todo:
            report.add(
                "status",
                f"ingest desligado · {len(scan.todo)} arquivo(s) em "
                "raw/ sem conversão",
            )
        return f"{stats['total']} convertidos (ingest desligado)"
    version = docs.docling_version()
    pending = len(scan.todo)
    if version is None:
        report.add(
            "status", "Docling ainda não está instalado neste computador"
        )
        report.todo(
            "Docling is not installed on this machine. Tell the user it is "
            "being installed once (several minutes), then run "
            f"`{CTX} install-docling` with a 600000 ms timeout (or in the "
            "background), then continue with the next item."
        )
    if pending:
        report.todo(
            f"{pending} document(s) to convert. Run `{CTX} ingest` with a "
            "600000 ms timeout; for more than 20 files run it in the "
            "background and tell the user you will report when it ends."
        )
    if stats["no_summary"]:
        report.todo(
            "Documents without summary in .context/index.md: for each, read "
            "only the first ~150 lines of its converted file and run "
            f'`{CTX} doc <id> --summary "<one English sentence>" --tags '
            '"a,b,c"`.'
        )
    if stats["needs_description"]:
        report.todo(
            "Images with little or no text are flagged in "
            ".context/manifest.json (needs_description). View each original "
            "in .context/raw/ and run `"
            f"{CTX} doc <id> --description-file <tmp.md>` with a short "
            "English description of what it shows."
        )
    missing = len(scan.missing_source)
    extra = (
        f" · {missing} original(is) ausente(s) neste computador"
        if missing
        else ""
    )
    pend = f" · {pending} pendente(s)" if pending else ""
    return f"{stats['total']} convertido(s){pend}{extra}"


# -- main -------------------------------------------------------------------
def run(
    layout: Layout,
    *,
    confirm_init: bool = False,
    force: set[str] | None = None,
) -> Report:
    first = not layout.config.exists()
    if first:
        cfg, _ = config.load(layout)
        if not confirm_init:
            return _plan(layout, cfg)
        _init(layout, cfg)

    cfg, problems = config.load(layout)
    report = Report(title=f"context-manager · {layout.root.name}")
    report.extend("warnings", [f"config: {p}" for p in problems])
    _ensure_structure(layout, cfg, report, quiet=first)
    _sync_config(layout, cfg, report)
    _rules(layout, cfg, report)

    fixed: list[str] = []
    changes, opted_out = integration.ensure_gitignore(layout, cfg)
    fixed += changes
    if changes and cfg["applied"]["gitignore"]:
        config.update(
            layout, lambda c: c["applied"].__setitem__("gitignore", True)
        )
    fixed += integration.ensure_claude_block(layout, cfg)
    alias_changes, collision = integration.ensure_alias(layout, cfg["alias"])
    fixed += alias_changes
    if collision:
        report.add("warnings", collision)
    hook_changes, hook_error = integration.ensure_hook(
        layout, cfg["modules"]["status_hook"]
    )
    fixed += hook_changes
    if hook_error:
        report.add("warnings", hook_error)
    if first:
        report.add(
            "done",
            ".context/ criado (config, PROJECT.md, índice, mapa, "
            "topics/, archive/, raw/)",
        )
    report.extend("done" if first else "fixed", fixed)

    is_repo = gitutil.is_repo(layout.root)
    if is_repo and not opted_out:
        tracked = gitutil.tracked_ignored(layout.root, ".context")
        if tracked:
            report.add(
                "warnings",
                f"{len(tracked)} arquivo(s) de .context/ continuam "
                "no git apesar do .gitignore",
            )
            report.todo(
                "Tell the user these files are still tracked and suggest "
                "(do not run) `git rm -r --cached .context/raw .context/local`"
                f": {', '.join(tracked[:5])}"
            )

    found = _topics(layout, cfg, report, force)
    docs_line = _documents(layout, cfg, report)

    if cfg["modules"]["map"]:
        stats = mapper.build(layout, cfg)
        map_line = f"{stats['folders']} pastas · {stats['files']:,} arquivos"
        if stats["missing"]:
            shown = ", ".join(stats["missing"][:10])
            report.todo(
                "Folders without a purpose in .context/MAP.md: "
                f"{shown}. Infer a short English purpose from the folder and "
                "file names only (do not open files) and set each with "
                f'`{CTX} describe <folder> "<purpose>"`.'
            )
    else:
        map_line = "desligado"

    for topic in found.topics.values():
        if topic.status != "archived":
            report.extend(
                "questions",
                [f"[{topic.name}] {q}" for q in topics.pending(topic)],
            )
    log = markdown.list_items(
        markdown.get_section(read_text(layout.project_md), "Decision log")
    )
    if len(log) > 60:
        report.add(
            "next",
            f"o log de decisões tem {len(log)} entradas: considere "
            f"/{cfg['alias']} tidy",
        )

    _summary(
        report,
        cfg=cfg,
        found=found,
        docs_line=docs_line,
        map_line=map_line,
        is_repo=is_repo,
    )
    if first:
        report.add("done", "context-manager instalado e configurado")
        report.todo(
            "PROJECT.md `## Purpose` is still TBD: infer it from the README "
            "if there is one, otherwise ask the user in one line; write two "
            "or three English sentences to a temp file and run "
            f"`{CTX} project Purpose --file <tmp.md>`."
        )
        report.block("COMANDOS", messages.commands(cfg))
        report.todo(
            "Show the user the COMANDOS block exactly as printed (it is "
            "already translated), right after the installation summary."
        )
    return report


def _summary(
    report: Report,
    *,
    cfg: dict[str, Any],
    found: Discovery,
    docs_line: str,
    map_line: str,
    is_repo: bool,
) -> None:
    active = [t for t in found.active() if t.parent is None]
    subs = [t for t in found.active() if t.parent]
    names = ", ".join(t.name for t in active) or "nenhum"
    extra = f" (+{len(subs)} subtópico(s))" if subs else ""
    completed = len(
        [t for t in found.by_status("completed") if t.parent is None]
    )
    archived = len(
        [t for t in found.topics.values() if t.archived and t.parent is None]
    )
    report.extend(
        "status",
        [
            f"Tópicos ativos: {names}{extra}",
            f"Concluídos: {completed} · Arquivados: {archived}",
            f"Documentos: {docs_line}",
            f"Mapa: {map_line}",
            f"Módulos: {messages.modules_line(cfg)}",
        ],
    )
    if not is_repo:
        report.add("status", "Git: esta pasta não é um repositório")
    if not active and not subs:
        report.add(
            "next",
            f"crie um tópico: /{cfg['alias']} new <nome> (ou uma pasta "
            "em .context/topics/)",
        )


def hook_line(layout: Layout) -> str:
    """One status line for the SessionStart hook (fast, read-only)."""
    if not layout.config.exists():
        if layout.skill_dir.is_dir():
            return (
                "context-manager is installed but not set up in this project: "
                "run /context-manager to initialize it."
            )
        return ""
    cfg, _ = config.load(layout)
    found = topics.discover(layout, history=False, materialize=False)
    active = [t.name for t in found.active()]
    questions = sum(
        len(topics.pending(t))
        for t in found.topics.values()
        if t.status != "archived"
    )
    fresh = 0
    if layout.topics.is_dir():
        for folder in layout.topics.iterdir():
            if folder.is_dir() and not (folder / "STATE.md").exists():
                fresh += 1
    pending_docs = 0
    if cfg["modules"]["ingest"]:
        cache = read_json(layout.hash_cache, default={}) or {}
        known = {
            d.get("source")
            for d in docs.load_manifest(layout)["documents"].values()
        }
        for path in docs.raw_files(layout):
            rel = path.relative_to(layout.raw).as_posix()
            stat = path.stat()
            hit = cache.get(rel)
            if (
                ("raw/" + rel) not in known
                or not hit
                or hit["size"] != stat.st_size
                or hit["mtime_ns"] != stat.st_mtime_ns
            ):
                pending_docs += 1
    alias = cfg["alias"]
    parts = [
        f"{len(active)} active topic(s)"
        + (f": {', '.join(active[:6])}" if active else "")
    ]
    if questions:
        parts.append(f"{questions} pending question(s)")
    if pending_docs:
        parts.append(f"{pending_docs} document(s) to ingest")
    if fresh:
        parts.append(f"{fresh} new topic folder(s)")
    return (
        f"context-manager: {' · '.join(parts)}. Run /{alias} to sync or "
        f"/{alias} <topic> to resume."
    )
