# Program icons

Finder shows a 32×32 icon for each file. The icon is a separate file on the
card with the same name stem: `NAME.HTM` and `NAME.JSH` use `NAME.ICN`.
A file with no icon, or a bad one, gets Finder's generic icon. There is no
list of program names anywhere.

## Supplying artwork

Put the artwork in `storage/`. `python3 tools/make_sd_image.py create card.img`
converts it to `NAME.ICN` on the card and leaves the source file unchanged.

For each program the builder tries these files in order and uses the first
that converts:

| Order | Location | File |
|---|---|---|
| 1–6 | `storage/` | `NAME.ICN`, `NAME.ICO`, `NAME.ICONS`, `NAME.ICON`, `NAME.ICON.PNG`, `NAME.ICON.ICO` |
| 7–13 | `storage/icons/` | the same six, then `NAME.PNG` |

- `NAME` is the full host stem. `LONGTITLE.ICO` beside `LONGTITLE.HTML`
  becomes `LONGTITL.ICN` beside `LONGTITL.HTM`.
- The suffix does not select a decoder. The content must be the native
  format below or any image Pillow can open, such as PNG or ICO.
- A plain `NAME.PNG` in `storage/` is ignored, so game sprites are never
  taken for icons.
- An ICO that contains a 32×32 frame uses that frame. Other artwork is
  scaled to fit 32×32 and centred. Colours become RGB332. Alpha ≥ 128 is
  opaque.
- A candidate that fails prints a note and the next one is tried.

Converting needs Pillow. The machine needs nothing but the `.ICN` file.

### The picker

When a program has no artwork and a display is attached, `create` opens
`tools/pick_icon.py`. It offers sprites cut from the program's `.ARTX`, or a
built-in set when the program has no pictures. The choice is saved as
`storage/NAME.ICON` and kept from then on. Markdown files are offered too; an
unchosen one gets the text-document icon.

`create -reicon` asks again for every program. Keep leaves a file as it is.

## File format (JIC1)

`NAME.ICN` is exactly 1160 bytes.

| Bytes | Content |
|---|---|
| 0–3 | `JIC1` |
| 4, 5 | width 32, height 32 |
| 6 | flags, 1 (mask present) |
| 7 | 0 |
| 8–135 | Mask: 1024 bits in row order, left pixel in bit 7. 1 = opaque, 0 = show the desktop |
| 136–1159 | Pixels: 1024 bytes in row order, RGB332 (red bits 7–5, green 4–2, blue 1–0) |

`functional_model/desktop_icons.py` encodes and decodes this format.
`storage/FINDER.HTML` reads the file with `fsRead` and checks the length and
the `JIC1` signature.

## Hidden files

Icon and picture sidecar files (`.ICN`, `.ART`, and `.ARJ`, the card name
of `NAME.ARTJS`) are hidden in Finder until View → Hidden files is checked.
