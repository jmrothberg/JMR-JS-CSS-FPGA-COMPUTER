"""Python hardware model of the RTL JS VM — explicit code BRAM + JSB v2 load.

LLM NOTE: Constitution: FM → this HM (memories / sizes) → SystemVerilog.
Do not invent a third JS interpreter: opcode semantics stay in
functional_model.bytecode.VM. This module is the load/memory twin of
rtl/engines/jmr_js_vm.sv (CODE_WORDS, header parse, heap sizes).
"""

from __future__ import annotations

from pathlib import Path
from typing import List, Optional

from functional_model.bytecode import VM
from functional_model.canvas_engine import CanvasEngine
from functional_model.input_engine import InputEngine
from functional_model.jsb_format import MAGIC, decode_chunk
from functional_model.machine import Machine

# Match RTL jmr_js_vm.sv (PACMAN.HTML ~16K ops; 32K words).
CODE_WORDS = 32768
MAX_CONSTS = 1024
MAX_VARS = 512
HEAP_SLOTS = 4096  # objects/arrays; BRAM heap in RTL, not DDR3 yet
STACK_DEPTH = 512


class JsHwVm:
    """Load .JSH/.JSB into code_mem, decode v2 trailer, run FM VM + canvas."""

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
        self.error: Optional[str] = None
        self.running = False

    def load_blob(self, data: bytes) -> None:
        """Write JSB bytes as little-endian words into code BRAM (RTL load)."""
        if data[:4] != MAGIC:
            raise ValueError("bad JSB magic")
        pad = (-len(data)) % 4
        raw = data + b"\x00" * pad
        nwords = min(len(raw) // 4, CODE_WORDS)
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
        self.ops_base = 3 + self.n_consts
        if self.n_vars > MAX_VARS:
            raise ValueError(f"n_vars {self.n_vars} > MAX_VARS {MAX_VARS}")
        if self.n_consts > MAX_CONSTS:
            raise ValueError(f"n_consts {self.n_consts} > MAX_CONSTS {MAX_CONSTS}")
        if self.ops_base + self.n_ops > CODE_WORDS:
            raise ValueError(
                f"code {self.ops_base + self.n_ops} words > CODE_WORDS {CODE_WORDS}"
            )
        chunk = decode_chunk(data)
        self._m.vm = VM(natives=self._m._natives())
        self._m.vm.globals.clear()
        self._m.html_host = None
        self._m._html_chunk = chunk
        self._m._sprites = list(getattr(chunk, "sprites", None) or [])
        self._m.vm._sprites = self._m._sprites
        self._m._raf_q = []
        self._m._listeners = []
        self._m._bytecode_html = True
        self._m.running = True
        self._m.vm.run(chunk)
        self.error = self._m.vm.error
        self.running = bool(self._m.running) and not self.error
        if self.error:
            self._m.running = False
            self._m._bytecode_html = False

    def load_path(self, path: Path) -> None:
        self.load_blob(Path(path).read_bytes())

    def set_key_bits(self, bits: int) -> None:
        self._m.set_key_bits(bits)

    def frame_tick(self) -> None:
        if not self.running:
            return
        self._m.frame_tick()
        self.error = self._m.vm.error
        self.running = bool(self._m.running) and not self.error

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
