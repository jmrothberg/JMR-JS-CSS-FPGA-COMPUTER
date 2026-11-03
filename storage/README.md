# storage/

This folder is the seed for the µSD card. It is a folder guide for the PC.
It is not the manual, and it is not copied onto the card.

`HELP.MD` is the manual. On the machine, `LOAD "HELP.MD"` then `READ`.
That file tells you how to play, edit, compile, and read documents. This
file tells you which host files become which card files, and which ones
must stay in this folder.

The shared Mac-style menus are installed in the main `gui_jmr_js.py` and
`card.img` for **Python and real RTL testing**. Launch the GUI normally. All 19 games/demos
now use File → Quit, application-specific About text headed JMR Enterprises,
and the shared mouse keyboard. Simpler programs have Game → Restart. The system
viewport keeps their entire existing picture and maps mouse coordinates back
into the game. No additional sprite images were added. `2DFANTA2.HTML`
(Fantasy Chess) and `DNKF.HTML` (Donkey Kong) use the shared application menus;
`MENUEX.HTML` is the small working conversion example. The common API and agent
porting instructions are in [SYSTEM_APPLICATIONS.md](../docs/SYSTEM_APPLICATIONS.md),
also `MENUS.MD` on the updated disk. The previous disk and rollback instructions
are under `build/system_tools/`. The normal GUI starts in Python; F9 selects the updated native RTL.
The board-tested bitstream is preserved while the new run74 hardware build
is qualified. See `../build/rtl_system_parity/README.md` for checks. `../run_python_system_preview.sh`
still provides an optional separate disk for isolated Python tests.

Words: [README.md — Words used](../README.md#words-used-in-this-project).

## What the card builder copies

```text
python3 tools/make_sd_image.py create card.img
```

Only regular files directly in this folder are seeds. `older versions/`
and other subfolders stay off the card. `README.md` stays off the card.
`HELP.MD` goes on.

The builder mints a `.JSH` for each `.HTML`. PYTHON, FPGA-SIM, and the
board `LOAD` / `RUN` that image. Do not keep `.JSH` files here; a host
copy would be stale. PNG sheets stay on the host. `make_artx.py` turns
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
the built-in set: text, computer, folder, disk, trash, printer, case,
the generic window, and the colored pictures (asteroids, Pac-Man,
missiles, tank, ship, ball, star). The choice is saved as `NAME.ICON`. Nothing in the
picker looks at the file name.

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
