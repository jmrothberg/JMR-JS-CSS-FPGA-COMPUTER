#!/usr/bin/env python3
"""Draw VIGIL's four art sheets into storage/ (original art, all generated here).

VIGIL is a new game for this machine: a watchman climbs a dying tower before
the sand runs out. Every pixel below is drawn by this script so the art is
reproducible — edit a number here, rerun, and the sheets change together.

    python3 tools/make_vigil_art.py
    python3 tools/make_artx.py VIGIL
    python3 tools/make_sd_image.py create card.img

Sheet order must stay in step with window.JMR_SPR in storage/VIGIL.HTML:
    0 tiles   (13 cells of 32x32, 416x32)
    1 hero    (14 poses 32x48, 448x48)
    2 guard   ( 8 poses 32x48, 256x48)
    3 logo    (256x96: wordmark over an hourglass and a heart)

Palette index 0 is transparent on the machine, so empty pixels carry alpha 0.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
STORAGE = ROOT / "storage"

# ---------------------------------------------------------------- colours --
OUT = (16, 12, 14)          # ink outline, shared by every sprite
OUT2 = (38, 30, 31)

BRICK = (46, 50, 70)
BRICK_D = (30, 33, 47)
BRICK_HI = (68, 75, 105)

STONE = (60, 67, 92)
STONE_D = (39, 44, 61)
STONE_HI = (90, 99, 131)

WOOD = (110, 76, 48)
WOOD_D = (72, 48, 30)
WOOD_HI = (146, 104, 60)

IRON = (78, 83, 104)
IRON_D = (44, 47, 62)
IRON_HI = (118, 125, 147)

BRASS = (124, 94, 54)
BRASS_HI = (182, 142, 82)

GOLD = (201, 150, 47)
GOLD_HI = (255, 214, 128)

NIGHT = (22, 34, 62)
MOON = (176, 200, 240)

SPIKE = (152, 159, 180)
SPIKE_D = (86, 91, 108)

FLAME = (255, 172, 60)
FLAME_HI = (255, 230, 150)
FLAME_D = (204, 94, 32)

HOOD = (216, 166, 70)
HOOD_D = (152, 104, 36)
CLOAK = (146, 96, 46)
CLOAK_D = (104, 66, 32)
TUNIC = (66, 112, 94)
TUNIC_D = (44, 79, 67)
SKIN = (236, 190, 146)
SKIN_D = (188, 140, 102)
BOOT = (60, 43, 28)
STEEL = (208, 214, 226)
STEEL_D = (138, 145, 164)

ARMOR = (96, 106, 126)
ARMOR_D = (62, 70, 88)
HELM = (132, 142, 162)
TABARD = (146, 49, 49)
TABARD_D = (101, 32, 32)
EYE = (255, 216, 120)

CLEAR = (0, 0, 0, 0)


def new_sheet(w: int, h: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (w, h), CLEAR)
    return im, ImageDraw.Draw(im)


def box(d: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, fill, outline=None):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=fill,
                outline=outline if outline else None)


# ------------------------------------------------------------------ tiles --
# Cell numbers are fixed: storage/VIGIL.HTML's tile table indexes them, so a
# tile code IS its cell number (1..14) and tile 0 draws nothing.
TILE_CELLS = 18
T_EMPTY, T_BRICK, T_FLOOR, T_BEAM, T_BARS, T_BARS_UP = 0, 1, 2, 3, 4, 5
T_PLATE, T_SPIKE, T_CRUMBLE, T_WINDOW, T_TORCH, T_CHAIN, T_BANNER = range(6, 13)
T_DOOR_TOP, T_DOOR_BOT, T_LADDER, T_HEART, T_HEART_EMPTY = 13, 14, 15, 16, 17


def tile_brick(d, x, y):
    box(d, x, y, 32, 32, BRICK)
    for row in range(4):
        yy = y + row * 8
        d.line([x, yy + 7, x + 31, yy + 7], fill=BRICK_D)
        off = 0 if row % 2 == 0 else 8
        for bx in range(-1, 3):
            xx = x + off + bx * 16
            if xx < x:
                continue
            d.line([xx, yy + 1, xx, yy + 6], fill=BRICK_D)
            d.line([xx + 1, yy, xx + 1, yy + 6], fill=BRICK_HI)
    d.line([x, y, x + 31, y], fill=BRICK_HI)


def tile_floor(d, x, y):
    box(d, x, y, 32, 32, STONE)
    box(d, x, y, 32, 6, STONE_HI)
    d.line([x, y + 6, x + 31, y + 6], fill=STONE_D)
    d.line([x, y + 19, x + 31, y + 19], fill=STONE_D)
    for bx in (10, 21):
        d.line([x + bx, y + 7, x + bx, y + 31], fill=STONE_D)
    d.line([x + 4, y + 7, x + 8, y + 7], fill=(118, 128, 162))
    d.line([x + 2, y + 31, x + 31, y + 31], fill=OUT2)


def tile_beam(d, x, y):
    box(d, x, y, 32, 13, WOOD)
    box(d, x, y, 32, 3, WOOD_HI)
    d.line([x, y + 12, x + 31, y + 12], fill=WOOD_D)
    d.line([x, y + 13, x + 31, y + 13], fill=OUT2)
    for gx in (7, 19):
        d.line([x + gx, y + 5, x + gx + 4, y + 9], fill=WOOD_D)
    d.line([x + 14, y, x + 14, y + 12], fill=WOOD_D)


def tile_gate(d, x, y, open_):
    if open_:
        box(d, x, y, 32, 9, IRON)
        box(d, x, y, 32, 3, IRON_HI)
        d.line([x, y + 8, x + 31, y + 8], fill=IRON_D)
        d.line([x + 16, y + 9, x + 16, y + 21], fill=IRON_D, width=2)
        d.ellipse([x + 12, y + 20, x + 20, y + 28], outline=IRON_D, width=2)
        return
    box(d, x, y, 32, 32, IRON_D)
    for bx in (3, 11, 19, 27):
        box(d, x + bx, y, 4, 32, IRON)
        box(d, x + bx, y, 1, 32, IRON_HI)
    for by in (6, 22):
        box(d, x, y + by, 32, 4, IRON)
        d.line([x, y + by, x + 31, y + by], fill=IRON_HI)
    d.line([x, y + 32, x + 31, y + 32], fill=OUT2, width=1)


def tile_plate(d, x, y):
    box(d, x + 2, y + 22, 28, 9, BRASS)
    box(d, x + 2, y + 22, 28, 3, BRASS_HI)
    d.line([x + 2, y + 30, x + 29, y + 30], fill=OUT2)
    box(d, x + 9, y + 25, 14, 3, GOLD)


def tile_spikes(d, x, y):
    for i in range(4):
        bx = x + i * 8
        d.polygon([(bx + 1, y + 30), (bx + 4, y + 13), (bx + 7, y + 30)], fill=OUT)
        d.polygon([(bx + 2, y + 29), (bx + 4, y + 15), (bx + 6, y + 29)], fill=SPIKE)
        d.line([bx + 4, y + 16, bx + 4, y + 27], fill=(202, 209, 230))
        d.line([bx + 2, y + 29, bx + 6, y + 29], fill=SPIKE_D)
    box(d, x, y + 29, 32, 3, OUT2)


def tile_crumble(d, x, y):
    box(d, x, y, 32, 32, (78, 86, 112))
    box(d, x, y, 32, 6, (104, 113, 142))
    d.line([x, y + 6, x + 31, y + 6], fill=STONE_D)
    d.line([x + 6, y + 8, x + 13, y + 18], fill=STONE_D, width=2)
    d.line([x + 13, y + 18, x + 8, y + 30], fill=STONE_D, width=2)
    d.line([x + 22, y + 7, x + 26, y + 16], fill=STONE_D, width=2)
    d.line([x + 26, y + 16, x + 21, y + 26], fill=STONE_D, width=2)
    d.line([x + 17, y + 21, x + 24, y + 30], fill=STONE_D)
    for px, py in ((4, 12), (19, 12), (14, 27)):
        d.point([(x + px, y + py)], fill=(132, 142, 174))


def tile_window(d, x, y):
    box(d, x, y, 32, 32, BRICK_D)
    d.rectangle([x + 7, y + 3, x + 25, y + 31], fill=OUT)
    d.rectangle([x + 8, y + 4, x + 24, y + 31], fill=NIGHT)
    d.ellipse([x + 8, y - 5, x + 24, y + 11], fill=OUT)
    d.ellipse([x + 9, y - 4, x + 23, y + 10], fill=NIGHT)
    d.ellipse([x + 15, y + 5, x + 22, y + 12], fill=MOON)
    d.ellipse([x + 18, y + 3, x + 25, y + 10], fill=NIGHT)
    d.point([(x + 11, y + 8), (x + 12, y + 22), (x + 20, y + 26)], fill=(216, 230, 255))
    d.line([x + 16, y + 4, x + 16, y + 31], fill=OUT2)
    d.line([x + 8, y + 19, x + 24, y + 19], fill=OUT2)
    d.line([x + 7, y + 3, x + 7, y + 31], fill=(96, 106, 138))


def tile_torch(d, x, y):
    box(d, x + 13, y + 18, 6, 12, WOOD_D)
    box(d, x + 10, y + 17, 12, 4, BRASS)
    d.polygon([(x + 16, y + 1), (x + 23, y + 12), (x + 16, y + 18), (x + 9, y + 12)], fill=FLAME)
    d.polygon([(x + 16, y + 6), (x + 20, y + 13), (x + 16, y + 17), (x + 12, y + 13)], fill=FLAME_HI)
    d.point([(x + 9, y + 15), (x + 24, y + 14)], fill=FLAME_D)


def tile_chain(d, x, y):
    for i in range(4):
        cy = y + i * 8
        d.ellipse([x + 13, cy, x + 19, cy + 7], outline=IRON)
        d.ellipse([x + 14, cy + 1, x + 18, cy + 6], outline=IRON_D)


def tile_banner(d, x, y):
    box(d, x + 9, y, 14, 4, BRASS)
    d.polygon([(x + 9, y + 4), (x + 23, y + 4), (x + 23, y + 26),
               (x + 16, y + 30), (x + 9, y + 26)], fill=TABARD, outline=OUT)
    d.line([x + 16, y + 8, x + 16, y + 24], fill=TABARD_D)
    d.line([x + 12, y + 12, x + 20, y + 12], fill=TABARD_D)
    d.line([x + 11, y + 4, x + 11, y + 25], fill=(176, 74, 74))


def tile_door(d, x, y, top):
    """A stone arch: two cells stacked, entered from the side it faces."""
    if top:
        box(d, x, y, 32, 32, BRICK_D)
        d.ellipse([x + 2, y + 4, x + 29, y + 40], fill=OUT)
        d.ellipse([x + 3, y + 5, x + 28, y + 39], fill=WOOD_D)
        d.rectangle([x + 3, y + 20, x + 28, y + 31], fill=WOOD_D)
        for bx in (8, 14, 20, 26):
            d.line([x + bx, y + 14, x + bx, y + 31], fill=WOOD)
        d.ellipse([x + 12, y + 6, x + 19, y + 13], fill=GOLD_HI)
        d.ellipse([x + 13, y + 7, x + 18, y + 12], fill=GOLD)
        return
    box(d, x, y, 32, 32, BRICK_D)
    d.rectangle([x + 3, y, x + 28, y + 31], fill=WOOD_D)
    for bx in (8, 14, 20, 26):
        d.line([x + bx, y, x + bx, y + 31], fill=WOOD)
    d.line([x + 3, y + 8, x + 28, y + 8], fill=OUT2)
    d.line([x + 3, y + 22, x + 28, y + 22], fill=OUT2)
    d.ellipse([x + 21, y + 13, x + 25, y + 17], fill=GOLD)
    d.line([x + 2, y, x + 2, y + 31], fill=(96, 74, 46))


def tile_ladder(d, x, y):
    d.line([x + 9, y, x + 9, y + 31], fill=OUT, width=4)
    d.line([x + 22, y, x + 22, y + 31], fill=OUT, width=4)
    d.line([x + 9, y, x + 9, y + 31], fill=BRASS, width=2)
    d.line([x + 22, y, x + 22, y + 31], fill=BRASS, width=2)
    for ry in (4, 12, 20, 28):
        d.line([x + 9, y + ry, x + 22, y + ry], fill=OUT, width=4)
        d.line([x + 9, y + ry, x + 22, y + ry], fill=WOOD, width=2)


def tile_heart(d, x, y, empty):
    fill = (56, 40, 40) if empty else (214, 60, 66)
    lit = (76, 54, 54) if empty else (255, 150, 152)
    d.ellipse([x + 2, y + 6, x + 15, y + 19], fill=fill, outline=OUT)
    d.ellipse([x + 13, y + 6, x + 26, y + 19], fill=fill, outline=OUT)
    d.polygon([(x + 3, y + 13), (x + 25, y + 13), (x + 14, y + 29)],
              fill=fill, outline=OUT)
    d.point([(x + 7, y + 10), (x + 8, y + 10), (x + 7, y + 11)], fill=lit)


def build_tiles() -> Image.Image:
    im, d = new_sheet(TILE_CELLS * 32, 32)
    builders = [
        lambda x, y: None,
        lambda x, y: tile_brick(d, x, y),
        lambda x, y: tile_floor(d, x, y),
        lambda x, y: tile_beam(d, x, y),
        lambda x, y: tile_gate(d, x, y, False),
        lambda x, y: tile_gate(d, x, y, True),
        lambda x, y: tile_plate(d, x, y),
        lambda x, y: tile_spikes(d, x, y),
        lambda x, y: tile_crumble(d, x, y),
        lambda x, y: tile_window(d, x, y),
        lambda x, y: tile_torch(d, x, y),
        lambda x, y: tile_chain(d, x, y),
        lambda x, y: tile_banner(d, x, y),
        lambda x, y: tile_door(d, x, y, 1),
        lambda x, y: tile_door(d, x, y, 0),
        lambda x, y: tile_ladder(d, x, y),
        lambda x, y: tile_heart(d, x, y, 0),
        lambda x, y: tile_heart(d, x, y, 1),
    ]
    for i, fn in enumerate(builders):
        fn(i * 32, 0)
    return im


# ---------------------------------------------------------------- figures --
HERO_W, HERO_H = 32, 48
# A pose is: shoulder (sx,sy), hip (hx,hy), head centre, two arms and two legs
# given as (elbow, hand) / (knee, foot), an optional sword (hilt, tip) and an
# optional lantern (hand-relative offset). Frames are 32x48, feet near y=46.
POSES = {
    "idle": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                 aL=((12, 24), (11, 29)), aR=((20, 24), (21, 29)),
                 lL=((14, 38), (13, 45)), lR=((18, 38), (19, 45)),
                 lamp=(11, 30)),
    "walk1": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                  aL=((14, 24), (16, 28)), aR=((19, 25), (17, 30)),
                  lL=((17, 38), (20, 45)), lR=((13, 39), (11, 45)),
                  lamp=(16, 29)),
    "walk2": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                  aL=((12, 24), (12, 29)), aR=((21, 24), (21, 29)),
                  lL=((14, 38), (14, 45)), lR=((18, 38), (17, 45)),
                  lamp=(12, 30)),
    "walk3": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                  aL=((19, 25), (17, 30)), aR=((14, 24), (16, 28)),
                  lL=((14, 38), (12, 45)), lR=((18, 39), (21, 45)),
                  lamp=(17, 29)),
    "walk4": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                  aL=((20, 24), (20, 29)), aR=((11, 24), (11, 29)),
                  lL=((18, 38), (18, 45)), lR=((14, 38), (13, 45)),
                  lamp=(11, 30)),
    "jump": dict(sh=(16, 18), hip=(17, 29), head=(16, 10),
                 aL=((10, 22), (8, 16)), aR=((22, 22), (24, 17)),
                 lL=((12, 34), (14, 39)), lR=((21, 34), (19, 39)),
                 lamp=(8, 17)),
    "fall": dict(sh=(16, 19), hip=(16, 30), head=(16, 11),
                 aL=((8, 21), (5, 22)), aR=((24, 21), (27, 22)),
                 lL=((13, 37), (12, 44)), lR=((20, 37), (22, 44))),
    "crouch": dict(sh=(16, 27), hip=(16, 37), head=(16, 20),
                   aL=((12, 31), (11, 36)), aR=((20, 31), (21, 36)),
                   lL=((12, 41), (11, 46)), lR=((20, 41), (21, 46)),
                   lamp=(10, 37)),
    "hang": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                 aL=((13, 12), (13, 5)), aR=((19, 12), (19, 5)),
                 lL=((15, 38), (14, 45)), lR=((18, 38), (19, 45))),
    "climb": dict(sh=(16, 18), hip=(16, 29), head=(16, 10),
                  aL=((14, 11), (14, 5)), aR=((20, 13), (22, 8)),
                  lL=((11, 33), (12, 39)), lR=((19, 37), (20, 45))),
    "wind": dict(sh=(17, 19), hip=(16, 31), head=(17, 11),
                 aL=((12, 24), (11, 29)), aR=((22, 22), (20, 16)),
                 lL=((14, 38), (13, 45)), lR=((19, 38), (21, 45)),
                 sword=((20, 16), (15, 10)), lamp=(10, 30)),
    "thrust": dict(sh=(17, 19), hip=(16, 31), head=(17, 11),
                   aL=((11, 24), (10, 29)), aR=((23, 22), (26, 21)),
                   lL=((14, 38), (16, 45)), lR=((19, 38), (22, 45)),
                   sword=((26, 21), (31, 20)), lamp=(9, 29)),
    "hurt": dict(sh=(17, 19), hip=(18, 31), head=(14, 11),
                 aL=((11, 20), (8, 17)), aR=((23, 20), (26, 17)),
                 lL=((15, 38), (13, 45)), lR=((21, 38), (23, 44))),
    "dead": dict(sh=(10, 42), hip=(18, 43), head=(7, 41),
                 aL=((16, 38), (20, 36)), aR=((9, 46), (5, 47)),
                 lL=((23, 46), (27, 45)), lR=((22, 40), (25, 40))),
    "cheer": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                  aL=((11, 15), (9, 8)), aR=((21, 15), (23, 8)),
                  lL=((14, 38), (13, 45)), lR=((18, 38), (19, 45)),
                  lamp=(8, 9)),
}

G_POSES = {
    "idle": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                 aL=((11, 24), (10, 29)), aR=((21, 23), (23, 27)),
                 lL=((13, 38), (12, 45)), lR=((19, 38), (20, 45)),
                 sword=((23, 27), (28, 29))),
    "walk1": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                  aL=((13, 24), (14, 29)), aR=((21, 23), (22, 27)),
                  lL=((17, 38), (20, 45)), lR=((13, 39), (11, 45)),
                  sword=((22, 27), (27, 30))),
    "walk2": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                  aL=((12, 24), (11, 29)), aR=((21, 23), (23, 27)),
                  lL=((14, 38), (13, 45)), lR=((18, 39), (21, 45)),
                  sword=((23, 27), (28, 30))),
    "wind": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                 aL=((10, 24), (9, 29)), aR=((22, 21), (20, 15)),
                 lL=((13, 38), (12, 45)), lR=((
                     20, 38), (21, 45)),
                 sword=((20, 15), (14, 9))),
    "thrust": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                   aL=((11, 24), (10, 29)), aR=((24, 21), (27, 20)),
                   lL=((14, 38), (16, 45)), lR=((20, 38), (23, 45)),
                   sword=((27, 20), (31, 20))),
    "recover": dict(sh=(16, 19), hip=(16, 31), head=(16, 11),
                    aL=((12, 24), (11, 29)), aR=((21, 23), (23, 28)),
                    lL=((13, 38), (12, 45)), lR=((19, 38), (20, 45)),
                    sword=((23, 28), (24, 34))),
    "hurt": dict(sh=(17, 19), hip=(18, 31), head=(14, 11),
                 aL=((10, 20), (7, 17)), aR=((22, 19), (25, 15)),
                 lL=((15, 38), (13, 45)), lR=((21, 38), (23, 44)),
                 sword=((25, 15), (29, 12))),
    "dead": dict(sh=(10, 42), hip=(18, 43), head=(7, 41),
                 aL=((16, 38), (21, 36)), aR=((9, 46), (5, 47)),
                 lL=((23, 46), (27, 45)), lR=((22, 40), (25, 40)),
                 sword=((21, 36), (27, 38))),
}


def _thick(d, a, b, w, fill):
    """A limb: ink casing, body colour, one lit edge."""
    d.line([a, b], fill=OUT, width=w + 2)
    d.line([a, b], fill=fill, width=w)


def _blob(d, p, r, fill):
    x, y = p
    d.ellipse([x - r - 1, y - r - 1, x + r + 1, y + r + 1], fill=OUT)
    d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def _torso(d, p, art):
    sx, sy = p["sh"]
    hx, hy = p["hip"]
    ws, wh = 6.5, 5.0
    mx, my = (sx + hx) / 2.0, (sy + hy) / 2.0
    poly = [(sx - ws, sy), (sx + ws, sy), (mx + wh - 1, my),
            (hx + wh, hy), (hx - wh, hy), (mx - wh + 1, my)]
    d.polygon(poly, fill=art["tunic"], outline=OUT)
    # lit left edge, shaded right edge
    d.line([(sx - ws + 1, sy + 1), (hx - wh + 1, hy - 1)], fill=art["tunic_hi"])
    d.line([(sx + ws - 1, sy + 1), (hx + wh - 1, hy - 1)], fill=art["tunic_d"])
    # belt
    d.line([(hx - wh, hy - 2), (hx + wh, hy - 2)], fill=art["belt"], width=2)
    d.point([(hx, hy - 2)], fill=GOLD)
    # collar
    d.line([(sx - 4, sy), (sx + 4, sy)], fill=art["tunic_d"])


def _cloak(d, p, art):
    sx, sy = p["sh"]
    hx, hy = p["hip"]
    d.polygon([(sx - 6, sy - 1), (sx + 5, sy - 1),
               (hx + 8, hy + 7), (hx + 2, hy + 10),
               (hx - 7, hy + 7)], fill=art["cloak"], outline=OUT)
    d.line([(sx - 5, sy + 2), (hx - 5, hy + 6)], fill=art["cloak_d"])


def _head(d, p, art):
    hx, hy = p["head"]
    if art.get("helm"):
        d.ellipse([hx - 6, hy - 6, hx + 6, hy + 7], fill=art["hood"], outline=OUT)
        d.ellipse([hx - 5, hy - 5, hx + 5, hy + 3], fill=art["hood_hi"])
        box(d, hx - 4, hy + 1, 9, 3, OUT2)
        d.point([(hx - 2, hy + 2), (hx + 2, hy + 2)], fill=EYE)
        d.line([(hx, hy - 6), (hx, hy + 3)], fill=OUT2)
        d.line([(hx - 6, hy + 4), (hx + 6, hy + 4)], fill=OUT2)
    else:
        d.ellipse([hx - 6, hy - 7, hx + 6, hy + 7], fill=art["hood"], outline=OUT)
        d.ellipse([hx - 4, hy - 4, hx + 4, hy + 3], fill=art["hood_hi"])
        d.ellipse([hx - 4, hy - 1, hx + 4, hy + 6], fill=art["face"])
        d.point([(hx - 2, hy + 1), (hx + 2, hy + 1)], fill=OUT)
        d.line([(hx - 4, hy + 5), (hx + 3, hy + 5)], fill=art["face_d"])
        d.line([(hx - 5, hy - 5), (hx + 4, hy - 5)], fill=art["hood_d"])


def _sword(d, p):
    if not p.get("sword"):
        return
    a, b = p["sword"]
    d.line([a, b], fill=OUT, width=4)
    d.line([a, b], fill=STEEL, width=2)
    d.point([b], fill=(255, 255, 255))
    # crossguard at the hilt
    gx, gy = a
    d.line([(gx - 2, gy + 2), (gx + 2, gy - 2)], fill=BRASS_HI, width=2)


def _lamp(d, p, ox):
    off = p.get("lamp")
    if not off:
        return
    x, y = ox + off[0], off[1]
    d.line([(x, y - 3), (x, y)], fill=OUT2)
    d.ellipse([x - 5, y - 1, x + 5, y + 9], fill=(72, 56, 30))
    box(d, x - 3, y + 1, 7, 8, BRASS, outline=OUT)
    box(d, x - 2, y + 2, 5, 6, FLAME_HI)
    d.point([(x - 1, y + 3), (x + 1, y + 6)], fill=FLAME)


def draw_figure(d, ox, p, art, lamp=False):
    """One humanoid in a 32x48 cell whose left edge is ox."""
    def T(pt):
        return (ox + pt[0], pt[1])

    # Back limbs first, then cloak, torso, front limbs, head, sword, lamp.
    _thick(d, T(p["hip"]), T(p["lR"][0]), 4, art["limb_d"])
    _thick(d, T(p["lR"][0]), T(p["lR"][1]), 3, art["limb_d"])
    _blob(d, T(p["lR"][1]), 2, art["boot"])
    _thick(d, T(p["sh"]), T(p["aR"][0]), 3, art["limb_d"])
    _thick(d, T(p["aR"][0]), T(p["aR"][1]), 3, art["limb_d"])
    _blob(d, T(p["aR"][1]), 2, art["hand"])
    _cloak(d, {k: T(v) if k in ("sh", "hip") else v for k, v in p.items()}, art)
    _torso(d, {k: T(v) if k in ("sh", "hip") else v for k, v in p.items()}, art)
    _thick(d, T(p["hip"]), T(p["lL"][0]), 4, art["limb"])
    _thick(d, T(p["lL"][0]), T(p["lL"][1]), 3, art["limb"])
    _blob(d, T(p["lL"][1]), 2, art["boot"])
    _thick(d, T(p["sh"]), T(p["aL"][0]), 3, art["limb"])
    _thick(d, T(p["aL"][0]), T(p["aL"][1]), 3, art["limb"])
    _blob(d, T(p["aL"][1]), 2, art["hand"])
    _head(d, {k: T(v) if k == "head" else v for k, v in p.items()}, art)
    _sword(d, {k: (T(v[0]), T(v[1])) if k == "sword" else v for k, v in p.items()})
    if lamp:
        _lamp(d, p, ox)


HERO_BODY = dict(cloak=CLOAK, cloak_d=CLOAK_D, tunic=TUNIC, tunic_hi=(88, 138, 116),
                 tunic_d=TUNIC_D, limb=(202, 162, 122), limb_d=(160, 122, 88),
                 hand=SKIN, boot=BOOT, belt=WOOD_D,
                 hood=HOOD, hood_hi=(240, 196, 104), hood_d=HOOD_D,
                 face=SKIN, face_d=SKIN_D)
GUARD_BODY = dict(cloak=TABARD, cloak_d=TABARD_D, tunic=ARMOR, tunic_hi=(126, 138, 160),
                  tunic_d=ARMOR_D, limb=ARMOR, limb_d=ARMOR_D, hand=STEEL_D,
                  boot=OUT2, belt=OUT, hood=HELM, hood_hi=(166, 176, 196),
                  hood_d=OUT2, face=SKIN, face_d=SKIN_D, helm=1)


def build_figure_sheet(poses: dict, art: dict, lamp: bool) -> Image.Image:
    """Every pose twice: facing right, then the mirror image facing left.

    The machine cannot mirror with setTransform (a negative x scale collapses
    to one pixel), so both facings are baked into the sheet. The left-facing
    half starts at cell len(poses).
    """
    names = list(poses.keys())
    im, d = new_sheet(len(names) * 2 * HERO_W, HERO_H)
    for i, name in enumerate(names):
        draw_figure(d, i * HERO_W, poses[name], art, lamp=lamp)
    facing = im.crop((0, 0, len(names) * HERO_W, HERO_H)).transpose(
        Image.FLIP_LEFT_RIGHT)
    im.paste(facing, (len(names) * HERO_W, 0))
    return im


# ------------------------------------------------------------------- logo --
GLYPHS = {
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "G": [".####", "#....", "#....", "#.###", "#...#", "#...#", ".###."],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
}


def build_icon() -> Image.Image:
    """32x32 desktop icon: the watchman's hooded head over a lit lantern."""
    im, d = new_sheet(32, 32)
    # hood and face
    d.ellipse([5, 2, 26, 25], fill=OUT)
    d.ellipse([6, 3, 25, 24], fill=HOOD)
    d.ellipse([8, 5, 23, 20], fill=HOOD_D)
    d.ellipse([10, 8, 21, 21], fill=SKIN)
    d.point([(13, 13), (14, 13), (18, 13), (19, 13)], fill=OUT)
    d.line([15, 16, 17, 16], fill=SKIN_D)
    d.line([9, 4, 22, 4], fill=(240, 196, 104))
    # shoulders
    d.polygon([(4, 31), (7, 23), (24, 23), (27, 31)], fill=OUT)
    d.polygon([(5, 31), (8, 24), (23, 24), (26, 31)], fill=TUNIC)
    # lantern, held to the right
    d.line([24, 20, 26, 16], fill=OUT2, width=2)
    d.ellipse([21, 15, 31, 27], fill=OUT)
    box(d, 22, 16, 8, 10, BRASS)
    box(d, 23, 17, 6, 8, FLAME_HI)
    d.point([(25, 19), (26, 22)], fill=FLAME)
    return im


