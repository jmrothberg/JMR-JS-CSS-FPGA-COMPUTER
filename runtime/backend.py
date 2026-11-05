"""Pluggable runtime backends for the JMR JS GUI (BASIC method, JS product).

Pattern cite: JMR-BASIC-FPGA-COMPUTER/runtime/backend.py
"""

from __future__ import annotations

import os
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
    """HTML/JS titles from card.img DIR (no compile sidecars)."""
    names: list[str] = []
    seen: set[str] = set()
    for n in extra or []:
        if n and n not in seen:
            seen.add(n)
            names.append(n)
    from functional_model.storage_engine import StorageEngine

    for n in StorageEngine().catalog():
        if n not in seen:
            seen.add(n)
            names.append(n)
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

    def set_mouse(self, x: int, y: int, buttons: int) -> bool:
        """Accepted sample, or False to retry. Old board firmware has no pointer RPC."""
        return True

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

    def put_files_on_card(self, paths: list) -> str:
        """gui-put: write host files onto card.img (HTML mints .JSH)."""
        from pathlib import Path as _P
        from tools.make_sd_image import put_host_files_on_card

        names = put_host_files_on_card([_P(p) for p in paths])
        return ", ".join(names)

    def put_card_names(self, names: list) -> str:
        """F8: files already on card.img (BOARD SAVE; PYTHON/SIM DIR)."""
        return ", ".join(names)


