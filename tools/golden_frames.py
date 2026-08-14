#!/usr/bin/env python3
"""Chrome vs PYTHON vs FPGA-SIM golden frames — bug-flusher, not a proof rung.

  python3 tools/golden_frames.py

Chrome is authoring/visual reference only. PYTHON bytecode then FPGA-SIM RTL
are the Constitution rungs. Output lands in traces/goldens/ as PNGs plus a
region-diff summary (downsample + color-class match). Not a hard CI gate.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

OUT = ROOT / "traces" / "goldens"
TITLES = ("INVADERS", "PACMAN", "DONKEY")
W, H = 640, 480
# 16×16 tiles → 40×30 cells. Stars / Date.now flicker are masked by class match.
TILE = 16
# Color-class bins (R,G,B each 0/1/2) — bunkers green vs black still differ.
CLASS_SHIFT = 7  # 256/2 → 2 bits? use 85: 0..84 / 85..169 / 170..255
# PACMAN stage-0 maze (map x:16 y:8 size:14, 28×31). HUD SCORE/LEVEL at x=420.
MAZE_X0, MAZE_X1 = 16, 408
MAZE_Y0, MAZE_Y1 = 8, 442
MAZE_TILE = 14
MAZE_COLS, MAZE_ROWS = 28, 31


def _rgb_class(r: int, g: int, b: int) -> int:
    return (r // 85) + 3 * (g // 85) + 9 * (b // 85)


def _idx_to_rgb(fb: bytes, pal) -> bytes:
    out = bytearray(W * H * 3)
    for i, pix in enumerate(fb):
        r, g, b = pal[pix]
        out[i * 3 : i * 3 + 3] = bytes((r, g, b))
    return bytes(out)


def _save_png(path: Path, rgb: bytes) -> None:
    from PIL import Image

    Image.frombytes("RGB", (W, H), rgb).save(path)


def _chrome_shot(html: Path, dest: Path) -> bool:
    chrome = shutil.which("google-chrome") or shutil.which("google-chrome-stable")
    if not chrome:
        print("SKIP chrome (binary missing)")
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        chrome,
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        f"--window-size={W},{H}",
        "--virtual-time-budget=2000",
        f"--screenshot={dest}",
        html.resolve().as_uri(),
    ]
    r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)
    if r.returncode != 0 or not dest.is_file():
        print("SKIP chrome", html.name, (r.stderr or r.stdout)[-200:])
        return False
    # Chrome may write a larger window; crop/resize to 640×480.
    from PIL import Image

    im = Image.open(dest).convert("RGB")
    if im.size != (W, H):
        im = im.resize((W, H))
        im.save(dest)
    print("OK chrome", html.name, dest.name)
    return True


def _python_shot(stem: str, dest: Path) -> bool:
    from functional_model import Machine
    from runtime.backend import PythonBackend

    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    py.type_line(f'LOAD "{stem}.HTML"')
    py.type_line("RUN")
    if not m.running or not getattr(m, "_bytecode_html", False):
        print("FAIL PYTHON", stem, "not running", m.vm.error)
        return False
    for _ in range(16):
        py.frame_tick()
        if m.vm.error:
            print("FAIL PYTHON", stem, "VM", m.vm.error)
            return False
    # NEW: PACMAN title is Enter-to-start; goldens must be stage 0 / level 1.
    if stem == "PACMAN":
        m.input.key_event(13, "Enter", True)
        m.input.key_event(13, "Enter", False)
        for _ in range(24):
            py.frame_tick()
            if m.vm.error:
                print("FAIL PYTHON", stem, "VM", m.vm.error)
                return False
    else:
        for _ in range(8):
            py.frame_tick()
            if m.vm.error:
                print("FAIL PYTHON", stem, "VM", m.vm.error)
                return False
    rgb = _idx_to_rgb(bytes(m.canvas.front), m.canvas.palette)
    dest.parent.mkdir(parents=True, exist_ok=True)
    _save_png(dest, rgb)
    print("OK PYTHON", stem, dest.name, "nz", sum(1 for b in m.canvas.front if b))
    return True


def _rtl_shot(stem: str, dest: Path) -> bool:
    os.environ.pop("JMR_SIM_HOST", None)
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        print("SKIP RTL", stem, "(no FPGA-SIM binary)")
        return False
    try:
        for _ in range(200):
            sim._rpc("TICK")
        sim.type_line(f'LOAD "{stem}.HTML"')
        sim.type_line("RUN")
        if "running=1" not in sim._rpc("STATUS?"):
            print("FAIL RTL", stem, "not running", sim._rpc("STATUS?"))
            return False
        # NEW: FRAME = one VM swap (TICK=1000 starved PACMAN/DONKEY goldens)
        for _ in range(16):
            sim._rpc("FRAME")
        if stem == "PACMAN":
            sim._rpc("KEYEVT 13 1")
            sim._rpc("KEYEVT 13 0")
            for _ in range(24):
                sim._rpc("FRAME")
        else:
            for _ in range(8):
                sim._rpc("FRAME")
        sim._rpc("FB?")
        fb = bytes(sim.framebuffer().front)
        pal = sim.framebuffer().palette
        rgb = _idx_to_rgb(fb, pal)
        dest.parent.mkdir(parents=True, exist_ok=True)
        _save_png(dest, rgb)
        print("OK RTL", stem, dest.name, "nz", sum(1 for b in fb if b))
        return True
    finally:
        sim.shutdown()


def _side_by_side(a: Path, b: Path, dest: Path) -> None:
    from PIL import Image

    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    ia = ia.resize((W, H))
    ib = ib.resize((W, H))
    out = Image.new("RGB", (W * 2 + 8, H), (32, 32, 32))
    out.paste(ia, (0, 0))
    out.paste(ib, (W + 8, 0))
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)


def _tile_diff(ref: Path, other: Path, mask_stars: bool) -> list[str]:
    from PIL import Image

    ir = Image.open(ref).convert("RGB").resize((W, H))
    io = Image.open(other).convert("RGB").resize((W, H))
    pr, po = ir.load(), io.load()
    hits: list[str] = []
    cols, rows = W // TILE, H // TILE
    for ty in range(rows):
        for tx in range(cols):
            miss = 0
            n = TILE * TILE
            for dy in range(TILE):
                for dx in range(TILE):
                    x, y = tx * TILE + dx, ty * TILE + dy
                    cr = _rgb_class(*pr[x, y])
                    co = _rgb_class(*po[x, y])
                    if cr != co:
                        miss += 1
            # stars: sparse 1-pixel noise — ignore tiles with < 8% mismatch
            frac = miss / n
            if mask_stars and frac < 0.08:
                continue
            if frac >= 0.08:
                hits.append(f"  tile {tx},{ty} mismatch {frac:.0%}")
    return hits


def _occupancy_rgb(src: Path) -> bytes:
    """Binary wall-vs-empty RGB; HUD (x>=410) masked off. Fonts excluded."""
    from PIL import Image

    im = Image.open(src).convert("RGB").resize((W, H))
    px = im.load()
    out = bytearray(W * H * 3)
    for y in range(H):
        for x in range(W):
            i = (y * W + x) * 3
            if x >= 410 or not (MAZE_X0 <= x < MAZE_X1 and MAZE_Y0 <= y < MAZE_Y1):
                continue
            r, g, b = px[x, y]
            if r or g or b:
                out[i : i + 3] = b"\xff\xff\xff"
    return bytes(out)


def _cell_grid(rgb: bytes) -> list[list[int]]:
    """28×31 maze-cell occupancy (any ink in the 14×14 tile)."""
    grid: list[list[int]] = []
    for ty in range(MAZE_ROWS):
        row: list[int] = []
        for tx in range(MAZE_COLS):
            ink = 0
            for dy in range(MAZE_TILE):
                for dx in range(MAZE_TILE):
                    x = MAZE_X0 + tx * MAZE_TILE + dx
                    y = MAZE_Y0 + ty * MAZE_TILE + dy
                    i = (y * W + x) * 3
                    if rgb[i] or rgb[i + 1] or rgb[i + 2]:
                        ink += 1
                        if ink >= 3:
                            break
                if ink >= 3:
                    break
            row.append(1 if ink >= 3 else 0)
        grid.append(row)
    return grid


def _grid_mismatch(a: list[list[int]], b: list[list[int]]) -> list[str]:
    hits: list[str] = []
    for ty in range(min(len(a), len(b))):
        for tx in range(min(len(a[ty]), len(b[ty]))):
            if a[ty][tx] != b[ty][tx]:
                hits.append(f"  cell {tx},{ty} {a[ty][tx]} vs {b[ty][tx]}")
    return hits


def _center_bits(rgb: bytes) -> list[int]:
    """Per-cell center ink — spokes paint the center; quarter-arcs do not."""
    bits: list[int] = []
    for ty in range(MAZE_ROWS):
        for tx in range(MAZE_COLS):
            x = MAZE_X0 + tx * MAZE_TILE + MAZE_TILE // 2
            y = MAZE_Y0 + ty * MAZE_TILE + MAZE_TILE // 2
            i = (y * W + x) * 3
            bits.append(1 if (rgb[i] or rgb[i + 1] or rgb[i + 2]) else 0)
    return bits


def _write_occupancy(src: Path, dest: Path) -> bytes:
    rgb = _occupancy_rgb(src)
    _save_png(dest, rgb)
    return rgb


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    report: list[str] = []
    rc = 0
    for stem in TITLES:
        html = ROOT / "storage" / f"{stem}.HTML"
        ch = OUT / f"{stem}_chrome.png"
        py = OUT / f"{stem}_python.png"
        rtl = OUT / f"{stem}_rtl.png"
        got_ch = _chrome_shot(html, ch) if html.is_file() else False
        got_py = _python_shot(stem, py)
        got_rtl = _rtl_shot(stem, rtl)
        if got_ch and got_py:
            _side_by_side(ch, py, OUT / f"{stem}_chrome_vs_python.png")
            hits = _tile_diff(ch, py, mask_stars=True)
            line = f"{stem} chrome vs PYTHON: {len(hits)} tiles"
            print(line)
            report.append(line)
            report.extend(hits[:24])
        if got_py and got_rtl:
            _side_by_side(py, rtl, OUT / f"{stem}_python_vs_rtl.png")
            hits = _tile_diff(py, rtl, mask_stars=True)
            line = f"{stem} PYTHON vs RTL: {len(hits)} tiles"
            print(line)
            report.append(line)
            report.extend(hits[:24])
        if stem == "PACMAN" and got_py:
            # NEW: stage-0 binary occupancy (HUD masked). Corridors, not RGB.
            py_occ = _write_occupancy(py, OUT / "PACMAN_python_occ.png")
            py_grid = _cell_grid(py_occ)
            if got_rtl:
                rtl_occ = _write_occupancy(rtl, OUT / "PACMAN_rtl_occ.png")
                rtl_grid = _cell_grid(rtl_occ)
                _side_by_side(
                    OUT / "PACMAN_python_occ.png",
                    OUT / "PACMAN_rtl_occ.png",
                    OUT / "PACMAN_occ_python_vs_rtl.png",
                )
                miss = _grid_mismatch(py_grid, rtl_grid)
                ctr = sum(
                    1
                    for a, b in zip(_center_bits(py_occ), _center_bits(rtl_occ))
                    if a != b
                )
                line = (
                    f"PACMAN occupancy PYTHON vs RTL: {len(miss)} cells, "
                    f"{ctr} center-bits"
                )
                print(line)
                report.append(line)
                report.extend(miss[:24])
                if ctr > 8:
                    rc = 1
            if got_ch:
                ch_occ = _write_occupancy(ch, OUT / "PACMAN_chrome_occ.png")
                ch_grid = _cell_grid(ch_occ)
                occupied = sum(sum(r) for r in ch_grid)
                if occupied < 40:
                    line = "PACMAN occupancy Chrome: skip (title / no Enter)"
                    print(line)
                    report.append(line)
                else:
                    miss = _grid_mismatch(ch_grid, py_grid)
                    line = f"PACMAN occupancy Chrome vs PYTHON: {len(miss)} cells"
                    print(line)
                    report.append(line)
                    report.extend(miss[:24])
        if not got_py:
            rc = 1
    summary = OUT / "summary.txt"
    summary.write_text("\n".join(report) + "\n", encoding="utf-8")
    print("wrote", summary)
    return rc


if __name__ == "__main__":
    sys.exit(main())
