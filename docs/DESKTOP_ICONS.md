# Optional program icons

The Finder-style monitor uses the program's FAT filename stem to find its
icon. There is no list of game names. `NAME.HTML`, `NAME.HTM`, and
`NAME.JSH` refer to the same `NAME.ICN` icon. Missing, malformed or
unreadable icons use the generic application window.

## Artwork supplied by the icon agent

Keep original artwork in `storage/` as `NAME.ICO`, `NAME.ICONS`,
`NAME.ICON`, `NAME.ICON.PNG` or `NAME.ICON.ICO`. The suffix does not change
the image decoder: contents must be a normal image Pillow can read (such
as PNG or Windows ICO), or the native format below. `storage/icons/NAME.PNG`
is also accepted. Root sprite PNG files are intentionally ignored.

Use the full host program stem before card-name truncation. For example,
`LONGTITLE.ICO` beside `LONGTITLE.HTML` becomes `LONGTITL.ICN` beside
`LONGTITL.HTM`. The existing card-name collision check still applies to
programs. Native `.ICN` artwork is preferred, followed by `.ICO`, `.ICONS`,
`.ICON`, `.ICON.PNG` and `.ICON.ICO`; root sidecars precede the icons
folder. A bad candidate produces a build note and the next candidate is
tried. No valid candidate means the runtime generic icon. A markdown
file with no icon is included in the picker. If you do not choose one,
the card builder writes the text document icon. A saved choice is kept.

`tools/make_sd_image.py create` performs the conversion. If a title has
no artwork yet and a display is attached, it first runs
`tools/pick_icon.py`: sprites cut from that title's `.ARTX` (nearest
neighbor, centered in 32×32). A title with no picture is offered a
built-in set: the line-art pictures, the same Macintosh sheet in color
(smile, floppy, bomb, watch, and the rest), and colored scenes. Those
pictures are choices. A file name does not select one. The choice is
written as `NAME.ICON`. That file is left as-is afterwards.
`create -reicon` asks again for every program. Keep leaves the current
file unchanged.
Artwork is fitted inside 32×32, centered, converted to
RGB332 and given a one-bit transparency mask (alpha ≥128 is opaque).
Artwork with an existing 32×32 ICO frame uses that frame. Preparing icons
requires Pillow; displaying the native sidecar does not.

## Native disk format (JIC1)

The `.ICN` sidecar is exactly 1,160 bytes:

- Bytes 0–3: ASCII `JIC1`.
- Bytes 4–5: width and height, both 32.
- Byte 6: flags, exactly 1 (transparency mask present).
- Byte 7: reserved, exactly 0.
- Bytes 8–135: 1,024 mask bits, row order, leftmost pixel first in bit 7.
  One means opaque; zero restores the desktop background.
- Bytes 136–1159: 1,024 pixels, row order, one RGB332 byte per pixel.
  Red occupies bits 7–5, green 4–2, blue 1–0. The desktop must use the
  corresponding RGB332 palette when compositing these pixels.

`functional_model/desktop_icons.py` decodes this format and supplies the
generic icon. `StorageEngine.program_icon()` reads from the same mounted
disk as the program. `rtl/engines/jmr_icon_stream.sv` accepts disk bytes
through a valid/ready interface and emits all 1,024 pixels through another
valid/ready interface. It stores only the 128-byte mask in distributed
RAM, with a separate legal RAM process. Artwork is streamed rather than
keeping every disk icon in block RAM.

The disk reader passes the file length on `start`, or zero if missing,
and pulses `src_error` on an I/O failure. Source bytes and output pixels
may stall. Errors restart the output at coordinate zero with the generic
icon, repainting the entire footprint including its transparent pixels.
Callers must paint the desktop background for transparent pixels rather
than skip them. The byte producer stops its current transfer once
`fallback` is raised. A new `start` is accepted only while idle.

## Status and checks

This page is the icon reader. The default shell is the Finder program,
which draws its own icons. The built-in desktop (`PROGRAM_FINDER=0`)
still uses this reader. Which bit is on the board: [FPGA_FIT.md](FPGA_FIT.md).
The QSPI image (run73o) has neither desktop.

`tests/test_desktop_system.py` compares complete desktop pixels and controls
against actual RTL, including Markdown/text filenames and the File, Edit,
View and Special menus. `tests/test_system_menu.py` checks the opaque
Enterprise menu, About, keyboard, held keys and mouse-only Quit against RTL.

Run `.venv/bin/python -m pytest -q tests/test_desktop_icons.py`. Checks
cover real PNG and ICO input, untouched source artwork, FAT disk reads,
hidden sidecars and all 1,024 model/RTL pixels with source/output stalls,
missing files, wrong lengths, invalid headers and a mid-picture I/O fault.
Tests use a temporary card image, never overwrite the project `card.img`,
and compile the actual synthesizable RTL reader with Verilator.

## Hidden files view

The desktop's View → Hidden files toggle reads the complete FAT catalog.
It displays native `.ICN` icons as `.ICON`, binary `.ART` as `.ARTX`, and
source `.ARJ` as `.ARTJS`. These are display suffixes; console commands
continue to use the actual short FAT name. The card builder copies ARTJS
as ARJ so it cannot overwrite the same-stem binary ART file. Ordinary DIR
hides these sidecars; DIR * includes them. Folder README.md files are not
seeded; HELP.MD is the computer's manual.
