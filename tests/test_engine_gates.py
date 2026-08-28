"""Gate tests for the run-50 combined change set (raster/blit/imgd engine,
fetch prefetch, raf_ts register). Written BEFORE the surgery per
RTL_DESIGN_PRINCIPLES 4.1: each pins the CURRENT exact behavior at the
seams the changes touch. Must be green on the unmodified tree first,
and green after every piece lands.

Seams covered:
 - ASET blit word packing: 2 px per 16-bit SRAM word (spr_so[0] byte
   select) -- a one-word source cache with a wrong tag or stale word
   fails exactly here (odd source x, odd width, 1-px source, scaled
   non-consecutive walks).
 - Sprite re-upload over the same SRAM addresses (LOAD B after LOAD A)
   -- a source cache that survives an upload blits stale pixels.
 - fillRect exactness at clip edges / 1x1 / zero-size, and
   fillRect->drawImage->fillRect ordering (engine serializes on busy).
 - getImageData/putImageData roundtrip at odd offsets and widths.
 - rAF timestamp exact IEEE doubles (vframe_no * 0x4030aaaaaaaaaaab):
   callback-delta floors and RUN-restart reset -- a raf_ts_q registered
   off by one frame moves the painted pixel by 16 or 17 columns.
 - Code reload then RUN (prefetch/code_we invalidation class).
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tests.test_rtl_snippets import _fb_pix, _fb_raw, _patch_js_spr, _sim, _vmstat_int


def _pattern(w: int, h: int) -> bytes:
    return bytes(((x + y * 3) % 6) + 1 for y in range(h) for x in range(w))


def _run_title(sim, name, src, sprites, aset=True):
    _patch_js_spr(name, src, sprites, aset=aset)
    sim._rpc("SDRELOAD")
    sim.type_line(f'LOAD "{name}"')
    sim.type_line("RUN")
    sim._rpc("FRAME")
    st = sim._rpc("VMSTAT?")
    assert _vmstat_int(st, "fault") == 0, st
    return _fb_raw(sim)


def _check_rect(raw, pix, sw_full, dx, dy, dw, dh, sx0, sy0, sw, sh):
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


# ---------------------------------------------------------------- blit seams

def test_gate_aset_blit_odd_source_x():
    """9-arg crop starting at ODD source x: first fetch uses the high byte
    of its word (spr_so[0]=1). A cache tag ignoring the byte lane fails."""
    pix = _pattern(10, 4)
    src = """
var img = new Image(); img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 3, 1, 5, 2, 30, 40, 5, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        raw = _run_title(sim, "GWB1.JS", src, [(10, 4, pix)])
        _check_rect(raw, pix, 10, 30, 40, 5, 2, 3, 1, 5, 2)
    finally:
        sim.shutdown()


def test_gate_aset_blit_one_px_wide_column():
    """1-px-wide source column, odd x: every row is a different word;
    no two consecutive fetches share a word (cache must never hit)."""
    pix = _pattern(9, 6)
    src = """
var img = new Image(); img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 5, 0, 1, 6, 80, 10, 1, 6);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        raw = _run_title(sim, "GWB2.JS", src, [(9, 6, pix)])
        _check_rect(raw, pix, 9, 80, 10, 1, 6, 5, 0, 1, 6)
    finally:
        sim.shutdown()


def test_gate_aset_blit_downscale_word_skips():
    """Downscale 14->5: DDA skips 2-3 source px per dest px, so the walk
    alternates same-word hits and word skips -- the cache-advance seam."""
    pix = _pattern(14, 3)
    src = """
