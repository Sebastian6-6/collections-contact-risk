"""User-facing texts (pt-BR)."""

from __future__ import annotations

from typing import Any

from .config import MODULES


def modules_line(cfg: dict[str, Any]) -> str:
    return " · ".join(
        f"{name} {'● on' if cfg['modules'][name] else '○ off'}"
        for name in MODULES
    )


def commands(cfg: dict[str, Any]) -> str:
    a = f"/{cfg['alias']}"
    rows = [
        (
            "Dia a dia",
            [
                (a, "verifica, corrige e atualiza tudo (na 1ª vez, instala)"),
                (f"{a} <tópico>", "o mesmo, e retoma o tópico de onde parou"),
                (f"{a} save", "salva rápido antes de parar; nada é assumido"),
            ],
        ),
        (
            "Atalhos",
            [
                (f"{a} commands", "esta lista"),
                (
                    f"{a} new <tópico>[/<sub>]",
                    "cria um tópico (ou crie a pasta você)",
                ),
                (f"{a} complete <tópico>", "marca como concluído"),
                (
                    f"{a} archive <tópico>",
                    "move para .context/archive/ (checa referências)",
                ),
                (f"{a} reopen <tópico>", "volta para ativo"),
                (
                    f"{a} ingest [--force <arq>]",
                    "converte agora / reconverte um arquivo",
                ),
                (
                    f"{a} forget <documento>",
                    "tira um documento do índice e apaga a conversão",
                ),
                (f"{a} module <nome> on|off", "liga ou desliga um módulo"),
                (
                    f"{a} describe <pasta> <texto>",
                    "descreve uma pasta no mapa",
                ),
                (f"{a} tidy", "consolida o log de decisões do PROJECT.md"),
            ],
        ),
    ]
    width = max(len(cmd) for _, items in rows for cmd, _ in items) + 2
    lines = [f"context-manager ({a}) — comandos", ""]
    for title, items in rows:
        lines.append(title)
        lines.extend(f"  {cmd:<{width}}{desc}" for cmd, desc in items)
        lines.append("")
    lines += [
        f"Módulos: {modules_line(cfg)}",
        f'Atalho: {a} (troque em "alias" no .context/config.json)',
        'Linguagem natural também funciona: "arquiva churn-analysis", '
        '"descreva a pasta ingestion/ no mapa"',
    ]
    return "\n".join(lines)
