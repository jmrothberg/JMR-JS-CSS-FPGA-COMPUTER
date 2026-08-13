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


# CSS colors the target games actually use (fillStyle / strokeStyle harvest
# + runtime mapping). Not a full CSS table — grow as titles need.
CSS_NAMED = {
    "black": (0, 0, 0),
    "white": (255, 255, 255),
    "red": (255, 0, 0),
    "green": (0, 128, 0),
    "lime": (0, 255, 0),
    "blue": (0, 0, 255),
    "yellow": (255, 255, 0),
    "cyan": (0, 255, 255),
    "aqua": (0, 255, 255),
    "magenta": (255, 0, 255),
    "fuchsia": (255, 0, 255),
    "orange": (255, 165, 0),
    "purple": (128, 0, 128),
    "pink": (255, 192, 203),
    "brown": (165, 42, 42),
    "gray": (128, 128, 128),
    "grey": (128, 128, 128),
    "silver": (192, 192, 192),
    "gold": (255, 215, 0),
    "navy": (0, 0, 128),
    "teal": (0, 128, 128),
    "maroon": (128, 0, 0),
    "olive": (128, 128, 0),
    "orangered": (255, 69, 0),
    "darkred": (139, 0, 0),
    "darkblue": (0, 0, 139),
    "darkgreen": (0, 100, 0),
    "lightblue": (173, 216, 230),
    "lightgray": (211, 211, 211),
    "lightgrey": (211, 211, 211),
    "hotpink": (255, 105, 180),
    "tomato": (255, 99, 71),
    "crimson": (220, 20, 60),
    "salmon": (250, 128, 114),
    "khaki": (240, 230, 140),
    "tan": (210, 180, 140),
    "beige": (245, 245, 220),
    "ivory": (255, 255, 240),
    "skyblue": (135, 206, 235),
    "royalblue": (65, 105, 225),
    "dodgerblue": (30, 144, 255),
    "deepskyblue": (0, 191, 255),
    "limegreen": (50, 205, 50),
    "forestgreen": (34, 139, 34),
    "greenyellow": (173, 255, 47),
    "violet": (238, 130, 238),
    "indigo": (75, 0, 130),
    "turquoise": (64, 224, 208),
    "coral": (255, 127, 80),
    "wheat": (245, 222, 179),
    "chocolate": (210, 105, 30),
    "firebrick": (178, 34, 34),
    "midnightblue": (25, 25, 112),
    "darkorange": (255, 140, 0),
    "goldenrod": (218, 165, 32),
    "plum": (221, 160, 221),
    "orchid": (218, 112, 214),
    "slateblue": (106, 90, 205),
    "steelblue": (70, 130, 180),
    "seagreen": (46, 139, 87),
    "springgreen": (0, 255, 127),
    "lavender": (230, 230, 250),
    "snow": (255, 250, 250),
    "dimgray": (105, 105, 105),
    "dimgrey": (105, 105, 105),
    "darkgray": (169, 169, 169),
    "darkgrey": (169, 169, 169),
}


def parse_css_color(s) -> Optional[Tuple[int, int, int]]:
    """'#RGB' / '#RRGGBB' / 'rgb(a)(…)' / named → (r, g, b) or None.

    rgba alpha is ignored (indexed glass has no blending; a≈0 still returns
    the color — callers decide transparency policy).
    """
    if not isinstance(s, str):
        return None
    t = s.strip().lower()
    if not t:
        return None
    if t.startswith("#"):
        hexs = t[1:]
        try:
            if len(hexs) == 3:
                return tuple(int(ch * 2, 16) for ch in hexs)  # type: ignore[return-value]
            if len(hexs) in (6, 8):
                return (
                    int(hexs[0:2], 16),
                    int(hexs[2:4], 16),
                    int(hexs[4:6], 16),
                )
        except ValueError:
            return None
        return None
    if t.startswith("rgb"):
        inner = t[t.find("(") + 1 : t.rfind(")")]
        parts = [p.strip() for p in inner.split(",")]
        if len(parts) >= 3:
            try:
                vals = []
                for p in parts[:3]:
                    if p.endswith("%"):
                        vals.append(int(float(p[:-1]) * 255 / 100))
                    else:
                        vals.append(int(float(p)))
                return tuple(max(0, min(255, v)) for v in vals)  # type: ignore[return-value]
            except ValueError:
                return None
        return None
    return CSS_NAMED.get(t)


