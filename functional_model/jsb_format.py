"""JMR-JS binary bytecode (.JSB) — frozen encoding for PYTHON + RTL VM.

Layout (little-endian):
  magic[4] = b'JSB1'
  n_ops:u16  n_consts:u16  n_vars:u16  flags:u16
  consts[n_consts]: each i32
  ops[n_ops]: each u32 = { arg1[31:24], arg0[23:8], op[7:0] }

Native IDs (CALL_NATIVE arg0) — resolved at compile time from name:
  0 console.log  1 clear  2 fillRect  3 swapBuffers
  4 keyLeft  5 keyRight  6 keyFire  7 startLoop
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
}


def encode_chunk(chunk: Chunk) -> bytes:
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
        if n in NATIVE_IDS:
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
            if name not in NATIVE_IDS:
                raise ValueError(f"unknown native {name!r}")
            a0 = NATIVE_IDS[name] & 0xFFFF
            a1 = int(args[1]) & 0xFF
        elif op == Op.MAKE_ARRAY:
            a0 = int(args[0]) & 0xFFFF
        word = (opc) | ((a0 & 0xFFFF) << 8) | ((a1 & 0xFF) << 24)
        ops_out.append(word)

    hdr = MAGIC + struct.pack("<HHHH", len(ops_out), len(consts), len(var_names), 0)
    body = b"".join(struct.pack("<i", c) for c in consts)
    body += b"".join(struct.pack("<I", w) for w in ops_out)
    return hdr + body


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
