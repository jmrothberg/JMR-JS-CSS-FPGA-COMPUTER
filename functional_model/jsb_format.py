"""JMR-JS binary bytecode (.JSB) — frozen encoding for PYTHON + RTL VM.

Layout (little-endian):
  magic[4] = b'JSB1'
  n_ops:u16  n_consts:u16  n_vars:u16  flags:u16
  consts[n_consts]: each i32
  ops[n_ops]: each u32 = { arg1[31:24], arg0[23:8], op[7:0] }

Native IDs (CALL_NATIVE arg0) — resolved at compile time from name:
  0 console.log  1 clear  2 fillRect  3 swapBuffers
  4 keyLeft  5 keyRight  6 keyFire  7 startLoop
  8 keyUp  9 keyDown
"""

from __future__ import annotations

import os
import struct
from dataclasses import dataclass
from typing import Any, List, Tuple

from functional_model.bytecode import Chunk, Op

MAGIC = b"JSB1"
PROGRAM_IMAGE_VERSION = 1

# Frozen V1 capacities shared with rtl/engines/jmr_js_vm.sv.
PROGRAM_CODE_WORDS = 20480  # 2026-08-21(3): RTL CODE_WORDS
PROGRAM_MAX_CONSTS = 1024
PROGRAM_MAX_VARS = 512
PROGRAM_MAX_NAMES = 1024
PROGRAM_NAME_BYTES = 16384  # mirrors jmr_js_vm.sv NAME_CAP (measured peak 3,644)
PROGRAM_MAX_CLASSES = 16
PROGRAM_MAX_METHODS = 16
PROGRAM_MAX_SPRITES = 16

NATIVE_IDS = {
    "console.log": 0,
    "clear": 1,
    "fillRect": 2,
    "swapBuffers": 3,
    "keyLeft": 4,
    "keyRight": 5,
    "keyFire": 6,
    "startLoop": 7,
    "keyUp": 8,
    "keyDown": 9,
    # NEW (compiler v2): Math natives — ids reserved; RTL grows later
    "Math.floor": 10,
    "Math.abs": 11,
    "Math.min": 12,
    "Math.max": 13,
    "Math.random": 14,
    "Math.sqrt": 15,
    # NEW: DOM/storage stubs (PYTHON bytecode path; RTL ignores / later)
    "document.getElementById": 16,
    "document.querySelector": 17,
    "document.createElement": 18,
    "document.addEventListener": 19,
    "window.addEventListener": 20,
    "localStorage.getItem": 21,
    "localStorage.setItem": 22,
    "JSON.parse": 23,
    "JSON.stringify": 24,
    "Date": 25,
    "Image": 26,
    # NEW JSB v2: HTML titles (rAF / timers / extra DOM). RTL grows later.
    "requestAnimationFrame": 27,
    "setTimeout": 28,
    "setInterval": 29,
    "clearTimeout": 30,
    "clearInterval": 31,
    "localStorage.removeItem": 32,
    "_stub": 33,  # unknown CALL_NATIVE → no-op
    # NEW (full-game builtins): Array(n) ctor; Date.now reserved for RTL
    "Array": 34,
    "Date.now": 35,
    # NEW: listener removal (DONKEY menus) — distinct from add ids 19/20
    "document.removeEventListener": 36,
    "window.removeEventListener": 37,
    # NEW: synthetic events (DONKEY boot script Enter via dispatchEvent)
    "document.dispatchEvent": 38,
    "window.dispatchEvent": 39,
    # NEW: typeof x → interned tag string (PACMAN map hole checks)
    "typeof": 40,
    # NEW: runtime key enumeration (mk.js for-in desugar). PYTHON-first:
    # the RTL nid-41 arm is pending the "worth doing" decision — until
    # then FPGA-SIM faults loud (fault 5) on titles that reach it.
    "Object.keys": 41,
    # sound(ch, freqHz, vol0_15, frames, slideHzPerFrame) — always succeed
    # (no-op until ADAU1761 PHY). Unknown nid is fault 5; do not omit this.
    "sound": 42,
    # --- V1.5 standalone compile ABI (43..48) -------------------------
    # The self-hosted compiler runs as an ordinary program and reaches the
    # outside world only through these. 44/45/46/48 are one RTL state
    # (S_CSRAM) with a mode select; 43/47 are single-beat.
    # Reads return -1 out of range so the tokenizer can probe cheaply;
    # writes fault (code 5) because a stray write corrupts FB/SOURCE/WORK
    # invisibly. artWrite2's bound is the framebuffer wall in silicon.
    "srcLen": 43,
    "srcByte": 44,
    "stgRead": 45,
    "stgWrite": 46,
    "cdone": 47,
    "artWrite2": 48,
    # Source WRITE. Without these an editor can only ever be RTL, never a
    # program: it could read the buffer but never change it.
    "srcWrite": 49,
    "srcSetLen": 50,
    # analog-joy: raw Pmod stick axes (0..255, rest ~128) + 5 discrete
    # buttons (bit0=A bit1=B bit2=C bit3=D bit4=click). Digital joy_in
    # (ids 4-9 above / joy()/getJoy() host natives) is unchanged.
    "joyX": 51,
    "joyY": 52,
    "joyButtons": 53,
    # natives V2: ES Math.round (ties toward +inf). Same shape as Math.floor.
    "Math.round": 54,
    # run 71 language-lite: the cheap V1.5 gaps that forced hand-edits
    "isFinite": 55,
    "isNaN": 56,
    "Math.ceil": 57,
}

# NEW: aliases share an id (decode prefers the canonical NATIVE_IDS key)
NATIVE_ALIASES = {
    "performance.now": "Date.now",   # run 71: frame clock alias
    "console.warn": 0,
    "addEventListener": 19,
    "removeEventListener": 36,
}

# flags bit0 = JSB v2 (name table + class table after ops).
FLAG_V2 = 1
# flags bit1 = ASET asset section present (external SRAM asset bank).
# When set, a u32 aset_byte_off (from file start) follows the 12-byte header
# (consts then start at byte 16 / word 4). Code part = [0, aset_byte_off);
# the loader streams code → code BRAM and the ASET payload → asset SRAM.
FLAG_ASET = 2
# flags bit2 = optional opcode-to-source-line section. It is appended after
# the existing trailer, so RTL that only understands flags[1:0] can ignore it.
FLAG_SOURCE_MAP = 4
# V2 transition flag: numeric constant slots are 64-bit IEEE-754 Values.
# Legacy 32-bit images remain readable until the RTL migration is complete.
FLAG_VALUE64 = 8
KNOWN_FLAGS = FLAG_V2 | FLAG_ASET | FLAG_SOURCE_MAP | FLAG_VALUE64
ASET_MAGIC = b"ASET"
SOURCE_MAP_MAGIC = b"SMAP"
SOURCE_MAP_VERSION = 1
ASET_PAL_BYTES = 768  # 256 × RGB888 at asset-SRAM offset 0
SRAM_BYTES = 4 * 1024 * 1024  # 2M × 16 IS61WV204816 contract (see docs/ARCHITECTURE.md)
# V2.0 MK.HTML would need JMR_SRAM_BYTES=8M / JMR_MAX_SPR=518. NOTE (2026-08-31):
# nothing in tools/ actually sets those today — MK mints under the default 4MB
# config with the wall below ACTIVE (MKBIGCPU is 2,801,304 ASET bytes, 5.4%
# under it). Do not read this comment as "the wall is off for MK".
# Lowest runtime-reserved SRAM address on the standard (4MB) board config —
# framebuffer/work/spr/src/imgd all live contiguously from here to the top
# of the bank. word 1,480,704 * 2 bytes/word, must track FB_SRAM_BASE in
# rtl/engines/jmr_fb_present.sv (and jmr_fb_scanout.sv's copy of the same
# param). Only meaningful for the default 4MB SRAM_BYTES; a JMR_SRAM_BYTES
# override implies a different board/region layout this constant doesn't
# know about, so the mint-time check below is skipped in that case.
_FB_SRAM_BASE_BYTES = 1_480_704 * 2

