#!/usr/bin/env python3
"""JMR JS Architecture Monitor — live schematic (observer).

Pattern cite: JMR-BASIC-FPGA-COMPUTER/gui_jmr.py ArchitectureView (window
mechanics only). Blocks follow docs/ARCHITECTURE.md posters — JS bytecode ISA,
three memory rooms, compile-on-RUN HTML. Not a BASIC 64K reskin.

F7/F8 µop-step is not in this pass (needs STEPUOP / TRACE).
"""

from __future__ import annotations

import time
import tkinter as tk
import tkinter.font as tkfont

from functional_model.bytecode import Op
from functional_model.jsb_format import (
    ASET_PAL_BYTES, FLAG_ASET, FLAG_SOURCE_MAP, FLAG_V2, FLAG_VALUE64,
    MAGIC, NATIVE_IDS,
)

ASET_PAL_ENTRIES = ASET_PAL_BYTES // 3

# Derived, never typed in: a new opcode must not leave the poster saying 34.
N_OPCODES = len(list(Op))

# Capacities come from the model that mirrors jmr_js_vm_pkg.sv, so the panel
# cannot drift from the RTL the way hand-typed numbers did (the 2026-08-21
# T200 fit moved every one of these).
try:  # pragma: no cover - the GUI must still open if the HM moves
    from hardware_model.js_vm import (
        CODE_WORDS, ENV_DEPTH, MAX_ARRAYS, MAX_CONSTS, MAX_OBJECTS,
        MAX_VARS, STACK_DEPTH,
    )
except ImportError:  # keep the schematic usable, just without headroom
    CODE_WORDS = ENV_DEPTH = MAX_ARRAYS = MAX_CONSTS = 0
    MAX_OBJECTS = MAX_VARS = STACK_DEPTH = 0
STACK_SLOTS = STACK_DEPTH or 2048


def _cap(live, cap: int) -> str:
    """`live / cap` with the percentage that tells you how close the wall is."""
    if not cap:
        return _dash(live)
    try:
        n = int(live)
    except (TypeError, ValueError):
        return f"—/{cap}"
    return f"{n}/{cap} ({n * 100 // cap}%)"


def _flag_names(flags) -> str:
    try:
        f = int(flags)
    except (TypeError, ValueError):
        return "—"
    bits = []
    for bit, name in (
        (FLAG_V2, "V2"), (FLAG_ASET, "ASET"),
        (FLAG_SOURCE_MAP, "SMAP"), (FLAG_VALUE64, "VALUE64"),
    ):
        if f & bit:
            bits.append(name)
    return f"0x{f:x} " + ("|".join(bits) if bits else "none")

# Phosphor palette (BASIC Architecture Monitor — method, not ISA)
ARCH_BG = "#0d0f0d"
BLOCK_IDLE = "#161a16"
BLOCK_ACTIVE = "#2f9e44"
BLOCK_OUTLINE = "#2c332c"
BLOCK_SELECT = "#ffd07a"
TITLE_FG = "#8fd08f"
VALUE_FG = "#e6ffe6"
ACCENT_FG = "#ffd07a"
WIRE_IDLE = "#333a33"
PHOSPHOR = "#33ff33"
DIE_FG = "#5a8f5a"


def _blend(active: str, idle: str, t: float) -> str:
    t = 0.0 if t < 0.0 else 1.0 if t > 1.0 else float(t)
    a = [int(active[i : i + 2], 16) for i in (1, 3, 5)]
    b = [int(idle[i : i + 2], 16) for i in (1, 3, 5)]
    rgb = []
    for i in range(3):
        v = int(round(b[i] + (a[i] - b[i]) * t))
        rgb.append(0 if v < 0 else 255 if v > 255 else v)
    return "#%02x%02x%02x" % tuple(rgb)


def _dash(val, default: str = "—") -> str:
    if val is None or val == "":
        return default
    return str(val)


# VMSTAT sname → schematic keys that should light (observer heat, no TRACE).
#
# The RTL st_t enum is append-only and now has ~112 members. The value64 exec
# path (FLAG_VALUE64, every current title) spends its cycles in the S_V64_*,
# S_HEAP_*, S_GC_* and S_FREE_* families, so a table that only knew the legacy
# 32-bit names left ~80% of real activity dark. S_V64_ is stripped first and
# the remainder falls through to the same engine mapping.
_STATE_ENGINES: dict[str, tuple[str, ...]] = {}


def _reg_states(keys: tuple[str, ...], *states: str) -> None:
    for st in states:
        _STATE_ENGINES[st] = keys


# fetch / image load — sequencer pulling words out of code BRAM
_reg_states(
    ("SEQUENCER", "COMPILER", "M_BRAM", "ARBITER", "S1"),
    "S_RD", "S_GOT_MAGIC", "S_GOT_HDR1", "S_GOT_HDR2", "S_LD_CONST",
    "S_TRAIL", "S_FETCH_WAIT", "S_CONST_HI",
)
# decode / execute
_reg_states(
    ("SEQUENCER", "DISPATCH", "STACK", "S2", "S3", "S4"),
    "S_EXEC", "S_DISPATCH",
)
_reg_states(("SEQUENCER", "NATIVE", "DISPATCH", "S4"), "S_NAT", "S_OGETI_NAT")
# Canvas 2D — fillRect / fillText / getImageData paint the on-chip FB
_reg_states(
    ("SEQUENCER", "CANVAS", "VIDEO", "M_BRAM", "ARBITER", "S4", "HDMI"),
    "S_RECT", "S_RECT_LD", "S_CIRCLE", "S_LINE", "S_CLEAR", "S_FONTPX",
    "S_TXT_LD", "S_TXT_DRAW", "S_IMGD_GET", "S_IMGD_PUT", "S_WIN_FILL",
    "S_FB_SYNC",
)
# Blitter — asset SRAM is the source, never code BRAM
_reg_states(
    ("SEQUENCER", "BLIT", "M_SRAM", "ARBITER", "S4"),
    "S_BLIT", "S_SPR", "S_PWALK", "S_PDO", "S_QSEG", "S_QPX", "S_QPY",
    "S_XF_MUL", "S_XF_APPLY",
)
# event / timer / rAF — the frame edge
_reg_states(
    ("SEQUENCER", "RAF", "S5", "HDMI"),
    "S_WAIT_FRAME", "S_DONE", "S_FRAME_RAF", "S_FRAME_TIMER",
)
_reg_states(("SEQUENCER", "RAF", "PHY_PS2", "PHY_JOY", "S4"), "S_KEYEV", "S_FRAME_KEY")
# string engine (JSON shares this path)
_reg_states(
    ("SEQUENCER", "STR", "STACK", "S4"),
    "S_JOIN", "S_JOIN_FIND", "S_IDXOF", "S_CONCAT", "S_REPL", "S_IDXSTR",
    "S_STRIDX", "S_STRIDX_WR", "S_STR_WR", "S_NAMCPY",
)
_reg_states(("SEQUENCER", "STR", "HEAP", "S4"), "S_JSON", "S_JSON_PARSE")
# ALU
_reg_states(
    ("SEQUENCER", "ALU", "STACK", "S4"),
    "S_SQRT", "S_DIV", "S_DIV_FIN", "S_MUL", "S_MUL_WR", "S_ALU", "S_ALU_WR",
    "S_MOD", "S_MINMAX",
)
# object / heap / env — allocation, property walks, calls, GC, free lists
_reg_states(
    ("SEQUENCER", "HEAP", "STACK", "M_BRAM", "ARBITER", "S4"),
    "S_CALL", "S_FOREACH", "S_ENV_LOAD", "S_ARR_DCOPY", "S_ALLOC",
    "S_HEAP_WAIT", "S_HEAP_CMP", "S_HEAP_WR", "S_HEAP_AWR", "S_HEAP_FILL",
    "S_HEAP_CLR", "S_GC_CLEAR", "S_GC_ROOT", "S_GC_POP", "S_GC_OBJ",
    "S_GC_ARR", "S_GC_SWEEP_OBJ", "S_GC_SWEEP_ARR", "S_GC_FN", "S_GC_ENV",
    "S_GC_SWEEP_ENV", "S_REL_ENV", "S_FREE_OBJ", "S_FREE_ARR", "S_CTOR_PAD",
    "S_CTOR_ENV", "S_CTOR_VARS", "S_METH", "S_FE_ELEM", "S_FE_FILTER",
    "S_IDXSCAN", "S_BIND", "S_ARR_PROMOTE", "S_SLICE", "S_SORT",
)


def _sname_keys(sname: str) -> list[str]:
    s = (sname or "").upper()
    if s in ("", "S_IDLE", "IDLE"):
        return ["SEQUENCER", "S5"]
    if s in ("LOAD", "LOADED"):
        return ["COMPILER", "STORE", "M_SDCARD", "SD", "PHY_SD", "CONSOLE"]
    if s == "COMPILE":
        return [
            "COMPILER", "M_BRAM", "M_SRAM", "SEQUENCER", "STORE",
            "S1", "CONSOLE", "ARBITER",
        ]
    if s == "RUN":
        return ["SEQUENCER", "DISPATCH", "S1", "S2", "S4"]
    # S_V64_EXEC and S_EXEC are the same stage of the same pipeline.
    base = "S_" + s[6:] if s.startswith("S_V64_") else s
    hit = _STATE_ENGINES.get(base)
    if hit is not None:
        return list(hit)
    return ["SEQUENCER", "S4"]


# Why the VM is parked, for states that are a wait rather than an opcode.
# This is a caption, never an opcode: the op at IP comes from the image the
# runtime actually loaded (backend.decode_op_at), so the DISPATCH box and the
# sequencer's own disassembly can never name two different instructions.
_STATE_NOTE = {
    "S_WAIT_FRAME": "parked — waiting for the frame / rAF callback",
    "S_DONE": "statement complete — frame edge",
    "S_IDLE": "no program running",
    "S_FRAME_RAF": "dispatching the queued rAF callback",
    "S_FRAME_TIMER": "dispatching a due setTimeout / setInterval",
    "S_FRAME_KEY": "dispatching a queued key event",
    "S_KEYEV": "key listener call",
    "S_FETCH_WAIT": "fetch stall — code BRAM read in flight",
    "S_HEAP_WAIT": "heap port stall",
    "S_FB_SYNC": "framebuffer swap / scanout sync",
}


def _state_note(sname: str) -> str:
    s = (sname or "").upper()
    base = "S_" + s[6:] if s.startswith("S_V64_") else s
    if base.startswith("S_GC_") or base.startswith("S_FREE_"):
        return "garbage collect / free list sweep"
    return _STATE_NOTE.get(base, "")


# The native a wait state is parked inside. Only states where the native is
# the actual cause, and only names the id table really has — the old table
# claimed drawImage/arc/lineTo, which have no CALL_NATIVE id at all, so the
# box printed "CALL_NATIVE —" under a name the ISA does not contain.
_STATE_NATIVE = {
    "S_WAIT_FRAME": "requestAnimationFrame",
    "S_FRAME_RAF": "requestAnimationFrame",
    "S_FRAME_TIMER": "setTimeout",
    "S_JSON": "JSON.stringify",
    "S_JSON_PARSE": "JSON.parse",
    "S_KEYEV": "addEventListener",
    "S_FRAME_KEY": "addEventListener",
}


def _state_native(sname: str) -> tuple[str, str]:
    """(name, id) of the native a wait state is parked in, else ('', '')."""
    s = (sname or "").upper()
    base = "S_" + s[6:] if s.startswith("S_V64_") else s
    name = _STATE_NATIVE.get(base, "")
    if not name:
        return "", ""
    nid = NATIVE_IDS.get(name)
    if nid is None:
        try:
            from functional_model.jsb_format import NATIVE_ALIASES

            nid = NATIVE_ALIASES.get(name)
        except ImportError:
            nid = None
    return (name, str(nid)) if nid is not None else ("", "")


