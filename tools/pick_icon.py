#!/usr/bin/env python3
"""Pick a 32×32 desktop icon from a title's own sprites.

Writes storage/NAME.ICON (a PNG the card builder already accepts). The
card stores it as NAME.ICN. A title with no picture yet is asked here,
from `make_sd_image.py create` or directly:

  python3 tools/pick_icon.py

Each choice is a piece of that title's .ARTX, nearest-neighbor fitted
into 32×32. A title with no picture, including a markdown file, is
offered the built-in pictures: line art, the color Macintosh sheet, and
scene pictures. If a markdown file is still without an icon when the
card is built, it gets the text document. Nothing here is named after a
particular game.

  python3 tools/pick_icon.py -reicon

asks again for every program. K keeps the icon already on that file.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from functional_model.desktop_icons import ICON_SIZE, generic_pixel  # noqa: E402

STORAGE = ROOT / "storage"
# Same names tools/desktop_icons.py treats as artwork, not sprite sheets.
_ICON_SUFFIXES = (".ICN", ".ICO", ".ICONS", ".ICON", ".ICON.PNG", ".ICON.ICO")
_MAX_CHOICES = 8


def icon_sources(storage_dir: Path) -> dict[str, Path]:
    """Uppercase filename -> path, for root artwork and storage/icons/."""
    found: dict[str, Path] = {}
    if not storage_dir.is_dir():
        return found
    folders = [storage_dir]
    icons = storage_dir / "icons"
    if icons.is_dir():
        folders.append(icons)
    for folder in folders:
        for path in folder.iterdir():
            if path.is_file() and not path.name.startswith("."):
                found[path.name.upper()] = path
    return found


def has_icon(storage_dir: Path, html: Path, sources: dict[str, Path] | None = None) -> bool:
    names = sources if sources is not None else icon_sources(storage_dir)
    stem = html.stem.upper()
    if any(stem + suffix in names for suffix in _ICON_SUFFIXES):
        return True
    # storage/icons/NAME.PNG is artwork. A root NAME.PNG is a sprite sheet.
    png = names.get(stem + ".PNG")
    return png is not None and png.parent.name == "icons"


def missing_html(storage_dir: Path, *, redo: bool = False) -> list[Path]:
    sources = icon_sources(storage_dir)
    out: list[Path] = []
    seen: set[str] = set()
    if not storage_dir.is_dir():
        return out
    for path in sorted(storage_dir.iterdir()):
        if not path.is_file():
            continue
        if path.suffix.upper() not in (".HTML", ".HTM", ".MD"):
            continue
        key = path.stem.upper()
        if key in seen or (not redo and has_icon(storage_dir, path, sources)):
            continue
        seen.add(key)
        out.append(path)
    return out


def current_icon_image(storage_dir: Path, html: Path):
    """The picture already saved for this file, or None if it cannot be read."""
    names = icon_sources(storage_dir)
    stem = html.stem.upper()
    path = None
    for suffix in _ICON_SUFFIXES:
        found = names.get(stem + suffix)
        if found is not None:
            path = found
            break
    if path is None:
        png = names.get(stem + ".PNG")
        if png is not None and png.parent.name == "icons":
            path = png
    if path is None:
        return None
    try:
        from PIL import Image

        return _fit32(Image.open(path).convert("RGBA"))
    except Exception:
        return None


def _rgb332(value: int, opaque: bool) -> tuple[int, int, int, int]:
    if not opaque:
        return (0, 0, 0, 0)
    return (value & 0xE0, (value & 0x1C) << 3, (value & 0x03) << 6, 255)


def generic_image():
    """The machine's generic application window, as a Pillow image."""
    from PIL import Image

    im = Image.new("RGBA", (ICON_SIZE, ICON_SIZE))
    im.putdata([_rgb332(*generic_pixel(x, y))
                for y in range(ICON_SIZE) for x in range(ICON_SIZE)])
    return im


_CLEAR = (0, 0, 0, 0)
_INK = (0, 0, 0, 255)
_PAPER = (255, 255, 255, 255)


def _canvas():
    from PIL import Image

    return Image.new("RGBA", (ICON_SIZE, ICON_SIZE), _CLEAR)


def _fill(im, x, y, w, h, color):
    px = im.load()
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px[xx, yy] = color


def _rect(im, x, y, w, h):
    """White rectangle, one-pixel black outline."""
    _fill(im, x, y, w, h, _PAPER)
    _fill(im, x, y, w, 1, _INK)
    _fill(im, x, y + h - 1, w, 1, _INK)
    _fill(im, x, y, 1, h, _INK)
    _fill(im, x + w - 1, y, 1, h, _INK)


def _box(im, x, y, w, h, fill, edge=_INK):
    """Filled rectangle with a one-pixel outline on its own border."""
    _fill(im, x, y, w, h, fill)
    _fill(im, x, y, w, 1, edge)
    _fill(im, x, y + h - 1, w, 1, edge)
    _fill(im, x, y, 1, h, edge)
    _fill(im, x + w - 1, y, 1, h, edge)


def _ink(im, x, y, w, h):
    _fill(im, x, y, w, h, _INK)


def text_icon_image():
    """Document with a folded corner and lines of text."""
    im = _canvas()
    x, y, w, h = 7, 3, 18, 26
    _rect(im, x, y, w, h)
    # Small dog-ear in the top-right. The page outline stays put.
    fold = 5
    px = im.load()
    for i in range(fold):
        px[x + w - fold + i, y + i] = _INK
    for i, width in enumerate((12, 9, 11, 8, 10)):
        _ink(im, x + 3, y + 9 + i * 3, width, 1)
    return im


def computer_icon_image():
    """Desktop computer: screen, face, disk slot, chin."""
    im = _canvas()
    _rect(im, 5, 2, 22, 26)
    _ink(im, 6, 20, 20, 1)
    _rect(im, 8, 5, 16, 11)
    _ink(im, 12, 8, 2, 2)
    _ink(im, 18, 8, 2, 2)
    _ink(im, 12, 12, 2, 1)
    _ink(im, 14, 13, 4, 1)
    _ink(im, 18, 12, 2, 1)
    _ink(im, 12, 22, 8, 2)
    _ink(im, 9, 28, 4, 2)
    _ink(im, 19, 28, 4, 2)
    return im


def folder_icon_image():
    im = _canvas()
    _rect(im, 6, 9, 20, 17)
    _ink(im, 6, 5, 10, 1)
    _ink(im, 6, 5, 1, 4)
    _ink(im, 15, 5, 1, 4)
    _fill(im, 7, 6, 8, 3, _PAPER)
    return im


def disk_icon_image():
    """Floppy disk."""
    im = _canvas()
    _rect(im, 6, 4, 20, 22)
    _rect(im, 9, 7, 14, 7)
    _fill(im, 10, 8, 12, 5, _INK)
    _fill(im, 14, 9, 4, 3, _PAPER)
    _ink(im, 9, 17, 14, 1)
    _ink(im, 9, 19, 10, 1)
    _ink(im, 9, 21, 12, 1)
    return im


def trash_icon_image():
    im = _canvas()
    _ink(im, 12, 3, 8, 1)
    _ink(im, 12, 3, 1, 4)
    _ink(im, 19, 3, 1, 4)
    _rect(im, 8, 6, 16, 4)
    _fill(im, 13, 6, 6, 1, _PAPER)
    _rect(im, 7, 10, 18, 16)
    for i in range(4):
        _ink(im, 10 + i * 3, 13, 1, 10)
    return im


def printer_icon_image():
    im = _canvas()
    _rect(im, 11, 2, 10, 9)
    _ink(im, 13, 4, 6, 1)
    _ink(im, 13, 6, 4, 1)
    _rect(im, 5, 9, 22, 16)
    _fill(im, 12, 9, 8, 1, _PAPER)
    _ink(im, 8, 15, 16, 1)
    _ink(im, 8, 18, 16, 1)
    _fill(im, 9, 16, 14, 2, _PAPER)
    return im


def case_icon_image():
    """Closed case with a handle."""
    im = _canvas()
    _rect(im, 5, 8, 22, 18)
    _ink(im, 12, 4, 8, 1)
    _ink(im, 12, 4, 1, 4)
    _ink(im, 19, 4, 1, 4)
    _rect(im, 13, 14, 6, 5)
    return im


