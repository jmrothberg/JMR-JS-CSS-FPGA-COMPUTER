# Resident JavaScript Toolbox — clean architecture

This is the **run81 implementation/simulation candidate**, not a published
FPGA release. It contains 44 programs/42 resident clients, the existing public
Toolbox API and native graphics services. No FPGA build, benchmark or physical
media update is part of this change.

The library uses **8096 of 8191 mutable instruction words, with 95 spare**; word
8191 remains the fixed final jump. It now fetches normalized SYS glyph bytes
without the old byte-swap loop. Widths remain available before tbUIInit and
per-app mutable state/scratch ownership is unchanged. The new typed font block
fits the existing SYS payload; all legacy bytes 0..20607 are preserved.

The generated candidate ROM, LNK, factory vectors and identity package come
from the same build. A matched disk supplies SYSTEM.SYS and all relinked clients.
Root published files, older routed factory audits and physical acceptance are
separate; these simulation changes do not overwrite those earlier results.
Exact candidate identities and scoped tests are in its software_work manifest.

The same native JavaScript processor runs applications and Toolbox functions.
There is one active application. Only instructions are shared: constants,
name bindings, mutable globals, objects and scratch bytes belong to each app.
This is a bounded native JavaScript system, without a browser or extra CPU.

## Exact boundary in this build

- `TOOLBOX.ROM`: JMRT container version **2**, 16-byte header, 32,768-byte
  instruction payload. Boot checks version, length, CRC and fixed final word
  before commit. Invalid/missing ROM uses the built-in factory bank.
- The virtual prefix is **8192 words**: **8191 mutable instructions** plus
  word 8191, a fixed jump to application address 8192 (`0x0020000b`). The first
  7168 words use BRAM; the remaining mutable tail uses distributed RAM.
  The app's **21504 physical words** remain available for code and metadata.
- `TOOLBOX.LNK`: generated JMTL version 2 linker information for the on-device
  compiler. It binds library names, constants, globals, function entries and
  the exact ROM identity. Update it together with ROM and relinked clients.
- `SYSTEM.SYS`: validated appearance data, including Chicago glyphs. It is
  data, not executable Toolbox code. The existing retained SYS region stays
  unchanged. ROM temporarily stages in otherwise unused SOURCE during boot.
- Native **64**, `toolbox(op,a,b,c)`, reports capability word **0x00010fff**.
  Operations: 0 capabilities; 1 memmove; 2 fill; 3 packed surface blit;
  4 packed pattern fill; 5 verified SYS read; 6 bounded raw rectangle copy;
  7 raster copy with Boolean modes, optional mask and 8×8 pattern;
  8 readU32; 9 writeU32; 10 writePair32; 11 writeU16; 12 destination scissor.
  The candidate requires typed mask 0x780 and clip bit 0x800; older bits fail
  explicitly. No new native ID is introduced.
- Native **65**, `sysDocument(op,ptr,role)`, transfers SOURCE name/metadata or
  initializes an empty document. It does not display dialogs or choose policy.
- Native **66**, `strByte(s,index)`, reads a stored UTF-8 byte from an interned
  string. It returns −1 for unsupported values or bounds. This does not add
  browser string methods or dynamic-string support.
- `fsList(dst,capacity,startRecord)` provides bounded catalog pages. `dst=0`
  preserves the earlier catalog contract. Software filters and displays rows.

`tbCopyBits(src,dst)` composes operation 6. It can copy between the arena and
8-bit indexed canvas, with bounds, clipping and overlap handling. `tbRaster`
uses operation 7 for copy, OR, XOR, destination AND NOT source, AND, or indexed
byte inversion. Inversion means palette index XOR 255, not RGB inversion.
`tbMask`/`tbMaskOff`, `tbPattern8`/`tbPatternOff` and `tbPaintRect` compose this
mechanism. Masks are one bit per request pixel; patterns repeat in destination
coordinates. Packed source expansion remains operation 3.

These primitives support software selection outlines, masked sprites,
patterned brushes, hatching and compositing. Shape/region algorithms can
compose spans and masks in software. They do not imply full QuickDraw,
alpha blending or arbitrary new pixel formats. See [TOOLBOX_API.md](TOOLBOX_API.md).

The Finder executable cache is **192 KiB**, with its saved 72 KiB arena and
SYS/front/SOURCE addresses retained. It gains 32 KiB from the top of the art
window; the total aperture remains 8 MiB. The art/large-transfer limit is now
**6,860,800 bytes**, a 0.4754% reduction. The largest shipped ASET is 2,801,304
bytes, leaving 4,059,496 bytes below that boundary. This avoids repeatedly
loading the larger resident-linked Finder image from disk. Actual cache reuse
and return acceptance are recorded with the build tests.

<a id="shared-ui-calls"></a>

## Shared software UI

`resources/toolbox/ui.js`, `session.js` and `documents.js` own window chrome,
menus with inverse active-title/hovered-row feedback, checks/enabling, modal dialogs, filename editing/caret, paged Open,
Save As/Replace, dirty-document decisions and tool launch policy. The replaced
classic menu/dialog/document and system-action controllers are removed from
the clean core. Boot artwork, Terminal and the ship/keyboard emergency path
remain available independently of application JavaScript. Recovery About
sends key 254 to the application's software UI; Escape still exits the app.

Migrated applications contain **explicit public calls** and marker
`jmr-clean-ui: session-v3-explicit`. The host and on-device compilers consume
these same calls; no desktop-only metadata translation is required:

