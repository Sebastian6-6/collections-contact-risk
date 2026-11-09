#!/usr/bin/env python3
"""Entry point of the context-manager skill.

Run from the project root, e.g. ``python3 .claude/skills/context-manager/
scripts/ctx.py run``. Only the standard library is required; Docling is
installed separately into a shared environment by ``install-docling``.
"""

import sys

if sys.version_info < (3, 10):  # keep this file parseable by old Pythons
    sys.stdout.write(
        "context-manager precisa de Python 3.10 ou mais novo "
        "(encontrado %d.%d).\n" % sys.version_info[:2]
    )
    sys.exit(1)

from pathlib import Path

# The skill lives inside the user's repository: never leave __pycache__ there
# (bytecode embeds absolute local paths and would end up in commits).
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))

from cm.cli import main

if __name__ == "__main__":
    sys.exit(main())
