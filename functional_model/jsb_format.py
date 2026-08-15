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

import struct
from typing import Any, List, Tuple

from functional_model.bytecode import Chunk, Op

MAGIC = b"JSB1"

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
}

# NEW: aliases share an id (decode prefers the canonical NATIVE_IDS key)
NATIVE_ALIASES = {
    "console.warn": 0,
    "addEventListener": 19,
    "removeEventListener": 36,
}

# flags bit0 = JSB v2 (name table + class table after ops; ops_base still 3+n_consts)
FLAG_V2 = 1
# flags bit1 = ASET asset section present (external SRAM asset bank).
# When set, a u32 aset_byte_off (from file start) follows the 12-byte header
# (consts then start at byte 16 / word 4). Code part = [0, aset_byte_off);
# the loader streams code → code BRAM and the ASET payload → asset SRAM.
FLAG_ASET = 2
ASET_MAGIC = b"ASET"
ASET_PAL_BYTES = 768  # 256 × RGB888 at asset-SRAM offset 0
SRAM_BYTES = 4 * 1024 * 1024  # 2M × 16 IS61WV204816 contract (see docs/ARCHITECTURE.md)
# LOAD_CONST a1: 0=i32  1=string intern  2=None  3=IEEE-754 bits in const pool
# 4=RegExp packed in const pool (pattern bytes + flags — RTL has no char heap)
_LC_I32, _LC_STR, _LC_NONE, _LC_F32, _LC_REGEX = 0, 1, 2, 3, 4
_STR_CAP = 512  # huge data: URIs stubbed — Image.onload still truthy


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
    return bytes(out), descs


def encode_chunk(
    chunk: Chunk, v2: bool | None = None, sprites=None, aset: bool = False
) -> bytes:
    """Encode a compiled Chunk to .JSB bytes.

    v1 (flags=0): ints only — simple .JS titles.
    v2 (flags=1): name/class trailer after ops so RTL ops_base stays 3+n_consts.
    aset=True (flags bit1): SPRD descriptors in the trailer + ASET section
    (palette + full-res sprite banks) for the external SRAM asset bank —
    the product path for HTML titles (no pixels in code BRAM).
    """
    if v2 is None:
        v2 = _needs_v2(chunk)
    if v2 or aset:
        return _encode_v2(
            chunk,
            sprites=sprites if sprites is not None else getattr(chunk, "sprites", None),
            aset=aset,
        )
    return _encode_v1(chunk)


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

    hdr = MAGIC + struct.pack("<HHHH", len(ops_out), len(consts), len(var_names), 0)
    body = b"".join(struct.pack("<i", c) for c in consts)
    body += b"".join(struct.pack("<I", w) for w in ops_out)
    return hdr + body


def _intern_name(names: List[str], index: dict[str, int], s: str) -> int:
    if s not in index:
        index[s] = len(names)
        names.append(s)
    return index[s]


def _encode_v2(chunk: Chunk, sprites=None, aset: bool = False) -> bytes:
    """JSB v2: keep header+i32 consts+ops; name/class trailer after ops."""
    names: List[str] = list(chunk.names)
    name_index: dict[str, int] = {n: i for i, n in enumerate(names)}
    fns = chunk.functions or {}

    consts: List[int] = []
    const_map: dict[int, int] = {}
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
            if packed not in const_map:
                const_map[packed] = len(consts)
                consts.append(packed)
            orig_lc.append((const_map[packed], _LC_REGEX))
            continue
        if isinstance(c, str):
            stored = c if len(c) <= _STR_CAP else "data:stub"
            orig_lc.append((_intern_name(names, name_index, stored), _LC_STR))
            continue
        if isinstance(c, float) and not isinstance(c, bool):
            bits = struct.unpack("<i", struct.pack("<f", float(c)))[0]
            if bits not in const_map:
                const_map[bits] = len(consts)
                consts.append(bits)
            orig_lc.append((const_map[bits], _LC_F32))
            continue
        if isinstance(c, bool):
            v = 1 if c else 0
        else:
            try:
                v = int(c)
            except (TypeError, ValueError):
                v = 0
        if v not in const_map:
            const_map[v] = len(consts)
            consts.append(v)
        orig_lc.append((const_map[v], _LC_I32))

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

    flags = FLAG_V2 | (FLAG_ASET if aset else 0)
    hdr = MAGIC + struct.pack(
        "<HHHH", len(ops_out), len(consts), len(var_names), flags
    )
    body = b"".join(struct.pack("<i", c) for c in consts)
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
    def _name_hash(s: str) -> int:
        h = 0
        for b in s.encode("utf-8"):
            h = (h * 31 + b) & 0xFFFF
        return h

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


def decode_chunk(data: bytes) -> Chunk:
    """Decode JSB/JSH bytes back to a Chunk (PYTHON card path / HM)."""
    if data[:4] != MAGIC:
        raise ValueError("bad JSB magic")
    n_ops, n_consts, n_vars, flags = struct.unpack_from("<HHHH", data, 4)
    off = 12
    aset_off = 0
    if flags & FLAG_ASET:
        aset_off = struct.unpack_from("<I", data, off)[0]
        off += 4
    packed_consts: List[int] = []
    for _ in range(n_consts):
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
    consts: List[Any] = list(packed_consts)
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
