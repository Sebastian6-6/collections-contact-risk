"""Working sessions on a topic: resume, save and tidy."""

from __future__ import annotations

import re
from typing import Any

from . import config, gitutil, mapper, markdown, topics
from .fsutil import atomic_write_text, file_lock, read_text, sha256_text, stamp
from .paths import Layout
from .report import Report
from .topics import Topic

CTX = "ctx.py"
_DOC_ID = re.compile(r"^\s*-\s*`?([a-z0-9][a-z0-9-]*)`?")


def _not_found(layout: Layout, name: str, report: Report) -> Report:
    known = (
        sorted(p.name for p in layout.topics.iterdir() if p.is_dir())
        if layout.topics.is_dir()
        else []
    )
    report.add("warnings", f"tópico '{name}' não encontrado")
    if known:
        report.add("status", f"Tópicos existentes: {', '.join(known)}")
    report.todo(
        f"Topic '{name}' does not exist. If it is a typo, retry with the "
        "right "
        f"name; otherwise ask the user whether to create it with "
        f"`{CTX} new {topics.slugify(name)}`."
    )
    report.exit_code = 2
    return report


def _overlaps(a: list[str], b: list[str]) -> list[str]:
    hits = []
    for x in a:
        for y in b:
            bx, by = topics.scope_base(x), topics.scope_base(y)
            if bx and by and (bx.startswith(by) or by.startswith(bx)):
                hits.append(x)
                break
    return hits


def _docs_in_use(layout: Layout, topic: Topic) -> list[str]:
    section = markdown.get_section(topic.body, "Documents in use")
    ids = {
        m.group(1)
        for line in section.splitlines()
        if (m := _DOC_ID.match(line))
    }
    if not ids:
        return []
    return [
        line
        for line in read_text(layout.index_md).splitlines()
        if any(line.startswith(f"| `{i}` |") for i in ids)
    ]


def resume(
    layout: Layout,
    cfg: dict[str, Any],
    name: str,
    session: str,
    *,
    read_only: bool = False,
    take_over: bool = False,
) -> Report:
    report = Report(title=f"context-manager · tópico {name}")
    topic = topics.find(layout, name, history=cfg["modules"]["history"])
    if topic is None:
        return _not_found(layout, name, report)
    read_only = read_only or topic.archived
    project = read_text(layout.project_md)
    ttl = float(cfg["lock_ttl_hours"])

    if not read_only:
        holder = topics.acquire(
            layout,
            topic,
            session,
            ttl,
            take_over=take_over,
            project_sha=sha256_text(project),
        )
        if holder:
            since = holder.get("started", "?")[11:16]
            report.add(
                "warnings",
                f"'{topic.name}' já está aberto em outra sessão desde {since}",
            )
            report.todo(
                "Ask the user: open read-only, or take over the other "
                "session? "
                f"Then rerun `{CTX} resume {topic.name} --session <session>` "
                "with `--read-only` or `--take-over`."
            )
            return report

    others = {
        n: i
        for n, i in topics.all_locks(layout, ttl).items()
        if n != topic.name and i.get("session") != session
    }
    for other_name, _info in others.items():
        other = topics.find(layout, other_name, history=False)
        if other and (shared := _overlaps(topic.scope, other.scope)):
            report.add(
                "warnings",
                f"'{other_name}' está aberto em outra sessão e "
                f"mexe no mesmo escopo: {', '.join(shared)}",
            )

    mode = "somente leitura" if read_only else "aberto nesta sessão"
    status = "arquivado" if topic.archived else topic.status
    report.add("status", f"{topic.name}: {status} · {mode}")
    report.extend("questions", topics.pending(topic))

    report.block("PROJECT (.context/PROJECT.md)", project or "(empty)")
    if topic.parent:
        parent = topics.find(layout, topic.parent, history=False)
        if parent:
            goal = markdown.get_section(parent.body, "Goal")
            shared = markdown.get_section(parent.body, "Shared decisions")
            report.block(
                f"PARENT {topic.parent} (goal and shared decisions)",
                f"## Goal\n{goal}\n\n## Shared decisions\n{shared or '—'}",
            )
    report.block(f"STATE ({layout.rel(topic.state_file)})", topic.text())
    if topic.parent is None:
        found = topics.discover(layout, history=False, materialize=False)
        kids = topics.children(found, topic.name)
        if kids:
            report.block(
                "SUBTOPICS",
                "\n".join(
                    f"- {k.name}: {'archived' if k.archived else k.status}"
                    for k in kids
                ),
            )
    if cfg["modules"]["map"]:
        rows = mapper.rows_in_scope(layout, topic.scope)
        if rows:
            report.block(
                "MAP (rows inside this topic's scope)",
                "| Folder | Purpose | Contents |\n|---|---|---|\n"
                + "\n".join(rows),
            )
    in_use = _docs_in_use(layout, topic)
    if in_use:
        report.block(
            "DOCUMENTS IN USE (from .context/index.md)", "\n".join(in_use)
        )

    report.todo(
        f"Give the user a short summary in {cfg['language']['output']}: "
        "goal, where we stopped, "
        "the next 1–3 plan items and any pending questions. Then carry "
        "on with the work."
    )
    if not read_only:
        report.todo(
            f"While working, edit {layout.rel(topic.state_file)} directly; "
            "record shared decisions only through "
            f"`{CTX} decision`. Read documents and data following the "
            "reading rules in CLAUDE.md."
        )
    else:
        report.todo(
            "This topic is read-only in this session: do not edit its files."
        )
    return report


