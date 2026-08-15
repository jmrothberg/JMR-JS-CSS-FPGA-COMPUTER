"""Python hardware model of the RTL JS VM — explicit code BRAM + JSB v2 load.

LLM NOTE: Constitution: FM → this HM (memories / sizes) → SystemVerilog.
Do not invent a third JS interpreter: opcode semantics stay in
functional_model.bytecode.VM. This module is the load/memory twin of
rtl/engines/jmr_js_vm.sv (CODE_WORDS, header parse, heap sizes).
"""

from __future__ import annotations

from pathlib import Path
import struct
from typing import Callable, Iterable, List, Optional

from functional_model.bytecode import VM
from functional_model.canvas_engine import CanvasEngine
from functional_model.input_engine import InputEngine
from functional_model.jsb_format import (
    FLAG_ASET,
    MAGIC,
    PROGRAM_CODE_WORDS,
    PROGRAM_MAX_CONSTS,
    PROGRAM_MAX_VARS,
    ProgramImage,
)
from functional_model.machine import Machine

# Match the current finite memories in rtl/engines/jmr_js_vm.sv.
CODE_WORDS = PROGRAM_CODE_WORDS
MAX_CONSTS = PROGRAM_MAX_CONSTS
MAX_VARS = PROGRAM_MAX_VARS
STACK_DEPTH = 2048
CALL_DEPTH = 128
MAX_OBJECTS = 8192
MAX_ARRAYS = 4096
HEAP_SLOTS = MAX_OBJECTS  # Backward-compatible name for the object heap cap.
OBJECT_SLOTS = 32
ARRAY_ELEMENTS = 128
ENV_DEPTH = 32
ENV_SLOTS = 16
RAF_QUEUE_DEPTH = 8
TIMER_QUEUE_DEPTH = 8
LISTENERS_PER_EVENT = 4


class _HardwareCapacityError(RuntimeError):
    pass


class _BoundedList(list):
    """List-shaped finite VM memory used by the transitional shared executor."""

    def __init__(
        self, capacity: int, label: str, overflow: Callable[[str], None]
    ) -> None:
        super().__init__()
        self._capacity = capacity
        self._label = label
        self._overflow = overflow

    def _check(self, new_len: int) -> None:
        if new_len > self._capacity:
            self._overflow(
                f"{self._label} overflow ({new_len} > {self._capacity})"
            )

    def append(self, value) -> None:
        self._check(len(self) + 1)
        super().append(value)

    def extend(self, values: Iterable) -> None:
        values = list(values)
        self._check(len(self) + len(values))
        super().extend(values)

    def insert(self, index: int, value) -> None:
        self._check(len(self) + 1)
        super().insert(index, value)

    def __iadd__(self, values):
        self.extend(values)
        return self

    def __setitem__(self, key, value) -> None:
        if isinstance(key, slice):
            replacement = list(value)
            removed = len(range(*key.indices(len(self))))
            self._check(len(self) - removed + len(replacement))
            super().__setitem__(key, replacement)
            return
        super().__setitem__(key, value)


class _HardwareCheckedVm(VM):
    """Transitional adapter: reuse VM semantics with finite stack memories."""

    def __init__(self, overflow: Callable[[str], None], natives=None) -> None:
        super().__init__(natives=natives)
        self.stack = _BoundedList(STACK_DEPTH, "eval stack", overflow)
        self.call_stack = _BoundedList(CALL_DEPTH, "call stack", overflow)


