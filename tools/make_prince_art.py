#!/usr/bin/env python3
"""Build the art sheets for PRINCE.HTML from Jordan Mechner's originals.

Room shapes and which piece goes where come from the Apple II source
(the open-source release). A piece is drawn there as one colour, which
on the Apple II is a lit pixel every four columns. Those pixels are
filled in and painted with the Macintosh brick, so a wall is the painted
brick and the openings stay where the original left them. Spikes, gates,
torches, potions, doors, the sword and the bones are the Macintosh
frames, set on the same floor line the prince walks.

  Prince/Prince-of-Persia-Apple-II/01 POP Source/   placement, rooms
  Prince/artwork/.../Persia(COLOR)/1360 Dungeon blocks   the brick
  Prince/artwork/.../Persia(COLOR)/1200 Dungeon          spikes, gates, doors
  Prince/artwork/.../Persia(COLOR)/150 Torch             the flame
  Prince/artwork/.../Persia(COLOR)/700 Swords            the sword
  Prince/artwork/.../Persia(COLOR)/400 Prince            the prince
  Prince/artwork/.../Persia(COLOR)/1750 Guard            the guard

The prince and the guard frames have no foot offset of their own, so
each one is scaled to the Apple II image it matches and anchored on
that image's feet.

  PRINCE-0.png  24 rooms, 4 across, then one 28x63 patch per tile the
                game can change (gate, door, loose floor, potion, sword)
  PRINCE-1.png  17 prince poses, then the same 17 mirrored
  PRINCE-2.png  7 guard poses, then the same 7 mirrored

A pose cell is 64x48. The image bottom sits on y=45 and the image is
centred on x=32, which is where PRINCE.HTML anchors the feet.

Run:  python3 tools/make_prince_art.py
Then: python3 tools/make_artx.py PRINCE
"""
import os
import re
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "Prince", "Prince-of-Persia-Apple-II", "01 POP Source")
IMGDIR = os.path.join(SRC, "Images")
STORAGE = os.path.join(ROOT, "storage")
# Macintosh color paintings. Frame files are 000, 001, ... in image order.
# The prince set has no frame for image 0, so image n is file n-1.
MAC = os.path.join(ROOT, "Prince", "artwork", "full-game", "COLOR",
                   "Persia(COLOR)")
STONE = (94, 135, 130, 255)   # the Macintosh dungeon stone

# Cell the game draws the figures from. Bottom of the source image is the
# foot line; the image is centred on AX.
CW, CH, AX, AY = 64, 48, 32, 45

# Tile ids the running game replaces. The patch shows the tile afterwards:
# an open gate or door, a loose floor that has fallen, a taken potion or sword.
MUTABLE = {4: 1, 10: 1, 11: 0, 16: 0, 17: 0, 22: 1}

# Prince poses, in the order PRINCE.HTML's POSE index uses. Numbers are
# image ids in IMG.CHTAB1 (stand, four run frames, jump, fall, hang,
# two climb frames, crouch, careful step, turn, hurt, dead, sword, strike).
KID_POSE = [15, 7, 9, 11, 13, 20, 22, 33, 39, 34, 35, 3, 16, 28, 26, 36, 38]
# Guard poses: stand, two walk frames, strike, block, hurt, dead.
GUARD_POSE = [27, 4, 6, 16, 20, 24, 32]


def load_tab(name):
    """Image table. Byte 0 is the count; image n's pointer is at n*2-1.
    The files are linked at $6000 even when the game loads them elsewhere."""
    data = open(os.path.join(IMGDIR, name), "rb").read()
    images = {}
    org = 0x6000
    n = 1
    while n < 200:
        o = n * 2 - 1
        if o + 1 >= len(data):
            break
        ptr = data[o] | (data[o + 1] << 8)
        off = ptr - org
        if not (0 <= off + 2 <= len(data)):
            break
        w, h = data[off], data[off + 1]
        if not (0 < w <= 40 and 0 < h <= 192 and off + 2 + w * h <= len(data)):
            break
        images[n] = (w, h, data[off + 2:off + 2 + w * h])
        n += 1
    if not images:
        raise SystemExit("no images in " + name)
    return images


