"""Deep operand-stack cases pinned to the vst_win window (depths 9-16).

Scaffolding for any future vst_win shrink (16 -> 8): VST_REL clamps
out-of-window reads to slot 0 SILENTLY, so a bad window change corrupts
values without faulting. These tests build operand stacks 9-16 deep and
paint only when every value survives; they must stay green before AND
after any window work. See OVERNIGHT_STATUS.md (2026-08-23) for why the
shrink was rejected without this file.
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
        assert nz >= 50, f"deep-stack result wrong (no paint, nz={nz}) {st}"
    finally:
        sim.shutdown()


def test_rtl_v64_deep_nested_add_depth14():
    """Right-nested adds push one operand per level: window depth 14."""
    src = """
var r;
function tick() {
  r = (1+(2+(3+(4+(5+(6+(7+(8+(9+(10+(11+(12+(13+14)))))))))))));
  if (r == 105) { fillRect(10, 10, 30, 30, 2); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("DEEP14.JS", src)


def test_rtl_v64_call_12_args_reads_every_slot():
    """A 12-arg call stacks callee handle + args; every slot must read back."""
    src = """
function f(a,b,c,d,e,g,h,i,j,k,l,m) {
  return a + b*2 + c*3 + d*4 + e*5 + g*6 + h*7 + i*8 + j*9 + k*10 + l*11 + m*12;
}
var r;
function tick() {
  r = f(1,2,3,4,5,6,7,8,9,10,11,12);
  if (r == 650) { fillRect(40, 10, 30, 30, 3); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("DEEPARG.JS", src)


def test_rtl_v64_call_inside_deep_expression():
    """A call fires while 4 outer operands are pending in the window."""
    src = """
function g(a,b,c,d,e,h,i,j) { return a+b+c+d+e+h+i+j; }
var r;
function tick() {
  r = 1 + (2 + (3 + (4 + g(5,6,7,8,9,10,11,12))));
  if (r == 78) { fillRect(70, 10, 30, 30, 4); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("DEEPMIX.JS", src)


def test_rtl_v64_array_literal_15_then_reduce():
    """A 15-element literal pushes 15 window slots before MAKE_ARRAY."""
    src = """
var a;
var r;
var i;
function tick() {
  a = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];
  r = 0;
  for (i = 0; i < 15; i++) r = r + a[i];
  if (r == 120 && a.length == 15) { fillRect(100, 10, 30, 30, 5); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("DEEPARR.JS", src)
