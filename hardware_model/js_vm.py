"""Python hardware model of the RTL JS VM — explicit code BRAM + JSB v2 load.

LLM NOTE: Constitution: FM → this HM (memories / sizes) → SystemVerilog.
FLAG_VALUE64 opcode semantics execute here from serialized code_mem words;
the functional_model.bytecode.VM remains only the explicitly transitional
pre-Value64 path. This module is the load/memory twin of
rtl/engines/jmr_js_vm.sv (CODE_WORDS, header parse, heap sizes).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import json
import math
import re
import struct
from typing import Callable, Iterable, List, Optional

from functional_model.bytecode import Op, VM, _png_size_from_data_uri
from functional_model.canvas_engine import CanvasEngine
from functional_model.input_engine import InputEngine
from functional_model.jsb_format import (
    ASET_MAGIC,
    FLAG_ASET,
    FLAG_VALUE64,
    MAGIC,
    PROGRAM_CODE_WORDS,
    PROGRAM_MAX_CONSTS,
    PROGRAM_MAX_NAMES,
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
MAX_OBJECTS = 960  # 2026-08-21(2): mirrors RTL; 768 pegged in PACMAN play
# Two-tier arrays: leftover BRAM cannot hold 1024×128. Same 65536 × 64b
# words as 1024×32+256×128; more short handles for nested map literals plus
# wall/bean JSON clones (~1152), fewer long (bunker push still fits).
MAX_ARRAYS_SHORT = 1536
MAX_ARRAYS_LONG = 12  # 2026-08-21(3): mirrors RTL
MAX_ARRAYS = MAX_ARRAYS_SHORT + MAX_ARRAYS_LONG
HEAP_SLOTS = MAX_OBJECTS  # Backward-compatible name for the object heap cap.
OBJECT_SLOTS = 32
ARRAY_SHORT_CAP = 32
ARRAY_ELEMENTS = 128
# One env per live call/closure. `new Ctor()` bodies that MAKE_FN keep that
# ctor env for as long as those closures live (empty update/draw on instances).
ENV_DEPTH = 256  # 2026-08-21 fit: mirrors RTL (measured peak 157)
ENV_SLOTS = 16
RAF_QUEUE_DEPTH = 8
TIMER_QUEUE_DEPTH = 64
LISTENERS_PER_EVENT = 4
# Independent bank (same leftover-BRAM width as objects). Do not share a
# bump index with MAX_OBJECTS — that made obj+fn <= 1024.
MAX_FUNCTIONS = MAX_OBJECTS
CONSOLE_LOG_DEPTH = 256
LOCAL_STORAGE_SLOTS = 64
BUILTIN_ELEMENT = 1
BUILTIN_IMAGE = 2
BUILTIN_DATE = 3
BUILTIN_REGEXP = 4
BUILTIN_CONTEXT = 5
VALUE64_SUPPORTED_OPS = frozenset(
    {
        Op.LOAD_CONST,
        Op.LOAD_VAR,
        Op.STORE_VAR,
        Op.LET_VAR,
        Op.ADD,
        Op.SUB,
        Op.MUL,
        Op.DIV,
        Op.LT,
        Op.GT,
        Op.EQ,
        Op.JUMP,
        Op.JUMP_IF_FALSE,
        Op.CALL_NATIVE,
        Op.RETURN,
        Op.POP,
        Op.DUP,
        Op.NEG,
        Op.NOT,
        Op.MAKE_ARRAY,
        Op.ARRAY_GET,
        Op.ARRAY_SET,
        Op.MOD,
        Op.CALL_USER,
        Op.RET_VAL,
        Op.MAKE_OBJ,
        Op.GET_PROP,
        Op.SET_PROP,
        Op.NEW_OBJ,
        Op.CALL_METHOD,
        Op.BIT_OR,
        Op.BIT_AND,
        Op.MAKE_FN,
        Op.CALL_VAL,
    }
)

# Frozen 64-bit Value ABI. These helpers are the executable Python reference
# for the same synthesizable representation that the RTL number/heap engines
# consume; do not route hardware-model arithmetic through Python Any values.
VALUE_MASK = 0xFFFFFFFFFFFFFFFF
VALUE_TAG_PREFIX = 0x7FF9
VALUE_TAG_MASK = 0xFFFF000000000000
VALUE_CANON_NAN = 0x7FF8000000000000
VALUE_KIND_UNDEFINED = 1
VALUE_KIND_NULL = 2
VALUE_KIND_BOOL = 3
VALUE_KIND_STRING = 4
VALUE_KIND_OBJECT = 5
VALUE_KIND_ARRAY = 6
VALUE_KIND_FUNCTION = 7
VALUE_KIND_ELEMENT = 8
VALUE_KIND_ENV = 9
# Heap-less {x,y} / {} after GC compact. Identity lives in the generation
# field so `{} !== {}`. Payload: bit31 has_x, bit30 has_y, x/y signed 15-bit.
# SET_PROP of any other key boxes back into MAX_OBJECTS via _value_small_fwd.
VALUE_KIND_RECORD = 10
VALUE_UNINITIALIZED = 0x7FF9F00000000000
ERROR_NONE = 0
ERROR_STACK = 1
ERROR_CALL_FRAME = 2
ERROR_CAPACITY = 3
ERROR_HANDLE = 4
ERROR_UNSUPPORTED = 5
ERROR_DATA = 6
ERROR_INTERNAL = 255


def _s15(value: int) -> int:
    """Pack a signed 15-bit integer into bits 14:0."""
    return int(value) & 0x7FFF


def _s15_unpack(bits: int) -> int:
    bits &= 0x7FFF
    return bits - 0x8000 if bits & 0x4000 else bits


def record_pack(ident: int, has_x: bool, has_y: bool, x: int = 0, y: int = 0) -> int:
    payload = (
        (int(bool(has_x)) << 31)
        | (int(bool(has_y)) << 30)
        | (_s15(x) << 15)
        | _s15(y)
    )
    return value_pack_tagged(VALUE_KIND_RECORD, ident, payload)


def record_unpack(word: int) -> tuple[int, bool, bool, int, int]:
    payload = value_payload(word)
    return (
        value_generation(word),
        bool(payload & (1 << 31)),
        bool(payload & (1 << 30)),
        _s15_unpack(payload >> 15),
        _s15_unpack(payload),
    )


def value_pack_tagged(kind: int, generation: int = 0, payload: int = 0) -> int:
    """Pack one non-number Value with checked kind/generation fields."""
    if not 1 <= int(kind) <= 0xF:
        raise ValueError(f"invalid Value kind {kind}")
    if not 0 <= int(generation) <= 0xFFF:
        raise ValueError(f"invalid Value generation {generation}")
    if not 0 <= int(payload) <= 0xFFFFFFFF:
        raise ValueError(f"invalid Value payload {payload}")
    return (
        (VALUE_TAG_PREFIX << 48)
        | (int(kind) << 44)
        | (int(generation) << 32)
        | int(payload)
    )


def value_is_number(word: int) -> bool:
    return (int(word) & VALUE_TAG_MASK) != (VALUE_TAG_PREFIX << 48)


def value_kind(word: int) -> int | None:
    return None if value_is_number(word) else (int(word) >> 44) & 0xF


def value_generation(word: int) -> int:
    if value_is_number(word):
        raise TypeError("Number Value has no generation")
    return (int(word) >> 32) & 0xFFF


def value_payload(word: int) -> int:
    if value_is_number(word):
        raise TypeError("Number Value has no payload")
    return int(word) & 0xFFFFFFFF


def value_pack_number(number: float | int) -> int:
    """Pack an IEEE-754 binary64 Number and canonicalize every NaN."""
    number = float(number)
    if math.isnan(number):
        return VALUE_CANON_NAN
    return struct.unpack("<Q", struct.pack("<d", number))[0]


def value_unpack_number(word: int) -> float:
    if not value_is_number(word):
        raise TypeError("tagged Value is not a Number")
    return struct.unpack("<d", struct.pack("<Q", int(word) & VALUE_MASK))[0]


def value_add(left: int, right: int) -> int:
    return value_pack_number(value_unpack_number(left) + value_unpack_number(right))


def value_sub(left: int, right: int) -> int:
    return value_pack_number(value_unpack_number(left) - value_unpack_number(right))


def value_mul(left: int, right: int) -> int:
    return value_pack_number(value_unpack_number(left) * value_unpack_number(right))


def value_div(left: int, right: int) -> int:
    """ECMAScript binary64 division, including infinities and signed zero."""
    a = value_unpack_number(left)
    b = value_unpack_number(right)
    if math.isnan(a) or math.isnan(b):
        return VALUE_CANON_NAN
    if b == 0.0:
        if a == 0.0:
            return VALUE_CANON_NAN
        sign = -1.0 if math.copysign(1.0, a) != math.copysign(1.0, b) else 1.0
        return value_pack_number(math.copysign(math.inf, sign))
    if math.isinf(a) and math.isinf(b):
        return VALUE_CANON_NAN
    return value_pack_number(a / b)


def value_mod(left: int, right: int) -> int:
    """ECMAScript remainder (quotient truncates toward zero)."""
    a = value_unpack_number(left)
    b = value_unpack_number(right)
    if math.isnan(a) or math.isnan(b) or math.isinf(a) or b == 0.0:
        return VALUE_CANON_NAN
    if math.isinf(b):
        return value_pack_number(a)
    return value_pack_number(math.fmod(a, b))


def value_to_bitwise_number(word: int) -> int:
    """ECMAScript ToNumber before ToInt32: Bool 0/1, Number unchanged, else +0.

    The compiler ORs grouped `switch` cases with BIT_OR of EQ bools
    (`case "d": case "ArrowRight":`). Those operands are tagged BOOL,
    not Number — zeroing them made every grouped case miss.
    """
    if value_is_number(word):
        return word
    if value_kind(word) == VALUE_KIND_BOOL:
        return value_pack_number(float(value_payload(word) & 1))
    return value_pack_number(0.0)


def value_to_int32(word: int) -> int:
    """ECMAScript ToInt32 for bitwise operators."""
    number = value_unpack_number(value_to_bitwise_number(word))
    if not math.isfinite(number) or number == 0.0:
        return 0
    unsigned = math.trunc(number) % (1 << 32)
    return unsigned - (1 << 32) if unsigned >= (1 << 31) else unsigned


def value_bit_or(left: int, right: int) -> int:
    raw = (value_to_int32(left) | value_to_int32(right)) & 0xFFFFFFFF
    signed = raw - (1 << 32) if raw >= (1 << 31) else raw
    return value_pack_number(signed)


def value_bit_and(left: int, right: int) -> int:
    raw = (value_to_int32(left) & value_to_int32(right)) & 0xFFFFFFFF
    signed = raw - (1 << 32) if raw >= (1 << 31) else raw
    return value_pack_number(signed)


@dataclass
class _ValueEnv:
    parent: int
    slots: dict[int, int]


@dataclass(frozen=True)
class _ValueFunction:
    entry: int
    nparam: int
    captured_env: int
    is_arrow: bool
    is_iife: bool
    bound_this: int
    has_bound_this: bool


@dataclass(frozen=True)
class _ValueCallFrame:
    return_ip: int
    base_sp: int
    this_value: int
    lexical_env: int
    function_handle: int
    constructor_value: int
    # MAKE_FN in this activation captured the call env; do not free on RET.
    env_escaped: bool = False


@dataclass
class _ValueTimer:
    due_frame: int
    sequence: int
    period: Optional[int]
    function_handle: int


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
        self._error_code = ERROR_NONE
        self.running = False
        # FLAG_VALUE64 images execute only from these finite word memories.
        # Host values are materialized at the public globals boundary, never
        # used by the serialized-word ALU or variable store.
        self._value64_active = False
        self._value_stack: List[int] = []
        self._value_vars: List[int] = [0] * MAX_VARS
        self._value_var_valid: List[bool] = [False] * MAX_VARS
        self._value_calls: List[_ValueCallFrame] = []
        self._value_this = value_pack_tagged(VALUE_KIND_UNDEFINED)
        self._value_env = value_pack_tagged(VALUE_KIND_UNDEFINED)
        self._value_last_ip = 0
        self._value_last_op: Optional[Op] = None
        # Stable heap slots never move. A Value payload is the slot index and
        # its 12-bit generation must match before any slot can be dereferenced.
        self._value_objects: List[Optional[dict[int, int]]] = [None] * MAX_OBJECTS
        self._value_object_generations: List[int] = [1] * MAX_OBJECTS
        self._value_object_classes: List[Optional[int]] = [None] * MAX_OBJECTS
        self._value_object_builtins: List[Optional[int]] = [None] * MAX_OBJECTS
        # JS function.prototype / instance [[Prototype]] (function-ctor objects).
        self._value_function_prototypes: List[int] = [0] * MAX_FUNCTIONS
        self._value_object_protos: List[int] = [0] * MAX_OBJECTS
        self._value_regex: dict[int, tuple[str, bool, bool]] = {}
        self._value_arrays: List[Optional[List[int]]] = [None] * MAX_ARRAYS
        self._value_array_generations: List[int] = [1] * MAX_ARRAYS
        self._value_array_long: List[bool] = [False] * MAX_ARRAYS
        self._value_envs: List[Optional[_ValueEnv]] = [None] * ENV_DEPTH
        self._value_env_generations: List[int] = [1] * ENV_DEPTH
        self._value_functions: List[Optional[_ValueFunction]] = [
            None
        ] * MAX_FUNCTIONS
        self._value_function_generations: List[int] = [1] * MAX_FUNCTIONS
        self._value_raf: List[int] = []
        self._value_timers: List[_ValueTimer] = []
        self._value_listeners: List[tuple[int, int]] = []
        self._value_pending_image_loads: List[int] = []
        # MAKE_FN pins captured env + parents so caller RET cannot recycle
        # an env still linked as captured_env.parent (onload LOAD_VAR `ctx`).
        self._value_env_escaped_words: set[int] = set()
        self._value_dispatch_roots: List[int] = []
        self._value_timer_sequence = 1
        self._value_frame_no = 0
        self._value_rng = 0x6D2B79F5
        self.console_log: List[tuple] = []
        self._value_callback_result: Optional[int] = None
        self._value_strings: List[str] = []
        self._value_storage: dict[str, str] = {}
        self._value_start_loop = False
        # Canvas2D path/transform (Chunk hid these on the host dict).
        self._value_canvas_aux: List[dict] = [{} for _ in range(MAX_OBJECTS)]
        # Image._spr/_pix and ImageData._idx — not interned name slots.
        self._value_native_host: List[dict] = [{} for _ in range(MAX_OBJECTS)]
        # Compacted {x,y}/{} immediates (VALUE_KIND_RECORD). ident → heap if boxed.
        self._value_small_id = 1
        self._value_small_fwd: dict[int, int] = {}

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
        const_words = self.n_consts * (2 if self.flags & FLAG_VALUE64 else 1)
        self.ops_base = (4 if (self.flags & FLAG_ASET) else 3) + const_words
        if self.n_vars > MAX_VARS:
            raise ValueError(f"n_vars {self.n_vars} > MAX_VARS {MAX_VARS}")
        if self.n_consts > MAX_CONSTS:
            raise ValueError(f"n_consts {self.n_consts} > MAX_CONSTS {MAX_CONSTS}")
        if self.ops_base + self.n_ops > CODE_WORDS:
            raise ValueError(
                f"code {self.ops_base + self.n_ops} words > CODE_WORDS {CODE_WORDS}"
            )
        if self.flags & FLAG_VALUE64:
            # Phase-2 path: never decode a Chunk and never call VM.run().
            self._load_value64_words()
            return
        # Tagged Q16 images are retired with exec32 (docs/REMOVING_EXEC32.md):
        # refuse loud rather than silently execute an encoding the silicon
        # no longer decodes.
        raise ValueError(
            "ProgramImage without FLAG_VALUE64 — tagged images are retired "
            "with exec32 (docs/REMOVING_EXEC32.md)"
        )

    def _load_legacy_decoded_image(self, image: ProgramImage) -> None:
        """Explicit transitional path for pre-Value64 ProgramImages only."""
        # Transitional execution adapter: opcode semantics remain in the FM VM,
        # but its Chunk is reconstructed only from validated serialized bytes.
        chunk = image.decode()
        self._capacity_error = None
        self._value64_active = False
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

    def _load_value64_words(self) -> None:
        """Execute the finite Value64 subset directly from code_mem words."""
        self._capacity_error = None
        self.error = None
        self._error_code = ERROR_NONE
        self._value64_active = True
        self._value_stack = []
        self._value_vars = [0] * MAX_VARS
        self._value_var_valid = [False] * MAX_VARS
        self._value_calls = []
        self._value_this = value_pack_tagged(VALUE_KIND_UNDEFINED)
        self._value_env = value_pack_tagged(VALUE_KIND_UNDEFINED)
        self._value_last_ip = 0
        self._value_last_op = None
        self._value_objects = [None] * MAX_OBJECTS
        self._value_object_generations = [1] * MAX_OBJECTS
        self._value_object_classes = [None] * MAX_OBJECTS
        self._value_object_builtins = [None] * MAX_OBJECTS
        self._value_function_prototypes = [0] * MAX_FUNCTIONS
        self._value_object_protos = [0] * MAX_OBJECTS
        self._value_regex = {}
        self._value_arrays = [None] * MAX_ARRAYS
        self._value_array_generations = [1] * MAX_ARRAYS
        self._value_array_long = [False] * MAX_ARRAYS
        self._value_envs = [None] * ENV_DEPTH
        self._value_env_generations = [1] * ENV_DEPTH
        self._value_functions = [None] * MAX_FUNCTIONS
        self._value_function_generations = [1] * MAX_FUNCTIONS
        self._value_raf = []
        self._value_timers = []
        self._value_listeners = []
        self._value_pending_image_loads: List[int] = []
        self._value_env_escaped_words = set()
        self._value_dispatch_roots = []
        self._value_timer_sequence = 1
        self._value_frame_no = 0
        self._value_rng = 0x6D2B79F5
        self.console_log = []
        self._value_callback_result = None
        self._value_strings = list(
            self.program_image.names if self.program_image else ()
        )
        self._value_start_loop = False
        self._value_canvas_aux = [{} for _ in range(MAX_OBJECTS)]
        self._value_native_host = [{} for _ in range(MAX_OBJECTS)]
        self._value_small_id = 1
        self._value_small_fwd = {}
        names = self.program_image.names if self.program_image else ()
        for slot, name in enumerate(
            self.program_image.var_names if self.program_image else ()
        ):
            if name in ("Date", "Object") and name in names:
                self._value_vars[slot] = value_pack_tagged(
                    VALUE_KIND_STRING, payload=names.index(name)
                )
                self._value_var_valid[slot] = True
        self._m._html_chunk = None
        self._m._raf_q = []
        self._m._listeners = []
        self._m._timers = []
        self._load_value64_aset()
        self._m.running = True
        self.running = True
        self._execute_value64_words()

    def _load_value64_aset(self) -> None:
        """Stream ASET payload into the inner Machine's SRAM (observer, not Chunk)."""
        self._m._sprites = []
        self._m._spr_descs = []
        if not (self.flags & FLAG_ASET) or self.program_image is None:
            return
        data = self.program_image.data
        aset_off = struct.unpack_from("<I", data, 12)[0]
        if data[aset_off : aset_off + 4] != ASET_MAGIC:
            return
        payload_len = struct.unpack_from("<I", data, aset_off + 4)[0]
        payload = data[aset_off + 8 : aset_off + 8 + payload_len]
        self._m.sram.load(payload)
        if len(payload) >= 768:
            self.canvas.palette = [
                (payload[i * 3], payload[i * 3 + 1], payload[i * 3 + 2])
                for i in range(256)
            ]
        descs: List[tuple] = []
        sprd = data.find(b"SPRD", 16, aset_off)
        if sprd >= 0:
            n_spr = struct.unpack_from("<H", data, sprd + 4)[0]
            pos = sprd + 6
            for _ in range(n_spr):
                width, height, soff = struct.unpack_from("<HHI", data, pos)
                descs.append((int(width), int(height), int(soff)))
                pos += 8
        self._m._spr_descs = descs
        # Image.src jmr:spr:N indexes this pack; third is SRAM offset (not pixels).
        self._m._sprites = list(descs)

    def _value64_fault(self, message: str) -> None:
        """Halt a Value64 image loudly; this path must never delegate."""
        lower = message.lower()
        if "stack" in lower or "underflow" in lower:
            self._error_code = ERROR_STACK
        elif "overflow" in lower or "capacity" in lower or "slots" in lower:
            self._error_code = ERROR_CAPACITY
        elif "call" in lower or "frame" in lower or "environment" in lower:
            self._error_code = ERROR_CALL_FRAME
        elif "handle" in lower or "stale" in lower or "free " in lower:
            self._error_code = ERROR_HANDLE
        elif "unsupported" in lower or "unknown" in lower:
            self._error_code = ERROR_UNSUPPORTED
        elif "json" in lower or "string" in lower or "regexp" in lower:
            self._error_code = ERROR_DATA
        else:
            self._error_code = ERROR_INTERNAL
        self._halt_error(f"ERROR: HM VALUE64: {message}")

    def _value64_push(self, word: int) -> bool:
        if len(self._value_stack) >= STACK_DEPTH:
            self._value64_fault(
                f"eval stack overflow ({len(self._value_stack) + 1} > {STACK_DEPTH})"
            )
            return False
        self._value_stack.append(int(word) & VALUE_MASK)
        return True

    def _value64_pop(self, ip: int, op: Op) -> Optional[int]:
        if not self._value_stack:
            self._value64_fault(f"eval stack underflow at IP {ip} ({op.name})")
            return None
        return self._value_stack.pop()

    @staticmethod
    def _value64_truthy(word: int) -> bool:
        if value_is_number(word):
            number = value_unpack_number(word)
            return number != 0.0 and not math.isnan(number)
        kind = value_kind(word)
        if kind in (VALUE_KIND_UNDEFINED, VALUE_KIND_NULL):
            return False
        if kind == VALUE_KIND_BOOL:
            return bool(value_payload(word))
        return True

    def _value64_load_var(self, slot: int, ip: int, op: Op, mode: int = 0) -> Optional[int]:
        names = self.program_image.var_names if self.program_image else ()
        if slot < len(names) and names[slot] == "__this":
            return self._value_this
        # a1==1: global — skip env chain (MRDO palK / c).
        if mode == 1:
            if self._value_var_valid[slot]:
                return self._value_vars[slot]
            return value_pack_tagged(VALUE_KIND_UNDEFINED)
        # a1>=2: local env slot index (mode-2). Dict is still keyed by name id.
        if mode >= 2:
            env = None
            if value_kind(self._value_env) == VALUE_KIND_ENV:
                env = self._value64_resolve_env(self._value_env, ip, op)
            if env is not None:
                if slot in env.slots:
                    return env.slots[slot]
                return value_pack_tagged(VALUE_KIND_UNDEFINED)
            # Flat IIFE / no ENV: same as LET_VAR local with vcsp==0 → vvars.
            if self._value_var_valid[slot]:
                return self._value_vars[slot]
            return value_pack_tagged(VALUE_KIND_UNDEFINED)
        env_handle = self._value_env
        while value_kind(env_handle) == VALUE_KIND_ENV:
            env = self._value64_resolve_env(env_handle, ip, op)
            if env is None:
                return None
            if slot in env.slots:
                return env.slots[slot]
            env_handle = env.parent
        if self._value_var_valid[slot]:
            return self._value_vars[slot]
        return value_pack_tagged(VALUE_KIND_UNDEFINED)

    def _value64_store_var(self, slot: int, word: int, ip: int, op: Op, mode: int = 0) -> bool:
        names = self.program_image.var_names if self.program_image else ()
        if slot < len(names) and names[slot] == "__this":
            self._value_this = word
            return True
        if mode == 1:
            self._value_vars[slot] = word
            self._value_var_valid[slot] = True
            return True
        if mode >= 2:
            env = None
            if value_kind(self._value_env) == VALUE_KIND_ENV:
                env = self._value64_resolve_env(self._value_env, ip, op)
            if env is not None:
                env.slots[slot] = word
                return True
            self._value_vars[slot] = word
            self._value_var_valid[slot] = True
            return True
        env_handle = self._value_env
        while value_kind(env_handle) == VALUE_KIND_ENV:
            env = self._value64_resolve_env(env_handle, ip, op)
            if env is None:
                return False
            if slot in env.slots:
                env.slots[slot] = word
                return True
            env_handle = env.parent
        self._value_vars[slot] = word
        self._value_var_valid[slot] = True
        return True

    def _value64_declare_local(self, slot: int, word: int, ip: int) -> bool:
        env = self._value64_resolve_env(self._value_env, ip, Op.LET_VAR)
        if env is None:
            return False
        if slot not in env.slots and len(env.slots) >= ENV_SLOTS:
            self._value64_fault(
                f"environment slots {len(env.slots) + 1} > {ENV_SLOTS} at IP {ip}"
            )
            return False
        env.slots[slot] = word
        return True

    def _value64_alloc_env(
        self, parent: int, ip: int, extra_roots: Optional[Iterable[int]] = None
    ) -> Optional[int]:
        for index, slot in enumerate(self._value_envs):
            if slot is None:
                self._value_envs[index] = _ValueEnv(parent, {})
                return value_pack_tagged(
                    VALUE_KIND_ENV, self._value_env_generations[index], index
                )
        roots = [parent]
        if extra_roots is not None:
            roots.extend(extra_roots)
        self._value64_collect(roots)
        for index, slot in enumerate(self._value_envs):
            if slot is None:
                self._value_envs[index] = _ValueEnv(parent, {})
                return value_pack_tagged(
                    VALUE_KIND_ENV, self._value_env_generations[index], index
                )
        self._value64_fault(
            f"environment heap overflow ({ENV_DEPTH + 1} > {ENV_DEPTH}) at IP {ip}"
        )
        return None

    def _value64_alloc_function(
        self, function: _ValueFunction, ip: int
    ) -> Optional[int]:
        for index, slot in enumerate(self._value_functions):
            # Functions and objects are different kinds (PYTHON lists are
            # already separate). Do not require objects[index] is None —
            # that shared the leftover-BRAM 1024 bump and faulted PACMAN
            # at MAKE_FN while hundreds of object slots were still free.
            if slot is None:
                self._value_functions[index] = function
                self._value_function_prototypes[index] = 0
                return value_pack_tagged(
                    VALUE_KIND_FUNCTION,
                    self._value_function_generations[index],
                    index,
                )
        self._value64_collect((function.captured_env, function.bound_this))
        for index, slot in enumerate(self._value_functions):
            if slot is None:
                self._value_functions[index] = function
                self._value_function_prototypes[index] = 0
                return value_pack_tagged(
                    VALUE_KIND_FUNCTION,
                    self._value_function_generations[index],
                    index,
                )
        self._value64_fault(
            f"function heap overflow ({MAX_FUNCTIONS + 1} > {MAX_FUNCTIONS}) "
            f"at IP {ip}"
        )
        return None

    def _value64_long_count(self) -> int:
        n = 0
        for index, slot in enumerate(self._value_arrays):
            if slot is None:
                continue
            if index >= MAX_ARRAYS_SHORT or self._value_array_long[index]:
                n += 1
        return n

    def _value64_ensure_long(self, index: int, ip: int) -> bool:
        """Promote a short-bank array in place (same handle). Overflow loud."""
        if index >= MAX_ARRAYS_SHORT or self._value_array_long[index]:
            return True
        if self._value64_long_count() >= MAX_ARRAYS_LONG:
            self._value64_fault(
                f"long array overflow ({MAX_ARRAYS_LONG + 1} > "
                f"{MAX_ARRAYS_LONG}) at IP {ip}"
            )
            return False
        self._value_array_long[index] = True
        return True

    def _value64_alloc_array(
        self,
        items: List[int],
        ip: int,
        extra_roots: Optional[Iterable[int]] = None,
    ) -> Optional[int]:
        need_long = len(items) > ARRAY_SHORT_CAP
        if need_long:
            ranges = ((MAX_ARRAYS_SHORT, MAX_ARRAYS),)
        else:
            # Spill into the long-handle range when the short bank is full
            # (nested map literals + JSON clones exceed the short bank).
            ranges = (
                (0, MAX_ARRAYS_SHORT),
                (MAX_ARRAYS_SHORT, MAX_ARRAYS),
            )
        def _collect() -> None:
            n0 = len(items)
            if extra_roots is not None:
                items.extend(extra_roots)
            self._value64_collect(items)
            if extra_roots is not None:
                del items[n0:]
        if need_long and self._value64_long_count() >= MAX_ARRAYS_LONG:
            _collect()
            if self._value64_long_count() >= MAX_ARRAYS_LONG:
                self._value64_fault(
                    f"long array overflow ({MAX_ARRAYS_LONG + 1} > "
                    f"{MAX_ARRAYS_LONG}) at IP {ip}"
                )
                return None
        def _try(lo: int, hi: int) -> Optional[int]:
            for index in range(lo, hi):
                if self._value_arrays[index] is None:
                    use_long = need_long or index >= MAX_ARRAYS_SHORT
                    if use_long and self._value64_long_count() >= MAX_ARRAYS_LONG:
                        continue
                    self._value_arrays[index] = list(items)
                    self._value_array_long[index] = use_long
                    return value_pack_tagged(
                        VALUE_KIND_ARRAY,
                        self._value_array_generations[index],
                        index,
                    )
            return None
        for lo, hi in ranges:
            handle = _try(lo, hi)
            if handle is not None:
                return handle
        _collect()
        for lo, hi in ranges:
            handle = _try(lo, hi)
            if handle is not None:
                return handle
        self._value64_fault(
            f"array heap overflow ({MAX_ARRAYS + 1} > {MAX_ARRAYS}) at IP {ip}"
        )
        return None

    def _value64_alloc_object(
        self, ip: int, extra_roots: Optional[Iterable[int]] = None
    ) -> Optional[int]:
        for index, slot in enumerate(self._value_objects):
            # Same split as alloc_function: object index != function index.
            if slot is None:
                self._value_objects[index] = {}
                self._value_object_protos[index] = 0
                return value_pack_tagged(
                    VALUE_KIND_OBJECT,
                    self._value_object_generations[index],
                    index,
                )
        self._value64_collect(extra_roots)
        for index, slot in enumerate(self._value_objects):
            if slot is None:
                self._value_objects[index] = {}
                self._value_object_protos[index] = 0
                return value_pack_tagged(
                    VALUE_KIND_OBJECT,
                    self._value_object_generations[index],
                    index,
                )
        self._value64_fault(
            f"object heap overflow ({MAX_OBJECTS + 1} > {MAX_OBJECTS}) at IP {ip}"
        )
        return None

    def _value64_new_record(self) -> int:
        ident = self._value_small_id
        self._value_small_id = 1 if ident >= 0xFFF else ident + 1
        return record_pack(ident, False, False)

    def _value64_record_follow(self, handle: int) -> int:
        """Walk RECORD → box / newer RECORD. Compact rewrites fwd[ident]
        to a new RECORD, so one hop would still unpack the stale x/y.
        """
        if value_kind(handle) != VALUE_KIND_RECORD:
            return handle
        seen: set[int] = set()
        while value_kind(handle) == VALUE_KIND_RECORD:
            ident = value_generation(handle)
            if ident in seen:
                break
            seen.add(ident)
            nxt = self._value_small_fwd.get(ident)
            if nxt is None:
                break
            handle = nxt
        return handle

    def _value64_record_box(self, handle: int, ip: int) -> Optional[int]:
        """Box a RECORD into a heap object so SET_PROP can mutate it.

        Compact rewrites fwd[ident] to a newer RECORD. Returning that
        RECORD made SET_PROP a no-op (primitive). Follow first; only
        reuse an existing heap object.
        """
        handle = self._value64_record_follow(handle)
        if value_kind(handle) in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
            return handle
        if value_kind(handle) != VALUE_KIND_RECORD:
            return handle
        ident = value_generation(handle)
        existing = self._value_small_fwd.get(ident)
        if existing is not None and value_kind(existing) in (
            VALUE_KIND_OBJECT,
            VALUE_KIND_ELEMENT,
        ):
            return existing
        boxed = self._value64_alloc_object(ip, (handle,))
        if boxed is None:
            return None
        _ident, has_x, has_y, x, y = record_unpack(handle)
        obj = self._value_objects[value_payload(boxed)]
        if has_x:
            key = self._value64_interned_string("x", ip)
            if key is None:
                return None
            obj[value_payload(key)] = value_pack_number(x)
        if has_y:
            key = self._value64_interned_string("y", ip)
            if key is None:
                return None
            obj[value_payload(key)] = value_pack_number(y)
        self._value_small_fwd[ident] = boxed
        return boxed

    def _value64_compactable_record(self, index: int) -> Optional[int]:
        """Empty or {x,y} number records can leave the 1024-slot object heap."""
        obj = self._value_objects[index]
        if obj is None:
            return None
        if self._value_object_builtins[index]:
            return None
        if self._value_object_classes[index] is not None:
            return None
        if self._value_object_protos[index]:
            return None
        if self._value_native_host[index]:
            return None
        if self._value_canvas_aux[index]:
            return None
        if index in self._value_regex:
            return None
        try:
            xi = self._value_strings.index("x")
            yi = self._value_strings.index("y")
        except ValueError:
            xi = yi = -1
        if len(obj) == 0:
            return None
        extra = [key for key in obj if key != xi and key != yi]
        if extra or xi < 0 or yi < 0:
            return None
        has_x = xi in obj
        has_y = yi in obj
        if not (has_x and has_y):
            return None
        x = y = 0
        if has_x:
            word = obj[xi]
            if not value_is_number(word):
                return None
            x = value_unpack_number(word)
            if x != int(x) or not -16384 <= int(x) <= 16383:
                return None
            x = int(x)
        if has_y:
            word = obj[yi]
            if not value_is_number(word):
                return None
            y = value_unpack_number(word)
            if y != int(y) or not -16384 <= int(y) <= 16383:
                return None
            y = int(y)
        ident = self._value_small_id
        self._value_small_id = 1 if ident >= 0xFFF else ident + 1
        return record_pack(ident, has_x, has_y, x, y)

    def _value64_rewrite_word(self, word: int, mapping: dict[int, int]) -> int:
        kind = value_kind(word)
        if kind not in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
            return word
        index = value_payload(word)
        if (
            index in mapping
            and value_generation(word) == self._value_object_generations[index]
        ):
            return mapping[index]
        return word

    def _value64_rewrite_list(self, items: list, mapping: dict[int, int]) -> None:
        """Rewrite one list in place so Python aliases (forEach/map) stay live."""
        rw = self._value64_rewrite_word
        for i, word in enumerate(items):
            items[i] = rw(word, mapping)

    def _value64_rewrite_all(self, mapping: dict[int, int]) -> None:
        """Replace compacted object handles everywhere a Value word is stored."""
        if not mapping:
            return
        rw = self._value64_rewrite_word
        self._value64_rewrite_list(self._value_stack, mapping)
        for slot, valid in enumerate(self._value_var_valid):
            if valid:
                self._value_vars[slot] = rw(self._value_vars[slot], mapping)
        self._value_this = rw(self._value_this, mapping)
        self._value_env = rw(self._value_env, mapping)
        if self._value_callback_result is not None:
            self._value_callback_result = rw(
                self._value_callback_result, mapping
            )
        self._value64_rewrite_list(self._value_raf, mapping)
        self._value64_rewrite_list(self._value_dispatch_roots, mapping)
        self._value64_rewrite_list(self._value_pending_image_loads, mapping)
        self._value_listeners = [
            (rw(e, mapping), rw(f, mapping)) for e, f in self._value_listeners
        ]
        for timer in self._value_timers:
            timer.function_handle = rw(timer.function_handle, mapping)
        for extra in self._value_native_host:
            for key, item in list(extra.items()):
                if isinstance(item, int) and not value_is_number(item):
                    extra[key] = rw(item, mapping)
        rewritten_frames = []
        for frame in self._value_calls:
            rewritten_frames.append(
                _ValueCallFrame(
                    return_ip=frame.return_ip,
                    base_sp=frame.base_sp,
                    this_value=rw(frame.this_value, mapping),
                    lexical_env=rw(frame.lexical_env, mapping),
                    function_handle=rw(frame.function_handle, mapping),
                    constructor_value=rw(frame.constructor_value, mapping),
                    env_escaped=frame.env_escaped,
                )
            )
        self._value_calls = rewritten_frames
        for index, obj in enumerate(self._value_objects):
            if obj is None or index in mapping:
                continue
            for key, value in list(obj.items()):
                obj[key] = rw(value, mapping)
            self._value_object_protos[index] = rw(
                self._value_object_protos[index], mapping
            )
        for array in self._value_arrays:
            if array is None:
                continue
            for i, value in enumerate(array):
                array[i] = rw(value, mapping)
        for env in self._value_envs:
            if env is None:
                continue
            env.parent = rw(env.parent, mapping)
            for key, value in list(env.slots.items()):
                env.slots[key] = rw(value, mapping)
        for index, function in enumerate(self._value_functions):
            if function is None:
                continue
            self._value_functions[index] = _ValueFunction(
                entry=function.entry,
                nparam=function.nparam,
                captured_env=rw(function.captured_env, mapping),
                is_arrow=function.is_arrow,
                is_iife=function.is_iife,
                bound_this=rw(function.bound_this, mapping),
                has_bound_this=function.has_bound_this,
            )
            self._value_function_prototypes[index] = rw(
                self._value_function_prototypes[index], mapping
            )
        for ident, boxed in list(self._value_small_fwd.items()):
            self._value_small_fwd[ident] = rw(boxed, mapping)

    def _value64_compact_records(
        self,
        marked_objects: set[int],
        extra_roots: Optional[Iterable[int]] = None,
    ) -> dict[int, int]:
        """Move empty/{x,y} heap objects to RECORD immediates (same MAX_OBJ cap)."""
        mapping: dict[int, int] = {}
        for index in list(marked_objects):
            immediate = self._value64_compactable_record(index)
            if immediate is None:
                continue
            mapping[index] = immediate
        if not mapping:
            return mapping
        self._value64_rewrite_all(mapping)
        # extra_roots are Python locals; rewrite before gen bump on release.
        if extra_roots is not None and isinstance(extra_roots, list):
            self._value64_rewrite_list(extra_roots, mapping)
        for index in mapping:
            self._value64_release_handle(
                value_pack_tagged(
                    VALUE_KIND_OBJECT,
                    self._value_object_generations[index],
                    index,
                )
            )
            marked_objects.discard(index)
        return mapping

    def _value64_collect(self, extra_roots: Optional[Iterable[int]] = None) -> None:
        """Deterministic mark/sweep over every Value64 machine root."""
        roots = [
            self._value_vars[slot]
            for slot in range(self.n_vars)
            if self._value_var_valid[slot]
        ]
        roots.extend(self._value_stack)
        roots.extend((self._value_this, self._value_env))
        roots.extend(self._value_raf)
        roots.extend(timer.function_handle for timer in self._value_timers)
        roots.extend(function for _event, function in self._value_listeners)
        roots.extend(self._value_dispatch_roots)
        roots.extend(self._value_pending_image_loads)
        for extra in self._value_native_host:
            for item in extra.values():
                if isinstance(item, int) and not value_is_number(item):
                    kind = value_kind(item)
                    if kind in (
                        VALUE_KIND_OBJECT,
                        VALUE_KIND_ELEMENT,
                        VALUE_KIND_ARRAY,
                        VALUE_KIND_FUNCTION,
                        VALUE_KIND_ENV,
                        VALUE_KIND_RECORD,
                    ):
                        roots.append(item)
        for frame in self._value_calls:
            roots.extend(
                (
                    frame.this_value,
                    frame.lexical_env,
                    frame.function_handle,
                    frame.constructor_value,
                )
            )
        if extra_roots is not None:
            roots.extend(extra_roots)

        marked_objects: set[int] = set()
        marked_arrays: set[int] = set()
        marked_envs: set[int] = set()
        marked_functions: set[int] = set()
        pending = list(roots)
        while pending:
            handle = pending.pop()
            kind = value_kind(handle)
            if kind in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
                index = value_payload(handle)
                if (
                    index >= MAX_OBJECTS
                    or value_generation(handle)
                    != self._value_object_generations[index]
                    or self._value_objects[index] is None
                    or index in marked_objects
                ):
                    continue
                marked_objects.add(index)
                pending.extend(self._value_objects[index].values())
                pending.append(self._value_object_protos[index])
            elif kind == VALUE_KIND_ARRAY:
                index = value_payload(handle)
                if (
                    index >= MAX_ARRAYS
                    or value_generation(handle)
                    != self._value_array_generations[index]
                    or self._value_arrays[index] is None
                    or index in marked_arrays
                ):
                    continue
                marked_arrays.add(index)
                pending.extend(self._value_arrays[index])
            elif kind == VALUE_KIND_ENV:
                index = value_payload(handle)
                if (
                    index >= ENV_DEPTH
                    or value_generation(handle)
                    != self._value_env_generations[index]
                    or self._value_envs[index] is None
                    or index in marked_envs
                ):
                    continue
                marked_envs.add(index)
                env = self._value_envs[index]
                pending.append(env.parent)
                pending.extend(env.slots.values())
            elif kind == VALUE_KIND_FUNCTION:
                index = value_payload(handle)
                if (
                    index >= MAX_FUNCTIONS
                    or value_generation(handle)
                    != self._value_function_generations[index]
                    or self._value_functions[index] is None
                    or index in marked_functions
                ):
                    continue
                marked_functions.add(index)
                function = self._value_functions[index]
                pending.extend((function.captured_env, function.bound_this))
                pending.append(self._value_function_prototypes[index])
            elif kind == VALUE_KIND_RECORD:
                boxed = self._value_small_fwd.get(value_generation(handle))
                if boxed is not None:
                    pending.append(boxed)

        # extra_roots (invoke args, JSON walk) rewritten here, before release.
        self._value64_compact_records(marked_objects, extra_roots)

        for index, slot in enumerate(self._value_objects):
            if slot is not None and index not in marked_objects:
                self._value64_release_handle(
                    value_pack_tagged(
                        VALUE_KIND_OBJECT,
                        self._value_object_generations[index],
                        index,
                    )
                )
        for index, slot in enumerate(self._value_arrays):
            if slot is not None and index not in marked_arrays:
                self._value64_release_handle(
                    value_pack_tagged(
                        VALUE_KIND_ARRAY,
                        self._value_array_generations[index],
                        index,
                    )
                )
        for index, slot in enumerate(self._value_envs):
            if slot is not None and index not in marked_envs:
                self._value64_release_handle(
                    value_pack_tagged(
                        VALUE_KIND_ENV,
                        self._value_env_generations[index],
                        index,
                    )
                )
        for index, slot in enumerate(self._value_functions):
            if slot is not None and index not in marked_functions:
                self._value64_release_handle(
                    value_pack_tagged(
                        VALUE_KIND_FUNCTION,
                        self._value_function_generations[index],
                        index,
                    )
                )

    def _value64_resolve_array(
        self, handle: int, ip: int, op: Op
    ) -> Optional[List[int]]:
        if value_kind(handle) != VALUE_KIND_ARRAY:
            self._value64_fault(f"{op.name} requires an array handle at IP {ip}")
            return None
        index = value_payload(handle)
        if index >= MAX_ARRAYS:
            self._value64_fault(f"array handle index {index} out of range at IP {ip}")
            return None
        generation = value_generation(handle)
        expected = self._value_array_generations[index]
        if generation != expected:
            self._value64_fault(
                f"stale array handle at IP {ip} "
                f"(slot {index} generation {generation} != {expected})"
            )
            return None
        slot = self._value_arrays[index]
        if slot is None:
            self._value64_fault(f"free array handle at IP {ip} (slot {index})")
            return None
        return slot

    def _value64_resolve_object(
        self, handle: int, ip: int, op: Op
    ) -> Optional[dict[int, int]]:
        if value_kind(handle) != VALUE_KIND_OBJECT:
            self._value64_fault(f"{op.name} requires an object handle at IP {ip}")
            return None
        index = value_payload(handle)
        if index >= MAX_OBJECTS:
            self._value64_fault(f"object handle index {index} out of range at IP {ip}")
            return None
        generation = value_generation(handle)
        expected = self._value_object_generations[index]
        if generation != expected:
            self._value64_fault(
                f"stale object handle at IP {ip} "
                f"(slot {index} generation {generation} != {expected})"
            )
            return None
        slot = self._value_objects[index]
        if slot is None:
            self._value64_fault(f"free object handle at IP {ip} (slot {index})")
            return None
        return slot

    def _value64_resolve_env(
        self, handle: int, ip: int, op: Op
    ) -> Optional[_ValueEnv]:
        if value_kind(handle) != VALUE_KIND_ENV:
            self._value64_fault(f"{op.name} requires an environment handle at IP {ip}")
            return None
        index = value_payload(handle)
        if index >= ENV_DEPTH:
            self._value64_fault(
                f"environment handle index {index} out of range at IP {ip}"
            )
            return None
        generation = value_generation(handle)
        expected = self._value_env_generations[index]
        if generation != expected:
            self._value64_fault(
                f"stale environment handle at IP {ip} "
                f"(slot {index} generation {generation} != {expected})"
            )
            return None
        slot = self._value_envs[index]
        if slot is None:
            self._value64_fault(f"free environment handle at IP {ip} (slot {index})")
            return None
        return slot

    def _value64_resolve_function(
        self, handle: int, ip: int, op: Op
    ) -> Optional[_ValueFunction]:
        if value_kind(handle) != VALUE_KIND_FUNCTION:
            self._value64_fault(f"{op.name} requires a function handle at IP {ip}")
            return None
        index = value_payload(handle)
        if index >= MAX_FUNCTIONS:
            self._value64_fault(
                f"function handle index {index} out of range at IP {ip}"
            )
            return None
        generation = value_generation(handle)
        expected = self._value_function_generations[index]
        if generation != expected:
            self._value64_fault(
                f"stale function handle at IP {ip} "
                f"(slot {index} generation {generation} != {expected})"
            )
            return None
        slot = self._value_functions[index]
        if slot is None:
            self._value64_fault(f"free function handle at IP {ip} (slot {index})")
            return None
        return slot

    def _value64_release_handle(self, handle: int) -> None:
        """Release one stable slot and invalidate all prior generations."""
        kind = value_kind(handle)
        index = value_payload(handle)
        if kind == VALUE_KIND_ARRAY and index < MAX_ARRAYS:
            self._value_arrays[index] = None
            self._value_array_long[index] = False
            generation = (self._value_array_generations[index] + 1) & 0xFFF
            self._value_array_generations[index] = generation or 1
        elif kind == VALUE_KIND_OBJECT and index < MAX_OBJECTS:
            self._value_objects[index] = None
            self._value_object_classes[index] = None
            self._value_object_builtins[index] = None
            self._value_object_protos[index] = 0
            self._value_canvas_aux[index] = {}
            self._value_native_host[index] = {}
            self._value_regex.pop(index, None)
            generation = (self._value_object_generations[index] + 1) & 0xFFF
            self._value_object_generations[index] = generation or 1
        elif kind == VALUE_KIND_ENV and index < ENV_DEPTH:
            self._value_envs[index] = None
            generation = (self._value_env_generations[index] + 1) & 0xFFF
            self._value_env_generations[index] = generation or 1
            # Drop leftover MAKE_FN pins for this slot (old generation).
            self._value_env_escaped_words = {
                word
                for word in self._value_env_escaped_words
                if not (
                    value_kind(word) == VALUE_KIND_ENV
                    and value_payload(word) == index
                )
            }
        elif kind == VALUE_KIND_FUNCTION and index < MAX_FUNCTIONS:
            self._value_functions[index] = None
            self._value_function_prototypes[index] = 0
            generation = (self._value_function_generations[index] + 1) & 0xFFF
            self._value_function_generations[index] = generation or 1

    def _value64_mark_env_escaped(self) -> None:
        """MAKE_FN captured this activation's env — RET must not recycle it."""
        if not self._value_calls:
            return
        frame = self._value_calls[-1]
        if frame.env_escaped:
            return
        self._value_calls[-1] = _ValueCallFrame(
            return_ip=frame.return_ip,
            base_sp=frame.base_sp,
            this_value=frame.this_value,
            lexical_env=frame.lexical_env,
            function_handle=frame.function_handle,
            constructor_value=frame.constructor_value,
            env_escaped=True,
        )

    def _value64_pin_captured_env_chain(self, captured_env: int) -> None:
        """Pin captured_env + parents so a caller RET cannot recycle them.

        MAKE_FN only sets env_escaped on the current frame. An onload arrow
        made inside `show()` still LOAD_VAR-walks `show`'s parent — the rAF
        `tick`/`update` env. That parent is not env_escaped, so RET recycled
        it (stale generation). Pin the env words only; do not mark ancestor
        *frames* env_escaped (that skipped inner forEach/animate RET).
        Walk by generation, do not fault — a stale parent is not a pin.
        Not a GC root: live closures already mark captured_env → parent.
        """
        handle = captured_env
        seen: set[int] = set()
        while value_kind(handle) == VALUE_KIND_ENV and handle not in seen:
            seen.add(handle)
            index = value_payload(handle)
            if index >= ENV_DEPTH:
                break
            if value_generation(handle) != self._value_env_generations[index]:
                break
            env = self._value_envs[index]
            if env is None:
                break
            self._value_env_escaped_words.add(handle)
            handle = env.parent

    def _value64_leave_call_frame(self, frame: _ValueCallFrame) -> None:
        """Pop one call: restore parent, free a non-escaping leaf env.

        palK/drawPix alloc an env per CALL_USER. Without this, ENV_DEPTH
        fills and GC runs tens of times per paint (PYTHON ~1 fps, FPGA-SIM
        ~10M clocks/frame). Closures set env_escaped so finder/forEach keep
        their captured env. MAKE_FN also pins parent env words (onload
        LOAD_VAR after the rAF caller returns).
        """
        leaving = self._value_env
        self._value_calls.pop()
        self._value_this = frame.this_value
        self._value_env = frame.lexical_env
        if (
            not frame.env_escaped
            and value_kind(leaving) == VALUE_KIND_ENV
            and leaving != frame.lexical_env
            and leaving not in self._value_env_escaped_words
        ):
            self._value64_release_handle(leaving)

    def _value64_string_text(self, word: int, ip: int, op: Op) -> Optional[str]:
        if value_kind(word) != VALUE_KIND_STRING:
            self._value64_fault(f"{op.name} requires a string Value at IP {ip}")
            return None
        index = value_payload(word)
        if index >= len(self._value_strings):
            self._value64_fault(f"string index {index} out of range at IP {ip}")
            return None
        return self._value_strings[index]

    def _value64_js_tostring(self, word: int) -> str:
        """JS ToString without faulting (String.prototype.indexOf(0) → '0')."""
        if value_kind(word) == VALUE_KIND_STRING:
            index = value_payload(word)
            return (
                self._value_strings[index]
                if index < len(self._value_strings)
                else ""
            )
        if value_kind(word) == VALUE_KIND_UNDEFINED:
            return "undefined"
        if value_kind(word) == VALUE_KIND_NULL:
            return "null"
        if value_kind(word) == VALUE_KIND_BOOL:
            return "true" if value_payload(word) else "false"
        host = self._value64_host_value(word)
        if isinstance(host, float) and math.isfinite(host) and host == int(host):
            return str(int(host))
        if host is None:
            return "undefined"
        return str(host)

    def _value64_interned_string(self, text: str, ip: int) -> Optional[int]:
        try:
            index = self._value_strings.index(text)
        except ValueError:
            if len(self._value_strings) >= PROGRAM_MAX_NAMES:
                self._value64_fault(
                    f"string table overflow ({len(self._value_strings) + 1} > "
                    f"{PROGRAM_MAX_NAMES}) at IP {ip}"
                )
                return None
            index = len(self._value_strings)
            self._value_strings.append(text)
        return value_pack_tagged(VALUE_KIND_STRING, payload=index)

    def _value64_property_slot(
        self, key: int, ip: int, op: Op
    ) -> Optional[int]:
        """Intern a computed property key to the string/name table index."""
        if value_kind(key) == VALUE_KIND_STRING:
            text = self._value64_string_text(key, ip, op)
            if text is None:
                return None
        elif value_is_number(key):
            number = value_unpack_number(key)
            text = (
                str(int(number))
                if math.isfinite(number) and number == int(number)
                else str(number)
            )
        else:
            text = str(self._value64_host_value(key))
        interned = self._value64_interned_string(text, ip)
        if interned is None:
            return None
        return value_payload(interned)

    def _value64_new_builtin_object(
        self, builtin: int, ip: int, fields: Optional[dict[str, int]] = None
    ) -> Optional[int]:
        values = tuple((fields or {}).values())
        handle = self._value64_alloc_object(ip, values)
        if handle is None:
            return None
        slot = value_payload(handle)
        self._value_object_builtins[slot] = builtin
        obj = self._value_objects[slot]
        for name, value in (fields or {}).items():
            key = self._value64_interned_string(name, ip)
            if key is None:
                return None
            if len(obj) >= OBJECT_SLOTS:
                self._value64_fault(
                    f"builtin object slots exceed {OBJECT_SLOTS} at IP {ip}"
                )
                return None
            obj[value_payload(key)] = value
        return handle

    def _value64_native(
        self, native_id: int, args: List[int], ip: int
    ) -> Optional[int]:
        undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)

        def number(index: int, default: float = 0.0) -> float:
            if index >= len(args):
                return default
            return value_unpack_number(args[index])

        try:
            if native_id == 0:
                # Diagnostic ring: keep last N. console.log must never abort
                # the program (JS does not). Heap/rAF/timer caps stay loud.
                self.console_log.append(
                    tuple(self._value64_host_value(value) for value in args)
                )
                if len(self.console_log) > CONSOLE_LOG_DEPTH:
                    del self.console_log[0]
            elif native_id == 1:
                self.canvas.clear(int(number(0)))
            elif native_id == 2:
                self.canvas.fill_rect(
                    int(number(0)),
                    int(number(1)),
                    int(number(2)),
                    int(number(3)),
                    int(number(4)) if len(args) > 4 else None,
                )
            elif native_id == 3:
                self.canvas.swap()
            elif native_id in (4, 5, 6, 8, 9):
                masks = {4: 4, 5: 8, 6: 16, 8: 1, 9: 2}
                return value_pack_tagged(
                    VALUE_KIND_BOOL,
                    payload=int(bool(self.input.play_bits() & masks[native_id])),
                )
            elif native_id == 7:
                self._value_start_loop = True
            elif native_id in (10, 11, 15):
                value = number(0)
                if native_id == 10:
                    value = math.floor(value) if math.isfinite(value) else value
                elif native_id == 11:
                    value = abs(value)
                else:
                    value = math.sqrt(value) if value >= 0 else math.nan
                return value_pack_number(value)
            elif native_id in (12, 13):
                values = [value_unpack_number(value) for value in args]
                return value_pack_number(
                    (min(values) if native_id == 12 else max(values))
                    if values
                    else (math.inf if native_id == 12 else -math.inf)
                )
            elif native_id == 14:
                self._value_rng = (
                    1664525 * self._value_rng + 1013904223
                ) & 0xFFFFFFFF
                return value_pack_number(self._value_rng / 4294967296.0)
            elif native_id in (16, 17, 18):
                style = self._value64_new_builtin_object(
                    BUILTIN_ELEMENT, ip
                )
                if style is None:
                    return None
                return self._value64_new_builtin_object(
                    BUILTIN_ELEMENT,
                    ip,
                    {
                        "style": style,
                        "width": value_pack_number(640),
                        "height": value_pack_number(480),
                    },
                )
            elif native_id in (19, 20):
                event = args[0] if args else undefined
                function = args[1] if len(args) > 1 else undefined
                if self._value64_string_text(event, ip, Op.CALL_NATIVE) is None:
                    return None
                if self._value64_resolve_function(
                    function, ip, Op.CALL_NATIVE
                ) is None:
                    return None
                pair = (event, function)
                if pair not in self._value_listeners:
                    count = sum(ev == event for ev, _fn in self._value_listeners)
                    if count >= LISTENERS_PER_EVENT:
                        self._value64_fault(
                            f"listener overflow ({LISTENERS_PER_EVENT + 1} > "
                            f"{LISTENERS_PER_EVENT}) at IP {ip}"
                        )
                        return None
                    self._value_listeners.append(pair)
            elif native_id in (21, 22):
                key = self._value64_string_text(
                    args[0] if args else undefined, ip, Op.CALL_NATIVE
                )
                if key is None:
                    return None
                if native_id == 21:
                    stored = self._value_storage.get(key)
                    return (
                        undefined
                        if stored is None
                        else self._value64_interned_string(stored, ip)
                    )
                value = (
                    str(self._value64_host_value(args[1]))
                    if len(args) > 1
                    else "None"
                )
                if key not in self._value_storage and len(
                    self._value_storage
                ) >= LOCAL_STORAGE_SLOTS:
                    self._value64_fault(
                        f"localStorage overflow ({LOCAL_STORAGE_SLOTS + 1} > "
                        f"{LOCAL_STORAGE_SLOTS}) at IP {ip}"
                    )
                    return None
                self._value_storage[key] = value
            elif native_id in (23, 24):
                if native_id == 24:
                    try:
                        host = self._value64_json_host(
                            args[0] if args else undefined, set()
                        )
                    except ValueError as exc:
                        self._value64_fault(f"JSON.stringify at IP {ip}: {exc}")
                        return None
                    return self._value64_interned_string(
                        json.dumps(host, separators=(",", ":")), ip
                    )
                raw = args[0] if args else undefined
                if value_kind(raw) in (VALUE_KIND_UNDEFINED, VALUE_KIND_NULL):
                    return value_pack_tagged(VALUE_KIND_NULL)
                text = self._value64_string_text(raw, ip, Op.CALL_NATIVE)
                if text is None:
                    return None
                try:
                    parsed = json.loads(text)
                except (TypeError, ValueError) as exc:
                    self._value64_fault(f"JSON.parse at IP {ip}: {exc}")
                    return None
                return self._value64_json_value(parsed, ip)
            elif native_id == 25:
                return self._value64_new_builtin_object(BUILTIN_DATE, ip)
            elif native_id == 26:
                empty = self._value64_interned_string("", ip)
                if empty is None:
                    return None
                return self._value64_new_builtin_object(
                    BUILTIN_IMAGE,
                    ip,
                    {
                        "src": empty,
                        "width": value_pack_number(1),
                        "height": value_pack_number(1),
                    },
                )
            elif native_id == 27:
                function = args[0] if args else undefined
                if self._value64_resolve_function(
                    function, ip, Op.CALL_NATIVE
                ) is None:
                    return None
                if len(self._value_raf) >= RAF_QUEUE_DEPTH:
                    self._value64_fault(
                        f"rAF queue overflow ({RAF_QUEUE_DEPTH + 1} > "
                        f"{RAF_QUEUE_DEPTH}) at IP {ip}"
                    )
                    return None
                self._value_raf.append(function)
            elif native_id in (28, 29):
                function = args[0] if args else undefined
                if self._value64_resolve_function(
                    function, ip, Op.CALL_NATIVE
                ) is None:
                    return None
                if len(self._value_timers) >= TIMER_QUEUE_DEPTH:
                    self._value64_fault(
                        f"timer queue overflow ({TIMER_QUEUE_DEPTH + 1} > "
                        f"{TIMER_QUEUE_DEPTH}) at IP {ip}"
                    )
                    return None
                frames = max(1, int(round(number(1) / (1000.0 / 60.0))))
                sequence = self._value_timer_sequence
                self._value_timer_sequence += 1
                self._value_timers.append(
                    _ValueTimer(
                        self._value_frame_no + frames,
                        sequence,
                        frames if native_id == 29 else None,
                        function,
                    )
                )
                return value_pack_number(sequence)
            elif native_id in (30, 31):
                # Web IDL long: ToInt32, not Number-only. clearTimeout(null)
                # / undefined is a no-op. FPGA-SIM already takes the word
                # without requiring a Number tag.
                word = args[0] if args else undefined
                timer_id = value_to_int32(word)
                self._value_timers = [
                    timer
                    for timer in self._value_timers
                    if timer.sequence != timer_id
                ]
            elif native_id == 32:
                key = self._value64_string_text(
                    args[0] if args else undefined, ip, Op.CALL_NATIVE
                )
                if key is None:
                    return None
                self._value_storage.pop(key, None)
            elif native_id == 33:
                pass
            elif native_id == 34:
                if len(args) == 1 and value_is_number(args[0]):
                    length = int(value_unpack_number(args[0]))
                    if length < 0 or length > ARRAY_ELEMENTS:
                        self._value64_fault(
                            f"Array length {length} outside 0..{ARRAY_ELEMENTS} "
                            f"at IP {ip}"
                        )
                        return None
                    return self._value64_alloc_array([undefined] * length, ip)
                return self._value64_alloc_array(args, ip)
            elif native_id == 35:
                return value_pack_number(
                    self._value_frame_no * (1000.0 / 60.0)
                )
            elif native_id in (36, 37):
                event = args[0] if args else undefined
                function = args[1] if len(args) > 1 else undefined
                self._value_listeners = [
                    pair
                    for pair in self._value_listeners
                    if pair != (event, function)
                ]
            elif native_id in (38, 39):
                event_handle = args[0] if args else undefined
                event = self._value64_resolve_object(
                    event_handle, ip, Op.CALL_NATIVE
                )
                if event is None:
                    return None
                type_key = self._value64_interned_string("type", ip)
                if type_key is None:
                    return None
                event_type = event.get(
                    value_payload(type_key),
                    self._value64_interned_string("keydown", ip),
                )
                if event_type is None:
                    return None
                listeners = [
                    function
                    for registered, function in list(self._value_listeners)
                    if registered == event_type
                ]
                saved_roots = self._value_dispatch_roots
                self._value_dispatch_roots = [
                    event_handle,
                    *listeners,
                    *saved_roots,
                ]
                for function in listeners:
                    if self._value64_invoke_function(
                        function, [event_handle]
                    ) is None and self.error:
                        return None
                self._value_dispatch_roots = saved_roots
            elif native_id == 41:
                # Object.keys(o): own keys as interned-string handles, slot
                # order (mirrors the RTL OGETI walk). Non-objects give [].
                value = args[0] if args else undefined
                keys: List[int] = []
                if (value_kind(value) == VALUE_KIND_OBJECT
                        and (value & 0xFFFFFFFF) < MAX_OBJECTS):
                    slots = self._value_objects[value & 0xFFFFFFFF]
                    if slots:
                        keys = [
                            (VALUE_TAG_PREFIX << 48)
                            | (VALUE_KIND_STRING << 44)
                            | (int(k) & 0xFFFF)
                            for k in slots.keys()
                        ]
                handle = self._value64_alloc_array(keys, ip)
                return handle
            elif native_id == 40:
                value = args[0] if args else undefined
                kind = value_kind(value)
                if value_is_number(value):
                    text = "number"
                elif kind == VALUE_KIND_UNDEFINED:
                    text = "undefined"
                elif kind == VALUE_KIND_BOOL:
                    text = "boolean"
                elif kind == VALUE_KIND_STRING:
                    text = "string"
                elif kind == VALUE_KIND_FUNCTION:
                    text = "function"
                else:
                    text = "object"
                return self._value64_interned_string(text, ip)
            else:
                self._value64_fault(
                    f"unsupported native ID {native_id} at IP {ip}"
                )
                return None
        except (TypeError, ValueError, OverflowError) as exc:
            self._value64_fault(f"native ID {native_id} argument error at IP {ip}: {exc}")
            return None
        return undefined

    def _value64_json_host(self, value: int, active: set[tuple[int, int]]):
        if value_is_number(value):
            number = value_unpack_number(value)
            return number if math.isfinite(number) else None
        kind = value_kind(value)
        if kind in (VALUE_KIND_UNDEFINED, VALUE_KIND_NULL):
            return None
        if kind == VALUE_KIND_BOOL:
            return bool(value_payload(value))
        if kind == VALUE_KIND_STRING:
            return self._value64_string_text(value, self._value_last_ip, Op.CALL_NATIVE)
        if kind == VALUE_KIND_ARRAY:
            key = (kind, value_payload(value))
            if key in active:
                raise ValueError("cyclic array")
            array = self._value64_resolve_array(
                value, self._value_last_ip, Op.CALL_NATIVE
            )
            if array is None:
                raise ValueError("invalid array handle")
            active.add(key)
            out = [self._value64_json_host(item, active) for item in array]
            active.remove(key)
            return out
        if kind in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
            key = (kind, value_payload(value))
            if key in active:
                raise ValueError("cyclic object")
            obj = self._value64_resolve_object(
                value, self._value_last_ip, Op.CALL_NATIVE
            )
            if obj is None:
                raise ValueError("invalid object handle")
            active.add(key)
            out = {
                self._value_strings[name]: self._value64_json_host(item, active)
                for name, item in obj.items()
                if name < len(self._value_strings)
            }
            active.remove(key)
            return out
        if kind == VALUE_KIND_RECORD:
            followed = self._value64_record_follow(value)
            if value_kind(followed) in (
                VALUE_KIND_OBJECT,
                VALUE_KIND_ELEMENT,
            ):
                return self._value64_json_host(followed, active)
            _ident, has_x, has_y, x, y = record_unpack(value)
            out = {}
            if has_x:
                out["x"] = x
            if has_y:
                out["y"] = y
            return out
        return None

    def _value64_json_value(
        self, host, ip: int, extra_roots: Optional[Iterable[int]] = None
    ) -> Optional[int]:
        # Sibling/ancestor handles live only in this Python walk until the
        # parent array/object is allocated. GC during a nested alloc must
        # mark them or JSON.parse rows get swept (stale generation).
        held = list(extra_roots) if extra_roots is not None else []
        if host is None:
            return value_pack_tagged(VALUE_KIND_NULL)
        if isinstance(host, bool):
            return value_pack_tagged(VALUE_KIND_BOOL, payload=int(host))
        if isinstance(host, (int, float)):
            return value_pack_number(host)
        if isinstance(host, str):
            return self._value64_interned_string(host, ip)
        if isinstance(host, list):
            items = []
            for item in host:
                value = self._value64_json_value(item, ip, held + items)
                if value is None:
                    return None
                items.append(value)
            return self._value64_alloc_array(items, ip, held)
        if isinstance(host, dict):
            if len(host) > OBJECT_SLOTS:
                self._value64_fault(
                    f"JSON object slots {len(host)} > {OBJECT_SLOTS} at IP {ip}"
                )
                return None
            fields = []
            built: List[int] = []
            for key, item in host.items():
                key_value = self._value64_interned_string(str(key), ip)
                value = self._value64_json_value(item, ip, held + built)
                if key_value is None or value is None:
                    return None
                fields.append((value_payload(key_value), value))
                built.extend((key_value, value))
            handle = self._value64_alloc_object(ip, held + built)
            if handle is None:
                return None
            obj = self._value_objects[value_payload(handle)]
            obj.update(fields)
            return handle
        self._value64_fault(f"unsupported JSON value {type(host).__name__} at IP {ip}")
        return None

    def _value64_named_prop(self, handle: int, name: str, default=None):
        """Read one interned object property as a host value (fillStyle, etc.)."""
        try:
            index = self._value_strings.index(name)
        except ValueError:
            return default
        obj = self._value_objects[value_payload(handle)]
        if obj is None:
            return default
        word = obj.get(index)
        if word is None:
            return default
        return self._value64_host_value(word)

    def _value64_canvas_host_arg(self, word: int):
        """Image / ImageData handles become the dicts Machine canvas natives expect."""
        kind = value_kind(word)
        if kind not in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
            return self._value64_host_value(word)
        slot = value_payload(word)
        host = dict(self._value_native_host[slot]) if 0 <= slot < MAX_OBJECTS else {}
        obj = self._value_objects[slot] if 0 <= slot < MAX_OBJECTS else None
        if obj is not None:
            for key, value in obj.items():
                if key < len(self._value_strings):
                    host[self._value_strings[key]] = self._value64_host_value(value)
        return host

    def _value64_bind_image_src(self, handle: int, src: str, ip: int) -> None:
        """Chunk Image.src: PNG size + jmr:spr:N → width/height/_spr (ASET blit)."""
        slot = value_payload(handle)
        width, height = _png_size_from_data_uri(src)
        extra = self._value_native_host[slot]
        extra.pop("_spr", None)
        extra.pop("_pix", None)
        if src.startswith("jmr:spr:"):
            try:
                sprite_index = int(src.split(":")[-1])
            except ValueError:
                sprite_index = -1
            pack = self._m._sprites or self._m._spr_descs
            if 0 <= sprite_index < len(pack):
                packed = pack[sprite_index]
                width, height = int(packed[0]), int(packed[1])
                extra["_spr"] = sprite_index
                if len(packed) > 2 and isinstance(packed[2], (bytes, bytearray)):
                    extra["_pix"] = packed[2]
        if "_spr" not in extra and "_pix" not in extra:
            # Loaded Image with no ASET sheet still has a drawable 1×1 (onload tests).
            extra["_pix"] = bytes([1])
            width, height = 1, 1
        obj = self._value_objects[slot]
        if obj is None:
            return
        for name, number in (("width", width), ("height", height)):
            interned = self._value64_interned_string(name, ip)
            if interned is None:
                return
            obj[value_payload(interned)] = value_pack_number(number)

    def _value64_canvas_or_dom_method(
        self, receiver: int, method: str, args: List[int], ip: int
    ) -> Optional[int]:
        """Canvas/DOM methods on element/context objects. None = not this surface."""
        undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
        builtin = None
        slot = value_payload(receiver)
        if value_kind(receiver) in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
            if 0 <= slot < MAX_OBJECTS:
                builtin = self._value_object_builtins[slot]
        canvas_ops = {
            "fillRect",
            "clearRect",
            "drawImage",
            "setTransform",
            "beginPath",
            "moveTo",
            "lineTo",
            "arc",
            "stroke",
            "fill",
            "quadraticCurveTo",
            "fillText",
            "measureText",
            "getImageData",
            "putImageData",
            "save",
            "restore",
            "translate",
            "rotate",
            "strokeRect",
        }
        if method == "getContext":
            handle = self._value64_new_builtin_object(BUILTIN_CONTEXT, ip)
            if handle is None:
                return None
            ctx_slot = value_payload(handle)
            self._value_canvas_aux[ctx_slot] = {
                "_path": [],
                "_tx": 0.0,
                "_ty": 0.0,
                "_sx": 1.0,
                "_sy": 1.0,
                "_saved": None,
            }
            # NEW: ctx.imageSmoothingEnabled default true; indexed blit is nearest
            smooth_name = self._value64_interned_string("imageSmoothingEnabled", ip)
            obj = self._value_objects[ctx_slot]
            if smooth_name is not None and obj is not None:
                obj[value_payload(smooth_name)] = value_pack_number(1)
            return handle
        if builtin == BUILTIN_DATE or method in (
            "toISOString",
            "getTime",
            "now",
        ):
            ms = self._value_frame_no * (1000.0 / 60.0)
            if method == "getTime" or method == "now":
                return value_pack_number(ms)
            if method == "toISOString":
                import datetime

                text = (
                    datetime.datetime.fromtimestamp(
                        ms / 1000.0, tz=datetime.timezone.utc
                    ).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
                    + "Z"
                )
                return self._value64_interned_string(text, ip)
        if method == "click":
            event = self._value64_new_builtin_object(BUILTIN_ELEMENT, ip)
            if event is None:
                return None
            type_name = self._value64_interned_string("type", ip)
            click = self._value64_interned_string("click", ip)
            if type_name is None or click is None:
                return None
            obj = self._value64_resolve_object(event, ip, Op.MAKE_OBJ)
            if obj is None:
                return None
            obj[value_payload(type_name)] = click
            result = self._value64_native(38, [event], ip)
            return undefined if result is None and not self.error else result
        if method in ("addEventListener", "removeEventListener"):
            native_id = 19 if method == "addEventListener" else 36
            result = self._value64_native(native_id, args, ip)
            return undefined if result is None and not self.error else result
        if method == "dispatchEvent":
            result = self._value64_native(38, args, ip)
            return undefined if result is None and not self.error else result
        if method in canvas_ops or builtin == BUILTIN_CONTEXT:
            # Port of Chunk VM Canvas2D: styles live on the context object,
            # path/transform in aux, natives are ctx.* (not bare fillRect names).
            aux = self._value_canvas_aux[slot] if 0 <= slot < MAX_OBJECTS else {}
            if not aux:
                aux = {
                    "_path": [],
                    "_tx": 0.0,
                    "_ty": 0.0,
                    "_sx": 1.0,
                    "_sy": 1.0,
                    "_saved": None,
                }
                if 0 <= slot < MAX_OBJECTS:
                    self._value_canvas_aux[slot] = aux
            host_args = [self._value64_canvas_host_arg(value) for value in args]
            xfn = self._m._natives().get("__ctx_xform")
            if xfn:
                xfn(
                    aux.get("_tx", 0),
                    aux.get("_ty", 0),
                    aux.get("_sx", 1) or 1,
                    aux.get("_sy", 1) or 1,
                )
            if method == "beginPath":
                aux["_path"] = []
                return undefined
            if method == "moveTo" and len(host_args) >= 2:
                aux.setdefault("_path", []).append(
                    f"M,{host_args[0]},{host_args[1]}"
                )
                return undefined
            if method == "lineTo" and len(host_args) >= 2:
                aux.setdefault("_path", []).append(
                    f"L,{host_args[0]},{host_args[1]}"
                )
                return undefined
            if method == "quadraticCurveTo" and len(host_args) >= 4:
                aux.setdefault("_path", []).append(
                    f"Q,{host_args[0]},{host_args[1]},{host_args[2]},{host_args[3]}"
                )
                return undefined
            if method == "arc" and len(host_args) >= 3:
                ccw = 1 if (len(host_args) > 5 and host_args[5]) else 0
                a0 = host_args[3] if len(host_args) > 3 else 0
                a1 = host_args[4] if len(host_args) > 4 else 0
                aux.setdefault("_path", []).append(
                    f"A,{host_args[0]},{host_args[1]},{host_args[2]},{a0},{a1},{ccw}"
                )
                return undefined
            if method == "fill":
                self._m._nat_fill_path(
                    aux.get("_path"),
                    self._value64_named_prop(receiver, "fillStyle")
                    or self._value64_named_prop(receiver, "strokeStyle"),
                )
                return undefined
            if method == "stroke":
                self._m._nat_stroke_path(
                    aux.get("_path"),
                    self._value64_named_prop(receiver, "strokeStyle")
                    or self._value64_named_prop(receiver, "fillStyle"),
                )
                return undefined
            if method == "fillText":
                self._m._nat_fill_text(
                    host_args[0] if host_args else "",
                    host_args[1] if len(host_args) > 1 else 0,
                    host_args[2] if len(host_args) > 2 else 0,
                    self._value64_named_prop(receiver, "fillStyle"),
                    self._value64_named_prop(receiver, "textAlign") or "left",
                    self._value64_named_prop(receiver, "font"),
                )
                return undefined
            if method == "measureText":
                result = self._m._nat_measure_text(
                    host_args[0] if host_args else "",
                    self._value64_named_prop(receiver, "font"),
                )
                converted = self._value64_json_value(result, ip)
                return undefined if converted is None and not self.error else converted
            if method == "strokeRect" and len(host_args) >= 4:
                self._m._nat_stroke_rect(
                    host_args[0],
                    host_args[1],
                    host_args[2],
                    host_args[3],
                    self._value64_named_prop(receiver, "strokeStyle")
                    or self._value64_named_prop(receiver, "fillStyle"),
                )
                return undefined
            if method == "translate" and len(host_args) >= 2:
                aux["_tx"] = (aux.get("_tx") or 0) + (host_args[0] or 0)
                aux["_ty"] = (aux.get("_ty") or 0) + (host_args[1] or 0)
                return undefined
            if method == "setTransform" and len(host_args) >= 6:
                aux["_sx"] = host_args[0] if host_args[0] else 1
                aux["_sy"] = host_args[3] if host_args[3] else 1
                aux["_tx"] = host_args[4] or 0
                aux["_ty"] = host_args[5] or 0
                return undefined
            if method == "save":
                aux["_saved"] = (
                    aux.get("_tx") or 0,
                    aux.get("_ty") or 0,
                    aux.get("_sx") or 1,
                    aux.get("_sy") or 1,
                    self._value64_named_prop(receiver, "globalAlpha", 1),
                )
                return undefined
            if method == "restore":
                saved = aux.get("_saved") or (0, 0, 1, 1, 1)
                aux["_tx"], aux["_ty"] = saved[0], saved[1]
                if len(saved) >= 4:
                    aux["_sx"], aux["_sy"] = saved[2], saved[3]
                if len(saved) >= 5:
                    alpha_name = self._value64_interned_string("globalAlpha", ip)
                    obj = self._value_objects[slot] if 0 <= slot < MAX_OBJECTS else None
                    if alpha_name is not None and obj is not None:
                        obj[value_payload(alpha_name)] = value_pack_number(
                            float(saved[4] or 1)
                        )
                return undefined
            if method == "rotate":
                # Chunk VM no-op; transform stays axis-aligned (setTransform / translate).
                return undefined
            if method == "getImageData":
                result = self._m._nat_get_image_data(
                    *(host_args[:4] + [0, 0, 0, 0])[:4]
                )
                if not isinstance(result, dict):
                    return undefined
                handle = self._value64_json_value(
                    {"width": result.get("width"), "height": result.get("height")},
                    ip,
                )
                if handle is None:
                    return None
                self._value_native_host[value_payload(handle)] = {
                    "_idx": result.get("_idx"),
                    "width": result.get("width"),
                    "height": result.get("height"),
                }
                return handle
            if method == "putImageData" and host_args:
                self._m._nat_put_image_data(*host_args)
                return undefined
            natives = self._m._natives()
            fn = natives.get(f"ctx.{method}") or natives.get(method)
            if fn is None:
                return undefined
            alpha = self._value64_named_prop(receiver, "globalAlpha", 1)
            try:
                alpha_f = 1.0 if alpha is None else float(alpha)
            except (TypeError, ValueError):
                alpha_f = 1.0
            if method == "fillRect" and alpha_f == 0.0:
                return undefined
            try:
                if method == "fillRect" and len(host_args) == 4:
                    fill = self._value64_named_prop(receiver, "fillStyle", 0)
                    if isinstance(fill, str):
                        self._m._nat_fill_style_css(fill)
                    result = fn(*host_args)
                else:
                    result = fn(*host_args)
            except Exception as exc:
                self._value64_fault(f"{method} at IP {ip}: {exc}")
                return None
            if result is None:
                return undefined
            converted = self._value64_json_value(result, ip)
            return undefined if converted is None and not self.error else converted
        if builtin in (
            BUILTIN_ELEMENT,
            BUILTIN_CONTEXT,
            BUILTIN_IMAGE,
            BUILTIN_DATE,
        ):
            return receiver
        return None

    def _value64_call_method(
        self, receiver: int, method: str, args: List[int], ip: int
    ) -> Optional[int]:
        undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
        kind = value_kind(receiver)
        if kind == VALUE_KIND_ARRAY:
            array = self._value64_resolve_array(receiver, ip, Op.CALL_METHOD)
            if array is None:
                return None
            if method == "push":
                if len(array) + len(args) > ARRAY_ELEMENTS:
                    self._value64_fault(
                        f"array length {len(array) + len(args)} > "
                        f"{ARRAY_ELEMENTS} at IP {ip}"
                    )
                    return None
                if len(array) + len(args) > ARRAY_SHORT_CAP:
                    idx = value_payload(receiver)
                    if not self._value64_ensure_long(idx, ip):
                        return None
                array.extend(args)
                return value_pack_number(len(array))
            if method == "pop":
                return array.pop() if array else undefined
            if method == "shift":
                return array.pop(0) if array else undefined
            if method == "unshift":
                if len(array) + len(args) > ARRAY_ELEMENTS:
                    self._value64_fault(
                        f"array length {len(array) + len(args)} > "
                        f"{ARRAY_ELEMENTS} at IP {ip}"
                    )
                    return None
                if len(array) + len(args) > ARRAY_SHORT_CAP:
                    idx = value_payload(receiver)
                    if not self._value64_ensure_long(idx, ip):
                        return None
                array[0:0] = args
                return value_pack_number(len(array))
            if method in ("slice", "splice"):
                start = int(value_unpack_number(args[0])) if args else 0
                if start < 0:
                    start = max(0, len(array) + start)
                if method == "slice":
                    end = (
                        int(value_unpack_number(args[1]))
                        if len(args) > 1
                        else len(array)
                    )
                    return self._value64_alloc_array(array[start:end], ip)
                count = (
                    max(0, int(value_unpack_number(args[1])))
                    if len(args) > 1
                    else len(array) - start
                )
                replacement = args[2:]
                if len(array) - count + len(replacement) > ARRAY_ELEMENTS:
                    self._value64_fault(
                        f"array length exceeds {ARRAY_ELEMENTS} at IP {ip}"
                    )
                    return None
                if len(array) - count + len(replacement) > ARRAY_SHORT_CAP:
                    idx = value_payload(receiver)
                    if not self._value64_ensure_long(idx, ip):
                        return None
                deleted = array[start : start + count]
                array[start : start + count] = replacement
                return self._value64_alloc_array(deleted, ip)
            if method == "indexOf":
                target = args[0] if args else undefined
                try:
                    index = array.index(target)
                except ValueError:
                    index = -1
                return value_pack_number(index)
            if method == "fill":
                fill = args[0] if args else undefined
                for index in range(len(array)):
                    array[index] = fill
                return receiver
            if method in ("forEach", "map", "find", "filter", "findIndex", "reduce"):
                if not args:
                    return undefined
                function = args[0]
                mapped: List[int] = []
                found = undefined
                found_index = value_pack_number(-1)
                acc = args[1] if method == "reduce" and len(args) > 1 else None
                start = 0
                if method == "reduce" and acc is None:
                    if not array:
                        return undefined
                    acc = array[0]
                    start = 1
                saved_roots = self._value_dispatch_roots
                # Same list object as dispatch_roots so compact rewrites mapped.
                held_map = list(saved_roots)
                n_saved = len(held_map)
                self._value_dispatch_roots = held_map
                try:
                    # Re-read live slots each index. A snapshot of handles
                    # goes stale when GC compact turns {x,y} into RECORD.
                    n = len(array)
                    for index in range(n):
                        if index < start:
                            continue
                        if index >= len(array):
                            continue
                        element = array[index]
                        invoke_args = (
                            [acc, element, value_pack_number(index), receiver]
                            if method == "reduce"
                            else [element, value_pack_number(index), receiver]
                        )
                        result = self._value64_invoke_function(
                            function, invoke_args
                        )
                        if result is None:
                            return None
                        if method == "map":
                            held_map.append(result)
                        elif method == "filter":
                            if self._value64_truthy(result) and index < len(
                                array
                            ):
                                held_map.append(array[index])
                        elif method == "find" and self._value64_truthy(result):
                            found = (
                                array[index]
                                if index < len(array)
                                else element
                            )
                            break
                        elif method == "findIndex" and self._value64_truthy(
                            result
                        ):
                            found_index = value_pack_number(index)
                            break
                        elif method == "reduce":
                            acc = result
                    mapped = held_map[n_saved:]
                finally:
                    self._value_dispatch_roots = saved_roots
                if method in ("map", "filter"):
                    return self._value64_alloc_array(mapped, ip)
                if method == "find":
                    return found
                if method == "findIndex":
                    return found_index
                if method == "reduce":
                    return acc
                return undefined
            if method == "join":
                separator = ","
                if args and value_kind(args[0]) not in (
                    VALUE_KIND_UNDEFINED,
                    VALUE_KIND_NULL,
                ):
                    separator = self._value64_js_tostring(args[0])
                text = separator.join(
                    str(self._value64_host_value(value)).removesuffix(".0")
                    for value in array
                )
                return self._value64_interned_string(text, ip)
            if method == "sort":
                if args and value_kind(args[0]) == VALUE_KIND_FUNCTION:
                    comparator = args[0]
                    saved_roots = self._value_dispatch_roots
                    self._value_dispatch_roots = [
                        receiver,
                        comparator,
                        *saved_roots,
                    ]
                    for index in range(1, len(array)):
                        value = array[index]
                        cursor = index
                        while cursor > 0:
                            compared = self._value64_invoke_function(
                                comparator, [array[cursor - 1], value]
                            )
                            if compared is None:
                                return None
                            if value_unpack_number(compared) <= 0:
                                break
                            array[cursor] = array[cursor - 1]
                            cursor -= 1
                        array[cursor] = value
                    self._value_dispatch_roots = saved_roots
                else:
                    array.sort(
                        key=lambda value: (
                            (0, self._value64_host_value(value))
                            if value_is_number(value)
                            else (1, str(self._value64_host_value(value)))
                        )
                    )
                return receiver
        elif kind == VALUE_KIND_STRING:
            text = self._value64_string_text(receiver, ip, Op.CALL_METHOD)
            if text is None:
                return None
            if method == "replace":
                replacement = (
                    self._value64_js_tostring(args[1]) if len(args) > 1 else ""
                )
                if (
                    args
                    and value_kind(args[0]) == VALUE_KIND_OBJECT
                    and self._value_object_builtins[value_payload(args[0])]
                    == BUILTIN_REGEXP
                ):
                    pattern, global_flag, ignore_case = self._value_regex[
                        value_payload(args[0])
                    ]
                    changed = re.sub(
                        pattern,
                        replacement,
                        text,
                        count=0 if global_flag else 1,
                        flags=re.IGNORECASE if ignore_case else 0,
                    )
                    return self._value64_interned_string(changed, ip)
                old = self._value64_js_tostring(args[0]) if args else ""
                return self._value64_interned_string(
                    text.replace(old, replacement, 1), ip
                )
            if method == "split":
                separator = (
                    self._value64_string_text(args[0], ip, Op.CALL_METHOD)
                    if args
                    else None
                )
                parts = [text] if separator is None else list(text) if separator == "" else text.split(separator)
                values = []
                for part in parts:
                    value = self._value64_interned_string(part, ip)
                    if value is None:
                        return None
                    values.append(value)
                return self._value64_alloc_array(values, ip)
            if method in ("substring", "substr", "slice"):
                start = int(value_unpack_number(args[0])) if args else 0
                if method == "substr":
                    end = (
                        start + int(value_unpack_number(args[1]))
                        if len(args) > 1
                        else len(text)
                    )
                else:
                    end = (
                        int(value_unpack_number(args[1]))
                        if len(args) > 1
                        else len(text)
                    )
                    if method == "substring" and start > end:
                        start, end = end, start
                return self._value64_interned_string(text[start:end], ip)
            if method == "charAt":
                index = int(value_unpack_number(args[0])) if args else 0
                return self._value64_interned_string(
                    text[index] if 0 <= index < len(text) else "", ip
                )
            if method in ("trim", "trimStart", "trimEnd", "toLowerCase", "toUpperCase"):
                changed = text
                if method == "trim":
                    changed = text.strip()
                elif method == "trimStart":
                    changed = text.lstrip()
                elif method == "trimEnd":
                    changed = text.rstrip()
                elif method == "toLowerCase":
                    changed = text.lower()
                else:
                    changed = text.upper()
                return self._value64_interned_string(changed, ip)
            if method == "indexOf":
                needle = (
                    self._value64_js_tostring(args[0]) if args else ""
                )
                return value_pack_number(text.find(needle))
        self._value64_fault(
            f"unsupported CALL_METHOD {method} for Value kind {kind} at IP {ip}"
        )
        return None

    def _value64_entry_nparam(self, entry: int) -> int:
        count = 0
        while entry + count < self.n_ops:
            word = self.code_mem[self.ops_base + entry + count]
            if (word & 0xFF) != int(Op.LET_VAR) or not ((word >> 24) & 1):
                break
            count += 1
        return count

    def _value64_bind_argv(self, args: List[int], nparam: int) -> List[int]:
        """JS: extra args dropped, missing params are undefined."""
        undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
        return args[:nparam] + [undefined] * max(0, nparam - len(args))

    def _value64_ensure_function_prototype(
        self, function_handle: int, ip: int, op: Op
    ) -> Optional[int]:
        """JS: every function has a .prototype object, created on first access."""
        function = self._value64_resolve_function(function_handle, ip, op)
        if function is None:
            return None
        index = value_payload(function_handle)
        proto = self._value_function_prototypes[index]
        if value_kind(proto) == VALUE_KIND_OBJECT:
            slot = value_payload(proto)
            if (
                slot < MAX_OBJECTS
                and self._value_objects[slot] is not None
                and value_generation(proto) == self._value_object_generations[slot]
            ):
                return proto
        proto = self._value64_alloc_object(ip, (function_handle,))
        if proto is None:
            return None
        self._value_function_prototypes[index] = proto
        return proto

    def _value64_ctor_function_for_class(
        self, name_index: int, ip: int, op: Op
    ) -> Optional[int]:
        """Look up `new Name` constructor as a first-class function value."""
        names = self.program_image.names if self.program_image else ()
        var_names = self.program_image.var_names if self.program_image else ()
        if name_index >= len(names):
            return None
        name = names[name_index]
        try:
            slot = var_names.index(name)
        except ValueError:
            return None
        handle = self._value64_load_var(slot, ip, op)
        if handle is None or value_kind(handle) != VALUE_KIND_FUNCTION:
            return None
        return handle

    def _value64_invoke_function(
        self, handle: int, args: List[int]
    ) -> Optional[int]:
        self._value_callback_result = None
        function = self._value64_resolve_function(handle, 0, Op.CALL_VAL)
        if function is None:
            return None
        undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
        args = args[: function.nparam] + [undefined] * max(
            0, function.nparam - len(args)
        )
        # Date.now / performance.now are GET_PROP wrappers around native 35.
        if function.entry < 0:
            return self._value64_native(-function.entry, args, 0)
        # Mutable so GC compact can rewrite args before they are LET_VAR'd.
        held = [handle, *args]
        env_handle = self._value64_alloc_env(function.captured_env, 0, held)
        if env_handle is None:
            return None
        handle = held[0]
        args = held[1:]
        frame = _ValueCallFrame(
            return_ip=-1,
            base_sp=len(self._value_stack),
            this_value=self._value_this,
            lexical_env=self._value_env,
            function_handle=handle,
            constructor_value=value_pack_tagged(VALUE_KIND_UNDEFINED),
        )
        self._value_calls.append(frame)
        self._value_env = env_handle
        self._value_this = (
            function.bound_this
            if function.is_arrow or function.has_bound_this
            else value_pack_tagged(VALUE_KIND_UNDEFINED)
        )
        for argument in args:
            if not self._value64_push(argument):
                return None
        self._execute_value64_words(start_ip=function.entry, top_level=False)
        return self._value_callback_result

    def _value64_has_async_work(self) -> bool:
        return bool(
            self._value_start_loop
            or self._value_raf
            or self._value_timers
            or self._value_listeners
        )

    def _execute_value64_words(
        self, max_steps: int = 8_000_000, *, start_ip: int = 0, top_level: bool = True
    ) -> None:
        """Fetch packed opcodes and 64-bit constants from finite code BRAM.

        8M is a runaway fuse (true infinite still trips). One rAF paint of a
        24×26 tile field plus per-pixel sprite palK if-chains is ~2M ops —
        the old 1M cap false-triggered after init queued rAF.
        """
        const_base = 4 if (self.flags & FLAG_ASET) else 3
        ip = start_ip
        steps = 0
        undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
        while self.running:
            if ip < 0:
                return
            if ip >= self.n_ops:
                if not self._value_calls:
                    break
                frame = self._value_calls[-1]
                if len(self._value_stack) != frame.base_sp:
                    self._value64_fault(
                        f"call stack imbalance at implicit return "
                        f"(sp {len(self._value_stack)} != base {frame.base_sp})"
                    )
                    return
                self._value64_leave_call_frame(frame)
                if frame.return_ip < 0:
                    self._value_callback_result = undefined
                    return
                if not self._value64_push(undefined):
                    return
                ip = frame.return_ip
                continue
            if steps >= max_steps:
                self._value64_fault(f"instruction limit {max_steps} exceeded")
                return
            steps += 1
            op_ip = ip
            word = self.code_mem[self.ops_base + ip]
            opcode = word & 0xFF
            arg0 = (word >> 8) & 0xFFFF
            arg1 = (word >> 24) & 0xFF
            ip += 1
            if opcode not in Op._value2member_map_:
                self._value64_fault(f"unknown opcode {opcode} at IP {op_ip}")
                return
            op = Op(opcode)
            self._value_last_ip = op_ip
            self._value_last_op = op

            if op == Op.LOAD_CONST:
                if arg1 in (0, 3):
                    lo = self.code_mem[const_base + 2 * arg0]
                    hi = self.code_mem[const_base + 2 * arg0 + 1]
                    if not self._value64_push((hi << 32) | lo):
                        return
                elif arg1 == 1:
                    if not self._value64_push(
                        value_pack_tagged(VALUE_KIND_STRING, payload=arg0)
                    ):
                        return
                elif arg1 == 2:
                    if not self._value64_push(
                        value_pack_tagged(VALUE_KIND_UNDEFINED)
                    ):
                        return
                elif arg1 == 4:
                    packed = self.code_mem[const_base + 2 * arg0]
                    length = (packed >> 16) & 0xFF
                    pattern = "".join(
                        chr((packed >> (8 * index)) & 0xFF)
                        for index in range(min(length, 2))
                    )
                    handle = self._value64_alloc_object(op_ip)
                    if handle is None:
                        return
                    slot = value_payload(handle)
                    self._value_object_builtins[slot] = BUILTIN_REGEXP
                    self._value_regex[slot] = (
                        pattern,
                        bool((packed >> 24) & 1),
                        bool((packed >> 25) & 1),
                    )
                    if not self._value64_push(handle):
                        return
                else:
                    self._value64_fault(
                        f"unsupported LOAD_CONST tag {arg1} at IP {op_ip}"
                    )
                    return
            elif op == Op.LOAD_VAR:
                value = self._value64_load_var(arg0, op_ip, op, arg1)
                if value is None or not self._value64_push(value):
                    return
            elif op in (Op.STORE_VAR, Op.LET_VAR):
                # Function prologue LET_VAR (a1 bit0): missing arguments are
                # undefined. Chunk VM padded call_fn argv and used
                # `pop() if stack else None`. JS: f(a,b){} f(1) binds b=undefined.
                if (
                    op == Op.LET_VAR
                    and (arg1 & 1)
                    and not self._value_stack
                ):
                    value = value_pack_tagged(VALUE_KIND_UNDEFINED)
                else:
                    value = self._value64_pop(op_ip, op)
                    if value is None:
                        return
                if op == Op.LET_VAR and (arg1 & 1):
                    if not self._value_calls:
                        self._value64_fault(
                            f"call stack underflow at IP {op_ip} (LET_VAR local)"
                        )
                        return
                    # JSB: LET_VAR local (a1 bit0) without an ENV is a global
                    # store — the flat IIFE CALL_VAL contract. With an ENV it
                    # declares in that frame. Same ProgramImage as RTL.
                    if value_kind(self._value_env) == VALUE_KIND_ENV:
                        if not self._value64_declare_local(arg0, value, op_ip):
                            return
                    elif not self._value64_store_var(arg0, value, op_ip, op):
                        return
                elif op == Op.LET_VAR and self._value_var_valid[arg0]:
                    pass
                else:
                    if not self._value64_store_var(arg0, value, op_ip, op, arg1):
                        return
            elif op in (
                Op.ADD,
                Op.SUB,
                Op.MUL,
                Op.DIV,
                Op.MOD,
                Op.BIT_OR,
                Op.BIT_AND,
                Op.LT,
                Op.GT,
                Op.EQ,
            ):
                right = self._value64_pop(op_ip, op)
                if right is None:
                    return
                left = self._value64_pop(op_ip, op)
                if left is None:
                    return
                try:
                    if op == Op.ADD:
                        if value_kind(left) == VALUE_KIND_STRING or value_kind(
                            right
                        ) == VALUE_KIND_STRING:
                            # JS ToString: 1+","+3 → "1,3" not Python "1.0,3.0"
                            # (PACMAN config.goods['1,3'] power pellets).
                            text = self._value64_js_tostring(
                                left
                            ) + self._value64_js_tostring(right)
                            result = self._value64_interned_string(text, op_ip)
                            if result is None:
                                return
                        else:
                            if not value_is_number(left):
                                left = value_pack_number(0)
                            if not value_is_number(right):
                                right = value_pack_number(0)
                            result = value_add(left, right)
                    elif op in (Op.SUB, Op.MUL, Op.DIV, Op.MOD, Op.LT, Op.GT):
                        if not value_is_number(left):
                            left = value_pack_number(0)
                        if not value_is_number(right):
                            right = value_pack_number(0)
                        if op == Op.SUB:
                            result = value_sub(left, right)
                        elif op == Op.MUL:
                            result = value_mul(left, right)
                        elif op == Op.DIV:
                            result = value_div(left, right)
                        elif op == Op.MOD:
                            result = value_mod(left, right)
                        else:
                            a = value_unpack_number(left)
                            b = value_unpack_number(right)
                            ordered = (a < b) if op == Op.LT else (a > b)
                            result = value_pack_tagged(
                                VALUE_KIND_BOOL, payload=int(ordered)
                            )
                    elif op == Op.BIT_OR:
                        result = value_bit_or(left, right)
                    elif op == Op.BIT_AND:
                        result = value_bit_and(left, right)
                    elif op == Op.EQ:
                        if value_is_number(left) and value_is_number(right):
                            a = value_unpack_number(left)
                            b = value_unpack_number(right)
                            equal = not math.isnan(a) and not math.isnan(b) and a == b
                        else:
                            equal = left == right
                        result = value_pack_tagged(
                            VALUE_KIND_BOOL, payload=int(equal)
                        )
                    else:
                        a = value_unpack_number(left)
                        b = value_unpack_number(right)
                        ordered = (a < b) if op == Op.LT else (a > b)
                        result = value_pack_tagged(
                            VALUE_KIND_BOOL, payload=int(ordered)
                        )
                except TypeError:
                    self._value64_fault(
                        f"{op.name} requires Number operands at IP {op_ip}"
                    )
                    return
                if not self._value64_push(result):
                    return
            elif op == Op.NEG:
                value = self._value64_pop(op_ip, op)
                if value is None:
                    return
                try:
                    result = value_pack_number(-value_unpack_number(value))
                except TypeError:
                    self._value64_fault(
                        f"NEG requires a Number operand at IP {op_ip}"
                    )
                    return
                if not self._value64_push(result):
                    return
            elif op == Op.NOT:
                value = self._value64_pop(op_ip, op)
                if value is None:
                    return
                if not self._value64_push(
                    value_pack_tagged(
                        VALUE_KIND_BOOL, payload=int(not self._value64_truthy(value))
                    )
                ):
                    return
            elif op == Op.JUMP:
                ip = arg0
            elif op == Op.JUMP_IF_FALSE:
                condition = self._value64_pop(op_ip, op)
                if condition is None:
                    return
                if not self._value64_truthy(condition):
                    ip = arg0
            elif op == Op.POP:
                if self._value64_pop(op_ip, op) is None:
                    return
            elif op == Op.DUP:
                if not self._value_stack:
                    self._value64_fault(f"eval stack underflow at IP {op_ip} (DUP)")
                    return
                if not self._value64_push(self._value_stack[-1]):
                    return
            elif op == Op.MAKE_ARRAY:
                if arg0 > ARRAY_ELEMENTS:
                    self._value64_fault(
                        f"array length {arg0} > {ARRAY_ELEMENTS} at IP {op_ip}"
                    )
                    return
                if len(self._value_stack) < arg0:
                    self._value64_fault(
                        f"eval stack underflow at IP {op_ip} "
                        f"(MAKE_ARRAY needs {arg0})"
                    )
                    return
                items = self._value_stack[-arg0:] if arg0 else []
                if arg0:
                    del self._value_stack[-arg0:]
                handle = self._value64_alloc_array(items, op_ip)
                if handle is None or not self._value64_push(handle):
                    return
            elif op == Op.ARRAY_GET:
                index_word = self._value64_pop(op_ip, op)
                if index_word is None:
                    return
                handle = self._value64_pop(op_ip, op)
                if handle is None:
                    return
                kind = value_kind(handle)
                undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
                if kind == VALUE_KIND_ARRAY:
                    array = self._value64_resolve_array(handle, op_ip, op)
                    if array is None:
                        return
                    try:
                        index = int(value_unpack_number(index_word))
                    except (TypeError, ValueError, OverflowError):
                        # JS: arr[undefined]/arr[NaN] is undefined, not a halt
                        # (PACMAN `_COS[this.orientation]` when GET_PROP misses).
                        if not self._value64_push(undefined):
                            return
                        continue
                    result = (
                        array[index]
                        if 0 <= index < len(array)
                        else undefined
                    )
                    if not self._value64_push(result):
                        return
                    continue
                if kind == VALUE_KIND_STRING:
                    text = self._value64_string_text(handle, op_ip, op)
                    if text is None:
                        return
                    try:
                        index = int(value_unpack_number(index_word))
                    except (TypeError, ValueError, OverflowError):
                        if not self._value64_push(undefined):
                            return
                        continue
                    ch = text[index] if 0 <= index < len(text) else ""
                    result = self._value64_interned_string(ch, op_ip)
                    if result is None or not self._value64_push(result):
                        return
                    continue
                if kind in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
                    obj = self._value64_resolve_object(handle, op_ip, op)
                    if obj is None:
                        return
                    slot = self._value64_property_slot(index_word, op_ip, op)
                    if slot is None:
                        return
                    if not self._value64_push(obj.get(slot, undefined)):
                        return
                    continue
                # Number/undefined/null[index] → undefined (working Chunk VM).
                if not self._value64_push(undefined):
                    return
            elif op == Op.ARRAY_SET:
                value = self._value64_pop(op_ip, op)
                if value is None:
                    return
                index_word = self._value64_pop(op_ip, op)
                if index_word is None:
                    return
                handle = self._value64_pop(op_ip, op)
                if handle is None:
                    return
                kind = value_kind(handle)
                if kind == VALUE_KIND_ARRAY:
                    array = self._value64_resolve_array(handle, op_ip, op)
                    if array is None:
                        return
                    try:
                        index = int(value_unpack_number(index_word))
                    except (TypeError, ValueError, OverflowError):
                        self._value64_fault(
                            f"ARRAY_SET requires a finite Number index at IP {op_ip}"
                        )
                        return
                    if index < 0 or index >= ARRAY_ELEMENTS:
                        self._value64_fault(
                            f"array index {index} outside 0..{ARRAY_ELEMENTS - 1} "
                            f"at IP {op_ip}"
                        )
                        return
                    if index >= ARRAY_SHORT_CAP:
                        idx = value_payload(handle)
                        if not self._value64_ensure_long(idx, op_ip):
                            return
                    undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
                    if index >= len(array):
                        array.extend([undefined] * (index - len(array) + 1))
                    array[index] = value
                    if not self._value64_push(value):
                        return
                    continue
                if kind in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
                    obj = self._value64_resolve_object(handle, op_ip, op)
                    if obj is None:
                        return
                    slot = self._value64_property_slot(index_word, op_ip, op)
                    if slot is None:
                        return
                    if slot not in obj and len(obj) >= OBJECT_SLOTS:
                        self._value64_fault(
                            f"object slots {len(obj) + 1} > {OBJECT_SLOTS} "
                            f"at IP {op_ip}"
                        )
                        return
                    obj[slot] = value
                    if not self._value64_push(value):
                        return
                    continue
                # Primitive[index]= is a sloppy-mode no-op.
                if not self._value64_push(value):
                    return
            elif op == Op.MAKE_OBJ:
                handle = self._value64_alloc_object(op_ip)
                if handle is None or not self._value64_push(handle):
                    return
            elif op == Op.GET_PROP:
                handle = self._value64_pop(op_ip, op)
                if handle is None:
                    return
                names = self.program_image.names if self.program_image else ()
                property_name = names[arg0] if arg0 < len(names) else ""
                if value_kind(handle) == VALUE_KIND_ARRAY:
                    array = self._value64_resolve_array(handle, op_ip, op)
                    if array is None:
                        return
                    if property_name != "length":
                        if not self._value64_push(
                            value_pack_tagged(VALUE_KIND_UNDEFINED)
                        ):
                            return
                        continue
                    if not self._value64_push(value_pack_number(len(array))):
                        return
                    continue
                if value_kind(handle) == VALUE_KIND_STRING:
                    text = self._value64_string_text(handle, op_ip, op)
                    if text is None:
                        return
                    # Date/performance are interned constructor names; Date.now
                    # compiles as GET_PROP + CALL_VAL, not CALL_METHOD.
                    if text in ("Date", "performance") and property_name == "now":
                        now_fn = self._value64_alloc_function(
                            _ValueFunction(
                                entry=-35,
                                nparam=0,
                                captured_env=self._value_env,
                                is_arrow=False,
                                is_iife=False,
                                bound_this=value_pack_tagged(
                                    VALUE_KIND_UNDEFINED
                                ),
                                has_bound_this=False,
                            ),
                            op_ip,
                        )
                        if now_fn is None or not self._value64_push(now_fn):
                            return
                        continue
                    if property_name != "length":
                        if not self._value64_push(
                            value_pack_tagged(VALUE_KIND_UNDEFINED)
                        ):
                            return
                        continue
                    if not self._value64_push(value_pack_number(len(text))):
                        return
                    continue
                if value_kind(handle) == VALUE_KIND_FUNCTION:
                    # Ctor.prototype.foo = … — functions are not object handles.
                    if property_name == "prototype":
                        proto = self._value64_ensure_function_prototype(
                            handle, op_ip, op
                        )
                        if proto is None or not self._value64_push(proto):
                            return
                        continue
                    if not self._value64_push(
                        value_pack_tagged(VALUE_KIND_UNDEFINED)
                    ):
                        return
                    continue
                if value_kind(handle) == VALUE_KIND_RECORD:
                    followed = self._value64_record_follow(handle)
                    if value_kind(followed) in (
                        VALUE_KIND_OBJECT,
                        VALUE_KIND_ELEMENT,
                    ):
                        handle = followed
                    else:
                        # Compact may rewrite fwd[ident] to a new RECORD;
                        # unpack the followed word, not the stale original.
                        _ident, has_x, has_y, x, y = record_unpack(followed)
                        if property_name == "x" and has_x:
                            result = value_pack_number(x)
                        elif property_name == "y" and has_y:
                            result = value_pack_number(y)
                        else:
                            result = value_pack_tagged(VALUE_KIND_UNDEFINED)
                        if not self._value64_push(result):
                            return
                        continue
                if value_kind(handle) not in (
                    VALUE_KIND_OBJECT,
                    VALUE_KIND_ELEMENT,
                ):
                    if property_name in ("width", "height"):
                        if not self._value64_push(
                            value_pack_number(
                                640 if property_name == "width" else 480
                            )
                        ):
                            return
                        continue
                    if not self._value64_push(
                        value_pack_tagged(VALUE_KIND_UNDEFINED)
                    ):
                        return
                    continue
                obj = self._value64_resolve_object(handle, op_ip, op)
                if obj is None:
                    return
                result = obj.get(
                    arg0, value_pack_tagged(VALUE_KIND_UNDEFINED)
                )
                if (
                    value_kind(result) == VALUE_KIND_UNDEFINED
                    and self._value_object_classes[value_payload(handle)]
                    is not None
                ):
                    class_index = self._value_object_classes[value_payload(handle)]
                    descriptor = next(
                        (
                            item
                            for item in (
                                self.program_image.classes
                                if self.program_image
                                else ()
                            )
                            if item.name_index == class_index
                        ),
                        None,
                    )
                    method_row = (
                        next(
                            (row for row in descriptor.methods if row[0] == arg0),
                            None,
                        )
                        if descriptor is not None
                        else None
                    )
                    if method_row is not None:
                        function = _ValueFunction(
                            entry=method_row[1],
                            nparam=self._value64_entry_nparam(method_row[1]),
                            captured_env=self._value_env,
                            is_arrow=False,
                            is_iife=False,
                            bound_this=handle,
                            has_bound_this=True,
                        )
                        result = self._value64_alloc_function(function, op_ip)
                        if result is None:
                            return
                        if method_row[2]:
                            result = self._value64_invoke_function(result, [])
                            if result is None:
                                return
                        # Prototype methods are not own properties — do not
                        # cache into the instance (OBJECT_SLOTS / identity).
                if not self._value64_push(result):
                    return
            elif op == Op.SET_PROP:
                value = self._value64_pop(op_ip, op)
                if value is None:
                    return
                handle = self._value64_pop(op_ip, op)
                if handle is None:
                    return
                names = self.program_image.names if self.program_image else ()
                property_name = names[arg0] if arg0 < len(names) else ""
                if value_kind(handle) == VALUE_KIND_ARRAY:
                    array = self._value64_resolve_array(handle, op_ip, op)
                    if array is None:
                        return
                    if property_name != "length":
                        if not self._value64_push(value):
                            return
                        continue
                    length = int(value_unpack_number(value))
                    if length < 0 or length > ARRAY_ELEMENTS:
                        self._value64_fault(
                            f"array length {length} outside 0..{ARRAY_ELEMENTS} "
                            f"at IP {op_ip}"
                        )
                        return
                    undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
                    if length > ARRAY_SHORT_CAP:
                        idx = value_payload(handle)
                        if not self._value64_ensure_long(idx, op_ip):
                            return
                    del array[length:]
                    if len(array) < length:
                        array.extend([undefined] * (length - len(array)))
                    if not self._value64_push(value_pack_number(length)):
                        return
                    continue
                kind = value_kind(handle)
                if kind == VALUE_KIND_FUNCTION:
                    # Item.prototype = obj (or first GET_PROP already created it).
                    if property_name == "prototype":
                        self._value_function_prototypes[value_payload(handle)] = (
                            value
                        )
                    if not self._value64_push(value):
                        return
                    continue
                if kind == VALUE_KIND_RECORD:
                    boxed = self._value64_record_box(handle, op_ip)
                    if boxed is None:
                        return
                    handle = boxed
                    kind = value_kind(handle)
                if kind not in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
                    # JS sloppy / working Chunk VM: SET_PROP on a primitive
                    # is a no-op (Date.now = fn when Date is a constructor name).
                    if not self._value64_push(value):
                        return
                    continue
                obj = self._value64_resolve_object(handle, op_ip, op)
                if obj is None:
                    return
                if arg0 not in obj and len(obj) >= OBJECT_SLOTS:
                    self._value64_fault(
                        f"object slots {len(obj) + 1} > {OBJECT_SLOTS} at IP {op_ip}"
                    )
                    return
                obj[arg0] = value
                # Defer Image.onload until the current script finishes so
                # `img.src = ...; img.onload = ...` still fires (data: / ASET).
                slot = value_payload(handle)
                if (
                    property_name == "src"
                    and 0 <= slot < len(self._value_object_builtins)
                    and self._value_object_builtins[slot] == BUILTIN_IMAGE
                ):
                    src_text = self._value64_host_value(value)
                    if isinstance(src_text, str):
                        self._value64_bind_image_src(handle, src_text, op_ip)
                    self._value_pending_image_loads.append(handle)
                if not self._value64_push(value):
                    return
            elif op == Op.CALL_NATIVE:
                if len(self._value_stack) < arg1:
                    self._value64_fault(
                        f"eval stack underflow at IP {op_ip} "
                        f"(CALL_NATIVE argc {arg1})"
                    )
                    return
                args = self._value_stack[-arg1:] if arg1 else []
                if arg1:
                    del self._value_stack[-arg1:]
                result = self._value64_native(arg0, args, op_ip)
                if result is None or not self._value64_push(result):
                    return
            elif op == Op.NEW_OBJ:
                if len(self._value_stack) < arg1:
                    self._value64_fault(
                        f"eval stack underflow at IP {op_ip} (NEW_OBJ argc {arg1})"
                    )
                    return
                args = self._value_stack[-arg1:] if arg1 else []
                if arg1:
                    del self._value_stack[-arg1:]
                descriptor = next(
                    (
                        item
                        for item in (self.program_image.classes if self.program_image else ())
                        if item.name_index == arg0
                    ),
                    None,
                )
                if descriptor is None:
                    self._value64_fault(
                        f"unknown class name index {arg0} at IP {op_ip}"
                    )
                    return
                receiver = self._value64_alloc_object(op_ip, args)
                if receiver is None:
                    return
                self._value_object_classes[value_payload(receiver)] = arg0
                ctor_fn = self._value64_ctor_function_for_class(arg0, op_ip, op)
                if self.error:
                    return
                if ctor_fn is not None:
                    proto = self._value64_ensure_function_prototype(
                        ctor_fn, op_ip, op
                    )
                    if proto is None:
                        return
                    self._value_object_protos[value_payload(receiver)] = proto
                if descriptor.constructor_ip is None and ctor_fn is not None:
                    function = self._value64_resolve_function(
                        ctor_fn, op_ip, op
                    )
                    if function is None:
                        return
                    args = self._value64_bind_argv(args, function.nparam)
                    env_handle = self._value64_alloc_env(
                        function.captured_env, op_ip, (receiver, *args)
                    )
                    if env_handle is None:
                        return
                    self._value_calls.append(
                        _ValueCallFrame(
                            return_ip=ip,
                            base_sp=len(self._value_stack),
                            this_value=self._value_this,
                            lexical_env=self._value_env,
                            function_handle=ctor_fn,
                            constructor_value=receiver,
                        )
                    )
                    self._value_env = env_handle
                    self._value_this = receiver
                    for argument in args:
                        if not self._value64_push(argument):
                            return
                    ip = function.entry
                elif descriptor.constructor_ip is None:
                    # Ctor-less NEW_OBJ (Event / KeyboardEvent / …): copy
                    # string arg0 onto .type and own properties from arg1.
                    obj = self._value_objects[value_payload(receiver)]
                    if args:
                        if value_kind(args[0]) == VALUE_KIND_STRING:
                            type_name = self._value64_interned_string("type", op_ip)
                            if type_name is None:
                                return
                            obj[value_payload(type_name)] = args[0]
                        if len(args) > 1 and value_kind(args[1]) in (
                            VALUE_KIND_OBJECT,
                            VALUE_KIND_ELEMENT,
                        ):
                            source = self._value64_resolve_object(
                                args[1], op_ip, op
                            )
                            if source is None:
                                return
                            for key, value in source.items():
                                if key not in obj and len(obj) >= OBJECT_SLOTS:
                                    self._value64_fault(
                                        f"object slots exceed {OBJECT_SLOTS} "
                                        f"at IP {op_ip}"
                                    )
                                    return
                                obj[key] = value
                    if not self._value64_push(receiver):
                        return
                else:
                    args = self._value64_bind_argv(
                        args,
                        self._value64_entry_nparam(descriptor.constructor_ip),
                    )
                    env_handle = self._value64_alloc_env(
                        self._value_env, op_ip, (receiver, *args)
                    )
                    if env_handle is None:
                        return
                    self._value_calls.append(
                        _ValueCallFrame(
                            return_ip=ip,
                            base_sp=len(self._value_stack),
                            this_value=self._value_this,
                            lexical_env=self._value_env,
                            function_handle=value_pack_tagged(VALUE_KIND_UNDEFINED),
                            constructor_value=receiver,
                        )
                    )
                    self._value_env = env_handle
                    self._value_this = receiver
                    for argument in args:
                        if not self._value64_push(argument):
                            return
                    ip = descriptor.constructor_ip
            elif op == Op.CALL_METHOD:
                if len(self._value_stack) < arg1 + 1:
                    self._value64_fault(
                        f"eval stack underflow at IP {op_ip} "
                        f"(CALL_METHOD argc {arg1})"
                    )
                    return
                args = self._value_stack[-arg1:] if arg1 else []
                if arg1:
                    del self._value_stack[-arg1:]
                receiver = self._value64_pop(op_ip, op)
                if receiver is None:
                    return
                names = self.program_image.names if self.program_image else ()
                method = names[arg0] if arg0 < len(names) else ""
                receiver_kind = value_kind(receiver)
                receiver_text = (
                    self._value64_string_text(receiver, op_ip, op)
                    if receiver_kind == VALUE_KIND_STRING
                    else None
                )
                if receiver_text == "Date" and method == "now":
                    result = self._value64_native(35, args, op_ip)
                    if result is None or not self._value64_push(result):
                        return
                elif method == "assign" and args:
                    # RTL keys the CALL_METH arm on id_assign alone — the
                    # receiver is ignored (the compiler's KeyboardEvent
                    # desugar passes the event object itself). Mirror that.
                    target = self._value64_resolve_object(
                        args[0], op_ip, op
                    )
                    if target is None:
                        return
                    for source_handle in args[1:]:
                        # ES: Object.assign skips null/undefined sources.
                        source_handle = self._value64_record_follow(
                            source_handle
                        )
                        if value_kind(source_handle) == VALUE_KIND_RECORD:
                            _ident, has_x, has_y, x, y = record_unpack(
                                source_handle
                            )
                            fields = []
                            if has_x:
                                fields.append(("x", value_pack_number(x)))
                            if has_y:
                                fields.append(("y", value_pack_number(y)))
                            for name, value in fields:
                                key = self._value64_interned_string(name, op_ip)
                                if key is None:
                                    return
                                ki = value_payload(key)
                                if ki not in target and len(target) >= OBJECT_SLOTS:
                                    self._value64_fault(
                                        f"object slots exceed {OBJECT_SLOTS} at IP {op_ip}"
                                    )
                                    return
                                target[ki] = value
                            continue
                        if value_kind(source_handle) not in (
                            VALUE_KIND_OBJECT,
                            VALUE_KIND_ELEMENT,
                        ):
                            continue
                        source = self._value64_resolve_object(
                            source_handle, op_ip, op
                        )
                        if source is None:
                            return
                        for key, value in source.items():
                            if key not in target and len(target) >= OBJECT_SLOTS:
                                self._value64_fault(
                                    f"object slots exceed {OBJECT_SLOTS} at IP {op_ip}"
                                )
                                return
                            target[key] = value
                    if not self._value64_push(args[0]):
                        return
                elif receiver_kind in (VALUE_KIND_ARRAY, VALUE_KIND_STRING):
                    result = self._value64_call_method(
                        receiver, method, args, op_ip
                    )
                    if result is None or not self._value64_push(result):
                        return
                elif receiver_kind == VALUE_KIND_FUNCTION and method == "bind":
                    function = self._value64_resolve_function(
                        receiver, op_ip, op
                    )
                    if function is None:
                        return
                    bound = _ValueFunction(
                        entry=function.entry,
                        nparam=function.nparam,
                        captured_env=function.captured_env,
                        is_arrow=function.is_arrow,
                        is_iife=function.is_iife,
                        bound_this=(
                            args[0]
                            if args
                            else value_pack_tagged(VALUE_KIND_UNDEFINED)
                        ),
                        has_bound_this=True,
                    )
                    handle = self._value64_alloc_function(bound, op_ip)
                    if handle is None or not self._value64_push(handle):
                        return
                elif receiver_kind in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
                    canvas_result = self._value64_canvas_or_dom_method(
                        receiver, method, args, op_ip
                    )
                    if canvas_result is not None:
                        if not self._value64_push(canvas_result):
                            return
                        continue
                    if self.error:
                        return
                    obj = self._value64_resolve_object(receiver, op_ip, op)
                    if obj is None:
                        return
                    class_index = self._value_object_classes[value_payload(receiver)]
                    descriptor = next(
                        (
                            item
                            for item in (
                                self.program_image.classes
                                if self.program_image
                                else ()
                            )
                            if item.name_index == class_index
                        ),
                        None,
                    )
                    method_row = (
                        next(
                            (row for row in descriptor.methods if row[0] == arg0),
                            None,
                        )
                        if descriptor is not None
                        else None
                    )
                    if method_row is None:
                        found = obj.get(
                            arg0, value_pack_tagged(VALUE_KIND_UNDEFINED)
                        )
                        if value_kind(found) != VALUE_KIND_FUNCTION:
                            proto = self._value_object_protos[
                                value_payload(receiver)
                            ]
                            if value_kind(proto) == VALUE_KIND_OBJECT:
                                proto_index = value_payload(proto)
                                if (
                                    proto_index < MAX_OBJECTS
                                    and self._value_objects[proto_index] is not None
                                    and value_generation(proto)
                                    == self._value_object_generations[proto_index]
                                ):
                                    found = self._value_objects[proto_index].get(
                                        arg0,
                                        value_pack_tagged(VALUE_KIND_UNDEFINED),
                                    )
                        if value_kind(found) == VALUE_KIND_FUNCTION:
                            function = self._value64_resolve_function(
                                found, op_ip, op
                            )
                            if function is None:
                                return
                            args = self._value64_bind_argv(
                                args, function.nparam
                            )
                            env_handle = self._value64_alloc_env(
                                function.captured_env,
                                op_ip,
                                (receiver, *args),
                            )
                            if env_handle is None:
                                return
                            self._value_calls.append(
                                _ValueCallFrame(
                                    return_ip=ip,
                                    base_sp=len(self._value_stack),
                                    this_value=self._value_this,
                                    lexical_env=self._value_env,
                                    function_handle=found,
                                    constructor_value=value_pack_tagged(
                                        VALUE_KIND_UNDEFINED
                                    ),
                                )
                            )
                            self._value_env = env_handle
                            self._value_this = (
                                function.bound_this
                                if function.is_arrow or function.has_bound_this
                                else receiver
                            )
                            for argument in args:
                                if not self._value64_push(argument):
                                    return
                            ip = function.entry
                            continue
                        if not self._value64_push(
                            value_pack_tagged(VALUE_KIND_UNDEFINED)
                        ):
                            return
                        continue
                    args = self._value64_bind_argv(
                        args, self._value64_entry_nparam(method_row[1])
                    )
                    env_handle = self._value64_alloc_env(
                        self._value_env, op_ip, (receiver, *args)
                    )
                    if env_handle is None:
                        return
                    self._value_calls.append(
                        _ValueCallFrame(
                            return_ip=ip,
                            base_sp=len(self._value_stack),
                            this_value=self._value_this,
                            lexical_env=self._value_env,
                            function_handle=value_pack_tagged(VALUE_KIND_UNDEFINED),
                            constructor_value=value_pack_tagged(
                                VALUE_KIND_UNDEFINED
                            ),
                        )
                    )
                    self._value_env = env_handle
                    self._value_this = receiver
                    for argument in args:
                        if not self._value64_push(argument):
                            return
                    ip = method_row[1]
                else:
                    self._value64_fault(
                        f"unsupported CALL_METHOD kind {receiver_kind}.{method} "
                        f"at IP {op_ip}"
                    )
                    return
            elif op == Op.MAKE_FN:
                is_arrow = bool(arg1 & 0x80)
                function = _ValueFunction(
                    entry=arg0,
                    nparam=arg1 & 0x3F,
                    captured_env=self._value_env,
                    is_arrow=is_arrow,
                    is_iife=bool(arg1 & 0x40),
                    bound_this=(
                        self._value_this
                        if is_arrow
                        else value_pack_tagged(VALUE_KIND_UNDEFINED)
                    ),
                    has_bound_this=is_arrow,
                )
                handle = self._value64_alloc_function(function, op_ip)
                if handle is None or not self._value64_push(handle):
                    return
                self._value64_mark_env_escaped()
                # Keep captured_env.parent alive across the rAF caller's RET.
                self._value64_pin_captured_env_chain(function.captured_env)
            elif op == Op.CALL_USER:
                if len(self._value_calls) >= CALL_DEPTH:
                    self._value64_fault(
                        f"call stack overflow ({len(self._value_calls) + 1} > {CALL_DEPTH})"
                    )
                    return
                if len(self._value_stack) < arg1:
                    self._value64_fault(
                        f"eval stack underflow at IP {op_ip} (CALL_USER argc {arg1})"
                    )
                    return
                nparam = self._value64_entry_nparam(arg0)
                argc = int(arg1)
                while argc > nparam:
                    if self._value64_pop(op_ip, op) is None:
                        return
                    argc -= 1
                undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
                while argc < nparam:
                    if not self._value64_push(undefined):
                        return
                    argc += 1
                env_handle = self._value64_alloc_env(self._value_env, op_ip)
                if env_handle is None:
                    return
                self._value_calls.append(
                    _ValueCallFrame(
                        return_ip=ip,
                        base_sp=len(self._value_stack) - nparam,
                        this_value=self._value_this,
                        lexical_env=self._value_env,
                        function_handle=value_pack_tagged(VALUE_KIND_UNDEFINED),
                        constructor_value=value_pack_tagged(VALUE_KIND_UNDEFINED),
                    )
                )
                self._value_env = env_handle
                self._value_this = value_pack_tagged(VALUE_KIND_UNDEFINED)
                ip = arg0
            elif op == Op.CALL_VAL:
                argc = arg0
                if len(self._value_calls) >= CALL_DEPTH:
                    self._value64_fault(
                        f"call stack overflow ({len(self._value_calls) + 1} > {CALL_DEPTH})"
                    )
                    return
                if len(self._value_stack) < argc + 1:
                    self._value64_fault(
                        f"eval stack underflow at IP {op_ip} (CALL_VAL argc {argc})"
                    )
                    return
                function_index = len(self._value_stack) - argc - 1
                function_handle = self._value_stack[function_index]
                function = self._value64_resolve_function(
                    function_handle, op_ip, op
                )
                if function is None:
                    return
                args = self._value_stack[function_index + 1 :]
                undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)
                args = args[: function.nparam] + [undefined] * max(
                    0, function.nparam - len(args)
                )
                # Date.now / performance.now: native 35, no bytecode body.
                if function.entry < 0:
                    del self._value_stack[function_index:]
                    result = self._value64_native(
                        -function.entry, args, op_ip
                    )
                    if result is None or not self._value64_push(result):
                        return
                    continue
                # JSB MAKE_FN a1 bit6: top-level IIFE is a flat CALL_VAL (no
                # ENV). Module lets are globals; class methods LOAD_VAR them.
                # Nested IIFE whose captured word is already an ENV still
                # gets a per-call environment. Same ProgramImage as RTL.
                if function.is_iife and value_kind(function.captured_env) != VALUE_KIND_ENV:
                    env_handle = function.captured_env
                else:
                    env_handle = self._value64_alloc_env(
                        function.captured_env,
                        op_ip,
                        (function_handle, *args),
                    )
                    if env_handle is None:
                        return
                del self._value_stack[function_index:]
                frame = _ValueCallFrame(
                    return_ip=ip,
                    base_sp=len(self._value_stack),
                    this_value=self._value_this,
                    lexical_env=self._value_env,
                    function_handle=function_handle,
                    constructor_value=value_pack_tagged(VALUE_KIND_UNDEFINED),
                )
                self._value_calls.append(frame)
                self._value_env = env_handle
                self._value_this = (
                    function.bound_this
                    if function.is_arrow or function.has_bound_this
                    else value_pack_tagged(VALUE_KIND_UNDEFINED)
                )
                for argument in args:
                    if not self._value64_push(argument):
                        return
                ip = function.entry
            elif op == Op.RET_VAL:
                result = self._value64_pop(op_ip, op)
                if result is None:
                    return
                if not self._value_calls:
                    self._value64_fault(
                        f"call stack underflow at IP {op_ip} (RET_VAL)"
                    )
                    return
                frame = self._value_calls[-1]
                if len(self._value_stack) != frame.base_sp:
                    self._value64_fault(
                        f"call stack imbalance at IP {op_ip} "
                        f"(sp {len(self._value_stack)} != base {frame.base_sp})"
                    )
                    return
                self._value64_leave_call_frame(frame)
                return_value = (
                    frame.constructor_value
                    if value_kind(frame.constructor_value) == VALUE_KIND_OBJECT
                    else result
                )
                if frame.return_ip < 0:
                    self._value_callback_result = return_value
                    return
                if not self._value64_push(return_value):
                    return
                ip = frame.return_ip
            elif op == Op.RETURN:
                if self._value_calls:
                    self._value64_fault(
                        f"call stack imbalance at IP {op_ip} (RETURN in call)"
                    )
                    return
                if self._value_stack:
                    self._value64_fault(
                        f"eval stack imbalance at IP {op_ip} "
                        f"(sp {len(self._value_stack)} != 0)"
                    )
                    return
                self._value64_flush_image_loads()
                if self.error:
                    return
                self._value64_collect()
                self.running = self._value64_has_async_work()
                self._m.running = self.running
                return
            else:
                self._value64_fault(
                    f"unsupported opcode {op.name} ({opcode}) at IP {op_ip}"
                )
                return

        if self.running and self._value_calls:
            self._value64_fault(
                f"call stack imbalance at program end ({len(self._value_calls)} frames)"
            )
            return
        self._value64_flush_image_loads()
        if self.error:
            return
        self._value64_collect()
        self.running = self._value64_has_async_work()
        self._m.running = self.running

    def load_path(self, path: Path) -> None:
        self.load_blob(Path(path).read_bytes())

    def set_key_bits(self, bits: int) -> None:
        self._m.set_key_bits(bits)

    def frame_tick(self) -> None:
        if not self.running:
            return
        if self._value64_active:
            self._value64_frame_tick()
            return
        self._execute_checked(self._m.frame_tick)

    def _value64_make_key_event(
        self, event_type: str, key_code: int, key: str
    ) -> Optional[int]:
        handle = self._value64_alloc_object(self._value_last_ip)
        if handle is None:
            return None
        obj = self._value64_resolve_object(handle, self._value_last_ip, Op.MAKE_OBJ)
        if obj is None:
            return None
        names = self.program_image.names if self.program_image else ()
        undefined = value_pack_tagged(VALUE_KIND_UNDEFINED)

        def optional_string(text: str) -> int:
            interned = self._value64_interned_string(text, self._value_last_ip)
            return interned if interned is not None else undefined

        fields = {
            "type": optional_string(event_type),
            "key": optional_string(key),
            "keyCode": value_pack_number(key_code),
            "which": value_pack_number(key_code),
            "code": optional_string(key),
        }
        for name, value in fields.items():
            if name in names:
                obj[names.index(name)] = value
        return handle

    def _value64_flush_image_loads(self) -> None:
        """Run Image.onload after the current script so src-then-onload works."""
        pending = self._value_pending_image_loads
        self._value_pending_image_loads = []
        if not pending or self.program_image is None:
            return
        names = self.program_image.names
        if "onload" not in names:
            return
        onload_index = names.index("onload")
        for handle in pending:
            obj = self._value_objects[value_payload(handle)]
            if obj is None:
                continue
            onload = obj.get(onload_index)
            if onload is None or value_kind(onload) != VALUE_KIND_FUNCTION:
                continue
            if self._value64_invoke_function(onload, []) is None and self.error:
                return

    def _value64_frame_tick(self) -> None:
        """One deterministic input → rAF snapshot → due-timer frame."""
        self._value64_flush_image_loads()
        if self.error:
            return
        self.input._sync_play_bits_to_keys()
        for event_type, key_code, key in self.input.drain_key_events():
            event_word = self._value64_interned_string(
                event_type, self._value_last_ip
            )
            if event_word is None:
                return
            event_handle = self._value64_make_key_event(
                event_type, key_code, key
            )
            if event_handle is None:
                return
            listeners = [
                function
                for event, function in list(self._value_listeners)
                if event == event_word
            ]
            self._value_dispatch_roots = [event_handle, *listeners]
            for function in listeners:
                self._value64_invoke_function(function, [event_handle])
                if self.error:
                    return
            self._value_dispatch_roots = []

        if self._value_start_loop:
            self._execute_value64_words(top_level=True)
            if self.error:
                return

        self._value_frame_no += 1
        raf = self._value_raf
        self._value_raf = []
        self._value_dispatch_roots = list(raf)
        timestamp = value_pack_number(
            self._value_frame_no * (1000.0 / 60.0)
        )
        for function in raf:
            self._value64_invoke_function(function, [timestamp])
            if self.error:
                return
        self._value_dispatch_roots = []

        due = sorted(
            (
                timer
                for timer in self._value_timers
                if timer.due_frame <= self._value_frame_no
            ),
            key=lambda timer: (timer.due_frame, timer.sequence),
        )
        self._value_dispatch_roots = [
            timer.function_handle for timer in due
        ]
        for timer in due:
            current = next(
                (
                    candidate
                    for candidate in self._value_timers
                    if candidate.sequence == timer.sequence
                ),
                None,
            )
            if current is None:
                continue
            if current.period is None:
                self._value_timers.remove(current)
            else:
                current.due_frame = self._value_frame_no + current.period
            self._value64_invoke_function(current.function_handle, [])
            if self.error:
                return
        self._value_dispatch_roots = []
        # onload after rAF/timers, before present, so src= this frame paints
        # the same BACK the rest of the frame drew (one Canvas bitmap).
        self._value64_flush_image_loads()
        if self.error:
            return
        self._value64_collect()
        self.running = self._value64_has_async_work()
        self._m.running = self.running

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

    def _value64_checkpoint(self) -> dict[str, int | str]:
        """Canonical raw-Value checkpoint; no host-value conversion."""
        vars_bytes = bytearray()
        roots: List[int] = []
        for slot in range(MAX_VARS):
            word = (
                self._value_vars[slot]
                if self._value_var_valid[slot]
                else VALUE_UNINITIALIZED
            )
            vars_bytes += struct.pack("<Q", word & VALUE_MASK)
            if self._value_var_valid[slot]:
                roots.append(word)

        frame_bytes = bytearray(b"F64\x01")
        frame_bytes += struct.pack(
            "<QQH",
            self._value_this & VALUE_MASK,
            self._value_env & VALUE_MASK,
            len(self._value_stack),
        )
        for word in self._value_stack:
            frame_bytes += struct.pack("<Q", word & VALUE_MASK)
        frame_bytes += struct.pack("<H", len(self._value_calls))
        for frame in self._value_calls:
            frame_bytes += struct.pack(
                "<iHQQQQ",
                frame.return_ip,
                frame.base_sp,
                frame.this_value & VALUE_MASK,
                frame.lexical_env & VALUE_MASK,
                frame.function_handle & VALUE_MASK,
                frame.constructor_value & VALUE_MASK,
            )

        queue_bytes = bytearray(b"Q64\x01")
        queue_bytes += struct.pack(
            "<II?H",
            self._value_frame_no,
            self._value_timer_sequence,
            self._value_start_loop,
            len(self._value_raf),
        )
        for handle in self._value_raf:
            queue_bytes += struct.pack("<Q", handle & VALUE_MASK)
        queue_bytes += struct.pack("<H", len(self._value_timers))
        for timer in self._value_timers:
            queue_bytes += struct.pack(
                "<iiqQ",
                timer.due_frame,
                timer.sequence,
                -1 if timer.period is None else timer.period,
                timer.function_handle & VALUE_MASK,
            )
        queue_bytes += struct.pack("<H", len(self._value_listeners))
        for event, function in self._value_listeners:
            queue_bytes += struct.pack(
                "<QQ", event & VALUE_MASK, function & VALUE_MASK
            )

        roots.extend(self._value_stack)
        roots.extend((self._value_this, self._value_env))
        for frame in self._value_calls:
            roots.extend(
                (
                    frame.this_value,
                    frame.lexical_env,
                    frame.function_handle,
                    frame.constructor_value,
                )
            )
        roots.extend(self._value_raf)
        roots.extend(timer.function_handle for timer in self._value_timers)
        for event, function in self._value_listeners:
            roots.extend((event, function))
        roots.extend(self._value_dispatch_roots)
        roots.extend(self._value_pending_image_loads)
        for extra in self._value_native_host:
            for item in extra.values():
                if isinstance(item, int) and not value_is_number(item):
                    kind = value_kind(item)
                    if kind in (
                        VALUE_KIND_OBJECT,
                        VALUE_KIND_ELEMENT,
                        VALUE_KIND_ARRAY,
                        VALUE_KIND_FUNCTION,
                        VALUE_KIND_ENV,
                    ):
                        roots.append(item)

        marked_objects: set[int] = set()
        marked_functions: set[int] = set()
        marked_arrays: set[int] = set()
        marked_envs: set[int] = set()
        marked_strings: set[int] = set()
        pending = list(roots)
        while pending:
            word = pending.pop()
            kind = value_kind(word)
            if kind == VALUE_KIND_STRING:
                index = value_payload(word)
                if index < len(self._value_strings):
                    marked_strings.add(index)
            elif kind in (VALUE_KIND_OBJECT, VALUE_KIND_ELEMENT):
                index = value_payload(word)
                if (
                    index < MAX_OBJECTS
                    and index not in marked_objects
                    and self._value_objects[index] is not None
                    and value_generation(word)
                    == self._value_object_generations[index]
                ):
                    marked_objects.add(index)
                    pending.extend(self._value_objects[index].values())
                    pending.append(self._value_object_protos[index])
            elif kind == VALUE_KIND_FUNCTION:
                index = value_payload(word)
                if (
                    index < MAX_FUNCTIONS
                    and index not in marked_functions
                    and self._value_functions[index] is not None
                    and value_generation(word)
                    == self._value_function_generations[index]
                ):
                    marked_functions.add(index)
                    function = self._value_functions[index]
                    pending.extend((function.captured_env, function.bound_this))
                    pending.append(self._value_function_prototypes[index])
            elif kind == VALUE_KIND_ARRAY:
                index = value_payload(word)
                if (
                    index < MAX_ARRAYS
                    and index not in marked_arrays
                    and self._value_arrays[index] is not None
                    and value_generation(word)
                    == self._value_array_generations[index]
                ):
                    marked_arrays.add(index)
                    pending.extend(self._value_arrays[index])
            elif kind == VALUE_KIND_ENV:
                index = value_payload(word)
                if (
                    index < ENV_DEPTH
                    and index not in marked_envs
                    and self._value_envs[index] is not None
                    and value_generation(word)
                    == self._value_env_generations[index]
                ):
                    marked_envs.add(index)
                    env = self._value_envs[index]
                    pending.append(env.parent)
                    pending.extend(env.slots.values())

        heap_bytes = bytearray(b"H64\x01")
        for index in sorted(marked_strings):
            raw = self._value_strings[index].encode("utf-8")
            heap_bytes += b"S" + struct.pack("<II", index, len(raw)) + raw
        for index in sorted(marked_objects):
            obj = self._value_objects[index]
            heap_bytes += b"O" + struct.pack(
                "<IHIiiH",
                index,
                self._value_object_generations[index],
                len(obj),
                -1
                if self._value_object_classes[index] is None
                else self._value_object_classes[index],
                -1
                if self._value_object_builtins[index] is None
                else self._value_object_builtins[index],
                len(obj),
            )
            for key in sorted(obj):
                heap_bytes += struct.pack(
                    "<IQ", key, obj[key] & VALUE_MASK
                )
            if index in self._value_regex:
                pattern, global_flag, ignore_case = self._value_regex[index]
                raw = pattern.encode("utf-8")
                heap_bytes += b"R" + struct.pack(
                    "<I??", len(raw), global_flag, ignore_case
                ) + raw
        for index in sorted(marked_functions):
            function = self._value_functions[index]
            heap_bytes += b"F" + struct.pack(
                "<IHHQQ???",
                index,
                self._value_function_generations[index],
                function.nparam,
                function.captured_env & VALUE_MASK,
                function.bound_this & VALUE_MASK,
                function.is_arrow,
                function.is_iife,
                function.has_bound_this,
            )
            heap_bytes += struct.pack("<I", function.entry)
        for index in sorted(marked_arrays):
            array = self._value_arrays[index]
            heap_bytes += b"A" + struct.pack(
                "<IHH",
                index,
                self._value_array_generations[index],
                len(array),
            )
            for word in array:
                heap_bytes += struct.pack("<Q", word & VALUE_MASK)
        for index in sorted(marked_envs):
            env = self._value_envs[index]
            heap_bytes += b"E" + struct.pack(
                "<IHQH",
                index,
                self._value_env_generations[index],
                env.parent & VALUE_MASK,
                len(env.slots),
            )
            for slot in sorted(env.slots):
                heap_bytes += struct.pack(
                    "<HQ", slot, env.slots[slot] & VALUE_MASK
                )

        return {
            "ip": self._value_last_ip,
            "op": int(self._value_last_op) if self._value_last_op is not None else 0,
            "sp": len(self._value_stack),
            "csp": len(self._value_calls),
            "vars": self._fnv_bytes(bytes(vars_bytes)),
            "heap": self._fnv_bytes(bytes(heap_bytes)),
            "frames": self._fnv_bytes(bytes(frame_bytes)),
            "queues": self._fnv_bytes(bytes(queue_bytes)),
            "raf": len(self._value_raf),
            "timers": len(self._value_timers),
            "listeners": len(self._value_listeners),
            "canvas": self._fnv_bytes(bytes(self.canvas.front)),
            "error_code": self._error_code,
            "error": self.error or "",
        }

    def checkpoint(self) -> dict[str, int | str]:
        """Canonical safe-point state used by Python/RTL differential tests."""
        if self._value64_active:
            return self._value64_checkpoint()
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
        if self._value64_active:
            op = int(self._value_last_op) if self._value_last_op is not None else 0
            checkpoint_ip = self._value_last_ip
            checkpoint_sp = len(self._value_stack)
            checkpoint_csp = len(self._value_calls)
        else:
            op = int(self._m.vm.last_op) if self._m.vm.last_op is not None else 0
            checkpoint_ip = int(self._m.vm.last_ip)
            checkpoint_sp = len(self._m.vm.stack)
            checkpoint_csp = len(self._m.vm.call_stack)
        frames_hash = self._fnv_bytes(
            canonical(
                (
                    tuple(self._m.vm.stack),
                    tuple(self._m.vm.call_stack),
                    self._m.vm.env,
                ),
                set(),
            )
        )
        queues_hash = self._fnv_bytes(
            canonical(
                (
                    tuple(getattr(self._m, "_raf_q", [])),
                    tuple(tuple(timer) for timer in getattr(self._m, "_timers", [])),
                    tuple(getattr(self._m, "_listeners", [])),
                ),
                set(),
            )
        )
        return {
            "ip": checkpoint_ip,
            "op": op,
            "sp": checkpoint_sp,
            "csp": checkpoint_csp,
            "vars": vars_hash,
            "heap": heap_hash,
            "frames": frames_hash,
            "queues": queues_hash,
            "raf": len(getattr(self._m, "_raf_q", [])),
            "timers": len(getattr(self._m, "_timers", [])),
            "listeners": len(getattr(self._m, "_listeners", [])),
            "canvas": canvas_hash,
            "error_code": ERROR_NONE if not self.error else ERROR_INTERNAL,
            "error": self.error or "",
        }

    @property
    def globals(self):
        if self._value64_active:
            names = self.program_image.var_names if self.program_image else ()
            return {
                names[slot]: self._value64_host_value(self._value_vars[slot])
                for slot in range(min(self.n_vars, len(names)))
                if self._value_var_valid[slot]
            }
        return self._m.vm.globals

    def _value64_host_value(self, word: int):
        """Observer-only conversion; execution always retains the Value word."""
        if value_is_number(word):
            return value_unpack_number(word)
        kind = value_kind(word)
        if kind in (VALUE_KIND_UNDEFINED, VALUE_KIND_NULL):
            return None
        if kind == VALUE_KIND_BOOL:
            return bool(value_payload(word))
        if kind == VALUE_KIND_STRING:
            index = value_payload(word)
            return (
                self._value_strings[index]
                if index < len(self._value_strings)
                else word
            )
        return word


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
