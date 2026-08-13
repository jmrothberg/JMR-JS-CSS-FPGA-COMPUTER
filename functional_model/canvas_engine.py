"""Canvas / framebuffer — 640×480×8 indexed, 256 RGB888 palette, double buffer.

LLM NOTE: Framebuffers are large — on FPGA they live in DDR3, not LUTs.
Palette is BRAM-sized (256×24). FM keeps both buffers in Python bytearrays.
"""

from __future__ import annotations

from typing import List, Optional, Tuple

from .font8 import CHAR_H, CHAR_W, glyph

WIDTH = 640
HEIGHT = 480
FB_BYTES = WIDTH * HEIGHT  # 307_200
# Dense 8×8 monitor grid (games overlay / host twin).
COLS = WIDTH // CHAR_W  # 80
ROWS = HEIGHT // CHAR_H  # 60
# HDMI console truth — matches rtl/video/jmr_text_hdmi_scanout.sv
# 64×16 cells, 8×16 pixels (glyph doubled vertically), letterboxed in 640×480.
CONSOLE_COLS = 64
CONSOLE_ROWS = 16
CONSOLE_CELL_H = 16
CONSOLE_ORIGIN_X = 64
CONSOLE_ORIGIN_Y = 112
CONSOLE_VISIBLE_LINES = 16  # last N console lines painted on glass


def _default_palette() -> List[Tuple[int, int, int]]:
    """Simple VGA-ish 256 ramp; index 0 = black, 1 = white, 2.. usable colors."""
    pal: List[Tuple[int, int, int]] = [(0, 0, 0)] * 256
    pal[0] = (0, 0, 0)
    pal[1] = (255, 255, 255)
    pal[2] = (255, 0, 0)
    pal[3] = (0, 255, 0)
    pal[4] = (0, 0, 255)
    pal[5] = (255, 255, 0)
    pal[6] = (0, 255, 255)
    pal[7] = (255, 0, 255)
    for i in range(8, 256):
        g = i & 0xFF
        pal[i] = (g, g, g)
    return pal


class CanvasEngine:
    def __init__(self) -> None:
        self.width = WIDTH
        self.height = HEIGHT
        self.palette = _default_palette()
        self.front = bytearray(FB_BYTES)
        self.back = bytearray(FB_BYTES)
        self.fill_style: int = 1  # palette index

    def clear(self, color: int = 0) -> None:
        c = color & 0xFF
        self.back[:] = bytes([c]) * FB_BYTES

    def clear_front(self, color: int = 0) -> None:
        c = color & 0xFF
        self.front[:] = bytes([c]) * FB_BYTES

    def fill_rect(self, x: int, y: int, w: int, h: int, color: int | None = None) -> None:
        c = self.fill_style if color is None else (color & 0xFF)
        if w <= 0 or h <= 0:
            return
        x0 = max(0, int(x))
        y0 = max(0, int(y))
        x1 = min(self.width, x0 + int(w))
        y1 = min(self.height, y0 + int(h))
        for yy in range(y0, y1):
            row = yy * self.width
            for xx in range(x0, x1):
                self.back[row + xx] = c

    def clear_rect(self, x: int, y: int, w: int, h: int) -> None:
        self.fill_rect(x, y, w, h, 0)

    def swap(self) -> None:
        self.front, self.back = self.back, self.front

    def draw_char_front(self, col: int, row: int, ch: str, color: int = 3) -> None:
        """Blit one glyph into the FRONT buffer (monitor glass)."""
        if col < 0 or row < 0 or col >= COLS or row >= ROWS:
            return
        c = color & 0xFF
        bits = glyph(ch if len(ch) == 1 else "?")
        x0 = col * CHAR_W
        y0 = row * CHAR_H
        for dy, byte in enumerate(bits):
            yy = y0 + dy
            base = yy * self.width + x0
            for dx in range(8):
                if byte & (1 << (7 - dx)):
                    self.front[base + dx] = c

    def draw_text_front(self, col: int, row: int, text: str, color: int = 3) -> None:
        for i, ch in enumerate(text):
            if col + i >= COLS:
                break
            self.draw_char_front(col + i, row, ch, color)

    def draw_console_char(self, col: int, row: int, ch: str, color: int = 3) -> None:
        """Blit one glyph into FRONT at HDMI letterbox cell (8×16)."""
        if col < 0 or row < 0 or col >= CONSOLE_COLS or row >= CONSOLE_ROWS:
            return
        bits = glyph(ch if len(ch) == 1 else "?")
        x0 = CONSOLE_ORIGIN_X + col * CHAR_W
        y0 = CONSOLE_ORIGIN_Y + row * CONSOLE_CELL_H
        c = color & 0xFF
        front = self.front
        w = self.width
        for dy, byte in enumerate(bits):
            for vrep in range(2):  # 2× vertical like HDMI scanout
                yy = y0 + dy * 2 + vrep
                base = yy * w + x0
                for dx in range(8):
                    if byte & (1 << (7 - dx)):
                        front[base + dx] = c

    def paint_console_letterbox(
        self,
        lines: list[str],
        prompt: Optional[str] = None,
        color: int = 3,
        prompt_color: int = 5,
    ) -> None:
        """Paint last CONSOLE_VISIBLE_LINES as 64×16 HDMI letterbox (shared glass)."""
        self.clear_front(0)
        # Wrap at 64; keep last CONSOLE_ROWS-1 content rows + prompt
        wrapped: list[str] = []
        for line in lines:
            text = line.replace("\t", " ")
            if not text:
                wrapped.append("")
                continue
            while text:
                wrapped.append(text[:CONSOLE_COLS])
                text = text[CONSOLE_COLS:]
        # NEW: RTL VRAM already has a bare ">" row. Drop it so the live prompt
        # is one row (yellow), not a green ">" plus a yellow ">" under it.
        while wrapped and wrapped[-1].strip() == ">":
            wrapped.pop()
        body = wrapped[-(CONSOLE_ROWS - 1) :] if wrapped else []
        for r, text in enumerate(body):
            for c, ch in enumerate(text[:CONSOLE_COLS]):
                self.draw_console_char(c, r, ch, color)
        pr = prompt if prompt is not None else "> "
        pr_row = min(len(body), CONSOLE_ROWS - 1)
        for c, ch in enumerate(pr[:CONSOLE_COLS]):
            self.draw_console_char(c, pr_row, ch, prompt_color)

    def front_rgb_preview(self, scale: int = 1) -> bytes:
        """RGB24 packed bytes of front buffer (for Tk PhotoImage / parity)."""
        out = bytearray(FB_BYTES * 3)
        pal = self.palette
        fi = 0
        oi = 0
        for _ in range(FB_BYTES):
            r, g, b = pal[self.front[fi]]
            out[oi] = r
            out[oi + 1] = g
            out[oi + 2] = b
            fi += 1
            oi += 3
        return bytes(out)
