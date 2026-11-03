"""FP-add normalization gates (built BEFORE the v64_norm_shift log-depth
rewrite). These target the paths that lean hardest on the normalize
shift: catastrophic cancellation (nearly-equal subtraction), exact
cancellation to signed zero, subnormal results, and rounding boundaries.
Exact-value paint gates — a wrong shift count or exponent clamp cannot
pass silently. Must be green before AND after the rewrite.
"""

import sys
import math
import pytest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tests.test_rtl_snippets import _fb_nz, _patch_js_v64, _sim, _vmstat_int


@pytest.mark.parametrize('left,right', [
    (1.0, 2.0**-53), (1.0, math.nextafter(2.0**-53, math.inf)),
    (1.0, -math.nextafter(1.0, 0.0)),
    (math.nextafter(1.0, math.inf), -1.0),
    (2.0**-1022, -(2.0**-1022 - 5e-324)),
    (5e-324, 5e-324), (5e-324, -5e-324),
    (2.0**-1022, -5e-324), (2.0**-1022, 5e-324),
    (1.7976931348623157e308, 1.7976931348623157e308),
    (1.7976931348623157e308, -1.7976931348623157e308),
    (-0.0, -0.0), (-0.0, 0.0),
    (9007199254740992.0, 1.0), (9007199254740992.0, 3.0),
    (-123456.75, 0.125), (0.1, 0.2),
])
def test_registered_add_sub_exact_number_checkpoints(left, right):
    from tests.test_rtl_snippets import (
        test_program_image_value64_number_checkpoint_matches_python_hm,
    )
    # Stored operands prevent compile-time folding. Both results feed
    # immediate arithmetic consumers before their raw IEEE checkpoints.
    test_program_image_value64_number_checkpoint_matches_python_hm(
        f'var a={left!r};var b={right!r};var sum=a+b;var diff=a-b;'
        'var again=sum-b;var reverse=diff+b;'
    )


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
        assert nz >= 50, f"FP add/norm result wrong (no paint, nz={nz}) {st}"
    finally:
        sim.shutdown()


def test_rtl_fpadd_catastrophic_cancellation():
    """Nearly-equal subtraction: the difference needs a DEEP normalize
    (1.0000001 - 1.0 exercises a ~23-bit left shift; (1+2^-50)-1 = 2^-50
    exercises a 50-bit shift — the full norm_shift range)."""
    src = """
var big = 1.0;
var tiny = 1.0 / 1125899906842624.0;  // 2^-50
var r = (big + tiny) - big;
var ok = 0;
function tick() {
  if (r == tiny) ok = 1;
  if (ok == 1) { fillRect(10, 10, 30, 30, 2); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPN1.JS", src)


def test_rtl_fpadd_exact_cancellation_signed_zero():
    """a + (-a) must be exactly +0, and 1/result must be +Infinity (not
    -Infinity) — the signed-zero contract through the cancel path."""
    src = """
var a = 3.75;
var z = a + (-a);
var ok = 0;
function tick() {
  if (z == 0 && (1 / z) > 0) ok = 1;
  if (ok == 1) { fillRect(40, 10, 30, 30, 3); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPN2.JS", src)


def test_rtl_fpadd_rounding_boundary():
    """Guard/sticky rounding at the 53-bit boundary: 1 + 2^-53 rounds to
    1.0 exactly (ties-to-even), while 1 + 2^-52 is representable."""
    src = """
var ulp = 1.0 / 4503599627370496.0;   // 2^-52
var half = ulp / 2.0;                  // 2^-53
var r1 = 1.0 + half;
var r2 = 1.0 + ulp;
var ok = 0;
function tick() {
  if (r1 == 1.0 && r2 > 1.0 && (r2 - 1.0) == ulp) ok = 1;
  if (ok == 1) { fillRect(70, 10, 30, 30, 4); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPN3.JS", src)


def test_rtl_fpadd_chain_running_sum():
    """A physics-style running sum with mixed magnitudes (the ASTEROID
    class): exactness over 20 accumulations of 0.1 vs the known binary64
    total (2.0000000000000004, NOT 2.0)."""
    src = """
var s = 0.0;
var i;
for (i = 0; i < 20; i++) s = s + 0.1;
var ok = 0;
function tick() {
  if (s != 2.0 && s > 2.0 && s < 2.0000000000000010) ok = 1;
  if (ok == 1) { fillRect(100, 10, 30, 30, 5); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    _run_v64("FPN4.JS", src)


@pytest.mark.parametrize('seed', [730, 731, 732, 733])
def test_registered_add_sub_mixed_exponents(seed):
    import random
    import struct
    from tests.test_rtl_snippets import (
        test_program_image_value64_number_checkpoint_matches_python_hm,
    )
    rng = random.Random(seed)
    source = []
    for index in range(4):
        values = []
        for _ in range(2):
            bits = rng.getrandbits(64)
            # Finite binary64 inputs spanning signs, exponents and mantissas.
            if (bits >> 52) & 0x7ff == 0x7ff:
                bits ^= 1 << 52
            values.append(struct.unpack('>d', bits.to_bytes(8, 'big'))[0])
        a, b = values
        source.append(
            f'var a{index}={a!r};var b{index}={b!r};'
            f'var s{index}=a{index}+b{index};var d{index}=a{index}-b{index};'
        )
    test_program_image_value64_number_checkpoint_matches_python_hm(''.join(source))
