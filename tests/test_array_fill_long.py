"""Array(n) with n > 32 must not write into another array (RTL simulator).

An Array(n) longer than 32 elements is born in the long-array table. Its
fill used to write its first element before the VM had read that the array
was long, so the write landed at the short address aid*32 — element 32 of
another long array. MacPaint's About box showed "pict?re". The fill now
waits one settle beat before each write (rtl/engines/jmr_js_vm.sv,
S_HEAP_FILL).
"""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.compiler import compile_source  # noqa: E402
from functional_model.jsb_format import ProgramImage  # noqa: E402
from hardware_model.js_vm import value_unpack_number  # noqa: E402

SRC = """var L=[],j=0,k;
while(j<5){var a=[];k=0;while(k<40){a.push(7);k=k+1;}L.push(a);j=j+1;}
var before=L[1][32];
var XS=Array(120);
var after=L[1][32], after33=L[1][33], xs0=XS[0], xlen=XS.length;"""
UNDEFINED = 0x7FF9100000000000


def test_array_n_over_32_leaves_other_long_arrays_alone(tmp_path):
    from runtime.sim_backend import SimBackend
    image = ProgramImage(bytes(ProgramImage.from_chunk(compile_source(SRC), v2=True, value64=True)))
    jsh = tmp_path / "t.jsh"
    jsh.write_bytes(bytes(image))
    os.environ.pop("JMR_SIM_HOST", None)
    sim = SimBackend()
    try:
        assert sim._rpc("JSHLOAD " + str(jsh)).startswith("OK")
        for _ in range(4):
            sim._rpc("FRAME")

        def raw(name):
            reply = sim._rpc("VVARPEEK " + str(image.var_names.index(name)))
            return int(reply.rsplit("v=0x", 1)[1], 16)

        assert value_unpack_number(raw("before")) == 7
        assert value_unpack_number(raw("after")) == 7
        assert value_unpack_number(raw("after33")) == 7
        assert raw("xs0") == UNDEFINED
        assert value_unpack_number(raw("xlen")) == 120
    finally:
        sim.shutdown()