_GREY = (192, 192, 192, 255)
_YELLOW = (224, 224, 0, 255)
_RED = (224, 0, 0, 255)
_GREEN = (0, 192, 0, 255)
_BLUE = (0, 0, 192, 255)
# RGB332 lattice, so the chooser preview matches the desktop.
_BEIGE = (224, 192, 128, 255)
_CREAM = (224, 224, 192, 255)
_NAVY = (0, 0, 128, 255)
_ORANGE = (224, 128, 0, 255)
_CYAN = (0, 224, 192, 255)
_MAGENTA = (224, 0, 192, 255)
_PINK = (224, 96, 128, 255)
_SKIN = (224, 160, 128, 255)
_BROWN = (160, 96, 0, 255)
_GOLD = (224, 192, 0, 255)
_SILVER = (192, 192, 192, 255)
_SCREEN = (0, 32, 64, 255)
_DK = (64, 64, 64, 255)
_LTBLUE = (64, 128, 192, 255)
_DKGREEN = (0, 96, 0, 255)
_MINT = (0, 224, 128, 255)
_OLIVE = (0, 64, 0, 255)


def _fill_poly(im, points, color):
    from PIL import ImageDraw

    ImageDraw.Draw(im).polygon(points, fill=color)


def _fill_disk(im, cx, cy, r, color):
    from PIL import ImageDraw

    ImageDraw.Draw(im).ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)


def _line(im, x0, y0, x1, y1, color=_INK):
    """One-pixel line. Game icons are black strokes on a light grey plate."""
    px = im.load()
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        if 0 <= x0 < ICON_SIZE and 0 <= y0 < ICON_SIZE:
            px[x0, y0] = color
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def _poly(im, points):
    for i, (x, y) in enumerate(points):
        nx, ny = points[(i + 1) % len(points)]
        _line(im, x, y, nx, ny)


def _circle(im, cx, cy, r, color=_INK):
    x = r
    y = 0
    err = 1 - r
    while x >= y:
        for px, py in (
            (cx + x, cy + y), (cx + x, cy - y), (cx - x, cy + y), (cx - x, cy - y),
            (cx + y, cy + x), (cx + y, cy - x), (cx - y, cy + x), (cx - y, cy - x),
        ):
            _line(im, px, py, px, py, color)
        y += 1
        if err < 0:
            err += 2 * y + 1
        else:
            x -= 1
            err += 2 * (y - x) + 1


def _field(im):
    """Light grey plate. Black drawing sits on it, the way the Mac icons do."""
    _fill(im, 4, 3, 24, 26, _GREY)


def asteroids_icon_image():
    """Rocks and a wedge ship. A picture to pick, not a filename test."""
    im = _canvas()
    _field(im)
    rock_a = [(7, 11), (12, 6), (17, 9), (15, 15), (9, 16), (6, 13)]
    rock_b = [(18, 7), (25, 8), (26, 14), (21, 16), (17, 12)]
    ship = [(14, 25), (20, 25), (17, 18)]
    _fill_poly(im, rock_a, (160, 160, 192, 255))
    _fill_poly(im, rock_b, (128, 160, 192, 255))
    _fill_poly(im, ship, _YELLOW)
    _poly(im, rock_a)
    _poly(im, rock_b)
    _poly(im, ship)
    return im


def pacman_icon_image():
    """A yellow mouth and a dot. A picture to pick, not a filename test."""
    im = _canvas()
    _field(im)
    _fill_disk(im, 13, 16, 8, _YELLOW)
    _fill_poly(im, [(13, 16), (22, 11), (22, 21)], _GREY)
    _circle(im, 13, 16, 8)
    _ink(im, 10, 12, 2, 2)
    _fill(im, 23, 15, 2, 2, _PAPER)
    _fill(im, 26, 15, 2, 2, _PAPER)
    return im


def missiles_icon_image():
    """Ground, cities, and a burst. A picture to pick, not a filename test."""
    im = _canvas()
    _field(im)
    _fill(im, 5, 24, 22, 4, _GREEN)
    _line(im, 5, 24, 26, 24)
    for x, h, color in ((7, 5, _BLUE), (13, 7, _YELLOW), (20, 5, _RED)):
        city = [(x, 24), (x + 2, 24 - h), (x + 4, 24)]
        _fill_poly(im, city, color)
        _poly(im, city)
    _line(im, 8, 6, 16, 15)
    _line(im, 24, 5, 16, 15)
    _fill_disk(im, 16, 13, 3, _RED)
    _circle(im, 16, 13, 3)
    return im


def tank_icon_image():
    """Top-down tank. A picture to pick, not a filename test."""
    im = _canvas()
    _field(im)
    _fill(im, 10, 12, 12, 11, _GREEN)
    _poly(im, [(10, 12), (21, 12), (21, 22), (10, 22)])
    _line(im, 8, 12, 8, 22)
    _line(im, 23, 12, 23, 22)
    _fill_disk(im, 15, 17, 3, _YELLOW)
    _circle(im, 15, 17, 3)
    _ink(im, 14, 7, 3, 10)
    return im


def ship_icon_image():
    """A lone wedge ship, for any vector game that is not a named picture."""
    im = _canvas()
    _field(im)
    hull = [(16, 6), (24, 24), (16, 19), (8, 24)]
    _fill_poly(im, hull, _BLUE)
    _poly(im, hull)
    _line(im, 16, 19, 16, 26, _RED)
    return im


def ball_icon_image():
    """A ball and a bat."""
    im = _canvas()
    _field(im)
    _fill_disk(im, 16, 12, 5, _RED)
    _circle(im, 16, 12, 5)
    _ink(im, 8, 24, 17, 2)
    return im


def star_icon_image():
    """A four-point star."""
    im = _canvas()
    _field(im)
    points = [(16, 5), (18, 14), (27, 16), (18, 18), (16, 27), (14, 18), (5, 16), (14, 14)]
    _fill_poly(im, points, _YELLOW)
    _poly(im, points)
    return im


def _frame(im):
    _fill(im, 0, 0, 32, 1, _INK)
    _fill(im, 0, 31, 32, 1, _INK)
    _fill(im, 0, 0, 1, 32, _INK)
    _fill(im, 31, 0, 1, 32, _INK)


def _ellipse(im, box, fill, outline=None):
    from PIL import ImageDraw

    ImageDraw.Draw(im).ellipse(box, fill=fill, outline=outline)


def _punch(im, cx, cy, r):
    """Cut a round hole back to transparent."""
    px = im.load()
    for yy in range(cy - r, cy + r + 1):
        for xx in range(cx - r, cx + r + 1):
            if 0 <= xx < ICON_SIZE and 0 <= yy < ICON_SIZE:
                if (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) <= r * r:
                    px[xx, yy] = _CLEAR


def _stamp(im, x, y, rows, color, scale=1):
    px = im.load()
    for gy, row in enumerate(rows):
        for gx, ch in enumerate(row):
            if ch != "#":
                continue
            for sy in range(scale):
                for sx in range(scale):
                    xx, yy = x + gx * scale + sx, y + gy * scale + sy
                    if 0 <= xx < ICON_SIZE and 0 <= yy < ICON_SIZE:
                        px[xx, yy] = color


_GLYPH_A = (" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #")
_GLYPH_I = ("###", " # ", " # ", " # ", " # ", " # ", "###")
_GLYPH_D = ("## ", "# #", "# #", "# #", "# #", "# #", "## ")
_GLYPH_Q = (" ### ", "#   #", "    #", "   # ", "  #  ", "     ", "  #  ")


def _page(im, x, y, w, h, paper=_CREAM):
    """Sheet of paper with an orange folded corner."""
    _box(im, x, y, w, h, paper)
    _fill_poly(im, [(x + w - 1, y), (x + w - 6, y), (x + w - 1, y + 5)], _ORANGE)
    _line(im, x + w - 6, y, x + w - 1, y + 5)


def _stars(im, points):
    px = im.load()
    for x, y in points:
        if 0 <= x < ICON_SIZE and 0 <= y < ICON_SIZE:
            px[x, y] = _CREAM


def _wedge(im, cx, cy, color=_YELLOW):
    """Ship pointing up, with a short flame."""
    hull = [(cx, cy - 8), (cx + 6, cy + 4), (cx, cy), (cx - 6, cy + 4)]
    _fill_poly(im, hull, color)
    _poly(im, hull)
    _fill_poly(im, [(cx - 2, cy + 3), (cx + 2, cy + 3), (cx, cy + 7)], _ORANGE)
    _fill(im, cx, cy + 3, 1, 3, _YELLOW)


def _ghost(im, cx, cy, color, eyes=_INK):
    _fill_disk(im, cx, cy - 2, 6, color)
    _fill(im, cx - 6, cy - 2, 13, 8, color)
    for dx in (-4, 0, 4):
        _fill_disk(im, cx + dx, cy + 6, 2, color)
    _fill(im, cx - 4, cy - 4, 3, 3, _CREAM)
    _fill(im, cx + 2, cy - 4, 3, 3, _CREAM)
    _fill(im, cx - 3, cy - 3, 2, 2, eyes)
    _fill(im, cx + 3, cy - 3, 2, 2, eyes)


