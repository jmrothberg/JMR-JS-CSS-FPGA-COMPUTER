#!/usr/bin/env python3
"""Compile storage/*.JS → .JSB (legacy smoke). HTML titles compile in memory
on RUN — this tool does not write a sidecar next to the HTML.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.compiler import compile_source  # noqa: E402
from functional_model.jsb_format import encode_chunk, jsb_to_hex_lines  # noqa: E402

STORAGE = ROOT / "storage"
VECTORS = ROOT / "vectors"

# Legacy fixed 8 (palette entries 0..7 stay frozen; monitor glass uses them).
_PAL8 = [
    (0, 0, 0),
    (255, 255, 255),
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 0),
    (0, 255, 255),
    (255, 0, 255),
]


def _extract_data_uri_sprites(src: str):
    """Replace data:image/…;base64,… with jmr:spr:N; keep FULL-RES RGBA sheets.

    ARCHITECTURE (2026-08-13): the old path downscaled sheets (`w*h > 180000`)
    and quantized to 8 colors so pixels fit code BRAM — that trap is removed.
    Sheets stay full quality; they are quantized against the per-title
    256-entry palette (_quantize_sprites) and ride the ProgramImage ASET section into
    the external SRAM asset bank, never into code BRAM.
    """
    import base64
    from io import BytesIO

    images = []  # PIL RGBA images (None = undecodable → 1×1 blank)
    seen: dict = {}  # identical data URIs share one sprite handle (dedup)
    pat = re.compile(r"data:image/[a-zA-Z0-9+./;=,_-]+")

    def repl(m):
        uri = m.group(0)
        if "," not in uri:
            return uri
        header, b64 = uri.split(",", 1)
        if "base64" not in header.lower():
            return uri
        if uri in seen:
            return f"jmr:spr:{seen[uri]}"
        try:
            from PIL import Image as PILImage

            blob = base64.b64decode(b64)
            im = PILImage.open(BytesIO(blob)).convert("RGBA")
        except Exception:
            im = None
        n = len(images)
        images.append(im)
        seen[uri] = n
        return f"jmr:spr:{n}"

    return pat.sub(repl, src), images


# String literals that might be CSS colors ('#fff', 'rgb(…)', 'orange', …)
_COLOR_TOKEN = re.compile(
    r"""['"](#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?(?:[0-9a-fA-F]{2})?"""
    r"""|rgba?\([^)'"]*\)|[a-zA-Z]{3,20})['"]"""
)


def _harvest_source_colors(src: str, cap: int = 120):
    """Exact fillStyle/strokeStyle colors from the JS source → palette seeds."""
    from functional_model.canvas_engine import parse_css_color

    out = []
    seen = set()
    for m in _COLOR_TOKEN.finditer(src):
        rgb = parse_css_color(m.group(1))
        if rgb and rgb not in seen:
            seen.add(rgb)
            out.append(rgb)
            if len(out) >= cap:
                break
    return out


