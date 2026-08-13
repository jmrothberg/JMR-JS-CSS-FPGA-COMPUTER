"""External SRAM asset bank — Python reference model.

Contract (see docs/ARCHITECTURE.md and CONSTITUTION.md MEMORY): one 4 MByte
SRAM, 2M x 16 (ISSI IS61WV204816), behind a simple synchronous port
(addr[20:0], wdata[15:0], rdata[15:0], we, req, ack). Same port, three
implementations: behavioral model in FPGA-SIM, DDR3-behind-a-bridge on the
Nexys Video board, the real chip on the ASIC / final PCB.

On RUN the loader streams the .JSH ASET payload here:
  0x000000 - 0x0002FF  title palette (256 x RGB888)
  0x000300 - top       full-res 8-bpp sprite banks (2-byte aligned)

LLM NOTE: the FM keeps one bytearray; word semantics (16-bit) matter only to
RTL/bridge. Sprite pixels are read from this bank at blit time — never copied
into code BRAM or the heap ("handles, not megabyte art").
"""

from __future__ import annotations

SRAM_BYTES = 4 * 1024 * 1024  # 2M x 16


class SramEngine:
    def __init__(self) -> None:
        self.mem = bytearray(SRAM_BYTES)
        self.loaded_bytes = 0  # last ASET payload size (MEM report / debug)

    def clear(self) -> None:
        self.mem[:] = bytes(SRAM_BYTES)
        self.loaded_bytes = 0

    def load(self, payload: bytes, base: int = 0) -> None:
        """Stream an ASET payload into the bank (RUN overwrites in place)."""
        if base < 0 or base + len(payload) > SRAM_BYTES:
            raise ValueError(
                f"ASET payload {len(payload)} bytes exceeds 4 MB asset SRAM"
            )
        self.mem[base : base + len(payload)] = payload
        self.loaded_bytes = len(payload)

    def view(self, off: int, length: int) -> memoryview:
        """Zero-copy window for the blitter (bounds-clamped)."""
        off = max(0, int(off))
        end = min(SRAM_BYTES, off + max(0, int(length)))
        return memoryview(self.mem)[off:end]
