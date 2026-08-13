"""Console — line editor / READY loop for the PYTHON glass.

LLM NOTE: Console never owns UART/PHY details; INPUT engine owns FIFO later.
"""

from __future__ import annotations

from typing import Iterable, List, Optional

from .machine import READY, Machine


class Console:
    def __init__(self, machine: Optional[Machine] = None) -> None:
        self.machine = machine if machine is not None else Machine()

    def boot(self) -> List[str]:
        return self.machine.boot_lines()

    def handle_line(self, line: str) -> List[str]:
        out = list(self.machine.execute_line(line))
        if not self.machine.running:
            out.append(READY)
        return out

    def run_lines(self, lines: Iterable[str]) -> List[str]:
        glass: List[str] = self.boot()
        for line in lines:
            glass.append(f"> {line.rstrip()}")
            glass.extend(self.handle_line(line))
        return glass
