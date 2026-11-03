# Desktop reference assets

`chicago-12.json` is the original Macintosh Chicago bitmap font extracted
from the local System file by `Macintosh/scripts/extract_menu_font.py`.
`mac-arrow.json` is the original arrow's data, mask and hotspot from the
same Macintosh project. These archival Apple assets retain their original
rights; no new license is asserted over them.

The monitor draws the bitmaps at native size. `vectors/desktop_font.hex`
and `vectors/desktop_advance.hex` hold the ASCII glyph rows and advances
used by the synthesizable renderer. Program icons come from the card;
see `docs/DESKTOP_ICONS.md`.

`enterprise.webp` is the user's supplied ship reference. `enterprise-menu.json`
compiles only its ship silhouette (without lettering) into the 28×8 native
menu bitmap. The PYTHON and RTL renderers use the same bits.

`chicago-reader.png` packs the same original glyphs in black and blue for
the Markdown reader. `tools/export_reader_font.py` rebuilds the sprite and
its embedded READ.HTML data. It uses external sprite memory, not more BRAM.
