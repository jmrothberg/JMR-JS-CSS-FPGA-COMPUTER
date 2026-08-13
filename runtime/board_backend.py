"""BOARD backend — USB tether on the PROG cable mirrors HDMI glass into the GUI.

BASIC / T100 method: one USB cable does JTAG and the console mirror.
On Nexys Video the PROG jack's FT2232 channel A is an FT245 FIFO (DPTI), not a
UART — the bitstream speaks that FIFO, and Linux still exposes it as a tty
(VCP). Bytes are:

  S<rowhex>:<64 chars>\\n   — text console (64×16), letterboxed like HDMI
  P<rr>:<160 hex nibbles>\\n — mini-FB row (160×120) scaled ×4 → 640×480
  K\\n                      — PS/2 scancode strobe (J15 keyboard proof)

Port autodetect: JMR_JS_SERIAL env wins; otherwise FT2232 (pid 0x6010) channel A
(location ".0") — channel B is JTAG. Optional FT232R on J13 is a fallback only.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Optional

from functional_model.canvas_engine import (
    CONSOLE_COLS,
    CONSOLE_ROWS,
    CanvasEngine,
)
from runtime.backend import RuntimeBackend
from runtime.flight_log import FlightLog

# Board char VRAM geometry (jmr_video_vram / jmr_uart_link dump)
_MIRROR_COLS = CONSOLE_COLS
_MIRROR_ROWS = CONSOLE_ROWS

_FB_W = 160
_FB_H = 120
_FB_SCALE = 4  # → 640×480

_HINT = "\n".join([
    "BOARD RUNTIME - NO TETHER",
    "",
    "NO PROG USB-SERIAL PORT FOUND.",
    "THE BOARD'S SCREEN IS THE HDMI MONITOR.",
    "",
    "CHECKLIST:",
    "- PROG MICRO-USB CABLE (J12) — SAME AS T100",
    "- PLAY KEYS = GUI ARROWS+SPACE (J15 USB HOST DEAD)",
    "- JP4 = BOOT SOURCE ONLY (NOT KEYBOARD)",
    "- 'DONE' LED LIT = FPGA CONFIGURED",
    "- LD7 BLINKS ON USB SCANCODE (J15) IF FIXED",
    "",
    "F9 -> FPGA-SIM (RTL) = SAME CORE, MIRRORED HERE.",
])

_ROW_RE = re.compile(r"^S([0-9A-Fa-f]):(.*)$")
_FB_RE = re.compile(r"^P([0-9A-Fa-f]{2}):([0-9A-Fa-f]*)$")


def _find_serial_port() -> Optional[str]:
    env_port = os.environ.get("JMR_JS_SERIAL", "").strip()
    if env_port:
        return env_port
    try:
        from serial.tools import list_ports
    except ImportError:
        return None
    # PROG FT2232 (pid 0x6010): ch A (".0") = DPTI FIFO tether, ch B (".1") =
    # JTAG (openFPGALoader board nexysVideo uses cable digilent_b = channel B).
    # VERIFIED on silicon 2026-08-12: S-rows stream on the ".0" interface.
    ftdi = [p for p in list_ports.comports() if p.vid == 0x0403]
    for p in ftdi:
        if p.pid == 0x6010 and (p.location or "").endswith(".0"):
            return p.device
    for p in ftdi:
        if p.pid == 0x6010 and not (p.location or "").endswith(".1"):
            return p.device
    for p in ftdi:
        if p.pid == 0x6001:
            return p.device
    return None


class BoardBackend(RuntimeBackend):
    name = "BOARD"

    def __init__(self) -> None:
        self._ser = None
        self._rows = [""] * _MIRROR_ROWS
        self._rx_buf = b""
        self._canvas = CanvasEngine()
        self._prompt = "> "
        self._log = FlightLog(self.name)
        # NEW: mini-FB mirror (game_mode P-rows) — full 640×480 after ×4 scale
        self._fb = bytearray(_FB_W * _FB_H)
        self._have_fb = False
        self._ps2_strobes = 0
        port = _find_serial_port()
        if port:
            try:
                import serial

                self._ser = serial.Serial(port, 115200, timeout=0.05)
                self._log.note(f"open {port}")
            except Exception as e:
                self._ser = None
                self._log.fault("SERIAL", str(e))
        else:
            self._log.note("no UART port found (HDMI-only BOARD)")

    @property
    def available(self) -> bool:
        return True

    def poll(self) -> None:
        if self._ser is None:
            return
        try:
            n = self._ser.in_waiting
            if n:
                self._rx_buf += self._ser.read(n)
        except Exception as e:
            self._log.fault("SERIAL", str(e))
            self._ser = None
            return
        while b"\n" in self._rx_buf:
            raw, self._rx_buf = self._rx_buf.split(b"\n", 1)
            line = raw.decode("ascii", errors="replace").rstrip("\r")
            if line == "K":
                # NEW: USB Host scancode reached RTL (ps2_strobe)
                self._ps2_strobes += 1
                self._log.note(f"ps2_strobe n={self._ps2_strobes}")
                continue
            m = _ROW_RE.match(line)
            if m:
                self._rows[int(m.group(1), 16)] = m.group(2)
                self._have_fb = False
                continue
            fm = _FB_RE.match(line)
            if fm:
                row = int(fm.group(1), 16)
                hexpix = fm.group(2)
                if 0 <= row < _FB_H and len(hexpix) >= _FB_W:
                    base = row * _FB_W
                    for x in range(_FB_W):
                        self._fb[base + x] = int(hexpix[x], 16) & 0xF
                    self._have_fb = True

    def frame_tick(self) -> None:
        self.poll()
        self._paint_mirror()

    def _prompt_row(self) -> int:
        for r in range(_MIRROR_ROWS - 1, -1, -1):
            if self._rows[r].startswith(">"):
                return r
        return _MIRROR_ROWS - 1

    def _paint_fb_scaled(self) -> None:
        """Mini 160×120 → full 640×480 (same ×4 as HDMI game scanout)."""
        front = self._canvas.front
        w = self._canvas.width
        for fy in range(_FB_H):
            src = fy * _FB_W
            for fx in range(_FB_W):
                pix = self._fb[src + fx]
                x0 = fx * _FB_SCALE
                y0 = fy * _FB_SCALE
                for dy in range(_FB_SCALE):
                    base = (y0 + dy) * w + x0
                    for dx in range(_FB_SCALE):
                        front[base + dx] = pix

    def _paint_mirror(self) -> None:
        """Rasterize tether into full 640×480 glass (shared HDMI letterbox)."""
        if self._ser is None:
            self._canvas.clear_front(0)
            for i, line in enumerate(_HINT.splitlines()[:25]):
                self._canvas.draw_text_front(2, 2 + i, line[:76], 3)
            return
        if self._have_fb:
            self._canvas.clear_front(0)
            self._paint_fb_scaled()
            return
        if not any(self._rows):
            self._canvas.clear_front(0)
            self._canvas.draw_text_front(2, 2, "HDMI MONITOR IS THE SCREEN", 3)
            self._canvas.draw_text_front(2, 4, "TYPE ON THE USB KEYBOARD IN J15", 3)
            self._canvas.draw_text_front(2, 6, "JP4=BOOT SOURCE ONLY — NOT KEYBOARD", 3)
            self._canvas.draw_text_front(2, 8, "LD6 ON=PS/2 CLK IDLE; LD7=SCANCODE", 3)
            return
        rows = [r.rstrip() for r in self._rows]
        pr = self._prompt_row()
        # paint_console_letterbox wraps/truncates; pass exact 16 VRAM rows
        self._canvas.clear_front(0)
        for r in range(_MIRROR_ROWS):
            text = rows[r] if r < len(rows) else ""
            for c, ch in enumerate(text[:_MIRROR_COLS]):
                color = 5 if r == pr else 3
                ch_out = ch
                if r == pr and c < len(self._prompt):
                    ch_out = self._prompt[c]
                elif r == pr and c >= len(self._prompt.rstrip()):
                    # keep board row under overlay past prompt
                    ch_out = ch if ch else " "
                self._canvas.draw_console_char(c, r, ch_out if ch_out else " ", color)
        # Ensure prompt chars visible
        for c, ch in enumerate(self._prompt[:_MIRROR_COLS]):
            self._canvas.draw_console_char(c, pr, ch, 5)

    def type_line(self, text: str) -> None:
        self._log.type_line(text)
        self._prompt = "> "
        if self._ser is None:
            return
        try:
            self._ser.write((text + "\n").encode("ascii", errors="replace"))
            self._ser.flush()
        except Exception as e:
            self._log.fault("SERIAL", str(e))

    def paint_prompt(self, prompt: str, cursor_on: bool = False) -> None:
        self._prompt = prompt
        self._paint_mirror()

    def hard_break(self) -> None:
        self._log.note("BREAK")
        if self._ser is not None:
            try:
                self._ser.write(b"\x1b")
            except Exception:
                pass

    def screen_text(self) -> str:
        if self._ser is None:
            return _HINT
        return "\n".join(self._rows)

    def set_joy(self, bits: int) -> None:
        # NEW: same wire as KEYBITS — board joy_in was hardwired 0
        self.set_key_bits(bits)

    def set_key_bits(self, bits: int) -> None:
        """GUI arrows/Space → PROG tether → RTL joy_in (J15 USB host is dead)."""
        if self._ser is None:
            return
        try:
            # 0xFE prefix + 6-bit play field (matches jmr_uart_link joy_cmd)
            self._ser.write(bytes([0xFE, bits & 0x3F]))
            self._ser.flush()
        except Exception as e:
            self._log.fault("KEYBITS", str(e))

    def framebuffer(self):
        return self._canvas

    def trace_path(self) -> Optional[Path]:
        return self._log.path

    def shutdown(self) -> None:
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass
