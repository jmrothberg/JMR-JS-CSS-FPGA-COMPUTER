#!/usr/bin/env python3
"""Export font8 glyphs as $readmemh hex for jmr_text_hdmi_scanout.

  python3 tools/export_font_rom_hex.py
  # → vectors/font_rom.hex  (128 glyphs × 8 rows = 1024 bytes)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.font8 import glyph  # noqa: E402

DEFAULT_HEX = ROOT / "vectors" / "font_rom.hex"


def build_font_rom() -> bytes:
    out = bytearray(1024)
    for code in range(128):
        rows = glyph(chr(code) if 32 <= code < 127 else " ")
        for r in range(8):
            out[code * 8 + r] = rows[r] if r < len(rows) else 0
    return bytes(out)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--hex", type=Path, default=DEFAULT_HEX)
    args = ap.parse_args(argv)
    data = build_font_rom()
    args.hex.parent.mkdir(parents=True, exist_ok=True)
    args.hex.write_text("\n".join(f"{b:02X}" for b in data) + "\n")
    print(f"wrote {args.hex} ({len(data)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
