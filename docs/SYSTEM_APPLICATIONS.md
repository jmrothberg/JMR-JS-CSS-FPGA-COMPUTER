# Writing an application: menus, windows, dialogs, files

The machine boots into Finder. Finder and every other program are HTML files
on the card, compiled to native JavaScript. The menu bar, windows and dialogs
are drawn by the resident Toolbox library, not by hardware and not by each
program.

| For | Read |
|---|---|
| Memory and graphics calls | [TOOLBOX_API.md](TOOLBOX_API.md) |
| Drawing recipes | [TOOLBOX_USAGE.md](TOOLBOX_USAGE.md) |
| Linking against the library, compiling, building the card | [RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md) |
| Game rules, art, sound, speed | [GAME_DESIGN.md](GAME_DESIGN.md) |
| Supported JavaScript | [JS_COMMANDS.md](JS_COMMANDS.md) |

Sources: `resources/toolbox/session.js`, `documents.js`, `ui.js`.

## Smallest program

```html
<!-- jmr-toolbox: resident-v2 -->
<!doctype html>
<html><body><canvas id="c" width="640" height="480"></canvas><script>
var ctx=document.getElementById("c").getContext("2d");
tbSessionProperty(ctx,2,"Menu Example|A small example of shared menus.");
tbSessionProperty(ctx,0,6);                       // 6 = windowed tool, 8 = game
tbSessionMenus(ctx,"Example|Add One=160|Reset=161");
var count=0,redraw=1;
tbSessionListen("keydown",function(e){
  if(e.keyCode===160){count=count+1;redraw=1;}
  if(e.keyCode===161){count=0;redraw=1;}
});
function frame(){
  if(redraw){ /* draw inside x 24..599, y 88..431 */ redraw=0; }
  tbSessionFrame(frame);
}
tbSessionFrame(frame);
tbSessionProgram("MENUEX.HTM");
</script></body></html>
```

| Example in `storage/` | Shows |
|---|---|
| `MENUEX.HTML` | A menu command |
| `GUIDEX.HTML` | A windowed tool with mouse dragging |
| `UISESS.HTML` | Owned File menu, Open and Save As, a nested port, scrolling. It overwrites SOURCE and writes files; use a scratch card |
| `UIMAN.HTML` | The manual UI calls, without a session |
| `EDITOR.HTML`, `NOTE.HTML` | The SOURCE document protocol |

## Two ways to use the UI

Use one per program, never both.

| | Session | Manual |
|---|---|---|
| Calls | `tbSession…` | `tbUIInit`, `tbMenus`, `tbUIPointer`, … |
| Who owns `addEventListener` and `requestAnimationFrame` | the session | the program |
| Menu bar, File and Special menus, About, Quit, file dialogs | provided | the program builds them |
| Use for | applications and games | special cases |

## Session calls

