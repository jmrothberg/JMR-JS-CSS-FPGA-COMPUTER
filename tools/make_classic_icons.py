"""Draw the classic 1984-style application and document icons.

    python3 tools/make_classic_icons.py               # write storage/*.ICON
    python3 tools/make_classic_icons.py --preview DIR # also DIR/NAME.png x8

Applications (black and white, after the original Macintosh):
  (macpaint() and macwrite() are drawings only; the card keeps the
  original hand-drawn storage/MACPAINT.ICON and MACWRITE.ICON)

Documents (a page with a folded top-right corner, the Mac way):
  PNTDOC    a MacPaint picture: a painted stroke and a small brush
  WRTDOC    a MacWrite document: lines of text and a small pen nib
  BASDOC    a TRS-80 BASIC program: a numbered listing (10, 20, 30, 40)
  TXTDOC    a note (.TXT): Note's cream page with blue lines

Each file is a 32x32 RGBA PNG saved as storage/NAME.ICON; the card builder
converts it to NAME.ICN (docs/DESKTOP_ICONS.md). Finder's DOCS table names
the document icon stems. Everything is drawn from the shapes below, so the
output is the same on every run.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
N = 32
CLEAR, WHITE, BLACK = None, 1, 0


class Canvas:
    def __init__(self):
        self.px = [[CLEAR] * N for _ in range(N)]

    def set(self, x, y, v):
        if 0 <= x < N and 0 <= y < N:
            self.px[y][x] = v

    def shape(self, inside, fill=WHITE, outline=BLACK):
        """Fill a region and draw its edge: an inside pixel with a
        4-neighbour outside is edge. Later shapes draw over earlier ones, so
        overlapping parts (fingers, thumb) keep their own outlines."""
        ins = [[inside(x + 0.5, y + 0.5) for x in range(N)] for y in range(N)]

        def at(x, y):
            if 0 <= x < N and 0 <= y < N:
                return ins[y][x]
            return inside(x + 0.5, y + 0.5)

        for y in range(N):
            for x in range(N):
                if not ins[y][x]:
                    continue
                edge = not (at(x - 1, y) and at(x + 1, y) and at(x, y - 1) and at(x, y + 1))
                v = outline if edge else fill
                if v is not None:
                    self.px[y][x] = v

    def image(self):
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for y in range(N):
            for x in range(N):
                v = self.px[y][x]
                if v is not None:
                    if isinstance(v, tuple):
                        im.putpixel((x, y), v + (255,))
                        continue
                    c = 255 if v == WHITE else 0
                    im.putpixel((x, y), (c, c, c, 255))
        return im


def diamond_page(c, cx=12, cy=12, r=11):
    """The page on the diagonal: a square turned 45 degrees."""
    c.shape(lambda x, y: abs(x - 0.5 - cx) + abs(y - 0.5 - cy) <= r + 0.1)


# The hand sits in the bottom-right corner with its origin at (OX, OY). The
# tool lies on the diagonal through it: d = x - y across the tool (0..2 is
# the pen's barrel), s = x + y along it (negative toward the tip).
OX, OY = 17, 11
# The lower-right edge of the curled fingers, by row: two knuckles.
FINGERS = {12: 14, 13: 13, 14: 13, 15: 13, 16: 12, 17: 11}


def hand_inside(x, y):
    x, y = math.floor(x) - OX, math.floor(y) - OY
    if not (1 <= y <= 17 and 1 <= x <= 14):
        return False
    if x - y > 5:                       # the index finger lies along the tool
        return False
    if y == 1 and x > 4:
        return False
    if y >= 14 and x < 2:
        return False
    return x <= FINGERS.get(y, 14)


def hand(c):
    """A right hand from the bottom of the icon: fist, thumb crease, the
    creases between the curled fingers, and the cuff."""
    c.shape(hand_inside)
    c.shape(lambda x, y: 1 <= math.floor(x) - OX <= 12
            and 18 <= math.floor(y) - OY <= 20)
    for x, y in ((2, 5), (2, 6), (3, 7), (3, 8), (4, 9), (5, 10), (6, 10),
                 (7, 10), (11, 13), (12, 13), (10, 16), (11, 16)):
        c.set(OX + x, OY + y, BLACK)


def tool(c, part):
    """Paint the tool over the hand: part(s, d) gives the pixel or None."""
    for y in range(N):
        for x in range(N):
            if x > OX + 14 or y > OY + 14:
                continue
            v = part(x - OX + y - OY, x - OX - (y - OY))
            if v is not None:
                c.set(x, y, v)


def pen(s, d):
    """A fountain pen: a pointed nib, then the black barrel."""
    if s < -8:
        return None
    if s < -5:
        return BLACK if d == 1 else None
    if s < -3:
        if 0 <= d <= 2:
            return WHITE if (d == 1 and s == -4) else BLACK
        return None
    return BLACK if 0 <= d <= 2 else None


def brush(s, d):
    """A paintbrush: black bristles to a point, a white ferrule, a thin
    handle."""
    if -13 <= s <= -11:
        return BLACK if d == 1 else None
    if -10 <= s <= -7:
        return BLACK if 0 <= d <= 2 else None
    if -6 <= s <= -3 and -1 <= d <= 3:
        return BLACK if d in (-1, 3) or s in (-6, -3) else WHITE
    if s >= -2 and 1 <= d <= 2:
        return BLACK
    return None


def macpaint():
    c = Canvas()
    diamond_page(c)
    # A brush stroke across the page and a patterned area under it.
    for x, y in ((4, 12), (5, 11), (6, 11), (7, 12), (8, 13), (9, 13),
                 (10, 12), (11, 11), (12, 10), (13, 10), (5, 12), (6, 12),
                 (9, 12), (10, 11), (11, 10), (4, 13), (8, 12), (12, 9)):
        c.set(x, y, BLACK)
    for y in range(14, 21):
        for x in range(5, 14):
            if (abs(x - 12) + abs(y - 12) <= 9 and (x + y) % 2 == 0
                    and y - x <= 10 and x + y >= 21):
                c.set(x, y, BLACK)
    hand(c)
    tool(c, brush)
    return c


def macwrite():
    c = Canvas()
    diamond_page(c)
    # Lines of writing parallel to the page's top-left edge, with word gaps.
    for k, u in enumerate(range(10, 34, 3)):
        for x in range(N):
            y = u - x
            if (0 <= y < N and abs(x - 12) + abs(y - 12) <= 8
                    and (x - y + 2 * k) % 7 != 0):
                c.set(x, y, BLACK)
    hand(c)
    tool(c, pen)
    return c


# ---- documents -----------------------------------------------------------

L, T, Rt, B, FOLD = 4, 1, 27, 30, 7


def doc_page(c, fill=WHITE):
    """A page with its top-right corner folded down."""
    def page(x, y):
        return (L <= x <= Rt + 1 and T <= y <= B + 1
                and not (x - (Rt + 1 - FOLD)) > (y - T))
    c.shape(page, fill=fill)
    # The fold: a triangle with its own edge.
    fx = Rt + 1 - FOLD
    for i in range(FOLD + 1):
        c.set(fx, T + i, BLACK)          # vertical edge of the flap
    for i in range(FOLD):
        c.set(fx + i, T + FOLD, BLACK)   # horizontal edge of the flap
    for y in range(T + 1, T + FOLD):
        for x in range(fx + 1, fx + (y - T)):
            c.set(x, y, WHITE)


DIGITS = {
    "0": ("###", "#.#", "#.#", "#.#", "###"),
    "1": (".#.", "##.", ".#.", ".#.", "###"),
    "2": ("###", "..#", "###", "#..", "###"),
    "3": ("###", "..#", ".##", "..#", "###"),
    "4": ("#.#", "#.#", "###", "..#", "..#"),
}


def text(c, s, x, y):
    for ch in s:
        for r, row in enumerate(DIGITS[ch]):
            for k, p in enumerate(row):
                if p == "#":
                    c.set(x + k, y + r, BLACK)
        x += 4


def hline(c, x0, x1, y, gaps=()):
    for x in range(x0, x1 + 1):
        if x not in gaps:
            c.set(x, y, BLACK)


def pntdoc():
    """MacPaint's page in miniature: the brush stroke over a patterned
    hill, as on the application's own page."""
    c = Canvas()
    doc_page(c)
    for x, y in ((7, 12), (8, 11), (9, 11), (10, 12), (11, 13), (12, 13),
                 (13, 12), (14, 11), (15, 11), (16, 12), (17, 13), (8, 12),
                 (9, 12), (12, 12), (15, 12), (16, 13), (18, 13), (19, 12),
                 (20, 11), (19, 13)):
        c.set(x, y, BLACK)
    for y in range(16, 27):
        for x in range(7, 25):
            dx, dy = x - 15.5, y - 26.0
            if dx * dx / 72.0 + dy * dy / 100.0 <= 1.0 and (x + y) % 2 == 0:
                c.set(x, y, BLACK)
    hline(c, 7, 24, 27)
    return c


