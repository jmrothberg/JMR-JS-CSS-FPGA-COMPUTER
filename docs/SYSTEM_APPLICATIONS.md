# Shared Mac-style application interface

The normal GUI is Python, then F9 for FPGA-SIM. Both use `card.img`.
Which bitstream is loaded: [FPGA_FIT.md](FPGA_FIT.md). The image still in QSPI (run73o) does not have this interface. The run75 rollback bit does. Run76 is the source being built.

```sh
.venv/bin/python gui_jmr_js.py
```

## System feature, declared by HTML

The system draws the Enterprise ship, classic font, opaque pull-downs, windows,
scroll controls and dialogs. HTML declares a role and optional application menus;
it handles application commands through the existing keydown event path. Do not
copy a menu renderer, click rectangles, ship image, or font atlas into each app.

`storage/MENUEX.HTML` is the complete small example for a menu command.
`storage/GUIDEX.HTML` is the example for a standalone desktop habit:
names in alphabetical order, drag one onto Trash, and Desk → Empty Trash.
Both converted real games use exactly the same interface:

```js
var ctx=document.getElementById("c").getContext("2d");
ctx.systemWindow=8;
ctx.systemMenus="Game|New Game=160|Pause / Resume=161";
addEventListener("keydown",function(e){
  if(e.keyCode===160)resetGame();
  if(e.keyCode===161)togglePause();
});
```

The same declarations are how a game uses the system box. File → Save draws
one Macintosh dialog: the words "Save document as:", the name field,
then Save and Cancel. There is no Eject, Drive, or radio row. The program
does not paint that box. Python draws it, and the chip draws the same box.
A one-pixel caret blinks in the name field. Clicking between letters, or
the left and right keys, moves it. Backspace deletes the letter before it.
The button Return presses has a second outline. The buttons are round.
Over the name field the pointer is an I-beam. A click outside the box
flashes that outlined button and does not close the box.
`storage/MENUEX.HTML` is the copy for a game. `storage/GUIDEX.HTML` is the
copy for a program that has a window.

## The boxes the system draws

Open, Save, Save As, the save-changes question, and Replace are one set of
boxes. `storage/EDITOR.HTML` is the program that uses them. It sets
`ctx.systemWindow` to 1 (Note uses 5), publishes `ctx.windowDirty`, and
does not supply its own `File|` menu. File → Save As opens the box the
editor shows: "Save document as:", the name field, Save, and Cancel.
The program does not paint that box, those words, the field, or the buttons.

File → Save delivers keyCode 113 with an empty character. The editor writes
the resume header and calls `cdone(129,0,0)`. The system then stores SOURCE
under the name from the box. The header bytes are in SOURCE document tools
below.

A menu string that starts with `File|` replaces that File menu. Items
labeled `Open...` and `Save As...` still open these boxes. The chosen
name is written at arena bytes 96–111 (the filename field, up to 12
letters and a trailing 0), and then the item's command key is delivered.
The program reads that name and loads or writes its own bytes. `Save`
stays a command key: the program already has a name. Do not paint a
second name field or file list in the window.

`resetGame` and `togglePause` are the application's own functions. Menu commands
have no text/character payload and do not simulate mouse clicks into game buttons.
The system consumes menu pointer events so a menu selection cannot also move a
chess piece or act as a click in the program underneath. Ship → About and Keyboard remain available. **Quit is in File for every
game and every windowed program**, and is absent from the ship menu. Games without their own Game menu
receive a shared Game → Restart action that reloads the same executable.

## Roles and drawing areas

- `1`: SOURCE Editor. Shared File/Edit actions and save/resume protocol below.
- `2`: SOURCE Reader. File → Open chooses another `.MD` or `.TXT` on disk.
- `3`: Compiler. The system selects this during the actual compile chain; do not
  insert chrome into the nearly full compiler program.
- `4`: Utility. Shared window and catalog contents; File → Quit works.
- `5`: Note. A tiny entry point opens an untitled `.TXT` in the shared Editor.
- `6`: Other utility/application. Shared window, File → Quit, application menus.
- `7`: Terminal. Selected by the system for the command console.
- `8`: Game. Shared top menu bar; no surrounding document frame.
- `0`: Legacy program without the shared application menu bar.

Windowed app content occupies **x=24..599, y=88..431**. Paint only that body.
The system owns everything outside it. A game has two options:

```js
ctx.systemWindow=8;
ctx.systemViewport=1;
ctx.systemAbout="Game title|One line describing the game.";
```

`systemViewport=1` fits the full existing 640×480 game into screen rows 24..479.
Keep all original drawing, collision, and mouse coordinates. The system samples
rows from the existing framebuffer during display and maps pointer coordinates
back into the same logical game space, including `offsetY` and motion deltas.
It does not allocate a second game framebuffer or add a sprite sheet. This is
particularly useful when converting a collection of existing games: score/HUD
text at the original top of the picture remains visible below the menu bar.

