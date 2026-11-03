"""Convert optional desktop artwork to the FPGA's tiny native disk format.

Pillow is used only while preparing the card, never by the board reader.
No program names or game-specific artwork are embedded here.
"""

from __future__ import annotations

from io import BytesIO
from pathlib import Path
from typing import Callable

from functional_model.desktop_icons import (
    DesktopIcon, ICON_HEADER, ICON_SIZE, decode_icon, icon_card_name,
)


def convert_icon(data: bytes) -> bytes:
    """Accept native JIC1 or an ordinary PNG/ICO; sniff content, not suffix."""
    if data.startswith(ICON_HEADER[:4]):
        return decode_icon(data).encode()
    from PIL import Image

    with Image.open(BytesIO(data)) as source:
        # Prefer the original 32px ICO frame, avoiding shrink/expand blur.
        if source.format == "ICO" and (ICON_SIZE, ICON_SIZE) in source.ico.sizes():
            source = source.ico.getimage((ICON_SIZE, ICON_SIZE))
        image = source.convert("RGBA")
    image.thumbnail((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (ICON_SIZE, ICON_SIZE))
    canvas.paste(image, ((ICON_SIZE - image.width) // 2,
                        (ICON_SIZE - image.height) // 2))
    pixels = bytearray(ICON_SIZE * ICON_SIZE)
    mask = bytearray(ICON_SIZE * ICON_SIZE // 8)
    rgba = canvas.load()
    for i in range(ICON_SIZE * ICON_SIZE):
        r, g, b, a = rgba[i % ICON_SIZE, i // ICON_SIZE]
        pixels[i] = (r & 0xE0) | ((g >> 3) & 0x1C) | (b >> 6)
        if a >= 128:
            mask[i >> 3] |= 0x80 >> (i & 7)
    return DesktopIcon(bytes(pixels), bytes(mask)).encode()


def collect_program_icons(
    storage_dir: Path,
    programs: list[str],
    report: Callable[[str], None] = print,
) -> list[tuple[str, bytes]]:
    """Find sidecars in storage/ or storage/icons/, without touching sources.

    Root artwork requires an explicit icon suffix so game sprite PNGs are
    never mistaken for application icons. In the icons folder STEM.PNG is
    also accepted. Native sidecars take priority, then standard ICO files.
    """
    suffixes = (".ICN", ".ICO", ".ICONS", ".ICON", ".ICON.PNG", ".ICON.ICO")
    root_files = {p.name.upper(): p for p in sorted(storage_dir.iterdir())
                  if p.is_file() and not p.name.startswith(".")}
    icon_dir = storage_dir / "icons"
    folder_files = ({p.name.upper(): p for p in sorted(icon_dir.iterdir())
                     if p.is_file() and not p.name.startswith(".")}
                    if icon_dir.is_dir() else {})
    out = {}
    for program in programs:
        stem = Path(program).stem.upper()
        card = icon_card_name(program)
        if card in out:
            continue
        candidates = []
        for files, extensions in ((root_files, suffixes),
                                  (folder_files, (*suffixes, ".PNG"))):
            for suffix in extensions:
                path = files.get(stem + suffix)
                if path is not None:
                    candidates.append(path)
        for path in candidates:
            try:
                out[card] = convert_icon(path.read_bytes())
            except (OSError, ValueError, SyntaxError) as exc:
                report(f"note: {path.name}: unusable icon ({exc}); using fallback unless another icon is available")
                continue
            report(f"note: {path.name} -> {card} (32x32 desktop icon)")
            break
    return sorted(out.items())