def _tank_body(im, x, y, w, h, body, face):
    """Top-down tank. face is U, D, L, or R. (x, y) is the top-left."""
    if face in ("U", "D"):
        _fill(im, x, y + 2, 3, h - 4, _DK)
        _fill(im, x + w - 3, y + 2, 3, h - 4, _DK)
        for i in range(2, h - 4, 3):
            _fill(im, x, y + i, 3, 1, _INK)
            _fill(im, x + w - 3, y + i, 3, 1, _INK)
        _box(im, x + 3, y + 3, w - 6, h - 6, body)
        _fill_disk(im, x + w // 2, y + h // 2, 3, _GOLD)
        _circle(im, x + w // 2, y + h // 2, 3)
        if face == "U":
            _fill(im, x + w // 2 - 1, y, 3, h // 2, _DK)
        else:
            _fill(im, x + w // 2 - 1, y + h // 2, 3, h // 2, _DK)
    else:
        _fill(im, x + 2, y, w - 4, 3, _DK)
        _fill(im, x + 2, y + h - 3, w - 4, 3, _DK)
        for i in range(2, w - 4, 3):
            _fill(im, x + i, y, 1, 3, _INK)
            _fill(im, x + i, y + h - 3, 1, 3, _INK)
        _box(im, x + 3, y + 3, w - 6, h - 6, body)
        _fill_disk(im, x + w // 2, y + h // 2, 3, _GOLD)
        _circle(im, x + w // 2, y + h // 2, 3)
        if face == "L":
            _fill(im, x, y + h // 2 - 1, w // 2, 3, _DK)
        else:
            _fill(im, x + w // 2, y + h // 2 - 1, w // 2, 3, _DK)


def _burst(im, cx, cy):
    _fill_disk(im, cx, cy, 4, _ORANGE)
    _fill_disk(im, cx, cy, 2, _YELLOW)
    _circle(im, cx, cy, 4, _RED)
    for dx, dy in ((0, -6), (0, 6), (-6, 0), (6, 0), (-4, -4), (4, -4), (-4, 4), (4, 4)):
        _fill(im, cx + dx, cy + dy, 2, 2, _YELLOW)


# --- Color Macintosh sheet. Choices. A file name does not select one. ---


def smile_icon_image():
    """Beige computer with a face on the screen."""
    im = _canvas()
    _box(im, 6, 2, 20, 23, _BEIGE)
    _fill(im, 7, 3, 18, 1, _CREAM)
    _fill(im, 8, 5, 16, 11, _SCREEN)
    _fill(im, 9, 6, 6, 1, (0, 64, 64, 255))
    _fill(im, 11, 8, 2, 2, _CREAM)
    _fill(im, 18, 8, 2, 2, _CREAM)
    px = im.load()
    for x, y in ((11, 12), (12, 13), (13, 14), (14, 14), (15, 14), (16, 14), (17, 14), (18, 13), (19, 12)):
        px[x, y] = _CREAM
        px[x, y + 1] = _MINT
    _fill(im, 8, 17, 16, 1, (192, 160, 64, 255))
    _fill(im, 11, 19, 10, 2, _DK)
    _fill(im, 14, 19, 4, 2, _SCREEN)
    _fill(im, 8, 26, 5, 3, (192, 160, 64, 255))
    _fill(im, 19, 26, 5, 3, (192, 160, 64, 255))
    return im


def macintosh_icon_image():
    """Beige computer, dark screen, no face."""
    im = _canvas()
    _box(im, 6, 2, 20, 23, _BEIGE)
    _fill(im, 7, 3, 18, 1, _CREAM)
    _fill(im, 8, 5, 16, 11, _SCREEN)
    _fill(im, 9, 6, 14, 2, (0, 64, 128, 255))
    _fill(im, 18, 12, 4, 2, (0, 64, 64, 255))
    _fill(im, 8, 17, 16, 1, (192, 160, 64, 255))
    _fill(im, 10, 19, 12, 3, _DK)
    _fill(im, 12, 20, 8, 1, _SILVER)
    _fill(im, 9, 26, 4, 3, (192, 160, 64, 255))
    _fill(im, 19, 26, 4, 3, (192, 160, 64, 255))
    return im


def letter_icon_image():
    """Cream letter with blue lines."""
    im = _canvas()
    _page(im, 8, 2, 16, 26)
    for i, width in enumerate((10, 8, 10, 7, 9)):
        _fill(im, 11, 10 + i * 3, width, 1, _LTBLUE)
    return im


def picture_icon_image():
    """Page with a small landscape."""
    im = _canvas()
    _page(im, 7, 2, 18, 27)
    _fill(im, 10, 8, 12, 9, _LTBLUE)
    _fill_disk(im, 18, 11, 2, _YELLOW)
    _fill_poly(im, [(10, 17), (14, 12), (18, 17)], _GREEN)
    _fill_poly(im, [(14, 17), (19, 11), (22, 17)], _DKGREEN)
    for i, width in enumerate((10, 7)):
        _fill(im, 10, 20 + i * 3, width, 1, _LTBLUE)
    return im


def badge_icon_image():
    """Navy card with a hole and the letters ID."""
    im = _canvas()
    _box(im, 7, 3, 18, 26, _NAVY, edge=_GOLD)
    _punch(im, 16, 7, 2)
    _stamp(im, 9, 14, _GLYPH_I, _CREAM, 2)
    _stamp(im, 17, 14, _GLYPH_D, _CREAM, 2)
    return im


def ask_icon_image():
    """Navy card with a yellow question mark."""
    im = _canvas()
    _box(im, 7, 3, 18, 26, _NAVY, edge=_GOLD)
    _stamp(im, 10, 8, _GLYPH_Q, _YELLOW, 2)
    return im


def cards_icon_image():
    """Three offset index cards."""
    im = _canvas()
    for dx, color in ((0, _LTBLUE), (3, _PINK), (6, _CREAM)):
        _box(im, 5 + dx, 6 + dx, 16, 18, color)
        _fill(im, 8 + dx, 12 + dx, 10, 1, _BLUE)
        _fill(im, 8 + dx, 16 + dx, 7, 1, _BLUE)
    return im


def diamond_icon_image():
    """Diamond with a hand, the classic application picture."""
    im = _canvas()
    pts = [(16, 1), (30, 16), (16, 30), (2, 16)]
    _fill_poly(im, pts, _CREAM)
    _poly(im, pts)
    _fill(im, 13, 18, 8, 4, _BLUE)
    _fill(im, 13, 18, 8, 1, _INK)
    _fill(im, 14, 12, 6, 7, _SKIN)
    _fill(im, 14, 7, 2, 6, _SKIN)
    _fill(im, 16, 6, 2, 7, _SKIN)
    _fill(im, 18, 7, 2, 6, _SKIN)
    _fill(im, 11, 14, 3, 3, _SKIN)
    return im


def floppy_icon_image():
    """Black disk, silver shutter, blue label."""
    im = _canvas()
    _box(im, 7, 3, 18, 26, (32, 32, 32, 255), edge=_SILVER)
    _fill(im, 10, 4, 12, 8, _SILVER)
    _fill(im, 13, 6, 6, 4, _DK)
    _fill(im, 10, 15, 12, 10, _BLUE)
    _fill(im, 12, 17, 8, 1, _CREAM)
    _fill(im, 12, 20, 6, 1, _CREAM)
    _fill(im, 12, 23, 7, 1, _YELLOW)
    return im


def basket_icon_image():
    """Silver wastebasket."""
    im = _canvas()
    _fill(im, 11, 3, 10, 2, _DK)
    _box(im, 8, 6, 16, 4, _SILVER)
    _fill(im, 14, 7, 4, 2, _DK)
    _fill_poly(im, [(9, 11), (23, 11), (21, 28), (11, 28)], _SILVER)
    _poly(im, [(9, 11), (23, 11), (21, 28), (11, 28)])
    for x in (13, 16, 19):
        _line(im, x, 13, x - 1, 26, _DK)
    return im


def press_icon_image():
    """Beige printer with paper in the top."""
    im = _canvas()
    _page(im, 11, 1, 10, 12, _CREAM)
    _fill(im, 13, 4, 6, 1, _LTBLUE)
    _fill(im, 13, 6, 4, 1, _LTBLUE)
    _box(im, 4, 11, 24, 16, _BEIGE)
    _fill(im, 5, 12, 22, 2, _CREAM)
    _fill(im, 7, 17, 18, 3, _DK)
    _fill(im, 8, 18, 16, 1, _SCREEN)
    _fill(im, 8, 23, 3, 2, _RED)
    _fill(im, 14, 23, 3, 2, _GREEN)
    _fill(im, 20, 23, 3, 2, _YELLOW)
    return im


def bomb_icon_image():
    """Black bomb with an orange fuse."""
    im = _canvas()
    _line(im, 18, 10, 25, 4, _BROWN)
    _line(im, 19, 11, 26, 5, _BROWN)
    _fill(im, 24, 2, 2, 2, _YELLOW)
    _fill(im, 27, 4, 2, 2, _ORANGE)
    _fill(im, 22, 5, 2, 2, _YELLOW)
    _fill(im, 26, 8, 2, 2, _ORANGE)
    _fill_disk(im, 13, 19, 9, _INK)
    _fill_disk(im, 10, 16, 3, _SILVER)
    _circle(im, 13, 19, 9, _DK)
    return im


def cabinet_icon_image():
    """Two-drawer file with colored labels."""
    im = _canvas()
    _box(im, 6, 3, 20, 26, _BEIGE)
    _fill(im, 7, 4, 18, 1, _CREAM)
    _fill(im, 8, 6, 16, 1, _DK)
    _box(im, 8, 8, 16, 8, _CREAM, edge=_DK)
    _fill(im, 9, 9, 6, 2, _RED)
    _fill(im, 13, 14, 6, 1, _SILVER)
    _box(im, 8, 18, 16, 8, _CREAM, edge=_DK)
    _fill(im, 9, 19, 6, 2, _BLUE)
    _fill(im, 13, 24, 6, 1, _SILVER)
    return im


def pencil_icon_image():
    """Yellow pencil."""
    im = _canvas()
    _fill_poly(im, [(7, 22), (20, 8), (24, 12), (11, 26)], _YELLOW)
    _poly(im, [(7, 22), (20, 8), (24, 12), (11, 26)])
    _fill_poly(im, [(7, 22), (4, 28), (10, 26)], _DK)
    _fill_poly(im, [(5, 26), (4, 28), (7, 27)], _INK)
    _fill_poly(im, [(20, 8), (24, 4), (28, 8), (24, 12)], _PINK)
    _fill_poly(im, [(20, 8), (22, 6), (26, 10), (24, 12)], _SILVER)
    _poly(im, [(20, 8), (24, 4), (28, 8), (24, 12)])
    return im


def balloon_icon_image():
    """Speech balloon."""
    im = _canvas()
    _ellipse(im, (4, 4, 27, 22), _CREAM, _INK)
    _fill_poly(im, [(10, 18), (8, 28), (18, 18)], _CREAM)
    _line(im, 10, 18, 8, 28)
    _line(im, 8, 28, 18, 18)
    _fill(im, 9, 12, 3, 3, _LTBLUE)
    _fill(im, 14, 12, 3, 3, _ORANGE)
    _fill(im, 19, 12, 3, 3, _GREEN)
    return im


def papers_icon_image():
    """Stack of sheets."""
    im = _canvas()
    _box(im, 8, 10, 16, 18, _LTBLUE)
    _box(im, 6, 7, 16, 18, _PINK)
    _page(im, 4, 3, 16, 18)
    _fill(im, 7, 10, 9, 1, _LTBLUE)
    _fill(im, 7, 13, 7, 1, _LTBLUE)
    _fill(im, 7, 16, 8, 1, _LTBLUE)
    return im


def flag_icon_image():
    """Stack of sheets with a red flag."""
    im = papers_icon_image()
    _fill_poly(im, [(18, 4), (26, 7), (18, 10)], _RED)
    _poly(im, [(18, 4), (26, 7), (18, 10)])
    _fill(im, 17, 4, 2, 12, _DK)
    return im


def suitcase_icon_image():
    """Brown case with a gold A."""
    im = _canvas()
    _fill(im, 12, 4, 8, 2, _BROWN)
    _fill(im, 12, 4, 2, 5, _BROWN)
    _fill(im, 18, 4, 2, 5, _BROWN)
    _box(im, 4, 8, 24, 20, _BROWN)
    _fill(im, 5, 9, 22, 2, _ORANGE)
    _box(im, 11, 13, 10, 12, _CREAM, edge=_GOLD)
    _stamp(im, 13, 15, _GLYPH_A, _INK)
    return im


def tab_icon_image():
    """Blue folder."""
    im = _canvas()
    _box(im, 4, 8, 10, 5, _LTBLUE)
    _box(im, 4, 12, 24, 16, _BLUE)
    _fill(im, 5, 13, 22, 2, _LTBLUE)
    _fill(im, 8, 20, 12, 1, _CREAM)
    return im


def watch_icon_image():
    """Silver watch with a red second hand."""
    im = _canvas()
    _fill(im, 13, 1, 6, 6, _DK)
    _fill(im, 14, 2, 4, 4, _BROWN)
    _fill(im, 13, 25, 6, 6, _DK)
    _fill(im, 14, 26, 4, 4, _BROWN)
    _fill_disk(im, 16, 16, 10, _SILVER)
    _circle(im, 16, 16, 10)
    _fill_disk(im, 16, 16, 7, _CREAM)
    _circle(im, 16, 16, 7)
    _fill(im, 15, 10, 2, 2, _INK)
    _fill(im, 15, 20, 2, 2, _INK)
    _fill(im, 10, 15, 2, 2, _INK)
    _fill(im, 20, 15, 2, 2, _INK)
    _fill(im, 15, 12, 2, 5, _INK)
    _fill(im, 15, 15, 5, 2, _INK)
    _line(im, 16, 16, 21, 11, _RED)
    return im


def command_icon_image():
    """Key with an open command mark. Holes sit in the four loops."""
    im = _canvas()
    _box(im, 4, 4, 24, 24, _SILVER)
    _fill(im, 5, 5, 22, 2, _CREAM)
    # Four loops, then a thin cross. Holes are punched last so the cross cannot fill them.
    loops = ((10, 11), (22, 11), (10, 23), (22, 23))
    for cx, cy in loops:
        _fill_disk(im, cx, cy, 4, _INK)
    _fill(im, 10, 15, 12, 3, _INK)
    _fill(im, 15, 11, 3, 12, _INK)
    for cx, cy in loops:
        _fill_disk(im, cx, cy, 2, _SILVER)
    return im


def dog_icon_image():
    """Black scottie with a red collar."""
    im = _canvas()
    _fill_poly(im, [(22, 14), (29, 6), (26, 6), (23, 13)], _INK)
    _fill_poly(im, [(8, 15), (22, 13), (25, 18), (23, 23), (7, 23), (5, 18)], _INK)
    _fill_poly(im, [(5, 16), (3, 10), (7, 6), (14, 7), (15, 13), (11, 16)], _INK)
    _fill_poly(im, [(7, 7), (5, 2), (9, 2), (11, 7)], _INK)
    _fill(im, 8, 23, 3, 5, _INK)
    _fill(im, 14, 23, 3, 5, _INK)
    _fill(im, 20, 23, 3, 5, _INK)
    _fill(im, 9, 16, 4, 2, _RED)
    _fill(im, 11, 10, 2, 2, _CREAM)
    _fill(im, 11, 11, 1, 1, _INK)
    return im


def speaker_icon_image():
    """Beige speaker and cyan waves."""
    im = _canvas()
    _circle(im, 14, 16, 12, _CYAN)
    _circle(im, 14, 16, 9, _CYAN)
    _circle(im, 14, 16, 6, _MINT)
    _box(im, 3, 8, 12, 16, _BEIGE)
    _fill(im, 4, 9, 10, 2, _CREAM)
    _ellipse(im, (6, 12, 12, 20), _DK, _INK)
    _fill_disk(im, 9, 16, 2, _SILVER)
    return im


def hands_icon_image():
    """Two open hands."""
    im = _canvas()

    def hand(x):
        _fill_disk(im, x + 6, 20, 6, _INK)
        _fill(im, x + 2, 8, 3, 10, _INK)
        _fill(im, x + 5, 6, 3, 12, _INK)
        _fill(im, x + 8, 8, 3, 10, _INK)
        _fill(im, x, 16, 4, 3, _INK)
        _fill_disk(im, x + 6, 20, 4, _SKIN)
        _fill(im, x + 3, 9, 1, 8, _SKIN)
        _fill(im, x + 6, 7, 1, 10, _SKIN)
        _fill(im, x + 9, 9, 1, 8, _SKIN)
        _fill(im, x + 1, 17, 2, 1, _SKIN)

    hand(2)
    hand(17)
    return im


def eject_icon_image():
    """Arrow going into a drive slot."""
    im = _canvas()
    _box(im, 16, 8, 13, 16, _BEIGE)
    _fill(im, 18, 14, 9, 4, _DK)
    _fill(im, 19, 15, 7, 2, _SCREEN)
    _fill_poly(im, [(3, 14), (12, 14), (12, 11), (16, 16), (12, 21), (12, 18), (3, 18)], _INK)
    _fill_poly(im, [(4, 15), (11, 15), (11, 13), (14, 16), (11, 19), (11, 17), (4, 17)], _ORANGE)
    return im


# --- Scene pictures for titles that have no sheet to crop. ---
# Three of each subject. A file name does not select one.


def rocks_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _stars(im, ((3, 4), (27, 5), (6, 22), (28, 26)))
    rock = [(3, 16), (7, 6), (16, 8), (17, 15), (12, 20), (4, 18)]
    _fill_poly(im, rock, (96, 128, 128, 255))
    _poly(im, rock)
    _fill_poly(im, [(8, 8), (12, 7), (13, 12), (8, 12)], (160, 160, 192, 255))
    other = [(18, 4), (28, 6), (29, 14), (22, 16), (16, 10)]
    _fill_poly(im, other, (128, 96, 64, 255))
    _poly(im, other)
    _wedge(im, 16, 24)
    _frame(im)
    return im


def saucer_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _stars(im, ((4, 6), (26, 8), (7, 26)))
    _fill_poly(im, [(4, 8), (10, 4), (14, 9), (8, 14), (3, 12)], (96, 128, 128, 255))
    _poly(im, [(4, 8), (10, 4), (14, 9), (8, 14), (3, 12)])
    _ellipse(im, (6, 16, 26, 24), _SILVER, _INK)
    _ellipse(im, (11, 10, 21, 18), _RED, _INK)
    _fill(im, 15, 13, 2, 2, _YELLOW)
    _fill(im, 22, 26, 3, 2, _CYAN)
    _frame(im)
    return im


def thrust_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _stars(im, ((4, 5), (26, 7), (6, 16)))
    _fill_poly(im, [(20, 4), (29, 6), (28, 13), (22, 12), (19, 8)], (128, 128, 160, 255))
    _poly(im, [(20, 4), (29, 6), (28, 13), (22, 12), (19, 8)])
    hull = [(16, 6), (26, 22), (16, 17), (6, 22)]
    _fill_poly(im, hull, _YELLOW)
    _poly(im, hull)
    _fill_poly(im, [(12, 21), (16, 29), (20, 21)], _ORANGE)
    _fill_poly(im, [(14, 21), (16, 26), (18, 21)], _YELLOW)
    _fill(im, 15, 14, 2, 2, _RED)
    _frame(im)
    return im


def chomp_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _fill_disk(im, 10, 16, 7, _YELLOW)
    _fill_poly(im, [(10, 16), (18, 11), (18, 21)], _NAVY)
    _circle(im, 10, 16, 7)
    _fill(im, 8, 13, 2, 2, _INK)
    _ghost(im, 23, 16, _RED)
    _frame(im)
    return im


def ghost_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _fill_disk(im, 16, 14, 9, _RED)
    _fill(im, 7, 14, 19, 10, _RED)
    for dx in (-6, 0, 6):
        _fill_disk(im, 16 + dx, 23, 3, _RED)
    _fill(im, 10, 11, 4, 4, _CREAM)
    _fill(im, 18, 11, 4, 4, _CREAM)
    _fill(im, 12, 12, 2, 3, _BLUE)
    _fill(im, 20, 12, 2, 3, _BLUE)
    _fill(im, 5, 27, 2, 2, _CREAM)
    _fill(im, 25, 27, 2, 2, _CREAM)
    _frame(im)
    return im


def pellet_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _fill_disk(im, 9, 16, 6, _YELLOW)
    _fill_poly(im, [(9, 16), (16, 12), (16, 20)], _NAVY)
    _circle(im, 9, 16, 6)
    _fill(im, 7, 13, 2, 2, _INK)
    _fill_disk(im, 18, 16, 3, _CREAM)
    _ghost(im, 24, 16, _LTBLUE, eyes=_NAVY)
    _fill(im, 21, 18, 2, 1, _CREAM)
    _fill(im, 23, 19, 2, 1, _CREAM)
    _fill(im, 25, 18, 2, 1, _CREAM)
    _frame(im)
    return im


def cities_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _fill(im, 0, 23, 32, 9, _GREEN)
    _fill(im, 0, 23, 32, 1, _DKGREEN)
    for x, h, color in ((4, 7, _BLUE), (12, 10, _YELLOW), (21, 6, _RED)):
        city = [(x, 23), (x + 2, 23 - h), (x + 5, 23)]
        _fill_poly(im, city, color)
        _poly(im, city)
    _line(im, 6, 4, 15, 14, _CREAM)
    _line(im, 26, 3, 16, 14, _PINK)
    _burst(im, 16, 12)
    _frame(im)
    return im


def battery_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _fill(im, 0, 24, 32, 8, _DKGREEN)
    _fill_poly(im, [(12, 24), (16, 18), (20, 24)], _YELLOW)
    _poly(im, [(12, 24), (16, 18), (20, 24)])
    _line(im, 16, 17, 8, 6, _CREAM)
    _line(im, 16, 17, 16, 4, _CREAM)
    _line(im, 16, 17, 25, 5, _CREAM)
    _line(im, 4, 3, 14, 16, _RED)
    _fill_disk(im, 4, 3, 2, _ORANGE)
    _frame(im)
    return im


def skyline_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _fill(im, 0, 26, 32, 6, _DK)
    for x, h, color in ((2, 10, _LTBLUE), (8, 16, _BLUE), (15, 12, _SILVER), (22, 18, _DK), (27, 8, _LTBLUE)):
        _fill(im, x, 26 - h, 5, h, color)
        _fill(im, x, 26 - h, 5, 1, _CREAM)
    _burst(im, 17, 10)
    _fill_poly(im, [(4, 6), (10, 8), (4, 10)], _CREAM)
    _frame(im)
    return im


def turret_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _OLIVE)
    _tank_body(im, 6, 8, 20, 22, _GREEN, "U")
    _fill(im, 14, 2, 4, 4, _YELLOW)
    _fill(im, 15, 1, 2, 2, _CREAM)
    _frame(im)
    return im


def duel_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _OLIVE)
    _tank_body(im, 1, 8, 14, 16, _GREEN, "R")
    _tank_body(im, 17, 8, 14, 16, _RED, "L")
    _fill(im, 14, 14, 4, 2, _YELLOW)
    _frame(im)
    return im


def splatter_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _OLIVE)
    _tank_body(im, 1, 14, 14, 16, _GREEN, "U")
    _burst(im, 22, 10)
    _fill(im, 16, 16, 2, 2, _DK)
    _fill(im, 26, 18, 2, 2, _SILVER)
    _fill(im, 20, 20, 2, 2, _DK)
    _frame(im)
    return im


def curtain_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, (0, 0, 64, 255))
    for x, color in ((2, _MINT), (8, _MAGENTA), (14, _CYAN), (20, _YELLOW), (26, _PINK)):
        _fill(im, x, 2, 5, 18, color)
    _fill(im, 4, 24, 24, 4, _CREAM)
    _fill(im, 8, 25, 4, 2, _CYAN)
    _fill(im, 20, 25, 4, 2, _MAGENTA)
    _frame(im)
    return im


def catch_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, (0, 0, 64, 255))
    for x, color in ((1, _MINT), (8, _PINK), (16, _CYAN), (24, _MAGENTA)):
        _fill(im, x, 2, 7, 6, color)
    _stars(im, ((6, 14), (24, 16), (12, 18)))
    _fill(im, 13, 12, 8, 8, _PINK)
    _fill(im, 15, 14, 3, 3, _CREAM)
    _fill(im, 6, 24, 20, 4, _CREAM)
    _fill(im, 4, 26, 24, 2, _CYAN)
    _frame(im)
    return im


def gems_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, (0, 0, 64, 255))
    _fill(im, 0, 2, 32, 4, _MINT)
    _fill(im, 6, 8, 6, 6, _PINK)
    _fill(im, 8, 10, 2, 2, _CREAM)
    _fill(im, 18, 12, 5, 5, _YELLOW)
    _fill(im, 12, 16, 4, 4, _CYAN)
    _fill(im, 5, 24, 22, 4, _CREAM)
    _frame(im)
    return im


def red_blue_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _INK)
    _fill(im, 3, 8, 12, 16, _RED)
    _fill(im, 17, 8, 12, 16, _BLUE)
    _frame(im)
    return im


def overlap_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _INK)
    _fill(im, 2, 4, 18, 16, _RED)
    _fill(im, 12, 12, 17, 16, _BLUE)
    _fill(im, 12, 12, 8, 8, _MAGENTA)
    _frame(im)
    return im