# --- V1.5 standalone-compile arena (word addresses; mirror of the RTL
# localparams in rtl/engines/jmr_js_vm.sv). Only live while a compiler
# program runs: no title is loaded, so ASET art, SPR and IMGD are all dead.
#
#   CART  art staging, PACKED 2 bytes/word, at its final RUN-time addresses
#         (that packing is what makes MKBIGCPU's 2.8MB fit under FB_SRAM_BASE
#         — one byte per word would blow straight through it)
#   CSCR  compiler scratch (the 40,960-word hole above WORK, plus SPR), 1 B/word
#   CIMG  assembled image (the IMGD snapshot region), 1 B/word
#
# stgRead/stgWrite (nids 45/46) see CSCR and CIMG as ONE flat byte arena:
#   [0, CSCR_WORDS)                      -> CSCR_SRAM_BASE + i
#   [CSCR_WORDS, CSCR_WORDS+CIMG_WORDS)  -> CIMG_SRAM_BASE + i - CSCR_WORDS
CART_SRAM_BASE = 0
CART_WORDS = 1_480_704  # == FB_SRAM_BASE; artWrite2 faults at or past this
CART_MAX_BYTES = _FB_SRAM_BASE_BYTES
CSCR_SRAM_BASE = 1_650_688
CSCR_WORDS = 73_728
CIMG_SRAM_BASE = 1_789_952
CIMG_WORDS = 307_200
CSTG_WORDS = CSCR_WORDS + CIMG_WORDS  # flat arena the compiler addresses
CSTG_MSG_OFF = 0  # 64-byte ASCII diagnostic for a failed compile
CSTG_MSG_MAX = 64
# Handoff header — the only bytes of the arena the console understands. Every
# other byte above CSTG_OUT_OFF + cmp_len is compiler-private.
#   +0 u8  PROGSEL   next program index (read by the console on status 0x80)
#   +1 u8  ART       1 = console pre-loaded NAME.ART into CSTG_ART_OFF
#   +2 u32 ART_LEN   packed art bytes, the mint pump's second range
#   +6 u16 SPAN_N    span-map records ARTSCAN emitted
#   +16 u8 PHASE     1 = stop after tokenizing (test harness; was +1)
CSTG_HDR_OFF = 64
CSTG_HDR_PROGSEL = CSTG_HDR_OFF + 0
CSTG_HDR_ART = CSTG_HDR_OFF + 1
CSTG_HDR_ART_LEN = CSTG_HDR_OFF + 2
CSTG_HDR_SPAN_N = CSTG_HDR_OFF + 6
CSTG_HDR_PHASE = CSTG_HDR_OFF + 16  # tokenize-only; +1 is the ART flag
CSTG_ART_OFF = 8192
CSTG_ART_HDRB = 4096
#   +12 u32 OUT_OFF  where the assembled image starts in the arena
# The image offset is published rather than fixed because the parser's tables
# are sized by the title: PACFAST's token array alone is 188KB, so a constant
# output slot would either collide with the tables or waste the arena on every
# small title. MINTASM writes the image over the token array, which is dead by
# then, and says so here.
CSTG_HDR_OUT_OFF = CSTG_HDR_OFF + 12
CSTG_HDR_BYTES = 64

# Span map — how the residual JS is read as a virtual byte stream over the
# card source, so a 2MB title never has to be materialised anywhere. Written
# by ARTSCAN, walked by the tokenizer. One more span kind (INLINE_TEXT) is
# what substitutes `jmr:spr:N` for a stripped data URI, exactly as the host
# does in tools/compile_js.py before compile_source ever sees the text.
#   +0  u8  KIND     0 = SOURCE (srcOff..+srcLen), 1 = INLINE, 2 = SEMI
#   +1  u8  LEN      INLINE: bytes held in the record itself (max 9)
#   +2  u32 SRC_OFF  SOURCE: absolute source byte offset
#   +6  u32 SRC_LEN  SOURCE: length
#   +10 u16 LINE     first HTML line of this span (CompileError parity)
CSTG_SPAN_OFF = 128
CSTG_SPAN_STRIDE = 12
CSTG_SPAN_MAX = 256
SPAN_KIND_SOURCE = 0
SPAN_KIND_INLINE = 1
SPAN_KIND_SEMI = 2
# Token stream — fixed stride so the four read-only prescans can index it
# freely. Variable-length records would force re-tokenizing, and the compiler
# is a multi-pass design; the source is forward-only, the tokens are not.
#   +0 u8  KIND
#   +1 u8  SUB      OP: which operator. KEYWORD: which keyword.
#   +2 u24 SRC_OFF  where the token text lives in the source
#   +5 u8  SRC_LEN  capped at 255
#
# There is deliberately no LINE field. Carrying one costs 2 bytes on every
# token — 63KB on PACFAST alone — to serve an error path that runs at most
# once per compile. The line number is recovered when a CompileError is
# actually raised, by counting newlines up to SRC_OFF. Rare work stays where
# it belongs. The parser's own tables start immediately after the token
# array (TOK_OFF + tok_n * STRIDE), so nothing is reserved for tokens that
# a small title never uses.
CSTG_TOK_OFF = CSTG_SPAN_OFF + CSTG_SPAN_STRIDE * CSTG_SPAN_MAX
CSTG_TOK_STRIDE = 6
TOK_EOF = 0
TOK_ID = 1
TOK_NUM = 2
TOK_STR = 3
TOK_TMPL = 4
TOK_OP = 5
TOK_REGEX = 6
TOK_KEYWORD = 7
CSTG_HDR_TOK_N = CSTG_HDR_OFF + 8  # u32: tokens the tokenizer produced

# Operator SUB codes. Maximal munch means the longest-first order in the
# tokenizer must match this table's multi-char entries; a wrong order is a
# silent mis-parse, not an error, so both live here as one contract.
OP_TOKENS = (
    "===", "!==", "==", "!=", "<=", ">=", "&&", "||", "++", "--", "=>", "?.",
    "+=", "-=", "*=", "/=", "%=",
    "+", "-", "*", "/", "%", "<", ">", "=", "!", "(", ")", ";", ":", "{", "}",
    ",", ".", "[", "]", "|", "&", "?",
)

# Keyword SUB codes.
KEYWORDS = (
    "var", "let", "const", "function", "return", "if", "else", "while", "for",
    "break", "continue", "new", "typeof", "class", "this", "true", "false",
    "null", "undefined", "switch", "case", "default", "do", "in", "of",
    "try", "catch", "finally", "throw",
)
CSTG_OUT_OFF = CSCR_WORDS  # assembled .JSH starts at the CIMG boundary

# cdone() status: 0 = mint, 0x80 = launch PROGSEL, anything else = error.
CMP_STATUS_DONE = 0x00
CMP_STATUS_NEXT = 0x80
CMP_STATUS_SAVE = 0x81   # write SOURCE back to the loaded name
CMP_STATUS_DELETE = 0x82
CMP_STATUS_LOAD = 0x83
CMP_STATUS_MINT_NAMED = 0x84
CMP_STATUS_MINT_ART = 0x85  # mint, then append the title's .ARTX payload

# PROGSEL ROM. Mirrored as literal rows in the RTL C_JSB_PREP name ROM, so
# the order is a contract — append only, never renumber.
COMPILE_CHAIN = (
    "ARTSCAN.JSH",  # 0 — entry point: spans, sprite table, palette seeds
    "ARTPNG.JSH",  # 1 — inflate + unfilter; histogram or quantize
    "COMPILER.JSH",  # 2 — tokenize / parse / emit the residual JS
    "COMPIL2.JSH",  # 3 — overlay half of the above, if the split is needed
    "MINTASM.JSH",  # 4 — assemble the image and cdone()
)
COMPILE_ENTRY = 0
SRC_SRAM_BASE = 1_724_416
SOURCE_MAX = 65_536


def cstg_word(i: int) -> int:
    """Flat compiler-arena byte index -> absolute SRAM word. -1 if out of range."""
    if i < 0 or i >= CSTG_WORDS:
        return -1
    if i < CSCR_WORDS:
        return CSCR_SRAM_BASE + i
    return CIMG_SRAM_BASE + (i - CSCR_WORDS)


def asset_sram_bytes() -> int:
    v = os.environ.get("JMR_SRAM_BYTES")
    return int(v) if v else SRAM_BYTES


def program_max_sprites() -> int:
    v = os.environ.get("JMR_MAX_SPR")
    return int(v) if v else PROGRAM_MAX_SPRITES
# LOAD_CONST a1: 0=i32  1=string intern  2=None  3=IEEE-754 bits in const pool
# 4=RegExp packed in const pool (pattern bytes + flags — RTL has no char heap)
_LC_I32, _LC_STR, _LC_NONE, _LC_F32, _LC_REGEX = 0, 1, 2, 3, 4
_STR_CAP = 512  # huge data: URIs stubbed — Image.onload still truthy
# Non-data interned literals (layout rows, etc.) keep their full text.
# NAMB length is u16; do not stub those down to 512.


@dataclass(frozen=True)
class ProgramClass:
    name_index: int
    constructor_ip: int | None
    methods: Tuple[Tuple[int, int, bool], ...]


@dataclass(frozen=True)
class _ImageMeta:
    n_ops: int
    n_consts: int
    n_vars: int
    flags: int
    code_end: int
    aset_off: int
    op_lines: Tuple[int, ...] | None
    names: Tuple[str, ...]
    classes: Tuple[ProgramClass, ...]
    var_names: Tuple[str, ...]
    # Words the loader streams into code BRAM beyond its 20,480-word depth.
    # 0 for every well-behaved image. Not fatal — see the note at the
    # CODE_WORDS checks below — but worth surfacing to tools.
    code_bram_overflow: int = 0


