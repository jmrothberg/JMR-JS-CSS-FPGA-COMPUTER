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
}

# NEW: aliases share an id (decode prefers the canonical NATIVE_IDS key)
NATIVE_ALIASES = {
    "console.warn": 0,
    "addEventListener": 19,
}

# flags bit0 = JSB v2 (name table + class table after ops; ops_base still 3+n_consts)
FLAG_V2 = 1
# LOAD_CONST a1: 0=i32  1=string intern  2=None  3=IEEE-754 bits in const pool
_LC_I32, _LC_STR, _LC_NONE, _LC_F32 = 0, 1, 2, 3
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
    return False


def encode_chunk(chunk: Chunk, v2: bool | None = None, sprites=None) -> bytes:
    """Encode a compiled Chunk to .JSB bytes.

    v1 (flags=0): ints only — simple .JS titles.
    v2 (flags=1): name/class trailer after ops so RTL ops_base stays 3+n_consts.
    """
    if v2 is None:
        v2 = _needs_v2(chunk)
    if v2:
        return _encode_v2(chunk, sprites=sprites if sprites is not None else getattr(chunk, "sprites", None))
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
            a1 = int(args[1]) & 0xFF if len(args) > 1 else 0
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


def _encode_v2(chunk: Chunk, sprites=None) -> bytes:
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
            a1 = int(args[1]) & 0xFF if len(args) > 1 else 0
        elif op == Op.CALL_VAL:
            a0 = int(args[0]) & 0xFFFF
        word = (opc) | ((a0 & 0xFFFF) << 8) | ((a1 & 0xFF) << 24)
        ops_out.append(word)

    hdr = MAGIC + struct.pack(
        "<HHHH", len(ops_out), len(consts), len(var_names), FLAG_V2
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
        for mname, entry in (meta.get("methods") or {}).items():
            mi = _intern_name(names, name_index, mname)
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
        trailer += struct.pack("<H", _name_hash(n))
    trailer += struct.pack("<H", len(var_names))
    for n in var_names:
        trailer += struct.pack("<H", name_index.get(n, 0) & 0xFFFF)
    trailer += struct.pack("<H", len(class_rows))
    for ni, ctor_ip, meth_rows in class_rows:
        trailer += struct.pack("<HHH", ni, ctor_ip, len(meth_rows))
        for mi, entry in meth_rows:
            trailer += struct.pack("<HH", mi, entry)
    # SPR1 sprite pack before UTF-8 names — RTL trailer stops after class table
    # then peeks this magic (PACMAN has none; INVADERS/DONKEY drawImage).
    spr = sprites if sprites is not None else getattr(chunk, "sprites", None)
    if spr:
        trailer += b"SPR1" + struct.pack("<H", len(spr))
        for w, h, pix in spr:
            trailer += struct.pack("<HH", int(w) & 0xFFFF, int(h) & 0xFFFF)
            trailer += pix[: int(w) * int(h)]
            if len(pix) < int(w) * int(h):
                trailer += b"\x00" * (int(w) * int(h) - len(pix))
    # UTF-8 names last — PYTHON decode only (RTL stops after class table / SPR1)
    for n in names:
        raw = n.encode("utf-8")[:0xFFFF]
        trailer += struct.pack("<H", len(raw)) + raw
    return hdr + body + trailer


def decode_chunk(data: bytes) -> Chunk:
    """Decode JSB/JSH bytes back to a Chunk (PYTHON card path / HM)."""
    if data[:4] != MAGIC:
        raise ValueError("bad JSB magic")
    n_ops, n_consts, n_vars, flags = struct.unpack_from("<HHHH", data, 4)
    off = 12
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
    if flags & FLAG_V2:
        n_names = struct.unpack_from("<H", data, off)[0]
        off += 2
        # hashes[n_names] then varmap/classes then UTF-8 names
        off += 2 * n_names  # skip RTL intern hashes
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
        for _ in range(n_names):
            ln = struct.unpack_from("<H", data, off)[0]
            off += 2
            names.append(data[off : off + ln].decode("utf-8", errors="replace"))
            off += ln
        for ni, ctor_ip, meths in class_raw:
            cname = names[ni] if ni < len(names) else f"C{ni}"
            methods = {
                (names[mi] if mi < len(names) else f"m{mi}"): int(entry)
                for mi, entry in meths
            }
            classes[cname] = {
                "ctor": None if ctor_ip == 0xFFFF else int(ctor_ip),
                "methods": methods,
            }
        # pad names so var/GET_PROP indices resolve
        while len(names) < n_names:
            names.append("")
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
        elif op in (Op.NEW_OBJ, Op.CALL_METHOD, Op.MAKE_FN):
            code.append((op, a0, a1))
        else:
            code.append((op,) if not a0 and not a1 else (op, a0, a1) if a1 else (op, a0))
    return Chunk(
        code, consts, names, functions=None, classes=classes or None, sprites=sprites or None
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
