"""String operations library: the same answers on the Python model and FPGA-SIM.

String methods, parseInt / parseFloat / Number, Math.trunc / Math.sign and
Number.isInteger are JavaScript in functional_model/strops_runtime.js
(STROPS.JS on the card). Both compilers add it only when a program uses one of
them, and route `x.m(...)` to `_jmr_sop_m(x, ...)`, which does the string work
when x is a string and calls x.m(...) otherwise, so arrays keep the hardware's
own methods. Hex/binary literals and do-while are compiler-only.

Every case is a small program that ends; each answer is a number global read
back with VVARPEEK. Never add a program that loops forever: it hangs the
simulator.
"""
import math
import os
import re
import sys
import zlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.compiler import (  # noqa: E402
    SOP_CALLS, SOP_DOTTED, SOP_METHODS, CompileError, compile_source)
from functional_model.jsb_format import ProgramImage  # noqa: E402
from hardware_model import js_vm as value64  # noqa: E402
from hardware_model.js_vm import JsHwVm  # noqa: E402

NAN = float("nan")

# name -> (program, {global: expected}). String results are checked with
# `=== "literal" ? 1 : 0` so every answer is a number.
GROUPS = {
    "search": ("""
var s = "hello world";
var a1 = s.indexOf("wor"), a2 = s.indexOf("o", 5), a3 = s.indexOf("zz"), a4 = s.indexOf("", 99);
var a5 = s.includes("lo w") ? 1 : 0, a6 = s.includes("hello", 1) ? 1 : 0;
var a7 = s.lastIndexOf("o"), a8 = s.lastIndexOf("o", 5), a9 = s.lastIndexOf("q");
var b1 = s.startsWith("hell") ? 1 : 0, b2 = s.startsWith("world", 6) ? 1 : 0, b3 = s.startsWith("x") ? 1 : 0;
var b4 = s.endsWith("rld") ? 1 : 0, b5 = s.endsWith("hello", 5) ? 1 : 0, b6 = s.endsWith("o") ? 1 : 0;
var c1 = s.charAt(4) === "o" ? 1 : 0, c2 = s.charAt(99) === "" ? 1 : 0, c3 = s.charCodeAt(1), c4 = s.charCodeAt(50);
var c5 = "b".localeCompare("a"), c6 = "a".localeCompare("b"), c7 = "ab".localeCompare("ab"), c8 = "ab".localeCompare("abc");
var c9 = "a1b".indexOf(1);
""", dict(a1=6, a2=7, a3=-1, a4=11, a5=1, a6=0, a7=7, a8=4, a9=-1,
          b1=1, b2=1, b3=0, b4=1, b5=1, b6=0, c1=1, c2=1, c3=101, c4=NAN,
          c5=1, c6=-1, c7=0, c8=-1, c9=1)),
    "cut": ("""
var s = "hello world";
var d1 = s.slice(6) === "world" ? 1 : 0, d2 = s.slice(-5, -2) === "wor" ? 1 : 0, d3 = s.slice(3, 1) === "" ? 1 : 0;
var d4 = s.slice(0) === s ? 1 : 0, d5 = s.slice() === s ? 1 : 0;
var e1 = s.substring(4, 1) === "ell" ? 1 : 0, e2 = s.substring(6) === "world" ? 1 : 0, e3 = s.substring(-3, 2) === "he" ? 1 : 0;
var e4 = s.substr(-5, 3) === "wor" ? 1 : 0, e5 = s.substr(2) === "llo world" ? 1 : 0, e6 = s.substr(1, 0) === "" ? 1 : 0;
var f1 = "  hi \\n".trim() === "hi" ? 1 : 0, f2 = "abc".trim() === "abc" ? 1 : 0, f3 = "   ".trim() === "" ? 1 : 0;
var g1 = s.replace("o", "0") === "hell0 world" ? 1 : 0, g2 = s.replace("zz", "y") === s ? 1 : 0, g3 = "aXb".replace("X", "") === "ab" ? 1 : 0;
var g4 = "a-b".replace("-", 7) === "a7b" ? 1 : 0;
var h1 = s.toUpperCase() === "HELLO WORLD" ? 1 : 0, h2 = "AbC1".toLowerCase() === "abc1" ? 1 : 0, h3 = "ABC".toUpperCase() === "ABC" ? 1 : 0;
var h4 = s.slice(1, 4).length, h5 = strByte(s.slice(1, 4), 2);
""", dict(d1=1, d2=1, d3=1, d4=1, d5=1, e1=1, e2=1, e3=1, e4=1, e5=1, e6=1,
          f1=1, f2=1, f3=1, g1=1, g2=1, g3=1, g4=1, h1=1, h2=1, h3=1, h4=3, h5=108)),
    "split_join": ("""
var p = "a,b,,c".split(",");
var i1 = p.length, i2 = p[0] === "a" ? 1 : 0, i3 = p[2] === "" ? 1 : 0, i4 = p[3] === "c" ? 1 : 0;
var q = "abc".split(""); var i5 = q.length, i6 = q[2] === "c" ? 1 : 0;
var i7 = "a b c".split(" ", 2).length, i8 = "".split(",").length, i9 = "x".split().length;
var i10 = "one--two".split("--")[1] === "two" ? 1 : 0;
var j1 = ["x", "y", "z"].join("-") === "x-y-z" ? 1 : 0, j2 = ["x", "y"].join() === "x,y" ? 1 : 0;
var j3 = [1, "a", true, null, -7].join("-") === "1-a-true---7" ? 1 : 0, j4 = [].join("+") === "" ? 1 : 0;
var j5 = [1, 0, 0, 1].join("") === "1001" ? 1 : 0, j6 = [2.5, 10].join(" ") === "2.5 10" ? 1 : 0;
var j7 = [123456789, -40].join(":") === "123456789:-40" ? 1 : 0;
""", dict(i1=4, i2=1, i3=1, i4=1, i5=3, i6=1, i7=2, i8=1, i9=1, i10=1,
          j1=1, j2=1, j3=1, j4=1, j5=1, j6=1, j7=1)),
    "numbers": ("""
var k1 = parseInt("  -42px"), k2 = parseInt("0x1F"), k3 = parseInt("z", 36), k4 = parseInt("1F", 16), k5 = parseInt("101", 2);
var k6 = parseInt("abc"), k7 = parseInt(3.9), k8 = parseInt("12", 1), k9 = parseInt("077"), k10 = parseInt(-7.5);
var l1 = parseFloat("3.25e2x"), l2 = parseFloat(".5"), l3 = parseFloat("-0.125"), l4 = parseFloat("x1"), l5 = parseFloat("1e") ;
var l6 = parseFloat("0.1") === 0.1 ? 1 : 0, l7 = parseFloat("Infinityx"), l8 = parseFloat(" 2.5e-3 ") === 0.0025 ? 1 : 0;
var m1 = Number(" 12 "), m2 = Number("12px"), m3 = Number(""), m4 = Number("0x10"), m5 = Number("0b101"), m6 = Number(true);
var m7 = Number(null), m8 = Number(), m9 = Number("-1.5e1"), m10 = Number("."), m11 = Number(7), m12 = Number("123456789012");
var n1 = Math.trunc(-3.7), n2 = Math.trunc(3.7), n3 = Math.sign(-2), n4 = Math.sign(0), n5 = Math.sign(9), n6 = Math.trunc("8.9");
var n7 = Number.isInteger(5) ? 1 : 0, n8 = Number.isInteger(5.5) ? 1 : 0, n9 = Number.isInteger("5") ? 1 : 0;
""", dict(k1=-42, k2=31, k3=35, k4=31, k5=5, k6=NAN, k7=3, k8=NAN, k9=77, k10=-7,
          l1=325, l2=0.5, l3=-0.125, l4=NAN, l5=1, l6=1, l7=math.inf, l8=1,
          m1=12, m2=NAN, m3=0, m4=16, m5=5, m6=1, m7=0, m8=0, m9=-15, m10=NAN,
          m11=7, m12=123456789012, n1=-3, n2=3, n3=-1, n4=0, n5=1, n6=8,
          n7=1, n8=0, n9=0)),
    "arrays_and_syntax": ("""
var arr = [3, 4, 5];
var o1 = arr.indexOf(4), o2 = arr.slice(1).length, o3 = arr.includes(5) ? 1 : 0, o4 = arr.includes(9) ? 1 : 0;
var o6 = arr.slice(0, 2)[1];
var box = { trim: function () { return 77; } }; var o7 = box.trim();
var x1 = 0x1F, x2 = 0b101, x3 = 0o17, x4 = 0XfF;
var i = 0, n = 0; do { i++; if (i == 2) continue; n += i; } while (i < 5);
var k = 0; do k++; while (k < 3);
var z = 0; do { z++; break; } while (true);
var f1 = 3; // "f1" has the same keyword hash as "do"
""", dict(o1=1, o2=2, o3=1, o4=0, o6=4, o7=77, x1=31, x2=5, x3=15, x4=255,
          i=5, n=13, k=3, z=1, f1=3)),
}


