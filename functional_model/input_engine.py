"""INPUT — keyboard FIFO + digital joystick bitfield (board Pmod / GUI mouse).

LLM NOTE: Same bitfield on PYTHON, FPGA-SIM (mouse→JOY), and BOARD (Pmod).
Bits: 0=UP 1=DOWN 2=LEFT 3=RIGHT 4=FIRE1 5=FIRE2

NEW (HTML games): generic key-state engine — PS/2 scancode → JS keyCode →
per-key down table + edge event queue. Tether KEYBITS OR into the same table
as debug only; HTML keydown/keyup handlers decide bindings (no hardcoded WASD).
"""

from __future__ import annotations

from collections import deque
from typing import Deque, Dict, List, Optional, Tuple

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
KEY_UP = JOY_UP
KEY_DOWN = JOY_DOWN
KEY_FIRE = JOY_FIRE1

# NEW: PS/2 Set-2 make codes → JS keyCode (subset for games + letters)
# Break = F0 + make; extended = E0 + make (arrows).
_PS2_MAKE_TO_KEYCODE: Dict[int, Tuple[int, str]] = {
    # arrows (E0 prefix stripped by caller)
    0x75: (38, "ArrowUp"),
    0x72: (40, "ArrowDown"),
    0x6B: (37, "ArrowLeft"),
    0x74: (39, "ArrowRight"),
    0x29: (32, " "),  # space
    # WASD / letters (HTML titles bind these themselves)
    0x1C: (65, "a"),
    0x1B: (83, "s"),
    0x23: (68, "d"),
    0x1D: (87, "w"),
    0x15: (81, "q"),
    0x24: (69, "e"),
    0x2D: (82, "r"),
    0x2C: (84, "t"),
    0x35: (89, "y"),
    0x3C: (85, "u"),
    0x43: (73, "i"),
    0x44: (79, "o"),
    0x4D: (80, "p"),
    0x1A: (90, "z"),
    0x22: (88, "x"),
    0x21: (67, "c"),
    0x2A: (86, "v"),
    0x32: (66, "b"),
    0x31: (78, "n"),
    0x3A: (77, "m"),
    0x5A: (13, "Enter"),
    0x76: (27, "Escape"),
}

# NEW: joy/KEYBITS mask → (keyCode, key) for tether debug OR
_PLAY_BIT_TO_KEY: List[Tuple[int, int, str]] = [
    (KEY_LEFT, 37, "ArrowLeft"),
    (KEY_UP, 38, "ArrowUp"),
    (KEY_RIGHT, 39, "ArrowRight"),
    (KEY_DOWN, 40, "ArrowDown"),
    (KEY_FIRE, 32, " "),
]


class InputEngine:
    def __init__(self, fifo_depth: int = 64) -> None:
        self._keys: Deque[str] = deque(maxlen=fifo_depth)
        self.joy: int = 0  # mouse / Pmod stick
        self.key_bits: int = 0  # arrow / space held state (tether debug)
        self.escape_pending: bool = False
        # NEW: key-state engine
        self._down: Dict[int, bool] = {}  # keyCode → pressed
        self._events: Deque[Tuple[str, int, str]] = deque(maxlen=64)  # (type, keyCode, key)
        self._ps2_ext = False
        self._ps2_break = False
        self._prev_play = 0  # last play_bits for tether edge OR

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
        """Tether/GUI KEYBITS — OR into key-state as debug mirror of arrows+space."""
        self.key_bits = int(bits) & 0x3F
        self._sync_play_bits_to_keys()

    def play_bits(self) -> int:
        """Combined stick + keyboard for games (arrows + fire)."""
        return (self.joy | self.key_bits) & 0x3F

    def clear_escape(self) -> None:
        self.escape_pending = False

    # --- NEW: key-state engine --------------------------------------------

    def push_ps2_byte(self, byte: int) -> None:
        """Feed one PS/2 Set-2 byte; updates down table + event queue."""
        b = int(byte) & 0xFF
        if b == 0xE0:
            self._ps2_ext = True
            return
        if b == 0xF0:
            self._ps2_break = True
            return
        make = b
        ext, brk = self._ps2_ext, self._ps2_break
        self._ps2_ext = False
        self._ps2_break = False
        info = _PS2_MAKE_TO_KEYCODE.get(make)
        if info is None:
            return
        key_code, key = info
        # Arrow makes are only valid with E0
        if make in (0x75, 0x72, 0x6B, 0x74) and not ext:
            return
        self._set_key(key_code, key, pressed=not brk)

    def _set_key(self, key_code: int, key: str, pressed: bool) -> None:
        was = bool(self._down.get(key_code))
        if pressed == was:
            return
        self._down[key_code] = pressed
        self._events.append(("keydown" if pressed else "keyup", key_code, key))

    def _sync_play_bits_to_keys(self) -> None:
        """OR tether KEYBITS into key-state (debug); edges → event queue."""
        bits = self.play_bits()
        prev = self._prev_play
        self._prev_play = bits
        for mask, code, key in _PLAY_BIT_TO_KEY:
            down = bool(bits & mask)
            was = bool(prev & mask)
            if down and not was:
                self._set_key(code, key, True)
            elif was and not down:
                self._set_key(code, key, False)

    def key_down(self, key_code: int) -> bool:
        return bool(self._down.get(int(key_code)))

    def key_event(self, key_code: int, key: str, pressed: bool) -> None:
        """NEW: GUI/host raw keyboard → key-state engine (the HTML decides
        bindings; this is the honest path for Enter/letters, not KEYBITS)."""
        self._set_key(int(key_code), str(key), bool(pressed))

    def drain_key_events(self) -> List[Tuple[str, int, str]]:
        """Pop queued keydown/keyup events (type, keyCode, key)."""
        out: List[Tuple[str, int, str]] = []
        while self._events:
            out.append(self._events.popleft())
        return out

    def discard_queued_keys(self) -> None:
        """Drop prompt/LIST KEYBITS so they cannot start a game on first rAF."""
        self._events.clear()
        self._prev_play = self.play_bits()