def wrtdoc():
    """MacWrite's page: ruled lines of text with word gaps."""
    c = Canvas()
    doc_page(c)
    hline(c, 7, 18, 5, gaps=(11, 15))                 # short of the fold
    rows = ((24, (12, 19)), (24, (10, 16, 21)), (24, (13, 18)),
            (24, (9, 15, 22)), (24, (11, 17)), (24, (14, 20)), (16, (12,)))
    for i, (x1, gaps) in enumerate(rows):
        hline(c, 7, x1, 9 + 3 * i, gaps)
    return c


def basdoc():
    """A BASIC program listing: line numbers 10 to 40, each followed by a
    statement."""
    c = Canvas()
    doc_page(c)
    for i, (num, end) in enumerate((("10", 19), ("20", 24), ("30", 22), ("40", 24))):
        y = 6 + 6 * i
        text(c, num, 7, y)
        for x in range(16, end + 1):
            if (x - 16) % 4 != 3:
                c.set(x, y + 2, BLACK)
    return c


# Note's colours (storage/NOTE.ICON): a cream page with blue writing.
CREAM, BLUE = (224, 224, 192), (0, 0, 192)


def txtdoc():
    """A note (.TXT, saved by Note and the Editor): Note's cream page with
    its blue lines, as one page with a folded corner."""
    c = Canvas()
    doc_page(c, fill=CREAM)
    for i, x1 in enumerate((18, 23, 21, 23, 15)):
        y = 8 + 4 * i
        for x in range(8, x1 + 1):
            c.set(x, y, BLUE)
            c.set(x, y + 1, BLUE)
    return c


# The application icons MACPAINT and MACWRITE are the hand-drawn ones in
# storage/; macpaint() and macwrite() are kept only as drawings to compare.
ICONS = {
    "PNTDOC": pntdoc,
    "WRTDOC": wrtdoc,
    "BASDOC": basdoc,
    "TXTDOC": txtdoc,
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", type=Path, default=ROOT / "storage",
                    help="where NAME.ICON goes (default storage/)")
    ap.add_argument("--preview", type=Path,
                    help="also write NAME.png enlarged 8x on grey into this folder")
    args = ap.parse_args()
    for name, draw in ICONS.items():
        im = draw().image()
        path = args.out / f"{name}.ICON"
        im.save(path, "PNG")
        print(f"{path}")
        if args.preview:
            args.preview.mkdir(parents=True, exist_ok=True)
            big = Image.new("RGBA", (N * 8, N * 8), (160, 160, 160, 255))
            big.alpha_composite(im.resize((N * 8, N * 8), Image.Resampling.NEAREST))
            big.save(args.preview / f"{name}.png")


if __name__ == "__main__":
    main()
