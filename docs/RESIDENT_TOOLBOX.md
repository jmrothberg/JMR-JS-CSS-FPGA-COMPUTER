# Resident native-JavaScript Toolbox

Development implementation, 2026-11-04. Board qualification is tracked in
`TOOLBOX_IMPLEMENTATION_STATUS.md`; source availability is not a released bit.

The existing native JavaScript VM executes both application and Toolbox code.
There is no added CPU, browser or interpreter. The design follows the Macintosh
separation of applications, shared Toolbox routines, editable resources and
small hardware services; it is not Macintosh binary compatibility.

## Files and memory

- `TOOLBOX.ROM`: 16-byte JMRT header and 16 KiB of native JavaScript instructions.
  The boot loader validates length, version and CRC before committing any words.
  Missing or invalid files leave the FPGA's factory instruction bank intact.
- `SYSTEM.SYS`: fonts, native UI labels, menu/dialog settings and startup artwork.
  Its existing validated payload is retained in external RAM. `tbResources`
  copies it without disk I/O. Shared software text uses its Chicago glyphs.
- `resources/toolbox/toolbox.js`: wrappers for native bulk drawing/memory calls.
- `resources/toolbox/ui.js`: cooperative menus, windows and modal dialogs.
- `storage/TBDEMO.HTML`: complete event-loop example with File and Help menus,
  list selection, name entry and About. Its Open/Save As dialogs demonstrate UI;
  they do not read or write files. Applications perform those operations.

The resident instruction window contains 4096 virtual 32-bit words. It stays loaded while
programs change. The first 3072 words use three spare BRAM tiles; the remaining 1024 are
fixed jump padding with no memory allocation. All 21504 application words
remain in BRAM. Run77c adds one 1024-word tile to the previous 20480-word
application bank so the current MacPaint name table fits. Linked files carry a
4096-instruction prefix which is checked against the bank and omitted from the
physical application RAM. Fetches are redirected into the shared bank. Library
constants, names, globals and heap objects remain per application: residency
shares instructions, not mutable application state or a running background VM.
The 8 MiB external-memory allocation and operating clocks remain unchanged.

At boot the loader temporarily stages ROM in the existing SYS scratch area,
commits it, then loads SYSTEM.SYS into that area. ROM does not take a second
external-memory reservation. A rolling 32-bit instruction identity rejects
mismatched clients (RTL fault 9); this is a compatibility check, not a security
signature. A ROM update requires matching relinked clients and a reboot.

## Build and edit

1. Edit the two JavaScript library sources. Preserve public call contracts.
2. Run `PYTHONPATH=. .venv/bin/python tools/toolbox_linker.py`. It generates
   `storage/TOOLBOX.ROM`, factory `vectors/toolbox_code.hex`, and the RTL factory
   identity package. The factory files are for future FPGA builds; updating a
   compatible disk ROM on a Toolbox-capable bit does not require rebuilding it.
3. Put `<!-- jmr-toolbox: resident-v1 -->` in the first 1024 bytes of each client HTML file. The host
   `tools.compile_js.compile_html_text` linker adds the canonical library and
   marks its JSH. Do not paste the library into a marked client too.
4. Compile all marked clients, validate them, and publish their HTML/JSH pairs
   together with the matching ROM. Do not rename only an old JSH or mix releases.
5. Reboot and check boot, File menus, modal cancellation, keyboard, mouse and
   return to Finder. Keep the previous disk and bit together for rollback.

The standalone COMPILER currently recognizes native `toolbox` calls but does
**not** perform resident linking. Marked source returns `?CE ROMLINK` instead
of minting a broken application. Use the host compiler for marked clients.
For standalone source compilation, inline only the necessary library routines
and omit the marker, subject to ordinary code capacity. This duplicates code.
External `<script src>` is not a library loader.

For a more Macintosh-like dialog, edit `tbUIDraw` and its hit-test coordinates
in `ui.js` together—for example, add a double outline to the default OK button.
Rebuild ROM and relink clients; no RTL change is needed. To edit glyph shapes,
change the SYSTEM.SYS source and repack it. Version 1 software text advances
remain the fixed Chicago advances in `_tbWidths`; changing those metrics also
requires a matching Toolbox update.

## Shared UI calls