# -- save -------------------------------------------------------------------
def _session_topics(
    layout: Layout, cfg: dict[str, Any], session: str, name: str | None
) -> list[str]:
    if name:
        return [name.strip("/")]
    locks = topics.all_locks(layout, float(cfg["lock_ttl_hours"]))
    return sorted(
        n for n, info in locks.items() if info.get("session") == session
    )


def save_prep(
    layout: Layout, cfg: dict[str, Any], session: str, name: str | None
) -> Report:
    report = Report(title="context-manager · save")
    names = _session_topics(layout, cfg, session, name)
    if not names:
        report.add("status", "nenhum tópico aberto nesta sessão")
        report.todo(
            "If you worked on a topic in this conversation, rerun with "
            "`--topic <name>`; otherwise tell the user there is nothing to "
            "save."
        )
        return report
    ttl = float(cfg["lock_ttl_hours"])
    changed = [
        f
        for f in gitutil.changed_files(layout.root)
        if not f.startswith((".context/", ".claude/"))
        and f not in (".gitignore", "CLAUDE.md")
    ]
    project = read_text(layout.project_md)
    for topic_name in names:
        topic = topics.find(layout, topic_name, history=False)
        if topic is None:
            _not_found(layout, topic_name, report)
            continue
        info = topics.read_lock(layout, topic_name, ttl) or {}
        outside = [f for f in changed if not topics.in_scope(topic, f)][:20]
        lines = [f"STATE: {layout.rel(topic.state_file)}"]
        if outside:
            lines.append(
                "Changed files outside scope (git): " + ", ".join(outside)
            )
        if info.get("project_sha") and info["project_sha"] != sha256_text(
            project
        ):
            lines.append(
                "PROJECT.md changed since this topic was opened; re-read its "
                "Decision log before recording decisions."
            )
        if info.get("goal_sha") and info["goal_sha"] != topics.goal_hash(
            topic
        ):
            lines.append("GOAL CHANGED since the topic was opened (pivot).")
        report.block(f"SAVE {topic_name}", "\n".join(lines))

    report.todo(
        "For each topic above, update its STATE.md: `## Where we stopped` "
        "(2–5 bullets), `## Plan` (mark [x] done, [~] dropped + ' — reason', "
        "add new items), `## Documents in use`, and `scope:` (add listed "
        "paths "
        "only if they clearly belong to the topic). Keep it short."
    )
    report.todo(
        "Do not wait for answers. Anything that needs the user (standards, "
        "conventions, doubtful choices) goes as `- [?] question (context, "
        "date)` under `## Pending` of the lowest level where it came up, and "
        "is listed in your reply. Never record those as decisions."
    )
    report.todo(
        "Only for decisions the user explicitly confirmed: "
        f'`{CTX} decision <topic> --level topic|parent|project "..."`.'
    )
    if cfg["modules"]["history"]:
        report.todo(
            "If GOAL CHANGED is shown: "
            f'`{CTX} history <topic> pivot "old → new — reason"` (unknown '
            "reason: write 'reason not recorded' and add a pending question)."
        )
    report.todo(
        f"Finish with `{CTX} save --finish --session <session>"
        + (f" --topic {name}" if name else "")
        + "`."
    )
    return report