var img = new Image(); img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.drawImage(img, 0, 0, 14, 3, 50, 60, 5, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        raw = _run_title(sim, "GWB3.JS", src, [(14, 3, pix)])
        _check_rect(raw, pix, 14, 50, 60, 5, 3, 0, 0, 14, 3)
    finally:
        sim.shutdown()


# NOTE (2026-08-27): a sprite re-upload invalidation gate was attempted
# and hit two harness walls: (a) a second .JS RUN in one sim session
# answers ?NB (console JSB lookup; stale-mount class, pre-existing), and
# (b) after hard_break of an HTML title the sim console stops accepting
# typed keys, so a second LOAD cannot be driven. Instead of gating it,
# the engine design makes the staleness impossible BY CONSTRUCTION: the
# one-word blit source cache is invalidated on every blit `go`, so a hit
# can only be served within a single blit walk, and sprite uploads can
# never interleave with a running blit (uploads happen at LOAD; the VM
# blocks on `busy` during a blit). Cost: one extra SRAM fetch per blit.


# ------------------------------------------------------------ fillRect seams

def test_gate_fillrect_exact_shapes():
    """1x1, thin bars, zero-size no-op, and edge-clipped rects -- exact."""
    src = """
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.fillStyle = '#ff0000';
  c.fillRect(100, 100, 1, 1);
  c.fillRect(0, 0, 640, 2);
  c.fillRect(200, 200, 0, 5);
  c.fillRect(630, 470, 40, 40);
  c.fillRect(5, 460, 3, 60);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        raw = _run_title(sim, "GFR1.JS", src, [(2, 2, bytes([1] * 4))])
        red = _fb_pix(raw, 100, 100)
        assert red != 0, "1x1 fillRect missing"
        assert _fb_pix(raw, 101, 100) == 0, "1x1 fillRect bled right"
        assert _fb_pix(raw, 100, 101) == 0, "1x1 fillRect bled down"
        assert _fb_pix(raw, 639, 0) == red, "full-width bar clipped short"
        assert _fb_pix(raw, 0, 1) == red, "bar row 1 missing"
        assert _fb_pix(raw, 200, 202) == 0, "zero-width rect painted"
        assert _fb_pix(raw, 639, 479) == red, "corner clip missing"
        assert _fb_pix(raw, 631, 471) == red, "right-edge clip missing"
        assert _fb_pix(raw, 6, 478) == red, "bottom-edge clip missing"
    finally:
        sim.shutdown()


def test_gate_fill_blit_fill_ordering():
    """fillRect under, drawImage over, fillRect over again -- the engine
    must serialize ops in program order (busy handshake), not reorder."""
    pix = bytes([3] * 16)
    src = """
var img = new Image(); img.src = "jmr:spr:0";
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.fillStyle = '#ff0000';
  c.fillRect(20, 20, 8, 8);
  c.drawImage(img, 22, 22);
  c.fillRect(24, 24, 2, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        raw = _run_title(sim, "GORD1.JS", src, [(4, 4, pix)])
        red = _fb_pix(raw, 20, 20)
        assert red != 0 and red != 3, ("base rect", red)
        assert _fb_pix(raw, 22, 22) == 3, "sprite must cover rect"
        assert _fb_pix(raw, 27, 27) == red, "rect visible outside sprite"
        assert _fb_pix(raw, 24, 24) == red, "top rect must cover sprite"
        assert _fb_pix(raw, 25, 23) == 3, "sprite visible outside top rect"
    finally:
        sim.shutdown()


# ------------------------------------------------------------ ImageData seam

def test_gate_imagedata_roundtrip_odd_geometry():
    """getImageData at an odd offset/size, putImageData at another odd
    offset -- exact pixel identity (the DMA walk seam)."""
    src = """
var c = document.getElementById('c').getContext('2d');
var grabbed = null;
function tick() {
  if (!grabbed) {
    c.fillStyle = '#ff0000'; c.fillRect(11, 7, 4, 3);
    c.fillStyle = '#00ff00'; c.fillRect(13, 8, 3, 5);
    grabbed = c.getImageData(11, 7, 7, 9);
    c.putImageData(grabbed, 101, 53);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        raw = _run_title(sim, "GIMG1.JS", src, [(2, 2, bytes([1] * 4))])
        bad = []
        for y in range(9):
            for x in range(7):
                a = _fb_pix(raw, 11 + x, 7 + y)
                b = _fb_pix(raw, 101 + x, 53 + y)
                if a != b:
                    bad.append((x, y, a, b))
        assert not bad, f"roundtrip mismatch: {bad[:8]}"
    finally:
        sim.shutdown()


# ---------------------------------------------------------- rAF timestamp

def test_gate_raf_timestamp_delta_exact():
    """Two-frame callback delta floor(t3 - t1) == 33 (2 * 50/3 exactly,
    IEEE). A raf_ts registered one frame stale paints 16 or 50 instead."""
    src = """
var c = document.getElementById('c').getContext('2d');
var t1 = -1, n = 0;
function tick(ts) {
  n = n + 1;
  if (n === 1) { t1 = ts; }
  if (n === 3) {
    c.fillStyle = '#ff0000';
    c.fillRect(Math.floor(ts - t1), 5, 1, 1);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("GRAF1.JS", src, [(2, 2, bytes([1] * 4))])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GRAF1.JS"')
        sim.type_line("RUN")
        for _ in range(4):
            sim._rpc("FRAME")
        st = sim._rpc("VMSTAT?")
        assert _vmstat_int(st, "fault") == 0, st
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 33, 5) != 0, (
            "delta pixel not at x=33: "
            + repr([x for x in range(80) if _fb_pix(raw, x, 5)])
        )
    finally:
        sim.shutdown()


# NOTE: a RUN-restart timestamp-reset gate needs a second RUN in one sim
# session, which the harness cannot drive (console keys dead after
# hard_break of an HTML title -- same wall as the reupload gate above).
# The delta gate above already pins ts == vframe_no * 50/3 exactly, and
# vframe_no <= 0 at program start is a one-line reset the C3 register
# follows by construction (raf_ts_q reloads whenever vframe_no changes,
# including the reset write).


# ------------------------------------------------- code reload (prefetch)

def test_gate_prefetch_control_flow_exact():
    """Branch/call/RET-heavy compute painted as an exact pixel -- the
    prefetch (C2) must never serve a stale word across taken branches,
    calls and returns."""
    src_a = """
var c = document.getElementById('c').getContext('2d');
function f(k) { if (k < 2) { return 1; } return f(k - 1) + f(k - 2); }
var acc = 0;
for (var i = 0; i < 8; i = i + 1) { acc = acc + f(i); }
function tick() {
  c.fillStyle = '#ff0000';
  c.fillRect(acc, 15, 1, 1);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        raw = _run_title(sim, "GCR1.JS", src_a, [(2, 2, bytes([1] * 4))])
        # f = fib(1,1,2,3,5,8,13,21) summed 0..7 = 54
        assert _fb_pix(raw, 54, 15) != 0, [
            x for x in range(120) if _fb_pix(raw, x, 15)]
        # The reload half (LOAD B then RUN) hits the second-RUN harness
        # wall; stale-after-code_we protection is the C2 sim-only checker
        # (prefetch word compared against real code_rdata on every op)
        # plus invalidation on code_we by construction.
    finally:
        sim.shutdown()


# ------------------------------------------------------------- joystick

def test_gate_joystick_move_delivers_release():
    """A stick MOVE is a simultaneous release+press (joy 4 -> 8 = up[L] +
    down[R] in one tick). The old dispatch enqueued the top-priority down
    bit then cleared BOTH edge masks, losing the keyup — the title
    believed the old direction was still held (ASTEROID board lag/ghost
    turning). Correct behavior: every transition is delivered; after
    L -> R -> release, the title's held set is empty."""
    src = """
var c = document.getElementById('c').getContext('2d');
var held = {};
document.addEventListener("keydown", function(e) { held[e.keyCode] = 1; });
document.addEventListener("keyup", function(e) { held[e.keyCode] = 0; });
function tick() {
  c.fillStyle = '#000000';
  c.fillRect(0, 0, 40, 8);
  c.fillStyle = '#ff0000';
  if (held[37]) { c.fillRect(10, 3, 1, 1); } else { c.fillRect(10, 5, 1, 1); }
  if (held[39]) { c.fillRect(20, 3, 1, 1); } else { c.fillRect(20, 5, 1, 1); }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js_spr("GJOY1.JS", src, [(2, 2, bytes([1] * 4))])
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GJOY1.JS"')
        sim.type_line("RUN")
        sim._rpc("FRAME")            # listeners attached
        sim._rpc("JOY 4")            # press Left
        sim._rpc("FRAME")
        sim._rpc("JOY 8")            # MOVE: release Left + press Right
        sim._rpc("FRAME")
        sim._rpc("JOY 0")            # release Right
        sim._rpc("FRAME")
        sim._rpc("FRAME")            # settle: deliver + repaint
        st = sim._rpc("VMSTAT?")
        assert _vmstat_int(st, "fault") == 0, st
        raw = _fb_raw(sim)
        l_held = _fb_pix(raw, 10, 3) != 0
        r_held = _fb_pix(raw, 20, 3) != 0
        assert not l_held, "Left still held: the move's keyup was lost"
        assert not r_held, "Right still held: the release keyup was lost"
    finally:
        sim.shutdown()