def pair_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _INK)
    _fill(im, 5, 12, 11, 13, _DK)
    _box(im, 3, 8, 12, 14, _RED)
    _fill(im, 18, 12, 11, 13, _DK)
    _box(im, 16, 8, 12, 14, _BLUE)
    _frame(im)
    return im


_SWATCH = (
    _RED, _GREEN, _BLUE, _YELLOW,
    _CYAN, _MAGENTA, _ORANGE, (128, 224, 0, 255),
    (0, 128, 192, 255), (224, 0, 128, 255), (128, 0, 192, 255), (0, 224, 128, 255),
    (192, 64, 0, 255), (64, 128, 192, 255), (224, 128, 192, 255), (128, 192, 64, 255),
)


def _swatches(im, origin, cell, gap, colors, mark=None):
    for i, color in enumerate(colors):
        x = origin + (i % 4) * (cell + gap)
        y = origin + (i // 4) * (cell + gap)
        _fill(im, x, y, cell, cell, color)
    if mark is None:
        return
    x = origin + (mark % 4) * (cell + gap) - 1
    y = origin + (mark // 4) * (cell + gap) - 1
    _fill(im, x, y, cell + 2, 1, _CREAM)
    _fill(im, x, y + cell + 1, cell + 2, 1, _CREAM)
    _fill(im, x, y, 1, cell + 2, _CREAM)
    _fill(im, x + cell + 1, y, 1, cell + 2, _CREAM)


def grid_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _INK)
    _swatches(im, 3, 5, 2, _SWATCH)
    _frame(im)
    return im


def mosaic_icon_image():
    im = _canvas()
    _swatches(im, 2, 7, 0, _SWATCH)
    _frame(im)
    return im


def swatch_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _INK)
    _swatches(im, 3, 5, 2, tuple(reversed(_SWATCH)), mark=5)
    _frame(im)
    return im