With `systemViewport=0` (the default), the program arranges its own content below
row 24. Chess and Donkey Kong already do this. Do **not** both move the game's
coordinates and enable the automatic viewport, or its contents will be inset
twice. The viewport is a presentation setting, not a game-specific renderer.

Every About dialog says **JMR Enterprises**, then the active program's title,
then the one-line description from `systemAbout`. Declare the metadata once on
startup. Use `Title|Description`, a 1–32 character title and 1–64 character
printable ASCII description, each at most 335 pixels in the shared font. The
system rejects text that does not fit instead of letting it cross the dialog.
Finder and system tools have their own role-based About descriptions; a game
must provide its own metadata. There is no game-name lookup in the runtime.

`ctx.windowScroll` and `ctx.windowScrollX` publish normalized scroll position
from 0 to 255, not a request to scroll. The system sends keys 128/129 for one line
up/down, 130/131 for page up/down and 132/133 for left/right. The app changes its
viewport and republishes the positions. Games do not need these properties.
`ctx.systemTitle="untitled"` supplies a 0–24 character printable ASCII document
caption and suppresses generic window hints. An empty title restores the default.
`ctx.windowBars=0` hides that scroll bar. The default is a bar. MacPaint sets
0 because the hand moves the page and the window itself does not scroll.

## Menu description

These context properties are write-only declarations.

Set `ctx.systemMenus` once at startup, using a literal string. Semicolons separate
menus, `|` separates the heading/items, and `=` assigns an item a command number.
Use at most **3 extra menus, 8 items per menu, 512 printable ASCII bytes total**.
A document program that must own File and Edit starts the descriptor with
`File|`. That form allows six menus and 14 items, up to 800 bytes, and
commands 160–239. `Quit` and `Close` leave the program. `Open...` and
`Save As...` open the shared boxes, then deliver that item's command
key. The name is at arena bytes 96–111. A lone `-` is a separator.
Menu headings are 1–12 characters; item labels are 1–24 characters. Commands
**160–191** must be unique in the descriptor. Do not use `File`, `Edit`, `View`,
or `Special` as custom headings. The system rejects invalid descriptors visibly.

Keep command numbers stable. Handle them inside an existing keydown handler
where possible: this machine has a small listener limit. Do not add a new
listener every time a game restarts. Only expose commands the app implements.
Do not invent an Undo command for chess unless actual chess undo exists.

The system provides File/Edit/View/Special in windowed tools. Games get File,
application menus and Special. Unsupported standard actions are grey. Special
launches Terminal, Editor, Reader, Compile, Utility, Note and Help, or restarts
Finder. These are common system actions, not game-specific callbacks.

## SOURCE document tools

SOURCE stays in the existing memory region. `srcLen`, `srcByte`, `srcWrite` and
`srcSetLen` access it; the document limit remains **65,536 bytes**. A menu does not
increase that limit. `EDIT` and `READ` chain-load their tools without loading the
tool's own HTML into SOURCE. Note opens the same editor rather than maintaining
a second editor. File → Open offers real disk files; no embedded manual copy.

Editor/Note use `ctx.windowDirty` bits: 0 modified, 1 undo available, 2 clipboard
available, 3 selection exists. Bits 4–5 report notices: 1 clipboard overflow,
2 document full. Commands are 137 Undo, 138 Cut, 139 Copy, 140 Paste, 141 Clear,
142 Select All. Selection and edits belong to the app; menus/dialogs belong to
the system. File → New/Open/Quit offers Save/Discard/Cancel when modified.

File → Save sends F2 (keyCode 113, empty character). The Editor writes this
21-byte resume header using `stgWrite`, then calls `cdone(129,0,0)`:

- bytes 32..35: `82,69,83,1` (`RES`, version 1).
- little-endian u32 at 36,40,44,48: caret row, column, top row, left column.
- byte 52: role 1 or 5.

The system saves SOURCE to the chosen filename and restarts the same editor on
that document, restoring the caret/viewport. New/Save As uses the shared filename
dialog. A new document starts with an empty name, not `UNTITLED.TXT`. A real
name stays in the field. The caret blinks at the insertion point, and
Backspace deletes the character before it. The on-screen
keyboard stays closed until the apple menu opens it.
Existing files require an explicit Replace choice. Radio buttons are not part
of that box. A program adds them only when the choice is real for that program.
Saving HTML invalidates its old `.JSH`, as the existing storage system requires;
Compile builds its new executable. Ordinary text uses `.TXT` or `.MD`.

