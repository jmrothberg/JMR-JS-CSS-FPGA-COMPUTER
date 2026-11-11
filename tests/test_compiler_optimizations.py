"""Compiler output shortening keeps JavaScript semantics.

Statement-level assignments and ++/-- drop their unused value, && / || tests
in if / while / for / ?: compile to direct jumps, and functions with more
than 16 locals keep the overflow in a nested environment. Each test runs the
compiled program on the hardware model and checks the values JavaScript
defines, including short-circuit order and side effects.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.bytecode import Op  # noqa: E402
from functional_model.compiler import Compiler, compile_source  # noqa: E402
from functional_model.jsb_format import ProgramImage  # noqa: E402
from hardware_model import js_vm as value64  # noqa: E402
from hardware_model.js_vm import JsHwVm  # noqa: E402


def _run(js: str) -> JsHwVm:
    hm = JsHwVm()
    hm.load_image(ProgramImage.from_chunk(compile_source(js), v2=True, value64=True))
    assert hm.error is None, hm.error
    return hm


def _num(hm: JsHwVm, name: str) -> float:
    raw = hm._value_vars[hm.program_image.var_names.index(name)]
    return value64.value_unpack_number(raw)


def _ops(js: str) -> list:
    c = Compiler(js)
    return [op[0] for op in c.compile().code]


# --- unused statement values ---------------------------------------------


def test_assignment_statement_has_no_reload():
    ops = _ops("var x = 0; x = 5; x += 2;")
    assert Op.POP not in ops
    assert ops.count(Op.LOAD_VAR) == 1  # only the += read


def test_increment_statement_has_no_dup():
    ops = _ops("var i = 0; i++; ++i; i--; --i;")
    assert Op.DUP not in ops and Op.POP not in ops


def test_statement_values_keep_their_semantics():
    hm = _run(
        "var a = 1, b = 2, c = 0, i = 0, s = 0;"
        "a = b = 7;"            # inner value still used
        "c = (a++, a++, a);"     # comma keeps the last value
        "for (i = 0; i < 5; i++) { s += i; }"
        "var p = i++; var q = ++i;"
        "var n = 0; n++; n++; --n;"
        "var t = 0; if (t = 3) { t = t + 10; }"
    )
    assert _num(hm, "a") == 9 and _num(hm, "b") == 7 and _num(hm, "c") == 9
    assert _num(hm, "s") == 10
    assert _num(hm, "p") == 5 and _num(hm, "q") == 7 and _num(hm, "i") == 7
    assert _num(hm, "n") == 1
    assert _num(hm, "t") == 13


def test_assignment_inside_short_circuit_stays_conditional():
    hm = _run("var x = 0, y = 0; var f = 0;"
              "f && (x = 1); 1 && (y = 2);"
              "var k = 0; k || (k = 4);")
    assert _num(hm, "x") == 0 and _num(hm, "y") == 2 and _num(hm, "k") == 4


# --- && / || as jumps ------------------------------------------------------


def test_condition_chain_emits_no_dup():
    ops = _ops("var a = 1, b = 2, c = 0, r = 0;"
               "if (a < b && b > c || c === 3) { r = 1; }"
               "while (a < 3 && b) { a = a + 1; }")
    assert Op.DUP not in ops


CASES = [
    ("a && b", lambda a, b, c: a and b),
    ("a || b", lambda a, b, c: a or b),
    ("a && b && c", lambda a, b, c: a and b and c),
    ("a || b || c", lambda a, b, c: a or b or c),
    ("a && b || c", lambda a, b, c: (a and b) or c),
    ("a || b && c", lambda a, b, c: a or (b and c)),
    ("(a || b) && c", lambda a, b, c: (a or b) and c),
    ("a && (b || c)", lambda a, b, c: a and (b or c)),
    ("!a && b || !c", lambda a, b, c: (not a and b) or not c),
    ("((a && b)) || (c && a)", lambda a, b, c: (a and b) or (c and a)),
]


@pytest.mark.parametrize("expr,want", CASES)
def test_condition_truth_tables(expr, want):
    rows = [(a, b, c) for a in (0, 1) for b in (0, 1) for c in (0, 1)]
    js = ["var out = [];"
          "function row(a, b, c) {"
          f"if ({expr}) out.push(1); else out.push(0);"
          f"out.push(({expr}) ? 1 : 0);"
          f"var w = 0; while (w < 1 && ({expr})) w = w + 1; out.push(w);"
          f"var f = 0; for (; f < 1 && ({expr}); f++) {{}} out.push(f);"
          "}"]
    for a, b, c in rows:
        js.append(f"row({a}, {b}, {c});")
    js.append("var n = out.length; var bits = 0; var k = 0;"
              "while (k < n) { bits = bits * 2 + out[k]; k++; }")
    hm = _run("".join(js))
    expect = 0
    for a, b, c in rows:
        v = 1 if want(a, b, c) else 0
        for _ in range(4):
            expect = expect * 2 + v
    assert _num(hm, "n") == 32
    assert _num(hm, "bits") == expect


def test_condition_short_circuit_order_and_side_effects():
    hm = _run(
        "var log = 0;"
        "function t(d, v) { log = log * 10 + d; return v; }"
        "if (t(1, 0) && t(2, 1)) { log = log * 10 + 9; }"
        "if (t(3, 1) || t(4, 1)) { log = log * 10 + 8; }"
        "if (t(5, 0) || t(6, 0) && t(7, 1)) { log = log * 10 + 7; }"
    )
    assert _num(hm, "log") == 13856  # 1 (2 skipped), 3 (4 skipped), 8, 5, 6 (7 skipped)


def test_value_of_and_or_is_unchanged():
    hm = _run("var a = 0 || 5; var b = 3 && 4; var c = 0 && 9; var d = 2 || 9;"
              "var e = (0 || 0) ? 1 : 2; var f = (6 && 7) + 1;")
    assert [_num(hm, k) for k in "abcdef"] == [5, 4, 0, 2, 2, 8]


def test_chain_followed_by_unterminated_statement():
    """A newline-ended statement must not swallow the next one's ?: ."""
    hm = _run("var a = 1, b = 1, c = 0, r = 0, s = 0\n"
              "r = a && b\n"
              "s = c ? 5 : 6\n")
    assert _num(hm, "r") == 1 and _num(hm, "s") == 6


