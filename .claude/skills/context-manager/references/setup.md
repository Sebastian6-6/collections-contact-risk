# Setup, machines and configuration

## First run in a folder

`ctx.py run` with no `.context/config.json` creates nothing: it prints a plan.

1. Show the plan to the user in their language and ask for **one** confirmation.
   Do not split it into several questions.
2. On "yes": `ctx.py run --confirm-init --session …`. It creates `.context/`, the
   managed blocks in `.gitignore` and `.claude/CLAUDE.md`, the `/c` alias skill
   and the SessionStart status hook. If the folder already has a root `AGENTS.md`,
   the plan says so and init sets `rules_file: "agents"`: project rules stay in
   AGENTS.md (imported by `.claude/CLAUDE.md`), and the skill never writes it.
3. Do the TODOs it prints, in order. Usually: install Docling (long, once per
   machine), describe folders for the map, fill PROJECT.md `## Purpose`
   (`ctx.py project Purpose --file <tmp.md>`), and show the COMANDOS block
   exactly as printed. The user expects the full command list right after
   installing.

If the user says no, stop; nothing was written.

A folder that is not a git repository works too: archive moves without history
and save cannot suggest scope from git changes. Do not run `git init` for the user.

## A second computer

The skill, `.context/` (minus `raw/` and `local/`) and the settings arrive through
git. Running `/c` there detects the existing setup and only installs what the
machine lacks, typically Docling. Originals in `raw/` are not on the new machine;
their converted Markdown is, so work continues. The report counts missing
originals as information, not as an error.

## Docling

`ctx.py install-docling` creates one shared environment per machine in
`~/.context-manager/venv` (`%USERPROFILE%\.context-manager\venv` on Windows) and
installs Docling with EasyOCR, which has Portuguese models. It never needs
activating: the script calls that interpreter by path. The first conversion of a
PDF or image also downloads Docling's layout and OCR models once. If the install fails, the
log path is in the report; relay it and suggest checking internet access or disk
space. Only `ingest` uses Docling.

## Modules (`config.json` → `modules`)

| Module | On | Off |
|---|---|---|
| `ingest` | converts `raw/`, keeps `index.md`, installs Docling | nothing converted; existing Markdown stays readable; status notes unconverted files |
| `map` | regenerates `MAP.md` on every `run` | `MAP.md` no longer refreshed and its rule leaves CLAUDE.md |
| `history` | `HISTORY.md` per topic; save moves done/dropped plan items there | no new history; existing files kept |
| `status_hook` | one status line at the start of each session | hook removed from `.claude/settings.json` |

`/c module <name> on|off` edits the config and reconciles at once. A manual edit
of `config.json` is applied on the next `/c`.

## Other settings

| Key | Default | Meaning |
|---|---|---|
| `alias` | `c` | shortcut name; changing it renames the alias skill |
| `git_profile` | `complete` | `complete`: ignore raw/ + local/ · `minimal`: also converted/ · `none`: ignore all of .context/ · `full`: ignore only local/ (publishes raw/ and converted/: review them for confidential content first) |
| `rules_file` | `claude` (`agents` if `AGENTS.md` exists at first run) | where project rules live: `claude` → `.claude/CLAUDE.md` outside the managed block · `agents` → root `AGENTS.md`, imported by the managed block with `@../AGENTS.md` (a `.claude/CLAUDE.md` stops Claude Code from reading AGENTS.md on its own). PROJECT.md keeps a generated `## Rules` pointer |
| `save_commit` | `false` | `true`: save commits only `.context/` (never pushes) |
| `language` | memory `en`, output `pt-BR`, ocr `["pt","en"]` | see SKILL.md |
| `large_file_threshold` | 2000 lines / 1 MB | above this, read slices first |
| `skip_dirs` | venvs, node_modules, caches, build | never mapped |
| `map.max_depth` / `map.max_rows` | 4 / 200 | depth shrinks automatically to fit |
| `lock_ttl_hours` | 8 | a topic lock older than this is considered abandoned |

What the reconciliation repairs vs. reports:
- **Repairs** what the skill owns: folders, generated files, managed blocks, alias,
  hook, config defaults.
- **Reports only** user content: STATE.md, PROJECT.md, plans, decisions, and the
  rules file (never written by the scripts). A legacy `## Conventions` in
  PROJECT.md is reported with a TODO: merge it into the rules file with the
  user's consent, then `ctx.py project Conventions --drop`.
- **Respects** a removed `.gitignore` block after it was applied once (deliberate
  opt-out); it is not re-added.

## Troubleshooting

- `/c` does not appear after copying the skill: start a new session.
- Status line missing at session start: check `.claude/settings.json` and that
  one of `python3`, `python` or `py` is on PATH for Git Bash.
- "arquivo ocupado por outra sessão": another session holds a write lock for a few
  seconds; retry.
