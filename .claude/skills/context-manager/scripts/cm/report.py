"""Two-audience output: pt-BR report for the user, TODOs for Claude."""

from __future__ import annotations

import json
from dataclasses import dataclass, field

ICONS = {
    "questions": "❓ Perguntas pendentes",
    "fixed": "✓ Correções aplicadas",
    "warnings": "⚠ Atenção",
    "done": "✓ Feito",
    "status": "📌 Estado",
    "next": "→ Próximo passo",
}


@dataclass
class Report:
    title: str
    sections: dict[str, list[str]] = field(default_factory=dict)
    todos: list[str] = field(default_factory=list)
    blocks: list[tuple[str, str]] = field(default_factory=list)
    exit_code: int = 0

    def add(self, section: str, line: str) -> None:
        self.sections.setdefault(section, []).append(line)

    def extend(self, section: str, lines: list[str]) -> None:
        for line in lines:
            self.add(section, line)

    def todo(self, text: str) -> None:
        self.todos.append(text)

    def block(self, heading: str, content: str) -> None:
        """Raw context for Claude (file contents), printed after the report."""
        self.blocks.append((heading, content))

    def merge(self, other: Report) -> None:
        for section, lines in other.sections.items():
            self.extend(section, lines)
        self.todos.extend(other.todos)
        self.blocks.extend(other.blocks)
        self.exit_code = max(self.exit_code, other.exit_code)

    def to_json(self) -> str:
        return json.dumps(
            {
                "title": self.title,
                "sections": self.sections,
                "todos": self.todos,
                "blocks": [
                    {"heading": h, "content": c} for h, c in self.blocks
                ],
            },
            ensure_ascii=False,
            indent=2,
        )

    def render(self) -> str:
        out = [self.title]
        order = ["questions", "fixed", "done", "warnings", "status", "next"]
        for key in order + [k for k in self.sections if k not in order]:
            lines = self.sections.get(key)
            if not lines:
                continue
            label = ICONS.get(key, key)
            count = f" ({len(lines)})" if key == "questions" else ""
            out.append(f"\n{label}{count}")
            out.extend(
                f"  {line}" if line.startswith(" ") else f"  • {line}"
                for line in lines
            )
        for heading, content in self.blocks:
            out.append(f"\n===== {heading} =====\n{content.rstrip()}")
        if self.todos:
            out.append("\n[claude] TODO — do these in order before replying:")
            out.extend(f"  {i}. {t}" for i, t in enumerate(self.todos, 1))
        return "\n".join(out) + "\n"
