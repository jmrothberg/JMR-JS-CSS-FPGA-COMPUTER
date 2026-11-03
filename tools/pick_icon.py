#!/usr/bin/env python3
"""Pick a 32×32 desktop icon from a title's own sprites.

Writes storage/NAME.ICON (a PNG the card builder already accepts). The
card stores it as NAME.ICN. A title with no picture yet is asked here,
from `make_sd_image.py create` or directly:

  python3 tools/pick_icon.py

Each choice is a piece of that title's .ARTX, nearest-neighbor fitted
into 32×32. A title with no picture, including a markdown file, is
offered a small set of built-in icons. If a markdown file is still
without an icon when the card is built, it gets the text document.
Nothing here is named after a particular game.
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


def missing_html(storage_dir: Path) -> list[Path]:
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
        if key in seen or has_icon(storage_dir, path, sources):
            continue
        seen.add(key)
        out.append(path)
    return out


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


def _circle(im, cx, cy, r):
    x = r
    y = 0
    err = 1 - r
    while x >= y:
        for px, py in (
            (cx + x, cy + y), (cx + x, cy - y), (cx - x, cy + y), (cx - x, cy - y),
            (cx + y, cy + x), (cx + y, cy - x), (cx - y, cy + x), (cx - y, cy - x),
        ):
            _line(im, px, py, px, py)
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


def stock_images() -> list[tuple[str, object]]:
    """Icons offered when a title has no picture of its own.

    The line-art pictures are choices. Nothing here looks at a file name.
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


def _wants_window() -> bool:
    if os.environ.get("PYTEST_CURRENT_TEST"):
        return False
    if not sys.stdin.isatty():
        return False
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))


def pick_missing(storage_dir: Path) -> list[Path]:
    """Open the chooser for every HTML in storage_dir that has no icon yet."""
    missing = missing_html(storage_dir)
    if not missing:
        print("note: every title already has an icon", file=sys.stderr)
        return []
    import tkinter as tk

    written: list[Path] = []

    root = tk.Tk()
    root.title("Desktop icons")
    body = tk.Frame(root)
    body.pack(padx=12, pady=12)
    state = {"i": 0, "busy": False, "photos": [], "done": set()}

    def show() -> None:
        for child in body.winfo_children():
            child.destroy()
        state["photos"] = []
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
        grid = tk.Frame(body)
        grid.pack(pady=8)
        generic = generic_image()

        def use(image) -> None:
            if state["busy"]:
                return
            state["busy"] = True
            written.append(save_icon(html, image))
            state["done"].add(state["i"])
            state["i"] += 1
            state["busy"] = False
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

        for number, image in enumerate(choices, start=1):
            label = f"{number} {stock[number - 1][0]}" if stock else str(number)
            button = tk.Button(grid, image=as_photo(image), text=label,
                               compound="top", command=lambda image=image: use(image))
            button.grid(row=(number - 1) // 4, column=(number - 1) % 4, padx=6, pady=6)
        if not stock:
            generic_button = tk.Button(grid, image=as_photo(generic), text="Generic",
                                       compound="top", command=lambda: use(generic))
            generic_button.grid(row=2, column=0, columnspan=2, padx=6, pady=6, sticky="w")

        def generic_for_blanks() -> None:
            # One key for every remaining title that has no .ARTX. Titles
            # that do have sprites stay on screen so a picture can be chosen.
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
                written.append(save_icon(html_j, generic_image()))
                state["done"].add(j)
            state["busy"] = False
            state["i"] = len(missing) if stay is None else stay
            show()

        tk.Label(
            body,
            text=("Click an icon. Keys 1–8 are the first eight. G generic, A generic for the rest, Q quit"
                  if stock else
                  "Keys: 1–8 sprite, G generic, A generic for the rest with no sprites, Q quit"),
        ).pack(anchor="w")
        state["choices"] = choices
        state["generic"] = generic
        state["blanks"] = generic_for_blanks

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
        elif key.lower() == "a":
            state["blanks"]()
        elif key.lower() == "q" or key == "Escape":
            root.destroy()

    root.bind_all("<Key>", on_key)
    root.protocol("WM_DELETE_WINDOW", root.destroy)
    show()
    root.mainloop()
    return written


def ensure_choice(storage_dir: Path) -> None:
    """From the card builder: ask when a display is attached, else leave a note.

    Headless and pytest runs do not open a window and do not invent files.
    The machine already draws the generic window when the sidecar is absent.
    """
    missing = missing_html(storage_dir)
    if not missing:
        return
    if not _wants_window():
        print(
            f"note: {len(missing)} title(s) have no desktop icon. "
            "python3 tools/pick_icon.py chooses a sprite, or a built-in icon when there is no picture.",
            file=sys.stderr,
        )
        return
    pick_missing(storage_dir)


def main() -> None:
    missing = missing_html(STORAGE)
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
    print(f"{len(missing)} title(s) need an icon. A window is opening.", file=sys.stderr)
    pick_missing(STORAGE)


if __name__ == "__main__":
    main()