def _image(js):
    return ProgramImage(bytes(ProgramImage.from_chunk(compile_source(js), v2=True, value64=True)))


def _value(raw):
    return value64.value_unpack_number(raw) if value64.value_is_number(raw) else ("raw", hex(raw))


def _check(group, got):
    want = GROUPS[group][1]
    bad = {}
    for name, value in want.items():
        g = got[name]
        same = (isinstance(g, float) and math.isnan(g)) if isinstance(value, float) and math.isnan(value) else g == value
        if not same:
            bad[name] = (g, value)
    assert not bad, f"{group}: got/want {bad}"


def _python(image):
    hm = JsHwVm()
    hm.load_image(image)
    assert hm.error is None, hm.error
    return hm


@pytest.mark.parametrize("group", sorted(GROUPS))
def test_python_model(group):
    image = _image(GROUPS[group][0])
    hm = _python(image)
    _check(group, {n: _value(hm._value_vars[image.var_names.index(n)]) for n in GROUPS[group][1]})


def test_fpga_sim_gives_the_same_answers(tmp_path):
    """One simulator for every group: JSHLOAD each program, peek its globals."""
    from runtime.sim_backend import SimBackend

    os.environ.pop("JMR_SIM_HOST", None)
    sim = SimBackend()
    try:
        for n, group in enumerate(sorted(GROUPS)):
            image = _image(GROUPS[group][0])
            jsh = tmp_path / f"t{n}.jsh"
            jsh.write_bytes(bytes(image))
            assert sim._rpc("JSHLOAD " + str(jsh)).startswith("OK")
            for _ in range(8):
                sim._rpc("FRAME")
            got = {}
            for name in GROUPS[group][1]:
                reply = sim._rpc("VVARPEEK " + str(image.var_names.index(name)))
                got[name] = _value(int(reply.rsplit("v=0x", 1)[1], 16))
            _check(group, got)
    finally:
        sim.shutdown()


