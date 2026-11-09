# Save and tidy

## `/c save`: fast checkpoint, no blocking questions

The user is usually about to leave. Make it quick and never wait for answers.

1. `ctx.py save --session …` (add `--topic <t>` if the topic was not opened
   through the skill in this session). It lists, per open topic: the STATE.md path,
   files changed outside the topic's scope, whether PROJECT.md changed since the
   topic was opened, and `GOAL CHANGED` when the goal was edited.
2. Edit each STATE.md:
   - `## Where we stopped`: 2–5 bullets, concrete enough to resume cold.
   - `## Plan`: mark `[x]` done and `[~] … — reason` dropped, add new items. The
     script moves done and dropped items to HISTORY.md, keeping STATE short.
   - `## Documents in use` and `scope:`: add listed paths only when they clearly
     belong to this topic.
3. Open questions (standards, conventions, doubtful choices) go to `## Pending` as
   `- [?] question (context, date)` in the **lowest** level where they came up
   (subtopic before parent, topic before project). They stay unconfirmed; never
   promote them to decisions or to PROJECT.md on your own.
4. Decisions the user explicitly confirmed during the session:
   `ctx.py decision <topic> --level topic|parent|project "…"`. If PROJECT.md
   changed since opening, re-read its Decision log first to avoid duplicates.
5. Pivot (`GOAL CHANGED`): `ctx.py history <topic> pivot "old → new — reason"`.
   Reason unknown: write `reason not recorded` and add a pending question.
6. `ctx.py save --finish --session …` (same `--topic` if used). It stamps
   `updated:`, moves plan items to history, releases the lock and, if
   `save_commit` is true, commits only `.context/`.
7. Reply briefly: what was saved and the pending questions, in the user's
   language. Do not ask them to answer now.

HISTORY.md lines are one event each: `YYYY-MM-DD done|drop|pivot  text — reason`.
It is not loaded on resume; read it only when the user asks why something changed.

## `/c tidy`: consolidate PROJECT.md decisions

1. `ctx.py tidy` prints the Decision log and its version hash.
2. Propose a consolidated log: merge duplicates, keep the newest of conflicting
   entries, keep dates and `[topic]` tags. Durable rules belong in the rules file
   (see `## Rules` in PROJECT.md): add them there by hand, outside any managed
   block and without rewriting existing rules, only if the user agrees.
3. After the user confirms, write the new section body (no heading) to a temp
   file and run `ctx.py tidy --apply <file> --expect <hash>`. If another session
   added decisions meanwhile, the script refuses; run `ctx.py tidy` again.