def sword_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, (48, 32, 32, 255))
    _fill(im, 0, 24, 32, 8, (96, 64, 32, 255))
    _fill_disk(im, 10, 12, 4, _SKIN)
    _fill(im, 7, 16, 6, 8, _BLUE)
    _fill(im, 8, 16, 4, 1, _GOLD)
    _fill(im, 18, 4, 2, 16, _SILVER)
    _fill(im, 15, 18, 8, 2, _GOLD)
    _fill(im, 18, 20, 2, 5, _BROWN)
    _fill_disk(im, 24, 22, 3, _GOLD)
    _punch(im, 24, 22, 1)
    _fill(im, 26, 21, 4, 2, _GOLD)
    _frame(im)
    return im


def arch_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, (64, 64, 64, 255))
    _box(im, 4, 6, 24, 22, (128, 128, 128, 255))
    _fill(im, 10, 12, 12, 16, _INK)
    _ellipse(im, (10, 8, 22, 18), _INK)
    _fill_disk(im, 16, 22, 3, _MINT)
    _fill(im, 14, 20, 4, 4, _GREEN)
    _fill_disk(im, 25, 8, 2, _GOLD)
    _frame(im)
    return im


def potion_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, (32, 0, 48, 255))
    _fill(im, 6, 6, 4, 3, _CREAM)
    _fill(im, 7, 4, 2, 3, _BROWN)
    _fill_disk(im, 8, 14, 5, _RED)
    _fill(im, 5, 10, 6, 4, _RED)
    _fill_disk(im, 20, 10, 3, _GOLD)
    _punch(im, 20, 10, 1)
    _fill(im, 22, 9, 6, 2, _GOLD)
    _fill(im, 25, 11, 2, 2, _GOLD)
    _fill_poly(im, [(14, 24), (18, 18), (22, 24), (18, 28)], _CYAN)
    _poly(im, [(14, 24), (18, 18), (22, 24), (18, 28)])
    _frame(im)
    return im