def save_finish(
    layout: Layout, cfg: dict[str, Any], session: str, name: str | None
) -> Report:
    report = Report(title="context-manager · save")
    names = _session_topics(layout, cfg, session, name)
    history = cfg["modules"]["history"]
    questions = 0
    for topic_name in names:
        topic = topics.find(layout, topic_name, history=False)
        if topic is None:
            report.add("warnings", f"tópico '{topic_name}' não encontrado")
            continue
        if topic.archived:
            report.add(
                "warnings", f"'{topic_name}' está arquivado: nada salvo"
            )
            continue
        raw_status = str(topic.meta.get("status", "active")).strip().lower()
        if raw_status not in topics.STATUSES:
            report.add(
                "warnings",
                f"{topic_name}: status '{raw_status}' inválido → "
                "mantido como active",
            )
            topic.meta["status"] = "active"
        moved = topics.harvest_plan(topic) if history else []
        topic.meta["updated"] = stamp()
        topic.save()
        for kind, text in moved:
            topics.append_history(layout, topic, kind, text)
        topics.release(layout, topic_name)
        questions += len(topics.pending(topic))
        detail = (
            f" · {len(moved)} item(ns) do plano → HISTORY.md" if moved else ""
        )
        report.add(
            "done", f"{topic_name}: STATE.md salvo{detail} · lock liberado"
        )
    if not names:
        report.add("status", "nenhum tópico aberto nesta sessão")
    if questions:
        report.add(
            "questions",
            f"{questions} pergunta(s) registrada(s) em Pending: "
            "responda quando puder; nada foi assumido como padrão",
        )

    if gitutil.is_repo(layout.root):
        if cfg["save_commit"]:
            ok, detail = gitutil.commit_paths(
                layout.root,
                ".context",
                "context: save " + (", ".join(names) or "project"),
            )
            if ok:
                report.add(
                    "done",
                    "commit do .context/ feito (só .context/, sem push)"
                    if detail == "committed"
                    else "nada novo para commitar",
                )
            else:
                report.add("warnings", f"commit do .context/ falhou: {detail}")
        elif gitutil.has_changes(layout.root, ".context"):
            report.add(
                "next",
                "contexto não commitado (save_commit: false): faça "
                "commit e push para continuar em outro computador",
            )
    report.todo(
        f"Reply in {cfg['language']['output']} with this summary and the "
        "pending questions, briefly. "
        "Do not ask the user to answer now."
    )
    return report


# -- tidy -------------------------------------------------------------------
def tidy_show(layout: Layout, cfg: dict[str, Any]) -> Report:
    report = Report(title="context-manager · tidy")
    text = read_text(layout.project_md)
    section = markdown.get_section(text, "Decision log")
    report.block("DECISION LOG", section or "(empty)")
    report.add("status", f"versão do log: {sha256_text(section)[:12]}")
    report.todo(
        "Propose a consolidated Decision log to the user (merge duplicates, "
        "keep the newest when entries conflict, keep dates and [topic] tags, "
        "durable rules belong in the rules file "
        f"`{config.rules_path(cfg)}`: move them there by hand, outside any "
        "managed block, only if the user agrees; never into PROJECT.md). "
        "After the user confirms, write the new section body to a temporary "
        f"file and run `{CTX} tidy --apply <file> --expect "
        f"{sha256_text(section)[:12]}`."
    )
    return report


