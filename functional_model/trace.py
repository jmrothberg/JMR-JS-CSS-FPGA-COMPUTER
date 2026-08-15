"""Always-on session flight log for PYTHON (BASIC TraceLog method).

Edge events stream live to traces/session_*_PYTHON.log. Recent lines live in
a ring and dump on ERROR/BREAK. No µop spam — keep it readable for humans/LLMs.
"""

from __future__ import annotations

import os
import subprocess
import sys
from collections import deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
TRACES_DIR = REPO_ROOT / "traces"
LINE_RING = 256


def git_stamp() -> str:
    try:
        head = subprocess.check_output(
            ["git", "rev-parse", "--short=12", "HEAD"],
            cwd=REPO_ROOT,
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        dirty = subprocess.call(
            ["git", "diff", "--quiet", "HEAD"],
            cwd=REPO_ROOT,
            stderr=subprocess.DEVNULL,
        )
        return f"{head}{'+dirty' if dirty else ''}"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


# NEW: pytest / parity battery must not bury F9 session logs. JMR_TRACE=1
# forces the GUI folder (title smokes that we want LATEST_* for).
def session_trace_dir() -> Path:
    if os.environ.get("JMR_TRACE", "").strip().lower() in ("1", "true", "yes"):
        TRACES_DIR.mkdir(parents=True, exist_ok=True)
        return TRACES_DIR
    if os.environ.get("PYTEST_CURRENT_TEST") or os.environ.get("PYTEST_VERSION"):
        d = TRACES_DIR / "pytest"
        d.mkdir(parents=True, exist_ok=True)
        return d
    argv = " ".join(sys.argv).replace("\\", "/")
    if "check_runtime_parity" in argv or "golden_frames" in argv:
        d = TRACES_DIR / "pytest"
        d.mkdir(parents=True, exist_ok=True)
        return d
    TRACES_DIR.mkdir(parents=True, exist_ok=True)
    return TRACES_DIR


def point_latest(runtime_name: str, path: Path) -> None:
    """traces/LATEST_<RUNTIME>.log → this session. Skip pytest noise."""
    if path.parent.name == "pytest":
        return
    latest = TRACES_DIR / f"LATEST_{runtime_name}.log"
    try:
        if latest.exists() or latest.is_symlink():
            latest.unlink()
        latest.symlink_to(path.name)
    except OSError:
        pass


class TraceLog:
    """Session file + in-memory ring; dump ring on error/BREAK."""

    def __init__(self, machine, directory: Optional[Path] = None) -> None:
        self.machine = machine
        self.directory = directory if directory is not None else session_trace_dir()
        self.directory.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
        self.path = self.directory / f"session_{stamp}_PYTHON.log"
        self.git = git_stamp()
        self.lines: deque[str] = deque(maxlen=LINE_RING)
        self._file = self.path.open("w", encoding="utf-8")
        self._write_header()
        point_latest("PYTHON", self.path)
        self.edge("BOOT", "machine constructed")

    def _write_header(self) -> None:
        self._file.write(
            "# JMR JS Computer PYTHON trace\n"
            f"# git={self.git}\n"
            f"# started_utc={datetime.now(timezone.utc).isoformat()}\n"
            "# events: EDGE / PLAY / MORE / FAULT — start reading at the end\n"
            "# ---\n"
        )
        self._file.flush()

    def _write(self, line: str) -> None:
        self._file.write(line + "\n")
        self._file.flush()

    def close(self) -> None:
        if not self._file.closed:
            self.edge("CLOSE", "session end")
            self._file.close()

    def __del__(self) -> None:  # pragma: no cover
        try:
            if hasattr(self, "_file") and not self._file.closed:
                self._file.close()
        except Exception:
            pass

    def edge(self, kind: str, detail: str = "") -> None:
        name = getattr(self.machine, "source_name", "")
        running = int(bool(getattr(self.machine, "running", False)))
        msg = f"EDGE {kind} running={running} src={name!r}"
        if detail:
            msg += f" {detail}"
        self.lines.append(msg)
        self._write(msg)

    def dump_ring(self, reason: str) -> None:
        self._write(f"# === DUMP reason={reason} ===")
        for line in self.lines:
            self._write(f"RING {line}")
        self._write("# === DUMP END ===")
        self._file.flush()
