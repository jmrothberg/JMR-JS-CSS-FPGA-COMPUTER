"""Pluggable runtime backends for the JMR JS GUI (BASIC method, JS product).

Pattern cite: JMR-BASIC-FPGA-COMPUTER/runtime/backend.py
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[1]
CARD_IMG = ROOT / "card.img"
STORAGE_DIR = ROOT / "storage"


class RuntimeBackend(ABC):
    name: str = "ABSTRACT"

    @abstractmethod
    def type_line(self, text: str) -> None:
        ...

    @abstractmethod
    def screen_text(self) -> str:
        ...

    def poll(self) -> None:
        pass

    def set_joy(self, bits: int) -> None:
        pass

    def set_key_bits(self, bits: int) -> None:
        pass

    def push_key(self, ch: str) -> None:
        pass

    def hard_break(self) -> None:
        pass

    def framebuffer(self):
        """Return CanvasEngine-like object or None."""
        return None

    @abstractmethod
    def trace_path(self) -> Optional[Path]:
        ...

    @property
    def available(self) -> bool:
        return True

    def shutdown(self) -> None:
        pass

    def frame_tick(self) -> None:
        pass

    def paint_prompt(self, prompt: str, cursor_on: bool = False) -> None:
        """Optional: paint monitor prompt into this runtime's glass."""
        pass


class PythonBackend(RuntimeBackend):
    name = "PYTHON"

    def __init__(self, machine) -> None:
        self.machine = machine

    def type_line(self, text: str) -> None:
        self.machine.type_line(text)

    def screen_text(self) -> str:
        return self.machine.screen_text()

    def set_joy(self, bits: int) -> None:
        self.machine.set_joy(bits)

    def set_key_bits(self, bits: int) -> None:
        self.machine.set_key_bits(bits)

    def push_key(self, ch: str) -> None:
        self.machine.push_key(ch)

    def hard_break(self) -> None:
        self.machine.hard_break()

    def framebuffer(self):
        return self.machine.canvas

    def frame_tick(self) -> None:
        self.machine.frame_tick()

    def paint_prompt(self, prompt: str, cursor_on: bool = False) -> None:
        self.machine.paint_monitor(prompt, cursor_on=cursor_on)

    @property
    def running(self) -> bool:
        """Game or last RUN frame owns the glass — GUI must not letterbox over it."""
        m = self.machine
        return bool(
            m.running
            or getattr(m, "_keep_fb", False)
            or m._loop_chunk is not None
            or getattr(m, "html_host", None) is not None
        )

    def trace_path(self) -> Optional[Path]:
        tr = getattr(self.machine, "trace", None)
        return tr.path if tr is not None else None

    def shutdown(self) -> None:
        tr = getattr(self.machine, "trace", None)
        if tr is not None:
            tr.close()
