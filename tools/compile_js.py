#!/usr/bin/env python3
"""Compile storage/*.JS → .JSB and storage/*.HTML scripts → .JSH.

  python3 tools/compile_js.py storage/INVADERS.JS
  python3 tools/compile_js.py --all
  python3 tools/compile_js.py --html storage/INVADERS.HTML
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

# Default CanvasEngine 8-slot pal — sprite pixels match FPGA-SIM GUI / RTL HDMI-ish.
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


def _pal8(r: int, g: int, b: int, a: int) -> int:
    if a < 16:
        return 0
    best, bd = 1, 1 << 30
    for i, (pr, pg, pb) in enumerate(_PAL8):
        d = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb)
        if d < bd:
            best, bd = i, d
    return best


def _extract_data_uri_sprites(src: str):
    """Replace data:image/png;base64,… with jmr:spr:N and build indexed pack."""
    import base64
    import re
    from io import BytesIO

    sprites = []
    pat = re.compile(r"data:image/[a-zA-Z0-9+./;=,_-]+")

    def repl(m):
        uri = m.group(0)
        if "," not in uri:
            return uri
        header, b64 = uri.split(",", 1)
        if "base64" not in header.lower():
            return uri
        try:
            from PIL import Image as PILImage

            blob = base64.b64decode(b64)
            im = PILImage.open(BytesIO(blob)).convert("RGBA")
        except Exception:
            n = len(sprites)
            sprites.append((1, 1, b"\x00"))
            return f"jmr:spr:{n}"
        w, h = im.size
        # cap a single sheet so .JSH + SPR1 fits code BRAM (32K words)
        while w * h > 180000:
            im = im.resize((max(1, w // 2), max(1, h // 2)))
            w, h = im.size
        pix = bytearray(w * h)
        px = im.load()
        for yy in range(h):
            row = yy * w
            for xx in range(w):
                r, g, b, a = px[xx, yy]
                pix[row + xx] = _pal8(r, g, b, a)
        n = len(sprites)
        sprites.append((w, h, bytes(pix)))
        return f"jmr:spr:{n}"

    return pat.sub(repl, src), sprites


def compile_one(src_path: Path, out_dir: Path | None = None) -> Path:
    text = src_path.read_text(encoding="utf-8")
    chunk = compile_source(text)
    blob = encode_chunk(chunk)
    dest = (out_dir or src_path.parent) / (src_path.stem.upper()[:8] + ".JSB")
    dest.write_bytes(blob)
    print(f"wrote {dest} ({len(blob)} bytes, {len(chunk.code)} ops)")
    # Hex for RTL $readmemh (INVADERS → vectors/invaders_jsb.hex)
    if src_path.stem.upper() == "INVADERS":
        VECTORS.mkdir(parents=True, exist_ok=True)
        hex_path = VECTORS / "invaders_jsb.hex"
        hex_path.write_text(jsb_to_hex_lines(blob, width=4))
        print(f"wrote {hex_path}")
    return dest


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
    src = "\n".join(bodies)
    src, sprites = _extract_data_uri_sprites(src)
    try:
        chunk = compile_source(src)
    except CompileError as e:
        e.line = _js_line_to_html(spans, e.line or 0)
        raise
    chunk.sprites = sprites or None
    return chunk


def encode_html_chunk(chunk) -> bytes:
    """Fresh internal .JSH bytes (JSB v2 + optional SPR1)."""
    return encode_chunk(chunk, v2=True, sprites=getattr(chunk, "sprites", None))


def compile_html_one(src_path: Path, out_dir: Path | None = None) -> Path:
    """Compile HTML <script> → fresh NAME.JSH (compile-on-RUN cache, not a LOAD name)."""
    html = src_path.read_text(encoding="utf-8")
    chunk = compile_html_text(html)
    blob = encode_html_chunk(chunk)
    dest = (out_dir or src_path.parent) / (src_path.stem.upper()[:8] + ".JSH")
    dest.write_bytes(blob)
    print(f"wrote {dest} ({len(blob)} bytes, {len(chunk.code)} ops, JSB v2)")
    return dest


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="*", type=Path)
    ap.add_argument("--all", action="store_true", help="compile all storage/*.JS")
    ap.add_argument(
        "--html",
        action="store_true",
        help="compile HTML <script> → .JSH (also with --all)",
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