def parse_bgdata():
    text = open(os.path.join(SRC, "Source", "BGDATA.S")).read().splitlines()
    names = ["maska", "piecea", "pieceay", "maskb", "pieceb", "pieceby",
             "piecec", "pieced", "fronti", "fronty", "frontx",
             "blockb", "blockc", "blockd", "blockfr",
             "panelb", "panelc", "spaceb", "spaceby", "floorb", "floorby"]
    tables = {}
    i = 0
    while i < len(text):
        line = text[i].strip()
        hit = None
        for nm in names:
            if line.startswith(nm + " ") or line.startswith(nm + "\t"):
                hit = nm
                break
        if hit is None:
            i += 1
            continue
        blob = [line[len(hit):].strip()]
        j = i + 1
        while j < len(text) and text[j].strip().startswith(("hex", "dfb")):
            blob.append(text[j].strip())
            j += 1
        raw = " ".join(blob).replace("hex", " ").replace("dfb", " ")
        vals = []
        for tok in raw.replace(",", " ").split():
            if tok.startswith("-"):
                vals.append(int(tok) & 0xFF)
            else:
                vals.append(int(tok, 16))
        tables[hit] = vals
        i = j
    mask = []
    grab = False
    for line in open(os.path.join(SRC, "Source", "HRTABLES.S")):
        s = line.strip()
        if s.startswith("MASKTAB"):
            grab = True
            s = s[len("MASKTAB"):].strip()
        elif grab and (s.startswith("*") or (s and not s.upper().startswith("HEX"))):
            break
        if grab:
            hexonly = "".join(ch for ch in s if ch in "0123456789abcdefABCDEF")
            for k in range(0, len(hexonly), 2):
                mask.append(int(hexonly[k:k + 2], 16))
    return tables, mask


def sb(v):
    return v - 256 if v >= 128 else v


def blueprint_rows():
    html = open(os.path.join(STORAGE, "PRINCE.HTML")).read()
    m = re.search(r"var BP = \[(.*?)\];", html, re.S)
    if not m:
        raise SystemExit("PRINCE.HTML has no BP table")
    return re.findall(r'"([A-Z]+)"', m.group(1))


