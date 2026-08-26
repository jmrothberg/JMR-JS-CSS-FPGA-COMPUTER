"""Class-method lookup gates (DONKEY root cause, 2026-08-26).

The parent method-table scan issued the pre-increment index after the
prime beat, re-reading one entry and lagging every later comparison by
one - the LAST method of any class with >=3 methods could never
resolve (silent undefined: DONKEY's Mario/DK/Barrel .update are all
declared last -> ramps and ladders with no player, no kong, no
barrels). Fixed by issuing one ahead; these gates pin every boundary.

Defect B (separate, still open): a CONSTRUCTORLESS class misses even
with 2 methods - strict xfail below until the class-stamp fix lands.
"""

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tests.test_rtl_snippets import _fb_pix, _fb_raw, _patch_js, _sim


def _run(src):
    sim = _sim()
    try:
        _patch_js("CLSM.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "CLSM.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        return _fb_pix(_fb_raw(sim), 12, 12)
    finally:
        sim.shutdown()


def _cls_src(n_before, with_ctor=True):
    stubs = " ".join(f"m{i}() {{ return {i}; }}" for i in range(1, n_before + 1))
    ctor = "constructor() { this.z = 1; }" if with_ctor else ""
    return f"""
class T {{
  {ctor}
  {stubs}
  last() {{ fillRect(10, 10, 20, 20, 5); }}
}}
var t = new T();
function tick() {{ t.last(); swapBuffers(); requestAnimationFrame(tick); }}
requestAnimationFrame(tick);
"""


def test_rtl_last_method_of_3():
    assert _run(_cls_src(2)) == 5, "last of 3 methods did not run"


def test_rtl_last_method_of_10():
    assert _run(_cls_src(9)) == 5, "last of 10 methods did not run"


def test_rtl_last_method_of_16_full_table():
    assert _run(_cls_src(15)) == 5, "last of 16 (MAX_CMETH) did not run"


def test_rtl_middle_method_still_found():
    src = """
class T {
  constructor() { this.z = 1; }
  m1() { return 1; }
  mid() { fillRect(10, 10, 20, 20, 5); }
  m3() { return 3; }
  m4() { return 4; }
}
var t = new T();
function tick() { t.mid(); swapBuffers(); requestAnimationFrame(tick); }
requestAnimationFrame(tick);
"""
    assert _run(src) == 5


@pytest.mark.xfail(reason="Defect B: constructorless class never consults the method lookup", strict=True)
def test_rtl_ctorless_class_method():
    assert _run(_cls_src(1, with_ctor=False)) == 5