class PythonBackend(RuntimeBackend):
    name = "PYTHON"

    def __init__(self, machine) -> None:
        self.machine = machine
        self._nat_hist: dict[str, int] = {}
        from functional_model.desktop import Desktop
        self.desktop = Desktop(machine.storage)
        self.desktop.tick()
        self._desktop_return = False
        from functional_model.system_menu import SystemMenu
        self.system_menu=SystemMenu()
        from functional_model.system_resources import SystemResources
        try:
            resources=SystemResources(machine.storage.load_bytes('SYSTEM.SYS'))
            toolbox_sys_data=resources.data
        except (FileNotFoundError,ValueError,OSError):
            resources=SystemResources()
            toolbox_sys_data=None
        machine._toolbox_sys_data=toolbox_sys_data
        from functional_model.toolbox_rom import unpack_rom,default_code
        try:
            machine._toolbox_code=unpack_rom(machine.storage.load_bytes("TOOLBOX.ROM"))
        except (FileNotFoundError,ValueError,OSError):
            machine._toolbox_code=default_code()
        self.system_menu.resources=resources
        self.system_menu.classic.resources=resources
        self.machine.system_progress=self._system_progress
        self._screen_line=""
        self._mouse_pending=None
        self._save_resume=None
        self._after_save=None
        self._pending_change=None
        self._name_action=None
        self._last_notice=0
        self._compile_close_pending=False
        self._finder_image=None
        self._finder_resident=None
        self._finder_home=self._finder_program()
        if self._finder_home:self.desktop.visible=False

    def _finder_program(self):
        """True when the shell is the Finder program, not the built-in desktop.

        auto (the default) turns on once FINDER.JSH is on the disk.
        JMR_FINDER=program forces it. JMR_FINDER=builtin keeps desktop.py.
        """
        mode=os.environ.get('JMR_FINDER','auto')
        if mode=='builtin':return False
        if mode=='program':return True
        try:
            self.machine.storage.load_bytes('FINDER.JSH')
            return True
        except FileNotFoundError:
            return False

    def _finder_blob(self):
        if self._finder_image is not None:return self._finder_image
        # storage/FINDER.HTML is the program being edited. The card's
        # FINDER.JSH is the older copy and was covering that picture.
        src=Path(__file__).resolve().parents[1]/'storage'/'FINDER.HTML'
        if src.is_file():
            from tools.compile_js import compile_html_text, encode_html_chunk
            blob=encode_html_chunk(compile_html_text(src.read_text(),source_path=src))
        else:
            blob=self.machine.storage.load_bytes('FINDER.JSH')
        self._finder_image=blob
        return blob

    def _park_finder(self):
        """Keep the running Finder in host RAM. The next program uses the one heap."""
        m=self.machine
        hw=m._hw_vm
        if hw is None:return
        from functional_model.jsb_format import CSCR_SRAM_BASE, CSCR_WORDS
        sram=m.sram
        n=sram.loaded_bytes
        base=CSCR_SRAM_BASE*2
        self._finder_resident={
            'hw':hw,
            'raf':list(getattr(m,'_finder_raf',[]) or []),
            'window':tuple(m.system_window),
            'menus':m.system_menus,
            'about':m.system_about,
            'viewport':m.system_viewport,
            'palette':list(m.canvas.palette),
            'sprites':list(m._sprites),
            'spr':list(getattr(m,'_spr_descs',[]) or []),
            'chunk':m._html_chunk,
            'aset':bytes(sram.mem[:n]),
            'stg':bytes(sram.mem[base:base+CSCR_WORDS*2]),
        }

    def _resume_finder(self):
        """Put the parked Finder back. It does not read the disk or run start() again."""
        r=self._finder_resident
        if not r or not r['raf']:
            self._finder_resident=None
            return False
        from functional_model.jsb_format import CSCR_SRAM_BASE
        m=self.machine
        hw=r['hw']
        m.sram.mem[:len(r['aset'])]=r['aset']
        m.sram.loaded_bytes=len(r['aset'])
        base=CSCR_SRAM_BASE*2
        m.sram.mem[base:base+len(r['stg'])]=r['stg']
        m.canvas.palette=list(r['palette'])
        m._sprites=list(r['sprites'])
        m._spr_descs=list(r['spr'])
        m.system_window=list(r['window'])
        m.system_menus=r['menus']
        m.system_about=r['about']
        m.system_viewport=r['viewport']
        m._html_chunk=r['chunk']
        m._hw_vm=hw
        m.vm=hw._m.vm
        hw.canvas=m.canvas
        hw.input=m.input
        hw._m.canvas=m.canvas
        hw._m.input=m.input
        hw._m._sprites=list(m._sprites)
        hw._value_raf=list(r['raf'])
        hw.running=bool(r['raf'])
        hw.error=None
        m.running=hw.running
        m._bytecode_html=True
        m._edit_active=True
        m._cmp_done=False
        m._arch_phase='run'
        # The other program may have left a canvas scale. The Finder
        # draws in glass pixels, 1:1.
        m._ctx_tx=0;m._ctx_ty=0;m._ctx_sx=1;m._ctx_sy=1;m._ctx_baseline=0
        # MacPaint's color plane starts at arena byte 73728, which is
        # also where a full disk's icon runs live. Those bytes come back
        # as long horizontal streaks. Drop the cache flags (they sit in
        # the parked half) so the next paint reads the .ICN files again.
        # The click that opened the other program never got to finish:
        # sysRun stops the Finder mid mouse-up. Drop that gesture.
        for i in range(256):
            m._nat_stg_write(48000+i,0)
        m._nat_stg_write(16392,0)
        m._nat_stg_write(16395,0)
        m.canvas.clear(0)
        m.canvas.clear_front(0)
        m._nat_stg_write(16385,1)
        self.desktop.visible=False
        return True

    def _finder_glass_blank(self):
        """True when the desktop stripe was never painted (index 0)."""
        c=self.machine.canvas
        front=getattr(c,'front',None)
        if not front:return True
        return front[40*c.width+40]==0

    def _pump_finder(self):
        """Run the Finder's start frame and its paint before the GUI draws.

        start() does not paint. The next frame does. Without this pump the
        glass stays black, with only the menu bar, until something else
        sets the dirty byte.
        """
        for _ in range(4):
            if not self.machine.running:return
            self.machine.frame_tick()
            if not self._finder_glass_blank():return
            self.machine._nat_stg_write(16385,1)

    def _start_finder_program(self):
        """Run FINDER.JSH. The built-in desktop stays in memory and hidden."""
        from functional_model.jsb_format import ProgramImage
        self._finder_home=False
        self.desktop.visible=False
        if self._resume_finder():
            self._pump_finder()
            return
        try:
            blob=self._finder_blob()
        except Exception:
            self.desktop.visible=True
            self.desktop.refresh()
            return
        self.machine.hard_break(quiet=True)
        self.desktop.visible=False
        self.machine._start_html_image(ProgramImage(blob),share_machine=True)
        # The editor uses this same SRAM. Its old "already started" flag
        # made the new Finder skip start() and leave the cleared glass black.
        self.machine._nat_stg_write(16384,0)
        self.machine._nat_stg_write(16600,0)
        self._pump_finder()

    def _finder_launch(self,name,how):
        """What the Finder program asked to run. Quit comes back here."""
        how=int(how)
        self.desktop.visible=False
        self._finder_home=True
        # Restart builds a fresh Finder. Leaving for a program keeps this one.
        if how==8 or not name:self._finder_resident=None
        elif getattr(self.machine,'system_window',[0])[0]==9:self._park_finder()
        # The Finder VM just stopped. Land on the monitor before LOAD/RUN
        # so the next program is not started inside the Finder's heap.
        self.machine.hard_break(quiet=True)
        self.desktop.visible=False
        if how==8 or not name:
            return
        if how==4:
            self._finder_home=False
            self.machine.paint_monitor('> ')
            return
        if how==5:
            self._perform_change(('tool','Note'));return
        if how==6:
            self._perform_change(('tool','Help'));return
        if how==7:
            self._perform_change(('tool','Utility'));return
        self.machine.unnamed_document=False
        self.machine.type_line('LOAD "'+name+'"')
        suf=Path(name).suffix.upper()
        if how==1:
            self.machine.type_line('EDIT')
        elif how==2 or (how==0 and suf not in ('.HTM','.HTML','.JS')):
            self.machine.type_line('READ')
        elif how==3:
            try:
                blob=self.machine.storage.load_bytes('COMPILE.JSH')
            except FileNotFoundError:
                self.machine.console_log.append('?NH')
                return
            from functional_model.jsb_format import ProgramImage
            self.machine._start_html_image(ProgramImage(blob),share_machine=True)
        else:
            self.machine.type_line('RUN')

    def _system_progress(self):
        self.machine.paint_monitor()
        self.framebuffer()
        pump=getattr(self,'run_wait_idle',None)
        if pump:pump()

    def type_line(self, text: str) -> None:
        if text.strip().upper() == "DESKTOP":
            self.desktop.visible = True
            self.desktop.refresh()
            return
        self.desktop.visible = False
        self._desktop_return = False
        self.machine.type_line(text)

    def screen_text(self) -> str:
        return self.machine.screen_text()

    def set_joy(self, bits: int) -> None:
        self.machine.set_joy(bits)

    def set_key_bits(self, bits: int) -> None:
        self.machine.set_key_bits(bits)

    def key_event(self, key_code: int, key: str, pressed: bool) -> None:
        if self.machine.system_compiling:return
        if self.system_menu.about:
            if pressed and key_code in (13,27):self.system_menu.about=False
            return
        if self.system_menu.classic.dialog=='save_as':
            if pressed:
                self._classic_actions(self.system_menu.classic.text_key(key_code,key))
                if not self.system_menu.classic.dialog and not self._save_resume:self._cancel_dialog()
            return
        ui=self.system_menu.classic
        if ui.dialog:
            if pressed:
                if key_code==27:ui.dialog=None;self._cancel_dialog()
                elif ui.dialog=='open':
                    if key_code in (38,40) and ui.files:
                        ui.selected=max(0,min(len(ui.files)-1,ui.selected+(-1 if key_code==38 else 1)))
                        ui.file_top=max(0,min(ui.file_top,ui.selected))
                        if ui.selected>=ui.file_top+7:ui.file_top=ui.selected-6
                    elif key_code==13 and ui.selected>=0:self._classic_actions([('open_file',ui.files[ui.selected])])
                elif key_code==13:
                    if ui.dialog=='changes':self._classic_actions([('changes','save')])
                    elif ui.dialog=='replace':self._classic_actions([('replace',)])
                    else:ui.dialog=None
            return
        if ui.menu:
            if pressed and key_code==27:ui.menu=0
            return
        if key_code==113 and self.machine.running and self.machine.system_window[0] in (1,5):
            if pressed:self._save_document()
            return
        self.machine.input.key_event(key_code, key, pressed)

    @property
    def system_keyboard(self):
        return self.system_menu.keyboard

    @property
    def console_line(self):
        return self._screen_line

    def console_key(self, char):
        if char==13:
            text=self._screen_line;self._screen_line=""
            self.machine.type_line(text)
        elif char in (8,127):self._screen_line=self._screen_line[:-1]
        elif 32<=char<127 and len(self._screen_line)<127:self._screen_line+=chr(char)
        self.machine.paint_monitor("> "+self._screen_line)

    def set_mouse(self, x: int, y: int, buttons: int) -> bool:
        self.desktop.x,self.desktop.y=x,y
        self.framebuffer()
        old_dialog=self.system_menu.classic.dialog
        consumed,actions=self.system_menu.pointer(x,y,buttons)
        if old_dialog and not self.system_menu.classic.dialog and not actions:self._cancel_dialog()
        if self.system_menu.open and self.desktop.menu:
            self.desktop.menu=0;self.desktop.dirty=True
        self._classic_actions(actions)
        if consumed:return True
        if self.desktop.visible:
            action=self.desktop.pointer(x,y,buttons)
            if action:self._desktop_action(*action)
            return True
        if self.machine.system_window[0]==8 and self.machine.system_viewport:
            from functional_model.canvas_engine import game_viewport_y
            y=game_viewport_y(y)
        if self.machine.running and not self.machine.input.set_mouse(x,y,buttons):
            self._mouse_pending=(x,y,buttons)
        return True

    def _send_system_key(self,code):
        self.machine.input.key_event(code,"",True)
        self.machine.input.key_event(code,"",False)

    def _cancel_dialog(self):
        if hasattr(self,'_name_keyboard_was'):
            self.system_menu.keyboard=self._name_keyboard_was;del self._name_keyboard_was
        self._pending_change=None;self._after_save=None;self._owned_key=0

    def _classic_actions(self,actions):
        if self.machine.system_compiling:
            if any(action[0]=='quit' or action==('menu','close') for action in actions):self._compile_close_pending=True
            return
        for action in actions:
            name=action[0]
            if name in ('quit','close'):
                self._request_change(('close',))
            elif name=='menu':
                command=action[1]
                if command.startswith('tool:'):self._request_change(('tool',command[5:]))
                elif command=='close':self._request_change(('close',))
                elif command=='new':self._request_change(('new',self.system_menu.window[0]))
                elif command=='open':
                    role=self.system_menu.window[0]
                    # Reader opens documents. Compile opens HTML programs.
                    # Editor and Note open either.
                    if role==2:suffixes=('.MD','.TXT')
                    elif role==3:suffixes=('.HTM','.HTML')
                    else:suffixes=('.MD','.TXT','.HTM','.HTML','.JS')
                    files=[n for n,size in self.machine.storage.list_all()
                           if Path(n).suffix.upper() in suffixes
                           and not (role==3 and Path(n).stem.upper()=='COMPILE')]
                    self.system_menu.classic.show_files(files)
                elif command=='save':self._save_document()
                elif command=='save_as':self._save_document(force_name=True)
                elif command.startswith('open:'):
                    # A program-owned Open... uses the shared list. The
                    # program loads the bytes; this does not LOAD SOURCE.
                    self._owned_key=int(command[5:])
                    self.system_menu.classic.show_files([n for n,size in self.machine.storage.list_all()])
                elif command.startswith('save_as:'):
                    self._owned_key=int(command[8:])
                    self.system_menu.classic.show_name(getattr(self,'_owned_name',''))
                elif command=='restart_app':
                    image=self.machine._hw_vm.program_image
                    self._classic_actions(self.system_menu.release_keys())
                    self.machine.hard_break(quiet=True)
                    self.machine._start_html_image(image)
                    self._desktop_return=True
                elif command.startswith('app:'):self._send_system_key(int(command[4:]))
                else:
                    keys={'undo':137,'cut':138,'copy':139,'paste':140,'clear':141,'select_all':142,'page_up':130,'page_down':131}
                    if command in keys:self._send_system_key(keys[command])
            elif name=='open_file':
                if getattr(self,'_owned_key',0):
                    self.system_menu.classic.dialog=None
                    self._give_owned_name(action[1])
                else:
                    role=self.system_menu.window[0]
                    self.system_menu.classic.dialog=None
                    self._request_change(('open',action[1],role))
            elif name=='save_name':self._confirm_save_name(action[1])
            elif name=='changes':
                pending=self._pending_change;self._pending_change=None;self.system_menu.classic.dialog=None
                if action[1]=='save':self._save_document(after=pending,resume=False)
                elif pending:self._perform_change(pending)
            elif name=='replace':
                target=self._replace_name;self.system_menu.classic.dialog=None
                if getattr(self,'_owned_replace',False):
                    self._owned_replace=False;self._give_owned_name(target);continue
                if getattr(self,'_compile_save_as',False):
                    self._compile_save_as=False
                    self._compile_to(target,copy=True)
                else:self._start_save(target)
            elif name=='keyboard' and action[1] and self.desktop.visible:
                self.desktop.visible=False;self.machine.paint_monitor("> "+self._screen_line)
            elif name=='key':
                _,code,text,pressed=action
                if text==27 and pressed:
                    if self.system_menu.classic.dialog:self.system_menu.classic.dialog=None
                    else:self.hard_break()
                elif self.machine.running:
                    names={8:'Backspace',9:'Tab',13:'Enter',27:'Escape',37:'ArrowLeft',38:'ArrowUp',39:'ArrowRight',40:'ArrowDown'}
                    self.machine.input.key_event(code,chr(text) if 32<=text<127 else names.get(code,''),pressed)
                elif pressed and text:self.console_key(text)

    def _request_change(self,operation):
        if self.machine.running and self.system_menu.window[0] in (1,5) and self.system_menu.window[3]&1:
            self._pending_change=operation;self.system_menu.classic.dialog='changes'
        else:self._perform_change(operation)

    def _perform_change(self,operation):
        kind=operation[0]
        self.system_menu.classic.dialog=None;self.system_menu.classic.menu=0
        if kind=='close':
            self.machine.system_compiling=False
            self._classic_actions(self.system_menu.release_keys())
            self.system_menu.keyboard=False;self.system_menu.open=False
            self.hard_break(quiet=True);return
        self.machine.hard_break(quiet=True);self.desktop.visible=False
        if kind=='new':self._new_document(operation[1]);return
        if kind=='open':
            _,name,role=operation
            self.machine.unnamed_document=False
            self.machine.type_line('LOAD "'+name+'"')
            if role in (1,5):
                self.machine._editor_resume=(0,0,0,0,role)
                self.machine.type_line('EDIT')
            elif role==2:self.machine.type_line('READ')
            elif role==3:
                # Open parks the HTML. Save compiles that name. Save As
                # writes a new program and leaves this one on the disk.
                try:
                    blob=self.machine.storage.load_bytes('COMPILE.JSH')
                except FileNotFoundError:
                    self.machine.console_log.append('?NH')
                    self._desktop_return=True
                    return
                from functional_model.jsb_format import ProgramImage
                self.machine._start_html_image(ProgramImage(blob), share_machine=True)
                self._desktop_return=True
                return
            else:
                image=getattr(self,'_system_tool_image',None)
                if image is not None:self.machine._start_html_image(image,share_machine=True)
            self._desktop_return=True;return
        if kind=='tool':
            tool=operation[1]
            if tool=='Terminal':self.machine.paint_monitor('> ');self._desktop_return=False
            elif tool=='Note':self._new_document(5)
            elif tool=='Editor':
                if self.machine.source_name and self.machine.source_lines:
                    self.machine.type_line('EDIT');self._desktop_return=True
                else:self._new_document(1)
            elif tool in ('Reader','Help'):
                name=self.machine.source_name if tool=='Reader' and Path(self.machine.source_name).suffix.upper() in ('.MD','.TXT') else 'HELP.MD'
                self.machine.type_line('LOAD "'+name+'"');self.machine.type_line('READ');self._desktop_return=True
            elif tool=='Utility':self._desktop_action('RUN','UTILITY.HTM')
            elif tool=='Compile':
                self._compile_close_pending=False
                self.machine.type_line('COMPILE');self._desktop_return=False
                if self._compile_close_pending:self._perform_change(('close',))
            elif tool=='Restart':self.hard_break()

    def _new_document(self,role):
        role=5 if role==5 else 1
        self.machine.source_name='UNTITLED.TXT' if role==5 else 'UNTITLED.HTM'
        self.machine.source_lines=[''];self.machine.unnamed_document=True
        self.machine._editor_resume=(0,0,0,0,role)
        self.machine.type_line('EDIT');self.desktop.visible=False;self._desktop_return=True

    def _resume_record(self):
        m=self.machine
        magic=[int(m._nat_stg_read(32+i)) for i in range(4)]
        if magic!=[82,69,83,1]:return (0,0,0,0,1)
        values=[]
        for at in (36,40,44,48):values.append(sum(int(m._nat_stg_read(at+i))<<(i*8) for i in range(4)))
        return (*values,int(m._nat_stg_read(52)))

    def _save_document(self,force_name=False,after=None,resume=True):
        if self.system_menu.window[0]==3:
            self._compile_save(force_name)
            return
        if self.system_menu.window[0] not in (1,5):return
        self._after_save=after;self._save_should_resume=resume
        if force_name or getattr(self.machine,'unnamed_document',False):
            self.system_menu.classic.show_name(self.machine.source_name or 'UNTITLED.TXT')
        else:self._start_save(self.machine.source_name)

    def _give_owned_name(self,name):
        """Leave the chosen 8.3 name at arena bytes 96-111, then the menu key.

        That slot is the filename field the console already uses. The
        program reads it and writes or loads its own bytes. SOURCE is
        not saved and the editor is not restarted.
        """
        raw=str(name or '').encode('ascii','replace')[:12]
        for i in range(16):
            self.machine._nat_stg_write(96+i, raw[i] if i<len(raw) else 0)
        key=self._owned_key;self._owned_key=0;self._owned_name=str(name or '')
        self.system_menu.classic.dialog=None
        self._send_system_key(key)

    def _confirm_owned_name(self,name):
        from hardware_model.fat32 import Fat32Volume
        name=name.strip().upper();stem,dot,ext=name.partition('.')
        if not stem or len(stem)>8 or len(ext)>3 or (dot and not ext):
            self.system_menu.classic.message='Use 1-8 letters, then a short suffix.';return
        check=name if dot else stem
        if Fat32Volume.decode_83(Fat32Volume.encode_83(check if not dot else name))!=(check if not dot else name):
            self.system_menu.classic.message='Use 1-8 letters, then a short suffix.';return
        existing={n.upper() for n,size in self.machine.storage.list_all()}
        if name in existing:
            self._replace_name=name;self._owned_replace=True
            self.system_menu.classic.dialog='replace';return
        self._owned_replace=False
        self._give_owned_name(name)

    def _confirm_save_name(self,name):
        if getattr(self,'_owned_key',0):
            self._confirm_owned_name(name);return
        from hardware_model.fat32 import Fat32Volume
        name=name.strip().upper();stem,dot,ext=name.partition('.')
        if ext=='HTML':ext='HTM';name=stem+'.HTM'
        if not stem or len(stem)>8 or len(ext)>3 or Fat32Volume.decode_83(Fat32Volume.encode_83(name))!=name:
            self.system_menu.classic.message='Use 1-8 letters, then .TXT / .HTM / .MD';return
        existing={n.upper() for n,size in self.machine.storage.list_all()}
        if getattr(self,'_compile_save_as',False):
            if ext not in ('HTM',''):
                self.system_menu.classic.message='Use 1-8 letters, then .HTM';return
            if not ext:name=stem+'.HTM'
            if name in existing and name!=self._compile_source_name():
                self._replace_name=name;self.system_menu.classic.dialog='replace';return
            self._compile_save_as=False
            self._compile_to(name,copy=name!=self._compile_source_name())
            return
        if name in existing and name!=self.machine.source_name.upper():
            self._replace_name=name;self.system_menu.classic.dialog='replace';return
        self._start_save(name)

    def _start_save(self,name):
        self.system_menu.classic.dialog=None
        if hasattr(self,'_name_keyboard_was'):
            self.system_menu.keyboard=self._name_keyboard_was;del self._name_keyboard_was
        self.machine.source_name=name;self.machine.unnamed_document=False
        self._save_resume=True
        self._send_system_key(113)

    def _compile_source_name(self):
        """The opened program as an 8.3 .HTM name. Empty when nothing is parked."""
        name=(self.machine.source_name or '').strip().upper()
        stem,dot,ext=name.partition('.')
        if ext=='HTML':ext='HTM'
        if not stem:return ''
        return stem[:8]+'.'+(ext or 'HTM')

    def _compile_save(self,force_name):
        """Save compiles the opened HTML. Save As writes a new program first."""
        name=self._compile_source_name()
        if (not name or name.startswith('COMPILE.') or not name.endswith('.HTM')
                or not self.machine.source_lines):
            self.system_menu.classic.message='Open an HTML program first.'
            self.system_menu.classic.dialog='message'
            return
        if force_name:
            self._compile_save_as=True
            self.system_menu.classic.show_name(name)
            return
        self._compile_to(name,copy=False)

    def _compile_to(self,name,copy):
        """Mint name.JSH. copy writes the HTML under the new name and leaves the original."""
        self.system_menu.classic.dialog=None
        if hasattr(self,'_name_keyboard_was'):
            self.system_menu.keyboard=self._name_keyboard_was;del self._name_keyboard_was
        if copy and name!=self._compile_source_name():
            body='\n'.join(self.machine.source_lines)
            if body and not body.endswith('\n'):body+='\n'
            # save_text drops a stale JSH of the new name. The original file is not touched.
            self.machine.storage.save_text(name,body)
            self.machine.source_name=name
        self.machine.hard_break(quiet=True)
        self.desktop.visible=False
        self.machine.type_line('COMPILE')
        if any(str(line).startswith('COMPILED') for line in self.machine.console_log[-4:]):
            self.desktop.visible=True
            self.desktop.refresh()

    def _desktop_action(self, action, name):
        if action == "EMPTY":
            # Empty Trash deletes the files the desktop is holding.
            for held in list(self.desktop.trash):
                self.machine.type_line('REMOVE "'+held+'"')
            self.desktop.trash=[]
            self.desktop.trash_open=False
            self.desktop.visible=True
            self.desktop.refresh()
            self._desktop_return=True
            return
        if action == "TERMINAL":
            self.machine.paint_monitor("> ")
            return
        commands = ([f'REMOVE "{name}"'] if action == "REMOVE" else
                    [f'LOAD "{name}"', action])
        for command in commands:
            before = len(self.machine.console_log)
            self.machine.type_line(command)
            if any(str(line).lstrip().startswith("?")
                   for line in self.machine.console_log[before:]):
                self._desktop_return = False
                return
        self._desktop_return = True
        if action in ("REMOVE", "COMPILE") and not self.machine.running:
            self.desktop.visible = True
            self.desktop.refresh()

    def push_key(self, ch: str) -> None:
        self.machine.push_key(ch)

    def hard_break(self, quiet: bool = False) -> None:
        self.machine.hard_break(quiet=quiet)
        self.system_menu.classic.menu=0;self.system_menu.classic.dialog=None
        self.system_menu.classic.drag=False;self.system_menu.classic.capture=False
        self._desktop_return = False
        if self._finder_program():
            # The Finder program comes back. The built-in desktop stays hidden.
            self.desktop.visible=False
            self._finder_home=True
        else:
            self.desktop.visible = True
            self.desktop.refresh()

    @property
    def more_waiting(self) -> bool:
        """True while LIST is parked on -- MORE -- (GUI must not paint `>`)."""
        return bool(getattr(self.machine, "_list_more_waiting", False))

    def framebuffer(self):
        from functional_model.desktop import pointer_overlays
        # The startup pictures own the glass. No menu bar over them.
        if getattr(self, '_boot_glass', False):
            self.machine.canvas.display_overlays = ()
            return self.machine.canvas
        params=list(getattr(self.machine,'system_window',(0,0,0,0)))
        if self.desktop.visible:params=[0,0,0,0]
        elif getattr(self.machine,'system_compiling',False):params=[3,0,0,(getattr(self.machine,'system_stage',0)&7)<<4]
        elif not self.machine.running:params=[7,0,0,0]
        elif params[0]>9:params[0]=6
        self.system_menu.window=tuple(params)
        defaults={0:('Finder','Manage programs and documents.'),
                  1:('Editor','Edit source code and text files.'),
                  2:('Reader','Read Markdown and text documents.'),
                  3:('Compiler','Compile HTML and JavaScript programs.'),
                  4:('Utility','Inspect files and disk space.'),
                  5:('Note','Write and save short text documents.'),
                  6:('System Tool','A shared-window system application.'),
                  7:('Terminal','Enter commands for the computer.'),
                  9:('Finder','Manage programs and documents.')}
        about=getattr(self.machine,'system_about',None) if self.machine.running and params[0]!=3 and not self.desktop.visible else None
        self.system_menu.application_title,self.system_menu.application_description=about or defaults.get(params[0],('Program','An HTML and JavaScript program.'))
        self.machine.canvas.display_game_viewport=bool(params[0]==8 and getattr(self.machine,'system_viewport',False))
        self.desktop.canvas.display_game_viewport=False
        self.system_menu.classic.configure(params[0],getattr(self.machine,'system_menus','') if self.machine.running and not self.desktop.visible else '')
        self.system_menu.classic.menu_enable=getattr(self.machine,'system_menu_enable',0xFFFFFFFF)
        self.system_menu.classic.menu_check=getattr(self.machine,'system_menu_check',0)
        self.system_menu.document_name=self.machine.source_name
        self.system_menu.document_title=getattr(self.machine,'system_title','') or ''
        self.system_menu.scroll_bars=getattr(self.machine,'system_bars',True)
        self.system_menu.classic.bars=self.system_menu.scroll_bars
        self.system_menu.source_lines=list(self.machine.source_lines or [])
        self.system_menu.classic.document=self.machine.source_name
        self.system_menu.classic.can_undo=bool(params[3]&2)
        self.system_menu.classic.can_paste=bool(params[3]&4)
        self.system_menu.classic.has_selection=bool(params[3]&8)
        if self.machine.running and params[0] and self.machine._hw_vm is not None:
            self._system_tool_image=self.machine._hw_vm.program_image
        ui=self.system_menu.classic
        ibeam=ui.dialog=='save_as' and 154<=self.desktop.x<364 and 150<=self.desktop.y<172
        overlays = self.system_menu.overlays() + pointer_overlays(
            self.desktop.x, self.desktop.y,
            watch=bool(getattr(self.machine,'system_compiling',False)),
            ibeam=ibeam)
        if self.desktop.visible:
            self.desktop.tick()
            self.desktop.canvas.display_overlays = overlays
            return self.desktop.canvas
        self.machine.canvas.display_overlays = overlays
        return self.machine.canvas

    def frame_tick(self) -> None:
        self.system_menu.classic.tick()
        self.machine.frame_tick()
        if self._save_resume and not self.machine.running:
            self._save_resume=None
            if any(str(x).startswith('SAVED') for x in self.machine.console_log[-3:]):
                record=self._resume_record()
                after=self._after_save;self._after_save=None
                if after:self._perform_change(after)
                elif self._save_should_resume:
                    self.machine._editor_resume=record
                    self.machine._editor_keep_source=True
                    self.machine.type_line('EDIT');self._desktop_return=True
        flags=getattr(self.machine,'system_window',[0,0,0,0])[3]
        notice=(flags>>4)&3
        if notice and notice!=self._last_notice and self.machine.running:
            self.system_menu.classic.dialog='message'
            self.system_menu.classic.message='Selection exceeds 4K clipboard.' if notice==1 else 'Document is full.'
        self._last_notice=notice
        if self._mouse_pending and self.machine.input.set_mouse(*self._mouse_pending):self._mouse_pending=None
        if self.system_menu.keyboard and not self.machine.running and not self.desktop.visible:
            self.machine.paint_monitor("> "+self._screen_line)
        if getattr(self.machine,'_app_stopped',False):
            self.machine._app_stopped=False
            # File → Quit and the editor's cdone both stop the program.
            # Come back to the Finder instead of leaving the black glass.
            # A save that is about to reopen the editor already set running.
            if self._finder_program() and not self.machine.running and not self.desktop.visible:
                self._finder_home=True
        if self._desktop_return and not self.running:
            self._desktop_return = False
            if self._finder_program():
                self.desktop.visible=False
                self._finder_home=True
            else:
                self.desktop.visible = True
                self.desktop.refresh()
        req=getattr(self.machine,'_finder_request',None)
        if req:
            self.machine._finder_request=None
            self._finder_launch(*req)
        if self._finder_home and not self.machine.running and not self.desktop.visible:
            self._start_finder_program()
        self.desktop.tick()

    def paint_prompt(self, prompt: str, cursor_on: bool = False, cursor_col=None) -> None:
        if self.desktop.visible or self.system_menu.keyboard:
            return
        self.machine.paint_monitor(prompt, cursor_on=cursor_on, cursor_col=cursor_col)

    @property
    def running(self) -> bool:
        """Game or last RUN frame owns the glass — GUI must not letterbox over it."""
        m = self.machine
        return bool(
            m.running or m.system_compiling
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