class ProgramImage:
    """Validated, versioned in-memory wrapper around the frozen JSB1 bytes."""

    __slots__ = ("_data", "_meta")

    def __init__(self, data: bytes | bytearray | memoryview) -> None:
        self._data = bytes(data)
        self._meta = _validate_program_image(self._data)

    @classmethod
    def from_chunk(
        cls,
        chunk: Chunk,
        v2: bool | None = None,
        sprites=None,
        aset: bool = False,
        value64: bool = True,
    ) -> "ProgramImage":
        return cls(
            encode_chunk(
                chunk,
                v2=v2,
                sprites=sprites,
                aset=aset,
                value64=value64,
            )
        )

    @property
    def version(self) -> int:
        return 2 if self.flags & FLAG_VALUE64 else PROGRAM_IMAGE_VERSION

    @property
    def code_bram_overflow(self) -> int:
        """Words this image streams past code BRAM's 20,480-word depth.

        0 for a well-behaved image. Non-zero means the loader DROPS that many
        words off the end (jmr_js_vm.sv:194-196 guards the write). The tail of
        the image is the NAMB name blob, so every instruction survives and the
        title runs — but its last names are lost, which shows up as a wrong or
        empty string somewhere rather than as a crash. A title to shrink, not
        a title to refuse.
        """
        return self._meta.code_bram_overflow

    @property
    def data(self) -> bytes:
        return self._data

    @property
    def n_ops(self) -> int:
        return self._meta.n_ops

    @property
    def n_consts(self) -> int:
        return self._meta.n_consts

    @property
    def n_vars(self) -> int:
        return self._meta.n_vars

    @property
    def flags(self) -> int:
        return self._meta.flags

    @property
    def code_end(self) -> int:
        """Bytes streamed into code BRAM; excludes the ASET section."""
        return self._meta.code_end

    @property
    def op_lines(self) -> Tuple[int, ...] | None:
        return self._meta.op_lines

    @property
    def var_names(self) -> Tuple[str, ...]:
        """Serialized global-variable slot names in RTL slot order."""
        return self._meta.var_names

    @property
    def names(self) -> Tuple[str, ...]:
        """Validated serialized intern/name table in opcode index order."""
        return self._meta.names

    @property
    def classes(self) -> Tuple[ProgramClass, ...]:
        """Validated class constructor/method/getter descriptors."""
        return self._meta.classes

    def decode(self) -> Chunk:
        """Reconstruct all VM execution input from this validated byte stream."""
        return _decode_chunk_unchecked(self._data, self._meta)

    def __bytes__(self) -> bytes:
        return self._data


def _name_hash(s: str) -> int:
    h = 0
    for b in s.encode("utf-8"):
        h = (h * 31 + b) & 0xFFFF
    return h


def _source_map_section(chunk: Chunk) -> bytes:
    lines = getattr(chunk, "op_lines", None)
    if lines is None:
        return b""
    if len(lines) != len(chunk.code):
        raise ValueError(
            f"source map has {len(lines)} entries for {len(chunk.code)} opcodes"
        )
    runs: list[tuple[int, int]] = []
    for raw_line in lines:
        line = int(raw_line)
        if line < 0 or line > 0xFFFFFFFF:
            raise ValueError(f"source line {line} is outside u32 range")
        if runs and runs[-1][0] == line and runs[-1][1] < 0xFFFF:
            runs[-1] = (line, runs[-1][1] + 1)
        else:
            runs.append((line, 1))
    payload = struct.pack("<HHH", SOURCE_MAP_VERSION, len(lines), len(runs))
    payload += b"".join(struct.pack("<IH", line, count) for line, count in runs)
    return SOURCE_MAP_MAGIC + struct.pack("<I", len(payload)) + payload


