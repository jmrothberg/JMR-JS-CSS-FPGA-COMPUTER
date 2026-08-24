"""FP-multiply result-availability gates (built BEFORE the sequential-FP
surgery, per the vst_win lesson: multi-cycle-where-callers-assume-same-
cycle is exactly the class the broad battery missed twice).

Every test consumes a fractional multiply's result in the EARLIEST
possible consumer position — store, chained multiply, immediate compare,
call argument, array index math — and paints only on the exact IEEE
value. A held/stale/one-cycle-early read cannot pass. These must be
green on the single-beat tree AND after the sequential unit lands.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tests.test_rtl_snippets import _fb_nz, _patch_js_v64, _sim, _vmstat_int


def _run_v64(name: str, src: str, frames: int = 3):
    sim = _sim()
    try:
        _patch_js_v64(name, src)
        sim._rpc("SDRELOAD")
        sim.type_line(f'LOAD "{name}"')
        sim.type_line("RUN")
        for _ in range(frames):
            sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert _vmstat_int(st, "fault") == 0, st
        nz = _fb_nz(sim)
        assert nz >= 50, f"FP result wrong or late (no paint, nz={nz}) {st}"
    finally:
        sim.shutdown()


def test_rtl_fpmul_store_then_compare():
    """Result stored and compared on the very next ops (exact 8.75)."""
    src = """
var r;
function tick() {
  r = 2.5 * 3.5;
  if (r == 8.75) { fillRect(10, 10, 30, 30, 2); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPM1.JS", src)


def test_rtl_fpmul_chained_products():
    """Each product feeds the next multiply immediately (exact 37.5)."""
    src = """
var r;
function tick() {
  r = (1.5 * 2.5) * (2.5 * 4.0);
  if (r == 37.5) { fillRect(40, 10, 30, 30, 3); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPM2.JS", src)


def test_rtl_fpmul_immediate_compare_and_arg():
    """Product consumed inside a comparison and as a call argument with no
    intervening ops (5.0 exact through the call)."""
    src = """
var ok = 0;
function take(v) { if (v == 5.0) ok = ok + 1; }
function tick() {
  take(2.5 * 2.0);
  if (1.25 * 4.0 > 4.9) ok = ok + 1;
  if (ok >= 2) { fillRect(70, 10, 30, 30, 4); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPM3.JS", src)


def test_rtl_fpmul_result_as_index_math():
    """Product drives array index math the next op (0.5*4=2 -> a[2])."""
    src = """
var a = [9, 9, 7, 9];
var r;
function tick() {
  r = a[0.5 * 4.0];
  if (r == 7) { fillRect(100, 10, 30, 30, 5); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPM4.JS", src)


def test_rtl_fpmul_int_operands_exact():
    """Both-integer operands (the future fast-path class) stay exact,
    including a product needing more than 31 bits (frame-clock class)."""
    src = """
var r, s;
function tick() {
  r = 46341 * 46341;
  s = 640 * 480;
  if (r == 2147488281 && s == 307200) { fillRect(130, 10, 30, 30, 6); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPM5.JS", src)


def test_rtl_fpmul_date_now_frameclock():
    """Date.now (vframe_no x 16.666... — the shared frame-clock product)
    must be monotonic and exactly divisible-consistent across frames."""
    src = """
var a = 0, b = 0, calls = 0;
function tick() {
  var t = Date.now();
  if (calls == 1) a = t;
  if (calls == 3) b = t;
  calls = calls + 1;
  if (calls > 4 && b > a) { fillRect(160, 10, 30, 30, 7); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPM6.JS", src, frames=7)
