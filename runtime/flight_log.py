"""Sparse SIM/BOARD flight log (BASIC SimBackend method).

Writes traces/session_<stamp>_<RUNTIME>.log with TYPE / NOTE / FAULT.
No µop spam by default.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parents[1]
TRACES_DIR = REPO_ROOT / "traces"


class FlightLog:
    def __init__(self, runtime_name: str, directory: Optional[Path] = None) -> None:
        self.directory = directory if directory is not None else TRACES_DIR
        self.directory.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
        self.path = self.directory / f"session_{stamp}_{runtime_name}.log"
        self.path.write_text(
            f"# JMR JS {runtime_name} flight log\n"
            f"# started_utc={datetime.now(timezone.utc).isoformat()}\n"
            f"# events: TYPE / NOTE / FAULT — start reading at the end\n"
            f"# ---\n",
            encoding="utf-8",
        )

    def type_line(self, text: str) -> None:
        self._append(f"TYPE {text}")

    def note(self, text: str) -> None:
        self._append(f"NOTE {text}")

    def fault(self, reason: str, detail: str = "") -> None:
        msg = f"FAULT reason={reason}"
        if detail:
            msg += f" {detail}"
        self._append(msg)

    def _append(self, line: str) -> None:
        with self.path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