def _validate_program_image(data: bytes) -> _ImageMeta:
    """Strictly validate every JSB1 boundary before a VM can see the image."""
    size = len(data)

    def need(off: int, count: int, what: str, limit: int | None = None) -> None:
        end = off + count
        bound = size if limit is None else limit
        if off < 0 or count < 0 or end > bound:
            raise ValueError(f"truncated ProgramImage {what}")

    def u16(off: int, what: str, limit: int | None = None) -> int:
        need(off, 2, what, limit)
        return struct.unpack_from("<H", data, off)[0]

    def u32(off: int, what: str, limit: int | None = None) -> int:
        need(off, 4, what, limit)
        return struct.unpack_from("<I", data, off)[0]

    need(0, 12, "header")
    if data[:4] != MAGIC:
        raise ValueError("bad JSB magic")
    n_ops, n_consts, n_vars, flags = struct.unpack_from("<HHHH", data, 4)
    unknown = flags & ~KNOWN_FLAGS
    if unknown:
        raise ValueError(f"unsupported required ProgramImage flags 0x{unknown:04x}")
    if (flags & FLAG_ASET) and not (flags & FLAG_V2):
        raise ValueError("ASET requires the v2 ProgramImage trailer")
    if n_consts > PROGRAM_MAX_CONSTS:
        raise ValueError(
            f"n_consts {n_consts} > MAX_CONSTS {PROGRAM_MAX_CONSTS}"
        )
    if n_vars > PROGRAM_MAX_VARS:
        raise ValueError(f"n_vars {n_vars} > MAX_VARS {PROGRAM_MAX_VARS}")

    off = 12
    aset_off = 0
    if flags & FLAG_ASET:
        aset_off = u32(off, "ASET offset")
        off += 4
        if aset_off & 3:
            raise ValueError("ASET offset is not word aligned")
        if aset_off < off or aset_off > size:
            raise ValueError("ASET offset is outside ProgramImage")
    code_limit = aset_off if aset_off else size
    const_bytes = 8 if flags & FLAG_VALUE64 else 4
    need(
        off,
        const_bytes * n_consts + 4 * n_ops,
        "constants/opcodes",
        code_limit,
    )
    const_off = off
    ops_off = const_off + const_bytes * n_consts
    off = ops_off + 4 * n_ops

    n_names = 0
    names: list[str] = []
    hash_rows: list[tuple[int, int]] = []
    var_name_idx: list[int] = []
    classes: list[ProgramClass] = []
    sprite_descs: list[tuple[int, int, int]] = []
    if flags & FLAG_V2:
        n_names = u16(off, "name count", code_limit)
        off += 2
        if n_names > PROGRAM_MAX_NAMES:
            raise ValueError(
                f"name count {n_names} > NAME_CAP {PROGRAM_MAX_NAMES}"
            )
        need(off, 3 * n_names, "name hash table", code_limit)
        for _ in range(n_names):
            nh, nl = struct.unpack_from("<HB", data, off)
            hash_rows.append((nh, nl))
            off += 3

        n_vn = u16(off, "variable name map", code_limit)
        off += 2
        if n_vn != n_vars:
            raise ValueError(
                f"variable trailer count {n_vn} does not match header {n_vars}"
            )
        need(off, 2 * n_vn, "variable name map", code_limit)
        for _ in range(n_vn):
            ni = u16(off, "variable name index", code_limit)
            off += 2
            if ni >= n_names:
                raise ValueError(f"variable name index {ni} is out of bounds")
            var_name_idx.append(ni)

        n_cls = u16(off, "class count", code_limit)
        off += 2
        if n_cls > PROGRAM_MAX_CLASSES:
            raise ValueError(
                f"class count {n_cls} > MAX_CLASSES {PROGRAM_MAX_CLASSES}"
            )
        for _ in range(n_cls):
            need(off, 6, "class row", code_limit)
            ni, ctor_ip, n_meth = struct.unpack_from("<HHH", data, off)
            off += 6
            if ni >= n_names:
                raise ValueError(f"class name index {ni} is out of bounds")
            if ctor_ip != 0xFFFF and ctor_ip >= n_ops:
                raise ValueError(f"class constructor IP {ctor_ip} is out of bounds")
            if n_meth > PROGRAM_MAX_METHODS:
                raise ValueError(
                    f"class method count {n_meth} > MAX_METHODS "
                    f"{PROGRAM_MAX_METHODS}"
                )
            need(off, 4 * n_meth, "class methods", code_limit)
            methods: list[tuple[int, int, bool]] = []
            for _m in range(n_meth):
                mi, entry = struct.unpack_from("<HH", data, off)
                off += 4
                if (mi & 0x7FFF) >= n_names:
                    raise ValueError(f"method name index {mi & 0x7FFF} is out of bounds")
                if entry >= n_ops:
                    raise ValueError(f"method entry IP {entry} is out of bounds")
                methods.append((mi & 0x7FFF, int(entry), bool(mi & 0x8000)))
            classes.append(
                ProgramClass(
                    int(ni),
                    None if ctor_ip == 0xFFFF else int(ctor_ip),
                    tuple(methods),
                )
            )

        if off + 4 <= code_limit and data[off : off + 4] == b"SPR1":
            if flags & FLAG_ASET:
                raise ValueError("ASET ProgramImage contains legacy SPR1 pixels")
            off += 4
            n_spr = u16(off, "SPR1 count", code_limit)
            off += 2
            # CONSTITUTION "loud overflow": the legacy SPR pack streams
            # w*h through an 18-bit count - a sprite over 262144 pixels
            # (or a 16-bit-overflowing dimension) must refuse at build
            # time, never silently misdraw. Big art belongs in ASET.
            for _si, (_w, _h, _pix) in enumerate(sprites or []):
                if _w >= 65536 or _h >= 65536:
                    raise ValueError(
                        f"sprite {_si}: {_w}x{_h} exceeds 16-bit dimensions")
                if _w * _h >= 262144:
                    raise ValueError(
                        f"sprite {_si}: {_w}x{_h} = {_w*_h} px exceeds the "
                        f"SPR pack 262144-pixel stream bound (use ASET)")
            if n_spr > program_max_sprites():
                raise ValueError(
                    f"sprite count {n_spr} > MAX_SPRITES {program_max_sprites()}"
                )
            for _ in range(n_spr):
                need(off, 4, "SPR1 descriptor", code_limit)
                sw, sh = struct.unpack_from("<HH", data, off)
                off += 4
                if not sw or not sh:
                    raise ValueError("SPR1 sprite dimensions must be non-zero")
                npi = int(sw) * int(sh)
                need(off, npi, "SPR1 pixels", code_limit)
                off += npi
        elif off + 4 <= code_limit and data[off : off + 4] == b"SPRD":
            if not (flags & FLAG_ASET):
                raise ValueError("SPRD descriptors require an ASET section")
            off += 4
            n_spr = u16(off, "SPRD count", code_limit)
            off += 2
            if n_spr > PROGRAM_MAX_SPRITES:
                raise ValueError(
                    f"sprite count {n_spr} > MAX_SPRITES {PROGRAM_MAX_SPRITES}"
                )
            need(off, 8 * n_spr, "SPRD descriptors", code_limit)
            for _ in range(n_spr):
                sw, sh, soff = struct.unpack_from("<HHI", data, off)
                off += 8
                if not sw or not sh:
                    raise ValueError("SPRD sprite dimensions must be non-zero")
                sprite_descs.append((int(sw), int(sh), int(soff)))
        elif flags & FLAG_ASET:
            raise ValueError("ASET ProgramImage is missing SPRD descriptors")

        if off + 4 <= code_limit and data[off : off + 4] == b"FSTY":
            off += 4
            n_fsty = u16(off, "FSTY count", code_limit)
            off += 2
            if n_fsty > PROGRAM_MAX_NAMES:
                raise ValueError(f"FSTY count {n_fsty} exceeds fill LUT capacity")
            need(off, 4 * n_fsty, "FSTY rows", code_limit)
            for _ in range(n_fsty):
                ni, palette_index = struct.unpack_from("<HH", data, off)
                off += 4
                if ni >= n_names or palette_index > 255:
                    raise ValueError("FSTY row is out of bounds")

        # NAMB was added without changing JSB magic. Accept the old unmarked
        # name stream, but validate either representation to the same bounds.
        if off + 4 <= code_limit and data[off : off + 4] == b"NAMB":
            off += 4
        total_name_bytes = 0
        for i in range(n_names):
            ln = u16(off, "UTF-8 name length", code_limit)
            off += 2
            need(off, ln, "UTF-8 name", code_limit)
            raw = data[off : off + ln]
            off += ln
            try:
                name = raw.decode("utf-8")
            except UnicodeDecodeError as exc:
                raise ValueError(f"invalid UTF-8 in ProgramImage name {i}") from exc
            names.append(name)
            total_name_bytes += ln
        if total_name_bytes > PROGRAM_NAME_BYTES:
            raise ValueError(
                f"name bytes {total_name_bytes} > NAME_BYTES {PROGRAM_NAME_BYTES}"
            )
        for i, name in enumerate(names):
            expected = (_name_hash(name), min(len(name.encode("utf-8")), 255))
            if hash_rows[i] != expected:
                raise ValueError(f"name hash/length mismatch at index {i}")

    op_lines: Tuple[int, ...] | None = None
    if flags & FLAG_SOURCE_MAP:
        need(off, 8, "source-map section", code_limit)
        if data[off : off + 4] != SOURCE_MAP_MAGIC:
            raise ValueError("source-map flag set but SMAP section is missing")
        payload_len = u32(off + 4, "source-map length", code_limit)
        off += 8
        source_end = off + payload_len
        need(off, payload_len, "source-map payload", code_limit)
        need(off, 6, "source-map header", source_end)
        sm_version, sm_n_ops, n_runs = struct.unpack_from("<HHH", data, off)
        off += 6
        if sm_version != SOURCE_MAP_VERSION:
            raise ValueError(f"unsupported source-map version {sm_version}")
        if sm_n_ops != n_ops:
            raise ValueError(
                f"source map has {sm_n_ops} opcodes; header has {n_ops}"
            )
        need(off, 6 * n_runs, "source-map runs", source_end)
        lines: list[int] = []
        for _ in range(n_runs):
            line, count = struct.unpack_from("<IH", data, off)
            off += 6
            if count == 0 or len(lines) + count > n_ops:
                raise ValueError("invalid source-map run length")
            lines.extend([int(line)] * count)
        if off != source_end or len(lines) != n_ops:
            raise ValueError("source-map payload length/count mismatch")
        op_lines = tuple(lines)

    # Validate encoded opcode references only after the v2 name table is known.
    for ip in range(n_ops):
        word = struct.unpack_from("<I", data, ops_off + 4 * ip)[0]
        opc, a0, a1 = word & 0xFF, (word >> 8) & 0xFFFF, (word >> 24) & 0xFF
        if opc not in Op._value2member_map_:
            raise ValueError(f"unknown opcode {opc} at IP {ip}")
        op = Op(opc)
        if op == Op.LOAD_CONST:
            if a1 in (_LC_I32, _LC_F32, _LC_REGEX) and a0 >= n_consts:
                raise ValueError(f"constant index {a0} at IP {ip} is out of bounds")
            if a1 == _LC_STR and a0 >= n_names:
                raise ValueError(f"string name index {a0} at IP {ip} is out of bounds")
            if a1 not in (_LC_I32, _LC_STR, _LC_NONE, _LC_F32, _LC_REGEX):
                raise ValueError(f"unknown LOAD_CONST tag {a1} at IP {ip}")
        elif op in (Op.LOAD_VAR, Op.STORE_VAR, Op.LET_VAR):
            if a0 >= n_vars:
                raise ValueError(f"variable index {a0} at IP {ip} is out of bounds")
        elif op in (Op.JUMP, Op.JUMP_IF_FALSE):
            if a0 > n_ops:
                raise ValueError(f"jump target {a0} at IP {ip} is out of bounds")
        elif op == Op.CALL_NATIVE:
            if a0 not in _id_to_native():
                raise ValueError(f"native ID {a0} at IP {ip} is unknown")
        elif op in (Op.CALL_USER, Op.MAKE_FN):
            if a0 >= n_ops:
                raise ValueError(f"function entry {a0} at IP {ip} is out of bounds")
        elif op in (Op.GET_PROP, Op.SET_PROP, Op.NEW_OBJ, Op.CALL_METHOD):
            if a0 >= n_names:
                raise ValueError(f"name index {a0} at IP {ip} is out of bounds")

    # The EXECUTABLE extent is what silicon refuses: jmr_js_vm.sv:6942 faults
    # code 3 on `ops_base + n_ops > CODE_WORDS`, and nothing else. Enforce
    # exactly that, so the model rejects what the board rejects and no more.
    exec_words = (ops_off + 4 * n_ops) // 4
    if exec_words > PROGRAM_CODE_WORDS:
        raise ValueError(
            f"executable {exec_words} words > CODE_WORDS {PROGRAM_CODE_WORDS}"
        )

    # The whole pre-ASET stream (header + consts + ops + v2 trailer) is what
    # the console pumps into code BRAM, and that BRAM is exactly 20,480 words
    # (jmr_js_vm.sv:163-164, c0[0:16383] + c1[0:4095]). Words past that are
    # DROPPED by the write port, not wrapped — jmr_js_vm.sv:194-196 guards
    # with `else if (code_waddr_q2 < CODE_WORDS)`. Since the trailer's last
    # section is the NAMB name blob, an over-long image loses the tail of its
    # names and keeps every instruction. PACFAST is the live example: 17,604
    # executable words (2,876 to spare) and 20,631 total, and it plays on the
    # board. This used to be a hard refusal here, which meant PYTHON alone
    # could not run a title the silicon runs. Record it; do not refuse it.
    image_words = ((aset_off if flags & FLAG_ASET else size) + 3) // 4
    code_bram_overflow = max(0, image_words - PROGRAM_CODE_WORDS)

    if flags & FLAG_ASET:
        if off > aset_off:
            raise ValueError("ProgramImage trailer overlaps ASET section")
        if any(data[off:aset_off]):
            raise ValueError("non-zero bytes in ProgramImage ASET alignment padding")
        need(aset_off, 8, "ASET header")
        if data[aset_off : aset_off + 4] != ASET_MAGIC:
            raise ValueError("bad ASET magic")
        payload_len = u32(aset_off + 4, "ASET payload length")
        if payload_len > SRAM_BYTES:
            raise ValueError(
                f"ASET payload {payload_len} bytes exceeds asset SRAM {SRAM_BYTES}"
            )
        if payload_len < ASET_PAL_BYTES:
            raise ValueError("ASET payload is missing the 256-entry palette")
        if aset_off + 8 + payload_len != size:
            raise ValueError("ASET payload length does not match ProgramImage size")
        for sw, sh, soff in sprite_descs:
            npi = sw * sh
            if soff < ASET_PAL_BYTES or (soff & 1):
                raise ValueError("ASET sprite offset is invalid or unaligned")
            if soff + npi > payload_len:
                raise ValueError("ASET sprite descriptor exceeds payload")
        code_end = aset_off
    else:
        if off != size:
            raise ValueError("unexpected bytes after ProgramImage trailer")
        code_end = size

    return _ImageMeta(
        n_ops=n_ops,
        n_consts=n_consts,
        n_vars=n_vars,
        flags=flags,
        code_end=code_end,
        aset_off=aset_off,
        op_lines=op_lines,
        names=tuple(names),
        classes=tuple(classes),
        var_names=(
            tuple(names[i] for i in var_name_idx)
            if flags & FLAG_V2
            else tuple(f"v{i}" for i in range(n_vars))
        ),
        code_bram_overflow=code_bram_overflow,
    )


