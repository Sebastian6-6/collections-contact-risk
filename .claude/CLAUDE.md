<!-- >>> context-manager (managed by the context-manager skill — edits inside are overwritten) >>> -->
@../AGENTS.md

## Context management (context-manager skill)
- Project rules live in `AGENTS.md` (imported above); `.context/PROJECT.md` is memory only (purpose, data sources, decision log). Write confirmed project-wide rules only there, never in PROJECT.md, and only with the user's consent. A rule that applies to one topic stays in that topic's STATE.md `## Decisions` (or a parent's `## Shared decisions`). Precedence: rules file > parent > topic; a narrower rule only refines, never contradicts.
- Project memory lives in `.context/`. Resume a topic with `/c <topic>`; after a long block of work, suggest `/c save`.
- When resuming, load ONLY that topic's `STATE.md` plus `.context/PROJECT.md`, never every topic.
- Never edit `.context/raw/`. Shared files (`PROJECT.md`, `manifest.json`, `map.json`, `index.md`, `MAP.md`) change only through `.claude/skills/context-manager/scripts/ctx.py`; an open topic's own `STATE.md` may be edited directly.
- Check `.context/MAP.md` before opening data files. Files over 2000 lines or 1 MB: read a slice first (Read with a limit, `head`); read fully only when the task needs it.
- Check `.context/index.md` before opening documents; read the converted Markdown in `.context/converted/` by page (`<!-- page N -->` markers), not the originals.
- Inside `.context/` use exact paths from the indexes: search tools may skip hidden or ignored folders.
- Never write credentials, tokens or connection strings into `.context/`.
- Never commit on your own; commits are the user's call.
- Talk to the user in pt-BR; write memory files in English.
<!-- <<< context-manager <<< -->