# Canvas / blitter work reaches the engines as ctx.* method natives, not as
# bare DOM names — matching "fillRect" never fired for a real title.
_CANVAS_NATIVES = {
    "ctx.fillRect", "ctx.clearRect", "ctx.setFillStyle", "ctx.fillText",
    "ctx.measureText", "ctx.strokeRect", "ctx.fillPath", "ctx.strokePath",
    "ctx.getImageData", "ctx.putImageData", "__ctx_xform",
    "fillRect", "clear", "swapBuffers", "setFillStyle",
}
_BLIT_NATIVES = {"ctx.drawImage", "drawImage"}
# `Image` allocates a sprite handle against the asset bank; the blit itself is
# a separate ctx.drawImage, so it lights the SRAM room rather than the blitter.
_ASSET_NATIVES = {"Image"}
_EVENT_NATIVES = {
    "requestAnimationFrame", "setTimeout", "setInterval", "clearTimeout",
    "clearInterval", "addEventListener", "removeEventListener",
    "document.addEventListener", "window.addEventListener",
    "document.removeEventListener", "window.removeEventListener",
    "document.dispatchEvent", "window.dispatchEvent", "__fire_click",
    "keyLeft", "keyRight", "keyUp", "keyDown", "keyFire", "startLoop",
}
_ALU_NATIVES = {
    "Math.floor", "Math.abs", "Math.min", "Math.max", "Math.random",
    "Math.sqrt",
}
_STR_NATIVES = {"JSON.parse", "JSON.stringify", "typeof", "Object.keys"}


def _op_engine_keys(op_name: str, native_name: str) -> list[str]:
    """Executing opcode → blocks (BASIC µop-heat analog, JS ISA)."""
    op = (op_name or "").upper()
    nat = native_name or ""
    # Executing an op means it was fetched, decoded, and its microcode entry
    # loaded — S3 was dark under PYTHON only because nothing ever claimed it.
    keys = ["SEQUENCER", "DISPATCH", "S1", "S2", "S3", "S4"]
    if op in (
        "ADD", "SUB", "MUL", "DIV", "MOD", "LT", "GT", "EQ",
        "NEG", "NOT", "BIT_OR", "BIT_AND",
    ):
        keys += ["ALU", "STACK"]
    elif op in (
        "MAKE_ARRAY", "ARRAY_GET", "ARRAY_SET", "MAKE_OBJ", "GET_PROP",
        "SET_PROP", "NEW_OBJ", "CALL_METHOD", "MAKE_FN", "CALL_USER",
        "CALL_VAL", "RET_VAL", "RETURN",
    ):
        keys += ["HEAP", "STACK"]
    elif op in (
        "LOAD_CONST", "LOAD_VAR", "STORE_VAR", "LET_VAR", "POP", "DUP",
        "JUMP", "JUMP_IF_FALSE",
    ):
        keys += ["STACK"]
    if op == "CALL_NATIVE":
        keys += ["NATIVE"]
        if nat in _CANVAS_NATIVES:
            keys += ["CANVAS", "VIDEO", "M_BRAM", "HDMI", "ARBITER"]
        elif nat in _BLIT_NATIVES:
            keys += ["BLIT", "M_SRAM", "ARBITER"]
        elif nat in _ASSET_NATIVES:
            keys += ["M_SRAM", "HEAP", "ARBITER"]
        elif nat in _EVENT_NATIVES:
            keys += ["RAF"]
        elif nat in _STR_NATIVES:
            keys += ["STR", "HEAP"]
        elif nat in _ALU_NATIVES:
            keys += ["ALU"]
        elif nat in ("console.log", "console.warn"):
            keys += ["CONS_ENG"]
        elif nat.startswith("localStorage"):
            keys += ["STORE", "M_SDCARD"]
        elif nat.startswith("document.") or nat.startswith("Array"):
            keys += ["HEAP"]
    return keys


def _native_hist_keys(hist: dict) -> dict[str, float]:
    """PYTHON native histogram → per-block heat 0..1.

    The observable counterpart of the RTL's PROF? cycle histogram: PYTHON has
    no state machine to sample, but it can say which natives the frame called.
    Without this the Canvas / blitter / string engines stayed dark under
    PYTHON for a title that hammers them, while FPGA-SIM lit them.
    """
    heat: dict[str, float] = {}
    if not hist:
        return heat
    total = sum(hist.values()) or 1
    for name, count in hist.items():
        share = count / total
        weight = min(1.0, 0.4 + share * 2.0)
        for key in _op_engine_keys("CALL_NATIVE", name):
            if weight > heat.get(key, 0.0):
                heat[key] = weight
    return heat


def _prof_keys(prof: str) -> dict[str, float]:
    """RTL PROF? cycle histogram → per-block heat 0..1.

    `PROF cycles=N S_V64_GC_ARR=5686497(21%) …`. A single VMSTAT sname is one
    sample at the frame edge (almost always S_WAIT_FRAME), so it cannot show
    which engines the frame used. This is where the cycles actually went.
    """
    heat: dict[str, float] = {}
    if not prof:
        return heat
    for tok in str(prof).split():
        if "=" not in tok or not tok.startswith("S_"):
            continue
        state, _, rest = tok.partition("=")
        pct = 0.0
        if "(" in rest and rest.endswith("%)"):
            try:
                pct = float(rest[rest.index("(") + 1 : -2]) / 100.0
            except ValueError:
                pct = 0.0
        if pct <= 0.0:
            continue
        # A 20%-of-cycles engine should read hot, not dim: percentages are
        # spread across a dozen states and none of them ever reaches 1.0.
        weight = min(1.0, 0.35 + pct * 2.6)
        for key in _sname_keys(state):
            if weight > heat.get(key, 0.0):
                heat[key] = weight
    return heat


PHOSPHOR_HI = "#b6ffb6"
PACKET_MS = 320.0
PACKET_MAX_FLIGHT = 3


def _polyline_point(pts, u: float) -> tuple[float, float]:
    """Point at fraction `u` along a polyline, measured by arc length."""
    if not pts:
        return (0.0, 0.0)
    if len(pts) == 1:
        return pts[0]
    segs = []
    total = 0.0
    for i in range(len(pts) - 1):
        dx = pts[i + 1][0] - pts[i][0]
        dy = pts[i + 1][1] - pts[i][1]
        d = (dx * dx + dy * dy) ** 0.5
        segs.append(d)
        total += d
    if total <= 0.0:
        return pts[0]
    want = max(0.0, min(1.0, u)) * total
    run = 0.0
    for i, d in enumerate(segs):
        if run + d >= want or i == len(segs) - 1:
            t = 0.0 if d <= 0 else (want - run) / d
            x = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t
            y = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t
            return (x, y)
        run += d
    return pts[-1]


def _op_packet_hops(op_name: str, native_name: str):
    """Executing op → the blocks a value actually travels between.

    JS analog of the BASIC µop packet story: fetch, dispatch, the one engine
    that opcode strobes, then the memory room it reaches through the arbiter.
    """
    op = (op_name or "").upper()
    if not op:
        return []
    hops = [
        ("SEQUENCER", "DISPATCH", "opcode", "S2"),
    ]
    engine = None
    room = None
    if op in ("ADD", "SUB", "MUL", "DIV", "MOD", "LT", "GT", "EQ",
              "NEG", "NOT", "BIT_OR", "BIT_AND"):
        engine, room = "ALU", None
    elif op in ("MAKE_ARRAY", "ARRAY_GET", "ARRAY_SET", "MAKE_OBJ", "GET_PROP",
                "SET_PROP", "NEW_OBJ", "CALL_METHOD", "MAKE_FN", "CALL_USER",
                "CALL_VAL", "RET_VAL", "RETURN"):
        engine, room = "HEAP", "M_BRAM"
    elif op in ("LOAD_CONST", "LOAD_VAR", "STORE_VAR", "LET_VAR", "POP", "DUP",
                "JUMP", "JUMP_IF_FALSE"):
        engine, room = "STACK", None
    elif op == "CALL_NATIVE":
        nat = native_name or ""
        hops.append(("DISPATCH", "NATIVE", "native id", "S3"))
        if nat in _CANVAS_NATIVES:
            engine, room = "CANVAS", "M_BRAM"
        elif nat in _BLIT_NATIVES:
            engine, room = "BLIT", "M_SRAM"
        elif nat in _ASSET_NATIVES:
            engine, room = "HEAP", "M_SRAM"
        elif nat in _EVENT_NATIVES:
            engine, room = "RAF", None
        elif nat in _STR_NATIVES:
            engine, room = "STR", "M_BRAM"
        elif nat in _ALU_NATIVES:
            engine, room = "ALU", None
        elif nat in ("console.log", "console.warn"):
            engine, room = "CONS_ENG", None
        elif nat.startswith("localStorage"):
            engine, room = "STORE", "M_SDCARD"
        else:
            engine, room = "HEAP", "M_BRAM"
    if engine is None:
        return hops
    src = "NATIVE" if op == "CALL_NATIVE" else "DISPATCH"
    hops.append((src, engine, "strobe", "S4"))
    if room:
        hops.append((engine, "ARBITER", "req", "S4"))
        hops.append(("ARBITER", room, "addr/data", "S4"))
    return hops