def amp_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _INK)
    _circle(im, 12, 16, 13, _MINT)
    _circle(im, 12, 16, 10, _GREEN)
    _circle(im, 12, 16, 7, _MINT)
    _box(im, 2, 6, 14, 20, (32, 64, 32, 255))
    _ellipse(im, (5, 10, 13, 22), _DK, _MINT)
    _fill_disk(im, 9, 16, 2, _MINT)
    _frame(im)
    return im


def notes_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _fill(im, 8, 6, 2, 16, _YELLOW)
    _fill(im, 20, 4, 2, 16, _MINT)
    _fill(im, 8, 6, 14, 3, _YELLOW)
    _ellipse(im, (4, 18, 12, 26), _YELLOW, _INK)
    _ellipse(im, (16, 16, 24, 24), _MINT, _INK)
    _frame(im)
    return im


def wave_icon_image():
    im = _canvas()
    _box(im, 2, 4, 28, 24, _NAVY)
    _fill(im, 3, 5, 26, 3, _DK)
    _fill(im, 5, 6, 3, 1, _RED)
    _fill(im, 9, 6, 3, 1, _YELLOW)
    pts = ((5, 18), (9, 12), (13, 20), (17, 10), (21, 16), (25, 13))
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        _line(im, x0, y0, x1, y1, _MINT)
    _fill(im, 24, 12, 2, 2, _YELLOW)
    _frame(im)
    return im


def stick_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _ellipse(im, (6, 18, 26, 30), _DK, _INK)
    _fill(im, 14, 12, 4, 10, _SILVER)
    _fill_disk(im, 16, 10, 5, _RED)
    _circle(im, 16, 10, 5)
    _fill_disk(im, 23, 22, 2, _YELLOW)
    _frame(im)
    return im


def pad_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _ellipse(im, (2, 6, 30, 28), _DK, _INK)
    _fill(im, 6, 13, 14, 6, _INK)
    _fill(im, 10, 9, 6, 14, _INK)
    _fill(im, 8, 15, 4, 2, _SILVER)
    _fill(im, 14, 11, 2, 4, _SILVER)
    _fill_disk(im, 23, 16, 3, _RED)
    _circle(im, 23, 16, 3)
    _frame(im)
    return im


def tilt_icon_image():
    im = _canvas()
    _fill(im, 0, 0, 32, 32, _NAVY)
    _ellipse(im, (4, 20, 24, 31), _DK, _INK)
    _line(im, 12, 24, 20, 10, _SILVER)
    _line(im, 13, 24, 21, 10, _SILVER)
    _line(im, 14, 24, 22, 10, _DK)
    _fill_disk(im, 22, 8, 5, _RED)
    _circle(im, 22, 8, 5)
    _fill(im, 6, 12, 3, 2, _YELLOW)
    _fill(im, 4, 15, 2, 2, _ORANGE)
    _fill_disk(im, 16, 24, 2, _YELLOW)
    _frame(im)
    return im


def more_images() -> list[tuple[str, object]]:
    """Color Macintosh pictures, then scenes.

    Offered with the line-art set when a title has no sheet to crop.
    Nothing here looks at a file name.
    """
    return [
        ("Smile", smile_icon_image()),
        ("Picture", picture_icon_image()),
        ("Badge", badge_icon_image()),
        ("Ask", ask_icon_image()),
        ("Cards", cards_icon_image()),
        ("Mac", macintosh_icon_image()),
        ("Letter", letter_icon_image()),
        ("Diamond", diamond_icon_image()),
        ("Floppy", floppy_icon_image()),
        ("Basket", basket_icon_image()),
        ("Press", press_icon_image()),
        ("Bomb", bomb_icon_image()),
        ("Cabinet", cabinet_icon_image()),
        ("Pencil", pencil_icon_image()),
        ("Balloon", balloon_icon_image()),
        ("Papers", papers_icon_image()),
        ("Flag", flag_icon_image()),
        ("Suitcase", suitcase_icon_image()),
        ("Tab", tab_icon_image()),
        ("Watch", watch_icon_image()),
        ("Command", command_icon_image()),
        ("Dog", dog_icon_image()),
        ("Speaker", speaker_icon_image()),
        ("Hands", hands_icon_image()),
        ("Eject", eject_icon_image()),
        ("Rocks", rocks_icon_image()),
        ("Saucer", saucer_icon_image()),
        ("Thrust", thrust_icon_image()),
        ("Chomp", chomp_icon_image()),
        ("Ghost", ghost_icon_image()),
        ("Pellet", pellet_icon_image()),
        ("Cities", cities_icon_image()),
        ("Battery", battery_icon_image()),
        ("Skyline", skyline_icon_image()),
        ("Turret", turret_icon_image()),
        ("Duel", duel_icon_image()),
        ("Splatter", splatter_icon_image()),
        ("Curtain", curtain_icon_image()),
        ("Catch", catch_icon_image()),
        ("Gems", gems_icon_image()),
        ("Red blue", red_blue_icon_image()),
        ("Overlap", overlap_icon_image()),
        ("Pair", pair_icon_image()),
        ("Grid", grid_icon_image()),
        ("Mosaic", mosaic_icon_image()),
        ("Swatch", swatch_icon_image()),
        ("Sword", sword_icon_image()),
        ("Arch", arch_icon_image()),
        ("Potion", potion_icon_image()),
        ("Amp", amp_icon_image()),
        ("Notes", notes_icon_image()),
        ("Wave", wave_icon_image()),
        ("Stick", stick_icon_image()),
        ("Pad", pad_icon_image()),
        ("Tilt", tilt_icon_image()),
    ]


