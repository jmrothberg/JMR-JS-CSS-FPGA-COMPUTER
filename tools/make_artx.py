#!/usr/bin/env python3
"""Quantize title art to NAME.ARTX (machine). PNGs stay the editable source.

New game (HTML already has jmr:spr:N + window.JMR_SPR listing STEM-N.png):

  python3 tools/make_artx.py MYGAME
  python3 tools/make_artx.py /path/to/bomberman.html

A path is looked up as-is (not uppercased). The tool copies STEM.HTML,
writes STEM.ARTX + STEM.ARTJS, and wires the Chrome shim so jmr:spr
loads __jmrSpr from the .ARTJS (same hook as INVF/DNKF). PNGs stay next
to the source HTML. Stem is the filename, card 8.3 (bomberman.html →
BOMBERMA). A bare MYGAME still reads storage/MYGAME.HTML. Then:

  python3 tools/make_sd_image.py create card.img

No args still migrates the old inlined-base64 titles to short names
(INVADERS→INVA, …). Originals are not rewritten. JMR_SPR order IS the
handle numbering — append-only. Mint strips data-host=chrome, so the
machine never sees the list.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.jsb_format import build_artx, read_artx  # noqa: E402
from tools.compile_js import (  # noqa: E402
    _build_title_palette,
    _extract_data_uri_sprites,
    _harvest_source_colors,
    _quantize_sprites,
    compile_html_text,
    encode_html_chunk,
)

STORAGE = ROOT / "storage"

# Original stem → new card-safe stem (≤8). Originals are not rewritten.
TITLES = {
    "INVADERS": "INVA",
    "INVFAST": "INVF",
    "FLDFAST": "FLDF",
    "MRDOFAST": "MRDOF",
    "DNKFAST": "DNKF",
    "MKBIG": "MKBA",
    "MKBIGCPU": "MKCA",
}

# Same block as docs/GAME_DESIGN.md "Making the same file run in Chrome".
_SHIM = """\
<script data-host="chrome">
// Chrome-only. Maps the machine's sprite handles to the real PNGs.
// This list is ALSO the art manifest make_artx.py reads — one source of
// truth, so the browser and the .ARTX can never disagree about order.
window.JMR_SPR = [%s];
(function () {
  var d = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, "src");
  Object.defineProperty(HTMLImageElement.prototype, "src", {
    get: function () { return d.get.call(this); },
    set: function (v) {
      var m = /^jmr:spr:(\\d+)$/.exec(v);
      d.set.call(this, m ? window.JMR_SPR[+m[1]] : v);
    }
  });
})();
</script>
"""

_JMR_SPR_ASSIGN = re.compile(r"window\.JMR_SPR\s*=\s*\[(.*?)\]", re.S)


def _game_source(html: str) -> str:
    """Joined <script> bodies the mint compiles (chrome blocks stripped)."""
    bodies = []
    for m in re.finditer(r"<script([^>]*)>(.*?)</script>", html, re.S | re.I):
        attrs = m.group(1) or ""
        if re.search(r'data-host\s*=\s*["\']chrome["\']', attrs, re.I):
            continue
        bodies.append(m.group(2))
    return ";\n".join(bodies)


def _source_sheets(html: str):
    """PIL RGBA sheets in jmr:spr:N / ARTX order (first-appearance, deduped)."""
    _src, images = _extract_data_uri_sprites(_game_source(html))
    return images


def read_jmr_spr(html: str) -> list[str] | None:
    """PNG filenames from window.JMR_SPR, or None if the shim is absent."""
    m = _JMR_SPR_ASSIGN.search(html)
    if not m:
        return None
    return re.findall(r'["\']([^"\']+)["\']', m.group(1))


def _shim_html(png_names: list[str]) -> str:
    inner = ", ".join(f'"{n}"' for n in png_names)
    return _SHIM % inner


def ensure_chrome_shim(html: str, png_names: list[str]) -> str:
    """Insert or refresh the JMR_SPR list before the first game script.

    Does not touch game code. A second data-host=chrome block (Web Audio)
    at the end of the file is left alone. Does not strip a .ARTJS interceptor
    — Chrome paints from ARTJS; JMR_SPR stays the PNG manifest this tool reads.
    """
    have = read_jmr_spr(html)
    if have == png_names:
        return html
    if have is not None:
        inner = ", ".join(f'"{n}"' for n in png_names)
        return _JMR_SPR_ASSIGN.sub(
            f"window.JMR_SPR = [{inner}]", html, count=1
        )
    block = _shim_html(png_names)
    for m in re.finditer(r"<script([^>]*)>", html, re.I):
        attrs = m.group(1) or ""
        if re.search(r'data-host\s*=\s*["\']chrome["\']', attrs, re.I):
            continue
        return html[: m.start()] + block + html[m.start() :]
    raise SystemExit("no game <script> to place the Chrome shim before")


def _write_pngs(dst_stem: str, images) -> list[str]:
    """Write STEM-N.png from the sheets that built the .ARTX (PIL order = N)."""
    from PIL import Image as PILImage

    names = []
    for i, im in enumerate(images):
        name = f"{dst_stem}-{i}.png"
        path = STORAGE / name
        sheet = im if im is not None else PILImage.new("RGBA", (1, 1), (0, 0, 0, 0))
        sheet.save(path, format="PNG")
        names.append(name)
    return names


def _artx_table(path: Path) -> list[tuple[int, int]]:
    _pal, sprites, _payload = read_artx(path.read_bytes())
    return [(w, h) for w, h, _pix in sprites]


def _images_from_jmr_spr(names: list[str], *, base: Path = STORAGE):
    from PIL import Image as PILImage

    out = []
    for name in names:
        path = Path(name)
        if not path.is_absolute():
            path = base / name
        if not path.is_file():
            raise SystemExit(f"JMR_SPR lists {name} but {path} is missing")
        out.append(PILImage.open(path).convert("RGBA"))
    return out


def _card_stem(filename: str) -> str:
    """8.3 card stem from a filename. bomberman.html → BOMBERMA."""
    return Path(filename).stem.upper()[:8]


def _is_html_path(arg: str) -> bool:
    """True when ARG is a filesystem path, not a storage/ stem.

    Do not uppercase before lookup — Linux paths are case-sensitive.
    A bare MYGAME / MYGAME.HTML is still the storage/ stem.
    """
    if "/" in arg or arg.startswith("~"):
        return True
    return Path(arg).is_file()


def pack_from_pngs(stem: str, *, html_path: Path | None = None) -> str:
    """Quantize JMR_SPR PNGs → storage/STEM.ARTX.

    html_path: read that file (any case) and copy it to storage/STEM.HTML.
    PNGs stay next to the source HTML — they are not copied into storage/.
    No html_path: existing title already in storage/ (PNGs also there).
    """
    dest_html = STORAGE / f"{stem}.HTML"
    dest_artx = STORAGE / f"{stem}.ARTX"
    if html_path is None:
        src_html_path = dest_html
        png_dir = STORAGE
        copy_html = False
    else:
        src_html_path = html_path.expanduser().resolve()
        png_dir = src_html_path.parent
        copy_html = src_html_path != dest_html.resolve()
    if not src_html_path.is_file():
        raise SystemExit(f"missing {src_html_path}")
    html = src_html_path.read_text(encoding="utf-8")
    names = read_jmr_spr(html)
    if not names:
        raise SystemExit(
            f"{stem}: no window.JMR_SPR in {src_html_path.name} — list the PNG "
            f"filenames so this tool knows sheet order"
        )
    images = _images_from_jmr_spr(names, base=png_dir)
    src = _game_source(html)
    harvested = _harvest_source_colors(src)
    palette = _build_title_palette(images, harvested)
    sprites = _quantize_sprites(images, palette)
    artx = build_artx(palette, sprites)
    if copy_html:
        dest_html.write_text(html, encoding="utf-8")
    dest_artx.write_bytes(artx)
    # Chrome cannot read .ARTX. Write .ARTJS and point jmr:spr at __jmrSpr
    # (not the PNG names). PNGs stay next to the source HTML.
    from tools.make_artjs import artjs_for, patch_html  # noqa: E402

    dest_artjs = STORAGE / f"{stem}.ARTJS"
    dest_artjs.write_text(artjs_for(artx), encoding="utf-8")
    chrome = patch_html(stem)
    copied = f"{dest_html.name} + " if copy_html else ""
    return (
        f"ok {src_html_path} + {len(names)} png → {copied}{dest_artx.name} "
        f"+ {dest_artjs.name} ({len(artx)} bytes) [{chrome.strip()}]"
    )


def migrate_one(src_stem: str, dst_stem: str, *, check: bool = True) -> str:
    """Write DST.HTML + DST.ARTX + DST-N.png. Does not touch SRC.HTML."""
    src_path = STORAGE / f"{src_stem}.HTML"
    dst_html_path = STORAGE / f"{dst_stem}.HTML"
    dst_artx_path = STORAGE / f"{dst_stem}.ARTX"
    if not src_path.is_file():
        raise SystemExit(f"missing {src_path}")

    src_html = src_path.read_text(encoding="utf-8")
    if "data:image/" not in src_html:
        raise SystemExit(f"{src_path.name} has no data:image to extract")

    sheets = _source_sheets(src_html)
    png_names = [f"{dst_stem}-{i}.png" for i in range(len(sheets))]

    dst_html = (
        dst_html_path.read_text(encoding="utf-8")
        if dst_html_path.is_file()
        else None
    )
    have_spr = read_jmr_spr(dst_html) if dst_html else None
    pngs_ok = all((STORAGE / n).is_file() for n in png_names)

    # Idempotent: dest already has the shim, the PNGs, and the sidecar.
    if (
        dst_html
        and have_spr == png_names
        and pngs_ok
        and dst_artx_path.is_file()
        and "jmr:spr:" in dst_html
        and "data:image/" not in dst_html
    ):
        table = _artx_table(dst_artx_path)
        if len(table) != len(png_names):
            raise SystemExit(
                f"{dst_stem}: JMR_SPR has {len(png_names)} entries, "
                f".ARTX has {len(table)} sprites"
            )
        dst_html_path.write_text(dst_html, encoding="utf-8")
        return f"ok {src_path.name} → {dst_html_path.name} (already extracted)"

    # Gold mint from the original (data URIs). ARTX and the identity gate
    # both come from this chunk so we never re-quantize a different way.
    chunk = compile_html_text(src_html, source_path=src_path)
    gold = encode_html_chunk(chunk) if check else None
    artx = build_artx(chunk.palette, chunk.sprites)

    if not chunk.sprites or len(chunk.sprites) != len(sheets):
        raise SystemExit(
            f"{src_stem}: extract found {len(sheets)} sheets, "
            f"mint has {0 if not chunk.sprites else len(chunk.sprites)}"
        )
    for i, ((w, h, _pix), im) in enumerate(zip(chunk.sprites, sheets)):
        size = (1, 1) if im is None else im.size
        if size != (w, h):
            raise SystemExit(
                f"{dst_stem}-{i}.png would be {size[0]}x{size[1]}, "
                f".ARTX[{i}] is {w}x{h} — JMR_SPR order would paint the wrong sheet"
            )

    png_names = _write_pngs(dst_stem, sheets)
    dst_artx_path.write_bytes(artx)

    if dst_html is None:
        new_html, _images = _extract_data_uri_sprites(src_html)
        if "data:image/" in new_html:
            raise SystemExit(f"{src_path.name}: data URI survived rewrite")
        dst_html = new_html
    dst_html = ensure_chrome_shim(dst_html, png_names)
    dst_html_path.write_text(dst_html, encoding="utf-8")

    # Manifest round-trip: JMR_SPR → PNGs must be the ARTX table.
    listed = read_jmr_spr(dst_html)
    if listed != png_names:
        raise SystemExit(f"{dst_stem}: JMR_SPR {listed!r} != {png_names!r}")
    table = _artx_table(dst_artx_path)
    png_images = _images_from_jmr_spr(listed)
    if len(png_images) != len(table):
        raise SystemExit(
            f"{dst_stem}: JMR_SPR has {len(png_images)} PNGs, "
            f".ARTX has {len(table)} sprites"
        )
    for i, (im, (w, h)) in enumerate(zip(png_images, table)):
        if im.size != (w, h):
            raise SystemExit(
                f"{listed[i]} is {im.size[0]}x{im.size[1]}, "
                f".ARTX[{i}] is {w}x{h}"
            )

    if check:
        after = encode_html_chunk(
            compile_html_text(dst_html, source_path=dst_html_path)
        )
        if after != gold:
            raise SystemExit(
                f"{src_stem}→{dst_stem}: mint differs "
                f"({len(gold)} vs {len(after)} bytes) — chrome shim must strip"
            )

    return (
        f"ok {src_path.name} → {dst_html_path.name} + {dst_artx_path.name} "
        f"+ {len(png_names)} png "
        f"({len(dst_html.encode('utf-8'))} src, {len(artx)} artx)"
    )


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "names",
        nargs="*",
        help="MYGAME (storage stem), /path/to/game.html (copy HTML+ARTX+ARTJS "
        "into storage/, wire Chrome), or INVADERS (migrate). Default: migrate the seven.",
    )
    ap.add_argument(
        "--no-check",
        action="store_true",
        help="skip the byte-identical mint compare (faster, not the gate)",
    )
    args = ap.parse_args(argv)
    check = not args.no_check
    if not args.names:
        for src_stem, dst_stem in TITLES.items():
            print(migrate_one(src_stem, dst_stem, check=check))
        return 0
    for raw in args.names:
        if _is_html_path(raw):
            src = Path(raw)
            print(pack_from_pngs(_card_stem(src.name), html_path=src))
            continue
        stem = raw.upper().removesuffix(".HTML").removesuffix(".ARTX")
        if stem in TITLES:
            print(migrate_one(stem, TITLES[stem], check=check))
        else:
            print(pack_from_pngs(stem))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
