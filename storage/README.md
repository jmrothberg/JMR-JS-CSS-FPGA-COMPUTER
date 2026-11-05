# storage/

Finder files for an already-burned card: [releases/updates](../releases/updates/README.md).
Which bitstream to load: [FPGA_FIT.md](../docs/FPGA_FIT.md).
Jacks: [USB_KEYBOARD_PMOD_MICE.md](../docs/USB_KEYBOARD_PMOD_MICE.md).

`SYSTEM.SYS` contains shared native fonts, menu/dialog captions and dialog
layout resources. Generate it from `resources/system/system.json`; do not edit
the binary. [How to edit and publish it](../docs/SYSTEM_RESOURCES.md). Reopen
the simulator after publishing. No `.bit` build is needed for resource edits.

This folder is the seed for the µSD card. It is a folder guide for the PC.
It is not the manual, and it is not copied onto the card.

`HELP.MD` is the manual. On the machine, `LOAD "HELP.MD"` then `READ`.
That file tells you how to play, edit, compile, and read documents. This
file tells you which host files become which card files, and which ones
must stay in this folder.

The GUI starts in Python and opens the Finder program. F9 selects FPGA-SIM.
Games use File → Quit. `MENUEX.HTML` is the small game example and
`GUIDEX.HTML` is the window example. The shared API is
[SYSTEM_APPLICATIONS.md](../docs/SYSTEM_APPLICATIONS.md), also `MENUS.MD`
on the card. The flashed board bit is still run73o
([releases/current](../releases/current/README.md)); it does not contain
this Finder. The older desktop snapshot is
[to_delete/builtin-finder-2026-11-03](../to_delete/builtin-finder-2026-11-03/README.md).

Words: [README.md — Words used](../docs/WORDS.md#words-used-in-this-project).

## What the card builder copies

```text
python3 tools/make_sd_image.py create card.img
```

Only regular files directly in this folder are seeds. `older versions/`
and other subfolders stay off the card. `README.md` stays off the card.
`HELP.MD` goes on.

The builder mints a `.JSH` for each `.HTML`. PYTHON, FPGA-SIM, and the
board `LOAD` / `RUN` that image. Do not keep `.JSH` files here; a host
copy would be stale. `FINDER.JSH` is the exception: it is the sidecar to
copy onto a card that is already burned. `create` still mints from
`FINDER.HTML` and does not copy this file. The same bytes are in
`releases/updates/`. PNG sheets stay on the host. `make_artx.py` turns
them into the two art files below.

`--nojsh` leaves title `.JSH` files off so the machine can prove `COMPILE`.
The compiler chain is still minted. Those programs are what does the
compiling.

## Names on the card

The card stores 8.3 names. The desktop's Hidden files view shows the long
names. Console commands use the short name.

| In this folder | On the card | Who uses it |
|---|---|---|
| `NAME.HTML` | `NAME.HTM` | `LOAD`. Source. Must stay under 65,536 bytes |
| minted, not stored here | `NAME.JSH` | `RUN`. Bytecode plus packed pictures |
| `NAME.ARTX` | `NAME.ART` | `COMPILE` and `RUN`. The picture bank |
| `NAME.ARTJS` | `NAME.ARJ` | Chrome on the PC. Kept so Hidden files can show it. The machine does not run it |
| `NAME.ICON` and the other icon suffixes | `NAME.ICN` | Desktop icon, 32×32 |
| `HELP.MD`, other `.MD`, `.TXT` | same short name | `READ`, and the document window |

`ARTJS` is stored as `ARJ` so it cannot overwrite the binary `ART` file
for the same stem. `DIR` hides `.JSH`, `.ART`, `.ARJ`, and `.ICN`.
`DIR *` lists the short names. Hidden files shows `.ARTJS`, `.ARTX`, and
`.ICON`.

## Pictures

`NAME-0.png`, `NAME-1.png`, and the rest are the sheets you edit. Do not
write `.ARTX` or `.ARTJS` by hand. `python3 tools/make_artx.py NAME` builds
both from those sheets and wires the Chrome hook. Rebuild the card after
a PNG change.

The HTML points at a sheet with `"jmr:spr:N"`. A title that uses `jmr:spr`
and has no `.ART` beside it fails with a missing-art message. Tags marked
`data-host="chrome"` are for opening the same HTML in a browser. The mint
strips them. The plain reason for two art files is in `HELP.MD`.

## Icons

Give an icon the same stem as its program: `PACFAST.ICO` beside
`PACFAST.HTML`. In this folder the builder accepts `NAME.ICO`,
`NAME.ICONS`, `NAME.ICON`, `NAME.ICON.PNG`, and `NAME.ICON.ICO`.
`storage/icons/NAME.PNG` is also art. A root `NAME.PNG` is a sprite sheet,
not an icon.

The builder fits the picture in 32×32, keeps the transparency mask, and
writes `NAME.ICN`. It does not change the original file. A markdown file
with no icon yet gets the text document. A chosen `NAME.ICON` is kept.

`python3 tools/pick_icon.py` asks when a title has no icon. A title with
an `.ARTX` offers pieces of that sheet. A title with no picture offers
the built-in set: line art, the color Macintosh sheet, and colored
scenes. The choice is saved as `NAME.ICON`. Nothing in the picker looks
at the file name. `python3 tools/make_sd_image.py create card.img -reicon`
asks again for every program. Keep leaves the current file.

## Programs that must stay here

`READ.HTML`, `EDITOR.HTML`, `ARTSCAN.HTML`, and `COMPILER.HTML` are the
programs behind the verbs `READ`, `EDIT`, and `COMPILE`. `DIR` hides those
stems. Removing the HTML from this folder, or leaving the minted `.JSH`
off the card, breaks the verb.

`EDIT` chain-loads `EDITOR.JSH` against the file `LOAD` parked. It is not
`LOAD` plus `RUN`. `NOTE.HTML` is an ordinary title for typing a draft.
`DIR` shows it. How to use each one is in `HELP.MD`.

Detail: [GAME_DESIGN.md — machine programs](../docs/GAME_DESIGN.md#machine-programs-in-storage--do-not-delete).

## Older copies

`older versions/` is not loaded. `DNKFAST` is the old inline-art Donkey;
the current file is `DNKF`. `DOOMOLD` is the sprite blit that smears on
the FPGA; the current file is `DOOM3DFI`.

The READY verbs, in the long form:
[JS_COMMANDS.md — READY console](../docs/JS_COMMANDS.md#ready-console-not-javascript).

### Toolbox development sources

Current `MACPAINT.HTML` uses native Toolbox bulk copy for Undo. Pair a newly
minted copy with the current simulator or a future matching FPGA build;
run75/run76 do not implement this native. The matching development disk and
launch instructions are in `build/toolbox_development/README.md`.
`UTILITY.HTML` now calls the shared fsList service itself; its old UTL catalog
header supplied by dedicated hardware is retired. `COMPILER.HTML` recognizes
the Toolbox native. See `docs/TOOLBOX_API.md` for application examples.

Toolbox additions: `TOOLBOX.ROM` is the shared native-JavaScript instruction
library; `TBDEMO.HTML` demonstrates its software File menus and dialogs.
These require the matched run77 runtime/bit. See docs/RESIDENT_TOOLBOX.md before
editing or compiling resident clients. Rebuild the ROM and all linked clients
together when changing library code. SYSTEM.SYS remains appearance data.
