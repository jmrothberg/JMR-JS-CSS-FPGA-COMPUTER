"""INPUT — keyboard FIFO + digital joystick bitfield (board Pmod / GUI mouse).

LLM NOTE: Same bitfield on PYTHON, FPGA-SIM (mouse→JOY), and BOARD (Pmod).
Bits: 0=UP 1=DOWN 2=LEFT 3=RIGHT 4=FIRE1 5=FIRE2
"""

from __future__ import annotations

from collections import deque
from typing import Deque, Optional

# Digital joystick / gamepad bitfield (matches RTL joy_regs).
JOY_UP = 1 << 0
JOY_DOWN = 1 << 1
JOY_LEFT = 1 << 2
JOY_RIGHT = 1 << 3
JOY_FIRE1 = 1 << 4
JOY_FIRE2 = 1 << 5

# Keyboard play bits (arrow keys + space) — OR'd into the same surface games read.
KEY_LEFT = JOY_LEFT
KEY_RIGHT = JOY_RIGHT
KEY_FIRE = JOY_FIRE1


class InputEngine:
    def __init__(self, fifo_depth: int = 64) -> None:
        self._keys: Deque[str] = deque(maxlen=fifo_depth)
        self.joy: int = 0  # mouse / Pmod stick
        self.key_bits: int = 0  # arrow / space held state
        self.escape_pending: bool = False

    def push_key(self, ch: str) -> None:
        if ch == "\x1b":
            self.escape_pending = True
            return
        if len(ch) == 1:
            self._keys.append(ch)

    def pop_key(self) -> Optional[str]:
        if not self._keys:
            return None
        return self._keys.popleft()

    def set_joy(self, bits: int) -> None:
        self.joy = int(bits) & 0x3F

    def set_key_bits(self, bits: int) -> None:
        self.key_bits = int(bits) & 0x3F

    def play_bits(self) -> int:
        """Combined stick + keyboard for games (left/right/fire)."""
        return (self.joy | self.key_bits) & 0x3F

    def clear_escape(self) -> None:
        self.escape_pending = False
