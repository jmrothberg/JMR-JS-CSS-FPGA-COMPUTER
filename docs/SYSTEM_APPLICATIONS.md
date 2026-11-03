# Shared Mac-style application interface

Status: **installed in the main Python GUI, native RTL simulator and `card.img`**, November 2, 2026.
Launch normally from the project folder:

```sh
.venv/bin/python gui_jmr_js.py
```

The default GUI starts in Python and uses `card.img`; saves go to that disk.
A copy of the disk from before this update and the publication record are under
`build/system_tools/` (see its README). The released FPGA bitstream is unchanged.
The interface has passed Python and native RTL/F9 checks. The RTL implements
menus, shared windows, file dialogs, document saves, Utility catalog staging
and compiler lifecycle in the same synthesizable hardware used for the board.
The new run74 bitstream must pass routing/timing gates and then a board test.
The board-tested release remains `releases/current/fpga.bit`.

`./run_python_system_preview.sh` remains an optional isolated Python-only preview
using `build/system_tools/python_card.img`, with its own saves and F9 disabled.

## System feature, declared by HTML

The system draws the Enterprise ship, classic font, opaque pull-downs, windows,
scroll controls and dialogs. HTML declares a role and optional application menus;
it handles application commands through the existing keydown event path. Do not
copy a menu renderer, click rectangles, ship image, or font atlas into each app.

`storage/MENUEX.HTML` is the complete small example. Both converted real games
use exactly the same interface:

```js
var ctx=document.getElementById("c").getContext("2d");
ctx.systemWindow=8;
ctx.systemMenus="Game|New Game=160|Pause / Resume=161";
addEventListener("keydown",function(e){
  if(e.keyCode===160)resetGame();
  if(e.keyCode===161)togglePause();
});
```

`resetGame` and `togglePause` are the application's own functions. Menu commands
have no text/character payload and do not simulate mouse clicks into game buttons.
The system consumes menu pointer events so a menu selection cannot also move a
chess piece or act as a click in the program underneath. Ship → About and Keyboard remain available. **Quit is in File for every
game**, and is absent from the ship menu. Games without their own Game menu
receive a shared Game → Restart action that reloads the same executable.

## Roles and drawing areas

- `1`: SOURCE Editor. Shared File/Edit actions and save/resume protocol below.
- `2`: SOURCE Reader. File → Open chooses another `.MD` or `.TXT` on disk.
- `3`: Compiler. The system selects this during the actual compile chain; do not
  insert chrome into the nearly full compiler program.
- `4`: Utility. Shared window and catalog contents; File → Close works.
- `5`: Note. A tiny entry point opens an untitled `.TXT` in the shared Editor.
- `6`: Other utility/application. Shared window, File → Close, application menus.
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

## Menu description

These context properties are write-only declarations.

Set `ctx.systemMenus` once at startup, using a literal string. Semicolons separate
menus, `|` separates the heading/items, and `=` assigns an item a command number.
Use at most **3 extra menus, 8 items per menu, 512 printable ASCII bytes total**.
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
the system. File → New/Open/Close offers Save/Discard/Cancel when modified.

File → Save sends F2 (keyCode 113, empty character). The Editor writes this
21-byte resume header using `stgWrite`, then calls `cdone(129,0,0)`:

- bytes 32..35: `82,69,83,1` (`RES`, version 1).
- little-endian u32 at 36,40,44,48: caret row, column, top row, left column.
- byte 52: role 1 or 5.

The system saves SOURCE to the chosen filename and restarts the same editor on
that document, restoring the caret/viewport. New/Save As uses the shared filename
dialog and mouse keyboard. Existing files require an explicit Replace choice.
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
   Use `MENUEX.HTML`, `2DFANTA2.HTML` and `DNKF.HTML` as working examples. Draw
   content only; the shared system supplies the chrome and file lifecycle.
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