def _native_id(name: str) -> int | None:
    if name in NATIVE_IDS:
        return NATIVE_IDS[name]
    if name in NATIVE_ALIASES:
        return NATIVE_ALIASES[name]
    return None


def _id_to_native() -> dict[int, str]:
    out: dict[int, str] = {}
    for k, v in NATIVE_IDS.items():
        out.setdefault(v, k)
    return out


def _needs_v2(chunk: Chunk) -> bool:
    """v1 is ints + ops 1–18/22. HTML objects/strings/rAF require v2."""
    v2_ops = {
        Op.MAKE_ARRAY, Op.ARRAY_GET, Op.ARRAY_SET, Op.MOD,
        Op.CALL_USER, Op.RET_VAL, Op.MAKE_OBJ, Op.GET_PROP, Op.SET_PROP,
        Op.NEW_OBJ, Op.CALL_METHOD, Op.BIT_OR, Op.BIT_AND, Op.MAKE_FN, Op.CALL_VAL,
    }
    for op, *_a in chunk.code:
        if op in v2_ops:
            return True
    for c in chunk.consts:
        if isinstance(c, str) or c is None or isinstance(c, float):
            return True
        if isinstance(c, dict):
            return True
    return False


def build_aset_payload(palette, sprites):
    """ASET payload = 256×RGB888 palette + 2-byte-aligned sprite banks.

    Returns (payload_bytes, [(w, h, sram_off), ...]). sram_off is the byte
    offset inside the payload == asset-SRAM address after the loader streams
    the payload to SRAM[0]. Deterministic: encode and decode/RUN rebuild the
    exact same offsets from (palette, sprites).
    """
    pal = list(palette or [])
    out = bytearray()
    for i in range(256):
        r, g, b = pal[i] if i < len(pal) else (0, 0, 0)
        out += bytes((int(r) & 0xFF, int(g) & 0xFF, int(b) & 0xFF))
    descs: List[Tuple[int, int, int]] = []
    for w, h, pix in sprites or []:
        if len(out) & 1:
            out += b"\x00"  # 16-bit SRAM port alignment
        descs.append((int(w) & 0xFFFF, int(h) & 0xFFFF, len(out)))
        need = int(w) * int(h)
        out += pix[:need]
        if len(pix) < need:
            out += b"\x00" * (need - len(pix))
    if len(out) > SRAM_BYTES:
        raise ValueError(
            f"ASET payload {len(out)} bytes exceeds the 4 MB asset SRAM bank"
        )
    # 2026-08-28: the 4MB check above is necessary but not sufficient — the
    # asset SRAM bank is SHARED with fixed runtime regions (framebuffer,
    # work RAM, legacy sprite RAM, source RAM, ImageData snapshot), all
    # placed contiguously from FB_SRAM_BASE to the top of the bank (see
    # rtl/jmr_js_core.sv WORK_SRAM_BASE, rtl/engines/jmr_fb_present.sv
    # FB_SRAM_BASE, rtl/engines/jmr_js_vm.sv SPR_SRAM_BASE/IMGD_SRAM_BASE,
    # rtl/engines/jmr_console_engine.sv SRC_SRAM_BASE). Art that reaches
    # FB_SRAM_BASE silently OVERLAPS live runtime data — every present-
    # engine frame copy trampled it, corrupting whichever pixels of the
    # art happened to land past this line (MKPVP/MKCPU/MKBIG/MKBIGCPU all
    # shipped this way; each was fixed by shrinking the art, not raising
    # this number). This check must never be silently bypassed again.
    if asset_sram_bytes() == SRAM_BYTES and len(out) > _FB_SRAM_BASE_BYTES:
        raise ValueError(
            f"ASET payload {len(out)} bytes reaches into runtime-reserved "
            f"SRAM (framebuffer/work/spr/src/imgd start at byte "
            f"{_FB_SRAM_BASE_BYTES}) — art would be corrupted by every "
            f"frame's display copy. Shrink the art (dedupe/repack sprite "
            f"sheets); do not raise this boundary without moving the "
            f"colliding RTL region."
        )
    return bytes(out), descs


# .ARTX sidecar — the ASET payload plus the SPRD rows, so a title's HTML
# does not have to carry base64 PNG. Host mint rebuilds the payload with
# build_aset_payload; off is the same value that lands in the .JSH SPRD row.
ARTX_MAGIC = b"ARTX"
ARTX_VERSION = 1


def build_artx(palette, sprites) -> bytes:
    """Sprite table + the same ASET payload encode_chunk embeds in the .JSH."""
    payload, descs = build_aset_payload(palette, sprites)
    out = bytearray(ARTX_MAGIC)
    out += struct.pack("<HH", ARTX_VERSION, len(descs))
    for w, h, soff in descs:
        out += struct.pack(
            "<HHI", int(w) & 0xFFFF, int(h) & 0xFFFF, int(soff) & 0xFFFFFFFF
        )
    out += struct.pack("<I", len(payload))
    out += payload
    return bytes(out)


def read_artx(data: bytes):
    """Return (palette, sprites, payload) from an .ARTX blob.

    sprites are (w, h, pix) so encode_chunk → build_aset_payload rebuilds
    the identical payload (same alignment rules, same palette bytes).
    """
    if len(data) < 12 or data[:4] != ARTX_MAGIC:
        raise ValueError("bad ARTX magic")
    ver, n = struct.unpack_from("<HH", data, 4)
    if ver != ARTX_VERSION:
        raise ValueError(f"unsupported ARTX version {ver}")
    need = 8 + n * 8 + 4
    if len(data) < need:
        raise ValueError("truncated ARTX header")
    descs = []
    off = 8
    for _ in range(n):
        w, h, soff = struct.unpack_from("<HHI", data, off)
        descs.append((int(w), int(h), int(soff)))
        off += 8
    (plen,) = struct.unpack_from("<I", data, off)
    off += 4
    payload = data[off : off + plen]
    if len(payload) != plen:
        raise ValueError("truncated ARTX payload")
    if plen < ASET_PAL_BYTES:
        raise ValueError("ARTX payload is missing the 256-entry palette")
    palette = [
        (payload[i * 3], payload[i * 3 + 1], payload[i * 3 + 2])
        for i in range(256)
    ]
    sprites = []
    for w, h, soff in descs:
        npi = w * h
        sprites.append((w, h, bytes(payload[soff : soff + npi])))
    return palette, sprites, payload


def encode_chunk(
    chunk: Chunk,
    v2: bool | None = None,
    sprites=None,
    aset: bool = False,
    value64: bool = True,
) -> bytes:
    """Encode a compiled Chunk to .JSB bytes.

    Every image is Value64 (FLAG_VALUE64, v2 trailer) — the HTML product
    encoding. The tagged Q16 encoding is retired with exec32
    (docs/REMOVING_EXEC32.md); requesting it raises so nothing in-tree
    can mint a blob the silicon no longer decodes.

    aset=True (flags bit1): SPRD descriptors in the trailer + ASET section
    (palette + full-res sprite banks) for the external SRAM asset bank —
    the product path for HTML titles (no pixels in code BRAM).
    """
    if not value64:
        raise ValueError(
            "tagged (non-Value64) ProgramImages are retired with exec32; "
            "every image must be FLAG_VALUE64 (docs/REMOVING_EXEC32.md)"
        )
    # Value64 requires the v2 trailer encoding.
    v2 = True
    if v2 or aset:
        return _encode_v2(
            chunk,
            sprites=sprites if sprites is not None else getattr(chunk, "sprites", None),
            aset=aset,
            value64=value64,
        )
    if value64:
        raise ValueError("64-bit Values require the v2 ProgramImage trailer")
    return _encode_v1(chunk)


def _upgrade_numeric_constants_to_value64(blob: bytes) -> bytes:
    """Expand a validated v2 image's constant pool without changing opcodes."""
    n_ops, n_consts, _n_vars, flags = struct.unpack_from("<HHHH", blob, 4)
    header_bytes = 16 if flags & FLAG_ASET else 12
    old_const_off = header_bytes
    old_ops_off = old_const_off + 4 * n_consts
    old_tail_off = old_ops_off + 4 * n_ops

    # A pool slot's LOAD_CONST tag tells whether its old 32-bit bits are an
    # integer, float32, or non-number descriptor. Conflicting uses are invalid.
    slot_types: dict[int, int] = {}
    for ip in range(n_ops):
        word = struct.unpack_from("<I", blob, old_ops_off + 4 * ip)[0]
        if (word & 0xFF) != int(Op.LOAD_CONST):
            continue
        index = (word >> 8) & 0xFFFF
        load_type = (word >> 24) & 0xFF
        if load_type not in (_LC_I32, _LC_F32, _LC_REGEX):
            continue
        previous = slot_types.setdefault(index, load_type)
        if previous != load_type:
            raise ValueError(f"constant slot {index} has conflicting Value types")

    expanded = bytearray()
    for index in range(n_consts):
        raw = struct.unpack_from("<I", blob, old_const_off + 4 * index)[0]
        load_type = slot_types.get(index, _LC_I32)
        if load_type == _LC_F32:
            number = struct.unpack("<f", struct.pack("<I", raw))[0]
            expanded += struct.pack("<d", float(number))
        elif load_type == _LC_I32:
            signed = struct.unpack("<i", struct.pack("<I", raw))[0]
            expanded += struct.pack("<d", float(signed))
        else:
            # Regex descriptors are consumed by the string engine, not ALU.
            expanded += struct.pack("<Q", raw)

    out = bytearray(blob[:old_const_off])
    out += expanded
    out += blob[old_ops_off:old_tail_off]
    out += blob[old_tail_off:]
    flags |= FLAG_VALUE64
    struct.pack_into("<H", out, 10, flags)
    if flags & FLAG_ASET:
        old_aset = struct.unpack_from("<I", blob, 12)[0]
        struct.pack_into("<I", out, 12, old_aset + 4 * n_consts)
    return bytes(out)