def _build_title_palette(images, harvested):
    """256-entry title palette: 0..7 legacy fixed, then harvested source
    colors (exact fillStyle hits), then adaptive colors from the sheets."""
    pal = list(_PAL8)
    for rgb in harvested:
        if rgb not in pal and len(pal) < 256:
            pal.append(rgb)
    room = 256 - len(pal)
    if room > 0 and any(im is not None for im in images):
        from PIL import Image as PILImage

        samples = []
        for im in images:
            if im is None:
                continue
            w, h = im.size
            step = max(1, (w * h) // 65536)  # cap work per sheet
            for px in list(im.getdata())[::step]:
                r, g, b, a = px
                if a >= 16:
                    samples.append((r, g, b))
        if samples:
            strip = PILImage.new("RGB", (len(samples), 1))
            strip.putdata(samples)
            q = strip.quantize(colors=room)
            qp = q.getpalette()[: room * 3]
            for i in range(0, len(qp), 3):
                rgb = (qp[i], qp[i + 1], qp[i + 2])
                if rgb not in pal and len(pal) < 256:
                    pal.append(rgb)
    while len(pal) < 256:
        pal.append((0, 0, 0))
    return pal


def _quantize_sprites(images, pal):
    """RGBA sheets → full-res 8-bpp indices in the title palette; alpha<16 → 0.

    Quantizes against entries 1..255 (temp palette shifted by one) so opaque
    black maps to ink, never to transparent index 0. All Pillow C paths —
    no per-pixel Python loop over Donkey-size sheets.
    """
    from PIL import Image as PILImage

    pimg = PILImage.new("P", (1, 1))
    flat = []
    for r, g, b in pal[1:256]:
        flat.extend((r, g, b))
    pimg.putpalette(flat)
    out = []
    for im in images:
        if im is None:
            out.append((1, 1, b"\x00"))
            continue
        w, h = im.size
        q = im.convert("RGB").quantize(palette=pimg, dither=0)
        q = q.point(lambda i: i + 1 if i < 255 else 255)
        mask = im.getchannel("A").point(lambda a: 255 if a < 16 else 0)
        q.paste(0, mask=mask)
        out.append((w, h, q.tobytes()))
    return out


def compile_one(src_path: Path, out_dir: Path | None = None) -> Path:
    # exec32 retirement: standalone .JS sidecar builds are not a product
    # path (HTML compile-on-RUN only). Refuse rather than mint a .JSB /
    # invaders_jsb.hex nobody should boot (docs/REMOVING_EXEC32.md).
    raise SystemExit(
        f"refusing {src_path.name}: .JS sidecar compiles are retired with "
        "exec32 — HTML titles compile on RUN (encode_html_chunk)"
    )


def _js_line_to_html(spans, js_line: int) -> int:
    """Map 1-based JS line in joined <script> bodies to HTML file line."""
    if js_line <= 0 or not spans:
        return js_line or 0
    remain = js_line
    for i, (h0, n) in enumerate(spans):
        if remain <= n:
            return h0 + remain - 1
        remain -= n
        if i + 1 < len(spans):
            # "\\n".join adds one line between scripts
            if remain == 1:
                return spans[i + 1][0]
            remain -= 1
    h0, n = spans[-1]
    return h0 + n - 1


def compile_html_text(html: str):
    """Compile-on-RUN: current HTML <script> → Chunk. CompileError.line is HTML line."""
    from functional_model.compiler import CompileError, compile_source

    spans = []
    bodies = []
    for m in re.finditer(r"<script[^>]*>(.*?)</script>", html, re.S | re.I):
        body = m.group(1)
        h0 = html[: m.start(1)].count("\n") + 1
        bodies.append(body)
        spans.append((h0, body.count("\n") + 1))
    if not any(b.strip() for b in bodies):
        raise CompileError("NO SCRIPT IN HTML", 1)
    # NEW: ';' between <script> blocks — browsers end statements at script
    # boundaries; a bare "\n" join glued DONKEY's `rAF(update)` to the next
    # script's `(function(){...})()` as a call chain (ASI hazard).
    src = ";\n".join(bodies)
    src, images = _extract_data_uri_sprites(src)
    harvested = _harvest_source_colors(src)
    palette = _build_title_palette(images, harvested)
    sprites = _quantize_sprites(images, palette)
    try:
        chunk = compile_source(src)
    except CompileError as e:
        e.line = _js_line_to_html(spans, e.line or 0)
        raise
    chunk.sprites = sprites or None
    chunk.palette = palette
    return chunk


def encode_html_chunk(chunk) -> bytes:
    """ProgramImage bytes (JSB v2 + SPRD descriptors + ASET section).

    HTML titles always take the ASET path: full-res sprite banks + the
    per-title palette stream to the external SRAM asset bank; code BRAM
    only ever sees bytecode + descriptors. Not a disk sidecar.
    """
    # Product HTML images always carry the frozen 64-bit Value ABI so PYTHON
    # and FPGA-SIM execute the same serialized words.
    return encode_chunk(
        chunk,
        v2=True,
        sprites=getattr(chunk, "sprites", None),
        aset=True,
        value64=True,
    )


def compile_html_one(src_path: Path, out_dir: Path | None = None) -> Path:
    """Compile HTML <script> and print size; do not write a sidecar file."""
    html = src_path.read_text(encoding="utf-8")
    chunk = compile_html_text(html)
    blob = encode_html_chunk(chunk)
    print(f"ok {src_path} ({len(blob)} bytes, {len(chunk.code)} ops)")
    return src_path


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="*", type=Path)
    ap.add_argument("--all", action="store_true", help="compile all storage/*.JS")
    ap.add_argument(
        "--html",
        action="store_true",
        help="compile HTML <script> in memory (no sidecar file)",
    )
    args = ap.parse_args(argv)
    paths = list(args.paths)
    if args.all:
        paths.extend(sorted(STORAGE.glob("*.JS")))
        paths.extend(sorted(STORAGE.glob("*.js")))
        if args.html:
            paths.extend(sorted(STORAGE.glob("*.HTML")))
    if not paths:
        ap.error("pass .JS/.HTML paths or --all")
    for p in paths:
        src = p.resolve() if p.is_absolute() else (ROOT / p if not p.exists() else p)
        if src.suffix.upper() in (".HTML", ".HTM") or (
            args.html and src.suffix.upper() in (".HTML", ".HTM")
        ):
            compile_html_one(src)
        else:
            compile_one(src)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