Editor selection is byte offsets. The clipboard and one-edit Undo each use at
most 4 KiB of existing compile scratch, at 24584 and 32768 respectively; the
clipboard header is at 24576..24583. The line index remains at 4096..20479. Cut/
Copy over 4 KiB reports a limit and leaves the document/clipboard intact. Clear
can delete a larger selection but has no Undo. There is no full document clone.
Compile uses that same scratch arena, so clipboard/Undo do not survive compiling.

## Instructions for a porting agent

1. Read the program, identify its real commands and current mouse/keyboard
   behavior. Start from the latest optimized project version; compare older
   supplied copies before replacing anything. Preserve existing artwork/logic.
2. Choose role 8 for a game or role 6 for a general tool. SOURCE document tools
   can use the documented Editor/Reader protocol. Do not assign Editor role
   merely to obtain enabled Save when the app has a different document model.
3. Declare `systemAbout` for the application and use `systemViewport=1` for
   an existing full-screen game. Declare a compact menu string when the app
   needs extra commands, and route those commands to existing functions.
   Use `MENUEX.HTML` for a menu command and `EDITOR.HTML` for Open, Save,
   and Save As. Draw the document only. The system draws the menu bar and
   those boxes. On a `File|` menu, label the items `Open...` and
   `Save As...` so the same boxes open. Read the chosen name at arena
   bytes 96–111 when that command key arrives.
4. Use the shared viewport to reserve the bar without changing game coordinates,
   or use explicit layout and update drawing and mouse coordinates together.
   Remove displaced toolbar buttons; put their real actions in menus.
5. Keep one animation loop. Restart resets state, not listeners/timers/animation
   loops. Keep literals and static menu setup outside per-frame code.
6. Compile with `tools/check_port.py`, run the serialized `.JSH` on Python,
   check the application-specific About dialog, exercise commands by clicking
   the actual menu, and test that menu clicks do
   not leak into content. Test restart repeatedly, Quit/close and mouse keyboard.
   For documents also test Save/Save As, dirty-close choices and opening files.
7. Record actual sizes and limitations. Update the normal disk only when the
   owner requests it, preserving other files and a rollback copy. Keep the
   released `.bit` alone. No claim of FPGA support
   until the same interface passes the real RTL simulator and board process.

## Memory and real examples

Menu descriptors remain small literals in the program. Context window state is
four bytes; menu command delivery uses the existing input path. No new native
opcode is needed. Editor, Utility, Note and the small example add **zero** sprite
sheets. Reader retains its existing Chicago text atlas. Chess retains 12 sheets;
Donkey Kong retains 6. The Python display uses cached host overlays; actual FPGA
resource use and fit for this interface have **not** yet been qualified.

Fantasy Chess uses Game → New Game and Level → Ply 1..5. Donkey Kong uses Game →
New Game - Mario / New Game - Luigi / Pause / Resume. Its existing fast dirty
redraw remains; a single animation loop handles the title and repeated restarts.
All 19 games/demos in `storage/` declare the shared menu role and About metadata.
The other 17 use the automatic viewport and receive Game → Restart. No runtime
behavior is selected by game filename. The publisher discovers declarations in
HTML, so future converted programs are included without editing a title list.

## MacPaint

`storage/MACPAINT.HTML` is a windowed drawing program, role 6. It draws
only in the white hole. Its menu descriptor starts with `File|`, so the
program owns the menu bar: File, Edit, Goodies, Font, FontSize, Style.
The title stripes say `untitled`. File → Open... and File → Save As...
open the shared boxes. MacPaint reads the name at arena bytes 96–111
and loads or writes `STEM.PNT` with `fsRead` and `fsWrite`. No new
instruction was added. The tool pictures are the 1984 MacPaint font,
and the 38 patterns are the System pattern list from that disk.

The page is 576 by 320. The page, one undo copy, and a full-page
clipboard have to fit in the 73,728-byte compile arena. A taller classic
page does not fit beside those copies. Bits are arena bytes (`stgRead` /
`stgWrite`) because a program cannot index ImageData pixels. Each ink
pixel also has a color nibble in the image half of that arena, which
this program does not use for pictures. The 16 colors are the exact
entries on the glass: black, white, red, green, blue, yellow, cyan,
magenta, and eight greys. The text tool is one 5 by 7 face. Font names
move the check. The stick uses `keyUp` / `keyDown` / `keyLeft` /
`keyRight` / `keyFire`. `joy()` is not a chip instruction. The window
sets `windowBars=0`.

## Standalone desktop, from the 128K Finder

The original Macintosh Finder is one disk, a Trash can, and four menus.
These are the pieces worth having on this computer, and small enough to
show in an HTML example.

Python desktop, now:

- View → List sorts names A to Z. View → Icons keeps disk order.
- Drag a file onto Trash. It leaves the window and stays on the disk.
- Click Trash to see the held files. Drag one onto Disk to put it back.
- Special → Empty Trash appears once Trash holds a file, asks, then `REMOVE`s them.
- File → Delete... still deletes the selected file immediately.

