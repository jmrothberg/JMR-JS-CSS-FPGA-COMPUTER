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
    """HTML/JS titles plus invisible .JSH compile cache names."""
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
            if p.suffix.upper() in (".HTML", ".HTM", ".JS", ".JSH") and p.name not in seen:
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
    rows = []
    for i in range(lo, hi):
        op, *args = code[i]
        name = op.name if hasattr(op, "name") else str(op)
        extra = ""
        if args:
            extra = " " + " ".join(str(a) for a in args[:3])
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


class PythonBackend(RuntimeBackend):
    name = "PYTHON"

    def __init__(self, machine) -> None:
        self.machine = machine

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

    def arch_snapshot(self) -> dict:
        """PYTHON live fields for the Architecture Monitor (existing Machine/VM)."""
        m = self.machine
        vm = getattr(m, "vm", None)
        stack = list(getattr(vm, "stack", None) or [])
        preview_parts = []
        for x in stack[-8:]:
            preview_parts.append(f"{_js_tag(x)}:{_js_short(x)}")
        catalog: list[str] = []
        try:
            catalog = list(m.storage.catalog())
        except Exception:
            catalog = []
        # NEW: also list compile-cache .JSH next to DIR names (not a LOAD name)
        catalog = _merge_jsh_catalog(catalog)
        running = bool(self.running)
        chunk = getattr(m, "_html_chunk", None)
        n_ops = len(getattr(chunk, "code", None) or []) if chunk is not None else 0
        n_consts = len(getattr(chunk, "consts", None) or []) if chunk is not None else 0
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
        ip = int(getattr(vm, "last_ip", 0) or 0) if vm is not None else 0
        last_op = getattr(vm, "last_op", None) if vm is not None else None
        op_name = last_op.name if last_op is not None and hasattr(last_op, "name") else ""
        arg0 = getattr(vm, "last_arg0", None) if vm is not None else None
        native_name = ""
        native_id = ""
        if op_name == "CALL_NATIVE" and arg0 is not None:
            native_id = arg0
            native_name = _native_name_for_id(arg0)
        src_line = 0
        op_lines = getattr(chunk, "op_lines", None) if chunk is not None else None
        if op_lines and 0 <= ip < len(op_lines):
            src_line = int(op_lines[ip] or 0)
        src_lines = list(getattr(m, "source_lines", None) or [])
        if running and op_name:
            sname = op_name
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
            "sp": len(stack),
            "raf": len(getattr(m, "_raf_q", []) or []),
            "ton": len(getattr(m, "_timers", []) or []),
            "source_name": getattr(m, "source_name", "") or "",
            "catalog": catalog,
            "glass": (m.screen_text() or "")[-800:],
            "hdmi_mode": "game" if running else "letterbox",
            "stack_depth": len(stack),
            "stack_preview": ", ".join(preview_parts),
            "n_globals": len(getattr(vm, "globals", {}) or {}),
            "more": bool(getattr(m, "_list_more_waiting", False)),
            "obj": len(getattr(vm, "globals", {}) or {}),
            "arr": sum(
                1 for v in (getattr(vm, "globals", {}) or {}).values()
                if isinstance(v, list)
            ),
            "spr": spr,
            "n_ops": n_ops,
            "n_consts": n_consts,
            "n_html": len(src_lines),
            "sram_bytes": sram_bytes,
        }
