# Topics

A topic is one subject of work with its own memory, in `.context/topics/<name>/`:
`STATE.md` is the present, `HISTORY.md` the append-only past. A big topic may have
**one** level of subtopics: `.context/topics/<parent>/<child>/`. Names: lowercase,
digits, `-` or `_`; command words (`save`, `new`, `archive`, …) are reserved.

## Resuming: `/c <topic>`

`ctx.py run --topic <topic> --session …` reconciles, then prints the topic bundle:
PROJECT.md, the parent's goal and shared decisions (for a subtopic), the topic's
STATE.md, the map rows inside its scope, the index rows of its documents in use,
and its subtopics (for a parent).

- Lock conflict ("já está aberto em outra sessão"): ask whether to open read-only
  or take over, then rerun `ctx.py resume <topic> --session … --read-only` or
  `--take-over`. Two sessions writing one STATE.md would overwrite each other.
- Scope overlap warning: another open session touches the same paths. Mention it
  in one line; keep working.
- Unknown topic: offer the closest existing one or `ctx.py new <slug>`.

Then give a short summary (goal, where we stopped, next 1–3 plan items, pending
questions) and continue the work.

## While working

- Keep `STATE.md` current by editing it directly. Sections:
  - `## Goal`: one or two sentences.
  - `## Plan`: `- [ ]` todo, `- [x]` done, `- [~] item — reason` dropped.
  - `## Where we stopped`: 2–5 bullets a newcomer could resume from.
  - `## Pending`: `- [?] question (context, date)`. Unconfirmed, never a standard.
  - `## Decisions`: append-only; prefer `ctx.py decision`.
  - `## Documents in use`: `- doc-id (p.10-14): why`, ids from `index.md`.
- Front matter `scope:` lists the paths the topic touches (folders end in `/`,
  globs allowed): `transform/marts/fct_churn_*`. It drives map filtering, overlap
  warnings and save suggestions. Code stays in the project's folders; topic folders
  hold memory only.
- The user's plan is theirs: propose changes to it, do not rewrite their items.
- A change of goal is a pivot: record it (see save.md) instead of silently
  replacing the goal.

## Decisions at three levels

Record only what the user confirmed:

```
ctx.py decision <topic> --level topic   "…"   # this topic's STATE.md
ctx.py decision <topic> --level parent  "…"   # parent's Shared decisions (subtopics)
ctx.py decision <topic> --level project "…"   # PROJECT.md Decision log
```

Rules follow the same levels, with this precedence: the rules file
(project-wide) > parent `## Shared decisions` > topic `## Decisions`. A narrower
rule may refine a broader one but never contradict it; if it would, raise it as
a `- [?]` question. A working agreement for one phase ("design only, no code
yet") is a topic decision, not a rules-file entry.

Pick the narrowest level that is true. A naming rule for every table is project
level; a choice for one dimension is topic level. A project-level decision that
becomes a standing rule is also written, with the user's consent, in the rules
file (`.claude/CLAUDE.md` outside the managed block, or `AGENTS.md` when
`rules_file` is `agents`). The log records when and why; the rules file holds
what applies now.

## New, complete, archive, reopen

- `ctx.py new <topic>` or `new <parent>/<child>` (creates the parent if needed).
  Creating the folder by hand works too; `/c` gives it a STATE.md. Ask the user for
  the goal in one line unless it is already clear, and write it under `## Goal`.
- `ctx.py complete <topic>`: status `completed`, folder stays. Make sure `Where we
  stopped` holds a final summary. A parent should complete only after its
  subtopics.
- `ctx.py archive <topic>`: needs `completed` subtopics; checks other memory files
  that link to it. If links exist it pauses and asks; with the user's consent run
  `ctx.py archive <topic> --force`. Moves the folder to `.context/archive/` (with
  `git mv` when tracked). Subtopics are archived with their parent only.
- `ctx.py reopen <topic>`: back to `active`; moves it back from the archive.
- Editing `status:` in a STATE.md by hand has the same effect on the next `/c`.
- An archived topic opens read-only: answer questions from it, do not edit it.