# --- locals beyond the 16 environment slots ---------------------------------


def _many_locals(n: int) -> str:
    names = [f"v{k}" for k in range(n)]
    decl = "".join(f"var {nm} = {k + 1};" for k, nm in enumerate(names))
    total = "+".join(names)
    return names, decl, total


def test_function_with_24_locals():
    names, decl, total = _many_locals(24)
    hm = _run(f"function f(p, q) {{ {decl} v20 = v20 + p; v3 = q * 2;"
              f"return {total}; }} var r = f(100, 50);")
    want = sum(range(1, 25)) + 100 - 4 + 100
    assert _num(hm, "r") == want


def test_overflow_locals_are_captured_by_closures():
    names, decl, total = _many_locals(20)
    hm = _run(
        f"function mk() {{ {decl}"
        "  var inc = function () { v19 = v19 + 1; v0 = v0 + 1; return v19 * 100 + v0; };"
        "  return inc; }"
        "var g = mk(); g(); var r = g();"
    )
    assert _num(hm, "r") == (20 + 2) * 100 + (1 + 2)


def test_overflow_locals_in_methods_keep_this():
    names, decl, total = _many_locals(18)
    hm = _run(
        "class K { constructor() { this.base = 1000; }"
        f"  sum(a) {{ {decl} for (var i = 0; i < 3; i++) {{ v17 = v17 + a; }}"
        f"    return this.base + {total}; }} }}"
        "var r = new K().sum(2);"
    )
    assert _num(hm, "r") == 1000 + sum(range(1, 19)) + 6


def test_overflow_locals_with_recursion_and_nested_functions():
    names, decl, total = _many_locals(20)
    hm = _run(
        f"function fact(n) {{ {decl}"
        "  function helper(k) { return k + v19 - 20; }"
        "  if (n <= 1) { return helper(1); }"
        "  return n * fact(n - 1); }"
        "var r = fact(6);"
    )
    assert _num(hm, "r") == 720


def test_many_params_and_locals_use_several_levels():
    params = [f"p{k}" for k in range(10)]
    names, decl, total = _many_locals(40)
    js = (f"function f({','.join(params)}) {{ {decl}"
          "  var g = function () { return v39 + p9; };"
          f"  v0 = v0 + p0; return {total} + {'+'.join(params)} + g(); }}"
          f"var r = f({','.join(str(k + 100) for k in range(10))});")
    calls = [op for op in compile_source(js).code if op[0] == Op.CALL_VAL]
    assert len(calls) >= 3  # two wrapper levels plus the closure call
    hm = _run(js)
    assert _num(hm, "r") == sum(range(1, 41)) + 100 + sum(range(100, 110)) + 40 + 109