def nearest_palette_index(
    palette: List[Tuple[int, int, int]], rgb: Tuple[int, int, int], lo: int = 1
) -> int:
    """Nearest palette entry ≥ lo (0 stays transparent-for-blits)."""
    r, g, b = rgb
    best, bd = lo, 1 << 30
    for i in range(lo, len(palette)):
        pr, pg, pb = palette[i]
        d = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb)
        if d < bd:
            best, bd = i, d
            if d == 0:
                break
    return best


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
        # NEW: draw-activity flag — present (swap) only on frames the game
        # actually drew (setTimeout-paced loops draw every Nth tick; swapping
        # blindly would flash the stale opposite buffer).
        self.dirty: bool = False

    def clear(self, color: int = 0) -> None:
        c = color & 0xFF
        self.back[:] = bytes([c]) * FB_BYTES
        self.dirty = True

    def clear_front(self, color: int = 0) -> None:
        c = color & 0xFF
        self.front[:] = bytes([c]) * FB_BYTES

    def fill_rect(self, x: int, y: int, w: int, h: int, color: int | None = None) -> None:
        c = self.fill_style if color is None else (color & 0xFF)
        if w <= 0 or h <= 0:
            return
        self.dirty = True
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

    def fill_console_cell(self, col: int, row: int, color: int = 6) -> None:
        """Solid cell block (GUI/SIM cursor blink — matches HDMI cyan cursor)."""
        if col < 0 or row < 0 or col >= CONSOLE_COLS or row >= CONSOLE_ROWS:
            return
        x0 = CONSOLE_ORIGIN_X + col * CHAR_W
        y0 = CONSOLE_ORIGIN_Y + row * CONSOLE_CELL_H
        c = color & 0xFF
        front = self.front
        w = self.width
        for dy in range(CONSOLE_CELL_H):
            base = (y0 + dy) * w + x0
            for dx in range(CHAR_W):
                front[base + dx] = c

    def paint_console_letterbox(
        self,
        lines: list[str],
        prompt: Optional[str] = None,
        color: int = 3,
        prompt_color: int = 5,
        cursor_on: bool = False,
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
        # NEW: drop trailing blank VRAM rows, then bare ">" — else blanks leave
        # a green ">" in the body and the host paints a second yellow ">" under it.
        while wrapped and not wrapped[-1].strip():
            wrapped.pop()
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
        # NEW: blinking block after prompt (HDMI already blinks via frame_div[5])
        if cursor_on and len(pr) < CONSOLE_COLS:
            self.fill_console_cell(len(pr), pr_row, color=6)

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

    def fill_text(
        self,
        text,
        x: int,
        y: int,
        color: int | None = None,
        align: str = "left",
        scale: int = 1,
    ) -> None:
        """8x8 glyphs into the BACK buffer (HTML fillText).

        NEW: integer scale from ctx.font px size (measureText matches:
        width = len × 8 × scale)."""
        c = self.fill_style if color is None else (color & 0xFF)
        s = str(text)
        self.dirty = True
        k = max(1, int(scale))
        cw = CHAR_W * k
        px, py = int(x), int(y)
        if align == "center":
            px -= (len(s) * cw) // 2
        elif align == "right":
            px -= len(s) * cw
        py -= 8 * k
        back = self.back
        w = self.width
        for i, ch in enumerate(s):
            bits = glyph(ch if len(ch) == 1 else "?")
            x0 = px + i * cw
            for dy, byte in enumerate(bits):
                for ry in range(k):
                    yy = py + dy * k + ry
                    if yy < 0 or yy >= self.height:
                        continue
                    row = yy * w
                    for dx in range(8):
                        if not (byte & (1 << (7 - dx))):
                            continue
                        xb = x0 + dx * k
                        for rx in range(k):
                            xx = xb + rx
                            if 0 <= xx < w:
                                back[row + xx] = c

    def blit_indexed(
        self,
        pix: bytes,
        iw: int,
        ih: int,
        sx: int,
        sy: int,
        sw: int,
        sh: int,
        dx: int,
        dy: int,
        dw: int,
        dh: int,
    ) -> None:
        """Nearest-neighbor blit; skip index 0 (transparent)."""
        if sw <= 0 or sh <= 0 or dw <= 0 or dh <= 0 or iw <= 0 or ih <= 0:
            return
        self.dirty = True
        back = self.back
        w = self.width
        h = self.height
        for yy in range(int(dh)):
            fy = int(dy) + yy
            if fy < 0 or fy >= h:
                continue
            src_y = int(sy) + yy * int(sh) // int(dh)
            if src_y < 0 or src_y >= ih:
                continue
            row = fy * w
            src_row = src_y * iw
            for xx in range(int(dw)):
                fx = int(dx) + xx
                if fx < 0 or fx >= w:
                    continue
                src_x = int(sx) + xx * int(sw) // int(dw)
                if src_x < 0 or src_x >= iw:
                    continue
                c = pix[src_row + src_x]
                if c:
                    back[row + fx] = c

    def fill_circle(
        self,
        cx: int,
        cy: int,
        r: int,
        color: int | None = None,
        stroke: bool = False,
        a0: float | None = None,
        a1: float | None = None,
        ccw: bool = False,
    ) -> None:
        """Filled or 1px-outline circle / pie (PACMAN beans / ghosts / mouth).

        NEW: a0/a1 = canvas arc start/end angles (radians, y-down like
        Canvas2D). None = full circle. Pie test matches the arc sweep
        direction (ccw flag) so Pac-Man's mouth animates like Chrome.
        """
        import math

        c = self.fill_style if color is None else (color & 0xFF)
        if r <= 0:
            return
        self.dirty = True
        r2 = r * r
        r_in = (r - 1) * (r - 1) if stroke else -1
        two_pi = 2 * math.pi
        angular = a0 is not None and a1 is not None
        if angular:
            if ccw:
                sweep = (a0 - a1) % two_pi
            else:
                sweep = (a1 - a0) % two_pi
            if sweep == 0:
                sweep = two_pi  # e.g. (0, 2π) exact wrap
        back = self.back
        w = self.width
        for yy in range(cy - r, cy + r + 1):
            if yy < 0 or yy >= self.height:
                continue
            dy = yy - cy
            row = yy * w
            for xx in range(cx - r, cx + r + 1):
                if xx < 0 or xx >= w:
                    continue
                dx = xx - cx
                d2 = dy * dy + dx * dx
                if d2 > r2 or (stroke and d2 < r_in):
                    continue
                if angular and d2 > 0:
                    theta = math.atan2(dy, dx)  # y-down = canvas angles
                    if ccw:
                        off = (a0 - theta) % two_pi
                    else:
                        off = (theta - a0) % two_pi
                    if off > sweep:
                        continue
                back[row + xx] = c
