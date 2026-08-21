"""Pluggable runtime backends for the JMR JS GUI (BASIC method, JS product).

Pattern cite: JMR-BASIC-FPGA-COMPUTER/runtime/backend.py
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[1]
CARD_IMG = ROOT / "card.img"
STORAGE_DIR = ROOT / "storage"


def parse_status_kv(line: str) -> dict:
    """Parse `VMSTAT k=v …` / `STATUS k=v …`. Unknown tokens ignored."""
    out: dict = {}
    if not line:
        return out
    for tok in str(line).split():
        if "=" not in tok:
            continue
        k, v = tok.split("=", 1)
        if not k:
            continue
        if v.isdigit() or (v.startswith("-") and v[1:].isdigit()):
            try:
                out[k] = int(v)
                continue
            except ValueError:
                pass
        out[k] = v
    return out


def card_catalog(extra: list[str] | None = None) -> list[str]:
    """HTML/JS titles from storage/ (no compile sidecars)."""
    names: list[str] = []
    seen: set[str] = set()
    for n in extra or []:
        if n and n not in seen:
            seen.add(n)
            names.append(n)
    if STORAGE_DIR.is_dir():
        for p in sorted(STORAGE_DIR.iterdir()):
            if not p.is_file() or p.name.startswith("."):
                continue
            if p.suffix.upper() in (".HTML", ".HTM", ".JS") and p.name not in seen:
                seen.add(p.name)
                names.append(p.name)
    return names


def _native_name_for_id(nid) -> str:
    try:
        from functional_model.jsb_format import NATIVE_IDS
        n = int(nid)
    except (TypeError, ValueError, ImportError):
        return ""
    for name, i in NATIVE_IDS.items():
        if i == n:
            return name
    return ""


def _native_id_for_name(name: str):
    """NATIVE_IDS / alias id for a name-table entry ('' when it is a user fn)."""
    if not name:
        return ""
    try:
        from functional_model.jsb_format import NATIVE_ALIASES, NATIVE_IDS
    except ImportError:
        return ""
    if name in NATIVE_IDS:
        return NATIVE_IDS[name]
    if name in NATIVE_ALIASES:
        return NATIVE_ALIASES[name]
    # ctx.fillRect and friends are canvas methods, not JSB native ids.
    return ""


def decode_op_at(chunk, ip):
    """(op_name, arg0, native_name, native_id) for chunk.code[ip].

    CALL_NATIVE arg0 is an index into chunk.names in every artifact the
    monitor sees (source Chunk, decoded ProgramImage, and the word image the
    RTL executes) — never a NATIVE_IDS id. Resolving it through NATIVE_IDS
    prints a different native than the one the op actually calls.
    """
    code = getattr(chunk, "code", None) or []
    try:
        ip = int(ip)
    except (TypeError, ValueError):
        return "", "", "", ""
    if not (0 <= ip < len(code)):
        return "", "", "", ""
    op, *args = code[ip]
    op_name = op.name if hasattr(op, "name") else str(op)
    arg0 = args[0] if args else ""
    native_name = ""
    native_id = ""
    if op_name == "CALL_NATIVE":
        names = getattr(chunk, "names", None) or []
        if isinstance(arg0, int) and 0 <= arg0 < len(names):
            native_name = str(names[arg0])
            native_id = _native_id_for_name(native_name)
    return op_name, arg0, native_name, native_id


# Ops whose Chunk arg0 indexes chunk.names. CALL_USER / MAKE_FN / JUMP carry a
# code address instead, and the word image's own LOAD_VAR slots resolve through
# a separate var_names table — annotating either from names[] prints a lie.
_NAME_INDEX_OPS = frozenset((
    "CALL_NATIVE", "CALL_METHOD", "LOAD_VAR", "STORE_VAR", "LET_VAR",
    "GET_PROP", "SET_PROP",
))


def fmt_code_window(chunk, ip, span: int = 5) -> str:
    """Disassemble chunk.code around IP (BASIC detokenize analog)."""
    code = getattr(chunk, "code", None) or []
    if not code:
        return ""
    try:
        ip = int(ip or 0)
    except (TypeError, ValueError):
        ip = 0
    lo = max(0, ip - span)
    hi = min(len(code), ip + span + 1)
    names = getattr(chunk, "names", None) or []
    rows = []
    for i in range(lo, hi):
        op, *args = code[i]
        name = op.name if hasattr(op, "name") else str(op)
        extra = ""
        if args:
            extra = " " + " ".join(str(a) for a in args[:3])
        # arg0 of a name-table op is an index — print what it names.
        if args and name in _NAME_INDEX_OPS:
            a0 = args[0]
            if isinstance(a0, int) and 0 <= a0 < len(names):
                extra += f"   ; {names[a0]}"
        mark = "→" if i == ip else " "
        rows.append(f"{mark} {i:5d}  {name}{extra}")
    return "\n".join(rows)


def fmt_html_window(lines, lineno, span: int = 4) -> str:
    """HTML/JS source around the line the current opcode compiled from."""
    if not lines:
        return ""
    try:
        ln = int(lineno)
    except (TypeError, ValueError):
        return ""
    if ln <= 0:
        return ""
    n = len(lines)
    lo = max(1, ln - span)
    hi = min(n, ln + span)
    rows = []
    for i in range(lo, hi + 1):
        text = lines[i - 1]
        if len(text) > 88:
            text = text[:85] + "…"
        mark = "→" if i == ln else " "
        rows.append(f"{i:5d}{mark} {text}")
    return "\n".join(rows)


def _js_tag(val) -> str:
    if val is None:
        return "undef"
    if isinstance(val, bool) or isinstance(val, int) or isinstance(val, float):
        return "int"
    if isinstance(val, str):
        return "str"
    if isinstance(val, list):
        return "arr"
    if isinstance(val, dict):
        cls = val.get("__class", "")
        if cls == "Fn":
            return "fn"
        if cls in ("Elem", "Element"):
            return "elem"
        return "obj"
    return type(val).__name__[:6]


def _js_short(val, n: int = 24) -> str:
    # NEW: never repr() heap objects — PACMAN stack entries are cyclic/huge
    # and repr() of one dict froze the GUI frame loop after RUN.
    if val is None:
        return "undef"
    if isinstance(val, dict):
        cls = val.get("__class") or "obj"
        return f"{cls}/{len(val)}"
    if isinstance(val, list):
        return f"[{len(val)}]"
    if isinstance(val, str):
        return val if len(val) <= n else val[: n - 1] + "…"
    try:
        s = str(val)
    except Exception:
        return "?"
    if len(s) > n:
        return s[: n - 1] + "…"
    return s


# Only the shares matter for engine heat, so a ceiling costs nothing.
_NAT_HIST_CAP = 1_000_000

_VALUE_KIND_TAGS = {
    1: "undef", 2: "null", 3: "bool", 4: "str", 5: "obj",
    6: "arr", 7: "fn", 8: "elem", 9: "env", 10: "rec",
}


def _value_stack_preview(hw, stack: list[int], n: int = 8) -> str:
    """Top-of-stack tags for the value64 word stack (no repr of heap slots)."""
    try:
        from hardware_model.js_vm import value_is_number, value_kind, value_payload
    except ImportError:
        return ""
    parts = []
    for word in stack[-n:]:
        try:
            if value_is_number(word):
                parts.append("num")
                continue
            kind = value_kind(word)
            tag = _VALUE_KIND_TAGS.get(kind, f"k{kind}")
            if tag == "str":
                strings = getattr(hw, "_value_strings", None) or []
                idx = value_payload(word)
                if 0 <= idx < len(strings):
                    parts.append(f"str:{_js_short(strings[idx], 16)}")
                    continue
            parts.append(f"{tag}:{value_payload(word)}")
        except Exception:
            parts.append("?")
    return ", ".join(parts)


def _val_str(hw, word: int) -> str:
    """One packed Value as `tag:payload`, resolving interned strings."""
    try:
        from hardware_model.js_vm import value_is_number, value_kind, value_payload

        if value_is_number(word):
            n = __import__("struct").unpack("<d", __import__("struct").pack("<Q", word))[0]
            return f"{n:g}" if n == n else "nan"
        kind = value_kind(word)
        tag = _VALUE_KIND_TAGS.get(kind, f"k{kind}")
        pay = value_payload(word)
        if tag == "str":
            strings = getattr(hw, "_value_strings", None) or []
            if 0 <= pay < len(strings):
                return f'str"{_js_short(strings[pay], 14)}"'
        return f"{tag}:{pay}"
    except Exception:
        return f"0x{word:016x}"


def _py_peek(hw, what: str, *args) -> str:
    """Render a JsHwVm structure in the same shape the RTL peek RPCs use."""
    what = (what or "").lower()

    if what == "obj":
        oid = int(args[0]) if args else 0
        objs = hw._value_objects
        if not (0 <= oid < len(objs)) or objs[oid] is None:
            return f"OBJ {oid} (empty slot)"
        obj = objs[oid]
        gen = hw._value_object_generations[oid]
        names = getattr(hw.program_image, "names", ()) or ()
        props = []
        for key, val in list(obj.items())[:12]:
            kname = names[key] if 0 <= key < len(names) else str(key)
            props.append(f"{kname}={_val_str(hw, val)}")
        return f"OBJ {oid} gen={gen} len={len(obj)} " + " ".join(props)

    if what == "arr":
        aid = int(args[0]) if args else 0
        arrs = hw._value_arrays
        if not (0 <= aid < len(arrs)) or arrs[aid] is None:
            return f"ARR {aid} (empty slot)"
        arr = arrs[aid]
        head = " ".join(_val_str(hw, v) for v in arr[:12])
        more = " …" if len(arr) > 12 else ""
        return f"ARR {aid} len={len(arr)} [{head}{more}]"

    if what == "stack":
        st = hw._value_stack
        head = " ".join(_val_str(hw, v) for v in st[-16:])
        return f"STK sp={len(st)} top16[{head}]"

    if what == "vars":
        base = int(args[0]) if args else 0
        n = int(args[1]) if len(args) > 1 else 16
        rows = []
        for i in range(base, min(base + n, len(hw._value_vars))):
            if not hw._value_var_valid[i]:
                continue
            names = getattr(hw.program_image, "var_names", ()) or ()
            nm = names[i] if 0 <= i < len(names) else f"v{i}"
            rows.append(f"{i}:{nm}={_val_str(hw, hw._value_vars[i])}")
        return "VARS " + (" ".join(rows) if rows else "(none set in range)")

    if what == "sram":
        base = int(args[0]) if args else 0
        n = int(args[1]) if len(args) > 1 else 64
        sram = getattr(getattr(hw, "_m", None), "sram", None)
        mem = getattr(sram, "mem", None)
        if mem is None:
            return ""
        loaded = int(getattr(sram, "loaded_bytes", 0) or 0)
        chunk = bytes(mem[base : base + n])
        if not chunk:
            return f"SRAM @{base} (out of range)"
        return f"SRAM @{base} loaded={loaded} " + chunk.hex(" ")

    if what == "raf":
        q = hw._value_raf
        return f"RAF n={len(q)} [" + " ".join(_val_str(hw, v) for v in q[:12]) + "]"

    if what == "timers":
        ts = hw._value_timers
        rows = [
            f"seq={t.sequence} due={t.due_frame} period={t.period}"
            for t in ts[:8]
        ]
        return f"TMR n={len(ts)} [" + "; ".join(rows) + "]"

    if what == "listeners":
        ls = hw._value_listeners
        # Both halves are packed Values — printing the raw key as an integer
        # showed a 19-digit NaN-box instead of the event name it encodes.
        rows = [f"{_val_str(hw, k)} -> {_val_str(hw, f)}" for k, f in ls[:10]]
        return f"LSN n={len(ls)} [" + "; ".join(rows) + "]"

    if what == "env":
        envs = hw._value_envs
        live = sum(1 for e in envs if e is not None)
        cur = ""
        try:
            from hardware_model.js_vm import VALUE_KIND_ENV, value_kind, value_payload

            if value_kind(hw._value_env) == VALUE_KIND_ENV:
                eid = value_payload(hw._value_env)
                env = envs[eid] if 0 <= eid < len(envs) else None
                if env is not None:
                    names = getattr(hw.program_image, "names", ()) or ()
                    slots = []
                    for key, val in list(env.slots.items())[:10]:
                        nm = names[key] if 0 <= key < len(names) else str(key)
                        slots.append(f"{nm}={_val_str(hw, val)}")
                    cur = f" cur={eid} parent={env.parent} " + " ".join(slots)
        except Exception:
            pass
        return f"ENV live={live}/{len(envs)}{cur}"

    if what == "fn":
        fns = hw._value_functions
        live = sum(1 for f in fns if f is not None)
        rows = [
            f"{i}:entry={f.entry} np={f.nparam}{' arrow' if f.is_arrow else ''}"
            for i, f in enumerate(fns) if f is not None
        ][:8]
        return f"FN live={live}/{len(fns)} [" + "; ".join(rows) + "]"

    if what == "gc":
        return (
            f"GCS objs={sum(1 for o in hw._value_objects if o is not None)}"
            f" arrs={sum(1 for a in hw._value_arrays if a is not None)}"
            f" envs={sum(1 for e in hw._value_envs if e is not None)}"
            f" fns={sum(1 for f in hw._value_functions if f is not None)}"
            f" strings={len(hw._value_strings or [])}"
        )

    if what == "ring":
        # PYTHON runs a frame to completion, so there is no frozen cycle ring
        # to replay. Say so rather than returning an empty ring.
        return ""

    return ""


def decode_ip(chunk, src_lines, ip) -> dict:
    """Shared arch_decode body: resolve one IP against the compiled image."""
    op_name, op_arg, native_name, native_id = decode_op_at(chunk, ip)
    if not op_name:
        return {}
    out = {
        "op_name": op_name,
        "op_arg": op_arg,
        "native_name": native_name,
        "native_id": native_id,
    }
    op_lines = getattr(chunk, "op_lines", None)
    if op_lines and 0 <= ip < len(op_lines):
        line = int(op_lines[ip] or 0)
        if line:
            out["src_line"] = line
            if 0 < line <= len(src_lines):
                out["html_line"] = src_lines[line - 1][:88]
    return out


def _merge_jsh_catalog(catalog: list[str]) -> list[str]:
    return card_catalog(catalog)


class RuntimeBackend(ABC):
    name: str = "ABSTRACT"

    @abstractmethod
    def type_line(self, text: str) -> None:
        ...

    @abstractmethod
    def screen_text(self) -> str:
        ...

    def poll(self) -> None:
        pass

    def set_joy(self, bits: int) -> None:
        pass

    def set_key_bits(self, bits: int) -> None:
        pass

    def push_key(self, ch: str) -> None:
        pass

    def hard_break(self) -> None:
        pass

    def framebuffer(self):
        """Return CanvasEngine-like object or None."""
        return None

    @abstractmethod
    def trace_path(self) -> Optional[Path]:
        ...

    @property
    def available(self) -> bool:
        return True

    def shutdown(self) -> None:
        pass

    def frame_tick(self) -> None:
        pass

    def paint_prompt(self, prompt: str, cursor_on: bool = False, cursor_col=None) -> None:
        """Optional: paint monitor prompt into this runtime's glass."""
        pass

    def arch_snapshot(self) -> dict:
        """Read-only Architecture Monitor fields. Missing keys are fine."""
        return {}

    def arch_decode(self, ip) -> dict:
        """What lives at `ip` in the loaded image: op, native, source line.

        Pure lookup against the compiled image — no RPC, no VM access — so the
        monitor can resolve any IP from the execution trace, not only the one
        the VM happens to be parked on.
        """
        return {}

    def arch_peek(self, what: str, *args) -> str:
        """One-line peek into a live VM structure, for an open inspector only.

        `what` is a neutral name (`obj`, `arr`, `stack`, `sram`, `vars`, `raf`,
        `timers`, `listeners`, `env`, `gc`, `ring`) — never a raw RPC verb, so
        the panel does not have to know which runtime it is talking to.
        Returns "" when this runtime cannot answer; the caller must treat that
        as "no view", never as an empty structure.
        """
        return ""


