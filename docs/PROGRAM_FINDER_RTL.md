# Program Finder: RTL handoff — November 3, 2026

The default RTL now boots `FINDER.JSH` from the disk. Finder owns the desktop,
windows, icons, sorting, folders, Trash and `DESKTOP.FDR`. These features can
change by updating the disk program. The shared menu bar, input, file services,
program loader and drawing primitives remain in the system.

Status: simulator boot, painted desktop, File menu, Terminal launch and cached
Finder return have passed. The captured desktop matches the Python reference pixel-for-pixel. All 73,728
parked arena bytes matched their packed RAM copy; restored file slots, windows,
ordering, comments and icon-cache regions matched after return. Four artwork
bounds tests passed, and both Finder build options passed RTL elaboration.
Owner testing of the remaining applications and file operations is still required. No bitstream build, flashing, game benchmark or physical-card
write was performed for this change. FPGA resource savings and timing are not
measured yet. The VM divider, raster engine and board input wiring are unchanged.

## Try it

Close and reopen `gui_jmr_js.py`, then select FPGA-SIM with F9. This uses
`sim/sim_build_synth/jmr_js_sim_server`. PYTHON still uses its existing backend.
Startup shows a graphical “Starting Finder...” panel while the disk program loads.
The current `card.img` already contains the matching `FINDER.JSH`; this change
does not rewrite the disk. Unlike Python's live source preference, RTL executes
the minted JSH: editing `storage/FINDER.HTML` alone cannot change FPGA-SIM.
Use the normal card publishing workflow after subsequent Finder source changes.

The checked Finder executable is 145,424 bytes, with 79,112 bytes of code and
trailers (fits the existing program memory). Its remaining bytes include artwork.
A missing or failed Finder leaves the console available rather than repeatedly
relaunching a failed program. Boot requires the normal SD image and system JSHs.

Owner comparison: boot, four menus and disabled/checkmarked commands; open a
game and Quit/Escape back; Reader/Editor/Note/Utility/Compile; then rename,
duplicate, Trash/restore and save/reload desktop positions on a disposable copy
of the disk image. These are suggested checks, not claimed passing results.

## Generic hooks for future programs

The existing native IDs 58–63 now cross a request/reply handshake into
`rtl/engines/jmr_finder_fs.sv`. Programs use the same functions as Python:

- `fsList()` writes raw root-file records at arena byte 256 and returns count.
  Header 240: used bytes u32, available bytes u32 (currently zero), count u16.
  Each record: name length u8, name bytes, size u32, DOS date u16, attributes u8.
  All multibyte numbers are little endian; a zero name length ends the list.
- `fsRead(nameOffset, fileOffset, destinationOffset, count)` returns bytes read.
  Reads stop at EOF. Seeking skips bytes sequentially through the existing engine.
- `fsWrite(nameOffset, sourceOffset, count, mode)` returns bytes written.
  Mode 1 appends; other modes replace. Append walks the FAT chain and reads only
  the partial final sector; it does not copy the whole file into another buffer.
- `fsRemove(nameOffset)` returns zero, including an already absent file.
- `fsRename(oldOffset, newOffset)` replaces the destination and renames the root
  entry without copying file data. Like the existing filesystem, it is not a
  transaction protected against power loss.
- `sysRun(nameOffset, how)` ends the current program. 0 runs HTM/JS or reads a
  document; 1 edits; 2 reads; 3 loads the selected source and starts COMPILE.JSH;
  4 enters Terminal; 5 Note; 6 Help; 7 Utility; 8 Finder. An empty name returns home.

Names are NUL-terminated uppercase FAT 8.3 bytes in the existing compile arena;
lowercase ASCII is normalized. Bad names, bounds or storage failures return -1.
There are no FAT subdirectories: Finder's folders are metadata in DESKTOP.FDR.
The services share the existing sector buffer, WORK port and SRAM arena. No
second file-sized buffer, JS heap or framebuffer was introduced. Do not keep
assets in the arena across app launches: it is shared scratch memory. The system
explicitly parks and restores this Finder’s arena as described below; other
programs do not receive that guarantee.

## Menus and drawing

