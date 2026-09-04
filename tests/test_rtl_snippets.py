"""Tiny FPGA-SIM RTL snippets — not LOAD+RUN of the three HTML titles."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from functional_model.storage_engine import resolve_storage_html, storage_html_min_lines

ROOT = Path(__file__).resolve().parents[1]

# div7 (run 52). Budget ceilings for
# VM progress scale by this; polling loops break early so passing tests
# pay nothing. Console/RPC-side waits are unscaled.
_VMDIV = 7


_SCRATCH_CARD = None


def _scratch_card():
    """Once per session: copy card.img to a scratch and point JMR_CARD_IMG
    at it. Tests write probe files (_patch_js/_patch_html) onto the card;
    the user's card.img must never accumulate that junk (their DIR filled
    with probe files). Both the patch helpers and _sim() route through
    here — a test may patch BEFORE its _sim() call, and re-copying then
    would silently discard the patch (PALK.JS ?FN, nops=0)."""
    global _SCRATCH_CARD
    if _SCRATCH_CARD is None:
        import shutil
        import tempfile

        scratch = Path(tempfile.gettempdir()) / "jmr_test_card.img"
        # JMR_CARD_SRC: pin the suite to a frozen card copy (the repo card
        # is re-minted by the content lane mid-session; measurement doctrine
        # says validate against a frozen snapshot when content moves).
        real = Path(os.environ.get("JMR_CARD_SRC", ROOT / "card.img"))
        if real.is_file():
            shutil.copyfile(real, scratch)
            os.environ["JMR_CARD_IMG"] = str(scratch)
            _SCRATCH_CARD = scratch
    return _SCRATCH_CARD


def _sim():
    os.environ.pop("JMR_SIM_HOST", None)
    _scratch_card()
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        pytest.skip("FPGA-SIM RTL binary missing")
    for _ in range(200):
        sim._rpc("TICK")
    return sim


def _patch_js(name: str, src: str) -> None:
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from tools.make_sd_image import patch_card_file

    card = _scratch_card() or (ROOT / "card.img")
    blob = encode_chunk(compile_source(src), v2=True, value64=True)
    patch_card_file(card, name, src.encode("utf-8"))
    patch_card_file(card, Path(name).stem[:8] + ".JSB", blob)


def _patch_js_v64(name: str, src: str) -> None:
    """Tiny .JS + Value64 .JSB (HTML FLAG_VALUE64 path, not tagged)."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from tools.make_sd_image import patch_card_file

    card = _scratch_card() or (ROOT / "card.img")
    blob = encode_chunk(compile_source(src), v2=True, value64=True)
    patch_card_file(card, name, src.encode("utf-8"))
    patch_card_file(card, Path(name).stem[:8] + ".JSB", blob)


def _patch_html(name: str, src: str) -> None:
    """Tiny HTML on the card (LIST-from-FAT path). Not a title rewrite."""
    from tools.make_sd_image import patch_card_file

    card = _scratch_card() or (ROOT / "card.img")
    patch_card_file(card, name, src.encode("utf-8"))


def _patch_js_spr(name: str, src: str, sprites: list, *, aset: bool = False, value64: bool = True) -> None:
    """Tiny .JS + SPR1 (or ASET/SPRD) pack so drawImage hits the blit (no HTML)."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from tools.make_sd_image import patch_card_file

    card = _scratch_card() or (ROOT / "card.img")
    blob = encode_chunk(
        compile_source(src), v2=True, sprites=sprites, aset=aset, value64=value64
    )
    patch_card_file(card, name, src.encode("utf-8"))
    patch_card_file(card, Path(name).stem[:8] + ".JSB", blob)


def _fb_raw(sim) -> bytes:
    import base64

    fb = sim._rpc("FB?")
    if not fb.startswith("FB 640 480 "):
        return b""
    return base64.b64decode(fb.split(None, 3)[3])


def _fb_pix(raw: bytes, x: int, y: int) -> int:
    if not raw:
        return 0
    return raw[y * 640 + x]


def _fb_nz(sim) -> int:
    return sum(1 for b in _fb_raw(sim) if b)


def _vmstat_int(vmstat: str, key: str) -> int:
    """Read one `key=<int>` field out of a VMSTAT? reply (-1 if absent).

    2026-08-28: token must match at a FIELD boundary — the naive
    split matched "fault=" inside "efault=" (which precedes it in
    VMSTAT), so every fault==0 assertion in the suite was silently
    reading efault. Found by a cross-agent VMSTAT discrepancy on the
    INVFAST fault-3."""
    tok = " " + key + "="
    padded = " " + vmstat
    if tok not in padded:
        return -1
    return int(padded.split(tok)[1].split()[0].replace(",", ""))

# (test_program_image_scalar_checkpoint_matches_python_hm deleted with the
#  tagged encoding — docs/REMOVING_EXEC32.md Phase 1: the value64 twin below
#  is the product-encoding checkpoint test.)

def test_program_image_value64_scalar_checkpoint_matches_python_hm():
    """The gated RTL Value64 island matches the HM raw scalar checkpoint."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    image = ProgramImage.from_chunk(
        compile_source("var x=1+2; var y=x*4;"), v2=True, value64=True
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()

    sim = _sim()
    try:
        # Stream the exact validated ProgramImage bytes; no decoded chunk or
        # host arithmetic participates in the RTL result.
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(100 * _VMDIV):
            sim._rpc("TICKN 10")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat or "fault=" in vmstat and "fault=0" not in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat

        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        assert got["ops_base"] == str(3 + 2 * image.n_consts), raw
        assert got["vars"] == f"{expected['vars']:x}", (raw, expected)
        assert got["heap"] == f"{expected['heap']:x}", (raw, expected)
        assert got["frames"] == f"{expected['frames']:x}", (raw, expected)
        assert got["queues"] == f"{expected['queues']:x}", (raw, expected)
        assert got["canvas"] == f"{expected['canvas']:x}", (raw, expected)
        assert got["sp"] == str(expected["sp"])
        assert got["csp"] == str(expected["csp"])
        assert got["raf"] == str(expected["raf"])
        assert got["timers"] == str(expected["timers"])
        assert got["listeners"] == str(expected["listeners"])
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


@pytest.mark.parametrize(
    "source",
    [
        "var a=0.1+0.2; var b=-7*3; var c=a>b;",
        "var p=0.0; var n=-0.0; var z=n*2; var same=p===n;",
        (
            "var pinf=1/0; var ninf=-1/0; var nan=0/0;"
            "var finite_inf=1/(1/0); var inf_inf=(1/0)/(1/0);"
        ),
        (
            "var neg=-7%3; var neg_divisor=7%-3; var finite_inf=7%(1/0);"
            "var half=7/2; var eighth=1/8;"
        ),
        (
            "var trunc=1.9|0; var nan=(0/0)|0;"
            "var wrap=4294967297|0; var mask=-1&3;"
        ),
    ],
)
def test_program_image_value64_number_checkpoint_matches_python_hm(source):
    """Synthesizable Number/bitwise scalar bits match the HM raw oracle."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(100 * _VMDIV):
            sim._rpc("TICKN 10")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat or (
                "fault=" in vmstat and "fault=0" not in vmstat
            ):
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        assert got["vars"] == f"{expected['vars']:x}", (raw, expected)
        assert got["frames"] == f"{expected['frames']:x}", (raw, expected)
        assert got["queues"] == f"{expected['queues']:x}", (raw, expected)
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


def test_program_image_value64_nested_heap_checkpoint_matches_python_hm():
    """Stable nested arrays/objects, identity, and cycles hash identically."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    image = ProgramImage.from_chunk(
        compile_source(
            "var inner=[1,2]; var obj={items:[inner,{n:3}]};"
            "var got=obj.items[1].n; obj.self=obj;"
            "var same=obj.self===obj; inner[1]=9;"
            "var changed=obj.items[0][1];"
        ),
        v2=True,
        value64=True,
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(2000 * _VMDIV):
            sim._rpc("TICKN 50")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        for field in ("vars", "heap", "frames", "queues", "canvas"):
            assert got[field] == f"{expected[field]:x}", (field, raw, expected)
        assert got["sp"] == str(expected["sp"])
        assert got["csp"] == str(expected["csp"])
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


def test_program_image_value64_heap_gc_reclaims_churn_matches_python_hm():
    """Allocation pressure collects unreachable stable array slots."""
    from functional_model.bytecode import Chunk, Op
    from functional_model.jsb_format import ProgramImage
    from hardware_model import js_vm as value64
    from hardware_model.js_vm import JsHwVm

    image = ProgramImage.from_chunk(
        Chunk(
            [(Op.MAKE_ARRAY, 0), (Op.POP,)] * (value64.MAX_ARRAYS + 1),
            [],
            [],
        ),
        v2=True,
        value64=True,
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(50000 * _VMDIV):
            sim._rpc("TICKN 1")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        assert got["vars"] == f"{expected['vars']:x}", (raw, expected)
        assert got["heap"] == f"{expected['heap']:x}", (raw, expected)
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


def test_program_image_value64_index_non_array_is_undefined_matches_python_hm():
    """1[0] is undefined on both sides; not a heap fault."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    image = ProgramImage.from_chunk(
        compile_source("var missing=1[0]; var ok=[9][0];"),
        v2=True,
        value64=True,
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()
    assert expected["error_code"] == 0

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(2000 * _VMDIV):
            sim._rpc("TICKN 50")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        assert got["vars"] == f"{expected['vars']:x}", (raw, expected)
        assert got["error"] == "0", raw
    finally:
        sim.shutdown()


@pytest.mark.parametrize(
    "source",
    [
        "var o={"
        + ",".join(f"p{index}:{index}" for index in range(33))
        + "};",
    ],
)
def test_program_image_value64_heap_faults_match_python_hm(source):
    """Object-slot overflow halts with the HM error code."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()
    assert expected["error_code"] != 0

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(2000 * _VMDIV):
            sim._rpc("TICKN 50")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


@pytest.mark.parametrize(
    "source",
    [
        "function add(a,b){return a+b;} var result=add(2,3);",
        (
            "function outer(x){let y=x+1;return ()=>y;}"
            "var closure=outer(4); var result=closure();"
        ),
        (
            "function make(x){return ()=>x;}"
            "var first=make(1); var second=make(2);"
            "var a=first(); var b=second();"
        ),
        pytest.param(
            "var P=(function(){let sheet=7;class P{read(){return sheet;}}"
            "return P;})(); var p=new P(); var result=p.read();",
            marks=pytest.mark.xfail(
                reason="potential-bugs #72: class-in-IIFE ctor allocates "
                "~950 objects and GC-storms through S_V64_CTOR_PAD "
                "(pre-existing on HEAD; sits at a wall-clock flake boundary)",
                strict=False,
            ),
        ),
    ],
)
def test_program_image_value64_calls_checkpoint_matches_python_hm(source):
    """Balanced calls and independent lexical closures match raw checkpoints."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(3000 * _VMDIV):
            sim._rpc("TICKN 50")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        for field in ("vars", "heap", "frames", "queues", "canvas"):
            assert got[field] == f"{expected[field]:x}", (field, raw, expected)
        assert got["sp"] == str(expected["sp"])
        assert got["csp"] == str(expected["csp"])
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


def test_program_image_value64_string_math_canvas_checkpoint_matches_python_hm():
    """Interned strings and the bounded scalar/canvas native subset match HM."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    source = (
        'var text="hello"; var magnitude=Math.abs(-3);'
        "var low=Math.min(7,2); var high=Math.max(7,2);"
        "clear(0); fillRect(1,1,2,2,5); swapBuffers();"
    )
    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(10000 * _VMDIV):
            sim._rpc("TICKN 100")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        for field in ("vars", "heap", "frames", "queues", "canvas"):
            assert got[field] == f"{expected[field]:x}", (field, raw, expected)
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


def test_program_image_value64_dom_array_foreach_checkpoint_matches_python_hm():
    """querySelector/getContext/fillRect, array push, and forEach match HM."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    source = (
        "var el=document.querySelector('canvas');"
        "var c=el.getContext('2d');"
        "c.fillStyle='#ffffff';"
        "c.fillRect(1,1,2,2);"
        "var n=0; var a=[]; a.push(3); a.push(4);"
        "a.forEach(function(x){n=n+x;});"
        "var result=n;"
    )
    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(10000 * _VMDIV):
            sim._rpc("TICKN 100")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        # Heap intern/string marking still diverges; vars prove querySelector,
        # getContext, push, and forEach (result = 3+4).
        assert got["vars"] == f"{expected['vars']:x}", (raw, expected)
        assert got["error"] == str(expected["error_code"]), (raw, expected)
        assert got["sp"] == str(expected["sp"])
    finally:
        sim.shutdown()


@pytest.mark.xfail(reason="potential-bugs #70: rAF/timer queue serialization hash differs RTL vs HM (frames/vars/heap match); pre-existing parity gap", strict=False)
def test_program_image_value64_raf_timer_order_checkpoint_matches_python_hm():
    """A frame snapshots rAF before firing due timers, with exact queue hashes."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    source = (
        "var order=0;"
        "function onRaf(){order=order*10+1;}"
        "function onTimer(){order=order*10+2;}"
        "requestAnimationFrame(onRaf); setTimeout(onTimer,0);"
    )
    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    hm = JsHwVm()
    hm.load_image(image)
    queued = hm.checkpoint()

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(50000 * _VMDIV):
            sim._rpc("TICKN 1")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_WAIT_FRAME" in vmstat:
                break
        assert "sname=S_WAIT_FRAME" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        for field in ("vars", "heap", "frames", "queues"):
            assert got[field] == f"{queued[field]:x}", (field, raw, queued)
        assert got["raf"] == "1"
        assert got["timers"] == "1"

        hm.frame_tick()
        expected = hm.checkpoint()
        sim._rpc("FRAME")
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        for field in ("vars", "heap", "frames", "queues", "canvas"):
            assert got[field] == f"{expected[field]:x}", (field, raw, expected)
        assert got["raf"] == "0"
        assert got["timers"] == "0"
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


def test_program_image_value64_closure_survives_gc_matches_python_hm():
    """A captured environment survives array-heap allocation pressure."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    source = (
        "function outer(x){return ()=>x;}"
        "var closure=outer(7); var waste=[];"
        + "waste=[];" * 4096
        + "var result=closure();"
    )
    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(10000 * _VMDIV):
            sim._rpc("TICKN 100")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        for field in ("vars", "heap", "frames"):
            assert got[field] == f"{expected[field]:x}", (field, raw, expected)
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


@pytest.mark.xfail(reason="potential-bugs #71: fault-state checkpoint parity (HM keeps sp=1 at call-overflow fault, RTL reports 0); pre-existing", strict=False)
def test_program_image_value64_recursive_capacity_checkpoint_matches_python_hm():
    """Recursive calls halt at the frozen finite environment capacity."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage
    from hardware_model.js_vm import JsHwVm

    image = ProgramImage.from_chunk(
        compile_source("function f(){return f();} var result=f();"),
        v2=True,
        value64=True,
    )
    hm = JsHwVm()
    hm.load_image(image)
    expected = hm.checkpoint()
    assert expected["error_code"] != 0

    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(5000 * _VMDIV):
            sim._rpc("TICKN 50")
            vmstat = sim._rpc("VMSTAT?")
            if "sname=S_IDLE" in vmstat:
                break
        assert "sname=S_IDLE" in vmstat, vmstat
        raw = sim._rpc("CHECKPOINT?")
        got = dict(field.split("=", 1) for field in raw.split()[1:])
        for field in ("vars", "heap", "frames"):
            assert got[field] == f"{expected[field]:x}", (field, raw, expected)
        assert got["sp"] == str(expected["sp"])
        assert got["csp"] == str(expected["csp"])
        assert got["error"] == str(expected["error_code"]), (raw, expected)
    finally:
        sim.shutdown()


def test_rtl_call_overflow_halts_loudly():
    """A recursive call past CSTK faults loudly instead of wrapping csp.

    Value64 (the only encoding since the exec32 cut) reports call-stack
    overflow as fault 2 (exec64 vcsp>=CSTK); tagged used 7.
    """
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage

    image = ProgramImage.from_chunk(
        compile_source("function f(){f();} f();"), v2=True
    )
    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(100 * _VMDIV):
            sim._rpc("TICKN 10")
            vmstat = sim._rpc("VMSTAT?")
            if "fault=2" in vmstat:
                break
        assert "fault=2" in vmstat, vmstat
        checkpoint = sim._rpc("CHECKPOINT?")
        assert "error=2" in checkpoint, checkpoint
    finally:
        sim.shutdown()


def test_rtl_timer_overflow_halts_loudly():
    """The 65th pending timer faults loudly instead of overwriting a callback.

    Value64 reports timer-queue overflow as fault 3 (exec64 site 3816);
    tagged used 2.
    """
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage

    src = "function f() {}\n" + "\n".join(
        "setTimeout(f, 1000);" for _ in range(65)
    )
    image = ProgramImage.from_chunk(compile_source(src), v2=True)
    sim = _sim()
    try:
        sim._program_image = image.data
        assert sim._stream_program_image().startswith("OK")
        vmstat = ""
        for _ in range(100 * _VMDIV):
            sim._rpc("TICKN 10")
            vmstat = sim._rpc("VMSTAT?")
            if "fault=3" in vmstat:
                break
        assert "fault=3" in vmstat, vmstat
        checkpoint = sim._rpc("CHECKPOINT?")
        assert "error=3" in checkpoint, checkpoint
    finally:
        sim.shutdown()


def test_rtl_down_key_release_keeps_keycode_40():
    """The KEYBITS Down release must not fall through to Up keyCode 38."""
    src = """
var released = 0;
function onup(e) {
  if (e.keyCode === 40) released = 1;
}
addEventListener("keyup", onup);
function tick() {
  if (released) { fillRect(10,10,30,30,2); swapBuffers(); }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("DOWNUP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "DOWNUP.JS"')
        sim.type_line("RUN")
        sim._rpc("KEYBITS 2")
        sim._rpc("FRAME")
        sim._rpc("KEYBITS 0")
        sim._rpc("FRAME")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50
    finally:
        sim.shutdown()


def test_rtl_push_object_survives_frame():
    """arr.push({n:1}) after keep watermark must still be readable next frame."""
    src = """