`storage/GUIDEX.HTML` is the copyable window. A windowed program draws
only in the white hole, x 24 to 600 and y 88 to 432, and leaves out
anything that does not fit. Games stay `systemWindow` 8 and fill the
screen. They are not put in that hole. `storage/READ.HTML` is the
document reader: `#` and `##` are twice body size and the marks are not
drawn. `- ` and `* ` become an indented square.

Those desktop behaviors belong to the Finder program below, not to a
later edit of `jmr_desktop.sv`. The built-in desktop remains only the
`JMR_FINDER=builtin` / `PROGRAM_FINDER=0` rollback. This machine has
one disk, so Eject stays off.

## Finder program

The section above is the built-in desktop (`functional_model/desktop.py`
and `rtl/engines/jmr_desktop.sv`). The Finder program is a different
thing: `storage/FINDER.HTML`, an ordinary card program, the way the
1984 Finder was a program and the menu bar stayed in ROM.

The Python shell uses it when `JMR_FINDER=program` (the GUI default)
or when `FINDER.JSH` is on the disk. `JMR_FINDER=builtin` keeps the
built-in desktop. Quitting a program, or Esc, runs the Finder again.
Nothing in the built-in desktop is deleted.

A menu title inverts while that menu is open. Dragging across the bar
switches menus. A row inverts under the pointer, and the command runs
when the button is released on it. A dialog button does the same: it
inverts while held, and it runs only if the pointer is still on it.

The Finder draws its own overlapping windows. Once it has loaded, that
running program stays in memory. Opening something else uses the one
heap, and coming back continues the same Finder. Restart loads it again.
The toolbox still draws
the menu bar, the Apple menu, and the Open / Save As dialogs. Folders,
icon positions, Trash, comments, and window places live in
`DESKTOP.FDR` on the flat card. There are no FAT subdirectories.

File has New Folder, Open, Close, Close All, Get Info, Duplicate, and
Put Back. Print, Page Setup, and Eject stay grey. Edit has Undo, Cut,
Copy, Paste, Clear, Select All, and Show Clipboard. View has by Icon,
by Small Icon, by Name, by Size, by Kind, by Date, and Hidden files.
Special has Clean Up, Empty Trash, Set Startup, Restart, Terminal, and
Compile. Erase Disk stays grey. An HTML file with a minted JSH is an
application. HTML with no JSH is source. `.MD` and `.TXT` are documents.

DIR hides `FINDER` the same way it hides EDITOR and COMPILER.
`DESKTOP.FDR` is hidden with the other non-title suffixes. The icons
are the rectangles the program draws. No new icon art is added.

## RTL program Finder handoff (November 3)

The default RTL now uses the Finder program and generic file/launch hooks.
The built-in desktop is preserved as a build option and source snapshot.
See [lastrun_ARCHITECTURE.md](lastrun_ARCHITECTURE.md).

The RTL implementation keeps the 8 MiB memory map. It caches the Finder image
and parks its arena state while another application uses the single VM. Returning
reconstructs JavaScript globals, restores the arena and redraws; it does not keep
a second live JS heap. This is specific to the Finder’s documented arena layout.
The implemented SYSTEM.SYS loader is documented in
[SYSTEM_RESOURCES.md](SYSTEM_RESOURCES.md), including source format and agent
instructions. It supplies shared visual resources; application behavior and
custom menu commands remain JavaScript. Boot, desktop, menu and Terminal-return smoke checks
have passed; application-wide owner testing and board timing remain outstanding.

## Shared scratch RAM is not initialized program state

The real board's external RAM is undefined at cold power-on and can contain
previous applications' data. A new system program must initialize every flag,
length and structure it reads before writing. Do not rely on Python/Verilator
zero-filled memory. Clear metadata and invalidate caches; image buffers can be
loaded on demand. A resident application's valid restore path must preserve
its saved state rather than performing a cold clear.

The November 4 Finder correction initializes file/window/control metadata,
comment lengths and icon-cache flags in `start()`. The loader clears the init
flag on cold launch; a resident return keeps it set. Regression tests seed
external RAM with 0xA5 and verify window geometry and keyboard selection.

## Run76 FPGA interface status

The six-menu `File|` contract, separator/checkmark rendering, `systemTitle` and
`windowBars` are now implemented in RTL and tested with the exact MacPaint
program. Use run76 after its release qualification; older run75 does not
support those extensions. `tests/test_owned_menus_rtl.py` exercises the native
parser and pointer dispatch, including Save, the last menu and Quit lifecycle.
The program still implements its own document bytes. `Open...` and
`Save As...` open the shared boxes and leave the name at arena bytes
96–111. Declaring those labels does not invent file serialization.