`ctx.systemWindow=9` gives a desktop program the canvas below the shared menu
bar, without the normal single-window frame. Use `ctx.systemMenus` with exactly
`File`, `Edit`, `View`, `Special`, in that order: up to 12 items in each menu,
32 total unique command codes 160–191, and the existing 512-byte descriptor cap.
Labels retain the 24-character cap. Commands arrive through the existing key
callback. Other roles retain their established three custom menus/eight items.

`ctx.systemMenuEnable` and `ctx.systemMenuCheck` are 32-bit masks: bit zero is
command 160. Disabled commands cannot fire. Checkmarks, active headings and
hovered rows are drawn by the shared overlay. `ctx.systemAbout` still supplies
application About text. Use SYSTEM_APPLICATIONS.md for application conventions.

The 1,024-word menu text RAM is reused, not enlarged: in role 9 its first 256
records hold bar/About/dialog text; the remaining 768 hold 32 x 24-character
items. Fixed system labels use the existing label ROM. Menu mask expansion
walks one command at a time rather than adding twelve parallel RAM read ports.
The old desktop renderer is excluded by a constant generate selection. The
shared disk catalog remains for existing Open/Save/Utility services.

## Resident Finder within 8 MB

The physical memory aperture stays at 8 MiB. A 256 KiB reservation immediately
below the existing framebuffer replaces the top of the artwork area:

- 160 KiB holds the packed Finder executable, loaded once from disk.
- 72 KiB holds its 73,728 arena bytes, packed two per physical RAM word.
- 24 KiB stages the validated SYSTEM.SYS resource payload before UI RAM commit.

Returning from an application replays the executable from RAM and restores the
Finder arena, including file slots, windows, ordering, comments and icon cache.
The JavaScript globals/functions are reconstructed in the existing single VM;
this is not a second VM or a complete suspended JS heap. The preserved init flag
skips Finder’s cold initialization, and a dirty flag requests repainting. Drawing
still takes time. Terminal launch also parks Finder. Explicit Finder restart
(mode 8) discards parked state. Restart the simulator after publishing a changed
FINDER.JSH so the cached executable is replaced.

The artwork ceiling is now 6,893,568 bytes. All current disk program assets fit;
the largest checked executable is about 2.8 MB. Compiler/art loaders reject data
that would overwrite this reservation. Framebuffer, source, scratch and other
existing regions retain their addresses. No extra BRAM framebuffer or heap was
added, and no game clock divider was changed. Synthesis utilization and timing
remain unmeasured until the next authorized board build.

The shared RTL canvas now honors the optional fifth indexed-colour argument to
`ctx.fillRect`, matching Python. Four-argument fillRect retains its fillStyle
behavior. The simulator refreshes the palette when the system-window role changes;
otherwise it could retain the pre-Finder palette and display the wrong colours.

## Updatable toolbox direction

