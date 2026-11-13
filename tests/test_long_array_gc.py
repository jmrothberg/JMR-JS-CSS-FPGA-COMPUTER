"""Growing an array past 32 elements collects garbage before fault 3.

Arrays of 33-128 elements live in a pool of 16 long rows. A new long array
already collected garbage when the pool was full; an array that grew into the
pool (push or a[i]= past element 31) did not, so unreachable long arrays
filled it and the program stopped with fault 3 (Compile, build 97). The RTL
promote (rtl/engines/jmr_js_vm.sv, S_ARR_PROMOTE) and the Python model
(hardware_model/js_vm.py, _value64_ensure_long) now collect once first.
"""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.compiler import compile_source  # noqa: E402
from functional_model.jsb_format import ProgramImage  # noqa: E402
from hardware_model.js_vm import JsHwVm, value_unpack_number  # noqa: E402

# 40 rounds each grow a fresh array to 40 elements with push and drop it, so
# at most one is live; the 17th used to fault 3. Then 40 more rounds grow
# arrays with a[i]= (ARRAY_SET) the same way.
SRC = """var r=0,keep=0,keep2=0,j,a,b;
while(r<40){a=[];j=0;while(j<40){a.push(r);j=j+1;}keep=keep+a[39];r=r+1;}
r=0;while(r<40){b=[];j=0;while(j<40){b[j]=r;j=j+1;}keep2=keep2+b[39];r=r+1;}
var blen=b.length;"""


def _image():
    return ProgramImage(bytes(ProgramImage.from_chunk(compile_source(SRC), v2=True, value64=True)))


def test_model_collects_before_long_array_overflow():
    image = _image()
    vm = JsHwVm()
    vm.load_image(image)
    assert vm.error is None, vm.error

    def num(name):
        return value_unpack_number(vm._value_vars[image.var_names.index(name)])

    assert num("keep") == sum(range(40))
    assert num("keep2") == sum(range(40))
    assert num("blen") == 40


def test_rtl_collects_before_long_array_overflow(tmp_path):
    from runtime.sim_backend import SimBackend
    image = _image()
    jsh = tmp_path / "t.jsh"
    jsh.write_bytes(bytes(image))
    os.environ.pop("JMR_SIM_HOST", None)
    sim = SimBackend()
    try:
        assert sim._rpc("JSHLOAD " + str(jsh)).startswith("OK")
        for _ in range(10):
            sim._rpc("FRAME")

        def num(name):
            reply = sim._rpc("VVARPEEK " + str(image.var_names.index(name)))
            return value_unpack_number(int(reply.rsplit("v=0x", 1)[1], 16))

        assert num("keep") == sum(range(40))
        assert num("keep2") == sum(range(40))
        assert num("blen") == 40
    finally:
        sim.shutdown()
