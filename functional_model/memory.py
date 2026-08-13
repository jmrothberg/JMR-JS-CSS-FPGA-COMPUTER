"""Minimal Memory for FAT32 card tooling (BASIC sibling method, slimmed)."""

from __future__ import annotations

from . import memory_map as mm


class MemoryError_(Exception):
    pass


class Memory:
    def __init__(self, cycles=None) -> None:
        self.cells = bytearray(mm.ADDRESS_SPACE)
        self.cycles = cycles

    def read(self, address: int) -> int:
        if not 0 <= address < mm.ADDRESS_SPACE:
            raise MemoryError_(f"read outside address space: {address:#06x}")
        return self.cells[address]

    def write(self, address: int, value: int) -> None:
        if not 0 <= address < mm.ADDRESS_SPACE:
            raise MemoryError_(f"write outside address space: {address:#06x}")
        self.cells[address] = value & 0xFF

    def read_block(self, address: int, length: int) -> bytes:
        if address < 0 or address + length > mm.ADDRESS_SPACE:
            raise MemoryError_(f"block read outside: {address:#06x}+{length}")
        return bytes(self.cells[address : address + length])

    def write_block(self, address: int, data: bytes) -> None:
        if address < 0 or address + len(data) > mm.ADDRESS_SPACE:
            raise MemoryError_(f"block write outside: {address:#06x}+{len(data)}")
        self.cells[address : address + len(data)] = data