The useful Macintosh pattern is a shared drawing/menu/dialog toolbox plus disk
applications. Apple’s original QuickDraw sources are described by the
[Computer History Museum](https://computerhistory.org/blog/macpaint-and-quickdraw-source-code/).
This project retains its own implementation; no Apple source was incorporated.

Finder layout and behavior are disk-updatable JavaScript. The shared RTL now
also loads `SYSTEM.SYS` at cold startup, before Finder. Its JSON source changes
native font glyphs, fixed menu/dialog captions, menu headings, document-dialog
positions, and button positions/widths/style without rebuilding the simulator
or bitstream. Version 1 retains character advances, action identities, dialog
box sizes and field arrangement. Embedded application fonts remain program
assets. See [SYSTEM_RESOURCES.md](SYSTEM_RESOURCES.md) for editing, publishing,
agent instructions, memory layout and limits. Python reads the same file.

The current simulator and card.img include this resource loader and the latest
Finder source, with SYS files classified as hidden support files. No new `.bit`
was started. Resource integrity/consumer readback and native dialog-coordinate
checks passed; broad application/board acceptance still belongs to owner testing.

## Rollback without a branch

`archive/builtin-finder-2026-11-03/` contains the pre-change source ZIP,
checksums and previous simulator executable. Restore selected source files
carefully rather than overwriting later unrelated edits.

The current source also retains the built-in desktop build option:

```sh
make -C sim sim_server_synth BUILD=sim_build_builtin_finder JMR_SIM_PARAMS=PROGRAM_FINDER=0
```

That produces a separate simulator directory; it does not replace the default
program-Finder executable. For a future board build, `JMR_BUILTIN_FINDER` in
`JMR_VIVADO_DEFINES` selects the built-in desktop. No board build was started.
The existing M/N trial bits and current release link were left alone.

## Python changes recorded before the resource pass

Historical parity checklist: the resource pass below now supplies the updated
save caption, unselected/empty unnamed Save As field, File → Quit, configurable
button styling and the latest Finder JSH. Caret/I-beam and all mouse-release
behavior still require a separate parity pass. Python has these behaviors. The chip still has
the previous dialog, cursor, and Finder paint. No bitstream was built for
them. `tools/export_classic_ui.py` label 147 is now `Save document as:`.
The generated package and disk resources have now been refreshed.

Shared toolbox (`functional_model/classic_ui.py`, the ROM the programs share):

- The save box says "Save document as:". A new document does not prefill
  `UNTITLED.TXT` or `UNTITLED.HTM`. A real name stays, and it is not
  selected. A 1px caret blinks twice a second at the insertion point
  (Chicago advance of the letters before it). Left and right move it.
  Backspace deletes the letter before it. A click in the field places it.
- The button Return already presses (Save, Open, Replace, the changes
  Save, OK) has a second outline, 4px outside the round button. The other
  buttons are round too, with no extra outline. A click outside the box
  inverts that outlined button for a few frames and does not dismiss it.
- File for every application says Quit. The command is still `close`.
  The Finder program's own File menu is unchanged.
- Dialog buttons and About OK invert while the pointer is held on them
  and run on mouse-up. `rtl/engines/jmr_classic_ui.sv` still acts on the
  mouse-down edge.

Pointer (`functional_model/desktop.py` `pointer_overlays`): over the save
name field (x 154–363, y 150–171) the cursor is an I-beam, hot spot (7, 7).
The arrow and the compile watch are unchanged. The I-beam is not a new
asset file.

Finder program (`storage/FINDER.HTML`, minted `FINDER.JSH` is 148,000
bytes on `card.img` as of this note):

- The down scroll mark is an open chevron, not a filled triangle and not
  the letter v.
- Dragging an icon lifts that picture off its spot and draws it under
  the pointer (arena 16472/16474 is where the drag started). The Disk
  and the Trash light up yellow while the pointer is over them; those
  are the same rectangles a drop uses. A band select is still the
  rectangle. A zoom outline's last frame asks for another paint.
- Renaming a name draws a white box around the letters and the same
  blinking caret. The blink sets the dirty byte every 16 frames, only
  while a rename is active.

Return to the Finder (`runtime/backend.py`): a fresh start clears arena
byte 16384 so `start()` runs on the cleared glass, then paints before the
window is shown. A parked Finder sets byte 16385. The editor's `cdone`
sets `_app_stopped`, and Python comes back to the Finder instead of
leaving role 9 over a black frame. RTL should not resume with init already
1 and dirty 0 on a cleared framebuffer.

`fillText` in Python now uses the same baseline register the chip already
has: top is y, middle is y−4×scale, bottom and the default are y−8×scale.
An unknown string such as `center` leaves the register. No RTL change.

Startup (`gui_jmr_js.py`, drawn by `paint_javatosh_boot` in
`functional_model/desktop.py`): before the Finder, Python shows two
pictures. Both use the Enterprise silhouette instead of the computer
sketch. Under the ship, Chicago reads `NCC-1701` and `JMR Enterprises`.
The first picture is that lockup, centered, for about 1.4s. The second
is the wide white box, with the same lockup on the left and the Chicago
words "Welcome to Javatosh." The box has a one-pixel black edge and a
black shadow on the right and the bottom only. The background is a
checker of desktop colours 0x5B and 0x7B on the rgb332 palette. A key
or a click skips both. RTL still shows "Starting Finder..." (label 169).
These two pictures are not on the chip yet.
