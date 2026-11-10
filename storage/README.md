# storage/

The source files for the card. `tools/make_sd_image.py` builds `card.img`
from this folder. This guide is for the PC; it is not copied to the card.
The on-card manual is `HELP.MD`.

```sh
python3 tools/make_sd_image.py create card.img
```

`create` replaces `card.img`, including documents saved on it. Only regular
files directly in this folder are read. Subfolders are ignored, except
`icons/`.

How to write a program: [GAME_DESIGN.md](../docs/GAME_DESIGN.md).

## What goes on the card

| In this folder | On the card | What it is |
|---|---|---|
| `NAME.HTML` | `NAME.HTM` | Program source. |
| — | `NAME.JSH` | The compiled program. `create` compiles it from the HTML. |
| `NAME.JSH` | not copied | A published copy of the compiled program. `create` ignores it. |
| `NAME.ARTX` | `NAME.ART` | Art the machine uses: palette and pixels. |
| `NAME.ARTJS` | `NAME.ARJ` | The same art as a script for a browser preview. The machine does not run it. |
| `NAME-0.png`, `NAME-1.png`, … | not copied | The sheets you edit. `tools/make_artx.py NAME` builds the two art files. |
| `NAME.ICON` and the other icon names | `NAME.ICN` | 32×32 desktop icon. [DESKTOP_ICONS.md](../docs/DESKTOP_ICONS.md) |
| `*.MD`, `*.TXT` | same name | Documents. Finder opens them in the reader. |
| `SYSTEM.SYS` | same | Fonts, captions and dialog layouts. Generated from `resources/system/system.json`. [SYSTEM_RESOURCES.md](../docs/SYSTEM_RESOURCES.md) |
| `TOOLBOX.ROM`, `TOOLBOX.LNK` | same | The resident Toolbox library and its link table. Built by `tools/toolbox_linker.py`. [RESIDENT_TOOLBOX.md](../docs/RESIDENT_TOOLBOX.md) |
| `COMPILE.LNK` | same | Link table the on-machine compiler reads. |
| `PAINT.RSC` | same | MacPaint tables. Built by `tools/build_paint_resources.py`. |
| `JSONRT.JS`, `STRRT.JS`, `BOTHRT.JS`, `LSRT.JS` | same | Library source the on-machine compiler adds to a program. Copies of `functional_model/*_runtime.js`. |
| `README.md` | not copied | This file. |

### Names on the card

The card stores 8.3 names: the first 8 characters of the name and the first
3 of the extension, upper case. `ARTJS` becomes `ARJ` so it cannot collide
with `ART`. Two files that map to the same card name stop the build. Keep
program names to 8 characters.

## Building options

| Option | Effect |
|---|---|
| `-nojsh` | Leaves each program's `.JSH` off the card, so the machine must compile it. The compiler programs are still compiled. |
| `-soundoff` | Compiles every `sound()` call to a no-op. |
| `-reicon` | Asks for an icon for every program again. |
| `--size 64M` | Image size. 64 MiB is the default. |

`python3 tools/make_sd_image.py list card.img` lists the card.
`burn /dev/sdX --keep-image` writes the existing `card.img` to a microSD
card.

## Programs that must stay

Finder and the system start these by name. Removing one breaks that
function.

| File | Role |
|---|---|
| `FINDER.HTML` | The desktop. It starts at power-on. |
| `EDITOR.HTML` | Text editor for the SOURCE document. |
| `READ.HTML` | Reader for `.MD` and `.TXT`. |
| `NOTE.HTML` | Opens a new untitled document in the editor. |
| `UTILITY.HTML` | Card catalogue. |
| `COMPILE.HTML` | The Compile window. |
| `ARTSCAN.HTML`, `COMPILER.HTML`, `COMPIL2.HTML` | The compiler stages. |
| `HELP.MD` | The manual Finder opens from Special → Help. |

## Examples to copy

| File | Shows |
|---|---|
| `BOXES.HTML` | The smallest game. |
| `MENUEX.HTML` | A menu command. |
| `GUIDEX.HTML` | A program in a window. |
| `UIMAN.HTML`, `UISESS.HTML` | The two ways to use Toolbox menus and dialogs. [SYSTEM_APPLICATIONS.md](../docs/SYSTEM_APPLICATIONS.md#two-ways-to-use-the-ui) |
| `JOYDEMO.HTML` | Stick and keys. |
| `SNDDEMO.HTML` | Sound effects. |
| `GRAPHICS.HTML`, `DAMAGE.HTML`, `COPYDEMO.HTML` | Toolbox drawing and bitmap copies. [TOOLBOX_USAGE.md](../docs/TOOLBOX_USAGE.md) |