Graphics helpers now also include `tbScreen(descriptor)` and
`tbCopyBits(sourceDescriptor,destinationDescriptor)`. See the
[raw bitmap transport contract](TOOLBOX_API.md#general-bitmap-transport-and-software-copybits).
The helper is JavaScript and checks native capability bit 5; the bounded
framebuffer/arena transfer is hardware. This new interface is not in the frozen
run77b/run77c bits. All current run77d/e/f candidates include it and still
require whole-board qualification. After that,
software algorithms using its existing access can change via matching ROM and
clients, without another bit. More code space alone cannot add hardware access.

Labels are arrays of printable ASCII codes, e.g. `[70,105,108,101]` for File.
There is no browser string-method dependency.

- `tbUIInit(ctx, descriptor, font, title)`: initialize one application's UI and
  copy 4096 font bytes from SYS. Returns 1 if available, otherwise 0. Reserve
  the 64 descriptor bytes and 4096 font bytes exclusively; avoid application
  buffers and filesystem catalog output. It disables the native app frame.
- `tbWindow(x,y,w,h,title)`: set window geometry/title.
- `tbMenus(menus)`: install `[[heading, [[label,command,enabled,checked],…]],…]`.
  Empty item labels are separators. Keep menus within the 640-pixel display.
- `tbMenuEnabled(menu,item,on)` / `tbMenuChecked(menu,item,on)`: update items.
- `tbUIPointer(x,y,buttons)`: handle absolute mouse position; buttons is 1 while
  left is held, 0 otherwise. Track held state across move events. Returns 1
  when consumed. Do not forward consumed events to document/game controls.
- `tbUIKey(keyCode,charCode)`: consume modal editing/navigation. Returns 1 when
  consumed. Enter accepts, Backspace edits; lists use keyboard arrows or mouse
  scroll buttons. Code 27 cancels when explicitly delivered to this helper; the
  machine reserves the physical Escape key for emergency application exit. Use
  the Cancel button to dismiss a modal on the board.
- `tbMenuCommand()`: take pending command, or 0. Window close produces 255.
  Application handles saving/dirty confirmation and quitting.
- `tbDialogOpen(kind,prompt,choices,value)`: show 1 alert, 2 confirmation,
  3 name entry, or 4 selection list. Arrays belong to the application. Name
  input is limited to 12 printable characters for the current disk interface.
- `tbDialogResult()`: take 0 pending, 1 accepted, or 2 cancelled.
- `tbDialogValue()` / `tbDialogSelection()`: read entered character array or
  selected zero-based list index. Validate selection before accessing a file.
- `tbUIChanged()`: take redraw flag. Redraw your content first, then call
  `tbUIDraw()` so opaque menus/dialogs cover it. Present through the ordinary
  animation frame; the library does not save/restore framebuffer memory.
- `tbText(codes,x,y)` / `tbTextWidth(codes)`: draw/measure Chicago text.
- `tbBox(x,y,w,h,fill)`: fill and outline a rectangle.

UI service is cooperative: keep each application frame bounded and call the
handlers regularly. The existing hardware Enterprise recovery menu remains
available. Legacy programs retain their existing native menus until converted.

Application close/quit example: after handling dirty-document confirmation,
write a zero byte into application-owned scratch and call `sysRun(pointer,8)`;
then return without scheduling another animation frame. The demo uses
`stgWrite(20063,0); sysRun(20063,8); return;`. This explicitly reloads Finder;
it does not restore its parked VM state. The native File/Quit path remains
available to legacy applications. `cdone()` is a compiler/system-tool chain
report, not a general exit API: in an ordinary RUN application it can leave
an idle VM instead of returning to Finder.

For the Enterprise About box set
`ctx.systemAbout="Program title|One line about the program"`; the system supplies
JMR Enterprises. A software Help/About item may instead open `tbDialogOpen(1,…)`.
The demo includes both forms.

Per-application cost matters: the current linked library adds 106 variable
bindings and 98 constant-pool entries before application additions (the limits
remain 512 variables and 1024 constants). Its 95-entry font-width array uses one
of the VM's large-array slots. The instruction bank saves application instruction
storage, not these bindings or heap allocations. Check the compiled limits when
porting large games; use inline primitive helpers alone when full UI is unneeded.


For the current development package, `build/run77c_toolbox_fixes/test_gui.sh`
opens the main GUI with the matched staged disk. F9 selects FPGA-SIM. TBDEMO's
Open dialog is a UI example, not a disk file reader; the application must supply
file choices and perform fsRead/fsWrite after acceptance.

Coordinates are display pixels. If a game scales or translates its canvas,
save its context, set the identity transform before `tbUIDraw()`, then restore
the context afterward. Mouse coordinates supplied to the UI must likewise be
unscaled display coordinates. The TBDEMO client already uses identity coordinates.

The complete CopyBits development package is `build/run77d_copybits_toolbox/`.
Its candidate `disk/card_run77d.img` is frozen and audited against all 32
programs. Its launcher creates a writable working copy for interactive tests.
Do not mix its ROM/clients with the older run77b/run77c packages.