def _encode_v1(chunk: Chunk) -> bytes:
    """Encode a compiled Chunk to .JSB bytes (ints only in const pool)."""
    consts: List[int] = []
    const_map: dict[int, int] = {}
    # Map original const indices → packed int indices (strings → 0 placeholder)
    orig_to_pack: List[int] = []
    for c in chunk.consts:
        if isinstance(c, bool):
            v = 1 if c else 0
        elif isinstance(c, (int, float)):
            v = int(c)
        else:
            v = 0  # strings unused by RTL natives except log (ignored)
        if v not in const_map:
            const_map[v] = len(consts)
            consts.append(v)
        orig_to_pack.append(const_map[v])

    # Vars = names that are not natives
    var_names: List[str] = []
    var_index: dict[str, int] = {}
    for n in chunk.names:
        if n in NATIVE_IDS or n in NATIVE_ALIASES:
            continue
        if n not in var_index:
            var_index[n] = len(var_names)
            var_names.append(n)

    ops_out: List[int] = []
    for op, *args in chunk.code:
        opc = int(op) & 0xFF
        a0 = 0
        a1 = 0
        if op == Op.LOAD_CONST:
            a0 = orig_to_pack[args[0]] & 0xFFFF
        elif op in (Op.LOAD_VAR, Op.STORE_VAR, Op.LET_VAR):
            name = chunk.names[args[0]]
            a0 = var_index[name] & 0xFFFF
            if op in (Op.LOAD_VAR, Op.STORE_VAR) and len(args) > 1:
                a1 = int(args[1]) & 0xFF
        elif op in (Op.JUMP, Op.JUMP_IF_FALSE):
            a0 = int(args[0]) & 0xFFFF
        elif op == Op.CALL_NATIVE:
            name = chunk.names[args[0]]
            nid = _native_id(name)
            if nid is None:
                raise ValueError(f"unknown native {name!r}")
            a0 = nid & 0xFFFF
            a1 = int(args[1]) & 0xFF
        elif op == Op.MAKE_ARRAY:
            a0 = int(args[0]) & 0xFFFF
        elif op == Op.MOD:
            pass  # no args
        elif op == Op.CALL_USER:
            # NEW: a0=entry_ip, a1=argc
            a0 = int(args[0]) & 0xFFFF
            a1 = int(args[1]) & 0xFF
        elif op == Op.RET_VAL:
            pass
        elif op == Op.MAKE_OBJ:
            pass
        elif op in (Op.GET_PROP, Op.SET_PROP):
            a0 = int(args[0]) & 0xFFFF  # name index — RTL heap uses slot ids later
        elif op == Op.NEW_OBJ:
            a0 = int(args[0]) & 0xFFFF  # class name index
            a1 = int(args[1]) & 0xFF
        elif op == Op.CALL_METHOD:
            a0 = int(args[0]) & 0xFFFF  # method name index
            a1 = int(args[1]) & 0xFF
        elif op == Op.MAKE_FN:
            a0 = int(args[0]) & 0xFFFF
            # NEW: a1 bit7 = is_arrow (lexical this); bit6 = IIFE (flat call);
            # low 6 bits = nparam
            a1 = int(args[1]) & 0x3F if len(args) > 1 else 0
            if len(args) > 2 and args[2]:
                a1 |= 0x80
            if len(args) > 3 and args[3]:
                a1 |= 0x40
        elif op == Op.CALL_VAL:
            # NEW: a0=argc (was dropped in v1 fall-through)
            a0 = int(args[0]) & 0xFFFF
        elif op in (Op.BIT_OR, Op.BIT_AND):
            pass
        word = (opc) | ((a0 & 0xFFFF) << 8) | ((a1 & 0xFF) << 24)
        ops_out.append(word)

    source_map = _source_map_section(chunk)
    flags = FLAG_SOURCE_MAP if source_map else 0
    hdr = MAGIC + struct.pack(
        "<HHHH", len(ops_out), len(consts), len(var_names), flags
    )
    body = b"".join(struct.pack("<i", c) for c in consts)
    body += b"".join(struct.pack("<I", w) for w in ops_out)
    return hdr + body + source_map


def _intern_name(names: List[str], index: dict[str, int], s: str) -> int:
    if s not in index:
        index[s] = len(names)
        names.append(s)
    return index[s]