| Call | Does |
|---|---|
| `tbSessionProperty(ctx,field,value)` | Set a property. See the table below |
| `tbSessionMenus(ctx,spec)` | Set the menus. `spec` is one string, or an array of strings with one menu each |
| `tbSessionListen(type,fn)` | Register an input callback. Registering the same `fn` twice adds it once |
| `tbSessionUnlisten(type,fn)` | Remove a callback registered for `"keydown"`, `"keyup"` or a mouse event. `document.removeEventListener` does not remove session callbacks |
| `tbSessionFrame(fn)` | Run `fn` on the next frame, once. Call it again from `fn` to keep animating |
| `tbSessionInvalidate(fn)` | Register a callback that redraws the content and does nothing else |
| `tbSessionTransform(a,b,c,d,e,f)` | `setTransform` that keeps the game viewport or window origin |
| `tbSessionProgram(name)` | Give the program's own 8.3 card name, for example `"MYGAME.HTM"`. Enables Game → Restart |
| `tbSessionSuffix(ext)` | File type, for example `"PNT"`. Filters Open lists and is the default Save As extension; without it Save As adds `.TXT` |
| `tbSessionCodes(text)` | Turn a string literal (up to 128 bytes) into the byte array the drawing and dialog calls take |
| `tbSessionChrome(fn)`, `tbSessionNames(fn)`, `tbSessionDocument(fn)` | Register callbacks. See [Callbacks](#callbacks) |

Other exported `tbSession…` names (`Defaults`, `Parse`, `Equals`, `Bit`,
`Masks`, `SendKey`, `Command`, `DialogResult`, `U32`) are the session's own
plumbing. Do not call them.

### Properties

| Field | Value |
|---|---|
| 0 | Role. Setting it starts the session: it initialises the UI, installs the input listeners and paints the window |
| 1 | 1 = game viewport (role 8 only) |
| 2 | `"Title|One line about the program"`, up to 100 bytes. Used as the window title and the About dialog |
| 4 | Window title string. Overrides the title from field 2 |
| 5 | Enable mask for commands 160–191. Bit *n* is command 160+*n*. Default: all enabled |
| 6 | Check-mark mask for commands 160–191 |
| 7, 8 | Vertical and horizontal scroll position, 0–255, shown by the scroll bars |
| 9 | Document flags for roles 1 and 5: 1 modified, 2 undo available, 4 clipboard has data, 8 selection exists. They enable the Edit items |

There is no field 3.

### Roles

| Role | Program | Default File menu |
|---|---|---|
| 1 | Editor | New, Open…, Save, Save As…, Quit |
| 2 | Reader | Open…, Quit |
| 3 | Compile window | Compile… (pick a program and compile it), Quit |
| 4 | Utility | Quit |
| 5 | Note | as role 1 |
| 6 | Any other windowed program | Quit |
| 8 | Game: full screen, menu bar only | Quit |
| 9 | Finder: no window frame, RGB332 palette | none; Finder owns its bar |

### Where to draw

**Windowed roles.** The session paints the desktop and one window. Draw only
in the content area, **x 24–599, y 88–431**. Callbacks registered with
`tbSessionListen`, `tbSessionFrame` and `tbSessionInvalidate` run inside a
[port](TOOLBOX_API.md#ports) clipped to the content area, and mouse
coordinates arrive in the same coordinates. The user can drag and resize the
window; the program keeps using the same coordinates. A smaller window shows
less of the content.

**Games (role 8).** The program draws the full 640×480 screen. The menu bar
covers rows 0–21. Either lay the game out below row 24, or set field 1 to 1:
the session then scales drawing by 0.95 vertically into rows 24–479 and maps
mouse coordinates back, so the game keeps its original coordinates. Do not do
both. A game that calls `setTransform` itself must call `tbSessionTransform`
instead. Physical pixel positions under the viewport:
[TOOLBOX_USAGE.md](TOOLBOX_USAGE.md#two-coordinate-spaces).

## Menus

```
"Game|New Game=160|Pause=161;Level|Easy=162|Hard=163"
```

`;` separates menus. `|` separates the heading and the items. `=` gives an
item its command number. An item that is only `-` is a separator. Text is
printable ASCII. The whole specification is at most 800 bytes, and each
string literal at most 255 bytes; pass an array of strings for a large bar.

| The program | Menu bar |
|---|---|
| never calls `tbSessionMenus` | The role's File menu; Edit for roles 1 and 5; Game → Restart for role 8; Special |
| gives menus whose first heading is not `File` | The role's File menu, the program's menus, Special |
| gives menus whose first heading is `File` | Exactly the program's menus |

Special holds Editor, Reader, Compile, Utility, Note, Help and Finder.

### Commands

A chosen item arrives at the program's `keydown` listeners as
`{keyCode: command, charCode: 0}`, except for the cases below.

| Command or label | The session does |
|---|---|
| 160–191 | Delivered to the program. Enabled and checked through properties 5 and 6 |
| Label `Quit` or `Close`, 1006, 255 (window close box) | Leaves the program and returns to Finder. Roles 1 and 5 ask about unsaved changes first |
| Label `Open...` | Shows the file list. On Open, writes the chosen name at arena bytes 96–111 and delivers the item's command |
| Label `Save As...` | Shows the name box, checks the name, asks before replacing a file. Then writes the name at 96–111 and delivers the item's command. Needs `filename_client.js` |
| 1001 New, 1002 Open, 1004 Save, 1005 Save As | Document commands of roles 1 and 5 |
| 137–142 | Undo, Cut, Copy, Paste, Clear, Select All. Delivered to the program |
| 1007 | Restart: runs the name given to `tbSessionProgram` again |
| 1010–1016 | Editor, Reader, Compile, Utility, Note, Help, Finder |

The file list reads every `fsList` page into one list, kept in rows of 100
because an array holds at most 128 values. Up and Down move a row, Page Up and
Page Down five; the scroll bar's arrows move a row and its track a page, and
the bar stays drawn at either end and for a short list. Reader (1011, and
Open in role 2) lists `.MD`, `.TXT`, `.HTM`, `.JS` and `.BAS` files; Compile
(1012) lists `.HTM` and `.JS`. A name that breaks the 8.3 rule reopens the
name box with the typed name and the rule as its prompt.

`Open...` and `Save As...` only choose a name. The program reads or writes
its own bytes with `fsRead` and `fsWrite`. Any other command number is
delivered unchanged; keep clear of key codes the program also handles.

Keep the menus static. Handle commands in one `keydown` listener. Only list
commands the program implements.

## Input and frames

`tbSessionListen` takes `"keydown"`, `"keyup"`, `"mousedown"`, `"mousemove"`
and `"mouseup"`. Other event names, such as `"click"`, are also accepted.
An event goes to the callbacks registered when it arrived: one that a callback
adds during the event first sees the next event.

The session sees input first. While a menu or dialog is open the program gets
no input. A click that operated a menu, the window frame or a scroll bar is
not passed on.

While a menu or dialog is open:

- With a `tbSessionInvalidate` callback, the program's frames are held and
  the callback is called to repaint what the menu or dialog covered.
- In a game (role 8) without one, frames are held too. The session copies
  the pixels under the menu or dialog to arena 308992–380319 before drawing
  it and puts them back when it closes.
- Otherwise frames continue and the UI is drawn on top.

The invalidate callback must only draw. It must not advance the game, edit
the document or read input.

Keep one `tbSessionFrame` chain. Restart must reset state, not add listeners
or a second chain.

### Keys the system owns

| Key | Meaning |
|---|---|
| Esc | See [Esc](#esc) |
| 254 | About. Sent by the ship menu; the session opens the About dialog |
| 113 (F2) with no character | Save, in roles 1 and 5 |
| 128, 129 | Scroll one line up, down |
| 130, 131 | Scroll one page up, down |
| 132, 133 | Scroll left, right |

### Esc

The session claims Esc for every role except 8: it sets bit 7 of
`ctx.windowDirty`, and the machine then delivers Esc as key 27 instead of
stopping the program. The session uses it to close an open menu, to cancel a
dialog, and otherwise as Quit (roles 1 and 5 ask about unsaved changes
first). Finder (role 9) receives it in its `keydown` listener and uses it to
cancel a rename, close Get Info, cancel its Empty Trash dialog and dismiss an
alert.

In a game (role 8), and in a program without a session, Esc stops the program
and returns to Finder at once.

Esc counts as unanswered until the program's listeners have run for a key.
After two unanswered Escs, the next one stops the program, so a program that
hangs can still be left with three presses. An Esc that arrives without a key
event, such as one sent over the serial link, is never answered: send three.

The scroll keys come from the scroll bars of `chrome_client.js`. The program
moves its view and reports the new position through properties 7 and 8.

The ship corner at the top left (x < 30, y < 22) belongs to the hardware. Its
menu has About and Keyboard. The on-screen keyboard and its Hold keys box
work over any program.

## Callbacks

| Register with | Signature | Module that supplies it |
|---|---|---|
| `tbSessionChrome(fn)` | `fn(mode,a,b)`. Mode 0: draw the scroll bars; `a`, `b` are the vertical and horizontal positions. Mode 1: mouse down at `a`, `b`; return a key code to send, or 0. Mode 2: the window was resized; `a`, `b` are the new content width and height | `chrome_client.js`. The program must define `tbClientResize(w,h)` |
| `tbSessionNames(fn)` | `fn(codes,suffix,kind)`. Kind 0: check and normalise the name array in place; return 1 if valid. Kind 1: return 1 if the name has that extension | `filename_client.js` |
| `tbSessionDocument(fn)` | `fn(action,value)`. See below | `editor_client.js`, for Editor and Note |

`filename_client.js` accepts 1–8 characters, an optional dot and 1–3
characters, from letters, digits and ``$%'-_@~`!(){}^#&``. It upper-cases the
name and adds the default extension when there is none.

Document actions:

| Action | Meaning | `value` |
|---|---|---|
| 0 | Return the current SOURCE name as a byte array, empty if unnamed | — |
| 1 | Save, then continue | what to do next |
| 2 | Commit a save under the name already chosen | what to do next |
| 3 | Start a new document | — |
| 4 | The user asked for New, Open or Quit; ask about unsaved changes if needed | what to do next |
| 5 | A dialog closed; return 1 if the document handled the result | dialog result |

"What to do next" is 0 stay, 1 new, 2 open, 3 quit. Helpers for a document
callback: `tbDocumentContinue(next)`, `tbDocumentSaveAs(next)`,
`tbDocumentHeader(role)`, `tbDocumentSuspend(on)`.

A program with its own file format does not register a document callback. It
uses `Open...` and `Save As...` items and its own `fsRead`/`fsWrite`.

## Manual UI

These seventeen calls are what the session is built on. A program that calls
them directly owns its own listeners and frame loop. `UIMAN.HTML` uses all of
them. Labels are arrays of ASCII codes.

| Call | Does |
|---|---|
| `tbUIInit(ctx,descriptor,glyphScratch,title)` | Start the UI. `descriptor` is 64 arena bytes, `glyphScratch` 32 bytes, both owned by the UI from then on. Returns 1, or 0 if the hardware lacks operations 8–12 or `SYSTEM.SYS` has no UI font |
| `tbWindow(x,y,w,h,title)` | Set the window rectangle and title |
| `tbMenus(menus)` | `[[title,[[label,command,enabled,checked],…]],…]`. An empty label is a separator. Command 255 is the close box |
| `tbMenuEnabled(menu,item,on)`, `tbMenuChecked(menu,item,on)` | Change one item by index |
| `tbUIKey(keyCode,charCode)` | Give a key to an open dialog. Returns 1 if used |
| `tbUIPointer(x,y,buttons)` | Give the pointer to the UI. `buttons` is 1 while the main button is down, else 0. Forward moves and releases too. Returns 1 if used |
| `tbMenuCommand()` | The chosen command, or 0. Reading clears it |
| `tbDialogOpen(kind,prompt,rows,value)` | Open a dialog |
| `tbDialogResult()` | 0 while open or idle. Reading clears it |
| `tbDialogValue()` | The name array of a kind 3 dialog |
| `tbDialogSelection()` | The chosen row of a kind 4 dialog, from 0 |
| `tbUIChanged()` | 1 if the UI needs a redraw. Reading clears it |
| `tbUIDraw()` | Draw menu bar, window frame, open menu and dialog. Call it last, after the content |
| `tbText(codes,x,y)` | Draw text in the 16-row system font. Codes outside 32–126 draw as `?` |
| `tbTextWidth(codes)` | Width in pixels |
| `tbBox(x,y,w,h,fill)` | Filled rectangle with a one-pixel black border |

| Dialog kind | Shows | Result |
|---|---|---|
| 1 | Message with OK. `rows[0]` is an optional second line | 1 |
| 2 | OK and Cancel | 1 OK, 2 Cancel |
| 3 | Name field (12 characters, at most 8 before the dot) with Save and Cancel. `value` is the starting name | 1 Save, 2 Cancel |
| 4 | List of `rows`, five visible, with Open and Cancel | 1 Open, 2 Cancel |
| 5 | Save, Discard, Cancel | 1, 2, 3 |
| 6 | Replace and Cancel | 1 Replace, 2 Cancel |

Return accepts. A dialog does no disk work; the caller acts on the result.

If `tbUIInit` failed, `tbUIDraw` writes the reason in the menu bar and
`tbText` draws nothing.

## Files, SOURCE and running programs

Names are NUL-terminated 8.3 names stored in the arena. The card is one flat
directory.

| Native | Does | Returns |
|---|---|---|
| `fsList(dst,capacity,start)` | Write one page of the catalog at `dst`, starting at record `start`. `capacity` ≥ 37 | records written, or −1 |
| `fsRead(name,offset,dst,n)` | Read up to `n` bytes of a file from `offset` | bytes read, or −1 |
| `fsWrite(name,src,n,mode)` | Write `n` bytes. Mode 0 replaces the file, 1 appends | `n`, or −1 |
| `fsRemove(name)` | Delete a file | 0, or −1 |
| `fsRename(old,new)` | Rename a file | 0, or −1 |
| `sysRun(name,how)` | Leave this program and start another. `how`: 0 run, 1 edit, 2 read, 3 compile, 8 return to Finder | — |
| `sysDocument(op,ptr,role)` | 0: write SOURCE name information at `ptr`. 1: name SOURCE from the name at `ptr`. 2: make SOURCE an empty unnamed document. Ops 1 and 2 need role 1 or 5 | 0, or −1 |
| `srcLen()`, `srcByte(i)`, `srcWrite(i,b)`, `srcSetLen(n)` | Read and write SOURCE, the shared document buffer of at most 65536 bytes | |
| `strByte(s,i)` | Byte `i` of a string literal's UTF-8 bytes | byte, or −1 |

`fsList` page: bytes 0–3 total size of the listed files, 8–9 record count,
byte 10 is 1 if more records follow, 12–15 the next `start`. Records begin
at byte 16: name length, name, u32 size, u16 DOS date, u8 attributes. A
length of 0 ends the page. With `dst` 0 it writes the whole catalog at arena
256 with its header at 240.

`sysDocument(0,ptr,0)` writes 20 bytes: 16 name bytes, name length, 1 if
unnamed, role, and the [exit status](#exit-status).

### Exit status

Byte 19 says why the last program stopped. Reading it clears it to 0, so
only the first `sysDocument(0,…)` after a return sees it. Finder reads it at
start and shows an alert for any value but 0.

| Value | Meaning | Finder shows |
|---|---|---|
| 0 | Normal exit, Quit or Esc | nothing |
| 4 | Disk error while loading | could not be opened: disk could not be read |
| 6 | File not found, or bad name | could not be opened: file not found |
| 7 | Not a program, or a damaged image | could not be opened: not a program |
| 9 | The `.JSH` image is missing or incomplete | could not be opened: program file missing |
| 10, 15 | Too large | could not be opened: too large |
| 14 | Compile error | could not be opened: did not compile |
| 16 | Checksum error | could not be opened: file damaged |
| 128 + *n* | VM fault *n* ([fault codes](JMR_JS_COMPATIBILITY.md#fault-codes)) | System Error box with a bomb and `ID = n` |

Values 1–31 are the loader's error reply codes. If Finder itself fails, it is
started once more with the status set. A second failure before Finder opens
anything leaves the read-only recovery display.

SOURCE is one shared buffer. Loading a document into it replaces what was
there. Writes are not atomic: a failed save can leave a partial file.

## Reserved arena bytes

A session program must leave these alone. Everything else in the arena
(0–380927) is the program's to lay out. The arena is not cleared between
programs: initialise every byte you read.

| Bytes | Used for |
|---|---|
| 32–52 | Editor resume header: `RES`, 1 at 32–35; u32 caret row, column, top row, left column at 36–51; role at 52 |
| 64–65 | Program-chain selector and save-completed flag |
| 96–111 | File name passed between the session, the program and `sysRun` |
| 208–211 | Pending action across a save |
| 308992–380319 | Role 8 only, while a menu or dialog is open: the pixels under it |
| 380320–380831 | Session catalog page and document name |
| 380832–380895 | Session UI descriptor |
| 380896–380927 | Session glyph scratch |

A manual-UI program supplies its own descriptor and glyph scratch and has no
reserved ranges.

## The shipped programs

**Editor and Note** (`EDITOR.HTML`, roles 1 and 5). Note creates an empty
document and starts the same Editor. Save As adds `.TXT` when no ending is
typed (neither sets `tbSessionSuffix`). The window title is the SOURCE name,
or `untitled`, set with `tbWindow` over `tbWindowBounds()`. Saving under a new
stem a program (`.HTM`, `.JS`) copies the old stem's `.ICN` and `.ART` to the
new stem when the new ones do not exist (arena 37104–37135 names, 40960–303103
bytes). Editor keeps its line index at arena 4096–20479, a clipboard
header at 24576–24583 with up to 4096 bytes at 24584, and one undo record of
up to 4096 bytes at 32768. Cut or Copy of more than 4096 bytes is refused.
Compile uses the same arena, so clipboard and undo do not survive it.

**Reader** (`READ.HTML`, role 2) shows `.MD` and `.TXT` files from SOURCE. It refuses anything but `.MD`, `.TXT`, `.HTM`, `.JS` and `.BAS`, or a
file with a NUL byte in its first 4 KB, with an alert, and returns to Finder.

**Finder** (`FINDER.HTML`, role 9) owns its whole menu bar and draws its own
overlapping windows, icons and Trash. Folders, icon positions, comments and
window places are stored in `DESKTOP.FDR`; the card has no subdirectories.
The machine keeps Finder's compiled image and arena while another program
runs, so returning to Finder does not reload it from the card. Icons:
[DESKTOP_ICONS.md](DESKTOP_ICONS.md). Document types are mapped to
applications by one table, `DOCS` in `FINDER.HTML`: extension, application
stem, and whether the Editor may open it as text. Today `.BAS` → TRSBASIC,
`.PNT` → MACPAINT, `.WRT` → MACWRITE. Such a file is a document: opening it
writes its name at arena 30000 and the extension's three letters and 1 at
30090, then runs `STEM.HTM`, which reads and clears that before it reuses the
memory. The file wears `STEM.ICN`. To add a type, add a row and make the
application read the hand-off. Files with other unknown extensions are hidden until View →
Hidden files.

**MacPaint** (`MACPAINT.HTML`, role 6) owns its menu bar: File, Edit,
Goodies, Font, FontSize, Style. It saves `STEM.PNT` through `Open...` and
`Save As...`. Its tables live in `PAINT.RSC` (1611 bytes: a 32-byte `JMRP`
version 1 header with an additive checksum, then fonts, icons, patterns and
tones), built by `tools/build_paint_resources.py` from
`resources/macpaint/tables.json` and loaded at arena 373504–375114.
`.PNT` files are `PNT3`: an 8-byte header, then the 576×320 page as one
colour nibble per pixel (92,160 bytes). Version 1 and 2 files still open.
Edit→Undo (or Z) swaps the page with a copy taken before the last operation.
Save on an untitled picture asks for a name (`tbDocumentSaveAs`, which
delivers key 0). Finder opens a `.PNT` by writing its name at arena 30000 and
`PNT`, 1 at 30090 before running MacPaint; MacPaint reads that before its
first frame clears the page.

**MacWrite** (`MACWRITE.HTML`, role 6) owns its menu bar: File, Edit, Search,
Format, Font, Style. It draws through its own port over the whole window
inside the frame and scroll bars, with the ruler under the title bar. The
document is three byte arrays: characters (13 ends a paragraph, 9 is a tab,
1 is a ruler), a style byte (1 bold, 2 italic, 4 underline, 8 outline,
16 shadow, 32 superscript, 64 subscript) and a font byte (font × 4 + size
step: Chicago 12/24/48 from the `SYSTEM.SYS` font, Monaco 9/18/36 from the
5 × 7 face in `PAINT.RSC`). Glyphs are drawn with operation 3. Up to 16
rulers hold margins, first-line indent, 8 tab stops, alignment and spacing;
the document always starts with ruler 0. It registers a document callback
for actions 4 and 5 only, so Quit, Close and Esc ask to save a changed
document, and it overrides `tbSessionNames` so Open lists `.WRT` and `.TXT`.
`.WRT` files are `WRT1`: a 32-byte header (`WRT1`, u32 character count, u8
rulers, u8 flags, u16 header size 32, u32 insertion point), the rulers
(32 bytes each), then the characters, styles and fonts. A name ending in
`.TXT` is read and written as plain text. Finder opens a `.WRT` with `WRT`, 1
at 30090. Headers, footers, title page, page breaks and printing are not
implemented.

| Arena bytes | MacWrite use |
|---|---|
| 112–191 | Document name, file header, name chosen in Open |
| 1024–4855 | Chicago and Monaco glyphs |
| 4864–6911 | Descriptors, caret pixels, advance tables, rulers, Find and Change text |
| 8192–69631 | Line records (24 bytes) and the relayout buffer |
| 69632–167935 | Characters, styles, fonts (30,000 each at most) |
| 167952–266271 | Clipboard and undo (12,000 characters each) |
| 266272–306271 | File and edit staging |

**Icon Editor** (`ICONEDIT.HTML`, role 6) edits the 32×32 icons on the card in
FatBits: every `.ICN` ([DESKTOP_ICONS.md](DESKTOP_ICONS.md)) and the two alert
icons in `SYSTEM.SYS`. It owns File (Save, Revert, Quit) and Edit (Undo,
Fill All, Clear, Invert). An `.ICN` save rewrites the 1160-byte JIC1 file. A
system icon save rewrites `SYSTEM.SYS` with those 128 bytes and a new payload
CRC; it takes effect at the next cold start, and rebuilding `SYSTEM.SYS` from
`system.json` discards it.

**TRS-80 BASIC** (`TRSBASIC.HTML`, role 6) is a TRS-80 Model I Level II
BASIC interpreter written as an ordinary program: no native, Toolbox or RTL
support beyond what this page lists. It owns File (Open..., Save, Save As...,
Quit), Tape (Open..., Rewind) and Run (Run, Break, List, Clear Screen). File →
Open... loads a `.BAS` and mounts anything else as the tape; Tape → Open...
always mounts. `SAVE`/`LOAD`/`KILL "NAME"` use `NAME.BAS`; `DIR` lists `.BAS`
and `.DAT`, `FILES` everything. `TAPE "NAME.DAT"` mounts a card file as the
cassette: each text line is one record; `INPUT#-1,A$` with one string takes
the whole line, otherwise fields split at commas; `PRINT#-1` appends a line.
BREAK is F1 or Pause; Esc quits as in every windowed program.
Programs are tokenized (1-byte keywords) and run 300 statements per frame.
Differences from the 1978 ROM: string space defaults to 16,384 bytes (Level
II starts with 50; `CLEAR n` sets it), numbers are 64-bit with Level II
6-digit printing, `MOD` is accepted, `DEF FN` works (Disk BASIC), and
`PRINT USING`, `ON ERROR`, `USR` and `VARPTR` do not.

| Arena bytes | TRS-80 BASIC use |
|---|---|
| 112–159 | File, tape and current program names |
| 256–799 | Keyword index and number formatting |
| 800–927 | Two descriptors for scrolling |
| 1024–2047 | Typed line and the tokenized direct line |
| 2048–4095 | `CHR$` bytes, array headers, keyword table |
| 4096–6143 | 64×16 screen and the copy last drawn |
| 6144–8191 | Tape read window |
| 8192–12287 | `DIR` catalog page |
| 12288–20223 | Array table, by variable name |
| 20480–22527 | Key queue, tape records, line staging, operator table |
| 24576–89999 | Program lines |
| 90112–221183 | Line number → offset map |
| 221184–299999 | String space (two halves) |
| 300032–380031 | `SAVE`/`LOAD` text |