class PacketAnimator:
    """One-hop-at-a-time dots along the dispatch → engine → memory corridor.

    Ported from the BASIC monitor's µop story. Same rule: non-preemptive, so a
    story finishes before the newest op plays — clearing on every change made
    the dots look random at full speed.
    """

    def __init__(self, canvas: tk.Canvas) -> None:
        self.canvas = canvas
        self.queue: list = []
        self.flight: list[dict] = []
        self._last_key: str | None = None
        self.caption = ""
        self.story_hops: list = []
        self.story_op = ""
        self.pending: tuple[str, str] | None = None

    def clear(self) -> None:
        for p in self.flight:
            self._delete(p)
        self.flight.clear()
        self.queue.clear()
        self._last_key = None
        self.caption = ""
        self.story_hops = []
        self.story_op = ""
        self.pending = None
        try:
            self.canvas.delete("packet")
        except tk.TclError:
            pass

    def _delete(self, p: dict) -> None:
        for item in (p.get("dot"), p.get("lab"), p.get("trail")):
            if item is not None:
                try:
                    self.canvas.delete(item)
                except tk.TclError:
                    pass

    def observe(self, op_name: str, native_name: str) -> None:
        key = f"{op_name}/{native_name}"
        if not op_name or key == self._last_key:
            return
        self._last_key = key
        if self.flight or self.queue:
            self.pending = (op_name, native_name)
            return
        self._start(op_name, native_name)

    def _start(self, op_name: str, native_name: str) -> None:
        hops = _op_packet_hops(op_name, native_name)
        if not hops:
            return
        self.story_hops = list(hops)
        self.story_op = op_name if op_name != "CALL_NATIVE" else (
            f"CALL_NATIVE {native_name}" if native_name else "CALL_NATIVE"
        )
        self.queue.extend(hops)
        self.caption = self._caption(self.story_op, hops)

    @staticmethod
    def _caption(op: str, hops) -> str:
        if not hops:
            return ""
        out = []
        prev_dst = None
        for src, dst, _label, _stage in hops:
            s = {"ARBITER": "ARB"}.get(src, src)
            d = {"ARBITER": "ARB"}.get(dst, dst)
            if src != prev_dst:
                if out:
                    out.append("  ·  ")
                out.append(s)
            out.append(" ──▶ ")
            out.append(d)
            prev_dst = dst
        return f"DATA {op}:  " + "".join(out)

    @staticmethod
    def _hop_duration(pts, duration_ms: float) -> float:
        plen = 0.0
        for i in range(len(pts) - 1):
            dx = pts[i + 1][0] - pts[i][0]
            dy = pts[i + 1][1] - pts[i][1]
            plen += (dx * dx + dy * dy) ** 0.5
        base = max(0.12, duration_ms / 1000.0)
        return max(0.20, min(base * 1.6, base * (plen / 260.0)))

    def tick(self, waypoints_of, *, duration_ms: float = PACKET_MS,
             stage_heat: dict | None = None) -> None:
        now = time.monotonic()
        while self.queue and len(self.flight) < PACKET_MAX_FLIGHT:
            src, dst, label, stage = self.queue.pop(0)
            try:
                pts = waypoints_of(src, dst)
            except Exception:
                continue
            if not pts or len(pts) < 2:
                continue
            flat = []
            for x, y in pts:
                flat.extend([x, y])
            trail = self.canvas.create_line(
                *flat, fill=ACCENT_FG, width=3, arrow=tk.LAST, tags=("packet",),
            )
            x0, y0 = pts[0]
            dot = self.canvas.create_oval(
                x0 - 6, y0 - 6, x0 + 6, y0 + 6,
                fill=PHOSPHOR_HI, outline=ACCENT_FG, width=2, tags=("packet",),
            )
            lab = self.canvas.create_text(
                x0 + 12, y0 - 12, text=label, fill=ACCENT_FG,
                font=("Menlo", 9, "bold"), anchor="w", tags=("packet",),
            )
            self.flight.append({
                "dot": dot, "lab": lab, "trail": trail, "pts": pts,
                "t0": now, "dur": self._hop_duration(pts, duration_ms),
                "src": src, "dst": dst,
            })
            if stage_heat is not None:
                if stage:
                    stage_heat[stage] = now
                stage_heat[src] = now
        done = []
        for p in self.flight:
            t = (now - p["t0"]) / p["dur"] if p["dur"] > 0 else 1.0
            if t >= 1.0:
                done.append(p)
                continue
            u = t * t * (3 - 2 * t)   # ease in-out
            x, y = _polyline_point(p["pts"], u)
            self.canvas.coords(p["dot"], x - 6, y - 6, x + 6, y + 6)
            self.canvas.coords(p["lab"], x + 12, y - 12)
        for p in done:
            self._delete(p)
            self.flight.remove(p)
            if stage_heat is not None:
                stage_heat[p["dst"]] = now
        if not self.flight and not self.queue:
            if self.pending:
                nxt = self.pending
                self.pending = None
                self._start(*nxt)
            elif self.story_hops:
                self.caption = self._caption(self.story_op, self.story_hops)


