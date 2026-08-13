#!/usr/bin/env python3
"""Terminal entry for the JMR JS Computer (PYTHON functional model)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Allow `python3 run_jmr_js.py` from repo root without installing a package.
ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from functional_model.console import Console  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="JMR JS-NATIVE-CPU (PYTHON)")
    parser.add_argument(
        "--script",
        type=Path,
        help="Run lines from a file instead of the interactive prompt",
    )
    args = parser.parse_args(argv)

    console = Console()

    if args.script is not None:
        lines = args.script.read_text(encoding="utf-8").splitlines()
        for row in console.run_lines(lines):
            print(row)
        return 0

    for row in console.boot():
        print(row)

    while True:
        try:
            line = input("> ")
        except EOFError:
            print()
            return 0
        except KeyboardInterrupt:
            print()
            return 0
        for row in console.handle_line(line):
            print(row)


if __name__ == "__main__":
    raise SystemExit(main())
