#!/usr/bin/env python3
"""Build storage/MKBIG.HTML — max MK art that fits V1 RTL (16 SPR, 4 MB ASET).

Reads digitized frames from storage/MK.HTML, packs them into three atlases
(arena + subzero + kano, each fighter sheet = left + right rows), and emits
a slim MKPVP-style V1 title that compiles with tools/compile_js.py today.

Run from repo root:
  python3 tools/mkbig.py
  python3 tools/compile_js.py storage/MKBIG.HTML
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import sys
from io import BytesIO
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.jsb_format import SRAM_BYTES, build_aset_payload
from tools.compile_js import (
    _build_title_palette,
    _harvest_source_colors,
    _quantize_sprites,
)

MK_SRC = ROOT / "storage" / "MK.HTML"
MKPVP_SRC = ROOT / "storage" / "MKPVP.HTML"
OUT = ROOT / "storage" / "MKBIG.HTML"

# Core MKPVP moves (V1 engine knows these anim names).
CORE_MOVES = [
    "stand",
    "walking",
    "walking-backward",
    "blocking",
    "endure",
    "high-punch",
    "low-punch",
    "high-kick",
    "low-kick",
    "jumping",
    "squating",
    "uppercut",
]
# Try extras only after core frames are maxed (still under 4 MB).
EXTRA_MOVES = ["spin-kick", "knock-down", "fall", "win"]

MAX_ATLAS_W = 4096
ARENA_SIZE = (640, 480)


def _load_mk_images(path: Path) -> dict[str, "object"]:
    from PIL import Image

    text = path.read_text(encoding="utf-8")
    pat = re.compile(r'"([^"]+)":\s*"(data:image/[^"]+)"')
    out: dict[str, object] = {}
    for img_path, uri in pat.findall(text):
        if "base64," not in uri:
            continue
        blob = base64.b64decode(uri.split(",", 1)[1])
        out[img_path] = Image.open(BytesIO(blob)).convert("RGBA")
    return out


def _frame_paths(
    imgs: dict,
    fighter: str,
    side: str,
    move: str,
    limit: int,
) -> list[str]:
    prefix = f"images/fighters/{fighter}/{side}/{move}/"
    keys = [k for k in imgs if k.startswith(prefix)]

    def frame_num(k: str) -> int:
        return int(k.rsplit("/", 1)[-1].split(".")[0])

    keys.sort(key=frame_num)
    return keys[:limit]


def _pack_frames(
    tagged_frames: list[tuple[str, str, str, object]],
    max_w: int = MAX_ATLAS_W,
) -> tuple[object, dict[str, dict[str, list[list[int]]]]]:
    """tagged_frames: (side, move, path, PIL image) → atlas + FRAMES[side][move]."""
    from PIL import Image

    x = y = row_h = 0
    placements: list[tuple[str, str, object, int, int, int, int]] = []
    for side, move, _path, im in tagged_frames:
        w, h = im.size
        if x + w > max_w and x > 0:
            x = 0
            y += row_h
            row_h = 0
        placements.append((side, move, im, x, y, w, h))
        x += w
        row_h = max(row_h, h)
    if not placements:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0)), {"left": {}, "right": {}}
    aw = max(px + w for _s, _m, _im, px, _py, w, _h in placements)
    ah = max(py + h for _s, _m, _im, _px, py, _h, h in placements)
    atlas = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
    frames: dict[str, dict[str, list[list[int]]]] = {"left": {}, "right": {}}
    for side, move, im, px, py, w, h in placements:
        atlas.paste(im, (px, py))
        frames[side].setdefault(move, []).append([px, py, w, h])
    return atlas, frames


def _fighter_frames(
    imgs: dict,
    fighter: str,
    move_limits: dict[str, int],
) -> list[tuple[str, str, str, object]]:
    tagged = []
    for move, limit in move_limits.items():
        for side in ("left", "right"):
            for path in _frame_paths(imgs, fighter, side, move, limit):
                tagged.append((side, move, path, imgs[path]))
    return tagged


def _estimate_payload(atlases: list) -> tuple[int, int]:
    harvested = _harvest_source_colors('fillStyle="#fff"')
    palette = _build_title_palette(atlases, harvested)
    sprites = _quantize_sprites(atlases, palette)
    payload, descs = build_aset_payload(palette, sprites)
    return len(payload), len(descs)


def _fits(imgs: dict, limits: dict[str, int]) -> bool:
    try:
        _build_atlases(imgs, limits, [])
        return True
    except ValueError:
        return False


def _pick_move_limits(imgs: dict) -> dict[str, int]:
    """Greedy: max frames per core move, then grow extras into leftover budget."""
    limits = {m: 10 for m in CORE_MOVES}
    while not _fits(imgs, limits):
        top = max(limits, key=lambda m: limits[m])
        if limits[top] <= 3:
            raise RuntimeError("cannot fit MK core moves in 4 MB ASET")
        limits[top] -= 1

    # Grow any move that still has source frames until ASET is full.
    changed = True
    while changed:
        changed = False
        for move in sorted(limits, key=lambda m: limits[m]):
            if limits[move] >= 12:
                continue
            trial = dict(limits)
            trial[move] += 1
            if _fits(imgs, trial):
                limits = trial
                changed = True

    for extra in EXTRA_MOVES:
        if extra in limits:
            continue
        for cap in (8, 7, 6, 5, 4, 3):
            trial = dict(limits)
            trial[extra] = cap
            if _fits(imgs, trial):
                limits = trial
                # Grow this extra move while it fits.
                while limits[extra] < 10:
                    grow = dict(limits)
                    grow[extra] += 1
                    if _fits(imgs, grow):
                        limits = grow
                    else:
                        break
                break
    return limits


def _build_atlases(
    imgs: dict,
    move_limits: dict[str, int],
    _extra_moves: list[str] | None = None,
) -> tuple[list, dict[str, dict], dict[str, dict]]:
    from PIL import Image

    _extra_moves = _extra_moves or []

    arena_im = imgs["images/arenas/0/arena.png"].resize(
        ARENA_SIZE, Image.Resampling.LANCZOS
    )
    atlases = [arena_im]
    all_frames: dict[str, dict] = {}
    for fighter in ("subzero", "kano"):
        tagged = _fighter_frames(imgs, fighter, move_limits)
        atlas, fr = _pack_frames(tagged)
        atlases.append(atlas)
        all_frames[fighter] = fr
    nbytes, nspr = _estimate_payload(atlases)
    if nspr > 16:
        raise ValueError(f"{nspr} sprites > MAX_SPR 16")
    if nbytes > SRAM_BYTES:
        raise ValueError(
            f"ASET {nbytes} bytes > {SRAM_BYTES} (4 MB) asset SRAM bank"
        )
    return atlases, all_frames, move_limits


def _png_data_uri(im) -> str:
    buf = BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def _frames_js(frames: dict) -> str:
    return json.dumps(frames, separators=(",", ":"))


def _game_script(frames: dict, mk_img_block: str) -> str:
  """MKPVP V1 engine (PVP + round score); art/FRAMES from MK packer."""
  template = MKPVP_SRC.read_text(encoding="utf-8")
  m = re.search(r"<script>(.*)</script>", template, re.S)
  if not m:
    raise RuntimeError("MKPVP.HTML has no <script>")
  logic_lines = [ln for ln in m.group(1).split("\n") if len(ln) <= 500]
  logic = "\n".join(logic_lines)

  # Replace MK_IMG block.
  logic = re.sub(
      r"var MK_IMG = \{[\s\S]*?\};",
      "var MK_IMG = {\n" + mk_img_block + "\n};",
      logic,
      count=1,
  )
  # Replace FRAMES table.
  logic = re.sub(
      r"var FRAMES = \{[\s\S]*?\};",
      "var FRAMES = " + _frames_js(frames) + ";",
      logic,
      count=1,
  )
  logic = logic.replace("MK PVP", "MK BIG")
  logic = logic.replace('LOAD "MKPVP.HTML"', 'LOAD "MKBIG.HTML"')
  logic = logic.replace("Digitized fighters. F or O to start", "MK frames packed to 4MB. F or O to start")
  return logic


def build(out_path: Path = OUT, mk_path: Path = MK_SRC) -> Path:
    imgs = _load_mk_images(mk_path)
    if "images/arenas/0/arena.png" not in imgs:
        raise SystemExit(f"no arena in {mk_path}")

    final_limits = _pick_move_limits(imgs)
    atlases, frame_tables, _ = _build_atlases(imgs, final_limits, [])

    nbytes, nspr = _estimate_payload(atlases)
    mk_img_block = ",\n".join(
        [
            '  "arena": "' + _png_data_uri(atlases[0]) + '"',
            '  "subzero": "' + _png_data_uri(atlases[1]) + '"',
            '  "kano": "' + _png_data_uri(atlases[2]) + '"',
        ]
    )
    script = _game_script(frame_tables, mk_img_block)
    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>MK BIG — JMR</title></head>
<body style="margin:0;background:#000">
<!-- Generated by tools/mkbig.py from storage/MK.HTML — V1 RTL limits (16 SPR, 4 MB ASET). -->
<!-- Moves: {", ".join(sorted(final_limits.keys()))} -->
<!-- Frames/move caps: {json.dumps(final_limits, sort_keys=True)} -->
<!-- ASET ~{nbytes} bytes, {nspr} sprites -->
<canvas id="gameCanvas" width="640" height="480"></canvas>
<script>
{script}
</script>
</body>
</html>
"""
    out_path.write_text(html, encoding="utf-8")
    print(
        f"wrote {out_path}  ASET≈{nbytes} bytes ({nbytes / 1024 / 1024:.2f} MB)  "
        f"sprites={nspr}  moves={len(final_limits)}"
    )
    return out_path


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "-o",
        "--out",
        type=Path,
        default=OUT,
        help=f"output HTML (default: {OUT})",
    )
    ap.add_argument(
        "--mk",
        type=Path,
        default=MK_SRC,
        help=f"source MK.HTML (default: {MK_SRC})",
    )
    ap.add_argument(
        "--compile",
        action="store_true",
        help="run compile_js.py on the output",
    )
    args = ap.parse_args(argv)
    out = build(args.out, args.mk)
    if args.compile:
        from tools.compile_js import compile_html_one

        compile_html_one(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