class ArchitectureView:
    """JS-native die diagram with live snapshot captions + click inspectors."""

    WIDTH = 1340
    HEIGHT = 1120

    ENGINES = [
        ("ALU", "ALU"),
        ("CANVAS", "Canvas 2D"),
        ("BLIT", "Blitter"),
        ("RAF", "Event/rAF"),
        ("STR", "String"),
        ("CONS_ENG", "Console"),
        ("STORE", "Storage"),
        ("VIDEO", "Video"),
    ]
    STAGES = [
        ("S1", "1 FETCH"),
        ("S2", "2 DECODE"),
        ("S3", "3 LOAD µCODE"),
        ("S4", "4 EXECUTE"),
        ("S5", "5 COMPLETE"),
    ]

    ENGINE_BLURBS = {
        "ALU": (
            "Expression / ALU — hardwired arithmetic for bytecode ops.\n"
            "ADD/SUB/MUL/DIV/MOD and compares. One copy; never merged."
        ),
        "CANVAS": (
            "Canvas 2D — fillRect · fillText (8×8 font ROM) · getImageData.\n"
            "Paints the on-chip dual 640×480 8-bpp framebuffer."
        ),
        "BLIT": (
            "Blitter — drawImage streams 8-bpp pixels from asset SRAM,\n"
            "2 px / 16-bit word. Pixels never enter code BRAM."
        ),
        "RAF": (
            "Event / Timer / rAF — requestAnimationFrame, setTimeout,\n"
            "keydown. Closures survive return so queued fns keep their env."
        ),
        "STR": (
            "String engine — interned strings, join, indexOf, replace.\n"
            "JSON.parse / stringify share this path (not a CSS engine)."
        ),
        "CONS_ENG": (
            "Console engine — READY · LOAD · RUN · DIR · EDIT.\n"
            "RUN always compiles the loaded HTML into an in-memory ProgramImage."
        ),
        "STORE": (
            "Storage engine — µSD SPI FAT32.\n"
            "NAME.HTML titles. Compile-on-RUN is in memory (code + ASET)."
        ),
        "VIDEO": (
            "Video / HDMI scanout — 8-bpp indexed through 256-entry RGB888\n"
            "palette. HDMI reads the on-chip FRONT framebuffer only."
        ),
    }
    STAGE_BLURBS = {
        "S1": "1 FETCH — Program Sequencer reads the next 32-bit bytecode word from code BRAM.",
        "S2": f"2 DECODE — Dispatch Table maps opcode[7:0] to an engine ({N_OPCODES} opcodes).",
        "S3": "3 LOAD µCODE — jump to that opcode's microcode entry (not a hidden CPU).",
        "S4": "4 EXECUTE — one op strobes one engine (ALU / heap / Canvas / blitter / …).",
        "S5": "5 COMPLETE / wait — statement done, or stall for rAF / blitter / timer.",
    }
    MEMORY_BLURBS = {
        "M_BRAM": (
            "ON-CHIP BRAM (room A) — working set, no fake 64K map.\n"
            f"Dual 640×480 8-bpp FB, code BRAM {CODE_WORDS or '?'}×32, JS heap,\n"
            "256-entry RGB888 palette, font ROM, FIFOs.\n"
            "HDMI scans out from the front FB."
        ),
        "M_SRAM": (
            "ASSET SRAM 4 MB (room B) — ISSI IS61WV204816.\n"
            "0x000000–0x0002FF title palette (256×RGB888).\n"
            "0x000300+ 8-bpp sprite banks. Blitter-source only.\n"
            "Pixels never enter code BRAM. No NAME.DAT file."
        ),
        "M_SDCARD": (
            "µSD FAT32 (room C) — disk, not RAM.\n"
            "LOAD \"NAME.HTML\" titles. Compile-on-RUN stays in memory\n"
            "(code + ASET). Card is HTML only."
        ),
        "ARBITER": (
            "MEMORY ARBITER — engines do not bypass BRAM / SRAM.\n"
            "Same simple SRAM port: addr[20:0], data[15:0], we/req/ack."
        ),
    }

    def __init__(self, window: tk.Toplevel) -> None:
        self.window = window
        self.canvas = tk.Canvas(
            window, width=self.WIDTH, height=self.HEIGHT,
            bg=ARCH_BG, highlightthickness=0,
        )
        self.canvas.pack(fill="both", expand=True)
        self.title_font = tkfont.Font(family="Helvetica", size=10, weight="bold")
        self.value_font = tkfont.Font(family="Menlo", size=9)
        self.small_font = tkfont.Font(family="Menlo", size=8)
        self.blocks: dict[str, tuple[int, int]] = {}
        self.block_rects: dict[str, tuple[int, int, int, int]] = {}
        self.inspect_key: str | None = None
        self._inspector: tk.Toplevel | None = None
        self._inspector_text: tk.Text | None = None
        self._inspect_body = ""
        self._runtime = "PYTHON"
        self._snap: dict = {}
        self._line_buf = ""
        self._heat_stamp: dict[str, float] = {}
        self._prof_heat: dict[str, float] = {}
        # Inspector peeks: cached per (name,args) so an open panel refreshing
        # every frame does not become one RPC per frame. Nothing is peeked
        # while every inspector is closed.
        self._peek_fn = None
        self._decode_fn = None
        self._peek_cache: dict[tuple, tuple[float, str]] = {}
        self._peek_ttl = 0.5
        # Re-clicking a block pages its peek window (heap slot, SRAM offset) —
        # the panel shows one slot at a time so a peek stays one RPC.
        self._probe_obj = 0
        self._probe_arr = 0
        self._probe_sram = 0
        # Execution replay. The GUI can only sample between frames, and there
        # the VM is always parked at the same rAF return — so a live IP read
        # shows one frozen instruction for the whole run. The runtimes hand us
        # the IPs they actually executed; this walks through them.
        self._replay: list[int] = []
        self._replay_i = 0
        self.replay_enabled = True
        self._replay_ip: int | None = None
        # Packet dots along the corridor (BASIC's µop story, JS opcodes).
        # Off by default — at 60 fps it is decoration, so it costs nothing
        # until you ask for it with A.
        self.packets = PacketAnimator(self.canvas)
        self.packets_enabled = False
        self._packet_stage_heat: dict[str, float] = {}
        # Register-change flash: a value that just changed reads as changed.
        self._prev_reg_vals: dict[str, str] = {}
        self._reg_flash_until: dict[str, float] = {}
        self.bars: dict[str, tuple] = {}
        self.wires: list[tuple[int, str, str, str]] = []  # line, key, kind, idle fill
        self._zoom = 1.0
        self._zoom_min = 0.45
        self._zoom_max = 3.5
        self._build()
        self.canvas.bind("<Button-1>", self._on_canvas_click)
        self.canvas.bind("<MouseWheel>", self._on_wheel)
        self.canvas.bind("<Button-4>", self._on_wheel)
        self.canvas.bind("<Button-5>", self._on_wheel)
        self.canvas.bind("<ButtonPress-2>", self._pan_mark)
        self.canvas.bind("<B2-Motion>", self._pan_drag)
        self.canvas.bind("<ButtonPress-3>", self._pan_mark)
        self.canvas.bind("<B3-Motion>", self._pan_drag)
        self.canvas.bind("<Shift-ButtonPress-1>", self._pan_mark)
        self.canvas.bind("<Shift-B1-Motion>", self._pan_drag)
        window.bind("<Home>", lambda _e: self._reset_view())
        window.bind("<h>", lambda _e: self._reset_view())
        window.bind("<H>", lambda _e: self._reset_view())
        window.bind("<a>", lambda _e: self._toggle_packets())
        window.bind("<A>", lambda _e: self._toggle_packets())
        window.bind("<t>", lambda _e: self._toggle_replay())
        window.bind("<T>", lambda _e: self._toggle_replay())
        self.canvas.bind("<Enter>", lambda _e: self.canvas.focus_set())

    def _block(self, key: str, x0: int, y0: int, x1: int, y1: int,
               title: str, accent: bool = False) -> None:
        rect = self.canvas.create_rectangle(
            x0, y0, x1, y1, fill=BLOCK_IDLE, outline=BLOCK_OUTLINE, width=1,
        )
        tw = max(36, x1 - x0 - 14)
        # title in the top padding; value in the lower half — never on the same baseline
        self.canvas.create_text(
            (x0 + x1) / 2, y0 + 16, text=title, font=self.title_font,
            fill=ACCENT_FG if accent else TITLE_FG, width=tw, justify="center",
        )
        value = self.canvas.create_text(
            (x0 + x1) / 2, y0 + (y1 - y0) * 0.64, text="", font=self.value_font,
            fill=VALUE_FG, justify="center", width=tw,
        )
        self.blocks[key] = (rect, value)
        self.block_rects[key] = (x0, y0, x1, y1)

    def _bar(self, key: str) -> None:
        """Thin activity meter along a block's bottom edge.

        Heat alone is a fill colour; the bar gives the eye a magnitude, which
        is what tells 3% of cycles from 30%.
        """
        x0, y0, x1, y1 = self.block_rects[key]
        track = self.canvas.create_rectangle(
            x0 + 6, y1 - 6, x1 - 6, y1 - 3,
            fill=BLOCK_OUTLINE, outline="", width=0,
        )
        fill = self.canvas.create_rectangle(
            x0 + 6, y1 - 6, x0 + 6, y1 - 3,
            fill=PHOSPHOR, outline="", width=0,
        )
        self.bars[key] = (track, fill)

    def _set_bar(self, key: str, frac: float) -> None:
        pair = self.bars.get(key)
        if pair is None:
            return
        try:
            x0, y0, x1, y1 = self.canvas.coords(pair[0])
        except (tk.TclError, ValueError):
            return
        frac = 0.0 if frac < 0.0 else 1.0 if frac > 1.0 else float(frac)
        self.canvas.coords(pair[1], x0, y0, x0 + (x1 - x0) * frac, y1)
        self.canvas.itemconfigure(
            pair[1], fill=_blend(PHOSPHOR_HI, PHOSPHOR, frac),
        )

    def _wire(self, key: str, *coords: float, kind: str = "ctrl") -> None:
        # NEW: poster legend — ctrl (solid), data (solid green-idle),
        # code (dashed blue) = compile-on-RUN HTML → ProgramImage → BRAM/SRAM
        if kind == "code":
            fill, dash = "#3a5580", (5, 3)
        elif kind == "data":
            fill, dash = "#1e3a1e", None
        else:
            fill, dash = WIRE_IDLE, None
        line = self.canvas.create_line(
            *coords, fill=fill, width=2, arrow=tk.LAST, dash=dash,
        )
        self.wires.append((line, key, kind, fill))

    def _on_wheel(self, event) -> None:
        if getattr(event, "num", None) == 5 or getattr(event, "delta", 0) < 0:
            factor = 0.9
        else:
            factor = 1.1
        new_zoom = max(self._zoom_min, min(self._zoom_max, self._zoom * factor))
        k = new_zoom / self._zoom if self._zoom else 1.0
        if abs(k - 1.0) < 1e-6:
            return
        x = self.canvas.canvasx(event.x)
        y = self.canvas.canvasy(event.y)
        self.canvas.scale("all", x, y, k, k)
        self._zoom = new_zoom
        self._sync_sd_window()

    def _pan_mark(self, event) -> None:
        self.canvas.scan_mark(event.x, event.y)

    def _pan_drag(self, event) -> None:
        self.canvas.scan_dragto(event.x, event.y, gain=1)
        self._sync_sd_window()

    def _reset_view(self) -> None:
        self.canvas.xview_moveto(0)
        self.canvas.yview_moveto(0)
        if abs(self._zoom - 1.0) > 1e-6:
            k = 1.0 / self._zoom
            self.canvas.scale("all", 0, 0, k, k)
            self._zoom = 1.0
        self._sync_sd_window()

    def _sync_sd_window(self) -> None:
        if "SD" not in self.block_rects:
            return
        try:
            x0, y0, x1, y1 = self.canvas.coords(self.blocks["SD"][0])
        except Exception:
            return
        self.canvas.coords(self._sd_window, x0 + 8, y0 + 26)
        w = max(40, x1 - x0 - 16)
        h = max(40, y1 - y0 - 34)
        self.canvas.itemconfigure(self._sd_window, width=w, height=h)

    def _build(self) -> None:
        # Layout corridors (wires stay in the gaps — never through labels):
        #   x=6/10 left gutter (PHY → UART/CONSOLE)
        #   x=210 left of die (compiler → sequencer)
        #   y=50 above the die (FETCH / compile-on-RUN into BRAM)
        #   x=704 core inner-right lip (dispatch → native)
        #   x=718 core↔ARB alley (heap → ARB top; blit/FB/store south bus)
        #   x=798 ARB↔memory alley
        #   y=714 under the die (ASET / store / joy)
        #   x=1326 right gutter (HDMI scanout → HDMI J8)
        c = self.canvas
        c.create_text(
            self.WIDTH / 2, 18, text="JMR JS PROCESSOR — LIVE",
            font=tkfont.Font(family="Helvetica", size=15, weight="bold"),
            fill=PHOSPHOR, tags=("chrome",),
        )
        c.create_text(
            self.WIDTH / 2, 36,
            text="HTML/JS-native CPU — bytecode is the ISA — wheel zoom · shift-drag pan · Home reset",
            font=self.small_font, fill=TITLE_FG, tags=("chrome",),
        )
        c.create_rectangle(
            218, 56, 1010, 708, outline=DIE_FG, width=3,
            dash=(6, 4), tags=("die",),
        )
        c.create_text(
            228, 70, text="JMR JS DIE · XC7A200T",
            font=self.small_font, fill=DIE_FG, tags=("die",), anchor="w",
        )

        self._block("UART", 16, 72, 204, 148, "UART / PROG TETHER")
        self._block("CONSOLE", 16, 162, 204, 258, "CONSOLE / LINE EDITOR")
        self._block("COMPILER", 16, 272, 204, 448, "COMPILER — compile-on-RUN")
        self._wire("UART", 110, 148, 110, 162)
        self._wire("CONSOLE", 110, 258, 110, 272)
        # compile-on-RUN: HTML → sequencer (left gutter — misses core title)
        self._wire(
            "CODE_BRAM", 204, 340, 210, 340, 210, 144, 240, 144, kind="code",
        )

        c.create_rectangle(226, 64, 710, 700, outline="#3b6e3b", width=2)
        c.create_text(
            500, 80, text="JS PROCESSOR CORE", font=self.title_font, fill=PHOSPHOR,
        )
        self._block("SEQUENCER", 240, 96, 468, 192, "1 PROGRAM SEQUENCER")
        self._block("DISPATCH", 482, 96, 696, 192, "2 DISPATCH TABLE")
        self._block("STACK", 240, 206, 468, 302, "3 TAGGED EVAL STACK")
        self._block("HEAP", 482, 206, 696, 302, "4 OBJECT / HEAP")
        self._block("NATIVE", 240, 316, 696, 394, "5 NATIVE CALL UNIT")
        self._wire("DISPATCH", 468, 144, 482, 144)
        self._wire("STACK", 354, 192, 354, 206)
        self._wire("HEAP", 589, 192, 589, 206)
        self._wire("STACK", 468, 254, 482, 254, kind="data")
        self._wire("NATIVE", 589, 302, 589, 316)
        self._wire("DISPATCH", 696, 144, 704, 144, 704, 355, 696, 355)

        c.create_text(
            468, 412, text="6 SHARED ENGINES — never merged",
            font=self.title_font, fill=TITLE_FG,
        )
        grid_x, grid_y, bw, bh, gap = 240, 428, 108, 92, 12
        for i, (key, label) in enumerate(self.ENGINES):
            rowi, coli = divmod(i, 4)
            x0 = grid_x + coli * (bw + gap)
            y0 = grid_y + rowi * (bh + gap)
            self._block(key, x0, y0, x0 + bw, y0 + bh, label)
            self._bar(key)
        self._wire("NATIVE2", 468, 394, 468, 428)
        # engines → ARB left edge (ARB sits beside the engine row, not on the bus)
        self._wire("ENG_ARB", 708, 474, 728, 474, kind="data")

        self._block("ARBITER", 728, 430, 788, 560, "ARB")
        self.canvas.itemconfigure(self.blocks["ARBITER"][1], font=self.small_font)

        c.create_rectangle(808, 64, 1010, 700, outline="#3b6e3b", width=2)
        c.create_text(
            909, 80, text="MEMORY — THREE ROOMS", font=self.title_font, fill=PHOSPHOR,
        )
        self._block("M_BRAM", 818, 98, 1000, 278, "A  ON-CHIP BRAM")
        self._block("M_SRAM", 818, 296, 1000, 486, "B  ASSET SRAM 4 MB")
        self._block("M_SDCARD", 818, 504, 1000, 688, "C  µSD FAT32")
        # heap → alley x=718 → ARB *top* (does not cross ARB caption)
        self._wire("MEM", 696, 254, 718, 254, 718, 430, 728, 430, kind="data")
        # ARB → rooms via x=798 (gap before memory 808)
        self._wire("ARB_MEM", 788, 450, 798, 450, 798, 188, 818, 188, kind="data")
        self._wire("BLIT_SRAM", 788, 495, 818, 495, kind="data")
        # FETCH + compile code along y=50 (above die / core title)
        self._wire(
            "FETCH", 354, 96, 354, 50, 909, 50, 909, 98, kind="code",
        )
        self._wire(
            "CODE_BRAM", 204, 300, 210, 300, 210, 50, 909, 50, 909, 98, kind="code",
        )
        # ASET: compiler → under-die y=714 → SRAM (misses MEMORY C title)
        self._wire(
            "CODE_ASET",
            204, 430, 210, 430, 210, 714, 718, 714, 718, 390, 818, 390,
            kind="code",
        )
        # Canvas FB: down between ALU/Canvas, south bus y=640, into ARB (not through ARB text)
        self._wire(
            "FB_BUS", 414, 520, 414, 640, 718, 640, 718, 495, 728, 495, kind="data",
        )
        # Blitter: down between Blitter/rAF onto the same south bus
        self._wire(
            "BLIT_SRAM", 588, 474, 594, 474, 594, 640, 718, 640, kind="data",
        )

        self._block("HDMI", 1022, 72, 1264, 168, "HDMI OUT  640×480", accent=True)
        self._block("REGS", 1022, 182, 1264, 300, "REGISTERS", accent=True)
        self._block("HSTATS", 1022, 314, 1264, 430, "HEAP STATS", accent=True)
        self._block("SD", 1022, 444, 1264, 700, "microSD / FAT32", accent=True)
        self.canvas.itemconfigure(self.blocks["SD"][1], font=self.small_font)
        self.sd_list = tk.Text(
            self.canvas, bg=BLOCK_IDLE, fg=VALUE_FG, bd=0, highlightthickness=0,
            font=self.small_font, wrap="none", cursor="arrow",
            spacing1=2, spacing3=2,
        )
        self.sd_list.configure(state="disabled")
        self._sd_window = self.canvas.create_window(
            1032, 472, window=self.sd_list, anchor="nw", width=220, height=214,
        )
        self._sd_list_text = ""
        self._wire("HDMI", 1000, 133, 1022, 133, kind="data")
        self._wire("REGS", 1000, 241, 1022, 241)
        self._wire("HSTATS", 1000, 372, 1022, 372, kind="data")
        # Storage → µSD room from below (not through C's header)
        self._wire(
            "STORE", 588, 578, 588, 640, 718, 640, 718, 714, 909, 714, 909, 688,
            kind="data",
        )
        self._wire("SD", 1000, 596, 1022, 596, kind="data")

        c.create_text(
            16, 730, text="BOARD CONNECTORS — Nexys Video (XC7A200T)",
            font=self.title_font, fill=PHOSPHOR, anchor="w",
        )
        phy = [
            ("PHY_PS2", "Keyboard", 16),
            ("PHY_HDMI", "HDMI J8", 266),
            ("PHY_UART", "PROG USB", 516),
            ("PHY_JOY", "Pmod joystick", 766),
            ("PHY_SD", "microSD card", 1022),
        ]
        for key, label, x0 in phy:
            self._block(key, x0, 748, x0 + 220, 814, label)
            c.create_rectangle(
                x0 + 90, 730, x0 + 130, 748, fill="#3b6e3b", outline=DIE_FG,
                tags=("pad",),
            )
        # plugs stay in gutters / under-die alley — HDMI on the RIGHT, SD straight up
        self._wire("KBD", 126, 748, 126, 722, 10, 722, 10, 210, 16, 210)
        self._wire("UART_PHY", 626, 748, 626, 722, 6, 722, 6, 110, 16, 110)
        self._wire(
            "HDMI_PHY", 1264, 133, 1326, 133, 1326, 736, 376, 736, 376, 748,
            kind="data",
        )
        self._wire("JOY", 876, 748, 876, 714, 718, 714, 718, 474, 708, 474)
        self._wire("SD_PHY", 1132, 748, 1132, 700)

        c.create_text(
            16, 834, text="INSTRUCTION FLOW", font=self.title_font,
            fill=PHOSPHOR, anchor="w",
        )
        x = 16
        for key, label in self.STAGES:
            self._block(key, x, 850, x + 216, 910, label)
            if key != "S5":
                self._wire("S_" + key, x + 216, 880, x + 248, 880)
            x += 252
        self.status_text = c.create_text(
            16, 932, text="", font=self.value_font, fill=VALUE_FG, anchor="w",
        )
        self.motto_text = c.create_text(
            16, 954, text="ONE OP · ONE DISPATCH · ONE ENGINE",
            font=self.value_font, fill=ACCENT_FG, anchor="w",
        )
        c.create_text(
            16, 976,
            text="click any box for live detail  ·  zoom in to see IP / heap / natives inside blocks",
            font=self.small_font, fill=TITLE_FG, anchor="w",
        )
        c.create_text(
            16, 998,
            text="solid = control/data · dashed blue = compile-on-RUN · A animates · T freezes the trace replay · F10 hides",
            font=self.small_font, fill=TITLE_FG, anchor="w",
        )
        self.path_text = c.create_text(
            16, 1020, text="", font=self.small_font, fill=TITLE_FG, anchor="w",
        )

    # How many recorded IPs to step past per GUI frame. 1 crawls through a
    # 600-entry trace; this walks it at a readable pace.
    _REPLAY_STRIDE = 7

    def _advance_replay(self, ring, running: bool) -> int | None:
        """Next IP from the executed-instruction trace, or None.

        This is a replay of what already ran at full speed — not stepping, and
        it never gates the machine. The REGISTERS panel keeps showing the true
        parked state so the two are never confused.
        """
        if not running or not self.replay_enabled:
            self._replay = []
            self._replay_i = 0
            self._replay_ip = None
            return None
        ring = list(ring or [])
        if ring:
            self._replay = ring
        if not self._replay:
            return None
        # The cursor free-runs and is taken modulo the current ring. Resetting
        # it whenever the ring changed pinned the display to one entry, since
        # a new frame's samples arrive between every GUI update.
        self._replay_i += self._REPLAY_STRIDE
        self._replay_ip = self._replay[self._replay_i % len(self._replay)]
        return self._replay_ip

    def _toggle_replay(self) -> None:
        self.replay_enabled = not self.replay_enabled
        self._replay_ip = None

    def _toggle_packets(self) -> None:
        self.packets_enabled = not self.packets_enabled
        if not self.packets_enabled:
            self.packets.clear()

    def _block_center(self, key: str) -> tuple[float, float] | None:
        rect = self.blocks.get(key)
        if rect is None:
            return None
        try:
            x0, y0, x1, y1 = self.canvas.coords(rect[0])
        except (tk.TclError, ValueError):
            return None
        return ((x0 + x1) / 2.0, (y0 + y1) / 2.0)

    def _block_edge(self, key: str, toward: tuple[float, float]):
        """Point on a block's border facing `toward` — dots leave the box, not
        the label underneath it."""
        rect = self.blocks.get(key)
        if rect is None:
            return None
        try:
            x0, y0, x1, y1 = self.canvas.coords(rect[0])
        except (tk.TclError, ValueError):
            return None
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        dx, dy = toward[0] - cx, toward[1] - cy
        if abs(dx) < 1e-6 and abs(dy) < 1e-6:
            return (cx, cy)
        halfw, halfh = max(1.0, (x1 - x0) / 2.0), max(1.0, (y1 - y0) / 2.0)
        scale = min(
            halfw / abs(dx) if abs(dx) > 1e-6 else float("inf"),
            halfh / abs(dy) if abs(dy) > 1e-6 else float("inf"),
        )
        return (cx + dx * scale, cy + dy * scale)

    def _packet_waypoints(self, src: str, dst: str):
        """Elbow polyline between two blocks, routed through the gap between
        them so a dot never crosses a block it is not visiting."""
        a = self._block_center(src)
        b = self._block_center(dst)
        if a is None or b is None:
            return []
        p0 = self._block_edge(src, b) or a
        p1 = self._block_edge(dst, a) or b
        if abs(p0[1] - p1[1]) < 14.0 or abs(p0[0] - p1[0]) < 14.0:
            return [p0, p1]
        midx = (p0[0] + p1[0]) / 2.0
        return [p0, (midx, p0[1]), (midx, p1[1]), p1]

    def _lod(self) -> str:
        """Zoom level of detail: what a caption can afford to show."""
        if self._zoom < 0.75:
            return "coarse"
        if self._zoom > 1.6:
            return "fine"
        return "normal"

    def _peek(self, what: str, *args) -> str:
        """Cached live peek. Returns "" when this runtime has no such view."""
        if self._peek_fn is None:
            return ""
        key = (what, args)
        now = time.monotonic()
        hit = self._peek_cache.get(key)
        if hit is not None and now - hit[0] < self._peek_ttl:
            return hit[1]
        try:
            val = self._peek_fn(what, *args) or ""
        except Exception as e:
            val = f"(peek failed: {e})"
        self._peek_cache[key] = (now, val)
        return val

    def _peek_block(self, title: str, what: str, *args) -> str:
        """`title` + one peek line, or a clear note that the view is missing."""
        body = self._peek(what, *args)
        if not body:
            return f"\n{title}\n  (not available on {self._runtime})\n"
        return f"\n{title}\n  {body}\n"

    def _eng_caption(self, label: str, *fields) -> str:
        """Engine box: title line plus whichever counters this runtime has.

        PYTHON has no dihit/swaps/divs and the RTL has no host-side ones, so a
        missing field is dropped rather than printed as a row of em dashes.
        """
        parts = []
        for key, short in fields:
            val = self._snap.get(key)
            if val in (None, "", "—"):
                continue
            parts.append(f"{short} {val}")
        return label + ("\n" + "  ".join(parts) if parts else "")

    _FLASH_MS = 0.45

    def _set(self, key: str, text: str) -> None:
        """Write a block's caption, flashing it when the value actually moved.

        Ported from the BASIC monitor: a counter that ticks past you is easy to
        miss, and IP / sp / heap change far faster than the eye tracks.
        """
        if key not in self.blocks:
            return
        item = self.blocks[key][1]
        prev = self._prev_reg_vals.get(key)
        if prev is not None and prev != text:
            self._reg_flash_until[key] = time.monotonic() + self._FLASH_MS
        self._prev_reg_vals[key] = text
        self.canvas.itemconfigure(item, text=text)
        until = self._reg_flash_until.get(key, 0.0)
        now = time.monotonic()
        if until > now:
            t = (until - now) / self._FLASH_MS
            self.canvas.itemconfigure(item, fill=_blend(PHOSPHOR_HI, VALUE_FG, t))
        elif until:
            self._reg_flash_until.pop(key, None)
            self.canvas.itemconfigure(item, fill=VALUE_FG)

    def _g(self, key: str, default="—"):
        snap = self._snap
        if key not in snap or snap[key] in (None, ""):
            return default
        return snap[key]

    def _heat_of(self, key: str) -> float:
        stamped = self._heat_stamp.get(key)
        decayed = 0.0
        if stamped is not None:
            decayed = max(0.0, min(1.0, 1.0 - (time.monotonic() - stamped) / 0.8))
        return max(decayed, self._prof_heat.get(key, 0.0))

    def _wire_heat(self, key: str) -> float:
        """Map a wire's tag to the block(s) that should light it."""
        aliases = {
            "NATIVE2": ("NATIVE",),
            "ARB_MEM": ("ARBITER",),
            "MEM": ("ARBITER", "M_BRAM", "M_SRAM"),
            "CODE_BRAM": ("COMPILER", "M_BRAM", "SEQUENCER"),
            "CODE_ASET": ("COMPILER", "M_SRAM", "BLIT"),
            "FETCH": ("SEQUENCER", "M_BRAM"),
            "BLIT_SRAM": ("BLIT", "M_SRAM", "ARBITER"),
            "FB_BUS": ("CANVAS", "VIDEO", "M_BRAM"),
            "HDMI_PHY": ("HDMI", "PHY_HDMI", "VIDEO"),
            "KBD": ("PHY_PS2", "CONSOLE"),
            "SD_PHY": ("SD", "PHY_SD", "STORE", "M_SDCARD"),
            "JOY": ("PHY_JOY", "RAF"),
            "UART_PHY": ("UART", "PHY_UART"),
            "ENG_ARB": ("ARBITER", "ALU", "CANVAS", "BLIT", "VIDEO"),
        }
        names = aliases.get(key, (key,))
        return max(self._heat_of(n) for n in names)

    def update(self, *, runtime: str = "PYTHON", snap: dict | None = None,
               line_buf: str = "", peek=None, decode=None) -> None:
        if runtime != self._runtime:
            # Peeks and the execution trace describe the machine that produced
            # them; carrying either across F9 into another runtime's panel
            # would be a lie.
            self._peek_cache.clear()
            self._replay = []
            self._replay_ip = None
        self._runtime = runtime
        self._peek_fn = peek
        self._decode_fn = decode
        self._snap = dict(snap or {})
        self._line_buf = line_buf or ""
        now = time.monotonic()
        sname = str(self._g("sname", "IDLE"))
        running = bool(self._snap.get("running"))
        # Walk the executed-IP trace and let the schematic follow it, so the
        # sequencer shows code that really ran instead of the one park point
        # every between-frames sample lands on.
        rip = self._advance_replay(self._snap.get("ip_ring"), running)
        if rip is not None and self._decode_fn is not None:
            info = {}
            try:
                info = self._decode_fn(rip) or {}
            except Exception:
                info = {}
            if info:
                self._snap["ip"] = rip
                self._snap.update(info)
        for key in _sname_keys(sname):
            self._heat_stamp[key] = now
        op_name = str(self._snap.get("op_name") or "")
        nname_live = str(self._snap.get("native_name") or "")
        # NEW: follow the opcode actually executing (not a blanket Canvas glow)
        if running:
            for key in _op_engine_keys(op_name, nname_live):
                self._heat_stamp[key] = now
        if self._line_buf or self._snap.get("more"):
            self._heat_stamp["CONSOLE"] = now
        if runtime == "BOARD":
            self._heat_stamp["PHY_HDMI"] = now
            if self._snap.get("tether"):
                self._heat_stamp["PHY_UART"] = now
        # NEW: real keystroke reaching the machine (gui_jmr_js.py, every
        # runtime) — was previously dark on BOARD in practice because the
        # RTL's own S_KEYEV dispatch state is one cycle wide against a
        # ~0.67s V-line heartbeat; this stamps on every actual keypress.
        kbd_t = self._snap.get("kbd_last_t")
        if isinstance(kbd_t, (int, float)) and \
                kbd_t > self._heat_stamp.get("PHY_PS2", 0.0):
            self._heat_stamp["PHY_PS2"] = kbd_t
        # Activity-weighted heat floor: the RTL's own cycle histogram, or the
        # native histogram PYTHON collects for the same purpose.
        if not running:
            self._prof_heat = {}
        else:
            self._prof_heat = _prof_keys(str(self._snap.get("prof") or ""))
            for key, val in _native_hist_keys(self._snap.get("natives") or {}).items():
                if val > self._prof_heat.get(key, 0.0):
                    self._prof_heat[key] = val

        # Packet dots: their departures/arrivals also light blocks, so tick
        # them before the fill pass or a dot lands on an unlit box.
        if self.packets_enabled:
            self.packets.observe(op_name, nname_live)
            self.packets.tick(
                self._packet_waypoints, stage_heat=self._packet_stage_heat,
            )
            for key, stamp in self._packet_stage_heat.items():
                if stamp > self._heat_stamp.get(key, 0.0):
                    self._heat_stamp[key] = stamp
        for key, (rect, _value) in self.blocks.items():
            self.canvas.itemconfigure(
                rect, fill=_blend(BLOCK_ACTIVE, BLOCK_IDLE, self._heat_of(key)),
            )
        for key, _label in self.ENGINES:
            self._set_bar(key, self._heat_of(key))
        self.sd_list.configure(
            bg=_blend(BLOCK_ACTIVE, BLOCK_IDLE, self._heat_of("SD")),
        )
        self._sync_sd_window()
        for line, key, kind, idle in self.wires:
            wkey = key[2:] if key.startswith("S_") else key
            heat = self._wire_heat(wkey)
            hot = "#66aaff" if kind == "code" else PHOSPHOR
            self.canvas.itemconfigure(line, fill=_blend(hot, idle, heat))

        ip = self._g("ip")
        sp = self._g("sp")
        raf = self._g("raf")
        self._set("UART", f"{runtime}\nPROG tether")
        buf = self._line_buf[-18:] if self._line_buf else ""
        self._set("CONSOLE", f"line: {buf!r}" if buf else "line: ''")
        src = self._g("source_name", "")
        nops = self._g("n_ops", "")
        nhtml = self._g("n_html", "")
        phase = str(self._snap.get("phase") or "")
        try:
            nops_i = int(nops)
        except (TypeError, ValueError):
            nops_i = 0
        try:
            nhtml_i = int(nhtml)
        except (TypeError, ValueError):
            nhtml_i = 0
        if phase == "compile":
            comp_live = "compiling"
        elif nops_i > 0:
            comp_live = f"{nops_i} ops"
        elif nhtml_i > 0:
            comp_live = f"{nhtml_i} lines  (RUN compiles)"
        else:
            comp_live = "LOAD HTML then RUN"
        self._set("COMPILER", f"{src or 'no HTML'}\n{comp_live}")
        src_line = self._g("src_line")
        seq_l2 = f"IP {_dash(ip)}"
        if src_line not in ("", "—", 0, "0"):
            seq_l2 += f"  L{src_line}"
        head = sname
        if self._replay_ip is not None:
            # Say what this is. The IP is real and was really executed, but it
            # is a replay of the last frame, not where the VM sits right now —
            # REGISTERS keeps the true parked values. The op at that IP is the
            # useful headline; the park state would contradict it.
            seq_l2 += "  ▶trace"
            head = str(self._g("op_name", "")) or sname
        seq = f"{head}\n{seq_l2}"
        lod = self._lod()
        if lod == "fine":
            # Zoomed in there is room for the line the op compiled from.
            html_line = str(self._g("html_line") or "").strip()
            note = _state_note(sname)
            if note:
                seq += f"\n{note}"
            if html_line:
                seq += f"\n{html_line[:42]}"
        elif lod == "coarse":
            seq = f"{sname}\n{_dash(ip)}"
        self._set("SEQUENCER", seq)
        op_name = self._g("op_name", "")
        self._set(
            "DISPATCH",
            (f"→ {op_name}\n{N_OPCODES} opcodes" if op_name not in ("", "—")
             else f"{N_OPCODES} opcodes\nidle"),
        )
        depth = self._g("stack_depth", sp)
        self._set("STACK", f"sp {depth}\n{STACK_SLOTS} tagged")
        # envl is the live env count; esp/efree are the RTL's stack pointer and
        # free-list head, which read 0 all through a run and looked like a dead
        # engine in the old "env 0 free 0" caption.
        env_live = self._g("envl", self._g("esp"))
        self._set(
            "HEAP",
            f"obj {self._g('obj')}  arr {self._g('arr')}\nenv {env_live}",
        )
        nid = self._g("native_id", "")
        nname = self._g("native_name", "")
        if nname not in ("", "—"):
            self._set(
                "NATIVE",
                f"CALL_NATIVE {nid}\n{nname}" if nid not in ("", "—")
                else f"CALL_NATIVE\n{nname}",
            )
        else:
            # IP parks off the call while the VM waits inside a native, so the
            # box names the native the state is parked in rather than going
            # blank for the whole run.
            pname, pid = _state_native(sname)
            if pname:
                self._set("NATIVE", f"in CALL_NATIVE {pid}\n{pname}")
            else:
                self._set("NATIVE", f"CALL_NATIVE  {len(NATIVE_IDS)} ids\nidle")
        # Engine captions carry live counters, not labels — the panel says LIVE.
        # A counter this runtime does not publish is left off instead of "—".
        self._set("ALU", self._eng_caption("Σ", ("divs", "divs")))
        self._set("CANVAS", self._eng_caption(
            "fillRect", ("dihit", "di hit"), ("imgd", "imgd"),
        ))
        self._set("BLIT", self._eng_caption("drawImage", ("spr", "spr")))
        self._set("RAF", f"rAF {raf}\nto {self._g('ton')}  ev {self._g('lsn')}")
        self._set("STR", self._eng_caption("join / JSON", ("strb", "strb")))
        self._set(
            "CONS_ENG",
            "MORE" if self._snap.get("more") else ("RUN" if running else "READY"),
        )
        self._set("STORE", f"FAT32\n{len(self._snap.get('catalog') or [])} files")
        self._set("VIDEO", self._eng_caption("640×480", ("swaps", "swaps")))
        self._set("ARBITER", "port")
        mode = self._g("hdmi_mode", "letterbox")
        self._set(
            "M_BRAM",
            f"code+heap+FB\nHDMI {mode}",
        )
        sram_b = self._g("sram_bytes", "")
        spr = self._g("spr")
        if sram_b not in ("", "—") and str(sram_b) != "0":
            self._set("M_SRAM", f"spr {spr}\nASET {sram_b} B")
        else:
            self._set(
                "M_SRAM",
                f"spr {spr}\n0x300+ banks",
            )
        ncat = len(self._snap.get("catalog") or [])
        self._set("M_SDCARD", f"{ncat} files\nHTML titles")
        if mode == "game" or running:
            self._set("HDMI", "RUN  full field\n640×480 game FB")
        else:
            self._set("HDMI", "READY letterbox\n64×16 on 640×480")
        if self._snap.get("board_coarse"):
            # BOARD is a UART tether with no VMSTAT — say the counters are
            # unavailable rather than letting em dashes read as zeros.
            self._set("REGS", f"{sname}\ncoarse tether\nno VMSTAT")
        else:
            self._set(
                "REGS",
                f"{sname}\nip {ip}  sp {sp}\nraf {raf}",
            )
        self._set(
            "HSTATS",
            f"obj {self._g('obj')}  arr {self._g('arr')}\n"
            f"spr {self._g('spr')}  strb {self._g('strb')}",
        )
        if runtime == "PYTHON":
            self._set("PHY_PS2", "sim only\n(no board)")
            self._set("PHY_HDMI", "sim glass\n640×480")
            self._set("PHY_UART", "sim only\n(no USB)")
            self._set("PHY_JOY", "GUI arrows\nKEYBITS")
            self._set("PHY_SD", "card.img\non host")
        elif runtime == "BOARD":
            tether = "tether OK" if self._snap.get("tether") else "no tether"
            self._set("PHY_PS2", "J15 dead\nGUI tether")
            self._set("PHY_HDMI", "monitor\n640×480")
            self._set("PHY_UART", f"PROG FT245\n{tether}")
            self._set("PHY_JOY", "Pmod 6-bit\nor KEYBITS")
            self._set("PHY_SD", "J1 slot\nSPI FAT")
        else:
            self._set("PHY_PS2", "USB/PS2 FIFO\nHTML bindings")
            self._set("PHY_HDMI", "RTL scanout\n640×480")
            self._set("PHY_UART", "sim RTL\nno USB")
            self._set("PHY_JOY", "KEYBITS\n6-bit joy")
            self._set("PHY_SD", "card.img\nSPI model")

        cat = list(self._snap.get("catalog") or [])
        body = "\n".join(cat[:40]) if cat else "(empty card)"
        if body != self._sd_list_text:
            self._sd_list_text = body
            self.sd_list.configure(state="normal")
            self.sd_list.delete("1.0", "end")
            self.sd_list.insert("1.0", body)
            self.sd_list.configure(state="disabled")

        fclk = self._g("fclk", "")
        fclk_s = f"  fclk {fclk}" if fclk not in ("", "—") else ""
        if self._faulted():
            # F-line forensics (run 60+): name the failing allocator and its
            # at-fault pool counts right on the main window — the headline
            # fact should not require opening an inspector.
            forensic = ""
            if "board_fault_kind_name" in self._snap:
                forensic = (
                    f" [{self._g('board_fault_kind_name')} alloc — pools "
                    f"env {self._g('board_fault_env')} "
                    f"arr {self._g('board_fault_arr')} "
                    f"obj {self._g('board_fault_obj')}]"
                )
            heat_src = (
                f"FAULT {self._g('fault')} at IP {_dash(ip)} "
                f"(L{self._g('src_line')}){forensic} — click REGISTERS"
            )
        elif self._snap.get("board_coarse"):
            heat_src = "heat: coarse (BOARD tether — no VMSTAT)"
        elif self._snap.get("prof"):
            heat_src = "heat: RTL cycle profile"
        elif self._snap.get("natives"):
            heat_src = "heat: native calls / frame"
        else:
            heat_src = "heat: state only"
        self.canvas.itemconfigure(
            self.status_text,
            text=(
                f"{runtime}  {sname}  ip {_dash(ip)}  raf {_dash(raf)}"
                f"{fclk_s}  ·  {heat_src}"
            ),
        )
        if self.packets_enabled and self.packets.caption:
            path = self.packets.caption
        elif self.packets_enabled:
            path = "packets ON (A) — waiting for an op"
        else:
            path = (
                "storage: NAME.HTML titles · compile-on-RUN in memory "
                "(code + ASET) · A = animate data path"
            )
        self.canvas.itemconfigure(self.path_text, text=path)
        self._refresh_inspector()

    # -- click inspector ---------------------------------------------------

    def _on_canvas_click(self, event) -> None:
        x = self.canvas.canvasx(event.x)
        y = self.canvas.canvasy(event.y)
        hit = None
        best_area = None
        for key, (rect, _val) in self.blocks.items():
            try:
                x0, y0, x1, y1 = self.canvas.coords(rect)
            except Exception:
                continue
            if x0 <= x <= x1 and y0 <= y <= y1:
                area = abs(x1 - x0) * abs(y1 - y0)
                if best_area is None or area < best_area:
                    best_area = area
                    hit = key
        if hit is None:
            return
        if hit == self.inspect_key:
            self._page_probe(hit)
        elif hit in ("HEAP", "HSTATS"):
            # Open on something worth reading — slot 0 is usually a hole, and
            # an "empty slot" first impression reads as a broken panel.
            if "empty slot" in (self._peek("obj", self._probe_obj) or ""):
                self._probe_obj = self._next_live_slot("obj", self._probe_obj, MAX_OBJECTS)
            if "empty slot" in (self._peek("arr", self._probe_arr) or ""):
                self._probe_arr = self._next_live_slot("arr", self._probe_arr, MAX_ARRAYS)
        self._select_block(hit)
        self._show_inspector()
        self._refresh_inspector(force=True)

    def _page_probe(self, key: str) -> None:
        """Clicking the already-selected block advances its peek window.

        One slot per peek keeps a drill-down at one RPC; paging is how you walk
        the heap or the asset bank without the panel fetching all of it.
        """
        if key in ("HEAP", "HSTATS"):
            self._probe_obj = self._next_live_slot("obj", self._probe_obj, MAX_OBJECTS)
            self._probe_arr = self._next_live_slot("arr", self._probe_arr, MAX_ARRAYS)
        elif key == "M_SRAM":
            self._probe_sram = (self._probe_sram + 64) % (4 * 1024 * 1024)
        self._peek_cache.clear()

    def _next_live_slot(self, what: str, cur: int, cap: int) -> int:
        """Next slot that actually holds something, so paging skips the holes."""
        if not cap:
            return 0
        for step in range(1, min(cap, 512) + 1):
            nxt = (cur + step) % cap
            body = self._peek(what, nxt)
            if body and "empty slot" not in body and "not available" not in body:
                return nxt
        return (cur + 1) % cap

    def _select_block(self, key: str) -> None:
        prev = self.inspect_key
        self.inspect_key = key
        if prev and prev in self.blocks:
            self.canvas.itemconfigure(
                self.blocks[prev][0], outline=BLOCK_OUTLINE, width=1,
            )
        if key in self.blocks:
            self.canvas.itemconfigure(
                self.blocks[key][0], outline=BLOCK_SELECT, width=2,
            )

    def _show_inspector(self) -> None:
        if self._inspector is not None and self._inspector.winfo_exists():
            self._inspector.deiconify()
            self._inspector.lift()
            return
        win = tk.Toplevel(self.window)
        win.title("JMR INSPECTOR")
        win.configure(bg=ARCH_BG)
        win.geometry("720x520")
        win.protocol("WM_DELETE_WINDOW", win.withdraw)
        frame = tk.Frame(win, bg=ARCH_BG)
        frame.pack(fill="both", expand=True, padx=8, pady=8)
        text = tk.Text(
            frame, bg=BLOCK_IDLE, fg=VALUE_FG, insertbackground=VALUE_FG,
            font=self.small_font, wrap="word", bd=0, highlightthickness=1,
            highlightbackground=BLOCK_OUTLINE, padx=8, pady=8,
        )
        scroll = tk.Scrollbar(frame, command=text.yview)
        text.configure(yscrollcommand=scroll.set, state="disabled")
        scroll.pack(side="right", fill="y")
        text.pack(side="left", fill="both", expand=True)
        self._inspector = win
        self._inspector_text = text
        self._inspect_body = ""

    def _refresh_inspector(self, *, force: bool = False) -> None:
        if self.inspect_key is None:
            return
        if self._inspector is None or not self._inspector.winfo_exists():
            return
        try:
            if self._inspector.state() == "withdrawn" and not force:
                return
        except tk.TclError:
            return
        body = self._inspector_body(self.inspect_key)
        if body == self._inspect_body and not force:
            return
        text = self._inspector_text
        assert text is not None
        yview = text.yview()
        self._inspect_body = body
        text.configure(state="normal")
        text.delete("1.0", "end")
        text.insert("1.0", body)
        text.configure(state="disabled")
        try:
            text.yview_moveto(yview[0])
        except Exception:
            pass
        if self._inspector is not None:
            self._inspector.title(f"JMR INSPECTOR — {self.inspect_key}")

    def _hdr(self, title: str) -> str:
        return f"{title}\n{'─' * 52}\n"

    def _live_kv(self) -> str:
        keys = (
            "sname", "state", "ip", "eip", "sp", "raf", "obj", "arr", "envl",
            "spr", "ton", "lsn", "esp", "efree", "gc", "fclk", "strb", "swaps",
            "dihit", "dimiss", "tfire", "tsch", "tmis", "divs", "imgd",
            "heapovf", "jsonovf", "spovf", "strovf", "fault", "fsite", "badst",
            "running", "hdmi_mode", "source_name", "n_ops", "n_consts",
            "n_vars", "flags", "n_html", "sram_bytes", "op_name", "op_arg",
            "native_id", "native_name",
            "phase", "src_line", "last_cmd", "html_line",
        )
        parts = []
        for k in keys:
            if k in self._snap:
                parts.append(f"  {k:12} {_dash(self._snap.get(k))}")
        return "\n".join(parts) if parts else "  (no live fields this runtime)"

    def _inspector_body(self, key: str) -> str:
        if key == "SEQUENCER":
            return self._inspect_sequencer()
        if key == "DISPATCH":
            return self._inspect_dispatch()
        if key == "STACK":
            return self._inspect_stack()
        if key == "HEAP" or key == "HSTATS":
            return self._inspect_heap()
        if key == "NATIVE":
            return self._inspect_native()
        if key == "COMPILER":
            return self._inspect_compiler()
        if key == "CONSOLE":
            return self._inspect_console()
        if key == "UART" or key == "PHY_UART":
            return self._inspect_uart()
        if key == "REGS":
            return self._inspect_regs()
        if key == "HDMI" or key == "PHY_HDMI":
            return self._inspect_hdmi()
        if key == "SD" or key == "M_SDCARD" or key == "PHY_SD":
            return self._inspect_sd()
        if key in self.ENGINE_BLURBS:
            return self._inspect_engine(key)
        if key in self.MEMORY_BLURBS:
            return self._inspect_memory(key)
        if key in self.STAGE_BLURBS:
            return self._hdr(self.STAGE_BLURBS[key]) + "\n" + self._live_kv() + "\n"
        if key.startswith("PHY_"):
            return self._inspect_phy(key)
        return f"{key}\n\n(no detail panel yet)\n"

    def _inspect_sequencer(self) -> str:
        magic = MAGIC.decode("ascii", errors="replace")
        code_win = str(self._snap.get("code_window") or "")
        html_win = str(self._snap.get("html_window") or "")
        html_line = str(self._g("html_line") or "")
        note = _state_note(str(self._g("sname", "")))
        body = (
            self._hdr("PROGRAM SEQUENCER — fetch unit")
            + "16-bit IP. Fetches 32-bit op-words from code BRAM:\n"
            "  op = { arg1[31:24], arg0[23:8], opcode[7:0] }\n"
            f"ProgramImage / {magic} header: n_ops, n_consts, n_vars, flags.\n"
            "Bytecode is the ISA — no hidden CPU, no V8/dukpy.\n"
            "Analog of BASIC PCU LINE/tokens: IP + HTML line the op compiled from.\n\n"
            f"runtime     {self._runtime}\n"
            f"phase       {self._g('phase')}\n"
            f"sname       {self._g('sname')}"
            + (f"   ({note})\n" if note else "\n")
            + f"IP          {self._g('ip')}\n"
            f"opcode      {self._g('op_name')}  arg0 {self._g('op_arg')}\n"
            f"native      {self._g('native_name')}  (id {self._g('native_id')})\n"
            f"n_ops       {_cap(self._g('n_ops'), CODE_WORDS)}  code words\n"
            f"n_consts    {_cap(self._g('n_consts'), MAX_CONSTS)}\n"
            f"n_vars      {_cap(self._g('n_vars'), MAX_VARS)}\n"
            f"flags       {_flag_names(self._snap.get('flags'))}\n"
            f"source      {self._g('source_name', '(none)')}\n"
            f"HTML line   {self._g('src_line')}   {html_line[:80]}\n"
        )
        body += self._fault_block()
        if html_win:
            body += "\nHTML around IP\n" + html_win + "\n"
        if code_win:
            body += "\nbytecode around IP\n" + code_win + "\n"
        return body

    def _inspect_dispatch(self) -> str:
        cur = str(self._g("op_name", "") or "")
        rows = ["opcode  name", "------  ----------------"]
        for op in sorted(Op, key=lambda o: int(o)):
            mark = "→" if cur and op.name == cur else " "
            rows.append(f"{mark} {int(op):02X}    {op.name}")
        return (
            self._hdr("DISPATCH TABLE — opcode → engine")
            + f"{N_OPCODES} opcodes. CALL_NATIVE (0D) is the FM name; RTL OP_CALL\n"
            "is the same instruction (name-table index in arg0).\n"
            f"now: {self._g('op_name')}  native {self._g('native_name')}\n\n"
            + "\n".join(rows)
            + "\n"
        )

    def _inspect_stack(self) -> str:
        preview = self._g("stack_preview", "")
        return (
            self._hdr("TAGGED EVAL STACK")
            + f"{STACK_SLOTS} entries. A VALUE64 image stores each slot as one\n"
            "64-bit NaN-boxed Value; legacy 32-bit images use value + tag.\n"
            "Tags: num, str, obj, arr, fn, undef, null, elem, env.\n"
            f"VARS: {MAX_VARS} tagged slots. CONST POOL: {MAX_CONSTS} slots\n"
            "(interned strings, IEEE-754 floats, packed RegExp).\n\n"
            f"sp / depth  {_cap(self._g('stack_depth', self._g('sp')), STACK_SLOTS)}\n"
            f"top of stack {preview or '—'}\n"
            + self._peek_block("live stack", "stack")
            + self._peek_block("variable slots", "vars", 0, 24)
        )

    def _inspect_heap(self) -> str:
        return (
            self._hdr("OBJECT / HEAP ENGINE")
            + "Stable slots with a 12-bit generation — a slot never moves,\n"
            "and a stale handle fails the generation check instead of\n"
            "dereferencing someone else's object.\n"
            "Closures survive after return: setTimeout / requestAnimationFrame.\n\n"
            f"obj    {_cap(self._g('obj'), MAX_OBJECTS)}\n"
            f"arr    {_cap(self._g('arr'), MAX_ARRAYS)}\n"
            f"env    {_cap(self._g('envl', self._g('esp')), ENV_DEPTH)}\n"
            f"spr    {self._g('spr')}    strings {self._g('strb')}\n"
            f"esp {self._g('esp')}   efree {self._g('efree')}   gc {self._g('gc')}\n"
            f"heapovf {self._g('heapovf')}   jsonovf {self._g('jsonovf')}   "
            f"spovf {self._g('spovf')}\n"
            f"fault   {self._g('fault')}\n"
            + self._peek_block("allocator", "gc")
            + self._peek_block("env chain", "env")
            + self._peek_block("functions", "fn", 0)
            + self._peek_block(f"object slot {self._probe_obj}", "obj", self._probe_obj)
            + self._peek_block(f"array slot {self._probe_arr}", "arr", self._probe_arr)
            + "\n(click OBJECT / HEAP again to step to the next live slot)\n"
        )

    def _inspect_native(self) -> str:
        rows = [f"  {nid:3}  {name}" for name, nid in sorted(NATIVE_IDS.items(), key=lambda kv: kv[1])]
        return (
            self._hdr("NATIVE CALL UNIT — CALL_NATIVE id table")
            + f"{len(NATIVE_IDS)} ids resolved at compile time. CALL_NATIVE arg0 is an\n"
            "index into the image name table; canvas work arrives as ctx.*\n"
            "method natives, which are engine calls rather than JSB ids.\n\n"
            + "\n".join(rows)
            + f"\n\nat IP  {self._g('native_name')}  (id {self._g('native_id')})\n"
        )

    def _inspect_compiler(self) -> str:
        html_win = str(self._snap.get("html_window") or "")
        body = (
            self._hdr("COMPILE-ON-RUN FRONT END")
            + "Lexer → Parser → Bytecode generator.\n"
            "LOAD \"NAME.HTML\" then RUN always recompiles the current HTML\n"
            "into an in-memory ProgramImage (code + ASET art).\n"
            "Code → code BRAM. ASET → external SRAM asset bank.\n"
            "Compile errors use HTML line numbers.\n"
            "Missing compile path → fail loud (?NH), never fake output.\n\n"
            f"phase        {self._g('phase')}\n"
            f"last command {self._g('last_cmd')!r}\n"
            f"loaded HTML  {self._g('source_name', '(none)')}\n"
            f"HTML lines   {self._g('n_html')}\n"
            f"n_ops        {self._g('n_ops')}   n_consts {self._g('n_consts')}\n"
            f"ASET bytes   {self._g('sram_bytes')}   sprites {self._g('spr')}\n"
            f"runtime      {self._runtime}\n"
        )
        if html_win:
            body += "\nHTML (editor buffer)\n" + html_win + "\n"
        return body

    def _inspect_console(self) -> str:
        glass = str(self._snap.get("glass") or "")
        last = ""
        for ln in reversed(glass.splitlines()):
            if ln.strip():
                last = ln.strip()
                break
        return (
            self._hdr("CONSOLE / LINE EDITOR")
            + "Monitor verbs: READY · LOAD · RUN · DIR · EDIT · LIST.\n"
            "LIST parks on -- MORE -- (Space pages). Line numbers = HTML.\n\n"
            f"typed line   {self._line_buf!r}\n"
            f"last command {self._g('last_cmd')!r}\n"
            f"MORE         {bool(self._snap.get('more'))}\n"
            f"last glass   {last[:120] or '—'}\n"
        )

    def _inspect_uart(self) -> str:
        return (
            self._hdr("UART / PROG TETHER")
            + "Nexys Video PROG FT245 (channel A) is a debug mirror / KEYBITS\n"
            "path, not the product keyboard. Product keys: USB/PS/2 FIFO;\n"
            "this board's J15 USB Host is dead — GUI tether until RMA.\n\n"
            f"runtime  {self._runtime}\n"
            f"tether   {_dash(self._snap.get('tether'), 'n/a')}\n"
        )

    def _faulted(self) -> bool:
        """True when the VM stopped on a fault rather than finishing."""
        for key in ("fault", "efault", "heapovf", "jsonovf", "spovf",
                    "cspovf", "toovf", "strovf", "pathovf"):
            val = self._snap.get(key)
            if val in (None, "", 0, "0", "—"):
                continue
            return True
        return False

    def _fault_block(self) -> str:
        """Post-mortem: what stopped, where, and the run-up to it.

        The RTL freezes its cycle ring on fault, so VRING? replays the last
        states and IPs before the stop — the closest thing to a stack trace
        this machine has. Only fetched once something has actually faulted.
        """
        if not self._faulted():
            return ""
        rows = [
            "",
            "!! FAULT — VM stopped",
            "─" * 52,
            f"fault {self._g('fault')}   ecode {self._g('ecode')}   "
            f"efault {self._g('efault')}",
            f"fsite {self._g('fsite')}   bad state {self._g('badst')}",
            f"IP {self._g('ip')}  (eip {self._g('eip')})   "
            f"HTML line {self._g('src_line')}",
            f"overflow: heap {self._g('heapovf')}  json {self._g('jsonovf')}  "
            f"stack {self._g('spovf')}  call {self._g('cspovf')}  "
            f"timer {self._g('toovf')}  str {self._g('strovf')}  "
            f"path {self._g('pathovf')}",
        ]
        line = str(self._g("html_line") or "")
        if line.strip():
            rows.append(f"source: {line.strip()[:88]}")
        if "board_fault_kind_name" in self._snap:
            state = self._snap.get("board_fault_state")
            state_str = f"0x{state:02X}" if isinstance(state, int) else self._g("board_fault_state")
            rows.append("")
            rows.append("BOARD run-60+ fault forensics (F-line):")
            rows.append(
                f"  kind {self._g('board_fault_kind_name')}   "
                f"retried {self._g('board_fault_retried')}   state {state_str}"
            )
            rows.append(
                f"  vcsp {self._g('board_fault_vcsp')}   "
                f"vsp {self._g('board_fault_vsp')}"
            )
            rows.append(
                f"  pools at fault — env {self._g('board_fault_env')}  "
                f"arr {self._g('board_fault_arr')}  obj {self._g('board_fault_obj')}"
            )
        trail = self._snap.get("board_ip_trail")
        if trail:
            hexips = ", ".join(f"{ip:04X}" for ip in trail)
            rows.append("BOARD approach path (T-line, newest first):")
            rows.append(f"  {hexips}")
        body = "\n".join(rows) + "\n"
        body += self._peek_block("cycle ring before the fault", "ring")
        body += self._peek_block("pixel counters", "px")
        win = str(self._snap.get("code_window") or "")
        if win:
            body += "\nbytecode at the stop\n" + win + "\n"
        return body

    def _inspect_regs(self) -> str:
        body = self._hdr("REGISTERS / VMSTAT") + f"runtime  {self._runtime}\n"
        if self._snap.get("board_coarse"):
            body += (
                "\nBOARD is a coarse UART tether: it mirrors the glass and\n"
                "reports whether a framebuffer is arriving. There is no VMSTAT\n"
                "over this link, so ip / sp / heap counters are unavailable —\n"
                "not zero. Use FPGA-SIM for per-state detail.\n"
            )
        body += "\n" + self._live_kv() + "\n"
        body += self._fault_block()
        hist = self._snap.get("natives") or {}
        if hist:
            rows = sorted(hist.items(), key=lambda kv: -kv[1])[:14]
            body += (
                "\nnative calls (recent frames)\n"
                + "\n".join(f"  {n:28} {c}" for n, c in rows)
                + "\n"
            )
        prof = str(self._snap.get("prof") or "")
        if prof:
            body += (
                "\nRTL cycle profile (PROF?, last 1 s of play)\n"
                "Where the clocks went — one VMSTAT sname is a single sample\n"
                "at the frame edge and cannot show this.\n"
                + "\n".join("  " + tok for tok in prof.split() if "=" in tok)
                + "\n"
            )
        return body

    def _inspect_hdmi(self) -> str:
        return (
            self._hdr("HDMI OUT 640×480")
            + "Native 640×480 @ ~60 Hz. 8-bpp indexed → 256-entry RGB888 palette.\n"
            "READY = 64×16 letterbox on the same FB. RUN = full-field game.\n"
            "Scanout is from the on-chip FRONT framebuffer — not asset SRAM.\n\n"
            f"mode     {self._g('hdmi_mode')}\n"
            f"running  {self._g('running')}\n"
            f"swaps    {self._g('swaps')}\n"
        )

    def _inspect_sd(self) -> str:
        cat = list(self._snap.get("catalog") or [])
        listing = "\n".join(f"  {n}" for n in cat[:80]) if cat else "  (empty)"
        return (
            self._hdr("microSD / FAT32")
            + "Room C: disk. LOAD names are NAME.HTML.\n"
            "Compile-on-RUN stays in memory (code + ASET).\n\n"
            + listing
            + "\n"
        )

    def _inspect_engine(self, key: str) -> str:
        extra = ""
        if key == "CANVAS":
            extra = (
                f"\ndihit {self._g('dihit')}  dimiss {self._g('dimiss')}  "
                f"imgd {self._g('imgd')}\n"
                f"text  txtn {self._g('txtn')}  txtw {self._g('txtw')}  "
                f"txtmiss {self._g('txtmiss')}  fontpx {self._g('fontpx')}\n"
                f"last rect (x,y,w,h,color,i)  {self._g('vdraw')}\n"
            )
        elif key == "BLIT":
            extra = (
                f"\nspr {self._g('spr')}  (drawImage from asset SRAM)\n"
                f"ASET {self._g('sram_bytes')} B loaded\n"
            )
        elif key == "RAF":
            extra = (
                f"\nraf {self._g('raf')}  ton {self._g('ton')}  "
                f"listeners {self._g('lsn')}\n"
                f"rafcall {self._g('rafcall')}  frames ended {self._g('frend')}\n"
                f"tfire {self._g('tfire')}  tsch {self._g('tsch')}  "
                f"tmis {self._g('tmis')}  toovf {self._g('toovf')}\n"
                f"key  kalloc {self._g('kalloc')}  kcall {self._g('kcall')}  "
                f"kevq {self._g('kevq')}\n"
                + self._peek_block("rAF queue", "raf")
                + self._peek_block("timers", "timers")
                + self._peek_block("key listeners", "listeners")
            )
        elif key == "ALU":
            extra = f"\ndivs {self._g('divs')}\n"
        elif key == "STR":
            extra = (
                f"\ninterned bytes {self._g('strb')}  strovf {self._g('strovf')}\n"
                f"joinmiss {self._g('joinmiss')}  jsonovf {self._g('jsonovf')}\n"
            )
        elif key == "VIDEO":
            extra = (
                f"\nswaps {self._g('swaps')}  hdmi {self._g('hdmi_mode')}  "
                f"fclk {self._g('fclk')}\n"
            )
        elif key == "STORE":
            extra = f"\nfiles {len(self._snap.get('catalog') or [])}\n"
        elif key == "CONS_ENG":
            extra = (
                f"\nlast command {self._g('last_cmd')!r}  "
                f"MORE {bool(self._snap.get('more'))}\n"
            )
        return (
            self._hdr(self.ENGINE_BLURBS[key])
            + f"runtime {self._runtime}   heat (0..1): {self._heat_of(key):.2f}\n"
            + extra
        )

    def _inspect_memory(self, key: str) -> str:
        extra = ""
        if key == "M_BRAM":
            extra = (
                f"\nhdmi {self._g('hdmi_mode')}  strb {self._g('strb')}\n"
                f"code  {_cap(self._g('n_ops'), CODE_WORDS)} words\n"
                + self._peek_block("variable slots", "vars", 0, 24)
                + self._peek_block("bytecode at IP", "ring")
            )
            win = str(self._snap.get("code_window") or "")
            if win:
                extra += "\ndisassembly around IP\n" + win + "\n"
        elif key == "M_SRAM":
            base = self._probe_sram
            extra = (
                f"\nspr {self._g('spr')}  ASET {self._g('sram_bytes')} B\n"
                "pixels never enter code BRAM\n"
                f"\n0x000000-0x0002FF is the {ASET_PAL_ENTRIES}-entry RGB888 title\n"
                "palette; sprite banks start at 0x000300.\n"
                + self._peek_block(f"hex @ byte {base} (0x{base:06x})", "sram", base, 64)
                + "\n(click ASSET SRAM again to page +64 bytes)\n"
            )
        elif key == "M_SDCARD":
            cat = list(self._snap.get("catalog") or [])
            extra = (
                f"\nfiles {len(cat)}\n"
                + ("\n".join(f"  {n}" for n in cat[:40]) + "\n" if cat else "")
            )
        return self._hdr(self.MEMORY_BLURBS[key]) + extra

    def _inspect_phy(self, key: str) -> str:
        blurbs = {
            "PHY_PS2": (
                "Keyboard — USB/PS/2 raw keycodes into the Input FIFO.\n"
                "The HTML decides bindings (no hardcoded title key maps).\n"
                "This Nexys Video J15 USB Host is dead; GUI tether until fixed."
            ),
            "PHY_JOY": (
                "Pmod joystick — 6-bit GPIO into the same INPUT path.\n"
                "GUI arrows+Space → KEYBITS while a game owns the glass."
            ),
        }
        return self._hdr(blurbs.get(key, key)) + f"\nruntime {self._runtime}\n"