class JsHwVm:
    """Validate ProgramImage bytes, load finite memories, and execute them."""

    def __init__(self) -> None:
        self.code_mem: List[int] = [0] * CODE_WORDS
        self.n_ops = 0
        self.n_consts = 0
        self.n_vars = 0
        self.flags = 0
        self.ops_base = 0
        self.canvas = CanvasEngine()
        self.input = InputEngine()
        # Reuse FM natives/rAF/key listeners — HM owns memories + glass
        self._m = Machine()
        self._m.canvas = self.canvas
        self._m.input = self.input
        self.program_image: Optional[ProgramImage] = None
        self._capacity_error: Optional[str] = None
        self.error: Optional[str] = None
        self.running = False

    def load_blob(self, data: bytes) -> None:
        """Validate exact serialized bytes, then load that ProgramImage."""
        self.load_image(ProgramImage(data))

    def load_image(self, image: ProgramImage) -> None:
        """Write the validated code portion into code BRAM and execute it."""
        if not isinstance(image, ProgramImage):
            raise TypeError("load_image requires a validated ProgramImage")
        self.program_image = image
        data = image.data
        code_bytes = data[: image.code_end]
        pad = (-len(code_bytes)) % 4
        raw = code_bytes + b"\x00" * pad
        nwords = len(raw) // 4
        for i in range(nwords):
            self.code_mem[i] = int.from_bytes(raw[i * 4 : i * 4 + 4], "little")
        for i in range(nwords, CODE_WORDS):
            self.code_mem[i] = 0
        # Header words — same parse as jmr_js_vm.sv S_GOT_MAGIC / HDR1 / HDR2
        magic_w = self.code_mem[0]
        if magic_w != int.from_bytes(MAGIC, "little"):
            raise ValueError("code_mem magic mismatch")
        hdr1 = self.code_mem[1]
        self.n_ops = hdr1 & 0xFFFF
        self.n_consts = (hdr1 >> 16) & 0xFFFF
        hdr2 = self.code_mem[2]
        self.n_vars = hdr2 & 0xFFFF
        self.flags = (hdr2 >> 16) & 0xFFFF
        self.ops_base = (4 if (self.flags & FLAG_ASET) else 3) + self.n_consts
        if self.n_vars > MAX_VARS:
            raise ValueError(f"n_vars {self.n_vars} > MAX_VARS {MAX_VARS}")
        if self.n_consts > MAX_CONSTS:
            raise ValueError(f"n_consts {self.n_consts} > MAX_CONSTS {MAX_CONSTS}")
        if self.ops_base + self.n_ops > CODE_WORDS:
            raise ValueError(
                f"code {self.ops_base + self.n_ops} words > CODE_WORDS {CODE_WORDS}"
            )
        # Transitional execution adapter: opcode semantics remain in the FM VM,
        # but its Chunk is reconstructed only from validated serialized bytes.
        chunk = image.decode()
        self._capacity_error = None
        self._m.vm = _HardwareCheckedVm(
            self._record_capacity_error, natives=self._bounded_natives()
        )
        self._m.vm.globals.clear()
        self._m.html_host = None
        self._m._html_chunk = chunk
        self._m._sprites = list(getattr(chunk, "sprites", None) or [])
        self._m.vm._sprites = self._m._sprites
        self._m._raf_q = []
        self._m._listeners = []
        self._m._timers = []
        self._m._timer_seq = 1
        self._m._frame_no = 0
        self._m._bytecode_html = True
        self._m.running = True
        self._execute_checked(lambda: self._m.vm.run(chunk))

    def load_path(self, path: Path) -> None:
        self.load_blob(Path(path).read_bytes())

    def set_key_bits(self, bits: int) -> None:
        self._m.set_key_bits(bits)

    def frame_tick(self) -> None:
        if not self.running:
            return
        self._execute_checked(self._m.frame_tick)

    def _record_capacity_error(self, message: str) -> None:
        self._capacity_error = f"ERROR: HM CAPACITY: {message}"
        raise _HardwareCapacityError(self._capacity_error)

    def _bounded_natives(self):
        """Wrap only finite RTL queues; all native behavior stays in Machine."""
        natives = self._m._natives()

        def bounded_raf(fn=None):
            if fn is not None and len(getattr(self._m, "_raf_q", [])) >= RAF_QUEUE_DEPTH:
                self._record_capacity_error(
                    f"rAF queue overflow ({RAF_QUEUE_DEPTH} callbacks)"
                )
            return self._m._nat_raf(fn)

        def bounded_timeout(fn=None, ms=0, *args):
            if fn is not None and len(getattr(self._m, "_timers", [])) >= TIMER_QUEUE_DEPTH:
                self._record_capacity_error(
                    f"timer queue overflow ({TIMER_QUEUE_DEPTH} timers)"
                )
            return self._m._nat_set_timeout(fn, ms, *args)

        def bounded_interval(fn=None, ms=0, *args):
            if fn is not None and len(getattr(self._m, "_timers", [])) >= TIMER_QUEUE_DEPTH:
                self._record_capacity_error(
                    f"timer queue overflow ({TIMER_QUEUE_DEPTH} timers)"
                )
            return self._m._nat_set_interval(fn, ms, *args)

        def bounded_listener(event=None, fn=None, *args):
            if event is not None and fn is not None:
                ev = str(event)
                current = [
                    f for et, f in getattr(self._m, "_listeners", []) if et == ev
                ]
                if fn not in current and len(current) >= LISTENERS_PER_EVENT:
                    self._record_capacity_error(
                        f"{ev} listener overflow "
                        f"({LISTENERS_PER_EVENT} listeners)"
                    )
            return self._m._nat_add_event_listener(event, fn, *args)

        natives["requestAnimationFrame"] = bounded_raf
        natives["setTimeout"] = bounded_timeout
        natives["setInterval"] = bounded_interval
        for name in (
            "addEventListener",
            "document.addEventListener",
            "window.addEventListener",
        ):
            natives[name] = bounded_listener
        return natives

    def _check_runtime_capacities(self) -> None:
        """Count reachable JS heap values at VM safe points.

        This is intentionally transitional while opcode semantics are shared:
        Python reachability supplies collection, but finite RTL-shaped caps
        are checked after top-level execution and each frame/callback batch.
        """
        if len(self._m.vm.stack) > STACK_DEPTH:
            self._record_capacity_error("eval stack overflow")
        if len(self._m.vm.call_stack) > CALL_DEPTH:
            self._record_capacity_error("call stack overflow")
        if len(getattr(self._m, "_raf_q", [])) > RAF_QUEUE_DEPTH:
            self._record_capacity_error("rAF queue overflow")
        if len(getattr(self._m, "_timers", [])) > TIMER_QUEUE_DEPTH:
            self._record_capacity_error("timer queue overflow")
        per_event: dict[str, int] = {}
        for event, _fn in getattr(self._m, "_listeners", []):
            per_event[event] = per_event.get(event, 0) + 1
        for event, count in per_event.items():
            if count > LISTENERS_PER_EVENT:
                self._record_capacity_error(f"{event} listener overflow")

        seen: set[int] = set()
        objects = 0
        arrays = 0
        envs = 0

        def visit(value) -> None:
            nonlocal objects, arrays, envs
            if isinstance(value, (str, bytes, int, float, bool, type(None))):
                return
            oid = id(value)
            if oid in seen:
                return
            seen.add(oid)
            if isinstance(value, list):
                arrays += 1
                if arrays > MAX_ARRAYS:
                    self._record_capacity_error(
                        f"array heap overflow ({arrays} > {MAX_ARRAYS})"
                    )
                if len(value) > ARRAY_ELEMENTS:
                    self._record_capacity_error(
                        f"array length {len(value)} > {ARRAY_ELEMENTS}"
                    )
                for item in value:
                    visit(item)
                return
            if isinstance(value, dict):
                if "__par" in value:
                    envs += 1
                    if envs > ENV_DEPTH:
                        self._record_capacity_error(
                            f"environment overflow ({envs} > {ENV_DEPTH})"
                        )
                    if len(value) - 1 > ENV_SLOTS:
                        self._record_capacity_error(
                            f"environment slots {len(value) - 1} > {ENV_SLOTS}"
                        )
                else:
                    objects += 1
                    if objects > MAX_OBJECTS:
                        self._record_capacity_error(
                            f"object heap overflow ({objects} > {MAX_OBJECTS})"
                        )
                    if len(value) > OBJECT_SLOTS:
                        self._record_capacity_error(
                            f"object slots {len(value)} > {OBJECT_SLOTS}"
                        )
                for item in value.values():
                    visit(item)
                return
            if isinstance(value, tuple):
                for item in value:
                    visit(item)

        for root in self._m.vm.globals.values():
            visit(root)
        for root in self._m.vm.stack:
            visit(root)
        visit(self._m.vm.env)
        for root in self._m.vm.call_stack:
            visit(root)
        visit(getattr(self._m, "_raf_q", []))
        visit(getattr(self._m, "_timers", []))
        visit(getattr(self._m, "_listeners", []))

    def _execute_checked(self, action: Callable[[], None]) -> None:
        try:
            action()
            if self._capacity_error:
                raise _HardwareCapacityError(self._capacity_error)
            self._check_runtime_capacities()
        except _HardwareCapacityError as exc:
            self._halt_error(str(exc))
        except IndexError as exc:
            self._halt_error(f"ERROR: HM STACK/CALL UNDERFLOW: {exc}")
        else:
            self.error = self._m.vm.error
            self.running = bool(self._m.running) and not self.error
            if self.error:
                self._m.running = False
                self._m._bytecode_html = False

    def _halt_error(self, message: str) -> None:
        self.error = message
        self.running = False
        self._m.running = False
        self._m._bytecode_html = False
        self._m.vm.error = message
        self._m.vm.halted = True

    @staticmethod
    def _fnv_bytes(data: bytes, value: int = 0xCBF29CE484222325) -> int:
        for byte in data:
            value ^= byte
            value = (value * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
        return value

    def checkpoint(self) -> dict[str, int | str]:
        """Canonical safe-point state used by Python/RTL differential tests."""
        vars_hash = 0xCBF29CE484222325
        names = self.program_image.var_names if self.program_image else ()
        for slot in range(MAX_VARS):
            value = self.globals.get(names[slot]) if slot < len(names) else None
            tag = 0
            raw = 0
            if slot < len(names):
                if names[slot] not in self.globals:
                    tag = 0
                elif value is None:
                    tag = 5
                elif isinstance(value, bool):
                    raw = 1 if value else 0
                elif isinstance(value, int):
                    raw = value & 0xFFFFFFFF
                elif isinstance(value, float):
                    tag = 7
                    raw = int(value * 65536.0) & 0xFFFFFFFF
                elif isinstance(value, str):
                    tag = 3
                elif isinstance(value, list):
                    tag = 2
                elif isinstance(value, dict):
                    tag = 4 if value.get("__class") == "Fn" else 1
            vars_hash = self._fnv_bytes(struct.pack("<IB", raw, tag), vars_hash)

        def canonical(value, seen: set[int]) -> bytes:
            if value is None:
                return b"u"
            if isinstance(value, bool):
                return b"b1" if value else b"b0"
            if isinstance(value, int):
                return b"i" + struct.pack("<Q", value & 0xFFFFFFFFFFFFFFFF)
            if isinstance(value, float):
                return b"f" + struct.pack("<d", value)
            if isinstance(value, str):
                raw = value.encode("utf-8")
                return b"s" + struct.pack("<I", len(raw)) + raw
            oid = id(value)
            if oid in seen:
                return b"r"
            seen.add(oid)
            if isinstance(value, list):
                return b"a" + b"".join(canonical(v, seen) for v in value)
            if isinstance(value, tuple):
                return b"t" + b"".join(canonical(v, seen) for v in value)
            if isinstance(value, dict):
                out = bytearray(b"o")
                for key in sorted(value, key=str):
                    out += canonical(str(key), seen)
                    out += canonical(value[key], seen)
                return bytes(out)
            return b"?"

        heap_hash = 0xCBF29CE484222325
        seen: set[int] = set()
        for name in names:
            heap_hash = self._fnv_bytes(
                canonical(self.globals.get(name), seen), heap_hash
            )
        canvas_hash = self._fnv_bytes(bytes(self.canvas.front))
        op = int(self._m.vm.last_op) if self._m.vm.last_op is not None else 0
        return {
            "ip": int(self._m.vm.last_ip),
            "op": op,
            "sp": len(self._m.vm.stack),
            "csp": len(self._m.vm.call_stack),
            "vars": vars_hash,
            "heap": heap_hash,
            "raf": len(getattr(self._m, "_raf_q", [])),
            "timers": len(getattr(self._m, "_timers", [])),
            "listeners": len(getattr(self._m, "_listeners", [])),
            "canvas": canvas_hash,
            "error": self.error or "",
        }

    @property
    def globals(self):
        return self._m.vm.globals


def run_jsh_frames(
    path: Path,
    frames: int = 30,
    *,
    key_left_at: Optional[int] = None,
    key_fire_at: Optional[int] = None,
) -> JsHwVm:
    """Load NAME.JSH, drain rAF frames, optional KEYBITS (HM smoke)."""
    from functional_model.input_engine import KEY_FIRE, KEY_LEFT

    vm = JsHwVm()
    vm.load_path(path)
    for i in range(frames):
        if key_left_at is not None and i == key_left_at:
            vm.set_key_bits(KEY_LEFT)
        elif key_fire_at is not None and i == key_fire_at:
            vm.set_key_bits(KEY_FIRE)
        elif key_left_at is not None and i == key_left_at + 1:
            vm.set_key_bits(0)
        elif key_fire_at is not None and i == key_fire_at + 1:
            vm.set_key_bits(0)
        vm.frame_tick()
        if vm.error:
            break
    return vm
