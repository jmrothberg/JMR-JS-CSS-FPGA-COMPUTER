"""Small disk icons shared by the desktop model and its RTL byte reader.

JIC1 layout: 8-byte header, 128-byte transparency bitmap, 1024 RGB332
pixels. Mask bit 7 is the leftmost pixel; one means draw. Pixels are in
row order. Putting the mask first lets hardware stream pixels using only
128 bytes of distributed RAM, rather than buffering every program icon.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import PurePath
from typing import Callable

ICON_SIZE = 32
ICON_HEADER = b"JIC1\x20\x20\x01\x00"
ICON_MASK_BYTES = ICON_SIZE * ICON_SIZE // 8
ICON_FILE_BYTES = len(ICON_HEADER) + ICON_MASK_BYTES + ICON_SIZE * ICON_SIZE


@dataclass(frozen=True)
class DesktopIcon:
    pixels: bytes
    mask: bytes

    def __post_init__(self) -> None:
        if len(self.pixels) != ICON_SIZE * ICON_SIZE:
            raise ValueError("icon must have 32 by 32 RGB332 pixels")
        if len(self.mask) != ICON_MASK_BYTES:
            raise ValueError("icon must have a 128-byte transparency mask")

    def pixel(self, x: int, y: int) -> tuple[int, bool]:
        if not (0 <= x < ICON_SIZE and 0 <= y < ICON_SIZE):
            raise IndexError((x, y))
        i = y * ICON_SIZE + x
        return self.pixels[i], bool(self.mask[i >> 3] & (0x80 >> (i & 7)))

    def encode(self) -> bytes:
        return ICON_HEADER + self.mask + self.pixels


def decode_icon(data: bytes) -> DesktopIcon:
    if len(data) != ICON_FILE_BYTES or data[:8] != ICON_HEADER:
        raise ValueError("unsupported or incomplete JIC1 icon")
    return DesktopIcon(bytes(data[136:]), bytes(data[8:136]))


def icon_card_name(program_name: str) -> str:
    """Match the actual FAT 8.3 program stem; HTML and HTM share an icon."""
    return PurePath(program_name).stem[:8].upper() + ".ICN"


def generic_pixel(x: int, y: int) -> tuple[int, bool]:
    """Outlined application window. Also implemented in jmr_icon_stream.sv."""
    if not (3 <= x <= 28 and 3 <= y <= 28):
        return 0, False
    if x in (3, 28) or y in (3, 28, 9):
        return 0, True
    if y <= 8:
        return 0x17, True  # bright blue title bar, RGB332
    if 7 <= x <= 24 and 14 <= y <= 23:
        if x in (7, 24) or y in (14, 23):
            return 0, True
        return 0xFC, True  # yellow screen
    return 0xFF, True


def _generic_icon() -> DesktopIcon:
    pixels = bytearray(1024)
    mask = bytearray(ICON_MASK_BYTES)
    for y in range(ICON_SIZE):
        for x in range(ICON_SIZE):
            i = y * ICON_SIZE + x
            pixels[i], opaque = generic_pixel(x, y)
            if opaque:
                mask[i >> 3] |= 0x80 >> (i & 7)
    return DesktopIcon(bytes(pixels), bytes(mask))


GENERIC_PROGRAM_ICON = _generic_icon()


def read_program_icon(read_bytes: Callable[[str], bytes], program_name: str) -> DesktopIcon:
    """Read from the mounted disk, never from a separate host-only catalog."""
    try:
        return decode_icon(read_bytes(icon_card_name(program_name)))
    except (OSError, ValueError):
        return GENERIC_PROGRAM_ICON