class Art:
    def __init__(self):
        self.bg1 = load_tab("IMG.BGTAB1.DUN")
        self.bg2 = load_tab("IMG.BGTAB2.DUN")
        self.ch1 = load_tab("IMG.CHTAB1")
        self.gd = load_tab("IMG.CHTAB4.GD")
        self.T, self.mask = parse_bgdata()
        self.lvl = open(os.path.join(SRC, "Levels", "LEVEL1"), "rb").read()
        self.map = self.lvl[720 + 720 + 256 + 256:720 + 720 + 256 + 256 + 96]
        self.overrides = {}
        # One Macintosh wall face, at the sheet's pixel size (the sheet is
        # the 280-wide room; the canvas draws it at 2x).
        brick = Image.open(os.path.join(
            MAC, "1360 Dungeon blocks", "frames", "005.png")).convert("RGBA")
        self.brick = brick.resize((32, 60), Image.Resampling.NEAREST)
        self.pxmask = None
        self._solid_cache = {}

    def bg(self, n):
        if not n:
            return None
        tab = self.bg2 if n & 0x80 else self.bg1
        return tab.get(n & 0x7F)

    def link(self, room, side):
        v = self.map[room * 4 + side]
        return v - 1 if v else -1

    def tile_of(self, room, idx):
        if room < 0 or idx < 0 or idx > 29:
            return 0, 0
        key = (room, idx)
        if key in self.overrides:
            return self.overrides[key], 0
        return self.lvl[room * 30 + idx] & 31, self.lvl[720 + room * 30 + idx]

    def blit(self, screen, n, xco, yco, op, chars=None):
        if chars is not None:
            im = chars.get(n)
        else:
            im = self.bg(n)
        if not im:
            return
        w, h, raw = im
        top = yco - h + 1
        for row in range(h):
            sy = top + row
            if not (0 <= sy < 192):
                continue
            base = sy * 40
            for col in range(w):
                sx = xco + col
                if not (0 <= sx < 40):
                    continue
                b = raw[row * w + col]
                i = base + sx
                old = screen[i]
                if op == 0:
                    screen[i] = old & b
                elif op == 1:
                    screen[i] = old | b
                elif op == 2:
                    screen[i] = b
                else:
                    screen[i] = (old & self.mask[b & 127]) | b
        # The same piece, filled solid, into the paint mask. The Apple II
        # colour is one lit pixel every four columns; filling that run is
        # the stone face. An AND mask clears where its own face is empty.
        if self.pxmask is not None and chars is None:
            self._mask_blit(n, xco, yco, op)

    def _solid(self, n):
        """The piece with the hi-res colour filled in, plus the one-pixel
        mortar rows closed. Cached: a room redraws the same pieces."""
        if n in self._solid_cache:
            return self._solid_cache[n]
        im = self.bg(n)
        if not im:
            self._solid_cache[n] = None
            return None
        w, h, raw = im
        W = w * 7
        bits = [0] * (W * h)
        for row in range(h):
            for col in range(w):
                b = raw[row * w + col]
                for bit in range(7):
                    if (b >> bit) & 1:
                        bits[row * W + col * 7 + bit] = 1
        out = bits[:]
        for row in range(h):
            base = row * W
            xs = [x for x in range(W) if bits[base + x]]
            if not xs:
                continue
            start = prev = xs[0]
            for x in xs[1:] + [9999]:
                if x - prev > 4:
                    for k in range(start, prev + 1):
                        out[base + k] = 1
                    start = x
                prev = x
        for row in range(1, h - 1):
            for x in range(W):
                i = row * W + x
                if not out[i] and out[i - W] and out[i + W]:
                    out[i] = 1
        self._solid_cache[n] = (W, h, out)
        return self._solid_cache[n]

    def _mask_blit(self, n, xco, yco, op):
        solid = self._solid(n)
        if not solid:
            return
        W, h, bits = solid
        top = yco - h + 1
        x0 = xco * 7
        mask = self.pxmask
        for row in range(h):
            sy = top + row
            if not (0 <= sy < 192):
                continue
            base = sy * 280
            src = row * W
            for x in range(W):
                sx = x0 + x
                if not (0 <= sx < 280):
                    continue
                if op == 0:
                    if not bits[src + x]:
                        mask[base + sx] = 0
                elif bits[src + x]:
                    mask[base + sx] = 1

    def _brick_image(self):
        """Paint the filled pieces with the Macintosh brick. A one- or
        two-pixel gap between two stone faces is the seam of the dither,
        so it is closed; a real opening is wider and stays black."""
        mask = self.pxmask
        closed = bytearray(mask)
        for y in range(192):
            row = y * 280
            for x in range(280):
                if mask[row + x]:
                    continue
                left = right = False
                for d in (1, 2):
                    if x - d >= 0 and mask[row + x - d]:
                        left = True
                    if x + d < 280 and mask[row + x + d]:
                        right = True
                if left and right:
                    closed[row + x] = 1
        img = Image.new("RGBA", (280, 192), (0, 0, 0, 255))
        px = img.load()
        bp = self.brick.load()
        tw, th = self.brick.size
        for y in range(192):
            row = y * 280
            for x in range(280):
                if closed[row + x]:
                    c = bp[x % tw, y % th]
                    px[x, y] = (c[0], c[1], c[2], 255)
        return img

    def _stamp(self, img, src, x, y, w, h):
        """Scale a Macintosh frame to w x h and set its top-left at x, y.
        Clipped by the paste, so a frame on the top row can start at y < 0."""
        if w < 1 or h < 1:
            return
        spr = src.resize((w, h), Image.Resampling.NEAREST)
        img.paste(spr, (x, y), spr)

    def _stamp_props(self, img, room):
        """The objects you have to see, from the Macintosh frames, on the
        floor line the prince walks (10 pixels above the block bottom)."""
        def frame(folder, n):
            return Image.open(os.path.join(MAC, folder, "frames",
                                           "%03d.png" % n)).convert("RGBA")

        spike = frame("1200 Dungeon", 100)
        gate = frame("1200 Dungeon", 16)
        potion = frame("1200 Dungeon", 113)
        flame = frame("150 Torch", 0)
        door = frame("1200 Dungeon", 94)
        sword = frame("700 Swords", 10)
        bones = frame("1200 Dungeon", 10)
        for r in range(3):
            surface = 55 + r * 63
            top = 3 + r * 63
            for c in range(10):
                obj, _st = self.tile_of(room, r * 10 + c)
                x0 = c * 28
                if obj == 2:
                    self._stamp(img, spike, x0 + 1, surface - 28, 26, 28)
                elif obj == 4:
                    self._stamp(img, gate, x0 + 4, surface - 50, 20, 50)
                elif obj == 10:
                    self._stamp(img, potion, x0 + 8, surface - 16, 12, 16)
                elif obj == 19:
                    self._stamp(img, flame, x0 + 8, top + 8, 12, 16)
                elif obj == 16:
                    # A door is two tiles, left then right. One arch spans both.
                    nxt = self.tile_of(room, r * 10 + c + 1)[0] if c < 9 else 0
                    if nxt == 17:
                        self._stamp(img, door, x0 + 10, surface - 52, 36, 52)
                    else:
                        self._stamp(img, door, x0 + 3, surface - 52, 22, 52)
                elif obj == 17:
                    prev = self.tile_of(room, r * 10 + c - 1)[0] if c > 0 else 0
                    if prev != 16:
                        self._stamp(img, door, x0 + 3, surface - 52, 22, 52)
                elif obj == 22:
                    self._stamp(img, sword, x0 + 1, surface - 8, 26, 8)
                elif obj == 21:
                    self._stamp(img, bones, x0 + 2, surface - 18, 24, 18)

    def colorize(self, screen, alpha_black):
        """280x192 RGBA. Every lit pixel is Macintosh stone. A one-pixel
        gap between two lit pixels is filled, so the brick dither becomes
        solid stone and the hi-res colour fringe does not show. Black is
        the mortar, and transparent when this is a sprite."""
        img = Image.new("RGBA", (280, 192), (0, 0, 0, 0 if alpha_black else 255))
        px = img.load()
        for y in range(192):
            bits = []
            row = screen[y * 40:(y + 1) * 40]
            for b in row:
                for i in range(7):          # bit 0 is the leftmost pixel
                    bits.append((b >> i) & 1)
            col = [None] * 280
            for x in range(280):
                if bits[x]:
                    col[x] = STONE
            for x in range(1, 279):
                if bits[x] == 0 and bits[x - 1] and bits[x + 1]:
                    col[x] = STONE
            for x in range(280):
                if col[x]:
                    px[x, y] = col[x]
        return img

    def render_room(self, room):
        screen = bytearray(40 * 192)
        self.pxmask = bytearray(280 * 192)
        T = self.T

        def at(r, c, rm=room):
            if c < 0:
                nb = self.link(rm, 0)
                return self.tile_of(nb, r * 10 + 9) if nb >= 0 and 0 <= r <= 2 else (20, 0)
            if c > 9:
                nb = self.link(rm, 1)
                return self.tile_of(nb, r * 10) if nb >= 0 and 0 <= r <= 2 else (20, 0)
            if r > 2:
                nb = self.link(rm, 3)
                return self.tile_of(nb, c) if nb >= 0 else (1, 0)
            if r < 0:
                nb = self.link(rm, 2)
                return self.tile_of(nb, 20 + c) if nb >= 0 else (1, 0)
            return self.tile_of(rm, r * 10 + c)

        def cvis(o):
            return o == 0 or o == 9 or o == 12 or o >= 26

        def draw(r, c):
            obj, state = at(r, c)
            xco = c * 4
            dy = 191 - (2 - r) * 63
            ay = dy - 3
            left, lstate = at(r, c - 1)
            if cvis(obj):
                bobj, bst = at(r + 1, c - 1)
                if bobj == 20:
                    cn = T["blockc"][bst if bst < 2 else 0]
                elif bobj in (7, 12):
                    cn = T["panelc"][bst if bst < 3 else 0]
                else:
                    cn = T["piecec"][bobj] if bobj < 30 else 0
                if cn:
                    self.blit(screen, cn, xco, dy, 1)
                mb = T["maskb"][left] if left < 30 else 0
                if mb:
                    self.blit(screen, mb, xco, dy, 0)
            if obj != 20:
                if left == 20:
                    bn, by = T["blockb"][lstate if lstate < 2 else 0], 0
                elif left in (7, 12):
                    bn = T["panelb"][lstate if lstate < 3 else 0]
                    by = sb(T["pieceby"][left])
                elif left == 0:
                    st = lstate if 0 <= lstate < 4 else 0
                    bn, by = T["spaceb"][st], sb(T["spaceby"][st])
                elif left == 1:
                    st = lstate if 0 <= lstate < 4 else 0
                    bn, by = T["floorb"][st], sb(T["floorby"][st])
                else:
                    bn = T["pieceb"][left] if left < 30 else 0
                    by = sb(T["pieceby"][left]) if left < 30 else 0
                if bn:
                    self.blit(screen, bn, xco, ay + by, 1)
            if obj == 20:
                dn = T["blockd"][state if state < 2 else 0]
            else:
                dn = T["pieced"][obj] if obj < 30 else 0
            if dn:
                self.blit(screen, dn, xco, dy, 2)
            if left in (26, 7, 12, 9, 20):
                ma = T["maska"][obj] if obj < 30 else 0
                if ma:
                    self.blit(screen, ma, xco, ay, 0)
            an = T["piecea"][obj] if obj < 30 else 0
            if an:
                self.blit(screen, an, xco, ay + sb(T["pieceay"][obj]), 1)
            if obj == 20:
                fn, fy, fx = T["blockfr"][state if state < 2 else 0], 0, 0
            else:
                fn = T["fronti"][obj] if obj < 30 else 0
                fy = sb(T["fronty"][obj]) if obj < 30 else 0
                fx = T["frontx"][obj] if obj < 30 else 0
            if fn:
                self.blit(screen, fn, xco + fx, ay + fy, 4)

        for r in (2, 1, 0):
            for c in range(10):
                draw(r, c)
        # The lip of the floor on the screen above, along the top edge.
        up = self.link(room, 2)
        for c in range(10):
            if up < 0:
                obj, state = 1, 0
            else:
                obj, state = self.tile_of(up, 20 + c)
            if obj == 20:
                dn = T["blockd"][state if state < 2 else 0]
            else:
                dn = T["pieced"][obj] if obj < 30 else 0
            if dn:
                self.blit(screen, dn, c * 4, 2, 2)
        img = self._brick_image()
        self._stamp_props(img, room)
        self.pxmask = None
        return img

    def sprite(self, tab, n):
        """Macintosh color pose, scaled to the Apple II image so the feet
        land on the same point. The prince frames start at image 1."""
        w, h, raw = tab[n]
        if tab is self.ch1:
            path = os.path.join(MAC, "400 Prince", "frames", "%03d.png" % (n - 1))
        else:
            path = os.path.join(MAC, "1750 Guard", "frames", "%03d.png" % n)
        if h and os.path.exists(path):
            mac = Image.open(path).convert("RGBA")
            nw = max(1, int(round(mac.width * h / float(mac.height))))
            mac = mac.resize((nw, h), Image.Resampling.NEAREST)
            wide = max(w * 7, mac.width)
            img = Image.new("RGBA", (wide, h), (0, 0, 0, 0))
            img.paste(mac, ((wide - mac.width) // 2, 0), mac)
            return img
        # No color frame for this pose: a lit Apple II pixel is flesh.
        img = Image.new("RGBA", (w * 7, h), (0, 0, 0, 0))
        px = img.load()
        flesh = (236, 214, 176, 255)
        for row in range(h):
            for col in range(w):
                b = raw[row * w + col]
                for bit in range(7):
                    if (b >> bit) & 1:
                        px[col * 7 + bit, row] = flesh
        return img

    def pose_sheet(self, tab, ids):
        sheet = Image.new("RGBA", (CW * len(ids) * 2, CH), (0, 0, 0, 0))
        for i, n in enumerate(ids):
            spr = self.sprite(tab, n)
            cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
            cell.paste(spr, (AX - spr.width // 2, AY - spr.height), spr)
            sheet.paste(cell, (i * CW, 0))
            flipped = cell.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.paste(flipped, ((len(ids) + i) * CW, 0))
        return sheet


def main():
    art = Art()
    rows = blueprint_rows()
    if len(rows) != 72:
        raise SystemExit("expected 72 blueprint rows, got %d" % len(rows))
    # The HTML blueprint is the level. A mismatch would put the picture
    # on the wrong tiles.
    for i, row in enumerate(rows):
        room, r = divmod(i, 3)
        for c, ch in enumerate(row):
            got = ord(ch) - 65
            want = art.lvl[room * 30 + r * 10 + c] & 31
            if got != want:
                raise SystemExit("BP != LEVEL1 at room %d row %d col %d" % (room, r, c))

    rooms = Image.new("RGBA", (280 * 4, 192 * 6 + 63), (0, 0, 0, 255))
    for room in range(24):
        im = art.render_room(room)
        rooms.paste(im, ((room % 4) * 280, (room // 4) * 192))

    # One patch per tile the game can change, in the same order the HTML
    # scans BP (room, then row, then column).
    npatch = 0
    for room in range(24):
        for r in range(3):
            for c in range(10):
                obj, _st = art.tile_of(room, r * 10 + c)
                if obj not in MUTABLE:
                    continue
                art.overrides = {(room, r * 10 + c): MUTABLE[obj]}
                alt = art.render_room(room)
                art.overrides = {}
                crop = alt.crop((c * 28, 3 + r * 63, c * 28 + 28, 3 + r * 63 + 63))
                rooms.paste(crop, (npatch * 28, 192 * 6))
                npatch += 1

    kid = art.pose_sheet(art.ch1, KID_POSE)
    guard = art.pose_sheet(art.gd, GUARD_POSE)
    rooms.save(os.path.join(STORAGE, "PRINCE-0.png"))
    kid.save(os.path.join(STORAGE, "PRINCE-1.png"))
    guard.save(os.path.join(STORAGE, "PRINCE-2.png"))
    print("PRINCE-0", rooms.size, "patches", npatch)
    print("PRINCE-1", kid.size, "PRINCE-2", guard.size)


if __name__ == "__main__":
    main()
