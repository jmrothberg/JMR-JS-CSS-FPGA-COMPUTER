# RTL work to match the Python desktop

Implementation note (November 3): the changes below are now in RTL and the
normal FPGA-SIM executable has been rebuilt. Centered captions and variable
selection bars pass the exact-pixel desktop test, including hidden suffixes.
Compile lifecycle verification also passed. The log from that check is
`to_delete/run74n_python_parity/parity_test.log`. The simulator you run
now is `sim/sim_build_synth`.

The new Compile launcher uses the native role-3 About panel. Its custom
`systemAbout` assignment failed on both the board-trial M simulator and the
updated simulator, so that redundant assignment was removed from the launcher.
`card.img` has the matching COMPILE.HTM/JSH; other card files are unchanged.
Native actions also release the old Finder launch so the completion results
stay visible as in Python. An idle Compile launcher closes immediately; an
active compile still finishes its write before closing.
The owner-tested M bit remains preserved. The requirements below describe the
requested changes from M, not additional unfinished edits.

Python is the glass to copy. The changes are already in
`functional_model/desktop.py`, `functional_model/classic_ui.py`, and
`runtime/backend.py`. This file is the RTL list. Do these three things
and nothing else.

`card.img` already contains `COMPILE.HTM`, `COMPILE.JSH`, and `COMPILE.ICN`.
`storage/COMPILE.HTML` is the program (`ctx.systemWindow=3`).
`COMPILER.HTML` stays the hidden engine. Do not strip `COMPILE.HTM`, and
do not add `COMPILE` to the system-stem hide list.

The USB card was not burned. After the RTL matches, Jonathan burns it with:

```bash
sudo python3 tools/make_sd_image.py burn /dev/sdb --keep-image
```

That writes the existing `card.img` to the USB card at `/dev/sdb` (the
31 MB JMR volume). It does not touch the internal disk.

Prove the glass in FPGA-SIM before a bitstream. The bit is the existing
board flow, only after that sim matches. A wrong bit costs many hours.

`tests/test_desktop_system.py` `test_native_desktop_pixels_controls_and_launch`
compares Python pixels to RTL. It passes when RTL matches the positions
below. Do not weaken the test.

Legal SRAM stays in force. Walk a catalog name one byte per clock.
Store the width in a register. Do not read the catalog from a
combinational pixel function, and do not add another heap.

## 1. Center Disk, Trash, and icon-view names

Font: `classic_advance` in `rtl/engines/jmr_classic_ui_pkg.sv`.
Width is the sum of advances of the characters actually drawn.
Left edge is `center - width/2`, integer division, same as Python
`text_width // 2`.

Pictures do not move. Disk and Trash both center on x=596.

| Caption | RTL today (`jmr_desktop_layout_pkg.sv` `caption_x`) | Target |
|---|---|---|
| Disk, cap 5 | 572 | 583 (width 27) |
| Trash, cap 6 | 575 | 579 (width 35) |

Y stays 86 for Disk and 449 for Trash.

Icon-view names, caps 14–28, are currently `wx+12+column*102`.
Center them on the 32 px icon. The icon origin is already
`wx+38+column*102` in `jmr_desktop.sv`. The center is `wx+54+column*102`.
Y stays `wy+98+row*86`.

The drawn label is the one `CHAR_WAIT` already produces:

- A program (`.HTM` / `.HTML` / `.JS`) stops at the dot, so `COMPILE.HTM`
  draws `COMPILE`.
- A document keeps its suffix. `.ARJ` draws `.ARTJS`, `.ART` draws
  `.ARTX`, `.ICN` draws `.ICON` (`label_suffix` in `CHAR_WAIT`).

Measure that drawn string. List view stays `wx+28`. Menu words,
the window title, and the dialog do not move.

`caption_x` is chosen before the name is read. The width has to be
ready in a register first: walk the same characters `CHAR_WAIT` draws,
add `classic_advance` once per clock, then set `text_x`.

## 2. Size the icon-view selection bar to that label

`desktop_base` in `jmr_desktop_layout_pkg.sv` paints a fixed bar:
x from `10+column*102` to `98+column*102` (88 px), y from
`97+row*86` to `115+row*86`.

Icon view becomes: left `center - width/2 - 3`, width `text_width+6`,
height 18, same y (`wy+97+row*86`). `center` is `wx+54+column*102`.
Use the width from step 1. The bar is painted during scanout, so the
width must already be registered. Do not look up the name inside
`desktop_base`.

List view stays x `wx+24`, width 490, height 18.

## 3. Make Compile a desktop program, the way Editor opens Note

### Open Compile from the Finder

`jmr_desktop.sv` Special, row 3, only compiles when a file is selected:

```systemverilog
3:if(selected<catalog_count_q)pending_action<=A_COMPILE;
```

When nothing is selected, do what Editor does for Note: `A_OPEN` of a
built-in name. `A_OPEN` already sends `LOAD "NAME"` and then `RUN`.

`system_file` is 2 bits and all four values are used (0 unused as a
name, 1 `HELP.MD`, 2 `UTILITY.HTM`, 3 `NOTE.HTM` in `system_name`).
Widen it and add id 4 = `COMPILE.HTM` (11 bytes, inside the existing
`name_i<12` walk). Nothing-selected Compile uses that id.