@pytest.mark.parametrize("group", ["cut", "numbers", "arrays_and_syntax"])
def test_machine_compiler_gives_the_same_answers(group):
    """The on-machine compiler (COMPILER + COMPIL2 on the model) adds the same
    library and routes the same calls."""
    from tools.selfhost import self_compile

    image = ProgramImage(self_compile("SOPTEST", "<script>\n" + GROUPS[group][0] + "\n</script>\n"))
    hm = _python(image)
    _check(group, {n: _value(hm._value_vars[image.var_names.index(n)]) for n in GROUPS[group][1]})


# --- the mechanism ---------------------------------------------------------


def test_card_copy_and_machine_constants_match_the_library():
    lib = (ROOT / "functional_model/strops_runtime.js").read_bytes()
    assert (ROOT / "storage/STROPS.JS").read_bytes() == lib
    for stage in ("COMPILER.HTML", "COMPIL2.HTML"):
        text = (ROOT / "storage" / stage).read_text()
        assert f"var SOPLEN={len(lib)};var SOPCRC={zlib.crc32(lib)};" in text, stage
        names = re.search(r"var SOP_H=\[(.*?)\];", text).group(1)
        want = list(SOP_METHODS) + list(SOP_CALLS) + list(SOP_DOTTED.values())
        assert names == ",".join(f'"_jmr_sop_{n}"' for n in want), stage
    args = re.search(r"var SOP_A=\[(.*?)\];", (ROOT / "storage/COMPIL2.HTML").read_text()).group(1)
    assert args == ",".join(str(n) for n in SOP_METHODS.values())


def test_runtime_payload_lengths_identify_one_library_set():
    """The machine recovers which libraries are loaded from their total length."""
    lib = len((ROOT / "functional_model/strops_runtime.js").read_bytes())
    seen = {}
    for b in range(16):
        if b & 6 == 4:
            continue
        n = (20308 if b & 2 else 18459) if b & 1 else (10927 if b & 2 else 0)
        n += 13018 if b & 4 else 0
        n += lib if b & 8 else 0
        assert n not in seen, (b, seen[n])
        seen[n] = b


def test_library_only_when_used():
    plain = compile_source("var a = [1, 2]; var b = a.length + 1;")
    used = compile_source("var s = 'ab'; var i = s.indexOf('b');")
    assert "_jmr_sop_indexOf" not in plain.functions
    assert "_jmr_sop_indexOf" in used.functions
    # No join, no String(): the number formatter is not linked.
    assert "_jmr_json_stringCoerceNative" not in used.functions
    assert "_jmr_json_stringCoerceNative" in compile_source("var j = [1.5].join(',');").functions


def test_reserved_library_names_and_remaining_walls():
    with pytest.raises(CompileError):
        compile_source("var _jmr_sop_x = 1;")
    with pytest.raises(CompileError):
        compile_source("var s = 'ab'; var t = s.repeat(2);")
