#!/usr/bin/env python3
"""Compile storage/*.JS → .JSB (+ optional $readmemh for RTL VM).

  python3 tools/compile_js.py storage/INVADERS.JS
  python3 tools/compile_js.py --all
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.compiler import compile_source  # noqa: E402
from functional_model.jsb_format import encode_chunk, jsb_to_hex_lines  # noqa: E402

STORAGE = ROOT / "storage"
VECTORS = ROOT / "vectors"


def compile_one(src_path: Path, out_dir: Path | None = None) -> Path:
    text = src_path.read_text(encoding="utf-8")
    chunk = compile_source(text)
    blob = encode_chunk(chunk)
    dest = (out_dir or src_path.parent) / (src_path.stem.upper() + ".JSB")
    # Keep stem case for 8.3: INVADERS.JSB
    dest = (out_dir or src_path.parent) / (src_path.stem + ".JSB")
    if src_path.stem.upper() == src_path.stem or True:
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


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="*", type=Path)
    ap.add_argument("--all", action="store_true", help="compile all storage/*.JS")
    args = ap.parse_args(argv)
    paths = list(args.paths)
    if args.all:
        paths.extend(sorted(STORAGE.glob("*.JS")))
        paths.extend(sorted(STORAGE.glob("*.js")))
    if not paths:
        ap.error("pass .JS paths or --all")
    for p in paths:
        compile_one(p.resolve() if p.is_absolute() else (ROOT / p if not p.exists() else p))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