File → Compile on the icon `COMPILE.HTM` is also `RUN`, not `COMPILE`.
The name is known one byte per clock in `CMD_NAME_WAIT`. If the action
is `A_COMPILE` and those bytes are `COMPILE.HTM`, change the action to
`A_OPEN` before the second command (`follow_char`). The first command
stays `LOAD`. Any other selected HTML still gets `LOAD` then `COMPILE`.

Double-click is already `A_OPEN`. Leave it.

### File → Open inside the Compiler window

The Compiler window is role 3. Open is grey. Enable it in both places
in `rtl/engines/jmr_classic_ui.sv`:

- `click_enabled`, menu 0, row 1 (about line 152)
- `popup_enabled_rows`, menu 0, row 1 (about line 171)

Today row 1 is enabled for an editable document or role 2. Add role 3.
New, Save, and Save As stay editable-only. Special stays disabled for
role 3 (`menu_kind==3` already requires `role!=3`).

The Open list is built in `rtl/engines/jmr_system_documents.sv` around
the `keep` expression (about line 188). Role 2 keeps `.MD` and `.TXT`.
Role 3 keeps `.HTM` only (`tail==32'h2e48544d`) and drops the name
`COMPILE.HTM`. Editor and Note keep `.MD`, `.TXT`, `.HTM`, and `.JS`.

Choosing a file is action 14 in `rtl/engines/jmr_system_actions.sv`.
After `LOAD`, role 1 and role 5 start the editor, and every other role
sends `READ` (`command_mode<=2` in `FINISH`). Role 3 sends `COMPILE`
instead (`command_mode<=4`, the existing `word_char` default).
`command_mode==4` already stays off the Finder. Do not set
`return_desktop` for that path.

## Leave alone

- Game menus. Special → Restart still says Restart.
- No title tests (`if (stem==...)` for a game). The `COMPILE.HTM` name
  check above is the tool launching itself.
- Host chrome in `gui_jmr_js.py` (the runtime line, the F-key footer).
- `COMPILER.HTML`, `EDITOR.HTML`, and `ARTSCAN.HTML`. They stay hidden
  engines.

## Next build — menu highlight

Python now matches a Mac menu. While a menu is open, its title in the
menu bar is a black bar with white Chicago text, and the item under the
pointer is the same. Moving the pointer moves that bar. A disabled item
stays grey and does not invert. The click still runs the same item.
Nothing is highlighted until a menu is open.

Finder is `functional_model/desktop.py`. The title bar is `menu_x`,
y 0, height 21, width 50 (Special is 74). The item bar is `menu_x+2`,
`26+row*21`, 154 by 20. The row is `(mouse_y-26)/21` while the pointer
is inside that menu and `y>=26`. Otherwise no item is inverted, and the
open title stays inverted.

In-app menus are `functional_model/classic_ui.py`. The title cell is the
same width the bar already uses (Chicago advance plus 20). The item bar
is `popup_left+2`, `26+row*21`, 208 by 20, and only when that row is
enabled.

The ship menu is `functional_model/system_menu.py`. About is the row
`26<=y<47`. Keyboard is `47<=y<68`. The bar is x 1..188.

RTL still paints every menu item black on white.
`rtl/engines/jmr_desktop.sv` sets `text_colour` to 0 for menu titles and
menu items (`event_menu_row` is the click, not the pointer).
`rtl/engines/jmr_desktop_layout_pkg.sv` `desktop_base` fills the open
menu white and does not paint a title bar or an item bar.
`rtl/video/jmr_classic_overlay.sv` keeps titles black on the white bar;
enabled items are black and disabled items are `24'h919191`.
`rtl/video/jmr_system_overlay.sv` paints About and Keyboard black on
white whenever `menu_open` is set. The overlay already sees the pixel
`x,y`. It also needs the pointer while the menu is open. Do this in
FPGA-SIM until the pixels match, then the next `.bit`.

## Next build — list order and Trash

Python Finder, in `functional_model/desktop.py`:

- View → List sorts the visible names A to Z (`name.upper()`).
  View → Icons stays in disk order. A selected name stays selected
  across the switch.
- Drag a name onto the Trash picture (x 570..625, y ≥ 404). The file
  stays on the disk and disappears from the window.
- Click Trash to show only those held names. Drag one onto the Disk
  picture (x 570..625, y 40..104) to put it back. Click Disk to leave
  the Trash window.
- When Trash holds at least one name, Special gains `Empty Trash` as
  its last item. Confirming it sends `REMOVE` for each held name.
  An empty Trash does not add the item, so the idle Special menu
  still matches the current RTL.
- File → Delete... is unchanged.

`tests/test_desktop_system.py` compares list-view pixels with the RTL
desktop. Alphabetical order changes those pixels. Match the sort before
calling that test green. Dragging and Empty Trash are new pointer
behavior in the same file. The reader change is not RTL: it is
`storage/READ.HTML`, and it reaches the machine when the card is minted.

## Finder program — RTL implementation ready for owner comparison

The former deliberate faults at native IDs 58–63 have been replaced by the
file-service handshake. The default RTL boots FINDER.JSH, returns there after
apps exit, and supports role 9's four menus, enable/check masks and highlights.
The built-in desktop remains available through PROGRAM_FINDER=0; a pre-change
source ZIP and simulator are saved in to_delete/builtin-finder-2026-11-03.

See [lastrun_ARCHITECTURE.md](lastrun_ARCHITECTURE.md).
The owner will do functional testing/comparison. No .bit build was started;
resource use and post-route timing have not been measured for this architecture.
Earlier pixel tests in this document describe the built-in desktop, not the
new JavaScript Finder, and are not proof of this revision's behavior.
