# SYSTEM.SYS: the system font and captions

`SYSTEM.SYS` is a data file on the card. It holds the system font, the boot
screen captions and the on-screen keyboard legends. It is not code. The
machine reads it once at cold start.

Its source is `resources/system/system.json`. Do not edit the binary.

## Change it

```sh
python3 tools/build_system_resources.py --image card.img
```

This packs `system.json`, writes `storage/SYSTEM.SYS`, and replaces only
`SYSTEM.SYS` inside `card.img`. Other files on the image are untouched.
Restart `gui_jmr_js.py` (or power-cycle the board) to load it. No simulator
or FPGA build is needed.

| Option | Meaning |
|---|---|
| first argument | Source JSON. Default `resources/system/system.json` |
| `--output PATH` | Where to write the file. Default `storage/SYSTEM.SYS` |
| `--image PATH` | Also replace `SYSTEM.SYS` in this card image |

`python3 tools/make_sd_image.py create card.img` copies `storage/SYSTEM.SYS`
onto a new card image.

To go back, rebuild from the previous JSON. `resources/system/defaults.json`
is the source of the fallback built into the hardware; leave it alone.

The Icon Editor (`ICONEDIT`) patches the bomb and caution icons in the card's
`SYSTEM.SYS` directly; `system.json` is not updated.

## What it changes on screen

| Data | Shown where |
|---|---|
| Font glyph shapes | Menu bar, window titles and dialogs drawn by the Toolbox; boot screen text; keyboard legends; ship-menu labels |
| Labels 160, 170, 171 | Boot screen: `JMR Enterprises`, `NCC-1701`, `Welcome` |

The text of menus and dialogs is not in this file. It is in the programs and
in `resources/toolbox/session.js` and `ui.js`. The other labels and the
dialog fields in `system.json` are still required and checked by the packer
and are written into the file, but the machine has no native menu or dialog
that displays them.

Without a valid `SYSTEM.SYS` the boot screen and keyboard use built-in data,
but the Toolbox has no font: `tbUIInit` fails and the menu bar shows
`SYSTEM.SYS UI font unavailable`.

## Source fields

| Field | Rule |
|---|---|
| `format` | 1 |
| `font` | Path to a glyph JSON file, relative to the source file |
| `glyph_overrides` | Per-character replacements. A glyph has `offset` (0–15), `advance`, and up to 16 `rows` of `0`/`1` characters. `offset` plus row length ≤ 16 |
| `labels` | ID 0–255 → printable ASCII, at most 127 characters and 600 pixels each, 2048 characters in total |
| `dialog_offsets` | `open`, `save_as`, `changes`, `replace`, `message`: `[x, y]` with x −60…60, y −40…16 |
| `dialog_buttons` | Three `[x, y, width]` slots per dialog. Unused slots are `[0,0,0]`. Buttons must hold their caption, stay inside the dialog, and not overlap |
| `rounded_buttons`, `default_button_outline` | true or false |
| `icons` | Optional. `bomb` and `caution`: 32 rows of 32 `0`/`1` characters. Finder draws them in its alerts |

Every printable character must keep the advance width it has in
`assets/desktop/chicago-12.json`. You can change glyph shapes, not spacing or
size.

Labels 110–114 are the headings File, Edit, View, Special, Game: 1–12
characters each. Labels 123, 142–147, 149 and 165 have pixel-width limits the
packer enforces.

## Loading

At cold start the machine opens `SYSTEM.SYS`, checks the header, length and
CRC-32, and only then copies the data to the display memories. A missing or
rejected file leaves the built-in data in place. Nothing is read from the
card after boot.

The verified payload stays in memory for programs to read with
`toolbox(5, offset, destination, length)`
([TOOLBOX_API.md](TOOLBOX_API.md#operation-5-systemsys-bytes)).

In the FPGA simulator, the command `SYS?` reports 0 pending, 1 loaded,
2 file unavailable, 3 rejected.

## Binary format

All fields little-endian unless stated. The file is exactly 24336 bytes.

Header, 16 bytes:

| Bytes | Field |
|---|---|
| 0–3 | `JMRS` |
| 4–5 | version 1 |
| 6–7 | header length 16 |
| 8–11 | payload length 24320 |
| 12–15 | CRC-32 of the payload (zlib) |

Payload, by byte offset:

| Offset | Size | Content |
|---|---|---|
| 0 | 4096 | Font: 128 glyphs × 16 rows, u16 each, bit 15 is the left pixel |
| 4096 | 4096 | 2048 label character records, u16: ASCII in bits 6–0, advance in bits 10–7 |
| 8192 | 1024 | 256 label indexes, u32: first record in bits 10–0, length in bits 17–11, pixel width in bits 27–18 |
| 9216 | 80 | Five menu headings, 16 bytes each, NUL padded |
| 9344 | 114 | Five dialog offsets (i16 x, y); u16 rounded flag; u16 outline flag; fifteen button triples (u16 x, y, width) |
| 9472 | 10240 | Keyboard legend bitmaps: 16 rows of 5 bytes per legend |
| 19712 | 512 | Ship-menu label bitmaps (Keyboard, X, Hold keys, About): 16 rows of u64 each |
| 20224 | 384 | Label bitmaps for Note, Help, Utility: 16 rows of u64 each |
| 20608 | 16 | UI font header `TBF1`: u8 schema 1, u8 first code 32, u8 count 95, u8 height 16, u16 glyph offset 20736, u16 glyph stride 32, u16 width offset 20624, u16 0 |
| 20624 | 95 | UI font advance widths, one byte per character 32–126 |
| 20736 | 3040 | UI font glyphs: 95 × 16 rows, u16 **big-endian**, bit 15 is the left pixel |
| 23776 | 256 | Alert icons: bomb, then caution. 32 rows of 4 bytes each, bit 7 of the first byte is the left pixel |

Unlisted bytes are zero.

The Toolbox reads the `TBF1` block. `tbUIInit` checks its first 8 bytes and
then uses the fixed offsets above.
