---
id: referencias-claude-notas-subagentes-e-modelos
source: raw/referencias/claude/notas-subagentes-e-modelos.md
origin: https://code.claude.com/docs/en/sub-agents + https://platform.claude.com/docs/en/models/overview · acesso 2026-11-09
sha256: 56bf31696cd558121cb5941dc397980c90a20d097a9f692db641da9523c5175c
converter: plain
converted: 2026-11-09 09:02
pages: 0
kind: document
---
# Claude Code subagents and model choice — facts used by this project

Sources (accessed 2026-11-09, current versions at that date):
- Claude Code docs, "Create custom subagents": https://code.claude.com/docs/en/sub-agents
- Claude Platform docs, "Models overview": https://platform.claude.com/docs/en/models/overview

This is a note, not a copy: the Anthropic documentation has no open license declared,
so only the facts the project relies on are recorded here, with short quotes.

## Subagent files (`.claude/agents/*.md`)

- YAML frontmatter followed by the system prompt in Markdown; "Only `name` and
  `description` are required". Unknown fields are ignored without an error.
- Fields used here: `model` (`sonnet`, `opus`, `haiku`, `fable`, a full model ID or
  `inherit`), `effort` (`low`, `medium`, `high`, `xhigh`, `max`; "available levels
  depend on the model"), `skills` ("The full skill content is injected, not only the
  description"), `tools` and `disallowedTools`, `color`.
- Model resolution order: per-invocation `model` parameter, then the frontmatter
  `model`, then `CLAUDE_CODE_SUBAGENT_MODEL`, then the main conversation's model. A
  family alias equal to the main conversation's family resolves to the main
  conversation's exact model.
- Effort: the per-invocation `effort` parameter overrides the frontmatter `effort`;
  `CLAUDE_CODE_EFFORT_LEVEL` overrides both. Without either, a subagent on another
  model does not inherit the session's effort level.
- Subagents receive their own system prompt plus environment details, not the Claude
  Code system prompt; CLAUDE.md files load unless `omitClaudeMd: true`.
- Claude Code watches `.claude/agents/`, but "The watcher covers only directories that
  existed when the session started": after creating the first agent file in a new
  `agents` directory, a restart is needed.

## Model choice

- "If you're unsure which model to use, start with Claude Opus 5.5 for most workloads.
  Use Claude Fable 5.1 for demanding reasoning and long-horizon agentic work, or when
  your evals on Claude Opus 5.5 at higher effort still fall short."
- Positioning in the comparison table: Fable 5.1 "demanding reasoning and long-horizon
  agentic work"; Opus 5.5 "long-running agentic coding and knowledge work"; Sonnet 5.5
  "The best combination of speed and intelligence"; Haiku 5.5 "high-volume,
  latency-sensitive tasks such as classification, extraction, and routing".
- Default effort per model in the table: Fable `high`, Opus `medium`, Sonnet `high`,
  Haiku `medium`.

## How the project applies it

Opus 5.5 for design, analysis and review; Sonnet 5.5 for well-scoped implementation;
Haiku 5.5 for running checks and summarizing logs; effort set per agent and raised per
task before switching models; Fable only if Opus fails. See
`.context/topics/arquitetura-solucao/PLAN.md` §3.