def _encode_v2(
    chunk: Chunk, sprites=None, aset: bool = False, value64: bool = False
) -> bytes:
    """JSB v2 with either legacy i32 or frozen binary64 constant slots."""
    names: List[str] = list(chunk.names)
    name_index: dict[str, int] = {n: i for i, n in enumerate(names)}
    fns = chunk.functions or {}

    consts: List[int] = []
    const_map: dict[tuple[str, int] | int, int] = {}
    # per original const: (packed_i32_or_name_idx, a1_tag)
    orig_lc: List[Tuple[int, int]] = []
    for c in chunk.consts:
        if c is None:
            orig_lc.append((0, _LC_NONE))
            continue
        if isinstance(c, dict) and c.get("__class") == "RegExp":
            # Pack pattern bytes + flags into the i32 const pool so RTL
            # String.replace can honor /pat/g without a char heap.
            raw = str(c.get("source") or "")
            pat, fl = raw, ""
            if raw.startswith("/"):
                end = raw.rfind("/")
                if end > 0:
                    pat, fl = raw[1:end], raw[end + 1 :]
            b0 = ord(pat[0]) if pat else 0
            b1 = ord(pat[1]) if len(pat) > 1 else 0
            packed = (
                (b0 & 0xFF)
                | ((b1 & 0xFF) << 8)
                | ((len(pat) & 0xFF) << 16)
                | ((1 if "g" in fl else 0) << 24)
                | ((1 if "i" in fl else 0) << 25)
            )
            key = ("regex", packed) if value64 else packed
            if key not in const_map:
                const_map[key] = len(consts)
                consts.append(packed)
            orig_lc.append((const_map[key], _LC_REGEX))
            continue
        if isinstance(c, str):
            # data:image payloads live in ASET; stub the JS string so name_mem
            # is not filled with megabyte URIs. Layout / source strings stay.
            if c.startswith("data:") and len(c) > _STR_CAP:
                stored = "data:stub"
            else:
                stored = c
            orig_lc.append((_intern_name(names, name_index, stored), _LC_STR))
            continue
        if isinstance(c, float) and not isinstance(c, bool):
            if value64:
                bits = struct.unpack("<Q", struct.pack("<d", float(c)))[0]
                key = ("number", bits)
            else:
                bits = struct.unpack("<i", struct.pack("<f", float(c)))[0]
                key = bits
            if key not in const_map:
                const_map[key] = len(consts)
                consts.append(bits)
            orig_lc.append((const_map[key], _LC_F32))
            continue
        if isinstance(c, bool):
            v = 1 if c else 0
        else:
            try:
                v = int(c)
            except (TypeError, ValueError):
                v = 0
        if value64:
            bits = struct.unpack("<Q", struct.pack("<d", float(v)))[0]
            key = ("number", bits)
            stored = bits
        else:
            key = v
            stored = v
        if key not in const_map:
            const_map[key] = len(consts)
            consts.append(stored)
        orig_lc.append((const_map[key], _LC_I32))

    var_names: List[str] = []
    var_index: dict[str, int] = {}
    for n in names:
        if n in NATIVE_IDS or n in NATIVE_ALIASES:
            continue
        if n not in var_index:
            var_index[n] = len(var_names)
            var_names.append(n)

    ops_out: List[int] = []
    for op, *args in chunk.code:
        opc = int(op) & 0xFF
        a0 = 0
        a1 = 0
        if op == Op.LOAD_CONST:
            a0, a1 = orig_lc[args[0]]
            a0 &= 0xFFFF
        elif op in (Op.LOAD_VAR, Op.STORE_VAR, Op.LET_VAR):
            name = chunk.names[args[0]]
            if name not in var_index:
                var_index[name] = len(var_names)
                var_names.append(name)
            a0 = var_index[name] & 0xFFFF
            # NEW: LET_VAR a1 bit0 = call-frame local (fn param/var). RTL has
            # flat vars: it must always-store those, keeping init-if-missing
            # only for top-level LET_VAR (state survives per-frame re-runs).
            if op == Op.LET_VAR and len(args) > 1 and args[1]:
                a1 = 1
                # NEW: a1[7:1] = env slot hint + 1 (0 = no hint). RTL
                # phase-6 verified first guess; mismatch rescans from 0.
                if len(args) > 2 and args[2] is not None:
                    a1 |= ((int(args[2]) & 0x1F) + 1) << 1
            # LOAD_VAR/STORE_VAR a1: 0=chain, 1=global, 2+slot=local.
            elif op in (Op.LOAD_VAR, Op.STORE_VAR) and len(args) > 1:
                a1 = int(args[1]) & 0xFF
        elif op in (Op.JUMP, Op.JUMP_IF_FALSE):
            a0 = int(args[0]) & 0xFFFF
        elif op == Op.CALL_NATIVE:
            name = chunk.names[args[0]]
            argc = int(args[1]) & 0xFF
            if name in fns:
                # class body compiled before function hoist — rewrite to CALL_USER
                opc = int(Op.CALL_USER) & 0xFF
                a0 = int(fns[name][0]) & 0xFFFF
                a1 = argc
            else:
                nid = _native_id(name)
                if nid is None:
                    nid = NATIVE_IDS["_stub"]
                a0 = nid & 0xFFFF
                a1 = argc
        elif op == Op.MAKE_ARRAY:
            a0 = int(args[0]) & 0xFFFF
        elif op == Op.CALL_USER:
            a0 = int(args[0]) & 0xFFFF
            a1 = int(args[1]) & 0xFF
        elif op in (Op.GET_PROP, Op.SET_PROP):
            a0 = int(args[0]) & 0xFFFF
        elif op == Op.NEW_OBJ:
            a0 = int(args[0]) & 0xFFFF
            a1 = int(args[1]) & 0xFF
        elif op == Op.CALL_METHOD:
            a0 = int(args[0]) & 0xFFFF
            a1 = int(args[1]) & 0xFF
        elif op == Op.MAKE_FN:
            a0 = int(args[0]) & 0xFFFF
            # NEW: a1 bit7 = is_arrow (lexical this); bit6 = IIFE (flat call);
            # low 6 bits = nparam
            a1 = int(args[1]) & 0x3F if len(args) > 1 else 0
            if len(args) > 2 and args[2]:
                a1 |= 0x80
            if len(args) > 3 and args[3]:
                a1 |= 0x40
        elif op == Op.CALL_VAL:
            a0 = int(args[0]) & 0xFFFF
        word = (opc) | ((a0 & 0xFFFF) << 8) | ((a1 & 0xFF) << 24)
        ops_out.append(word)

    source_map = _source_map_section(chunk)
    flags = (
        FLAG_V2
        | (FLAG_ASET if aset else 0)
        | (FLAG_SOURCE_MAP if source_map else 0)
        | (FLAG_VALUE64 if value64 else 0)
    )
    hdr = MAGIC + struct.pack(
        "<HHHH", len(ops_out), len(consts), len(var_names), flags
    )
    body = (
        b"".join(struct.pack("<Q", c) for c in consts)
        if value64
        else b"".join(struct.pack("<i", c) for c in consts)
    )
    body += b"".join(struct.pack("<I", w) for w in ops_out)
    # trailer: names, var→name idx, class table (RTL ops_base unchanged)
    # Intern class/method names before freezing the name table
    classes = chunk.classes or {}
    class_rows: list[tuple[int, int, list[tuple[int, int]]]] = []
    for cname, meta in classes.items():
        ni = _intern_name(names, name_index, cname)
        ctor = meta.get("ctor")
        ctor_ip = 0xFFFF if ctor is None else int(ctor) & 0xFFFF
        meth_rows: list[tuple[int, int]] = []
        getters = meta.get("getters") or ()
        for mname, entry in (meta.get("methods") or {}).items():
            mi = _intern_name(names, name_index, mname)
            # NEW: bit15 of the name index flags a `get name()` accessor
            if mname in getters:
                mi |= 0x8000
            meth_rows.append((mi & 0xFFFF, int(entry) & 0xFFFF))
        class_rows.append((ni & 0xFFFF, ctor_ip, meth_rows))
    trailer = struct.pack("<H", len(names))
    # NEW: u16 hashes first so RTL intern does not walk UTF-8 (that FSM hung HTML RUN)
    for n in names:
        # NEW: u8 length after each hash — RTL string concat folds
        # h(a+b) = h(a)*31^len(b) + h(b), and find-or-alloc matches
        # hash+len (two PACMAN names collide on hash alone)
        trailer += struct.pack("<HB", _name_hash(n), min(len(n.encode("utf-8")), 255))
    trailer += struct.pack("<H", len(var_names))
    for n in var_names:
        trailer += struct.pack("<H", name_index.get(n, 0) & 0xFFFF)
    trailer += struct.pack("<H", len(class_rows))
    for ni, ctor_ip, meth_rows in class_rows:
        trailer += struct.pack("<HHH", ni, ctor_ip, len(meth_rows))
        for mi, entry in meth_rows:
            trailer += struct.pack("<HH", mi, entry)
    # Sprite block before UTF-8 names — RTL trailer stops after class table
    # then peeks this magic (PACMAN has none; INVADERS/DONKEY drawImage).
    spr = sprites if sprites is not None else getattr(chunk, "sprites", None)
    aset_payload = b""
    if aset:
        # ASET path: descriptors only (SPRD); pixels + palette go to the
        # external SRAM asset bank via the ASET section (never code BRAM).
        aset_payload, descs = build_aset_payload(
            getattr(chunk, "palette", None), spr
        )
        # NEW: RTL descriptor table holds 16 (MAX_SPR in jmr_js_vm.sv).
        # Fail LOUD at compile time — never silently drop a sheet.
        if len(descs) > 16:
            raise ValueError(
                f"ASET has {len(descs)} sprites; RTL MAX_SPR is 16 — "
                "grow the descriptor table, do not drop art"
            )
        trailer += b"SPRD" + struct.pack("<H", len(descs))
        for w, h, soff in descs:
            trailer += struct.pack("<HHI", w, h, soff)
        # NEW: FSTY — fillStyle color table. The compiler owns the title
        # palette, so it precomputes name→palette-index with the SAME
        # resolve the FM uses at runtime; RTL loads this LUT so PYTHON and
        # RTL paint the exact same indices (no hardcoded hex map drift).
        from .canvas_engine import nearest_palette_index, parse_css_color

        pal = getattr(chunk, "palette", None)
        fsty_rows = []
        if pal:
            for i, n in enumerate(names):
                if i >= 1024:
                    break  # RTL fill_lut is 1024 entries
                s = str(n).strip().lower()
                rgb = parse_css_color(s)
                if rgb is None:
                    continue
                idx = 0 if rgb == (0, 0, 0) else nearest_palette_index(pal, rgb, lo=1)
                fsty_rows.append((i, idx))
        trailer += b"FSTY" + struct.pack("<H", len(fsty_rows))
        for i, idx in fsty_rows:
            trailer += struct.pack("<HH", i, idx & 0xFF)
    elif spr:
        # Legacy SPR1 (tiny .JS demos only): pixels inline in the trailer.
        trailer += b"SPR1" + struct.pack("<H", len(spr))
        for w, h, pix in spr:
            trailer += struct.pack("<HH", int(w) & 0xFFFF, int(h) & 0xFFFF)
            trailer += pix[: int(w) * int(h)]
            if len(pix) < int(w) * int(h):
                trailer += b"\x00" * (int(w) * int(h) - len(pix))
    # UTF-8 names last. NEW: "NAMB" marks the section so the RTL trailer FSM can
    # find it with the same 4-byte peek it already does for SPR1/SPRD instead of
    # inferring the position. RTL streams these bytes into name_mem so str[i] /
    # str.length work on interned literals (string-row sprites).
    trailer += b"NAMB"
    for n in names:
        raw = n.encode("utf-8")[:0xFFFF]
        trailer += struct.pack("<H", len(raw)) + raw
    # Optional debug section is after the legacy trailer. Existing RTL stops
    # after NAMB and ignores it; validated Python execution restores op_lines.
    trailer += source_map
    if not aset:
        return hdr + body + trailer
    # ASET file layout: [hdr | u32 aset_off | body | trailer | pad4 | ASET…]
    code_len = len(hdr) + 4 + len(body) + len(trailer)
    pad = (-code_len) % 4  # ASET section starts word-aligned for the streamer
    aset_off = code_len + pad
    return (
        hdr
        + struct.pack("<I", aset_off)
        + body
        + trailer
        + b"\x00" * pad
        + ASET_MAGIC
        + struct.pack("<I", len(aset_payload))
        + aset_payload
    )


def decode_chunk(data: bytes | ProgramImage) -> Chunk:
    """Validate JSB1 bytes, then reconstruct a Chunk solely for VM semantics."""
    image = data if isinstance(data, ProgramImage) else ProgramImage(data)
    return image.decode()