def stock_images() -> list[tuple[str, object]]:
    """Icons offered when a title has no picture of its own.

    Line art, then the color Macintosh sheet, then scene pictures.
    Nothing here looks at a file name.
    """
    return [
        ("Text", text_icon_image()),
        ("Computer", computer_icon_image()),
        ("Folder", folder_icon_image()),
        ("Disk", disk_icon_image()),
        ("Trash", trash_icon_image()),
        ("Printer", printer_icon_image()),
        ("Case", case_icon_image()),
        ("Generic", generic_image()),
        ("Asteroids", asteroids_icon_image()),
        ("Pac-Man", pacman_icon_image()),
        ("Missiles", missiles_icon_image()),
        ("Tank", tank_icon_image()),
        ("Ship", ship_icon_image()),
        ("Ball", ball_icon_image()),
        ("Star", star_icon_image()),
        *more_images(),
    ]


def markdown_icon_files(programs: list[str]) -> list[tuple[str, bytes]]:
    """Card sidecars: every markdown file wears the text document icon."""
    from io import BytesIO

    from functional_model.desktop_icons import icon_card_name
    from tools.desktop_icons import convert_icon

    blob = None
    out = {}
    for program in programs:
        if Path(program).suffix.upper() != ".MD":
            continue
        if blob is None:
            raw = BytesIO()
            text_icon_image().save(raw, "PNG")
            blob = convert_icon(raw.getvalue())
        out[icon_card_name(program)] = blob
    return sorted(out.items())


def _fit32(im):
    """Center a sprite in 32×32. Integer scale when it fits, else nearest."""
    from PIL import Image

    box = im.getbbox()
    if box:
        im = im.crop(box)
    w, h = im.size
    if w < 1 or h < 1:
        return Image.new("RGBA", (ICON_SIZE, ICON_SIZE))
    scale = 1
    while (scale + 1) * w <= 30 and (scale + 1) * h <= 30:
        scale += 1
    if w <= 30 and h <= 30:
        im = im.resize((w * scale, h * scale), Image.Resampling.NEAREST)
    else:
        factor = 30 / max(w, h)
        im = im.resize((max(1, int(w * factor)), max(1, int(h * factor))),
                       Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (ICON_SIZE, ICON_SIZE))
    canvas.paste(im, ((ICON_SIZE - im.width) // 2, (ICON_SIZE - im.height) // 2), im)
    return canvas


def _gutter_rects(w: int, h: int, pix: bytes) -> list[tuple[int, int, int, int]]:
    """Split a sheet on fully empty rows and columns. Returns x, y, w, h."""
    rects: list[tuple[int, int, int, int]] = []
    y = 0
    while y < h:
        while y < h and not any(pix[y * w:(y + 1) * w]):
            y += 1
        if y >= h:
            break
        y0 = y
        while y < h and any(pix[y * w:(y + 1) * w]):
            y += 1
        x = 0
        while x < w:
            if not any(pix[yy * w + x] for yy in range(y0, y)):
                x += 1
                continue
            x0 = x
            while x < w and any(pix[yy * w + x] for yy in range(y0, y)):
                x += 1
            rects.append((x0, y0, x - x0, y - y0))
    return rects


def _blobs(w: int, pix: bytes, rect: tuple[int, int, int, int]) -> list[tuple[int, int, int, int]]:
    """Separate a packed sheet into solid shapes. Coordinates are sheet-absolute."""
    x0, y0, rw, rh = rect
    stride = 2 if max(rw, rh) > 160 else 1
    gw = (rw + stride - 1) // stride
    gh = (rh + stride - 1) // stride
    mask = bytearray(gw * gh)
    for gy in range(gh):
        sy = y0 + min(rh - 1, gy * stride)
        row = sy * w
        for gx in range(gw):
            sx = x0 + min(rw - 1, gx * stride)
            if pix[row + sx]:
                mask[gy * gw + gx] = 1
    seen = bytearray(gw * gh)
    found: list[tuple[int, int, int, int, int]] = []
    for start in range(gw * gh):
        if not mask[start] or seen[start]:
            continue
        stack = [start]
        seen[start] = 1
        minx = maxx = start % gw
        miny = maxy = start // gw
        count = 0
        while stack:
            i = stack.pop()
            count += 1
            gx, gy = i % gw, i // gw
            if gx < minx:
                minx = gx
            if gx > maxx:
                maxx = gx
            if gy < miny:
                miny = gy
            if gy > maxy:
                maxy = gy
            if gx > 0 and mask[i - 1] and not seen[i - 1]:
                seen[i - 1] = 1
                stack.append(i - 1)
            if gx + 1 < gw and mask[i + 1] and not seen[i + 1]:
                seen[i + 1] = 1
                stack.append(i + 1)
            if gy > 0 and mask[i - gw] and not seen[i - gw]:
                seen[i - gw] = 1
                stack.append(i - gw)
            if gy + 1 < gh and mask[i + gw] and not seen[i + gw]:
                seen[i + gw] = 1
                stack.append(i + gw)
        bw = maxx - minx + 1
        bh = maxy - miny + 1
        if count >= 12 and 4 <= max(bw, bh) <= 100:
            found.append((
                x0 + minx * stride,
                y0 + miny * stride,
                min(rw - minx * stride, bw * stride + stride),
                min(rh - miny * stride, bh * stride + stride),
                count,
            ))
    found.sort(key=lambda item: item[4], reverse=True)
    return [item[:4] for item in found[:24]]


def _crop_image(pal, sheet_w: int, pix: bytes, rect: tuple[int, int, int, int]):
    from PIL import Image

    x, y, rw, rh = rect
    if rw < 4 or rh < 4 or rw > 240 or rh > 200:
        return None
    data = []
    opaque = 0
    for yy in range(y, y + rh):
        base = yy * sheet_w + x
        for value in pix[base:base + rw]:
            if value == 0:
                data.append((0, 0, 0, 0))
            else:
                r, g, b = pal[value]
                data.append((r, g, b, 255))
                opaque += 1
    if opaque < 20 or opaque > rw * rh * 0.92:
        return None
    return _fit32(Image.frombytes("RGBA", (rw, rh), bytes(v for px in data for v in px)))


def candidates_for(html: Path) -> list:
    """Up to 8 distinct sprites from the title's .ARTX, largest-useful first."""
    artx = None
    for suffix in (".ARTX", ".ART"):
        path = html.with_suffix(suffix)
        if path.is_file():
            artx = path
            break
    if artx is None:
        return []
    from functional_model.jsb_format import read_artx

    palette, sprites, _payload = read_artx(artx.read_bytes())
    seen: set[bytes] = set()
    ranked: list[tuple[int, object]] = []
    for sheet_w, sheet_h, pix in sprites:
        if sheet_w < 4 or sheet_h < 4:
            continue
        zeros = pix.count(0)
        # A title card or backdrop has almost no transparent pixels.
        if zeros < sheet_w * sheet_h * 0.08:
            continue
        for rect in _gutter_rects(sheet_w, sheet_h, pix):
            pieces = [rect]
            if rect[2] > 96 or rect[3] > 96:
                pieces = _blobs(sheet_w, pix, rect) or pieces
            for piece in pieces:
                image = _crop_image(palette, sheet_w, pix, piece)
                if image is None:
                    continue
                key = image.tobytes()
                if key in seen:
                    continue
                seen.add(key)
                opaque = sum(1 for i in range(3, len(key), 4) if key[i])
                ranked.append((opaque, image))
    ranked.sort(key=lambda item: item[0], reverse=True)
    return [image for _score, image in ranked[:_MAX_CHOICES]]


def save_icon(html: Path, image) -> Path:
    dest = html.with_suffix(".ICON")
    image.save(dest, "PNG")
    print(f"note: {dest.name} (32x32, card name {html.stem[:8].upper()}.ICN)",
          file=sys.stderr)
    return dest


def _wants_window(*, force: bool = False) -> bool:
    if os.environ.get("PYTEST_CURRENT_TEST"):
        return False
    # -reicon is an explicit request, so a non-tty launcher may still open it.
    if not force and not sys.stdin.isatty():
        return False
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))


