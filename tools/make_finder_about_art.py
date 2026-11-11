#!/usr/bin/env python3
"""Put the Enterprise silhouette in Finder's art sheet for the About box.

  python3 tools/make_finder_about_art.py

Source: resources/system/art/enterprise_source.webp (1050x525, black ship on
white, "NCC-1701 / USS ENTERPRISE" lettering below it). Only the ship is used:
rows 0..SHIP_BOTTOM (the lettering starts at y=323), cropped to its ink box,
scaled to SHIP_W wide, thresholded to 1-bit.

Writes:
  resources/system/art/enterprise_about.png  the 1-bit picture (black/white)
  storage/FINDER-0.png  sheet 0: the Chicago font at y 0..63 (unchanged) and
                        the ship at (0,64) as a stencil: white around it,
                        transparent where the ship is. The old blue copy of
                        the font there was never drawn.
  storage/FINDER.ARTX   re-quantized from FINDER-0.png against the palette
                        already in FINDER.ARTX (so the font keeps index 9,
                        exactly as before), then the stencil's white is set
                        to raw index 255. Finder has no .ARTJS.

Finder (role 9) paints sprite bytes as RGB332 indexes, not through the .ARTX
palette, so the quantizer's black (index 9) would show dark teal. Instead
drawAbout() fills the picture rectangle with black (#000000 = index 0) and
draws the stencil over it: 255 is RGB332 white, 0 is transparent, so the
ship stays pure black. Re-run this tool, not tools/make_artx.py FINDER, which
would quantize the stencil's white to index 1 (dark blue).

FINDER.HTML drawAbout() draws sheet 0 at (0,64,SHIP_W,SHIP_H). Re-mint
FINDER.JSH afterwards. No code bytes are added for the picture and the
.ARTX size does not change, so FINDER.JSH stays under the Finder cache.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.jsb_format import build_artx, read_artx  # noqa: E402
from tools.compile_js import _quantize_sprites  # noqa: E402
from tools.make_artx import _images_from_jmr_spr, read_jmr_spr  # noqa: E402

ART = ROOT / "resources" / "system" / "art"
STORAGE = ROOT / "storage"
SHIP_BOTTOM = 315  # ship ink ends at y=306; the lettering starts at y=323
SHIP_W, SHIP_H = 240, 62  # FINDER.HTML drawAbout() uses these numbers
SHEET_Y = 64


def ship() -> Image.Image:
    src = Image.open(ART / "enterprise_source.webp").convert("L")
    src = src.crop((0, 0, src.width, SHIP_BOTTOM))
    ink = src.point(lambda v: 255 if v < 128 else 0)
    src = src.crop(ink.getbbox())
    small = src.resize((SHIP_W, SHIP_H), Image.Resampling.LANCZOS)
    return small.point(lambda v: 0 if v < 128 else 255).convert("1")


def main() -> None:
    pic = ship()
    pic.save(ART / "enterprise_about.png")
    sheet_path = STORAGE / "FINDER-0.png"
    sheet = Image.open(sheet_path).convert("RGBA")
    sheet.paste((0, 0, 0, 0), (0, SHEET_Y, sheet.width, sheet.height))
    white = Image.new("RGBA", pic.size, (255, 255, 255, 255))
    around = pic.point(lambda v: 255 if v else 0).convert("L")
    sheet.paste(white, (0, SHEET_Y), around)
    sheet.save(sheet_path)

    html = (STORAGE / "FINDER.HTML").read_text(encoding="utf-8")
    images = _images_from_jmr_spr(read_jmr_spr(html))
    # A fresh title palette would renumber the font's black (the blue copy is
    # gone), and Finder draws raw indexes. Keep the palette already shipped.
    palette = read_artx((STORAGE / "FINDER.ARTX").read_bytes())[0]
    sprites = _quantize_sprites(images, palette)
    w, h, pix = sprites[0]
    pix = bytearray(pix)
    for i in range(SHEET_Y * w, h * w):
        if pix[i]:
            pix[i] = 255  # RGB332 white; 0 stays transparent
    sprites[0] = (w, h, bytes(pix))
    artx = build_artx(palette, sprites)
    (STORAGE / "FINDER.ARTX").write_bytes(artx)
    print(f"ship {SHIP_W}x{SHIP_H} at (0,{SHEET_Y}); FINDER.ARTX {len(artx)} bytes")


if __name__ == "__main__":
    main()
