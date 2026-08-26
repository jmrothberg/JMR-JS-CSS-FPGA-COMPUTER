"""Wide sprite sheets (>1023 px) - the DONKEY missing-characters root
cause (2026-08-25). The sprite-geometry parse truncates width to 10
bits ({...}[9:0], jmr_js_vm.sv:8788), so a sheet wider than 1023
computes every source offset with a wrapped row stride: the WHOLE sheet
blits garbage, not just the far columns. DONKEY's character sheets are
936/1398/1470 wide; its platforms (small sheets) drew fine - exactly
the board and sim symptom. The FM loses them identically, so no parity
test could catch it; FIXED 2026-08-26 (full 16-bit parse); this gate keeps it fixed.
Constitution: "Great graphics stay at full quality... do not downscale
sheets to fit"; silent truncation also violates "loud overflow".
"""

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tests.test_rtl_snippets import _fb_pix, _fb_raw, _patch_js_spr, _sim


def test_rtl_wide_sheet_blits_exact():
    W, H = 1400, 20
    pix = bytearray(W * H)
    for y in range(H):
        for x in range(1200, 1208):
            pix[y * W + x] = 6
        for x in range(100, 108):
            pix[y * W + x] = 3
    src = """
var img = new Image(); img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 100, 0, 8, 8, 10, 10, 8, 8);
  c.drawImage(img, 1200, 0, 8, 8, 40, 10, 8, 8);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("WSPR.JS", src, [(W, H, bytes(pix))])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "WSPR.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 12, 12) == 3, "left-edge crop broken (stride wrap)"
        assert _fb_pix(raw, 42, 12) == 6, "far crop broken (width truncation)"
    finally:
        sim.shutdown()
