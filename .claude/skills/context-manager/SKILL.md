---
name: context-manager
description: Persistent, token-efficient project memory for this repository. Converts PDFs, Word, PowerPoint, Excel and images into indexed Markdown with Docling, keeps one memory file per topic plus a shared PROJECT.md and a repository map, and resumes work exactly where it stopped. Use it for /context-manager or /c, and whenever the user wants to resume, continue or save progress on a topic or task, asks where they stopped, wants documents ingested or prepared for AI use, asks what is inside the repository folders, or mentions topics, project memory, STATE.md, PROJECT.md or the .context folder, even if they never name the skill.
allowed-tools: Bash(python3 .claude/skills/context-manager/scripts/ctx.py *), Bash(python .claude/skills/context-manager/scripts/ctx.py *), Bash(py -3 .claude/skills/context-manager/scripts/ctx.py *)
metadata:
  version: 1.0.0
---

# context-manager

Gives this repository a memory that survives sessions and machines while keeping
token use low: originals are converted once, indexed, and read by page; each topic
has a short `STATE.md`; nothing is loaded that the current task does not need.

Arguments for this invocation: $ARGUMENTS

## Talking to the user

Reply in the language in `.context/config.json` → `language.output` (default
pt-BR). Write every memory file (STATE, HISTORY, PROJECT, summaries, map purposes)
in English: they are read by models, and English instructions are followed more
reliably and cost fewer tokens. Converted documents keep their original language.

## Running the CLI

Everything deterministic is done by one script, from the project root:

```
python3 .claude/skills/context-manager/scripts/ctx.py <command> [options]
```

- If `python3` is missing or opens the Microsoft Store (Windows), use `python`,
  then `py -3`, and keep using the one that works. In this file, `ctx.py` means
  that full command.
- Pass `--session ${CLAUDE_SESSION_ID}` to `run`, `resume` and `save`: topic
  locks are tied to the session.
- Output has two parts. The report (written in pt-BR; translate it if the output
  language differs) is for the user: relay it concisely, keeping its facts,
  without dumping it raw. `===== BLOCK =====` sections are
  context for you. The `[claude] TODO` list is for you: do every item, in order,
  before your final reply. Some items are long-running (Docling install, large
  ingests): use a 600000 ms timeout or run them in the background as the item says.

## Routing

Read the reference file for a row before acting on it the first time in a session.

| Arguments | Run | Reference |
|---|---|---|
| *(none)* | `ctx.py run --session …` | `references/setup.md` on first run |
| `<topic>` | `ctx.py run --topic <topic> --session …` | `references/topics.md` |
| `save` | save protocol | `references/save.md` |
| `commands` | `ctx.py commands`; show the COMANDOS block as printed | — |
| `new <topic>` / `new <topic>/<sub>` | `ctx.py new …` | `references/topics.md` |
| `complete` · `archive` · `reopen` `<topic>` | `ctx.py <verb> <topic>` | `references/topics.md` |
| `ingest [--force x]` | `ctx.py ingest …` | `references/documents.md` |
| `forget <doc-id>` | `ctx.py forget <doc-id>` | `references/documents.md` |
| `module [name on\|off]` | `ctx.py module …` | `references/setup.md` |
| `describe <folder> <text>` | `ctx.py describe <folder> "<English text>"` | `references/documents.md` |
| `tidy` | tidy protocol | `references/save.md` |

Any first argument that is not a command is a topic name. Plain-language requests
map to the closest row ("arquiva o churn" → `archive churn…`; "onde parei no
dim-customer?" → `<topic>`). When unsure which topic is meant, run `ctx.py run`
and ask, offering the active topics it lists.

## Rules that always apply

- **Load little, on purpose.** Resume loads one topic's `STATE.md` and
  `PROJECT.md`, never every topic. Consult `.context/MAP.md` before opening data
  files and `.context/index.md` before opening documents; read converted Markdown
  by page (`<!-- page N -->`) instead of whole files or originals. Large files
  (thresholds in `config.json`): read a slice first, the whole file only when the
  task truly needs it. This is the point of the skill: tokens go to the task.
- **Rules and memory are separate.** Normative project rules (conventions,
  architecture rules, standards) live in one rules file: `.claude/CLAUDE.md`
  outside the managed block, or root `AGENTS.md` when `config.json` →
  `rules_file` is `agents` (the managed block then imports it with
  `@../AGENTS.md`). `PROJECT.md` is memory only: purpose, data sources, decision
  log. The scripts never write the rules file; you edit it by hand, only with
  the user's consent, never inside a managed block, never rewriting rules the
  user or a third party wrote. Only project-wide rules go there: a rule for one
  topic or phase stays in that topic's `## Decisions` (or the parent's
  `## Shared decisions`). Precedence: rules file > parent > topic; a narrower
  rule may refine a broader one, never contradict it.
- **Shared files go through the script.** `PROJECT.md`, `manifest.json`,
  `map.json`, `index.md` and `MAP.md` are written only by `ctx.py` (it locks and
  writes atomically, so parallel sessions never lose lines): PROJECT.md sections
  with `ctx.py project <Purpose|"Data sources"> --file <tmp.md>`,
  decisions with `ctx.py decision`. Modules change with `ctx.py module`; other
  `config.json` keys only when the user asks, followed by `ctx.py run`. The open
  topic's own `STATE.md` you may edit directly. Never touch `.context/raw/`. The
  user may edit any file by hand; `ctx.py run` reconciles.
- **Never assume a standard.** Doubts about conventions or choices become
  `- [?]` pending questions at the lowest level where they arose; only decisions
  the user confirmed are recorded with `ctx.py decision`, and a confirmed rule
  that must hold from now on is also written in the rules file.
- **Paths inside `.context/`**: use the exact paths from indexes and reports;
  search tools may skip hidden or git-ignored folders.
- **No secrets, no commits.** Never write credentials or connection strings into
  `.context/`. Never commit on your own (only `save` does, and only if
  `save_commit` is true).

## Layout

```
.context/
├── config.json      modules, alias, git profile, rules file, thresholds (user-editable)
├── PROJECT.md       shared memory: purpose, pointer to the rules file, data sources, decision log
├── MAP.md · map.json   generated repository map · folder purposes
├── index.md · manifest.json   generated document index · conversion state
├── raw/             originals (git-ignored unless git_profile is full)      converted/  Markdown per document
├── topics/<t>/      STATE.md (present) · HISTORY.md (append-only past) · <sub>/
├── archive/<t>/     archived topics (read-only)
└── local/           machine-only cache and locks (git-ignored)
```