def tidy_apply(layout: Layout, body: str, expect: str) -> Report:
    report = Report(title="context-manager · tidy")
    lock = (
        layout.locks
        / f"write-{sha256_text(layout.rel(layout.project_md))[:16]}.lock"
    )
    with file_lock(lock):
        text = read_text(layout.project_md)
        current = sha256_text(markdown.get_section(text, "Decision log"))[:12]
        if current != expect:
            report.add(
                "warnings",
                "o log mudou desde que foi lido (outra sessão "
                "registrou decisões); nada foi alterado",
            )
            report.todo(f"Run `{CTX} tidy` again and redo the proposal.")
            return report
        old = markdown.get_section(text, "Decision log")
        note = old.split("\n", 1)[0] if old.startswith("<!--") else ""
        if note and not body.lstrip().startswith("<!--"):
            body = f"{note}\n{body.strip()}"
        atomic_write_text(
            layout.project_md,
            markdown.replace_section(text, "Decision log", body),
        )
    report.add("done", "log de decisões consolidado")
    return report


PROJECT_SECTIONS = ("Purpose", "Data sources")
# Rules moved out of PROJECT.md in 1.1.0; kept only so it can be dropped.
LEGACY_SECTION = "Conventions"
RULES_SECTION = "Rules"


def _project_lock(layout: Layout):
    lock_name = sha256_text(layout.rel(layout.project_md))[:16]
    return file_lock(layout.locks / f"write-{lock_name}.lock")


def has_content(section: str) -> bool:
    """True when a section holds more than HTML comments and whitespace."""
    return bool(re.sub(r"<!--.*?-->", "", section, flags=re.S).strip())


def rules_pointer(cfg: dict[str, Any]) -> str:
    """Body of PROJECT.md's skill-owned ``## Rules`` section."""
    return (
        "<!-- generated by context-manager from config.json rules_file -->\n"
        f"Project rules live in `{config.rules_path(cfg)}` (single source of "
        "truth). This file is memory only: purpose, data sources and the "
        "decision log."
    )


def ensure_rules_pointer(layout: Layout, cfg: dict[str, Any]) -> bool:
    """Create or refresh the ``## Rules`` pointer; True if PROJECT.md changed."""
    if not layout.project_md.exists():
        return False
    wanted = rules_pointer(cfg)
    with _project_lock(layout):
        text = read_text(layout.project_md)
        current = markdown.get_section(text, RULES_SECTION)
        if current == wanted:
            return False
        if markdown.section_span(text, RULES_SECTION) is None:
            new = markdown.insert_section_before(
                text, RULES_SECTION, wanted, before="Data sources"
            )
        else:
            new = markdown.replace_section(text, RULES_SECTION, wanted)
        atomic_write_text(layout.project_md, new)
    return True


def project_drop_legacy(layout: Layout) -> Report:
    """Remove the legacy ``## Conventions`` section after its rules moved."""
    report = Report(title="context-manager · PROJECT.md")
    with _project_lock(layout):
        text = read_text(layout.project_md)
        if markdown.section_span(text, LEGACY_SECTION) is None:
            report.add("status", "PROJECT.md não tem `## Conventions`")
            return report
        atomic_write_text(
            layout.project_md, markdown.remove_section(text, LEGACY_SECTION)
        )
    report.add("done", "PROJECT.md: seção 'Conventions' removida")
    return report


def project_set(layout: Layout, section: str, body: str) -> Report:
    """Replace one user-facing section of PROJECT.md under its write lock."""
    report = Report(title="context-manager · PROJECT.md")
    with _project_lock(layout):
        text = read_text(layout.project_md)
        old = markdown.get_section(text, section)
        note = old.split("\n", 1)[0] if old.startswith("<!--") else ""
        if note and not body.lstrip().startswith("<!--"):
            body = f"{note}\n{body.strip()}"
        atomic_write_text(
            layout.project_md, markdown.replace_section(text, section, body)
        )
    report.add("done", f"PROJECT.md: seção '{section}' atualizada")
    return report