def _decode_chunk_unchecked(data: bytes, meta: _ImageMeta) -> Chunk:
    """Decode bytes already checked by ProgramImage.

    Transitional only: functional_model.bytecode.VM still owns opcode
    semantics, but every field in this Chunk is reconstructed from bytes.
    """
    n_ops, n_consts, n_vars, flags = struct.unpack_from("<HHHH", data, 4)
    off = 12
    aset_off = 0
    if flags & FLAG_ASET:
        aset_off = struct.unpack_from("<I", data, off)[0]
        off += 4
    packed_consts: List[int] = []
    for _ in range(n_consts):
        if flags & FLAG_VALUE64:
            packed_consts.append(struct.unpack_from("<Q", data, off)[0])
            off += 8
        else:
            packed_consts.append(struct.unpack_from("<i", data, off)[0])
            off += 4
    ops_words: List[int] = []
    for _ in range(n_ops):
        ops_words.append(struct.unpack_from("<I", data, off)[0])
        off += 4
    names: List[str] = []
    var_name_idx: List[int] = []
    classes: dict[str, dict] = {}
    sprites: list = []
    palette: list | None = None
    if flags & FLAG_V2:
        n_names = struct.unpack_from("<H", data, off)[0]
        off += 2
        # hashes[n_names] (u16 hash + u8 len each) then varmap/classes then UTF-8 names
        off += 3 * n_names  # skip RTL intern hash+len records
        n_vn = struct.unpack_from("<H", data, off)[0]
        off += 2
        for _ in range(n_vn):
            var_name_idx.append(struct.unpack_from("<H", data, off)[0])
            off += 2
        n_cls = struct.unpack_from("<H", data, off)[0]
        off += 2
        class_raw: list[tuple[int, int, list[tuple[int, int]]]] = []
        for _ in range(n_cls):
            ni, ctor_ip, n_meth = struct.unpack_from("<HHH", data, off)
            off += 6
            meths: list[tuple[int, int]] = []
            for _m in range(n_meth):
                mi, entry = struct.unpack_from("<HH", data, off)
                off += 4
                meths.append((mi, int(entry)))
            class_raw.append((ni, ctor_ip, meths))
        sprite_descs: list[tuple[int, int, int]] = []
        if off + 4 <= len(data) and data[off : off + 4] == b"SPR1":
            off += 4
            n_spr = struct.unpack_from("<H", data, off)[0]
            off += 2
            for _s in range(n_spr):
                sw, sh = struct.unpack_from("<HH", data, off)
                off += 4
                npi = int(sw) * int(sh)
                sprites.append((int(sw), int(sh), bytes(data[off : off + npi])))
                off += npi
        elif off + 4 <= len(data) and data[off : off + 4] == b"SPRD":
            # ASET descriptors: pixels live in the ASET section / asset SRAM
            off += 4
            n_spr = struct.unpack_from("<H", data, off)[0]
            off += 2
            for _s in range(n_spr):
                sw, sh, soff = struct.unpack_from("<HHI", data, off)
                off += 8
                sprite_descs.append((int(sw), int(sh), int(soff)))
        # NEW: skip the FSTY fillStyle LUT (RTL-only; FM resolves at runtime
        # with the same algorithm the compiler used, so results are identical)
        if off + 4 <= len(data) and data[off : off + 4] == b"FSTY":
            off += 4
            n_fsty = struct.unpack_from("<H", data, off)[0]
            off += 2 + 4 * n_fsty
        # NEW: "NAMB" marks the UTF-8 name bytes for the RTL trailer FSM.
        # Tolerate its absence so an older .JSH still decodes.
        if off + 4 <= len(data) and data[off : off + 4] == b"NAMB":
            off += 4
        for _ in range(n_names):
            ln = struct.unpack_from("<H", data, off)[0]
            off += 2
            names.append(data[off : off + ln].decode("utf-8", errors="replace"))
            off += ln
        for ni, ctor_ip, meths in class_raw:
            cname = names[ni] if ni < len(names) else f"C{ni}"
            methods = {}
            getters: set = set()
            for mi, entry in meths:
                # NEW: bit15 of the name index flags a `get name()` accessor
                is_get = bool(mi & 0x8000)
                mi &= 0x7FFF
                mname = names[mi] if mi < len(names) else f"m{mi}"
                methods[mname] = int(entry)
                if is_get:
                    getters.add(mname)
            classes[cname] = {
                "ctor": None if ctor_ip == 0xFFFF else int(ctor_ip),
                "methods": methods,
                "getters": getters,
            }
        # pad names so var/GET_PROP indices resolve
        while len(names) < n_names:
            names.append("")
        # ASET section: palette + full-res sprite banks (asset-SRAM image)
        if (flags & FLAG_ASET) and aset_off:
            if data[aset_off : aset_off + 4] != ASET_MAGIC:
                raise ValueError("bad ASET magic (truncated asset section?)")
            pay_len = struct.unpack_from("<I", data, aset_off + 4)[0]
            payload = data[aset_off + 8 : aset_off + 8 + pay_len]
            if len(payload) < pay_len:
                raise ValueError("truncated ASET payload")
            palette = [
                (payload[i * 3], payload[i * 3 + 1], payload[i * 3 + 2])
                for i in range(256)
            ]
            for sw, sh, soff in sprite_descs:
                npi = sw * sh
                sprites.append((sw, sh, bytes(payload[soff : soff + npi])))
    else:
        # v1: synthesize var names; GET_PROP name idx may not round-trip
        names = [f"v{i}" for i in range(max(n_vars, 1))]
        var_name_idx = list(range(n_vars))

    idn = _id_to_native()
    code: List[Tuple] = []
    if flags & FLAG_VALUE64:
        consts: List[Any] = [
            struct.unpack("<d", struct.pack("<Q", raw))[0] for raw in packed_consts
        ]
    else:
        consts = list(packed_consts)
    for w in ops_words:
        opc = w & 0xFF
        a0 = (w >> 8) & 0xFFFF
        a1 = (w >> 24) & 0xFF
        op = Op(opc) if opc in Op._value2member_map_ else opc
        if op == Op.LOAD_CONST:
            if a1 == _LC_STR:
                consts.append(names[a0] if a0 < len(names) else "")
                code.append((Op.LOAD_CONST, len(consts) - 1))
            elif a1 == _LC_NONE:
                consts.append(None)
                code.append((Op.LOAD_CONST, len(consts) - 1))
            elif a1 == _LC_F32:
                bits = packed_consts[a0] if a0 < len(packed_consts) else 0
                if flags & FLAG_VALUE64:
                    consts.append(struct.unpack("<d", struct.pack("<Q", bits))[0])
                else:
                    consts.append(struct.unpack("<f", struct.pack("<i", bits))[0])
                code.append((Op.LOAD_CONST, len(consts) - 1))
            elif a1 == _LC_REGEX:
                packed = packed_consts[a0] if a0 < len(packed_consts) else 0
                u = packed & 0xFFFFFFFF
                plen = (u >> 16) & 0xFF
                chars = []
                if plen >= 1:
                    chars.append(chr(u & 0xFF))
                if plen >= 2:
                    chars.append(chr((u >> 8) & 0xFF))
                fl = ("g" if (u >> 24) & 1 else "") + ("i" if (u >> 25) & 1 else "")
                consts.append(
                    {"__class": "RegExp", "source": "/" + "".join(chars) + "/" + fl}
                )
                code.append((Op.LOAD_CONST, len(consts) - 1))
            else:
                code.append((Op.LOAD_CONST, a0))
        elif op in (Op.LOAD_VAR, Op.STORE_VAR, Op.LET_VAR):
            ni = var_name_idx[a0] if a0 < len(var_name_idx) else a0
            # ensure names[ni] exists for VM
            while len(names) <= ni:
                names.append(f"v{len(names)}")
            # Keep a1 so LOAD_VAR/STORE_VAR global/local modes survive decode.
            if a1:
                code.append((op, ni, a1))
            else:
                code.append((op, ni))
        elif op == Op.CALL_NATIVE:
            nstr = idn.get(a0, "_stub")
            ni = _intern_name(names, {n: i for i, n in enumerate(names)}, nstr)
            code.append((Op.CALL_NATIVE, ni, a1))
        elif op == Op.CALL_USER:
            code.append((Op.CALL_USER, a0, a1))
        elif op in (Op.JUMP, Op.JUMP_IF_FALSE, Op.MAKE_ARRAY, Op.GET_PROP, Op.SET_PROP, Op.CALL_VAL):
            code.append((op, a0))
        elif op == Op.MAKE_FN:
            # NEW: unpack a1 bit7 → is_arrow, bit6 → IIFE, low 6 → nparam
            code.append(
                (op, a0, a1 & 0x3F, 1 if (a1 & 0x80) else 0, 1 if (a1 & 0x40) else 0)
            )
        elif op in (Op.NEW_OBJ, Op.CALL_METHOD):
            code.append((op, a0, a1))
        else:
            code.append((op,) if not a0 and not a1 else (op, a0, a1) if a1 else (op, a0))
    return Chunk(
        code,
        consts,
        names,
        functions=None,
        classes=classes or None,
        sprites=sprites or None,
        palette=palette,
        op_lines=list(meta.op_lines) if meta.op_lines is not None else None,
    )


def jsb_to_hex_lines(data: bytes, width: int = 4) -> str:
    """$readmemh words (width bytes, little-endian → hex word)."""
    lines = []
    # Pad to width
    pad = (-len(data)) % width
    data = data + b"\x00" * pad
    for i in range(0, len(data), width):
        chunk = data[i : i + width]
        # little-endian word as hex
        val = int.from_bytes(chunk, "little")
        lines.append(f"{val:0{width*2}X}")
    return "\n".join(lines) + "\n"


def decode_header(data: bytes) -> Tuple[int, int, int]:
    if data[:4] != MAGIC:
        raise ValueError("bad JSB magic")
    n_ops, n_consts, n_vars, _flags = struct.unpack_from("<HHHH", data, 4)
    return n_ops, n_consts, n_vars