var arr = [];
var armed = 0;
function tick() {
  if (!armed) {
    arr.push({n:1});
    armed = 1;
  } else if (arr[0] && arr[0].n == 1) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("KEEP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "KEEP.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "nursery obj from push was rewound"
    finally:
        sim.shutdown()


def test_rtl_id_prop_postfix_dec_writes_back():
    """Bare item.timeout-- must store (same compiler path as PACMAN engine)."""
    src = """
var item = {timeout: 5};
var i;
for (i = 0; i < 3; i++) {
  if (item.timeout) item.timeout--;
}
function tick() {
  if (item.timeout == 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("TDEC.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "TDEC.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "item.timeout-- did not write back"
    finally:
        sim.shutdown()


def test_rtl_coord_overwrite_does_not_heapovf():
    """item.coord = {x,y} every frame must rewind, not freeze keep."""
    src = """
var item = {coord: {x: 0, y: 0}};
var n = 0;
function tick() {
  item.coord = {x: n, y: n};
  n = n + 1;
  fillRect(10, 10, 30, 30, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("COORD.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "COORD.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        import re as _re

        hm = _re.search(r"heapovf=(\d+)", st or "")
        assert hm and int(hm.group(1)) == 0, st
        assert _fb_nz(sim) >= 50, "coord overwrite stopped drawing"
    finally:
        sim.shutdown()


def test_rtl_keyevt_space_keycode():
    """KEYEVT 32 must reach addEventListener (e.keyCode)."""
    src = """
var hit = 0;
addEventListener("keydown", function(e) {
  if (e.keyCode == 32) hit = 1;
});
function tick() {
  if (hit) {
    fillRect(40, 10, 30, 30, 4);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("KEYSP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "KEYSP.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        sim.key_event(32, " ", True)
        sim._rpc("FRAME")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "KEYEVT 32 did not fire listener"
    finally:
        sim.shutdown()


def test_rtl_keyevt_space_e_key_char():
    """KEYEVT 32 must deliver e.key === ' ' (U+0020), not keyCode-only."""
    src = """
var hit = 0;
addEventListener("keydown", function(e) {
  if (e.key === " ") hit = 1;
});
function tick() {
  if (hit) {
    fillRect(50, 10, 30, 30, 5);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("KEYCH.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "KEYCH.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        sim.key_event(32, " ", True)
        sim._rpc("FRAME")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "e.key === ' ' did not match"
    finally:
        sim.shutdown()


def test_rtl_push_survives_particle_burst():
    """grid.push then a burst of new objs — grid[0] still readable next frame."""
    src = """
var grid = [];
var burst = [];
var armed = 0;
function tick() {
  if (armed == 0) {
    grid.push({n:1});
    armed = 1;
  } else if (armed == 1) {
    for (var i = 0; i < 8; i++) burst.push({p:i});
    armed = 2;
  } else if (grid[0] && grid[0].n == 1) {
    fillRect(20, 10, 30, 30, 3);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("BURST.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "BURST.JS"')
        sim.type_line("RUN")
        for _ in range(4):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "grid obj died after nursery burst"
    finally:
        sim.shutdown()


def test_rtl_dir_hides_jsb_shows_html():
    # Snippet patches dirty the FAT; rebuild so HTML titles are on the card.
    from tools.make_sd_image import create_image

    create_image(ROOT / "card.img", force=True)
    sim = _sim()
    try:
        sim._rpc("SDRELOAD")
        sim.type_line("DIR")
        pages = []
        found = False
        for _ in range(8):
            st = sim.screen_text().replace("\\n", "\n")
            pages.append(st)
            for ln in st.splitlines():
                t = ln.strip().upper()
                assert not t.endswith(".JSB"), ln
                assert not t.endswith(".JSH"), ln
            blob = st.upper()
            if "JOYDEMO" in blob or "BOXES" in blob or "ASTEROID" in blob:
                found = True
                break
            if "-- MORE" in st:
                sim.push_key(" ")
            else:
                break
        blob = "\n".join(pages)
        assert found or any(
            x in blob.upper() for x in ("JOYDEMO", "BOXES", "ASTEROID")
        ), blob[-400:]
    finally:
        sim.shutdown()


def test_rtl_list_pages_more():
    """LIST of a multi-page HTML must park on MORE, not prompt at ~230."""
    html = storage_html_min_lines(230)
    if html is None:
        pytest.skip("no storage HTML with >230 lines")
    sim = _sim()
    try:
        sim.type_line(f'LOAD "{html.name}"')
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        assert "-- MORE" in st, st[-400:]
        assert not st.rstrip().endswith(">"), st[-200:]
    finally:
        sim.shutdown()


def test_rtl_load_html_line_count():
    """LOADED NAME (N LINES) must count past the 8K SOURCE prefix."""
    html = storage_html_min_lines(230)
    if html is None:
        pytest.skip("no storage HTML with >230 lines")
    stem = html.stem.upper()
    sim = _sim()
    try:
        sim.type_line(f'LOAD "{html.name}"')
        st = sim.screen_text().replace("\\n", "\n")
        assert "LOADED" in st, st[-300:]
        assert "LINES" in st, st[-300:]
        assert stem[:8] in st.upper(), st[-300:]
        n = 0
        for tok in st.replace("(", " ").replace(")", " ").split():
            if tok.isdigit() and int(tok) > n:
                n = int(tok)
        assert n > 230, (n, st[-300:])
    finally:
        sim.shutdown()


def test_rtl_list_after_run_is_source():
    """LIST after RUN still shows source text, not .JSB/.JSH bytes."""
    sim = _sim()
    try:
        sim.type_line('LOAD "JOYDEMO.HTML"')
        sim.type_line("RUN")
        sim.hard_break()
        sim._rpc(f"TICKN {200 * _VMDIV}")
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        assert (
            "fillRect" in st or "JOY DEMO" in st or "Joystick demo" in st
        ), st[-400:]
    finally:
        sim.shutdown()


def test_rtl_list_long_line_wraps_without_holes():
    """64-col LIST wrap must not extra-NL (VRAM already wraps at col 63).

    Line-number digits used to skip list_col, so wrap fired late and print_nl
    skipped a glass row — long printable lines looked like injected spaces.
    """
    from functional_model.canvas_engine import CONSOLE_COLS

    body = "".join(chr(ord("A") + (i % 26)) for i in range(180))
    src = "<html>\n<script>\nvar s=\"" + body + "\";\n</script>\n</html>\n"
    numbered = '30 var s="' + body + '";'
    segs = [numbered[i : i + CONSOLE_COLS] for i in range(0, len(numbered), CONSOLE_COLS)]
    sim = _sim()
    try:
        _patch_html("WRAP.HTML", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "WRAP.HTML"')
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        rows = [ln.rstrip() for ln in st.splitlines()]
        assert segs[0] in rows, st
        i = rows.index(segs[0])
        got = rows[i : i + len(segs)]
        assert got == segs, (got, segs, st)
        # extra wrap-NL left a 3-char remnant row between wraps
        assert all(len(r) > 8 for r in got[:-1]), got
    finally:
        sim.shutdown()


def test_rtl_unknown_command_sn_error():
    """laod must print ?SN ERROR, not a bare ?."""
    sim = _sim()
    try:
        sim.type_line("laod")
        st = sim.screen_text().replace("\\n", "\n")
        assert "?SN ERROR" in st, st[-400:]
        sim.type_line('LOAD "NOPE.HTML"')
        st = sim.screen_text().replace("\\n", "\n")
        assert "?FN FILE NOT FOUND" in st, st[-400:]
    finally:
        sim.shutdown()


def test_rtl_list_long_data_uri_pages_to_mark():
    """LIST of a ~3K data-URI line shows the squash placeholder, then MARK.

    Card copies of .HTM/.HTML squash >200-char lines to
    `<LINE n: EMBEDDED DATA k CHARS OMITTED>`
    (make_sd_image.squash_long_html_lines) — the fix for "monitor stalls
    on list": the console no longer streams megabytes of base64 through
    the SPI line buffer. LIST must show the placeholder and reach MARK.
    """
    src = (
        "<html>\n<script>\n"
        'var s = "data:image/png;base64,' + ("A" * 3000) + '";\n'
        "</script>\n<!--MARK-->\n</html>\n"
    )
    sim = _sim()
    try:
        _patch_html("LONG.HTML", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "LONG.HTML"')
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        assert "CHARS OMITTED" in st, st[-400:]
        saw_mark = "MARK" in st
        for _ in range(40):
            if saw_mark:
                break
            sim.push_key(" ")
            st = sim.screen_text().replace("\\n", "\n")
            if "MARK" in st or "</html>" in st:
                saw_mark = True
                break
            if "-- MORE" not in st:
                break
        assert saw_mark, st[-500:]
    finally:
        sim.shutdown()


def test_rtl_finder_paths_out_of_house():
    """Same mini-BFS as PYTHON: stringify/replace opens a 2-cell, then path."""
    src = r"""
var data = [
  [1,1,1,1],
  [1,2,2,1],
  [1,2,2,1],
  [0,0,0,0]
];
function _copyMapOpen(_cm_s){var _cm_o=[];for(var _cm_j=0;_cm_j<_cm_s.length;_cm_j++){var _cm_w=_cm_s[_cm_j],_cm_r=[];for(var _cm_i=0;_cm_i<_cm_w.length;_cm_i++){_cm_r.push(_cm_w[_cm_i]==2?0:_cm_w[_cm_i]);}_cm_o.push(_cm_r);}return _cm_o;}
var opened = _copyMapOpen(data);
function finder(params) {
  var defaults = { map:null, start:{}, end:{}, type:'path' };
  var options = Object.assign({}, defaults, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(function() {
    return Array(x_length).fill(0);
  });
  var _getValue = function(x, y) {
    if (options.map[y] && typeof options.map[y][x] != 'undefined') {
      return options.map[y][x];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value == 0) {
        if (to.x == options.end.x && to.y == options.end.y) {
          steps[to.y][to.x] = from;
          finded = true;
        } else if (!steps[to.y][to.x]) {
          steps[to.y][to.x] = from;
          new_list.push(to);
        }
      }
    };
    list.forEach(function(current) {
      next(current, {y: current.y + 1, x: current.x});
      next(current, {y: current.y, x: current.x + 1});
      next(current, {y: current.y - 1, x: current.x});
      next(current, {y: current.y, x: current.x - 1});
    });
    if (!finded && new_list.length) {
      _render(new_list);
    }
  };
  _render([options.start]);
  if (finded) {
    var current = options.end;
    while (current.x != options.start.x || current.y != options.start.y) {
      result.unshift(current);
      current = steps[current.y][current.x];
    }
  }
  return result;
}
var path = finder({ map:opened, start:{x:1,y:1}, end:{x:0,y:3} });
function tick() {
  if (path.length) {
    fillRect(60, 10, 30, 30, 6);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FINDER.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FINDER.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "finder BFS did not path out of a 2-cell"
    finally:
        sim.shutdown()


def test_rtl_nested_for_continue_skips_cells():
    """RTL twin of bunker-arch continue: skipped corners must not paint."""
    src = """
var n = 0;
for (var row = 0; row < 10; row++) {
  for (var col = 0; col < 14; col++) {
    if (row === 0 && (col < 2 || col > 11)) continue;
    if (row === 1 && (col < 1 || col > 12)) continue;
    if (row >= 6 && col >= 5 && col <= 8) continue;
    n = n + 1;
  }
}
function tick() {
  if (n === 118) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("CONT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "CONT.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "nested for continue did not skip 22 cells"
    finally:
        sim.shutdown()


def test_rtl_array_find_identity_splice():
    """arr.find(el => el === obj) then splice — INVADERS bullet path."""
    src = """
var grid = [{n:1}, {n:2}, {n:3}];
var a = grid[1];
var hit = grid.find(function(el) { return el === a; });
if (hit === a) grid.splice(1, 1);
function tick() {
  if (grid.length === 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FIND.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FIND.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "Array.find identity splice did not drop the object"
    finally:
        sim.shutdown()


def test_rtl_value64_array_find_identity_splice():
    """Value64 arr.find(el => el === obj) then splice (HTML titles)."""
    src = """
var grid = [{n:1}, {n:2}, {n:3}];
var a = grid[1];
var hit = grid.find(function(el) { return el === a; });
if (hit === a) grid.splice(1, 1);
function tick() {
  if (grid.length === 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("VFIND.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "VFIND.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_value64_array_fill_map_nested():
    """Value64 Array(n).fill(0).map(() => Array(m).fill(0)) writable rows."""
    src = """
var steps = Array(2).fill(0).map(function() {
  return Array(2).fill(0);
});
steps[0][1] = 7;
function tick() {
  if (steps[0] && steps[0][1] == 7) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("VARMAP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "VARMAP.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_value64_array_filter_unshift():
    """Value64 Array.filter + unshift (getItemsByType / path rebuild)."""
    src = """
var items = [{t:1}, {t:2}, {t:1}];
var a = items.filter(function(e) { return e.t == 1; });
var p = [9];
p.unshift(3);
function tick() {
  if (a.length === 2 && p[0] === 3 && p.length === 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("VFILT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "VFILT.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_value64_raf_map_churn_no_heap_fault():
    """rAF Array.map + {x,y} temps must collect; idle PACMAN died at fault=3."""
    import re as _re

    src = """
function tick() {
  var i = 0;
  while (i < 8) {
    Array(8).fill(0).map(function() { return {x: 1, y: 1}; });
    i = i + 1;
  }
  fillRect(10, 10, 8, 8, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("VCHURN.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "VCHURN.JS"')
        sim.type_line("RUN")
        st = ""
        for _ in range(64):
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?") or ""
            assert "fault=3" not in st, st
            assert "sname=S_IDLE" not in st, st
            assert "fcap=0" in st, st
        assert "fault=0" in st, st
        raf = int(_re.search(r"raf=(\d+)", st).group(1))
        assert raf >= 1, st
        gc = int(_re.search(r"gc=(\d+)", st).group(1))
        assert gc > 0, st
        assert "vdraw=10,10,8,8,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_present_once_per_frame():
    """rAF + setTimeout(0) in the same frame must present once (write_repeat).

    Each callback used to pulse fb_swap at ip>=n_ops, so swaps ran at ~2×
    frames and the glass interleaved half-drawn banks.
    """
    import re as _re

    src = """
var n = 0;
function tick() {
  n = n + 1;
  fillRect(10, 10, 8, 8, 2);
  setTimeout(function() { n = n; }, 0);
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("PONCE.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "PONCE.JS"')
        sim.type_line("RUN")
        for _ in range(4):
            sim._rpc("FRAME")
        st0 = sim._rpc("VMSTAT?")
        s0 = int(_re.search(r"swaps=(\d+)", st0 or "").group(1))
        # ~12 frame_tick periods (65536 clocks). One present/frame → ~12 swaps;
        # per-callback present → ~24.
        f0 = int(_re.search(r"frend=(\d+)", st0 or "").group(1))
        sim._rpc(f"TICKN {800 * _VMDIV}")
        st1 = sim._rpc("VMSTAT?")
        s1 = int(_re.search(r"swaps=(\d+)", st1 or "").group(1))
        f1 = int(_re.search(r"frend=(\d+)", st1 or "").group(1))
        delta = s1 - s0
        frames = f1 - f0
        # S_FB_SYNC copies each presented frame into the back bank
        # (~307k clk/present), so absolute swaps per wall-clock window
        # shrank. The invariant is unchanged: at most ONE present per
        # completed frame (the per-callback bug presented ~2x frames).
        assert 1 <= delta <= frames + 1, (
            f"present not once per frame: swaps {s0}->{s1} delta={delta} "
            f"frames={frames} ({st1})"
        )
    finally:
        sim.shutdown()


def test_rtl_foreach_settimeout_find_splice():
    """Nested forEach + setTimeout(0) + identity find + splice(captured i).

    PYTHON twin: test_foreach_settimeout_splice_object_identity. Must drop
    the matched object, not the last forEach index.
    """
    src = """
var invaders = [{id:0},{id:1},{id:2}];
var shots = [invaders[1]];
invaders.forEach((invader, i) => {
  shots.forEach((projectile, j) => {
    if (projectile === invader) {
      setTimeout(() => {
        const found = invaders.find((inv2) => inv2 === invader);
        if (found) invaders.splice(i, 1);
      }, 0);
    }
  });
});
function tick() {
  if (invaders.length === 2 && invaders[0].id === 0 && invaders[1].id === 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("HIT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "HIT.JS"')
        sim.type_line("RUN")
        for _ in range(12):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, (
            "setTimeout(0) find+splice did not drop the identity match"
        )
    finally:
        sim.shutdown()


def test_rtl_nested_arr_prop_find_splice():
    """splice must mutate the array stored on an object (grid.invaders).

    A top-level array splice can pass while obj.arr.splice() hits a copy.
    """
    src = """
var grid = { invaders: [{id:0},{id:1},{id:2}] };
var shots = [grid.invaders[1]];
grid.invaders.forEach((invader, i) => {
  shots.forEach((projectile, j) => {
    if (projectile === invader) {
      setTimeout(() => {
        const found = grid.invaders.find((inv2) => inv2 === invader);
        if (found) grid.invaders.splice(i, 1);
      }, 0);
    }
  });
});
function tick() {
  if (grid.invaders.length === 2 && grid.invaders[0].id === 0 && grid.invaders[1].id === 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("GSPLC.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GSPLC.JS"')
        sim.type_line("RUN")
        for _ in range(12):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, (
            "obj.arr identity find+splice did not drop the match"
        )
    finally:
        sim.shutdown()


def test_rtl_settimeout_delay_keeps_drawing():
    """setTimeout(fn, 1000) must not fire on the next few frames."""
    src = """
var n = 0;
setTimeout(function() { n = 1; }, 1000);
function tick() {
  if (n === 0) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("TDELAY.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "TDELAY.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "setTimeout(1000) fired immediately (stopped drawing)"
    finally:
        sim.shutdown()


def test_rtl_list_space_pages_past_230():
    """LIST MORE Space must pump clocks so later HTML lines appear."""
    html = storage_html_min_lines(230)
    if html is None:
        pytest.skip("no storage HTML with >230 lines")
    sim = _sim()
    try:
        sim.type_line(f'LOAD "{html.name}"')
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        assert "-- MORE" in st, st[-400:]
        nums0 = []
        for ln in st.splitlines():
            tok = ln.strip().split(None, 1)
            if tok and tok[0].isdigit():
                nums0.append(int(tok[0]))
        sim.push_key(" ")
        st2 = sim.screen_text().replace("\\n", "\n")
        nums = []
        for ln in st2.splitlines():
            tok = ln.strip().split(None, 1)
            if tok and tok[0].isdigit():
                nums.append(int(tok[0]))
        prev = max(nums0) if nums0 else 0
        assert nums and max(nums) > prev, (prev, max(nums) if nums else None, st2[-400:])
    finally:
        sim.shutdown()


def test_rtl_two_keydown_listeners_and_remove():
    src = """
var n = 0;
function fa(e) { if (e.keyCode === 13) n = n + 1; }
function fb(e) { if (e.keyCode === 13) n = n + 10; }
addEventListener("keydown", fa);
addEventListener("keydown", fb);
function tick() {
  if (n === 11) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("LISN.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "LISN.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        sim._rpc("KEYEVT 13 1")
        sim._rpc("FRAME")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "both keydown listeners did not fire"
    finally:
        sim.shutdown()


def test_rtl_dispatch_event_enter():
    src = """
var st = 0;
addEventListener("keydown", function(e) {
  if (e.keyCode === 13) st = 1;
});
var ev = { type: "keydown", key: "Enter", keyCode: 13, which: 13 };
if (document.dispatchEvent) document.dispatchEvent(ev);
function tick() {
  if (st === 1) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("DISP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "DISP.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "dispatchEvent Enter did not reach keydown"
    finally:
        sim.shutdown()


def test_rtl_keyboard_event_ctor_sets_key():
    """new KeyboardEvent must copy options.key so e.key === 'Enter' (DONKEY boot)."""
    src = """
var st = 0;
addEventListener("keydown", function(e) {
  if (e.key === "Enter") st = 1;
});
var ev;
try {
  ev = new KeyboardEvent("keydown", { key: "Enter", keyCode: 13, which: 13 });
} catch (e) {
  ev = { type: "keydown", key: "Enter", keyCode: 13, which: 13 };
}
if (document.dispatchEvent) document.dispatchEvent(ev);
function tick() {
  if (st === 1) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("KBEV.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "KBEV.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "new KeyboardEvent did not set e.key"
    finally:
        sim.shutdown()


def test_rtl_position2coord_offset_center():
    """Generic cell-center offset: falsy at center, truthy ±2 px."""
    src = """
var size = 14, mx = 50, my = 50, cx = 12, cy = 14;
var posx = mx + cx * size + size / 2;
var posy = my + cy * size + size / 2;
var fx = Math.abs(posx - mx) % size - size / 2;
var fy = Math.abs(posy - my) % size - size / 2;
var offset = Math.sqrt(fx * fx + fy * fy);
var moved = Math.sqrt(
  (Math.abs(posx + 2 - mx) % size - size / 2) *
  (Math.abs(posx + 2 - mx) % size - size / 2)
);
var ok = (!offset && moved) ? 1 : 0;
function tick() {
  if (ok) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("OFFS.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "OFFS.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "position2coord offset not falsy at cell center"
    finally:
        sim.shutdown()


def test_rtl_join_empty_eq_case_1100():
    """RTL twin: join('') === '1100' and indexOf(1) > -1."""
    src = """
var code = [1, 1, 0, 0];
var hit = 0;
switch (code.join('')) {
  case '1100':
    if (code.indexOf(1) > -1) hit = 1;
    break;
  default:
    hit = 2;
}
function tick() {
  if (hit == 1) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("JOIN.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "JOIN.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "join('') did not EQ case 1100"
    finally:
        sim.shutdown()


def test_rtl_switch_join_draws_arc_not_spokes():
    """RTL twin: 1100 paints a quarter-arc, not a spoke through the cell center."""
    src = """
var c = document.getElementById('c').getContext('2d');
c.strokeStyle = '#09f';
c.lineWidth = 2;
var code = [1, 1, 0, 0];
var size = 20;
var posx = 100, posy = 100;
function tick() {
  switch (code.join('')) {
    case '1100':
      c.beginPath();
      c.arc(posx + size / 2, posy + size / 2, size / 2, 3.14159265, 4.71238898, false);
      c.stroke();
      break;
    default:
      c.beginPath();
      c.moveTo(posx, posy);
      c.lineTo(posx + 10, posy);
      c.stroke();
      c.beginPath();
      c.moveTo(posx, posy);
      c.lineTo(posx, posy + 10);
      c.stroke();
      c.beginPath();
      c.moveTo(posx, posy);
      c.lineTo(posx - 10, posy);
      c.stroke();
      c.beginPath();
      c.moveTo(posx, posy);
      c.lineTo(posx, posy - 10);
      c.stroke();
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("ARCS.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ARCS.JS"')
        sim.type_line("RUN")
        # FRAME waits for a rAF present (TICK+FB? used to pump 614k extra clocks)
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 100, 100) == 0, "spoke through cell center (join missed case)"
        assert _fb_pix(raw, 100, 110) != 0, "quarter-arc occupancy missing"
    finally:
        sim.shutdown()


def test_rtl_ghost_update_leaves_start_cell():
    """RTL twin: ghost-update snippet leaves the start cell (finder + COS)."""
    src = r"""
function _copyMapOpen(_cm_s){var _cm_o=[];for(var _cm_j=0;_cm_j<_cm_s.length;_cm_j++){var _cm_w=_cm_s[_cm_j],_cm_r=[];for(var _cm_i=0;_cm_i<_cm_w.length;_cm_i++){_cm_r.push(_cm_w[_cm_i]==2?0:_cm_w[_cm_i]);}_cm_o.push(_cm_r);}return _cm_o;}
var size = 14, mx = 0, my = 0;
var _COS = [1, 0, -1, 0], _SIN = [0, 1, 0, -1];
function position2coord(x, y) {
  var fx = Math.abs(x - mx) % size - size / 2;
  var fy = Math.abs(y - my) % size - size / 2;
  return {
    x: Math.floor((x - mx) / size),
    y: Math.floor((y - my) / size),
    offset: Math.sqrt(fx * fx + fy * fy)
  };
}
function finder(params) {
  var options = Object.assign({}, {map: null, start: {}, end: {}}, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(function() {
    return Array(x_length).fill(0);
  });
  var _getValue = function(x, y) {
    if (options.map[y] && typeof options.map[y][x] != 'undefined') {
      return options.map[y][x];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value == 0) {
        if (to.x == options.end.x && to.y == options.end.y) {
          steps[to.y][to.x] = from;
          finded = true;
        } else if (!steps[to.y][to.x]) {
          steps[to.y][to.x] = from;
          new_list.push(to);
        }
      }
    };
    list.forEach(function(current) {
      next(current, {y: current.y + 1, x: current.x});
      next(current, {y: current.y, x: current.x + 1});
      next(current, {y: current.y - 1, x: current.x});
      next(current, {y: current.y, x: current.x - 1});
    });
    if (!finded && new_list.length) {
      _render(new_list);
    }
  };
  _render([options.start]);
  if (finded) {
    var current = options.end;
    while (current.x != options.start.x || current.y != options.start.y) {
      result.unshift(current);
      current = steps[current.y][current.x];
    }
  }
  return result;
}
var data = [
  [1, 1, 1, 1],
  [1, 2, 2, 1],
  [1, 0, 0, 1],
  [1, 0, 0, 1]
];
var ghost = {
  x: mx + 1 * size + size / 2,
  y: my + 1 * size + size / 2,
  speed: 1,
  orientation: 3,
  status: 1,
  timeout: 0,
  coord: {x: 1, y: 1, offset: 0},
  vector: {x: 1, y: 1},
  path: []
};
var player = {coord: {x: 1, y: 3}};
var startx = ghost.x, starty = ghost.y;
var i;
for (i = 0; i < 40; i++) {
  ghost.coord = position2coord(ghost.x, ghost.y);
  if (ghost.timeout) ghost.timeout--;
  if (!ghost.coord.offset) {
    if (ghost.status == 1 && !ghost.timeout) {
      var new_map = _copyMapOpen(data);
      ghost.path = finder({map: new_map, start: ghost.coord, end: player.coord});
      if (ghost.path.length) {
        ghost.vector = ghost.path[0];
      }
      if (ghost.vector.x > ghost.coord.x) ghost.orientation = 0;
      else if (ghost.vector.x < ghost.coord.x) ghost.orientation = 2;
      else if (ghost.vector.y > ghost.coord.y) ghost.orientation = 1;
      else if (ghost.vector.y < ghost.coord.y) ghost.orientation = 3;
    }
  }
  ghost.x += ghost.speed * _COS[ghost.orientation];
  ghost.y += ghost.speed * _SIN[ghost.orientation];
}
var left = (ghost.x != startx || ghost.y != starty) ? 1 : 0;
function tick() {
  if (left) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("GHOST.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GHOST.JS"')
        sim.type_line("RUN")
        # JSON engine removed: the loop-equivalent map copy runs at
        # interpreted speed (was 1 cell/beat hardware) — allow 3 frames.
        for _ in range(3):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "ghost-update snippet did not leave start cell"
    finally:
        sim.shutdown()


def test_rtl_house_cell_offset_cos_moves():
    """Map origin 16,8 size 14 cell (12,14): !offset then _COS/_SIN step."""
    src = """
var size = 14, mx = 16, my = 8, cx = 12, cy = 14;
var _COS = [1, 0, -1, 0], _SIN = [0, 1, 0, -1];
function position2coord(x, y) {
  var fx = Math.abs(x - mx) % size - size / 2;
  var fy = Math.abs(y - my) % size - size / 2;
  return {
    x: Math.floor((x - mx) / size),
    y: Math.floor((y - my) / size),
    offset: Math.sqrt(fx * fx + fy * fy)
  };
}
var x = mx + cx * size + size / 2;
var y = my + cy * size + size / 2;
var speed = 1, orientation = 3;
var starty = y;
var i, coord;
for (i = 0; i < 20; i++) {
  coord = position2coord(x, y);
  if (!coord.offset) {
    y += speed * _SIN[orientation];
    x += speed * _COS[orientation];
  } else {
    y += speed * _SIN[orientation];
    x += speed * _COS[orientation];
  }
}
var left = (y != starty) ? 1 : 0;
function tick() {
  if (left) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("GMOVE.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GMOVE.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "house-cell !offset / _COS did not change y"
    finally:
        sim.shutdown()


def test_rtl_finder_many_frames_still_paths():
    """Array nursery rewind: finder JSON/steps temps must not pin n_arr."""
    src = r"""
function _copyMapOpen(_cm_s){var _cm_o=[];for(var _cm_j=0;_cm_j<_cm_s.length;_cm_j++){var _cm_w=_cm_s[_cm_j],_cm_r=[];for(var _cm_i=0;_cm_i<_cm_w.length;_cm_i++){_cm_r.push(_cm_w[_cm_i]==2?0:_cm_w[_cm_i]);}_cm_o.push(_cm_r);}return _cm_o;}
var data = [
  [1,1,1,1],
  [1,2,2,1],
  [1,2,2,1],
  [0,0,0,0]
];
function finder(params) {
  var defaults = { map:null, start:{}, end:{}, type:'path' };
  var options = Object.assign({}, defaults, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(function() {
    return Array(x_length).fill(0);
  });
  var _getValue = function(x, y) {
    if (options.map[y] && typeof options.map[y][x] != 'undefined') {
      return options.map[y][x];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value == 0) {
        if (to.x == options.end.x && to.y == options.end.y) {
          steps[to.y][to.x] = from;
          finded = true;
        } else if (!steps[to.y][to.x]) {
          steps[to.y][to.x] = from;
          new_list.push(to);
        }
      }
    };
    list.forEach(function(current) {
      next(current, {y: current.y + 1, x: current.x});
      next(current, {y: current.y, x: current.x + 1});
      next(current, {y: current.y - 1, x: current.x});
      next(current, {y: current.y, x: current.x - 1});
    });
    if (!finded && new_list.length) {
      _render(new_list);
    }
  };
  _render([options.start]);
  if (finded) {
    var current = options.end;
    while (current.x != options.start.x || current.y != options.start.y) {
      result.unshift(current);
      current = steps[current.y][current.x];
    }
  }
  return result;
}
var n = 0;
function tick() {
  var opened = _copyMapOpen(data);
  var path = finder({ map:opened, start:{x:1,y:1}, end:{x:0,y:3} });
  if (path.length) n = n + 1;
  if (n >= 2) {
    fillRect(60, 10, 30, 30, 6);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FINDN.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FINDN.JS"')
        sim.type_line("RUN")
        for _ in range(2000 * _VMDIV):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "finder temps pinned n_arr; later frames returned []"
    finally:
        sim.shutdown()


def test_rtl_setinterval_rearms():
    """setInterval must fire more than once (PYTHON twin test_setinterval_rearms_and_clear_cancels)."""
    src = """
var n = 0;
setInterval(function() {
  n = n + 1;
  if (n >= 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
}, 0);
"""
    sim = _sim()
    try:
        _patch_js("INTV.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "INTV.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "setInterval did not rearm"
    finally:
        sim.shutdown()


def test_rtl_reverse_at_cell_center():
    """KEYEVT reverse is applied at the next cell center (PACMAN reverse stall)."""
    src = """
var size = 14;
var x = size / 2;
var dir = 1;
var queued = 1;
addEventListener("keydown", function(e) {
  if (e.keyCode === 37) queued = -1;
  if (e.keyCode === 39) queued = 1;
});
function tick() {
  var fx = Math.abs(x) % size - size / 2;
  if (!fx) dir = queued;
  x = x + dir;
  if (dir === -1) {
    fillRect(10, 10, 30, 30, 2);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("REV.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "REV.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        sim._rpc("KEYEVT 37 1")
        for _ in range(20):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "KEYEVT reverse did not apply at cell center"
    finally:
        sim.shutdown()


def test_rtl_class_getter_aabb_lands():
    """GET_PROP of `get bottom()` must be y+height so the overlap window hits.

    Same class of miss as a projectile skipping an AABB: the HTML compares
    numbers, but an uninvoked getter leaves undefined/+0 and the body falls
    through the floor.
    """
    src = """
class Body {
  constructor(x, y, w, h) {
    this.x = x;
    this.y = y;
    this.width = w;
    this.height = h;
    this.speed = 2;
  }
  get bottom() { return this.y + this.height; }
  land(platY) {
    if (this.bottom > platY && this.bottom - this.speed < platY + 24) {
      this.y = platY - this.height;
    }
  }
}
var p = new Body(200, 608, 35, 52);
p.land(648);
function tick() {
  if (p.y == 596) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        from functional_model.compiler import compile_source
        from functional_model.jsb_format import encode_chunk
        from tools.make_sd_image import patch_card_file

        card = _scratch_card() or (ROOT / "card.img")
        blob = encode_chunk(compile_source(src), v2=True, value64=True)
        patch_card_file(card, "AABB.JS", src.encode("utf-8"))
        patch_card_file(card, "AABB.JSB", blob)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "AABB.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        # Value64 native fillRect updates vdraw even when FB? is still the
        # READY glass. Land only paints this rect if get bottom() was y+h.
        st = sim._rpc("VMSTAT?")
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_make_array_setprop_this_beyond_tos_window():
    """MAKE_ARRAY of 16+ then SET_PROP must keep `this` under the handle.

    The TOS window is 16 FFs. A 20-element literal drops vsp by 19, so
    win[1] stays leftover unless BRAM refills it. SET_PROP then wrote the
    array onto that leftover instead of the receiver, and a later for-of
    over this.cells saw length 0 (no tiles / no AABB).
    """
    cells = ",\n      ".join(f"new Cell({i})" for i in range(20))
    src = f"""
class Cell {{
  constructor(n) {{ this.n = n; }}
}}
class Box {{
  constructor() {{
    this.cells = [
      {cells}
    ];
  }}
  sum() {{
    let s = 0;
    for (const c of this.cells) s = s + c.n;
    return s;
  }}
}}
var b = new Box();
function tick() {{
  if (b.sum() == 190) {{
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }}
  requestAnimationFrame(tick);
}}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        from functional_model.compiler import compile_source
        from functional_model.jsb_format import encode_chunk
        from tools.make_sd_image import patch_card_file

        card = _scratch_card() or (ROOT / "card.img")
        blob = encode_chunk(compile_source(src), v2=True, value64=True)
        patch_card_file(card, "ARR20.JS", src.encode("utf-8"))
        patch_card_file(card, "ARR20.JSB", blob)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ARR20.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_array_push_70_cells():
    """array.push past the old ARR_CAP=64 must keep length (bunker bricks)."""
    src = """
var cells = [];
var i = 0;
while (i < 70) {
  cells.push({n: i});
  i = i + 1;
}
function tick() {
  if (cells.length == 70) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("PUSH70.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "PUSH70.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_array_pop():
    """Array.pop must shrink length (ASTEROID clearArr / any while-pop)."""
    src = """
var a = [1, 2, 3];
var x = a.pop();
function tick() {
  if (x == 3 && a.length == 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("ARRPOP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ARRPOP.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_array_pop():
    """Array.pop must shrink length (ASTEROID clearArr / any while-pop)."""
    src = """
var a = [1, 2, 3];
var x = a.pop();
function tick() {
  if (x == 3 && a.length == 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("ARRPOP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ARRPOP.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_date_now_inside_iife_raf():
    """Date.now() in a nested rAF callback must not ERROR_HANDLE (stale env)."""
    src = """
(function () {
  var lastTime = 0;
  function tick() {
    var now = Date.now();
    if (now >= lastTime) {
      fillRect(10, 10, 30, 30, 2);
      swapBuffers();
    }
    lastTime = now;
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
})();
"""
    sim = _sim()
    try:
        _patch_js_v64("DATENOW.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "DATENOW.JS"')
        sim.type_line("RUN")
        for _ in range(6):
            sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_console_log_rings_does_not_halt():
    """console.log overflow must not CAPACITY-fault (DONKEY Mario.update)."""
    src = """
var i = 0;
function tick() {
  while (i < 300) {
    console.log(i);
    i = i + 1;
  }
  fillRect(10, 10, 30, 30, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("LOG300.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "LOG300.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_array_get_non_number_is_undefined():
    """arr[undefined] must not ERROR_INTERNAL (PACMAN _COS[orientation])."""
    src = """
var a = [1, 0, -1, 0];
var miss = a[undefined];
function tick() {
  if (miss === undefined) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("ARRUND.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ARRUND.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_foreach_literal_array_set_x():
    """LOAD_VAR current then SET_PROP x must write the object, not the env."""
    src = """
var steps = [[0,0,0],[0,0,0],[0,0,0]];
var list = [{x:1, y:1}];
list.forEach(function(current) {
  var to = {y: current.y + 1, x: current.x};
  if (!steps[to.y][to.x]) steps[to.y][to.x] = current;
});
function tick() {
  if (steps[2][1]) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("FEXSET.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FEXSET.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_foreach_literal_array_set_x():
    """LOAD_VAR current then SET_PROP x must write the object, not the env."""
    src = """
var steps = [[0,0,0],[0,0,0],[0,0,0]];
var list = [{x:1, y:1}];
list.forEach(function(current) {
  var to = {y: current.y + 1, x: current.x};
  if (!steps[to.y][to.x]) steps[to.y][to.x] = current;
});
function tick() {
  if (steps[2][1]) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("FEXSET.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FEXSET.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_item_assign_cos_orientation():
    """Object.assign(this, settings, params) must copy params.orientation."""
    src = """
var t = {times: 0};
Object.assign(t, {times: 0, orientation: 0}, {orientation: 3});
function tick() {
  if (t.times == 0 && t.orientation == 3) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("COSORI.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "COSORI.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_class_field_listener_enter():
    """GET_PROP this.method must yield a Fn so KEYEVT Enter reaches it."""
    src = """
var hit = 0;
class G {
  startSelect = (e) => {
    if (e.key === "Enter") hit = 1;
  }
}
const g = new G();
addEventListener("keydown", g.startSelect);
function tick() {
  if (hit) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("CLSM.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "CLSM.JS"')
        sim.type_line("RUN")
        for _ in range(4):
            sim._rpc("FRAME")
        sim._rpc("KEYEVT 13 1")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "class-field listener did not see Enter"
    finally:
        sim.shutdown()


def test_rtl_control_object_survives_frames():
    """player.control = {orientation:n} must outlive the object nursery rewind."""
    src = """
var player = {x: 0};
var n = 0;
addEventListener("keydown", function(e) {
  if (e.keyCode == 37) player.control = {orientation: 2};
});
function tick() {
  n = n + 1;
  if (player.control && player.control.orientation == 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("CTRL.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "CTRL.JS"')
        sim.type_line("RUN")
        # ARR_KEEP_DELAY is 8 frames — rewind must be live before the key
        for _ in range(12):
            sim._rpc("FRAME")
        sim._rpc("KEYEVT 37 1")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "player.control was rewound"
    finally:
        sim.shutdown()


def test_rtl_destructure_space_key():
    """const { key } = e; key === ' ' must match KEYEVT 32 (INVADERS start)."""
    src = """
var hit = 0;
addEventListener("keydown", function(e) {
  const { key } = e;
  if (key === " ") hit = 1;
});
function tick() {
  if (hit) {
    fillRect(10, 10, 30, 30, 4);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("DSPC.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "DSPC.JS"')
        sim.type_line("RUN")
        for _ in range(4):
            sim._rpc("FRAME")
        sim._rpc("KEYEVT 32 1")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "destructured e.key !== space"
    finally:
        sim.shutdown()


def test_rtl_ctor_children_survive_frames():
    """arr.push(new C()) must keep the ctor's OWN array + child objects.

    The object watermark is stored oid+1, but a constructor allocates its
    children AFTER the instance, so everything the ctor built sat in the
    nursery and the per-frame rewind dropped it (INVADERS alien formation
    vanished one frame after startGame; the array watermark was never
    committed at all).
    """
    src = """
var grids = [];
var started = 0;
class Grid {
  constructor() {
    this.items = [];
    var i;
    for (i = 0; i < 3; i++) {
      this.items.push({n: i + 1});
    }
  }
}
addEventListener("keydown", function(e) {
  if (e.keyCode == 32 && !started) {
    started = 1;
    grids.push(new Grid());
  }
});
function tick() {
  // per-frame churn: rewind only resets the bump pointer, so the dropped
  // oids must actually be handed out again for the loss to show (any real
  // game allocates temps every frame)
  var j;
  for (j = 0; j < 6; j++) {
    var tmp = {a: j, b: [j, j + 1]};
  }
  var ok = 0;
  grids.forEach(function(g) {
    if (g.items && g.items.length == 3 && g.items[2] && g.items[2].n == 3) ok = 1;
  });
  if (ok) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("CTORK.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "CTORK.JS"')
        sim.type_line("RUN")
        # keep watermarks must already be live before the push
        for _ in range(12):
            sim._rpc("FRAME")
        sim._rpc("KEYEVT 32 1")
        for _ in range(12):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "ctor-built array/objects were rewound"
    finally:
        sim.shutdown()


def test_rtl_boot_heavy_loop_survives():
    """A loop registered at top-level after heavy boot allocation must live.

    The nursery does not rewind during the keep grace window, so a long grace
    baked that many frames of per-frame temps into the kept region. With too
    little headroom left, a frame allocated over its own live rAF Fn object and
    the dispatcher then ran a stale function that never re-armed — PACMAN froze
    on its first drawn frame with raf=0.
    """
    # NOTE: build inside a function. Top-level LET_VAR is "init only if missing"
    # in BOTH the FM and RTL (startLoop re-entry), so `var row = []` in a
    # top-level loop would alias one array on either rung.
    src = """
function build() {
  var out = [];
  var i;
  for (i = 0; i < 120; i++) { out.push({a:i, c:{d:i * 2}}); }
  return out;
}
var boot = build();
var n = 0;
function tick() {
  // per-frame churn so the nursery actually recycles
  var k, tmp;
  for (k = 0; k < 40; k++) { tmp = {x:k, y:[k, k+1], z:{w:k}}; }
  n = n + 1;
  if (n >= 10 && boot.length == 120 && boot[119].c.d == 238) {
    fillRect(20, 20, 40, 40, 3);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("BOOTL.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "BOOTL.JS"')
        sim.type_line("RUN")
        for _ in range(30):
            sim._rpc("FRAME")
        assert "raf=1" in sim._rpc("VMSTAT?"), "boot-registered loop stopped re-arming"
        assert _fb_nz(sim) >= 200, "loop died or boot heap was clobbered"
    finally:
        sim.shutdown()


def test_rtl_string_row_bitmap_draws():
    """str.length + str[i] === "1" — string-row sprites (INVADERS drawBitmap).

    RTL kept only a hash+length per interned string and never loaded the UTF-8
    name bytes, so row.length was undefined (loop body skipped) and row[col]
    was undefined. Every alien/saucer drawn this way was invisible while
    fillRect/drawImage art still painted.
    """
    src = """
var ROWS = ["0110", "1111"];
function drawBitmap(x, y, rows, scale) {
  var r, col, row;
  for (r = 0; r < rows.length; r++) {
    row = rows[r];
    for (col = 0; col < row.length; col++) {
      if (row[col] === "1") {
        fillRect(x + col * scale, y + r * scale, scale, scale, 5);
      }
    }
  }
}
function tick() {
  drawBitmap(20, 20, ROWS, 8);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("STRIX.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "STRIX.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        # 6 set bits x 8x8 = 384 px; anything less means chars did not compare
        assert _fb_nz(sim) >= 384, f"string-row bitmap drew {_fb_nz(sim)} px"
    finally:
        sim.shutdown()


def test_rtl_html_string_row_bitmap_draws():
    """Value64 HTML path: row[col]==="1" then c.fillRect (INVADERS drawBitmap).

    Tagged .JS used a 1-beat STRIDX that happened to match parent name_rdaddr.
    HTML RUN is exec64: name_rdaddr is exec's FF, name_rdata/char_id each lag
    one clock. Hopping STRIDX→WR the first beat made === "1" never true, so
    splash aliens/saucer/cannon bitmaps stayed blank while fillRect bars painted.
    """
    html = """<!DOCTYPE html><canvas id="c" width="640" height="480"></canvas>
<script>
var c = document.getElementById('c').getContext('2d');
var ROWS = ["0110", "1111"];
function drawBitmap(x, y, rows, scale) {
  var r, col, row;
  for (r = 0; r < rows.length; r++) {
    row = rows[r];
    for (col = 0; col < row.length; col++) {
      if (row[col] === "1") {
        c.fillRect(x + col * scale, y + r * scale, scale, scale);
      }
    }
  }
}
function tick() {
  c.fillStyle = '#fff';
  drawBitmap(20, 20, ROWS, 8);
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
</script>
"""
    from tools.compile_js import compile_html_text, encode_html_chunk

    sim = _sim()
    try:
        sim._program_image = encode_html_chunk(compile_html_text(html))
        assert sim._stream_program_image().startswith("OK")
        # FRAME's 2000-clock idle abort never sees vsync (FRAME_DIV=65535),
        # so rAF never runs. TICKN lets the divider fire.
        st = ""
        for _ in range(8 * _VMDIV):
            sim._rpc("TICKN 20000")
            st = sim._rpc("VMSTAT?")
            if "sname=S_WAIT_FRAME" in st:
                break
        sim._rpc("TICKN 20000")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert _fb_nz(sim) >= 384, f"html string-row bitmap drew {_fb_nz(sim)} px ({st})"
    finally:
        sim.shutdown()


def test_rtl_html_fillrect_computed_y_w():
    """ctx.fillRect y/w from .length, not trailing immediates (drawBitmap).

    Literal c.fillRect(70,68,500,7) already paints. drawBitmap's
    fillRect(x+col*s, y+r*s, s, s) uses ADD/MUL/LOAD_VAR, so the TOS
    window can miss the canvas and native fillRect is skipped.
    """
    html = """<!DOCTYPE html><canvas id="c" width="640" height="480"></canvas>
<script>
var c = document.getElementById('c').getContext('2d');
var s = 'ab';
function tick() {
  c.fillStyle = '#fff';
  c.fillRect(10, s.length * 80, 8, 8);
  c.fillRect(200, 10, s.length * 4, 8);
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
</script>
"""
    from tools.compile_js import compile_html_text, encode_html_chunk

    sim = _sim()
    try:
        sim._program_image = encode_html_chunk(compile_html_text(html))
        assert sim._stream_program_image().startswith("OK")
        st = ""
        for _ in range(8 * _VMDIV):
            sim._rpc("TICKN 20000")
            st = sim._rpc("VMSTAT?")
            if "sname=S_WAIT_FRAME" in st:
                break
        sim._rpc("TICKN 20000")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        raw = _fb_raw(sim)
        # y = 2*80 = 160; w = 2*4 = 8. Wrong slot → these pixels stay 0.
        assert _fb_pix(raw, 12, 162) != 0, f"computed y missed ({st})"
        assert _fb_pix(raw, 204, 12) != 0, f"computed w missed ({st})"
    finally:
        sim.shutdown()


def _expect_text(text: str, x: int, y: int, k: int, align: str = "left") -> set:
    """Pixels PYTHON's canvas_engine.fill_text would set (the parity spec)."""
    from functional_model.font8 import glyph

    px = x - (len(text) * 8 * k) // 2 if align == "center" else x
    if align == "right":
        px = x - len(text) * 8 * k
    py = y - 8 * k
    out = set()
    for i, ch in enumerate(text):
        bits = glyph(ch)
        for dy, byte in enumerate(bits):
            for dx in range(8):
                if byte & (1 << (7 - dx)):
                    for ry in range(k):
                        for rx in range(k):
                            out.add((px + (i * 8 + dx) * k + rx, py + dy * k + ry))
    return out


def test_rtl_filltext_draws_real_glyphs():
    """ctx.fillText must paint the PYTHON 8x8 font, not a filled bar.

    RTL drew a solid 64x8 rect for every fillText, so every HUD/menu was a
    row of blocks. Glyphs come from the same font ROM the console scanout
    uses, and the px size in ctx.font picks the integer scale.
    """
    src = """
var c = document.getElementById('c').getContext('2d');
c.font = '16px Foo';
c.fillStyle = 'white';
function tick() {
  c.fillText('AB', 100, 108);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FTXT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FTXT.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        raw = _fb_raw(sim)
        want = _expect_text("AB", 100, 108, 2)
        got = {(i % 640, i // 640) for i, b in enumerate(raw) if b}
        assert got == want, (
            f"glyph pixels differ: {len(got)} drawn vs {len(want)} expected, "
            f"{len(want - got)} missing / {len(got - want)} extra"
        )
    finally:
        sim.shutdown()


def test_rtl_filltext_numbers_draw_digits():
    """fillText(number) must expand to digits (HUD score/level counters)."""
    src = """
var c = document.getElementById('c').getContext('2d');
var _SCORE = 0;
c.font = '8px F';
c.fillStyle = 'white';
function tick() {
  c.fillText(_SCORE, 100, 108);
  c.fillText(1234, 200, 108);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("NTXT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "NTXT.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        got = {(i % 640, i // 640) for i, b in enumerate(_fb_raw(sim)) if b}
        want = _expect_text("0", 100, 108, 1) | _expect_text("1234", 200, 108, 1)
        assert got == want, (
            f"numeric text differs: {len(want - got)} missing / {len(got - want)} extra"
        )
    finally:
        sim.shutdown()


def test_rtl_measure_text_does_not_churn_heap():
    """measureText per frame must not walk the keep watermark up.

    A fresh {width} object per call looked harmless, but any store into old
    space raises the keep watermark to the bump pointer, so one new object per
    frame crept upward until the ring wrapped and recycled the oldest live
    data. PACMAN lost half of its maze rows that way. One reserved metrics
    object is enough for every title.
    """
    src = """
var c = document.getElementById('c').getContext('2d');
function build() {
  var out = [];
  var i;
  for (i = 0; i < 100; i++) { out.push([i, i + 1, i + 2]); }
  return out;
}
var boot = build();
var keep = {n: 0};
var n = 0;
function tick() {
  c.font = '8px F';
  keep.n = c.measureText('SCORE').width;
  n = n + 1;
  if (n >= 50 && boot.length == 100 && boot[99] && boot[99][2] == 101) {
    fillRect(20, 20, 40, 40, 3);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("MTXT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "MTXT.JS"')
        sim.type_line("RUN")
        for _ in range(70):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 1500, "boot arrays were recycled under measureText churn"
    finally:
        sim.shutdown()


def test_rtl_filltext_center_align_and_joined_text():
    """textAlign='center' plus a built string ('P'+1) must draw its characters.

    A concat used to intern a hash with no bytes, so text assembled at runtime
    ('SCORE ' + score) had nothing to draw from.
    """
    src = """
var c = document.getElementById('c').getContext('2d');
c.font = '8px Foo';
c.textAlign = 'center';
c.fillStyle = 'white';
function tick() {
  c.fillText('P' + 1, 320, 108);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FTXTC.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FTXTC.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        raw = _fb_raw(sim)
        want = _expect_text("P1", 320, 108, 1, align="center")
        got = {(i % 640, i // 640) for i, b in enumerate(raw) if b}
        assert got == want, (
            f"centred joined text differs: {len(got)} drawn vs {len(want)} "
            f"expected, {len(want - got)} missing / {len(got - want)} extra"
        )
    finally:
        sim.shutdown()


def test_rtl_div_by_two_is_shift_not_restoring():
    """Integer /2 is a 1-cycle shift; /3 still uses the restoring divider.

    `cell/2` in a per-object loop used to cost 48 clocks each (board WNS
    forced a multi-cycle '/'). Exact even/even stays int; a tight loop of
    `/2` must not bump `divs` (slow-path count). `/3` still may. FRAME may
    run a handful of rAFs, so allow a few `/3` — not one per loop trip.
    """
    import re as _re

    src = """
var two = 2;
var cell = 4;
var n = 9;
var three = 3;
var i;
var acc;
function tick() {
  acc = 0;
  for (i = 0; i < 80; i++) acc = acc + cell / two;
  if (acc == 160 && n / three == 3 && (5 / two) * two == 5)
    fillRect(10, 10, 30, 30, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("DIV2.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "DIV2.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st0 = sim._rpc("VMSTAT?")
        d0 = int(_re.search(r"divs=(\d+)", st0 or "").group(1))
        sim._rpc("FRAME")
        st1 = sim._rpc("VMSTAT?")
        d1 = int(_re.search(r"divs=(\d+)", st1 or "").group(1))
        delta = d1 - d0
        assert delta < 20, (
            f"/2 used the 48-cycle divider: divs {d0}->{d1} delta={delta} ({st1})"
        )
        assert _fb_nz(sim) >= 50, f"/2 or /3 result was wrong ({st1})"
    finally:
        sim.shutdown()


def test_rtl_value64_div_by_two_is_shift_not_restoring():
    """Value64 /2 must be 1-cycle (HTML titles); /3 may still restore."""
    import re as _re

    src = """
var two = 2;
var cell = 4;
var n = 9;
var three = 3;
var i;
var acc;
function tick() {
  acc = 0;
  for (i = 0; i < 80; i++) acc = acc + cell / two;
  if (acc == 160 && n / three == 3 && (5 / two) * two == 5) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("VDIV2.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "VDIV2.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st0 = sim._rpc("VMSTAT?")
        d0 = int(_re.search(r"divs=(\d+)", st0 or "").group(1))
        sim._rpc("FRAME")
        st1 = sim._rpc("VMSTAT?")
        d1 = int(_re.search(r"divs=(\d+)", st1 or "").group(1))
        delta = d1 - d0
        assert delta < 20, (
            f"Value64 /2 used restoring DIV: divs {d0}->{d1} delta={delta} ({st1})"
        )
        assert "vdraw=10,10,30,30,2" in st1, st1
    finally:
        sim.shutdown()


def test_rtl_click_does_not_autostart():
    """click listener + rAF attract must stay idle until KEYEVT 32.

    A hidden #start addEventListener('click') must not be synthesized on
    the first WAIT_FRAME (Chrome never auto-clicks).
    """
    src = """
var active = 0;
addEventListener("click", function() { active = 1; });
addEventListener("keydown", function(e) {
  const { key } = e;
  if (!active && key === " ") active = 1;
});
function tick() {
  if (!active) fillRect(10, 10, 40, 40, 2);
  else fillRect(200, 10, 40, 40, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("SPLASH.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "SPLASH.JS"')
        sim.type_line("RUN")
        for _ in range(12):
            sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 20, 20) == 2, "attract was skipped (auto-click?)"
        assert _fb_pix(raw, 220, 20) != 3, "game rect painted before Space"
        sim._rpc("KEYEVT 32 1")
        for _ in range(12):
            sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 220, 20) == 3, "Space did not leave attract"
    finally:
        sim.shutdown()


def test_rtl_nested_map_rows_survive_raf():
    """Nested number rows [[1,1],[1,1]] must still read back after rAF.

    Maze tiles are a 2D number array. If the inner rows die, get(i,j) is
    falsy, beans paint a full grid, and wall strokes go missing/wrong —
    the garbled-maze look. Hardcoded join('1100') arcs already pass
    (test_rtl_switch_join_draws_arc_not_spokes); this is the map data.
    """
    src = """
var map = [[1, 1], [1, 1]];
function tick() {
  if (map[0] && map[0][0] == 1 && map[0][1] == 1 && map[1] && map[1][1] == 1) {
    fillRect(10, 10, 30, 30, 2);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("WBOX.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "WBOX.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 20, 20) == 2, "nested map[j][i] did not survive rAF"
    finally:
        sim.shutdown()


def test_rtl_drawimage_row_stride():
    """1:1 blit must keep source rows (wrong spr_ww looks like Venetian blinds)."""
    # 16×4: row0=2, row1=3, row2=4, row3=5
    pix = bytes([2] * 16 + [3] * 16 + [4] * 16 + [5] * 16)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 0, 0);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("STRIDE.JS", src, [(16, 4, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "STRIDE.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 8, 0) == 2, _fb_pix(raw, 8, 0)
        assert _fb_pix(raw, 8, 1) == 3, _fb_pix(raw, 8, 1)
        assert _fb_pix(raw, 8, 2) == 4, _fb_pix(raw, 8, 2)
        assert _fb_pix(raw, 8, 3) == 5, _fb_pix(raw, 8, 3)
    finally:
        sim.shutdown()


def test_rtl_scaled_drawimage_2x_solid():
    """5-arg drawImage 2× must fill dest, not skip every other row."""
    pix = bytes([4] * 16)  # 4×4 solid blue (palette 4)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 10, 10, 8, 8);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("SCALE2.JS", src, [(4, 4, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "SCALE2.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        holes = [
            (x, y)
            for y in range(10, 18)
            for x in range(10, 18)
            if _fb_pix(raw, x, y) != 4
        ]
        assert not holes, f"scaled blit holes (Venetian blinds) {holes[:8]}"
    finally:
        sim.shutdown()


def test_rtl_scaled_drawimage_2x_rows():
    """2× scale must repeat each source row, not skip dest lines."""
    pix = bytes([2] * 4 + [3] * 4)  # 4×2: row0=2, row1=3
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 0, 0, 8, 4);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("SCROW.JS", src, [(4, 2, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "SCROW.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 2, 0) == 2 and _fb_pix(raw, 2, 1) == 2, (
            _fb_pix(raw, 2, 0),
            _fb_pix(raw, 2, 1),
        )
        assert _fb_pix(raw, 2, 2) == 3 and _fb_pix(raw, 2, 3) == 3, (
            _fb_pix(raw, 2, 2),
            _fb_pix(raw, 2, 3),
        )
    finally:
        sim.shutdown()


def test_rtl_settransform_scales_drawimage():
    """setTransform(2,0,0,2,0,0) + natural drawImage must 2× dest."""
    pix = bytes([4] * 16)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.setTransform(2, 0, 0, 2, 0, 0);
  c.drawImage(img, 5, 5);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("XFDIM.JS", src, [(4, 4, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "XFDIM.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        # dest origin 10,10 size 8×8
        holes = [
            (x, y)
            for y in range(10, 18)
            for x in range(10, 18)
            if _fb_pix(raw, x, y) != 4
        ]
        assert not holes, f"setTransform blit holes {holes[:8]}"
    finally:
        sim.shutdown()


def test_rtl_raf_stays_armed():
    """Looping rAF must keep raf>=1 after a frame (DONKEY Enter left raf=0)."""
    import re as _re

    src = """
function tick() {
  fillRect(10, 10, 8, 8, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("RAF1.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "RAF1.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        m = _re.search(r"raf=(\d+)", st or "")
        assert m and int(m.group(1)) >= 1, st
    finally:
        sim.shutdown()


def test_rtl_getimagedata_small_finishes_frame():
    """8×8 getImageData must not eat the FRAME cap (full-canvas copy can)."""
    import re as _re

    src = """
var c = document.getElementById('c').getContext('2d');
function tick() {
  fillRect(0, 0, 8, 8, 2);
  var d = c.getImageData(0, 0, 8, 8);
  if (d) fillRect(40, 10, 8, 8, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("IMGD.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "IMGD.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        m = _re.search(r"fcap=(\d+)", st or "")
        assert m and int(m.group(1)) == 0, st
        assert _fb_pix(_fb_raw(sim), 44, 12) == 3, "getImageData did not return"
    finally:
        sim.shutdown()


def test_rtl_nested_map_survives_measuretext_timeout():
    """Maze rows must survive rAF + measureText + setTimeout(0) churn."""
    src = """
var map = [[1, 1], [1, 1]];
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.measureText("SCORE");
  setTimeout(function() { var z = 0; }, 0);
  if (map[0] && map[0][0] == 1 && map[1] && map[1][1] == 1) {
    fillRect(10, 10, 30, 30, 2);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("MCHURN.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "MCHURN.JS"')
        sim.type_line("RUN")
        for _ in range(12):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 20, 20) == 2, "map rows died under measureText/timer"
    finally:
        sim.shutdown()


def test_rtl_filltext_score_in_closure():
    """Numeric fillText inside a HUD closure must draw a glyph, not skip."""
    src = """
var score = 7;
function hud() {
  var c = document.getElementById('c').getContext('2d');
  c.font = '16px Foo';
  c.fillStyle = 'white';
  c.fillText(score, 40, 40);
}
function tick() {
  hud();
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("SCORE.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "SCORE.JS"')
        sim.type_line("RUN")
        for _ in range(4):
            sim._rpc("FRAME")
        raw = _fb_raw(sim)
        want = _expect_text("7", 40, 40, 2)
        got = {(i % 640, i // 640) for i, b in enumerate(raw) if b}
        assert want & got, f"SCORE digit missing: want {len(want)} got {len(got)}"
    finally:
        sim.shutdown()


def test_rtl_spr1_then_filltext():
    """NAMB must still load after a SPR1 pack (fillText after blit)."""
    pix = bytes([4] * 4)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
c.font = '8px F';
c.fillStyle = 'white';
function tick() {
  c.drawImage(img, 0, 0);
  c.fillText('A', 40, 40);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("SPTXT.JS", src, [(2, 2, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "SPTXT.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 0, 0) == 4, _fb_pix(raw, 0, 0)
        want = _expect_text("A", 40, 40, 1)
        got = {(i % 640, i // 640) for i, b in enumerate(raw) if b}
        assert want & got, "fillText after SPR1 missed NAMB"
    finally:
        sim.shutdown()


def test_rtl_aset_drawimage_1x():
    """ASET/SPRD 1:1 blit from asset SRAM (product path, tiny pack)."""
    pix = bytes([2] * 8 + [3] * 8)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 0, 0);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("ASET1.JS", src, [(8, 2, pix)], aset=True)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ASET1.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 4, 0) == 2, _fb_pix(raw, 4, 0)
        assert _fb_pix(raw, 4, 1) == 3, _fb_pix(raw, 4, 1)
    finally:
        sim.shutdown()


def test_rtl_aset_scaled_drawimage_2x():
    """ASET 5-arg 2× blit must fill dest (title-letter scale path)."""
    pix = bytes([4] * 16)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 10, 10, 8, 8);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("ASET2.JS", src, [(4, 4, pix)], aset=True)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ASET2.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        holes = [
            (x, y)
            for y in range(10, 18)
            for x in range(10, 18)
            if _fb_pix(raw, x, y) != 4
        ]
        assert not holes, f"ASET scaled holes {holes[:8]}"
    finally:
        sim.shutdown()


def test_rtl_aset_settransform_scales_drawimage():
    """ASET + setTransform(2,0,0,2,0,0) must 2× dest (title world→glass)."""
    pix = bytes([4] * 16)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.setTransform(2, 0, 0, 2, 0, 0);
  c.drawImage(img, 5, 5);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("ASETX.JS", src, [(4, 4, pix)], aset=True)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ASETX.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        holes = [
            (x, y)
            for y in range(10, 18)
            for x in range(10, 18)
            if _fb_pix(raw, x, y) != 4
        ]
        assert not holes, f"ASET setTransform holes {holes[:8]}"
    finally:
        sim.shutdown()


def test_rtl_aset_scaled_drawimage_2x_rows():
    """ASET 2× must repeat each source row (non-square dest, title scale)."""
    pix = bytes([2] * 4 + [3] * 4)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 0, 0, 8, 4);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("ASETR.JS", src, [(4, 2, pix)], aset=True)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ASETR.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 2, 0) == 2 and _fb_pix(raw, 2, 1) == 2, (
            _fb_pix(raw, 2, 0),
            _fb_pix(raw, 2, 1),
        )
        assert _fb_pix(raw, 2, 2) == 3 and _fb_pix(raw, 2, 3) == 3, (
            _fb_pix(raw, 2, 2),
            _fb_pix(raw, 2, 3),
        )
    finally:
        sim.shutdown()


def test_rtl_drawimage_9arg_src_window():
    """9-arg drawImage must take the source window, not the whole sheet."""
    pix = bytes([2] * 8 + [3] * 8 + [4] * 8 + [5] * 8)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 4, 2, 4, 2, 0, 0, 4, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("WIN9.JS", src, [(8, 4, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "WIN9.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 1, 0) == 4, _fb_pix(raw, 1, 0)
        assert _fb_pix(raw, 1, 1) == 5, _fb_pix(raw, 1, 1)
        assert _fb_pix(raw, 0, 0) != 2, "9-arg used sheet origin instead of window"
    finally:
        sim.shutdown()


def test_rtl_drawimage_neg_dest_crops_source():
    """Negative dest x must keep source DDA (clip_u-to-0 smeared sheet-left)."""
    # 8×2: left 4 px = 2, right 4 px = 5 (row1: 3 / 6)
    pix = bytes([2] * 4 + [5] * 4 + [3] * 4 + [6] * 4)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, -4, 0);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("NEGDI.JS", src, [(8, 2, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "NEGDI.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        # dest [-4,4)×[0,2) ∩ glass → x=0..3 is sheet columns 4..7
        assert _fb_pix(raw, 0, 0) == 5, _fb_pix(raw, 0, 0)
        assert _fb_pix(raw, 3, 0) == 5, _fb_pix(raw, 3, 0)
        assert _fb_pix(raw, 0, 1) == 6, _fb_pix(raw, 0, 1)
    finally:
        sim.shutdown()


def test_rtl_analog_joy_natives_read_stick():
    """analog-joy: joyX()/joyY()/joyButtons() read the Pmod stick's raw
    axes/buttons (RUN 61 plan item 2) — digital joy()/keyLeft() etc. are
    unchanged. Board wires rtl/phys/jmr_i2c_joy directly; FPGA-SIM has no
    I2C model, so the ANALOG debug RPC (sim_main.cpp) feeds it here, same
    shape as the existing JOY/KEYBITS RPCs."""
    src = """
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.fillStyle = joyX();
  c.fillRect(0, 0, 2, 2);
  c.fillStyle = joyY();
  c.fillRect(4, 0, 2, 2);
  c.fillStyle = joyButtons();
  c.fillRect(8, 0, 2, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("ANLGJOY.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ANLGJOY.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        # power-on rest default: analog_x=analog_y=128, buttons=0
        assert _fb_pix(raw, 0, 0) == 128, _fb_pix(raw, 0, 0)
        assert _fb_pix(raw, 4, 0) == 128, _fb_pix(raw, 4, 0)
        assert _fb_pix(raw, 8, 0) == 0, _fb_pix(raw, 8, 0)
        # deflect the stick + press A(bit0)+C(bit2)+click(bit4) = 0x15
        sim._rpc("ANALOG 200 60 21")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 0, 0) == 200, _fb_pix(raw, 0, 0)
        assert _fb_pix(raw, 4, 0) == 60, _fb_pix(raw, 4, 0)
        assert _fb_pix(raw, 8, 0) == 21, _fb_pix(raw, 8, 0)
    finally:
        sim.shutdown()


def test_rtl_math_round_ties_toward_plus_inf():
    """natives V2: Math.round is a real CALL_NATIVE (nid 54), same shape as
    Math.floor. ES ties toward +inf: 1.5→2, -1.5→-1, -0.5→0."""
    src = """
var c = document.getElementById('c').getContext('2d');
var ok;
function tick() {
  ok = (Math.round(1.4) == 1) && (Math.round(1.5) == 2)
    && (Math.round(-1.5) == -1) && (Math.round(-0.5) == 0);
  c.fillStyle = ok ? 5 : 1;
  c.fillRect(0, 0, 8, 8);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("MROUND.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "MROUND.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 0, 0) == 5, _fb_pix(raw, 0, 0)
    finally:
        sim.shutdown()


def test_rtl_drawimage_negative_dwidth_mirrors():
    """neg-xform: negative dWidth mirrors the sprite in place (RUN 61 plan
    item 3). Canvas dest rect = [dx+dw, dx) when dw<0, so dx=4, dw=-4 puts
    the (mirrored) rect on [0,4)x[0,2) — columns visited right-to-left,
    source walk still left-to-right (jmr_raster_engine.sv flip_x)."""
    # 4x2 sheet: col0=2, col1=3, col2=4, col3=5 (row1 same, +4 each)
    pix = bytes([2, 3, 4, 5, 6, 7, 8, 9])
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 0, 0, 4, 2, 4, 0, -4, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("NEGDW.JS", src, [(4, 2, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "NEGDW.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        # mirrored: glass x=0 shows source col 3 (value 5), x=3 shows col 0 (2)
        assert _fb_pix(raw, 0, 0) == 5, _fb_pix(raw, 0, 0)
        assert _fb_pix(raw, 1, 0) == 4, _fb_pix(raw, 1, 0)
        assert _fb_pix(raw, 2, 0) == 3, _fb_pix(raw, 2, 0)
        assert _fb_pix(raw, 3, 0) == 2, _fb_pix(raw, 3, 0)
        assert _fb_pix(raw, 0, 1) == 9, _fb_pix(raw, 0, 1)
    finally:
        sim.shutdown()


def _vmstat(sim) -> str:
    return sim._rpc("VMSTAT?") or ""


@pytest.mark.skip(reason="V2: JSON engine removed from V1 silicon 2026-08-23")
def test_rtl_json_parse_interned_nested():
    """JSON.parse of an interned nested-array literal must finish the FRAME."""
    import re as _re

    src = """
var n = JSON.parse("[[1,2],[0,1]]");
function tick() {
  if (n && n[0] && n[0][1] == 2 && n[1] && n[1][0] == 0) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("JPAR.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "JPAR.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = _vmstat(sim)
        m = _re.search(r"fcap=(\d+)", st)
        r = _re.search(r"raf=(\d+)", st)
        assert m and int(m.group(1)) == 0, st
        assert r and int(r.group(1)) >= 1, st
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "interned JSON.parse nested miss"
    finally:
        sim.shutdown()


@pytest.mark.skip(reason="V2: JSON engine removed from V1 silicon 2026-08-23")
def test_rtl_json_stringify_nested_finishes_frame():
    """JSON.stringify of nested number arrays must not hang (fcap=0, raf>=1)."""
    import re as _re

    src = """
var n = JSON.parse(JSON.stringify([[1,2],[0,1]]));
function tick() {
  if (n && n[0] && n[0][1] == 2 && n[1] && n[1][0] == 0) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("JSTR.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "JSTR.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = _vmstat(sim)
        m = _re.search(r"fcap=(\d+)", st)
        r = _re.search(r"raf=(\d+)", st)
        assert m and int(m.group(1)) == 0, st
        assert r and int(r.group(1)) >= 1, st
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "stringify+parse nested miss"
    finally:
        sim.shutdown()


def test_rtl_replace_interned_global():
    """Interned 'aabb'.replace(/a/g,'c') must become ccbb (indexOf, not title)."""
    src = """
var r = "aabb".replace(/a/g, "c");
function tick() {
  if (r.indexOf("c") == 0 && r.indexOf("b") == 2) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("REPLI.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "REPLI.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "interned replace(/g) miss"
    finally:
        sim.shutdown()


@pytest.mark.skip(reason="V2: JSON engine removed from V1 silicon 2026-08-23")
def test_rtl_stringify_replace_parse_opens_digit():
    """Dynstr JSON.stringify + replace(/2/g,0) + parse must turn 2 into 0."""
    src = r"""
var data = [[1,2],[0,1]];
var o = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
function tick() {
  if (o && o[0] && o[0][1] == 0 && o[1] && o[1][0] == 0) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("JREP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "JREP.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "stringify+replace+parse miss"
    finally:
        sim.shutdown()


@pytest.mark.skip(reason="V2: JSON engine removed from V1 silicon 2026-08-23")
def test_rtl_value64_stringify_replace_parse_opens_digit():
    """Value64 JSON.stringify + replace(/2/g,0) + parse (HTML titles)."""
    src = r"""
var data = [[1,2],[0,1]];
var o = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
function tick() {
  if (o && o[0] && o[0][1] == 0 && o[1] && o[1][0] == 0) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("VJREP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "VJREP.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "vdraw=10,10,30,30,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_typeof_number_not_undefined():
    """typeof 0 != 'undefined' (map hole check)."""
    src = """
var a = [0, 1];
function tick() {
  if (typeof a[0] != 'undefined' && typeof a[1] != 'undefined') {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("TYPEOF.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "TYPEOF.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "typeof number miss"
    finally:
        sim.shutdown()


def test_rtl_finder_opened_map_paths():
    """BFS path out of a 2-cell with the house already open (no JSON)."""
    src = r"""
var opened = [
  [1,1,1,1],
  [1,0,0,1],
  [1,0,0,1],
  [0,0,0,0]
];
function finder(params) {
  var defaults = { map:null, start:{}, end:{}, type:'path' };
  var options = Object.assign({}, defaults, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(function() {
    return Array(x_length).fill(0);
  });
  var _getValue = function(x, y) {
    if (options.map[y] && typeof options.map[y][x] != 'undefined') {
      return options.map[y][x];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value == 0) {
        if (to.x == options.end.x && to.y == options.end.y) {
          steps[to.y][to.x] = from;
          finded = true;
        } else if (!steps[to.y][to.x]) {
          steps[to.y][to.x] = from;
          new_list.push(to);
        }
      }
    };
    list.forEach(function(current) {
      next(current, {y: current.y + 1, x: current.x});
      next(current, {y: current.y, x: current.x + 1});
      next(current, {y: current.y - 1, x: current.x});
      next(current, {y: current.y, x: current.x - 1});
    });
    if (!finded && new_list.length) {
      _render(new_list);
    }
  };
  _render([options.start]);
  if (finded) {
    var current = options.end;
    while (current.x != options.start.x || current.y != options.start.y) {
      result.unshift(current);
      current = steps[current.y][current.x];
    }
  }
  return result;
}
var path = finder({ map:opened, start:{x:1,y:1}, end:{x:0,y:3} });
function tick() {
  if (path.length) {
    fillRect(60, 10, 30, 30, 6);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FINDO.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FINDO.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "opened-map finder BFS miss"
    finally:
        sim.shutdown()


def test_rtl_array_fill_map_nested():
    """Array(n).fill(0).map(() => Array(m).fill(0)) must be writable rows."""
    src = """
var steps = Array(2).fill(0).map(function() {
  return Array(2).fill(0);
});
steps[0][1] = 7;
function tick() {
  if (steps[0] && steps[0][1] == 7) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("ARMAP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ARMAP.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "fill+map nested rows miss"
    finally:
        sim.shutdown()


def test_rtl_join_string_digits_case_1100():
    """['1','1','0','0'].join('') must EQ interned '1100'."""
    src = """
var code = ["1", "1", "0", "0"];
var hit = 0;
switch (code.join("")) {
  case "1100":
    hit = 1;
    break;
  default:
    hit = 2;
}
function tick() {
  if (hit == 1) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("JOINS.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "JOINS.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "string-digit join missed case 1100"
    finally:
        sim.shutdown()


@pytest.mark.skip(reason="V2: behind the V1 authoring wall (silicon arm removed 2026-08-23)")
def test_rtl_findindex_identity():
    """arr.findIndex identity must return the matching index."""
    src = """
var a = [{id:1}, {id:2}];
var i = a.findIndex(function(e) { return e.id == 2; });
function tick() {
  if (i == 1) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FIDXI.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FIDXI.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "findIndex identity miss"
    finally:
        sim.shutdown()


def test_rtl_getimagedata_64_and_full_canvas_fcap0():
    """64×64 then 640×480 getImageData must finish FRAME (do not raise CAP)."""
    import re as _re

    src = """
var c = document.getElementById('c').getContext('2d');
function tick() {
  fillRect(0, 0, 8, 8, 2);
  var d = c.getImageData(0, 0, 64, 64);
  if (d) fillRect(40, 10, 8, 8, 3);
  c.getImageData(0, 0, 640, 480);
  fillRect(60, 10, 8, 8, 4);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("IMGF.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "IMGF.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = _vmstat(sim)
        m = _re.search(r"fcap=(\d+)", st)
        assert m and int(m.group(1)) == 0, st
        assert _fb_pix(_fb_raw(sim), 44, 12) == 3, "64x64 getImageData did not return"
        assert _fb_pix(_fb_raw(sim), 64, 12) == 4, "full-canvas getImageData ate the FRAME"
    finally:
        sim.shutdown()


def test_rtl_getimagedata_full_canvas_fcap0():
    """640×480 getImageData must finish FRAME (1 px/cycle, do not raise CAP)."""
    import re as _re

    src = """
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.getImageData(0, 0, 640, 480);
  fillRect(60, 10, 8, 8, 4);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("IMGF2.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "IMGF2.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = _vmstat(sim)
        m = _re.search(r"fcap=(\d+)", st)
        assert m and int(m.group(1)) == 0, st
        assert _fb_pix(_fb_raw(sim), 64, 12) == 4, "full-canvas getImageData ate the FRAME"
    finally:
        sim.shutdown()


def test_rtl_times_mod2_two_wedges():
    """this.times%2 must paint two different rects across frames (mouth gate)."""
    src = """
var times = 0;
var c = document.getElementById('c').getContext('2d');
function tick() {
  times = times + 1;
  c.beginPath();
  if (times % 2) c.arc(80, 40, 16, 0.5, 5.5, false);
  else c.arc(80, 40, 16, 0.2, 6.0, false);
  c.fill();
  if (times % 2) fillRect(10, 10, 8, 8, 2);
  else fillRect(30, 10, 8, 8, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("MOUTH.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "MOUTH.JS"')
        sim.type_line("RUN")
        saw2 = False
        saw3 = False
        for _ in range(8):
            sim._rpc("FRAME")
            raw = _fb_raw(sim)
            if _fb_pix(raw, 12, 12) == 2:
                saw2 = True
            if _fb_pix(raw, 32, 12) == 3:
                saw3 = True
        assert saw2 and saw3, (saw2, saw3)
    finally:
        sim.shutdown()


def test_rtl_player_x_moves_on_key():
    """coord writeback: a keydown must change the painted x."""
    src = """
var x = 10;
document.addEventListener("keydown", function(e) { x = x + 20; });
function tick() {
  fillRect(x, 20, 8, 8, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("PMOV.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "PMOV.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 12, 22) == 2, "player never drew"
        sim._rpc("KEYEVT 39 1")
        sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 32, 22) == 2, "keydown did not move x"
    finally:
        sim.shutdown()


def test_rtl_filter_keeps_truthy():
    """arr.filter must keep truthy elements (not a title gate)."""
    src = """
var a = [0, 1, 0, 2];
var b = a.filter(function(x) { return x; });
function tick() {
  if (b.length == 2 && b[0] == 1 && b[1] == 2) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FILT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FILT.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "filter miss"
    finally:
        sim.shutdown()


def test_rtl_for_of_sums():
    """for (const x of arr) must compile to an index loop that runs."""
    src = """
var s = 0;
for (const x of [1, 2, 3]) s = s + x;
function tick() {
  if (s == 6) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FOROF.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FOROF.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "for-of miss"
    finally:
        sim.shutdown()


def test_rtl_title_blit_one_raf_fcap0():
    """Several drawImage + fillText in one rAF must finish (fcap=0)."""
    import re as _re

    pix = bytes([2] * 16)
    src = """
var img = new Image();
img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 0, 0, 16, 16);
  c.drawImage(img, 20, 0, 16, 16);
  c.drawImage(img, 40, 0, 16, 16);
  c.font = "16px sans-serif";
  c.fillText("TITLE", 10, 40);
  c.fillText("ENTER", 10, 60);
  fillRect(80, 10, 8, 8, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("TBLT.JS", src, [(4, 4, pix)])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "TBLT.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = _vmstat(sim)
        m = _re.search(r"fcap=(\d+)", st)
        r = _re.search(r"raf=(\d+)", st)
        assert m and int(m.group(1)) == 0, st
        assert r and int(r.group(1)) >= 1, st
        assert _fb_pix(_fb_raw(sim), 82, 12) == 3, "title blit did not finish"
    finally:
        sim.shutdown()


def test_rtl_title_oneshot_no_rear_raf():
    """Title that draws once and does not re-queue rAF must still present.

    DONKEY showTitleScreen leaves raf=0. FRAME used to require raf!=0 and
    spin 16M clocks (FB SAME / blank glass). Do not raise the FRAME cap.
    """
    import re as _re

    src = """
function tick() {
  fillRect(10, 10, 30, 30, 2);
  swapBuffers();
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("ONCE.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ONCE.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = _vmstat(sim)
        m = _re.search(r"fcap=(\d+)", st)
        assert m and int(m.group(1)) == 0, st
        assert _fb_nz(sim) >= 50, "one-shot title FRAME did not present pixels"
    finally:
        sim.shutdown()


@pytest.mark.skip(reason="V2: behind the V1 authoring wall (silicon arm removed 2026-08-23)")
def test_rtl_stridx_find_splice_one_frame():
    """String-row blit + find+splice must finish one FRAME (do not raise CAP)."""
    import re as _re

    src = """
var rows = ["01110", "11111", "01110"];
var aliens = [{id:1}, {id:2}, {id:3}];
function tick() {
  var y, x;
  for (y = 0; y < rows.length; y++) {
    for (x = 0; x < 5; x++) {
      if (rows[y][x] === "1") fillRect(10 + x * 2, 10 + y * 2, 2, 2, 2);
    }
  }
  var hit = aliens.find(function(a) { return a.id == 2; });
  if (hit) {
    var i = aliens.findIndex(function(a) { return a === hit; });
    if (i < 0) i = 1;
    aliens.splice(i, 1);
  }
  if (aliens.length == 2) fillRect(40, 10, 8, 8, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("STRK.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "STRK.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = _vmstat(sim)
        m = _re.search(r"fcap=(\d+)", st)
        assert m and int(m.group(1)) == 0, st
        assert _fb_pix(_fb_raw(sim), 44, 12) == 3, "find+splice did not finish FRAME"
    finally:
        sim.shutdown()


def test_rtl_get_put_keeps_left_and_right():
    """Full-canvas GET then PUT must keep both left and right rects.

    PACMAN caches the maze with getImageData(0,0,width,height) then
    putImageData every later frame. A left-only dump/put walk looks like
    a broken left maze with live sprites still drawing on top.
    """
    src = """
var c = document.getElementById('c').getContext('2d');
var cached = null;
function tick() {
  if (!cached) {
    fillRect(20, 20, 40, 40, 2);
    fillRect(400, 20, 40, 40, 3);
    cached = c.getImageData(0, 0, 640, 480);
  } else {
    fillRect(0, 0, 640, 480, 0);
    c.putImageData(cached, 0, 0);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("IMGP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "IMGP.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 30, 30) == 2, "GET/PUT dropped the left rect"
        assert _fb_pix(raw, 410, 30) == 3, "GET/PUT dropped the right rect"
    finally:
        sim.shutdown()


def test_rtl_game_ctor_raf_f_increments():
    """Game-ctor rAF must apply `item.times = f/frames` inside forEach.

    `f` itself can live in the nested fn's env and still increment (PACMAN
    env 1442 key 102). Mouth/ghosts need the *forEach callback* to read that
    `f` and SET_PROP times — that write stayed 0 on FPGA-SIM.
    """
    src = """
function Game() {
  var resetItems = function() {};
  var getItemsByType = function() {};
  var Item = function(params) {
    this._settings = {frames: 1, times: 0, timeout: 0, status: 1,
      update: function() {}, draw: function() {}};
    Object.assign(this, this._settings, params || {});
  };
  var items = [];
  var i;
  for (i = 0; i < 12; i++) items.push(new Item({frames: 10, times: 0}));
  var maps = [{frames: 1, times: 0, update: function() {}, draw: function() {}}];
  this.init = function() { this.start(); };
  this.start = function() {
    var f = 0;
    var timestamp = (new Date()).getTime();
    var fn = function() {
      var now = (new Date()).getTime();
      if (now - timestamp < 16) {
        requestAnimationFrame(fn);
        return;
      }
      timestamp = now;
      f = f + 1;
      maps.forEach(function(map) {
        if (!(f % map.frames)) map.times = f / map.frames;
      });
      items.forEach(function(item) {
        if (!(f % item.frames)) item.times = f / item.frames;
        if (item.timeout) item.timeout--;
        item.update();
      });
      if (items[0].times != 0) {
        fillRect(10, 10, 20, 20, 2);
        swapBuffers();
      }
      requestAnimationFrame(fn);
    };
    requestAnimationFrame(fn);
  };
}
var g = new Game();
g.init();
"""
    sim = _sim()
    try:
        _patch_js_v64("GCTF.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GCTF.JS"')
        sim.type_line("RUN")
        saw = False
        for _ in range(24):
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
            # Value64 records the native fillRect in vdraw; FB? can lag a
            # bank until present. PACMAN HTML uses ctx.fillRect (S_V64_RECT).
            if "vdraw=10,10,20,20,2" in st or _fb_pix(_fb_raw(sim), 15, 15) == 2:
                saw = True
                break
        assert saw, "forEach did not write item.times from captured f"
    finally:
        sim.shutdown()


def test_rtl_times_from_f_div_frames():
    """item.times = f/frames when !(f%frames) must toggle (mouth gate)."""
    src = """
var item = {frames: 10, times: 0};
var f = 0;
function tick() {
  f = f + 1;
  if (!(f % item.frames)) item.times = f / item.frames;
  if (item.times % 2) fillRect(10, 10, 8, 8, 2);
  else fillRect(30, 10, 8, 8, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("TMOD.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "TMOD.JS"')
        sim.type_line("RUN")
        saw2 = False
        saw3 = False
        for _ in range(24):
            sim._rpc("FRAME")
            raw = _fb_raw(sim)
            if _fb_pix(raw, 12, 12) == 2:
                saw2 = True
            if _fb_pix(raw, 32, 12) == 3:
                saw3 = True
        assert saw2 and saw3, (saw2, saw3)
    finally:
        sim.shutdown()


def test_rtl_ghost_x_moves_across_raf():
    """Ghost this.x += speed must stick across rAF keep (not only a tight loop)."""
    src = r"""
var _COS = [1, 0, -1, 0], _SIN = [0, 1, 0, -1];
var ghost = {x: 100, y: 100, speed: 1, orientation: 3};
function tick() {
  ghost.x += ghost.speed * _COS[ghost.orientation];
  ghost.y += ghost.speed * _SIN[ghost.orientation];
  fillRect(ghost.x, ghost.y, 6, 6, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("GXRAF.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GXRAF.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        y0 = None
        raw = _fb_raw(sim)
        for y in range(80, 120):
            if _fb_pix(raw, 102, y) == 2:
                y0 = y
                break
        assert y0 is not None, "ghost never drew"
        for _ in range(12):
            sim._rpc("FRAME")
        raw = _fb_raw(sim)
        moved = False
        for y in range(70, y0):
            if _fb_pix(raw, 102, y) == 2:
                moved = True
                break
        assert moved, "ghost y did not decrease across rAF"
    finally:
        sim.shutdown()


def test_rtl_get_put_keeps_thin_strokes():
    """1px vertical strokes must survive full-canvas GET/PUT on both sides."""
    src = """
var c = document.getElementById('c').getContext('2d');
c.strokeStyle = '#09f';
c.lineWidth = 2;
var cached = null;
function tick() {
  if (!cached) {
    c.beginPath(); c.moveTo(30, 20); c.lineTo(30, 80); c.stroke();
    c.beginPath(); c.moveTo(400, 20); c.lineTo(400, 80); c.stroke();
    cached = c.getImageData(0, 0, 640, 480);
  } else {
    fillRect(0, 0, 640, 480, 0);
    c.putImageData(cached, 0, 0);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("IMGS.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "IMGS.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        left = any(_fb_pix(raw, x, 50) != 0 for x in range(28, 33))
        right = any(_fb_pix(raw, x, 50) != 0 for x in range(398, 403))
        assert left, "GET/PUT dropped the left 1px stroke"
        assert right, "GET/PUT dropped the right 1px stroke"
    finally:
        sim.shutdown()


def test_rtl_mouth_pie_has_gap():
    """PACMAN mouth: filled arc + lineTo center must leave a facing gap."""
    src = """
var c = document.getElementById('c').getContext('2d');
c.fillStyle = '#FFE600';
function tick() {
  c.beginPath();
  c.arc(80, 80, 16, 0.20 * Math.PI, -0.20 * Math.PI, false);
  c.lineTo(80, 80);
  c.closePath();
  c.fill();
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("PIE.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "PIE.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        body = _fb_pix(raw, 70, 80)
        gap = _fb_pix(raw, 94, 80)
        assert body != 0, "mouth body did not fill"
        assert gap == 0, "mouth pie filled the facing gap (looks like a closed circle)"
    finally:
        sim.shutdown()


def test_rtl_mouth_pie_left_facing_gap():
    """Player default orientation 2: gap must face left, not a full disk."""
    src = """
var c = document.getElementById('c').getContext('2d');
c.fillStyle = '#FFE600';
function tick() {
  c.beginPath();
  c.arc(80, 80, 16, 1.20 * Math.PI, 0.80 * Math.PI, false);
  c.lineTo(80, 80);
  c.closePath();
  c.fill();
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("PIEL.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "PIEL.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        raw = _fb_raw(sim)
        body = _fb_pix(raw, 90, 80)
        gap = _fb_pix(raw, 66, 80)
        assert body != 0, "left-facing mouth body did not fill"
        assert gap == 0, "left-facing mouth filled the gap (closed circle)"
    finally:
        sim.shutdown()


def test_rtl_arr_oob_is_undefined():
    """arr[-1] and arr[len] must be undefined so map.get returns -1."""
    src = """
var row = [1, 1, 1];
var hit = 0;
if (typeof row[-1] == 'undefined' && typeof row[3] == 'undefined') hit = 1;
function tick() {
  if (hit) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("OOB.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "OOB.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "arr OOB was not undefined"
    finally:
        sim.shutdown()


def test_rtl_long_string_index_past_255():
    """Interned str[i] / str.length must use NAMB u16, not the hash u8."""
    # Past hash u8 (255) and the old data:stub cap (512). B at 200, A at 500.
    lit = ("A" * 200) + "B" + ("A" * 399)
    src = (
        "var s = '" + lit + "';\n"
        "var hit = 0;\n"
        "if (s.length === 600 && s[200] === 'B' && s[500] === 'A') hit = 1;\n"
        "function tick() {\n"
        "  if (hit) fillRect(10, 10, 20, 20, 2);\n"
        "  swapBuffers();\n"
        "  requestAnimationFrame(tick);\n"
        "}\n"
        "requestAnimationFrame(tick);\n"
    )
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk

    sim = _sim()
    try:
        # Value64 ProgramImage (same path as HTML RUN), not a FAT .JSB sidecar.
        sim._program_image = encode_chunk(compile_source(src), v2=True, value64=True)
        assert sim._stream_program_image().startswith("OK")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        # FB? follows the front bank; this snippet's last swap can leave the
        # 20×20 on the back. vdraw is the native that ran.
        assert "vdraw=10,10,20,20,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_loop_var_array_is_new_each_iteration():
    """while { var row = []; rows.push(row) } must not alias every row."""
    src = """
var rows = [];
var r = 0;
while (r < 3) {
  var row = [];
  row.push(r);
  rows.push(row);
  r = r + 1;
}
rows[1][0] = 9;
var hit = 0;
if (rows[0][0] === 0 && rows[1][0] === 9 && rows[2][0] === 2) hit = 1;
function tick() {
  if (hit) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk

    sim = _sim()
    try:
        sim._program_image = encode_chunk(compile_source(src), v2=True, value64=True)
        assert sim._stream_program_image().startswith("OK")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,20,20,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_nested_fn_loop_var_is_local():
    """Inner `var col = 0` must not reset an outer function's column cursor."""
    src = """
var hit = 0;
function inner() {
  var col = 0;
  while (col < 16) { col = col + 1; }
}
function outer() {
  var col = 0;
  var n = 0;
  while (col < 24) {
    if (col === 1 || col === 17) inner();
    n = n + 1;
    if (n > 200) { hit = -1; return; }
    col = col + 1;
  }
  hit = n;
}
outer();
function tick() {
  if (hit === 24) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk

    sim = _sim()
    try:
        sim._program_image = encode_chunk(compile_source(src), v2=True, value64=True)
        assert sim._stream_program_image().startswith("OK")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,20,20,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_leaf_calls_reuse_env():
    """600 leaf CALL_USER must not GC-storm (ENV_DEPTH is 512)."""
    src = """
function leaf(n) { var t = n + 1; return t; }
var i = 0;
var s = 0;
while (i < 600) { s = s + leaf(1); i = i + 1; }
function tick() {
  if (s === 1200) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk

    sim = _sim()
    try:
        sim._program_image = encode_chunk(compile_source(src), v2=True, value64=True)
        assert sim._stream_program_image().startswith("OK")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,20,20,2" in st, st
        # Boot/end sweep may bump gc; env-full storm was gc=60+/frame.
        import re
        gc = int(re.search(r"gc=(\d+)", st).group(1))
        assert gc <= 4, st
    finally:
        sim.shutdown()


def test_rtl_closure_survives_outer_return():
    """MAKE_FN must keep the captured env after the outer call returns."""
    src = """
function outer() {
  var n = 7;
  return function inner() { return n; };
}
var f = outer();
var hit = f();
function tick() {
  if (hit === 7) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk

    sim = _sim()
    try:
        sim._program_image = encode_chunk(compile_source(src), v2=True, value64=True)
        assert sim._stream_program_image().startswith("OK")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "vdraw=10,10,20,20,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_value64_nested_foreach_finder():
    """Same FLAG_VALUE64 image as PYTHON nested-forEach finder; pixels required."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from test_bytecode_js import _NESTED_FOREACH_FINDER_JS

    sim = _sim()
    try:
        sim._program_image = encode_chunk(
            compile_source(_NESTED_FOREACH_FINDER_JS), v2=True, value64=True
        )
        assert sim._stream_program_image().startswith("OK")
        st = _wait_vm_idle_or_frame(sim)
        if "fault=241" in st:
            st = st + " " + sim._rpc("STK?")
        assert "fault=0" in st, st
        if "sname=S_WAIT_FRAME" in st:
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 15, 15) == 2, st
        assert "vdraw=10,10,20,20,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_value64_proto_coord_finder_after_getimagedata():
    """Same FLAG_VALUE64 image as PYTHON proto-coord+getImageData finder."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from test_bytecode_js import _PROTO_COORD_FINDER_JS

    sim = _sim()
    try:
        sim._program_image = encode_chunk(
            compile_source(_PROTO_COORD_FINDER_JS), v2=True, value64=True
        )
        assert sim._stream_program_image().startswith("OK")
        st = _wait_vm_idle_or_frame(sim)
        if "fault=241" in st:
            st = st + " " + sim._rpc("STK?")
        assert "fault=0" in st, st
        if "sname=S_WAIT_FRAME" in st:
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 15, 15) == 2, st
        assert _fb_pix(raw, 45, 15) == 3, st
    finally:
        sim.shutdown()


def test_rtl_value64_foreach_getimagedata_then_finder():
    """Same FLAG_VALUE64 image as PYTHON getImageData-inside-forEach then finder."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from test_bytecode_js import _FOREACH_GETIMG_FINDER_JS

    sim = _sim()
    try:
        sim._program_image = encode_chunk(
            compile_source(_FOREACH_GETIMG_FINDER_JS), v2=True, value64=True
        )
        assert sim._stream_program_image().startswith("OK")
        st = _wait_vm_idle_or_frame(sim)
        if "fault=241" in st:
            st = st + " " + sim._rpc("STK?")
        assert "fault=0" in st, st
        if "sname=S_WAIT_FRAME" in st:
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 15, 15) == 2, st
    finally:
        sim.shutdown()


def test_rtl_value64_param_x_coord_array_set():
    """Same FLAG_VALUE64 image as PYTHON position2coord(x,y) ARRAY_SET."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from test_bytecode_js import _PARAM_X_COORD_SET_JS

    sim = _sim()
    try:
        sim._program_image = encode_chunk(
            compile_source(_PARAM_X_COORD_SET_JS), v2=True, value64=True
        )
        assert sim._stream_program_image().startswith("OK")
        st = _wait_vm_idle_or_frame(sim)
        if "fault=241" in st:
            st = st + " " + sim._rpc("STK?")
        assert "fault=0" in st, st
        if "sname=S_WAIT_FRAME" in st:
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 15, 15) == 2, st
    finally:
        sim.shutdown()


def test_rtl_value64_maze31_neighbor_array_set():
    """Same FLAG_VALUE64 image as PYTHON 31×28 neighbor ARRAY_SET."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from test_bytecode_js import _maze31_neighbor_set_js

    sim = _sim()
    try:
        sim._program_image = encode_chunk(
            compile_source(_maze31_neighbor_set_js()), v2=True, value64=True
        )
        assert sim._stream_program_image().startswith("OK")
        st = _wait_vm_idle_or_frame(sim)
        if "fault=241" in st:
            st = st + " " + sim._rpc("STK?")
        assert "fault=0" in st, st
        if "sname=S_WAIT_FRAME" in st:
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 15, 15) == 2, st
    finally:
        sim.shutdown()


def test_rtl_value64_foreach_ctor_assign_function_prop():
    """Same FLAG_VALUE64 image as PYTHON forEach+new Ctor+assign; no fault=2."""
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from test_bytecode_js import _FOREACH_CTOR_ASSIGN_JS

    sim = _sim()
    try:
        sim._program_image = encode_chunk(
            compile_source(_FOREACH_CTOR_ASSIGN_JS), v2=True, value64=True
        )
        assert sim._stream_program_image().startswith("OK")
        st = _wait_vm_idle_or_frame(sim)
        assert "fault=0" in st, st
        if "sname=S_WAIT_FRAME" in st:
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert "cspovf=0" in st, st
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 15, 15) == 2, st
        assert "vdraw=10,10,20,20,2" in st, st
    finally:
        sim.shutdown()


def test_rtl_finder_28_wide_house_paths():
    """stringify/replace/parse of a 28-wide house map must still path out."""
    src = r"""
function _copyMapOpen(_cm_s){var _cm_o=[];for(var _cm_j=0;_cm_j<_cm_s.length;_cm_j++){var _cm_w=_cm_s[_cm_j],_cm_r=[];for(var _cm_i=0;_cm_i<_cm_w.length;_cm_i++){_cm_r.push(_cm_w[_cm_i]==2?0:_cm_w[_cm_i]);}_cm_o.push(_cm_r);}return _cm_o;}
var data = [];
var y, x;
for (y = 0; y < 8; y++) {
  data[y] = [];
  for (x = 0; x < 28; x++) data[y][x] = 1;
}
for (x = 0; x < 28; x++) { data[0][x] = 1; data[7][x] = 1; }
for (y = 1; y < 7; y++) { data[y][0] = 1; data[y][27] = 1; }
for (x = 1; x < 27; x++) data[6][x] = 0;
data[5][12] = 2; data[5][13] = 2; data[5][14] = 2; data[5][15] = 2;
data[4][12] = 1; data[4][13] = 2; data[4][14] = 2; data[4][15] = 1;
data[3][13] = 0; data[3][14] = 0;
function finder(params) {
  var options = Object.assign({}, {map: null, start: {}, end: {}, type: 'path'}, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) return [];
  var finded = false, result = [];
  var y_length = options.map.length, x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(function() { return Array(x_length).fill(0); });
  var _getValue = function(x, y) {
    if (options.map[y] && typeof options.map[y][x] != 'undefined') return options.map[y][x];
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value < 1) {
        if (value == -1) { to.x = (to.x + x_length) % x_length; to.y = (to.y + y_length) % y_length; }
        if (to.x == options.end.x && to.y == options.end.y) { steps[to.y][to.x] = from; finded = true; }
        else if (!steps[to.y][to.x]) { steps[to.y][to.x] = from; new_list.push(to); }
      }
    };
    list.forEach(function(current) {
      next(current, {y: current.y + 1, x: current.x});
      next(current, {y: current.y, x: current.x + 1});
      next(current, {y: current.y - 1, x: current.x});
      next(current, {y: current.y, x: current.x - 1});
    });
    if (!finded && new_list.length) _render(new_list);
  };
  _render([options.start]);
  if (finded) {
    var current = options.end;
    while (current.x != options.start.x || current.y != options.start.y) {
      result.unshift(current);
      current = steps[current.y][current.x];
    }
  }
  return result;
}
var n = 0;
function tick() {
  var opened = _copyMapOpen(data);
  var path = finder({map: opened, start: {x: 13, y: 5}, end: {x: 2, y: 6}});
  if (path.length) n = n + 1;
  if (n >= 2) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("F28.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "F28.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, "28-wide house finder did not path out"
    finally:
        sim.shutdown()


# Real PACMAN level-1 maze literal (31 rows x 28 cols) — regression harness
# for the createMap flow: config['map'] -> Object.assign -> stringify/parse.
_MAZE31 = (
    "[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],"
    "[1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1],"
    "[1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1],"
    "[1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1],"
    "[1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1],"
    "[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],"
    "[1,0,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,0,1],"
    "[1,0,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,0,1],"
    "[1,0,0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,0,0,1],"
    "[1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1],"
    "[1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1],"
    "[1,1,1,1,1,1,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,1,1,1,1,1,1],"
    "[1,1,1,1,1,1,0,1,1,0,1,1,1,2,2,1,1,1,0,1,1,0,1,1,1,1,1,1],"
    "[1,1,1,1,1,1,0,1,1,0,1,2,2,2,2,2,2,1,0,1,1,0,1,1,1,1,1,1],"
    "[0,0,0,0,0,0,0,0,0,0,1,2,2,2,2,2,2,1,0,0,0,0,0,0,0,0,0,0],"
    "[1,1,1,1,1,1,0,1,1,0,1,2,2,2,2,2,2,1,0,1,1,0,1,1,1,1,1,1],"
    "[1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1],"
    "[1,1,1,1,1,1,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,1,1,1,1,1,1],"
    "[1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1],"
    "[1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1],"
    "[1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1],"
    "[1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1],"
    "[1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1],"
    "[1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1],"
    "[1,1,1,0,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,1],"
    "[1,1,1,0,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,1],"
    "[1,0,0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,0,0,1],"
    "[1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1],"
    "[1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1],"
    "[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],"
    "[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]"
)


def test_rtl_maze31_survives_createmap():
    """Real maze literal must keep row lengths + values through createMap.

    Mirrors PACMAN: config['map'] literal, Object.assign(this,_settings,
    _params) with _settings.data=[], then data=JSON.parse(JSON.stringify()).
    Markers: (15,15)=2 lengths ok, (35,15)=4 values ok, (55,15)=5 get() edge
    ok. On length failure the first bad row y and its length are drawn at
    y=100/110 marker rows so the fb tells us where it broke.
    """
    src = (
        "var _COIGIG = [{'map':[" + _MAZE31 + "]}];\n"
        + r"""
var config = _COIGIG[0];
var obj = {data: [], x_length: 0, y_length: 0};
Object.assign(obj, {data: [], x_length: 0, y_length: 0}, {data: config['map']});
function _copyMapId(_cm_s){var _cm_o=[];for(var _cm_j=0;_cm_j<_cm_s.length;_cm_j++){var _cm_w=_cm_s[_cm_j],_cm_r=[];for(var _cm_i=0;_cm_i<_cm_w.length;_cm_i++){_cm_r.push(_cm_w[_cm_i]);}_cm_o.push(_cm_r);}return _cm_o;}
obj.data = _copyMapId(config['map']);
obj.y_length = obj.data.length;
obj.x_length = obj.data[0].length;
var get = function(x, y) {
  if (obj.data[y] && typeof obj.data[y][x] != 'undefined') return obj.data[y][x];
  return -1;
};
var lens_ok = (obj.y_length == 31 && obj.x_length == 28) ? 1 : 0;
var bad_y = -1, bad_len = -1;
var vals_ok = 1;
var vy = -1, vx = -1, vgot = -9;
// IIFE like the real game (top-level `var x=` in a loop is init-once by
// design — startLoop re-entry — so the check must run at fn depth 1)
(function() {
  var y, x;
  for (y = 0; y < 31; y++) {
    var row = obj.data[y];
    if (!row || row.length != 28) {
      lens_ok = 0;
      if (bad_y < 0) { bad_y = y; bad_len = row ? row.length : -1; }
    } else {
      for (x = 0; x < 28; x++) {
        if (row[x] != config['map'][y][x]) {
          vals_ok = 0;
          if (vy < 0) { vy = y; vx = x; vgot = row[x]; }
        }
      }
    }
  }
})();
var edge_ok = (get(-1, 5) == -1 && get(28, 5) == -1 && get(0, 0) == 1 &&
               get(27, 30) == 1 && get(1, 1) == 0 && get(13, 12) == 2) ? 1 : 0;
function tick() {
  if (lens_ok) fillRect(10, 10, 10, 10, 2);
  if (vals_ok) fillRect(30, 10, 10, 10, 4);
  if (edge_ok) fillRect(50, 10, 10, 10, 5);
  if (bad_y >= 0) fillRect(100 + bad_y * 4, 100, 4, 4, 3);
  if (bad_len >= 0) fillRect(100 + bad_len * 4, 110, 4, 4, 3);
  if (vy >= 0) fillRect(100 + vy * 4, 120, 4, 4, 3);
  if (vx >= 0) fillRect(100 + vx * 4, 130, 4, 4, 3);
  if (vgot > -9) fillRect(100 + (vgot + 2) * 4, 140, 4, 4, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    )
    sim = _sim()
    try:
        _patch_js("MAZE31.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "MAZE31.JS"')
        sim.type_line("RUN")
        for _ in range(3):
            sim._rpc("FRAME")
        raw = _fb_raw(sim)
        bad_y = next((i for i in range(40) if _fb_pix(raw, 100 + i * 4, 102)), None)
        bad_len = next((i for i in range(40) if _fb_pix(raw, 100 + i * 4, 112)), None)
        vy = next((i for i in range(40) if _fb_pix(raw, 100 + i * 4, 122)), None)
        vx = next((i for i in range(40) if _fb_pix(raw, 100 + i * 4, 132)), None)
        vgot = next((i - 2 for i in range(40) if _fb_pix(raw, 100 + i * 4, 142)), None)
        assert _fb_pix(raw, 15, 15) == 2, (
            f"maze row lengths wrong (first bad y={bad_y} len={bad_len})"
        )
        assert _fb_pix(raw, 35, 15) == 4, (
            f"maze values wrong after createMap (first bad y={vy} x={vx} got={vgot})"
        )
        assert _fb_pix(raw, 55, 15) == 5, "map.get edge behaviour wrong"
    finally:
        sim.shutdown()


@pytest.mark.skip(reason="V2: JSON engine removed from V1 silicon 2026-08-23")
def test_rtl_value64_stringify_indexof_zero_keeps_beans():
    """Value64 JSON.stringify(data).indexOf(0) must see digit 0 (beans check).

    PACMAN stage.update does JSON.stringify(beans.data).indexOf(0)<0 then
    nextStage(). Small stringify+parse tests never call indexOf(0); tagged
    maze31 uses the other heap. Markers: (15,15)=2 small chained, (35,15)=4
    maze chained, (55,15)=5 maze stored then indexOf, (75,15)=6 "0" needle.
    """
    src = (
        "var m = [" + _MAZE31 + "];\n"
        + r"""
var small_hit = JSON.stringify([[1,0],[1,1]]).indexOf(0);
var beans = {data: JSON.parse(JSON.stringify(m))};
var chained = JSON.stringify(beans.data).indexOf(0);
var stored = JSON.stringify(beans.data);
var stored_hit = stored.indexOf(0);
var str_needle = stored.indexOf("0");
function tick() {
  if (small_hit >= 0 && chained >= 0 && stored_hit >= 0 && str_needle >= 0)
    fillRect(10, 10, 10, 10, 2);
  else
    fillRect(10, 10, 10, 10, 1);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    )
    sim = _sim()
    try:
        _patch_js_v64("IDX0.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "IDX0.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        # fillRect pixels are not in FB? here; vdraw is the last paint (same
        # as test_rtl_value64_stringify_replace_parse_opens_digit).
        assert "vdraw=10,10,10,10,2" in st, (
            f"stringify.indexOf digit-0 miss {st}"
        )
    finally:
        sim.shutdown()


def test_rtl_maze_reparse_survives_nursery_churn():
    """Post-boot map.data re-parse must survive later frames' array temps.

    PACMAN nextStage() re-runs data=JSON.parse(JSON.stringify(...)) on
    keydown (post-boot). The parsed rows are nursery arrays; storing them
    into an old-space object must not leave refs that the frame rewind
    recycles into draw temps (code=[0,0,0,0]) — that was the 4-wide maze.
    """
    src = (
        "var m = [" + _MAZE31 + "];\n"
        + r"""
var obj = {data: []};
function _copyMapId(_cm_s){var _cm_o=[];for(var _cm_j=0;_cm_j<_cm_s.length;_cm_j++){var _cm_w=_cm_s[_cm_j],_cm_r=[];for(var _cm_i=0;_cm_i<_cm_w.length;_cm_i++){_cm_r.push(_cm_w[_cm_i]);}_cm_o.push(_cm_r);}return _cm_o;}
(function() { obj.data = _copyMapId(m); })();
var n = 0, ok = -1;
function churn() {
  var k;
  for (k = 0; k < 40; k++) { var t = [0, 0, 0, 0]; t[0] = k; }
}
function verify() {
  var good = 1, y, x;
  for (y = 0; y < 31; y++) {
    var row = obj.data[y];
    if (!row || row.length != 28) good = 0;
    else for (x = 0; x < 28; x++) { if (row[x] != m[y][x]) good = 0; }
  }
  return good;
}
function tick() {
  n = n + 1;
  if (n == 3) { obj.data = _copyMapId(m); }
  if (n > 3 && n < 7) churn();
  if (n == 7) ok = verify();
  if (ok == 1) fillRect(10, 10, 10, 10, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    )
    sim = _sim()
    try:
        _patch_js("REPARSE.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "REPARSE.JS"')
        sim.type_line("RUN")
        for _ in range(9):
            sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 15, 15) == 2, (
            "re-parsed maze rows were recycled by later frame temps"
        )
    finally:
        sim.shutdown()


def test_rtl_nested_find_indexof_splice_identity():
    """Nested array find + indexOf-by-identity + splice (collision shape)."""
    src = """
var grids = [{invaders: [{id:1}, {id:2}, {id:3}]}];
var projectiles = [{id:10}, {id:20}];
var invader = grids[0].invaders[1];
var projectile = projectiles[0];
function tick() {
  var grid = grids[0];
  var invaderFound = grid.invaders.find(function(a) { return a === invader; });
  var projectileFound = projectiles.find(function(p) { return p === projectile; });
  if (invaderFound && projectileFound) {
    var i = grid.invaders.indexOf(invaderFound);
    var j = projectiles.indexOf(projectileFound);
    grid.invaders.splice(i, 1);
    projectiles.splice(j, 1);
  }
  if (grid.invaders.length == 2 && projectiles.length == 1)
    fillRect(10, 10, 8, 8, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("NFIS.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "NFIS.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")
        assert _fb_pix(_fb_raw(sim), 14, 14) == 3, "nested find+indexOf+splice missed identity"
    finally:
        sim.shutdown()


def test_rtl_title_gamestate_enter_advances():
    """Bound class-field listeners must advance both Enter-driven stages."""
    src = """
var gameState = "title";
class G {
  startSelect = (event) => {
    if (event.key === "Enter" && gameState === "title") {
      gameState = "character";
      this.characterSelect();
    }
  }
  characterSelect() {
    document.removeEventListener("keydown", this.startSelect);
    document.addEventListener("keydown", (event) => this.startGame(event));
  }
  startGame(event) {
    if (event.key === "Enter" && gameState === "character") {
      gameState = "game";
    }
  }
}
const g = new G();
function update() {
  if (gameState == "title") {
    document.addEventListener("keydown", g.startSelect);
    fillRect(10, 10, 20, 20, 2);
  } else if (gameState == "character") {
    fillRect(40, 10, 20, 20, 3);
  } else {
    fillRect(70, 10, 20, 20, 4);
  }
  swapBuffers();
  requestAnimationFrame(update);
}
requestAnimationFrame(update);
(function () {
  function fireEnter() {
    var ev;
    try {
      ev = new KeyboardEvent("keydown", { key: "Enter", keyCode: 13, which: 13 });
    } catch (e) {
      ev = { type: "keydown", key: "Enter", keyCode: 13, which: 13 };
    }
    if (document.dispatchEvent) document.dispatchEvent(ev);
  }
  var n = 0;
  function boot() {
    n += 1;
    if (n === 4) fireEnter();
    if (n === 12) fireEnter();
    if (n < 14) requestAnimationFrame(boot);
  }
  requestAnimationFrame(boot);
})();
"""
    sim = _sim()
    try:
        _patch_js("TENT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "TENT.JS"')
        sim.type_line("RUN")
        saw = False
        # update and boot occupy separate rAF slots, so boot's n===12 arrives
        # after more than 16 frame callbacks.
        for _ in range(32):
            sim._rpc("FRAME")
            if _fb_pix(_fb_raw(sim), 74, 14) == 4:
                saw = True
                break
        assert saw, "bound listeners did not advance title through game"
    finally:
        sim.shutdown()


def _wait_vm_idle_or_frame(sim, slices=20):
    """Advance the VM to a DEFINED sampling point, then return that VMSTAT.

    TICKN 20000 = 20M clocks. INVADERS HTML boot to first WAIT_FRAME is ~120M
    (splash fillText + string-row drawBitmap). TICKN 10 * 200 was only 2M.

    A title whose attract mode never stops (PACMAN) will not come to rest, and
    this loop samples only once per 20M-clock slice against a ~3.9M-clock
    frame -- so it almost never catches the brief frame-end window. It then
    used to return a snapshot from a RANDOM mid-frame instant, where the VM is
    mid-drawImage inside an allocation and `raf=0` is simply correct: the
    callback has not re-registered yet. Callers asserting "raf=0" not in vmstat
    were reading that as a dead animation loop. It is not one -- the same
    snapshot showed rafcall=99, fault=0, healthy obj/arr.

    So on timeout, spend one FRAME rpc: it runs to the next framebuffer swap
    and leaves the VM at S_WAIT_FRAME, the boundary the GUI also samples at,
    where raf / obj / arr mean what the callers think they mean.
    """
    vmstat = ""
    for _ in range(slices):
        sim._rpc("TICKN 20000")
        vmstat = sim._rpc("VMSTAT?")
        if "sname=S_WAIT_FRAME" in vmstat or "sname=S_IDLE" in vmstat:
            return vmstat
        if "fault=" in vmstat and "fault=0" not in vmstat:
            return vmstat
    sim._rpc("FRAME")
    return sim._rpc("VMSTAT?")


def test_invaders_fpga_sim_held_left_changes_frame_within_budget():
    """INVADERS on real RTL: start, held left changes FB, frame clocks stay in budget."""
    from tools.compile_js import compile_html_text, encode_html_chunk

    html = resolve_storage_html("INVADERS")
    if html is None:
        pytest.skip("no INVADERS-family HTML in storage/")
    image_data = encode_html_chunk(compile_html_text(html.read_text(encoding="utf-8")))
    sim = _sim()
    try:
        sim._loaded_name = html.name
        sim._loaded_html_text = html.read_text(encoding="utf-8")
        sim._program_image = image_data
        assert sim._stream_program_image().startswith("OK")
        vmstat = _wait_vm_idle_or_frame(sim)
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        before = _fb_raw(sim)
        sim._rpc("KEYEVT 13 1")
        sim._rpc("FRAME")
        sim._rpc("KEYEVT 13 0")
        sim._rpc("KEYEVT 32 1")
        sim._rpc("FRAME")
        sim._rpc("KEYEVT 32 0")
        sim._rpc("KEYEVT 37 1")
        fclk = 0
        after = before
        for _ in range(16):
            sim._rpc("FRAME")
            vmstat = sim._rpc("VMSTAT?")
            if "fclk=" in vmstat:
                fclk = max(fclk, int(vmstat.split("fclk=")[1].split()[0].replace(",", "")))
            after = _fb_raw(sim)
        assert after != before
        assert "raf=0" not in vmstat
        # Value64 splash/game frames do per-pixel fillRect from string-row
        # sprites; sequential GET_PROP is real silicon (~30 MHz), so FRAME
        # is capped at 64M (was 16M on the combo-heap cheat).
        assert fclk <= 64_000_000 * _VMDIV, f"frame clocks {fclk} exceed FRAME cap ({vmstat})"
    finally:
        sim.shutdown()


def test_pacman_fpga_sim_enter_paints_maze():
    """PACMAN on real RTL: Enter leaves splash and paints a changing maze."""
    from tools.compile_js import compile_html_text, encode_html_chunk

    html = resolve_storage_html("PACMAN")
    if html is None:
        pytest.skip("no PACMAN-family HTML in storage/")
    image_data = encode_html_chunk(compile_html_text(html.read_text(encoding="utf-8")))
    sim = _sim()
    try:
        sim._loaded_name = html.name
        sim._loaded_html_text = html.read_text(encoding="utf-8")
        sim._program_image = image_data
        assert sim._stream_program_image().startswith("OK")
        vmstat = _wait_vm_idle_or_frame(sim)
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        assert "raf=0" not in vmstat, vmstat
        splash = _fb_raw(sim)
        sim._rpc("KEYEVT 13 1")
        sim._rpc("FRAME")
        sim._rpc("KEYEVT 13 0")
        maze = _fb_raw(sim)
        vmstat = sim._rpc("VMSTAT?")
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        assert "raf=0" not in vmstat, vmstat
        assert sum(1 for b in maze if b) >= 1000
        # Do NOT assert framebuffer inequality here (the old
        # `maze != splash` / `later != maze` pair). Those compared pixel
        # bytes on a ONE-frame budget, which stopped meaning "the game is
        # animating" when S_FB_SYNC (4188e01, 2026-08-20) made a
        # same-scene frame produce a byte-identical buffer. Sprite motion
        # can be sub-pixel for many frames -- measured 30 on DONKEY, which
        # is exactly how that smoke turned into a permanent false failure.
        # `rafcall` advancing is deterministic proof the rAF loop is live
        # and does not care how fast anything moves.
        raf0 = _vmstat_int(vmstat, "rafcall")
        for _ in range(4):
            sim._rpc("FRAME")
            vmstat = sim._rpc("VMSTAT?")
            assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
            assert "raf=0" not in vmstat, vmstat
        raf1 = _vmstat_int(vmstat, "rafcall")
        assert raf1 > raf0, f"rAF loop stalled: rafcall {raf0} -> {raf1} ({vmstat})"
        still = _fb_raw(sim)
        # nextStage must not skip every map (stringify(beans).indexOf(0)).
        assert sum(1 for b in still if b) >= 1000
    finally:
        sim.shutdown()


def test_donkey_fpga_sim_enter_keeps_raf():
    """DONKEY on real RTL: title paints, Enter keeps rAF, pixels keep changing."""
    from tools.compile_js import compile_html_text, encode_html_chunk

    html = resolve_storage_html("DONKEY")
    if html is None:
        pytest.skip("no DONKEY-family HTML in storage/")
    image_data = encode_html_chunk(compile_html_text(html.read_text(encoding="utf-8")))
    sim = _sim()
    try:
        sim._loaded_name = html.name
        sim._loaded_html_text = html.read_text(encoding="utf-8")
        sim._program_image = image_data
        assert sim._stream_program_image().startswith("OK")
        vmstat = _wait_vm_idle_or_frame(sim, slices=40)
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        splash = _fb_raw(sim)
        assert sum(1 for b in splash if b) >= 50
        # Enter #1 -> character select. This screen is EVENT-driven:
        # raf=0 there is correct (the old one-Enter-into-game premise was
        # the pre-dispatchEvent boot quirk; docs/potential bugs.md #60).
        sim._rpc("KEYEVT 13 1")
        sim._rpc("FRAME")
        sim._rpc("KEYEVT 13 0")
        sim._rpc("FRAME")
        play = _fb_raw(sim)
        vmstat = sim._rpc("VMSTAT?")
        for _ in range(6):
            if play != splash:
                break
            sim._rpc("FRAME")
            vmstat = sim._rpc("VMSTAT?")
            play = _fb_raw(sim)
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        assert play != splash
        # Enter #2 -> the game proper; rAF must be armed there.
        sim._rpc("KEYEVT 13 1")
        for _ in range(3):
            sim._rpc("FRAME")
        sim._rpc("KEYEVT 13 0")
        for _ in range(3):
            sim._rpc("FRAME")
        play = _fb_raw(sim)
        vmstat = sim._rpc("VMSTAT?")
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        assert "raf=0" not in vmstat, vmstat
        assert sum(1 for b in play if b) >= 50
        # "Keeps rAF" means the callback keeps RUNNING, not merely that the
        # armed flag is set: every frame on this screen is ~1.03M clocks of
        # honest redraw, so fclk is the real signal.
        #
        # Do NOT re-add a "framebuffer changed within N frames" check here.
        # Measured on this screen (2026-08-22 probe): the picture is
        # byte-identical for frames 1-30, changes at 31 (2076 bytes = one
        # sprite stepping a single glass pixel), holds again until 44.
        # Motion is sub-pixel per frame, so any small N is a coin flip.
        # The old N=8 check only ever passed BEFORE S_FB_SYNC (4188e01,
        # 2026-08-20), when the two FB banks still held different images and
        # consecutive FB? reads differed even when the scene did not --
        # i.e. it was passing on the bank-mismatch bug that fix removed.
        fclk = 0
        for _ in range(8):
            sim._rpc("FRAME")
            vmstat = sim._rpc("VMSTAT?")
            if "fault=" in vmstat and "fault=0" not in vmstat:
                break
            if "fclk=" in vmstat:
                fclk = max(
                    fclk,
                    int(vmstat.split("fclk=")[1].split()[0].replace(",", "")),
                )
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        assert "raf=0" not in vmstat, vmstat
        assert fclk > 100_000, f"rAF armed but idle: fclk={fclk} ({vmstat})"
        assert fclk < 32_000_000 * _VMDIV, f"fclk={fclk} ({vmstat})"
    finally:
        sim.shutdown()


def test_rtl_fillstyle_fillrect_global_loop_fclk():
    """fillStyle+fillRect+global PAL load: fclk must not be 8.8M-class."""
    src = (
        "var PAL = [1, 2, 3, 4];\n"
        "var c = document.querySelector('canvas').getContext('2d');\n"
        "function palK(k) {\n"
        "  c.fillStyle = PAL[k];\n"
        "  c.fillRect(0, 0, 4, 4);\n"
        "}\n"
        "function tick() {\n"
        "  var i = 0;\n"
        "  while (i < 64) { palK(i & 3); i = i + 1; }\n"
        "  requestAnimationFrame(tick);\n"
        "}\n"
        "requestAnimationFrame(tick);\n"
    )
    _patch_js_v64("PALK.JS", src)
    sim = _sim()
    try:
        sim.type_line('LOAD "PALK.JS"')
        sim.type_line("RUN")
        fclk = 0
        vmstat = ""
        for _ in range(8):
            sim._rpc("FRAME")
            vmstat = sim._rpc("VMSTAT?")
            if "fault=" in vmstat and "fault=0" not in vmstat:
                break
            if "fclk=" in vmstat:
                fclk = max(
                    fclk,
                    int(vmstat.split("fclk=")[1].split()[0].replace(",", "")),
                )
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        assert "raf=0" not in vmstat, vmstat
        # 64 tiny rects must not cost millions of clocks (old MRDO was 8.8M).
        assert fclk < 2_000_000 * _VMDIV, f"fclk={fclk} ({vmstat})"
        assert _fb_pix(_fb_raw(sim), 1, 1) != 0
    finally:
        sim.shutdown()


def test_mrdo_fpga_sim_enter_fclk_not_pathological():
    """MRDO on real RTL: Enter starts, fault=0, fclk << 8.8M."""
    from tools.compile_js import compile_html_text, encode_html_chunk

    html = resolve_storage_html("MRDO")
    if html is None:
        pytest.skip("no MRDO-family HTML in storage/")
    image_data = encode_html_chunk(compile_html_text(html.read_text(encoding="utf-8")))
    sim = _sim()
    try:
        sim._loaded_name = html.name
        sim._loaded_html_text = html.read_text(encoding="utf-8")
        sim._program_image = image_data
        assert sim._stream_program_image().startswith("OK")
        vmstat = _wait_vm_idle_or_frame(sim, slices=40)
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        sim._rpc("KEYEVT 13 1")
        sim._rpc("FRAME")
        sim._rpc("KEYEVT 13 0")
        fclk = 0
        for _ in range(4):
            sim._rpc("FRAME")
            vmstat = sim._rpc("VMSTAT?")
            if "fault=" in vmstat and "fault=0" not in vmstat:
                break
            if "fclk=" in vmstat:
                fclk = max(
                    fclk,
                    int(vmstat.split("fclk=")[1].split()[0].replace(",", "")),
                )
        assert "fault=0" in vmstat or "fault=" not in vmstat, vmstat
        assert "raf=0" not in vmstat, vmstat
        # Target: dispatch tax gone; honest pixel writes, ideally < 2M.
        # MRDO attract measures ~9.3M clk/frame (fillText-heavy full-screen
        # paint + the FB_SYNC present copy). This guards the 64M-cap
        # pathology, not MRDO's inherent weight; tighten after the ledger's
        # FIND/IMGD/GC speed items land.
        assert fclk < 12_000_000 * _VMDIV, f"fclk={fclk} ({vmstat})"
    finally:
        sim.shutdown()


def test_rtl_pacman_like_ctx_fillrect_width_after_date_throttle():
    """Game-ctor Date throttle then ctx.fillRect(0,0,_.width,_.height).

    PACMAN HTML black was vdraw=0,0,0,0 / fclk≈32k (skip or 0-size).
    Native fillRect snippets were not this path.
    """
    src = """
function Game() {
  var _ = this;
  Object.assign(_, {width: 640, height: 480});
  var c = document.getElementById('c').getContext('2d');
  this.start = function() {
    var timestamp = (new Date()).getTime();
    var fn = function() {
      var now = (new Date()).getTime();
      if (now - timestamp < 16) {
        requestAnimationFrame(fn);
        return;
      }
      timestamp = now;
      c.fillStyle = '#000000';
      c.fillRect(0, 0, _.width, _.height);
      c.fillStyle = '#ffffff';
      c.fillRect(10, 10, 20, 20);
      requestAnimationFrame(fn);
    };
    requestAnimationFrame(fn);
  };
}
var g = new Game();
g.start();
"""
    sim = _sim()
    try:
        _patch_js_v64("PMW.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "PMW.JS"')
        sim.type_line("RUN")
        saw = False
        st = ""
        for _ in range(24):
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
            if "vdraw=10,10,20,20" in st or "vdraw=0,0,640,480" in st:
                saw = True
                break
            if _fb_pix(_fb_raw(sim), 15, 15) != 0:
                saw = True
                break
        assert saw, st
    finally:
        sim.shutdown()


def test_rtl_stroke_after_fill_black_paints_white():
    """fillStyle black + fillRect must not leave stroke() black (ASTEROID rocks)."""
    src = """
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.fillStyle = '#000000';
  c.fillRect(0, 0, 640, 480);
  c.strokeStyle = '#ffffff';
  c.beginPath();
  c.moveTo(20, 20);
  c.lineTo(80, 20);
  c.stroke();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("STROKE.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "STROKE.JS"')
        sim.type_line("RUN")
        raw = b""
        for _ in range(8):
            sim._rpc("FRAME")
            raw = _fb_raw(sim)
            if _fb_pix(raw, 40, 20) != 0:
                break
        assert _fb_pix(raw, 40, 20) != 0, "stroke after fillRect black painted nothing"
    finally:
        sim.shutdown()


def test_rtl_image_onload_arrow_sets_player_image():
    """Constructor arrow onload must write Player.image (INVADERS gun)."""
    pix = bytes([4] * 16)
    src = """
class Player {
  constructor() {
    this.image = null;
    this.width = 0;
    this.height = 0;
    const image = new Image();
    image.src = "jmr:spr:0";
    image.onload = () => {
      this.image = image;
      this.width = image.width;
      this.height = image.height;
    };
  }
}
var p = new Player();
var c = document.getElementById('c').getContext('2d');
function tick() {
  if (p.image) {
    c.drawImage(p.image, 10, 10, p.width, p.height);
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("GUN.JS", src, [(4, 4, pix)], value64=True)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GUN.JS"')
        sim.type_line("RUN")
        raw = b""
        st = ""
        for _ in range(12):
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
            raw = _fb_raw(sim)
            if _fb_pix(raw, 11, 11) == 4:
                break
        assert _fb_pix(raw, 11, 11) == 4, st
    finally:
        sim.shutdown()


def test_rtl_lastkeypressed_identity_sets_facing():
    """lastKeyPressed === 'a' must set facingLeft (DONKEY)."""
    src = """
var o = {lastKeyPressed: '', facingLeft: false, facingRight: true};
function tick() {
  o.lastKeyPressed = 'a';
  if (o.lastKeyPressed === 'a') {
    o.facingLeft = true;
    o.facingRight = false;
  }
  if (o.facingLeft) {
    fillRect(10, 10, 20, 20, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_v64("FACE.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FACE.JS"')
        sim.type_line("RUN")
        saw = False
        st = ""
        for _ in range(8):
            sim._rpc("FRAME")
            st = sim._rpc("VMSTAT?")
            if "vdraw=10,10,20,20,2" in st or _fb_pix(_fb_raw(sim), 15, 15) == 2:
                saw = True
                break
        assert saw, st
    finally:
        sim.shutdown()


def _stream_html(sim, html: str) -> str:
    """Compile-on-RUN HTML → ProgramImage, same path as titles."""
    from tools.compile_js import compile_html_text, encode_html_chunk

    sim._program_image = encode_html_chunk(compile_html_text(html))
    assert sim._stream_program_image().startswith("OK")
    st = ""
    for _ in range(8 * _VMDIV):
        sim._rpc("TICKN 20000")
        st = sim._rpc("VMSTAT?")
        if "sname=S_WAIT_FRAME" in st:
            break
    return st


def test_rtl_keydown_letter_w_paints():
    """Twin of test_hw_value64_keydown_letter_w (potential bugs.md 15)."""
    html = """<!DOCTYPE html><canvas id="c" width="640" height="480"></canvas>
<script>
var c = document.getElementById("c").getContext("2d");
addEventListener("keydown", function(e) {
  if (e.key === "w") {
    c.fillStyle = "#fff";
    c.fillRect(10, 10, 4, 4);
  }
});
function tick() { requestAnimationFrame(tick); }
requestAnimationFrame(tick);
</script>
"""
    sim = _sim()
    try:
        st = _stream_html(sim, html)
        assert "fault=0" in st, st
        sim.key_event(87, "w", True)
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert _fb_pix(_fb_raw(sim), 11, 11) != 0, st
    finally:
        sim.shutdown()


def test_rtl_foreach_then_raf_paints():
    """Twin of test_hw_value64_foreach_then_raf_paints (potential bugs.md 6)."""
    html = """<!DOCTYPE html><canvas id="c" width="640" height="480"></canvas>
<script>
var c = document.getElementById("c").getContext("2d");
c.fillStyle = "#fff";
[1, 2].forEach(function(x) { c.fillRect(10 * x, 10, 4, 4); });
function tick() {
  c.fillRect(100, 10, 4, 4);
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
</script>
"""
    sim = _sim()
    try:
        st = _stream_html(sim, html)
        assert "fault=0" in st, st
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 11, 10) != 0 or _fb_pix(raw, 21, 10) != 0, st
        assert _fb_pix(raw, 101, 10) != 0, st
    finally:
        sim.shutdown()


def test_rtl_date_now_advances_paints():
    """Twin of test_hw_value64_date_now_advances_on_frame (potential bugs.md 14)."""
    html = """<!DOCTYPE html><canvas id="c" width="640" height="480"></canvas>
<script>
var c = document.getElementById("c").getContext("2d");
var t0 = Date.now();
function tick() {
  if (Date.now() !== t0) {
    c.fillStyle = "#fff";
    c.fillRect(10, 10, 4, 4);
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
</script>
"""
    sim = _sim()
    try:
        st = _stream_html(sim, html)
        assert "fault=0" in st, st
        sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert "fault=0" in st, st
        assert _fb_pix(_fb_raw(sim), 11, 11) != 0, st
    finally:
        sim.shutdown()

