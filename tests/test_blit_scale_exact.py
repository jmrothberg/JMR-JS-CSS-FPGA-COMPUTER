"""Scaled-blit exactness gates (built BEFORE the divide-hoist surgery on
the jmr_js_vm.sv:1620 per-pixel combinational divides, per the vst_win
lesson). The staged fix replaces floor((x*sw)/rw) per-pixel divides with
a per-blit div_uq setup (q = sw/rw, r = sw%rw) plus an exact DDA
(sx += q; acc += r; if acc >= rw then sx += 1, acc -= rw). These gates
pin the CURRENT floor semantics per-pixel at awkward non-integer ratios
in both directions, plus a 9-arg source-rect blit (nonzero blit_sx/sy),
so an off-by-one in the DDA carry or a stale spr_so register cannot pass.
Must be green before AND after the surgery.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tests.test_rtl_snippets import _fb_pix, _fb_raw, _patch_js_spr, _sim, _vmstat_int


def _pattern(w: int, h: int) -> bytes:
    # nonzero palette values only (0 is transparent in the blit path)
    return bytes(((x + y * 3) % 6) + 1 for y in range(h) for x in range(w))


def _run_blit(name: str, src: str, sprites: list):
    sim = _sim()
    try:
        _patch_js_spr(name, src, sprites)
        sim._rpc("SDRELOAD")
        sim.type_line(f'LOAD "{name}"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert _vmstat_int(st, "fault") == 0, st
        return _fb_raw(sim)
    finally:
        sim.shutdown()


def _check_rect(raw, pix, sw_full, dx, dy, dw, dh, sx0, sy0, sw, sh):
    """Every dest pixel must be src[floor(y*sh/dh)+sy0][floor(x*sw/dw)+sx0]."""
    bad = []
    for y in range(dh):
        for x in range(dw):
            sx = sx0 + (x * sw) // dw
            sy = sy0 + (y * sh) // dh
            want = pix[sy * sw_full + sx]
            got = _fb_pix(raw, dx + x, dy + y)
            if got != want:
                bad.append((dx + x, dy + y, got, want))
    assert not bad, f"{len(bad)} wrong pixels, first 8: {bad[:8]}"


def test_rtl_blit_upscale_7x5_to_10x9():
    """Non-integer upscale: uneven DDA steps in both axes."""
    pix = _pattern(7, 5)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 3, 2, 10, 9);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    raw = _run_blit("BSU1.JS", src, [(7, 5, pix)])
    _check_rect(raw, pix, 7, 3, 2, 10, 9, 0, 0, 7, 5)


def test_rtl_blit_downscale_12x6_to_5x4():
    """Downscale: the DDA whole-step quotient q >= 1 (q=2 rows/cols skipped)."""
    pix = _pattern(12, 6)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 20, 20, 5, 4);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    raw = _run_blit("BSD1.JS", src, [(12, 6, pix)])
    _check_rect(raw, pix, 12, 20, 20, 5, 4, 0, 0, 12, 6)


def test_rtl_blit_awkward_16x16_to_23x11():
    """Mixed: upscale X (16->23), downscale Y (16->11), both fractional."""
    pix = _pattern(16, 16)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 40, 5, 23, 11);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    raw = _run_blit("BSA1.JS", src, [(16, 16, pix)])
    _check_rect(raw, pix, 16, 40, 5, 23, 11, 0, 0, 16, 16)


def test_rtl_blit_9arg_source_rect_scaled():
    """9-arg drawImage: nonzero blit_sx/sy source window (5,3 8x6) scaled
    to 11x8 — the source-offset add must survive the hoist."""
    pix = _pattern(16, 12)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 5, 3, 8, 6, 60, 30, 11, 8);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    raw = _run_blit("BS9A.JS", src, [(16, 12, pix)])
    _check_rect(raw, pix, 16, 60, 30, 11, 8, 5, 3, 8, 6)