class PythonBackend(RuntimeBackend):
    name = "PYTHON"

    def __init__(self, machine) -> None:
        self.machine = machine
        self._nat_hist: dict[str, int] = {}

    def type_line(self, text: str) -> None:
        self.machine.type_line(text)

    def screen_text(self) -> str:
        return self.machine.screen_text()

    def set_joy(self, bits: int) -> None:
        self.machine.set_joy(bits)

    def set_key_bits(self, bits: int) -> None:
        self.machine.set_key_bits(bits)

    def key_event(self, key_code: int, key: str, pressed: bool) -> None:
        # NEW: raw keyboard → FM key-state engine (HTML decides bindings)
        self.machine.input.key_event(key_code, key, pressed)

    def push_key(self, ch: str) -> None:
        self.machine.push_key(ch)

    def hard_break(self) -> None:
        self.machine.hard_break()

    @property
    def more_waiting(self) -> bool:
        """True while LIST is parked on -- MORE -- (GUI must not paint `>`)."""
        return bool(getattr(self.machine, "_list_more_waiting", False))

    def framebuffer(self):
        return self.machine.canvas

    def frame_tick(self) -> None:
        self.machine.frame_tick()

    def paint_prompt(self, prompt: str, cursor_on: bool = False, cursor_col=None) -> None:
        self.machine.paint_monitor(prompt, cursor_on=cursor_on, cursor_col=cursor_col)

    @property
    def running(self) -> bool:
        """Game or last RUN frame owns the glass — GUI must not letterbox over it."""
        m = self.machine
        return bool(
            m.running
            or getattr(m, "_keep_fb", False)
            or m._loop_chunk is not None
            or getattr(m, "html_host", None) is not None
        )

    def trace_path(self) -> Optional[Path]:
        tr = getattr(self.machine, "trace", None)
        return tr.path if tr is not None else None

    def shutdown(self) -> None:
        tr = getattr(self.machine, "trace", None)
        if tr is not None:
            tr.close()

    def _hw_live(self) -> dict:
        """Live fields from the JsHwVm that actually executes an HTML title.

        Machine.vm is the loader's VM: it stops updating the moment
        _run_html_bytecode hands the ProgramImage to JsHwVm, so reading it
        during play reports ip 0 / no opcode / empty heap for the whole run.
        Every counter below lives on the hardware VM instead.
        """
        hw = getattr(self.machine, "_hw_vm", None)
        if hw is None or not getattr(hw, "_value64_active", False):
            return {}
        stack = list(getattr(hw, "_value_stack", None) or [])
        return {
            "ip": int(getattr(hw, "_value_last_ip", 0) or 0),
            "last_op": getattr(hw, "_value_last_op", None),
            "sp": len(stack),
            "stack_depth": len(stack),
            "stack_preview": _value_stack_preview(hw, stack),
            "obj": sum(1 for o in (getattr(hw, "_value_objects", None) or []) if o is not None),
            "arr": sum(1 for a in (getattr(hw, "_value_arrays", None) or []) if a is not None),
            "envl": sum(1 for e in (getattr(hw, "_value_envs", None) or []) if e is not None),
            "fn": sum(1 for f in (getattr(hw, "_value_functions", None) or []) if f is not None),
            "strb": len(getattr(hw, "_value_strings", None) or []),
            "raf": len(getattr(hw, "_value_raf", None) or []),
            "ton": len(getattr(hw, "_value_timers", None) or []),
            "lsn": len(getattr(hw, "_value_listeners", None) or []),
            "fault": getattr(hw, "error", None) or "",
            "natives": self._take_native_hist(hw),
            "ip_ring": (
                hw.arch_ip_ring() if hasattr(hw, "arch_ip_ring") else []
            ),
        }

    def _take_native_hist(self, hw) -> dict:
        """Natives called since the last snapshot, decayed so heat can fade.

        The monitor samples faster than a frame, so draining the counter every
        call would leave most samples empty and the engines would strobe.
        """
        take = getattr(hw, "arch_take_natives", None)
        if not callable(take):
            return {}
        # F10 stops the monitor from sampling, so the VM-side counter can hold
        # a whole hidden session. Cap the merge or re-opening the window shows
        # one enormous spike that then takes many frames to decay away.
        for name, n in take().items():
            self._nat_hist[name] = min(
                _NAT_HIST_CAP, self._nat_hist.get(name, 0) + n
            )
        # Half-life of a few frames: a native that stopped being called stops
        # lighting its engine, without flickering between frames.
        self._nat_hist = {
            k: v for k, v in ((k, v * 3 // 4) for k, v in self._nat_hist.items()) if v
        }
        return dict(self._nat_hist)

    def arch_decode(self, ip) -> dict:
        m = self.machine
        return decode_ip(
            getattr(m, "_html_chunk", None),
            list(getattr(m, "source_lines", None) or []),
            ip,
        )

    def arch_peek(self, what: str, *args) -> str:
        """PYTHON peeks — same views the RTL serves over OBJPEEK/ARRPEEK/…

        Read straight off the JsHwVm so the PYTHON inspector shows the same
        structures as FPGA-SIM instead of an empty panel.
        """
        hw = getattr(self.machine, "_hw_vm", None)
        if hw is None or not getattr(hw, "_value64_active", False):
            return ""
        try:
            return _py_peek(hw, what, *args)
        except Exception as e:  # a peek must never take the GUI down
            return f"(peek failed: {e})"

    def arch_snapshot(self) -> dict:
        """PYTHON live fields for the Architecture Monitor (existing Machine/VM)."""
        m = self.machine
        vm = getattr(m, "vm", None)
        hw = self._hw_live()
        stack = list(getattr(vm, "stack", None) or [])
        preview_parts = []
        for x in stack[-8:]:
            preview_parts.append(f"{_js_tag(x)}:{_js_short(x)}")
        catalog: list[str] = []
        try:
            catalog = list(m.storage.catalog())
        except Exception:
            catalog = []
        catalog = _merge_jsh_catalog(catalog)
        running = bool(self.running)
        chunk = getattr(m, "_html_chunk", None)
        n_ops = len(getattr(chunk, "code", None) or []) if chunk is not None else 0
        n_consts = len(getattr(chunk, "consts", None) or []) if chunk is not None else 0
        # JSB1 header as loaded — the sequencer panel names these fields, and
        # the header n_consts is not len(chunk.consts) (slots vs decoded pool).
        hwvm = getattr(m, "_hw_vm", None)
        n_vars = int(getattr(hwvm, "n_vars", 0) or 0) if hwvm is not None else 0
        flags = int(getattr(hwvm, "flags", 0) or 0) if hwvm is not None else 0
        if hwvm is not None and getattr(hwvm, "n_consts", None):
            n_consts = int(hwvm.n_consts)
        spr = len(getattr(m, "_spr_descs", None) or [])
        sram_bytes = int(getattr(getattr(m, "sram", None), "loaded_bytes", 0) or 0)
        phase = str(getattr(m, "_arch_phase", "") or "")
        if not phase:
            if running:
                phase = "run"
            elif getattr(m, "source_lines", None):
                phase = "loaded"
            else:
                phase = "idle"
        if hw:
            ip = int(hw["ip"])
        else:
            ip = int(getattr(vm, "last_ip", 0) or 0) if vm is not None else 0
        # The image is the ground truth for what op lives at IP; the VM's
        # own last_op agrees with it and is only a fallback for a bare .JS run.
        op_name, arg0, native_name, native_id = decode_op_at(chunk, ip)
        if not op_name:
            last_op = (hw.get("last_op") if hw else None) or (
                getattr(vm, "last_op", None) if vm is not None else None
            )
            op_name = last_op.name if hasattr(last_op, "name") else ""
            arg0 = getattr(vm, "last_arg0", None) if vm is not None else ""
        src_line = 0
        op_lines = getattr(chunk, "op_lines", None) if chunk is not None else None
        if op_lines and 0 <= ip < len(op_lines):
            src_line = int(op_lines[ip] or 0)
        src_lines = list(getattr(m, "source_lines", None) or [])
        if running and hw and (hw["raf"] or hw["ton"]):
            # The GUI only ever samples PYTHON between frames, and the frame
            # loop parks with rAF/timers queued — the same place the RTL
            # reports S_WAIT_FRAME. Same vocabulary so the runtimes compare.
            sname = "S_WAIT_FRAME"
        elif running:
            sname = "RUN"
        elif phase == "compile":
            sname = "COMPILE"
        elif phase == "load":
            sname = "LOAD"
        elif phase == "loaded":
            sname = "LOADED"
        elif running:
            sname = "RUN"
        else:
            sname = "IDLE"
        return {
            "running": running,
            "phase": phase,
            "sname": sname,
            "ip": ip,
            "op_name": op_name,
            "op_arg": arg0 if arg0 is not None else "",
            "native_id": native_id,
            "native_name": native_name,
            "src_line": src_line,
            "html_line": (
                src_lines[src_line - 1][:88] if src_line and 0 < src_line <= len(src_lines)
                else ""
            ),
            "code_window": fmt_code_window(chunk, ip) if chunk is not None else "",
            "html_window": fmt_html_window(src_lines, src_line or 1 if src_lines else 0),
            "last_cmd": getattr(m, "_arch_cmd", "") or "",
            "sp": hw.get("sp", len(stack)),
            "raf": hw.get("raf", len(getattr(m, "_raf_q", []) or [])),
            "ton": hw.get("ton", len(getattr(m, "_timers", []) or [])),
            "lsn": hw.get("lsn", len(getattr(m, "_listeners", []) or [])),
            "source_name": getattr(m, "source_name", "") or "",
            "catalog": catalog,
            "glass": (m.screen_text() or "")[-800:],
            "hdmi_mode": "game" if running else "letterbox",
            "stack_depth": hw.get("stack_depth", len(stack)),
            "stack_preview": hw.get("stack_preview") or ", ".join(preview_parts),
            "n_globals": len(getattr(vm, "globals", {}) or {}),
            "more": bool(getattr(m, "_list_more_waiting", False)),
            "obj": hw.get("obj", len(getattr(vm, "globals", {}) or {})),
            "arr": hw.get(
                "arr",
                sum(
                    1 for v in (getattr(vm, "globals", {}) or {}).values()
                    if isinstance(v, list)
                ),
            ),
            "envl": hw.get("envl", ""),
            "strb": hw.get("strb", ""),
            "fault": hw.get("fault", ""),
            "natives": hw.get("natives", {}),
            "ip_ring": hw.get("ip_ring", []),
            "spr": spr,
            "n_ops": n_ops,
            "n_consts": n_consts,
            "n_vars": n_vars,
            "flags": flags,
            "n_html": len(src_lines),
            "sram_bytes": sram_bytes,
        }