```js
// Also put <!-- jmr-toolbox: resident-v2 --> in the first 1024 HTML bytes.
var ctx = document.querySelector("canvas").getContext("2d");
tbSessionProperty(ctx,0,6);
tbSessionProperty(ctx,2,"My Tool|One line about the tool");
tbSessionMenus(ctx,["File|Quit=1006","Special|Finder=1016"]);
tbSessionProgram("MYTOOL.HTM");
tbSessionListen("keydown",onKey);
tbSessionFrame(frame);
```

Menu specifications may be one interned string or an array of per-menu
strings. Keep **each string within 255 UTF-8 bytes** for the on-device compiler;
large menu sets use an array, rather than dynamic string concatenation.
The compiler rejects oversized tokens. Host palette generation includes shared
library colors; existing ART palettes remain shared by both compilation paths.
Finder's RGB332 scanout uses UI white 255/cyan 31; other shipped title palettes
use white 1/cyan 6. Disabled labels are stippled, cannot highlight or activate,
and retain a black check marker when checked. Terminal uses the native console
and is separate from shared application menus. About key 254 opens the current
application's dialog. Finder selected labels use white SYS glyphs on black and
retain reverse selection after About dismissal and cached return in the focused
native-instruction check.

Use `tbSessionFrame` for the application's animation scheduling and
`tbSessionListen` for its keyboard/mouse callbacks. UI controls consume input. `tbSessionInvalidate(fn)` supplies a content-only
redraw callback: redraw the current scene without editing SOURCE, advancing
animation or consuming input. Sessions with this callback pause application
frames during menus/dialogs and invoke the redraw to restore covered content.
Games without a separate redraw callback continue their ordinary frames with
the software UI drawn above them, preserving the former overlay behavior. `tbSessionTransform` composes an explicit game
transform with the software viewport. `tbSessionSuffix("PNT")` filters file
choices and supplies a default extension for that application's own I/O.

`tbSessionCodes(text)` converts a bounded interned ASCII label to the byte
array accepted by the lower-level drawing/dialog API.

The lower-level API remains available: `tbUIInit`, `tbWindow`, `tbMenus`,
`tbMenuEnabled`, `tbMenuChecked`, `tbUIPointer`, `tbUIKey`, `tbMenuCommand`,
`tbDialogOpen`, `tbDialogResult`, `tbDialogValue`, `tbDialogSelection`,
`tbUIChanged`, `tbUIDraw`, `tbText`, `tbTextWidth`, `tbBox`. Labels in this
lower-level API are printable ASCII byte arrays. Dialog kinds are 1 alert,
2 confirmation, 3 filename, 4 list, 5 Save/Discard/Cancel, 6 Replace.

Shared sessions reserve **380320–380927**: 512 catalog bytes, 64 descriptor
bytes and 32 glyph bytes. Lower-level callers supply disjoint scratch. Glyphs
are fetched one at a time from the normalized TBF1 font in SYS; a private
4 KiB font copy is unnecessary. See TOOLBOX_API.md for its exact layout and
validation scope. UI initialization and drawing APIs retain their existing ownership.
Private state is packed into ordinary per-app objects at build time. This is
normal compiled JavaScript, with no new execution engine.

SOURCE saves use the console's existing file writer. Byte 64 selects the
explicit continuation; the client clears byte 65 before requesting a save.
Only successful close sets byte 65 to 1 before chaining. The resumed session
consumes that marker and pending action 208–211. Failure shows `?IO` and does
not continue or report SAVED. Writes are not atomic; an I/O failure can leave
a partial file. Note defaults bare filenames to `.JS`; Editor to `.HTM`.

## Safe program switching

Editor NEXT removes the five session listeners and does not schedule another
animation frame before `cdone(128,…)`. Listener removal alone does not halt a
VM waiting for a frame. The run79 console additionally requests a stop and
waits for the VM halt acknowledgement before replacing code. Its bounded full
RTL simulator check passed Finder→Editor→Finder with matching program headers,
VM reinitialization and preserved SOURCE. This is distinct from FPGA timing
qualification and physical testing; consult implementation status for those.
Explicit New intentionally clears SOURCE.

## Updating without Vivado

1. Edit shared JavaScript while preserving the native ABI and capacity.
2. Run `python3 -m tools.toolbox_linker`. This regenerates ROM, LNK, factory
   instruction files and the factory identity package.
3. Relink every resident client using the exact ROM/LNK; the HTML marker is
   `jmr-toolbox: resident-v2`. Never paste the library into a marked client.
4. Generate and audit the disk, publish it as one matched set, then restart.
   Updating the disk ROM on a compatible bit does not synthesize new hardware.

The on-device compiler performs resident linking using the matching LNK and
ROM. Legacy resident-v1 clients are rejected. Retain the prior bit and disk
as a pair. The instruction identity is a compatibility check, not a security
signature. A larger bank, changed hardware access/format, ABI change or clock
change requires RTL editing, Vivado and a newly qualified `.bit`.

A shared-file update takes effect at **cold machine startup with the compatible
FPGA configuration**. Finder Restart and Game Restart reopen a program; they
do not reload the resident ROM. Keep the matching bit and disk together when
starting or resetting the machine.

## MacPaint resource ownership

`PAINT.RSC` holds the original 31 tables: 95 glyphs, 16 icons and widths,
mutable patterns and tones. The 1611-byte file has a 32-byte JMRP v1 header,
fixed offsets and an **additive checksum**, not CRC. It loads into this app's
arena 373504–375114; glyph descriptor 375168–375231. Runtime modifications
remain private to MacPaint. Missing/invalid resources produce a visible error.
The released sources use external ART handles for Finder/Reader fonts so
on-device compilation receives complete, unsquashed executable source.

See [shared Window/Port/Control/Damage and client-module contracts](TOOLBOX_API.md#shared-windows-ports-controls-and-damage-in-this-candidate).