def pick_missing(storage_dir: Path, *, redo: bool = False) -> list[Path]:
    """Open the chooser for every HTML in storage_dir that has no icon yet.

    redo=True includes files that already have an icon. Keep leaves those
    files unchanged.
    """
    missing = missing_html(storage_dir, redo=redo)
    if not missing:
        print("note: every title already has an icon", file=sys.stderr)
        return []
    import tkinter as tk

    written: list[Path] = []

    root = tk.Tk()
    root.title("Desktop icons")
    body = tk.Frame(root)
    body.pack(padx=12, pady=12)
    state = {"i": 0, "busy": False, "photos": [], "done": set(), "canvas": None, "skip": None}

    def on_wheel(event) -> None:
        canvas = state.get("canvas")
        if canvas is None:
            return
        if getattr(event, "num", None) == 4 or getattr(event, "delta", 0) > 0:
            canvas.yview_scroll(-3, "units")
        else:
            canvas.yview_scroll(3, "units")

    root.bind_all("<Button-4>", on_wheel)
    root.bind_all("<Button-5>", on_wheel)
    root.bind_all("<MouseWheel>", on_wheel)

    def show() -> None:
        for child in body.winfo_children():
            child.destroy()
        state["photos"] = []
        state["canvas"] = None
        while state["i"] < len(missing) and state["i"] in state["done"]:
            state["i"] += 1
        index = state["i"]
        if index >= len(missing):
            root.destroy()
            return
        html = missing[index]
        step = len(state["done"]) + 1
        tk.Label(body, text=f"{html.name}    {step} / {len(missing)}",
                 font=("TkFixedFont", 16, "bold")).pack(anchor="w")
        tk.Label(body, text="Reading sprites…").pack(anchor="w")
        root.update_idletasks()
        choices = candidates_for(html)
        stock = [] if choices else stock_images()
        if stock:
            choices = [image for _name, image in stock]
        for child in body.winfo_children():
            child.destroy()
        tk.Label(body, text=f"{html.name}    {step} / {len(missing)}",
                 font=("TkFixedFont", 16, "bold")).pack(anchor="w")
        if stock:
            tk.Label(body, text="No picture for this title. Pick an icon.").pack(anchor="w")
        else:
            tk.Label(body, text="Click a sprite from this title, or Generic.").pack(anchor="w")
        generic = generic_image()
        current = current_icon_image(storage_dir, html) if has_icon(storage_dir, html) else None

        def use(image) -> None:
            if state["busy"]:
                return
            state["busy"] = True
            written.append(save_icon(html, image))
            state["done"].add(state["i"])
            state["i"] += 1
            state["busy"] = False
            show()

        def skip() -> None:
            if state["busy"]:
                return
            state["done"].add(state["i"])
            state["i"] += 1
            show()

        def as_photo(image):
            import base64
            from io import BytesIO
            from PIL import Image

            zoom = image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST)
            plate = Image.new("RGBA", zoom.size, (170, 170, 170, 255))
            plate.alpha_composite(zoom)
            raw = BytesIO()
            plate.convert("RGB").save(raw, "PNG")
            photo = tk.PhotoImage(data=base64.b64encode(raw.getvalue()))
            state["photos"].append(photo)
            return photo

        if current is not None:
            bar = tk.Frame(body)
            bar.pack(anchor="w", pady=4)
            tk.Button(bar, image=as_photo(current), text="Keep", compound="top",
                      command=skip).pack(side="left")
            tk.Label(bar, text="Already on this file. Keep leaves it.").pack(side="left", padx=8)

        cols = 4
        outer = tk.Frame(body)
        outer.pack(pady=8)
        row_count = max(1, (len(choices) + cols - 1) // cols)
        view_h = min(520, row_count * 168 + 8)
        canvas = tk.Canvas(outer, width=680, height=view_h, highlightthickness=0)
        scroll = tk.Scrollbar(outer, orient="vertical", command=canvas.yview)
        grid = tk.Frame(canvas)
        canvas.create_window((0, 0), window=grid, anchor="nw")
        grid.bind("<Configure>", lambda _event: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.configure(yscrollcommand=scroll.set)
        canvas.pack(side="left", fill="both")
        if row_count * 168 > view_h:
            scroll.pack(side="right", fill="y")
        state["canvas"] = canvas

        for number, image in enumerate(choices, start=1):
            label = f"{number} {stock[number - 1][0]}" if stock else str(number)
            button = tk.Button(grid, image=as_photo(image), text=label,
                               compound="top", font=("TkFixedFont", 8),
                               command=lambda image=image: use(image))
            button.grid(row=(number - 1) // cols, column=(number - 1) % cols, padx=6, pady=6)
        if not stock:
            generic_button = tk.Button(grid, image=as_photo(generic), text="Generic",
                                       compound="top", command=lambda: use(generic))
            generic_button.grid(row=2, column=0, columnspan=2, padx=6, pady=6, sticky="w")

        def generic_for_blanks() -> None:
            # One key for every remaining title that has no .ARTX. Titles
            # that do have sprites stay on screen so a picture can be chosen.
            # A file that already has an icon is left alone.
            if state["busy"]:
                return
            state["busy"] = True
            stay = None
            for j in range(state["i"], len(missing)):
                html_j = missing[j]
                has_art = html_j.with_suffix(".ARTX").is_file() or html_j.with_suffix(".ART").is_file()
                if has_art:
                    if stay is None:
                        stay = j
                    continue
                if has_icon(storage_dir, html_j):
                    state["done"].add(j)
                    continue
                written.append(save_icon(html_j, generic_image()))
                state["done"].add(j)
            state["busy"] = False
            state["i"] = len(missing) if stay is None else stay
            show()

        hint = ("Click an icon. Keys 1–8 are the first eight. G generic, A generic for the rest, Q quit"
                if stock else
                "Keys: 1–8 sprite, G generic, A generic for the rest with no sprites, Q quit")
        if current is not None:
            hint += ". K keeps this file's icon"
        if len(choices) > 8:
            hint += ". Scroll for more"
        tk.Label(body, text=hint).pack(anchor="w")
        state["choices"] = choices
        state["generic"] = generic
        state["blanks"] = generic_for_blanks
        state["skip"] = skip if current is not None else None

    def on_key(event) -> None:
        if state["busy"]:
            return
        key = event.keysym
        choices = state.get("choices") or []
        if key in "12345678":
            number = int(key) - 1
            if number < len(choices):
                # Reuse the button path: save that image.
                if state["busy"]:
                    return
                state["busy"] = True
                written.append(save_icon(missing[state["i"]], choices[number]))
                state["done"].add(state["i"])
                state["i"] += 1
                state["busy"] = False
                show()
        elif key.lower() == "g":
            state["busy"] = True
            written.append(save_icon(missing[state["i"]], state["generic"]))
            state["done"].add(state["i"])
            state["i"] += 1
            state["busy"] = False
            show()
        elif key.lower() == "k" and state.get("skip"):
            state["skip"]()
        elif key.lower() == "a":
            state["blanks"]()
        elif key.lower() == "q" or key == "Escape":
            root.destroy()

    root.bind_all("<Key>", on_key)
    root.protocol("WM_DELETE_WINDOW", root.destroy)
    show()
    root.update_idletasks()
    root.lift()
    try:
        root.attributes("-topmost", True)
        root.after(400, lambda: root.attributes("-topmost", False))
    except tk.TclError:
        pass
    root.mainloop()
    return written


def ensure_choice(storage_dir: Path, *, redo: bool = False) -> None:
    """From the card builder: ask when a display is attached, else leave a note.

    Headless and pytest runs do not open a window and do not invent files.
    The machine already draws the generic window when the sidecar is absent.
    redo=True asks again for every program. Without a display that is an
    error, so a card is not rebuilt as if the icons had been reviewed.
    """
    missing = missing_html(storage_dir, redo=redo)
    if not missing:
        return
    if not _wants_window(force=redo):
        if redo:
            raise SystemExit(
                "--reicon needs a display so each icon can be chosen again. "
                "The card was not rebuilt."
            )
        print(
            f"note: {len(missing)} title(s) have no desktop icon. "
            "python3 tools/pick_icon.py chooses a sprite, or a built-in icon when there is no picture.",
            file=sys.stderr,
        )
        return
    print(
        f"note: icon chooser for {len(missing)} program(s). "
        "K keeps the current picture. Q closes the chooser and the card build continues.",
        file=sys.stderr,
    )
    pick_missing(storage_dir, redo=redo)


def main(argv: list[str] | None = None) -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-reicon",
        "--reicon",
        action="store_true",
        help="choose again for every program; K keeps the icon already on that file",
    )
    args = parser.parse_args(argv)
    missing = missing_html(STORAGE, redo=args.reicon)
    if not missing:
        print("every title already has an icon")
        return
    if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        print(
            "No display is available, so the chooser cannot open. "
            "Run python3 tools/pick_icon.py from the desktop session.",
            file=sys.stderr,
        )
        raise SystemExit(1)
    if args.reicon:
        print(f"{len(missing)} title(s). A window is opening so each icon can be chosen again.",
              file=sys.stderr)
    else:
        print(f"{len(missing)} title(s) need an icon. A window is opening.", file=sys.stderr)
    pick_missing(STORAGE, redo=args.reicon)


if __name__ == "__main__":
    main()