def build_logo() -> Image.Image:
    im, d = new_sheet(256, 96)
    box(d, 6, 2, 244, 58, (26, 22, 30), outline=GOLD)
    d.line([8, 4, 247, 4], fill=(64, 53, 44))
    scale, gap = 6, 8
    word = "VIGIL"
    total = len(word) * 5 * scale + (len(word) - 1) * gap
    x0 = (256 - total) // 2
    for i, ch in enumerate(word):
        gx = x0 + i * (5 * scale + gap)
        for ry, line in enumerate(GLYPHS[ch]):
            for rx, lit in enumerate(line):
                if lit != "#":
                    continue
                box(d, gx + rx * scale, 8 + ry * scale, scale, scale, GOLD_HI)
                box(d, gx + rx * scale, 8 + ry * scale + scale - 1, scale, 1, GOLD)
    d.line([x0, 58, x0 + total - 1, 60], fill=GOLD)
    # hourglass, left of centre
    d.line([6, 66, 34, 66], fill=BRASS_HI, width=2)
    d.line([6, 94, 34, 94], fill=BRASS_HI, width=2)
    d.polygon([(8, 68), (32, 68), (20, 80), (32, 92), (8, 92), (20, 80)],
              fill=(64, 55, 42), outline=BRASS)
    d.polygon([(11, 70), (29, 70), (20, 79)], fill=GOLD_HI)
    d.polygon([(20, 83), (28, 90), (12, 90)], fill=GOLD)
    d.point([(20, 81)], fill=GOLD_HI)
    # heart, right of centre
    hx, hy = 210, 64
    d.ellipse([hx, hy + 3, hx + 9, hy + 12], fill=(214, 60, 66), outline=OUT)
    d.ellipse([hx + 7, hy + 3, hx + 16, hy + 12], fill=(214, 60, 66), outline=OUT)
    d.polygon([(hx + 1, hy + 8), (hx + 16, hy + 8), (hx + 8, hy + 19)],
              fill=(214, 60, 66), outline=OUT)
    d.point([(hx + 4, hy + 6), (hx + 5, hy + 6)], fill=(255, 178, 178))
    return im


def main() -> None:
    STORAGE.mkdir(parents=True, exist_ok=True)
    sheets = [
        ("VIGIL-0.png", build_tiles()),
        ("VIGIL-1.png", build_figure_sheet(POSES, HERO_BODY, True)),
        ("VIGIL-2.png", build_figure_sheet(G_POSES, GUARD_BODY, False)),
        ("VIGIL-3.png", build_logo()),
    ]
    for name, im in sheets:
        path = STORAGE / name
        im.save(path, format="PNG")
        print(f"wrote {path.relative_to(ROOT)} {im.size[0]}x{im.size[1]}")
    # Finder's desktop icon is a separate 32x32 file (docs/DESKTOP_ICONS.md);
    # the card builder converts this PNG to VIGIL.ICN.
    icon = STORAGE / "VIGIL.ICON"
    build_icon().save(icon, format="PNG")
    print(f"wrote {icon.relative_to(ROOT)} 32x32")


if __name__ == "__main__":
    main()
