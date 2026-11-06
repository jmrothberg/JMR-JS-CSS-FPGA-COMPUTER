# Native JavaScript Toolbox — interface v1 (run81 simulation candidate)

The native JavaScript engine remains the CPU. `toolbox(op,a,b,c)` calls a small
100 MHz RTL peripheral through the existing cold service handshake. Python
models the same contract. This interface is new: run75/run76 releases do not
contain it. Development applications using it must be paired with the new
simulator and its matching bitstream. This candidate includes operations 1–12. Its matching FPGA image is required; an older bit with operations 1–7 is insufficient.
Qualification is tracked in [TOOLBOX_IMPLEMENTATION_STATUS.md](TOOLBOX_IMPLEMENTATION_STATUS.md).
Shared software UI calls and resident linking are documented in
[RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md).

## Memory operations

```javascript
var version = toolbox(0,0,0,0); // 69631 (0x00010fff): version 1, operation bits 1–12
var copied = toolbox(1,source,destination,length); // memmove, overlap is safe
var filled = toolbox(2,destination,byteValue,length);
```

Addresses are logical bytes in the existing 380928-byte staging arena,
including its physical discontinuity at byte 73728. This does not allocate
memory or grant access to other applications, firmware, or arbitrary DDR.
The result is the byte count, or -1 for invalid ranges. A zero-length range at
the end is valid. All bounds are checked before modifying memory. Calls are
synchronous; the VM resumes immediately after the peripheral acknowledges.
Display scanout continues. An emergency application stop aborts after any
outstanding memory transaction completes.

MacPaint's document/undo layout is unchanged. Its copyRange now makes one
memmove call; a complete undo snapshot uses two calls instead of 230400
byte-access calls plus JavaScript loop work. This is a call-count reduction,
not a measured speed factor. Its newer strip/block previews remain unchanged.

## Resident system resources

`toolbox(5,payloadOffset,destination,length)` copies bytes from the verified
SYSTEM.SYS payload retained in the existing 24 KiB boot staging area. Offsets
exclude its 16-byte file header. The result is the length, or -1 if the resource
file was absent/invalid, the source is outside 24320 bytes, or the destination
is outside the arena. The application cannot write this shared resource area.
No extra BRAM or DDR reservation is used. Python retains the same boot snapshot;
changes to disk take effect at the next system start, just as on the board.

The legacy font remains little-endian 16-bit rows for existing hardware/UI
consumers. This candidate adds a **TBF1 schema 1 software font block** in the
previously zero tail of the same validated 24320-byte SYS payload:

- Bytes 0..20607: unchanged font, records, index, headings, configuration,
  keyboard, ship and the three 128-byte accessory label bitmaps.
- Bytes 20608..20623: header `<4sBBBBHHHH`: magic TBF1, schema 1, first code 32,
  count 95, height 16, glyph offset 20736, stride 32, width offset 20624, reserved 0.
- Bytes 20624..20718: 95 canonical proportional advances. Bytes 20719..20735
  remain zero for alignment.
- Bytes 20736..23775: 95 glyphs × 32 bytes, 16 rows each, **big-endian/MSB-first**
  for the packed blitter. Bytes 23776..24319 remain zero.

The resource builder derives both representations and advances from the same
validated font source, including glyph overrides. Native consumers stop before
byte 20608; the old broad About allocation 20224..24319 does not mean every byte
was live. The current label writer/read consumer uses 20224..20607 for Note,
Help and Utility; the removed 256×128 About bitmap bank has no live reader.

`tbUIInit` copies/checks the first 8 fixed schema bytes. The host `unpack_ui_font`
decoder checks all 16 header bytes, fixed offsets/stride and advance bounds.
The JavaScript renderer uses fixed schema offsets; it does not interpret or
validate arbitrary relocation fields. Unsupported/missing headers return 0,
suppress `tbText` glyph draws and produce a native-font diagnostic on `tbUIDraw`.

The generated compact advance string is decoded once to the same 95-entry array
before public UI calls. The linker verifies it against the canonical font. This
preserves `tbTextWidth` before initialization and avoids external width reads
per character. It adds 95 one-time `strByte` calls and two typed metadata reads per
UIInit; each glyph miss removes 32 JS `stgRead` and 32 `stgWrite` calls. These
are dispatch counts, not a measured speed factor or an all-path latency claim.
The font change uses the same arena bytes and SYS bank. Operations 8–12 below add typed transport and destination clipping; one session still owns input and frames. Install the matching SYSTEM.SYS with ROM/LNK and relinked clients,
then cold-restart. The native outer SYS format/version/CRC is unchanged.

## Packed surfaces

`toolbox(3,descriptor,0,0)` copies a surface rectangle to the drawing framebuffer.
`toolbox(4,descriptor,0,0)` fills a surface rectangle with an 8-by-8 pattern.
Both return source rectangle width times height, or -1 for invalid geometry.
Present the drawing buffer using the application's usual frame/presentation
path. This service does not flip buffers by itself.

The descriptor is 64 logical bytes. Multi-byte values are little-endian.
The descriptor is captured before writing, so the descriptor may overlap the
surface without changing the current operation.

- Byte 0: version = 1.
- Byte 1: bits per pixel, 1, 4, or 8.
- Byte 2: flags; bit 0 skips zero-valued source pixels when copying. Write
  other bits as zero; bit 1 does not select the framebuffer in this version.
- Byte 3: scale, 1, 2, 4, or 8. Used by copying; fills use source coordinates.
- Bytes 4–7: surface base address, unsigned 32-bit.
- Bytes 8–9: row stride in logical bytes.
- Bytes 10–13: surface width and height, unsigned 16-bit each.
- Bytes 14–17: source x and y, unsigned 16-bit each.
- Bytes 18–21: rectangle width and height, unsigned 16-bit each.
- Bytes 22–25: destination x and y, signed 16-bit each.
- Bytes 26–29: clip x and y, signed 16-bit each.
- Bytes 30–33: clip width and height, unsigned 16-bit each.
- Bytes 34–35: foreground and background palette indices.
- Bytes 36–39: reserved, write zero.
- Bytes 40–47: eight pattern rows, high bit leftmost.
- Bytes 48–63: palette lookup for 4-bit copying.

1-bit pixels use high bit first; 4-bit pixels use high nibble first. The 1-bit
copy selects foreground/background; 4-bit copy uses its lookup; 8-bit copy uses
the byte directly. Palette entries are indices in the current application's
palette, not CSS colors or RGB values. Copying clips against both the descriptor
clip and the 640-by-480 screen, including negative destination coordinates.
Pattern origin is the absolute source surface origin, so adjoining rectangles
have a continuous pattern. Fill masks foreground/background to pixel depth and
preserves adjacent packed pixels.

See `tests/test_toolbox.py` and `sim/tb_toolbox.sv` for complete descriptor
examples and overlap, transparency, clipping, and error cases.

## Architecture status

The clean core uses an 8192-word resident prefix with 8191 mutable words and
one fixed final jump. Replaced native menus/dialogs/document policy are removed;
shared JavaScript owns them. Essential boot/Terminal/recovery UI remains.
The run81 candidate has 44 programs/42 resident clients, including eight CB
variants. Its library uses **8096 of 8191 mutable instructions**, leaving 95 spare.
Native ABI version1 and the64-byte descriptor layout stay the same; capability bits extend through operation12. Candidate factory vectors, ROM identity
package, disk ROM, LNK and relinked clients are generated as one matching set.
There is no new FPGA build, routed INIT audit or physical acceptance for run81;
earlier factory/build results remain historical evidence for those exact inputs.
See [RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md) and the candidate software manifest.

## General bitmap transport and software CopyBits

`toolbox(6,sourceDescriptor,destinationDescriptor,0)` copies an unscaled
rectangle of **8-bit palette indices** between any combination of application
arena surfaces and the persistent drawing framebuffer. It does not copy the
DDR front image, composite overlays, RGB colors or another application's memory.
It does not present the frame. Present through the ordinary animation-frame
path after drawing.

Both descriptors use the existing 64-byte layout, with these rules:

- Version byte 0 is 1, depth byte 1 is **8**, and scale byte 3 is **1**.
- Flag byte 2 is 0 for an arena bitmap or 2 for the drawing framebuffer.
  Transparency and other flag combinations are rejected by this operation.
- Arena base, row stride and surface dimensions describe a bounded arena
  allocation. Screen descriptors must have base 0, stride 640, width 640 and
  height 480. The screen flag never grants access to arbitrary physical memory.
- The source rectangle is bytes 14–21. The destination uses signed x/y at
  bytes 22–25 and the same width/height at bytes 18–21. Its bytes 14–17 are
  ignored. Source bytes 22–33 are ignored.
- The source rectangle must fit its surface completely. Destination drawing
  clips to its surface and to its signed origin/unsigned size clip at bytes
  26–33. Negative destination coordinates retain correct source alignment.
- Both complete descriptors and all bounds are checked before the first
  destination write. They may themselves overlap a destination allocation.
  Invalid descriptors, unequal rectangle sizes or a nonzero fourth argument
  return −1 without modifying either surface.
- Overlap has snapshot/memmove semantics in either direction. Aliased arena
  surfaces must have the same stride; overlapping allocations with different
  strides are rejected. Disjoint arena layouts may have different strides.
- Success returns requested width × height, including clipped pixels; a
  valid zero-area rectangle returns 0. An emergency stop drains any outstanding
  memory/read transaction and can leave an already partially copied rectangle.
  Validation is atomic; execution is not transactional.

`tbScreen(d)` initializes a framebuffer descriptor. `tbCopyBits(src,dst)` checks
capability bit 5 and invokes the raw transfer. `tbSurface`, `tbRect`, `tbPlace`
and `tbClip` describe allocations and rectangles. For an arena destination larger
than 640×480, set its clip explicitly with `tbClip`.

```javascript
// Caller reserves descriptors 100–227 and bytes 2000–6095 exclusively.
tbScreen(100);
tbRect(100,40,60,64,64);
tbSurface(164,2000,64,64,64,8);
var saved=tbCopyBits(100,164); // screen → offscreen bitmap
tbScreen(100);
tbRect(100,0,0,64,64);
tbPlace(100,140,60,1);
var restored=tbCopyBits(164,100); // bitmap → screen at new position
```

The hardware contract is **raw rectangle transport**, not the full Macintosh
QuickDraw CopyBits API. Packed 1/4-bit expansion, scaling and transparent-zero
drawing remain operation 3. Operation 6 rejects packed formats and raster modes;
it never silently truncates colored screen pixels to one bit. Software can
capture indexed pixels into its arena, manipulate those bytes, then restore
them. Future selection, compositing, scrolling and conversion algorithms can
therefore be Toolbox JavaScript updates if they fit existing memory and code
limits. Their performance depends on how much work remains in software.

Adding hardware formats, accelerated raster modes, ports, memory access or
larger instruction-bank capacity still requires RTL changes, Vivado and a new
bit. Available BRAM alone does not change this interface. Shared-library updates
require a matching ROM and relinked clients followed by restart.

Application conversion instructions and the complete helper list are in
[TOOLBOX_MIGRATION_GUIDE.md](TOOLBOX_MIGRATION_GUIDE.md).

## Resident software menus and dialogs

The new resident implementation and complete UI call list are documented in
[RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md). See `storage/TBDEMO.HTML` for a complete
marked client. These are JavaScript library functions, not additional native
hardware IDs. Release/testing status remains in TOOLBOX_IMPLEMENTATION_STATUS.

## General raster extension — operation 7

`toolbox(7,sourceDescriptor,destinationDescriptor,0)` retains operation 6's
geometry, validation, clipping, overlap and requested-pixel-count contract.
Capability bit 6 advertises it. Additional fields are in the source descriptor:

- Byte 36: mode 0 copy; 1 source OR destination; 2 XOR; 3 destination AND NOT
  source; 4 AND; 5 destination palette byte XOR 255. Mode 5 is not RGB inversion.
- Byte 37: bit 0 enables a one-bit mask; bit 1 enables an 8×8 pattern.
  Other bits are invalid. The source geometry remains required in all modes.
- Bytes 40–47: eight pattern rows, most-significant bit first. Byte 34 is
  foreground and 35 background. Pattern phase follows destination x/y modulo 8.
- Bytes 48–51: little-endian mask arena base; bytes 52–53: little-endian stride.
  Mask coordinates are request-relative x/y. Stride must cover ceil(width/8),
  and stride×height must fit the arena. Zero mask bits preserve the destination.
  Masks overlapping an arena destination allocation are conservatively rejected.

`tbRaster(src,dst,mode)` checks capability and writes the mode. `tbMask(src,base,stride)`
and `tbMaskOff(src)` control masking. `tbPattern8(src,rows,foreground,background)`
and `tbPatternOff(src)` control pattern source selection. `tbPaintRect` composes
a patterned screen rectangle. Inspect `resources/toolbox/toolbox.js` for exact
helper signatures. These helpers are updateable software; the validated bulk
transport and Boolean mechanisms are the stable hardware boundary.

## Practical graphics recipes

The isolated TOOLBOX_USAGE.md guide and GRAPHICS.HTML / DAMAGE.HTML examples
show correct physical coordinate conversion, descriptor sizing and previous-frame
damage ownership. The corrected tbPaintRect sets both rectangle sizes and uses8191/8191 resident
words. Keep its matched ROM/LNK/clients together.


## Shared Windows, Ports, Controls and damage in this candidate

Finder, Editor/Note, Reader, Utility and MacPaint use common software window
geometry and drawing ports. Finder owns file records, desktop content and
DESKTOP.FDR. The Toolbox owns hit geometry, drag/grow bounds and the shared
control calculations. The bounded stacking module stores up to eight window IDs
in back-to-front order; activating one removes its old position and appends it.
Closing returns the next front ID. Finder paints and hit-tests in this order.
Single-window applications use the same hit/move/grow implementation. Their
initial geometry stays (8,34,612,420); Finder's disk starts (8,34,548,354).

`tbWindowPart(x,y,wx,wy,w,h)` returns 0 outside, 1 title, 2 close, 3 grow,
or 6 content. `tbWindowAdjust(rect,dx,dy,grow)` updates a caller-owned four-number
rectangle and damages its old and new bounds. `tbWindowBounds()` exposes the
current session rectangle for reading. `tbWindowFocus/Remove/At` are supplied
by `window_client.js`; IDs are integer 0..7, with 255 meaning no window.
`tbControlPart` classifies an axis-aligned scrollbar's arrow/thumb/page regions;
`tbControlValue` clamps movement. Client chrome reports the existing reserved
scroll keys 128..133. No second event listener or frame scheduler is installed.

`tbPortPush(x,y,w,h,dx,dy)` takes an **absolute screen-space** half-open clip
and adds a **local drawing origin** to the current origin. Nested clips
intersect, including empty intersections. There are four fixed levels in a
24-number stack; overflow returns -1 without saving a Canvas frame or changing
clip/origin. Only pop after a successful push. `tbPortPop()` restores Canvas
state, origin and clip; underflow returns -1 without mutation. `tbPortBounds()`
returns the six-number `[left,top,right,bottom,originX,originY]` view for reading;
clients must not mutate it. `tbUIInit` unwinds previous scopes and resets the
hardware clip. The session balances content scopes before drawing global chrome.

Canvas drawing and `tbSessionTransform` include the local origin. `tbText` and
`tbPlaceScreen` do too. **Raw `tbPlace` remains descriptor coordinates**: it must
also work for arena destinations. Raw CopyBits source coordinates, descriptors,
readback and arena writes keep their explicit coordinate contract. The hardware
scissor filters framebuffer destination writes only, across Canvas and Toolbox;
it does not change source reads or operation return counts. `tbPortClip/Reset`
are low-level scissor calls; use balanced push/pop for composable software ports.

`tbDamage(x,y,w,h)` clips to the desktop and accumulates one bounded union.
Empty, negative-size and entirely offscreen rectangles contribute nothing.
`tbDamageClip()` pushes this union as a port; pop it after repaint, then call
`tbDamageClear()`. This is a rectangular damage manager, not an arbitrary Region
list. Finder uses it for activation, moves, resize, close and exposure. File or
selection changes without a narrower known region safely repaint the desktop.

`tbScrollRect(src,dst,x,y,w,h,dx,dy)` in `scroll_client.js` performs overlap-safe
screen-to-screen CopyBits using two caller-owned 64-byte descriptors and the
active local origin. It damages only exposed strips. Displacements larger than
the rectangle damage the whole rectangle without copying. A rejected native
copy returns -1; the app must fall back to full redraw. Editor and Reader use it with descriptors36928..37055; Finder uses17024..17151. Utility retains direct redraw for its small monospace list rather than adding copy read/write traffic. These ranges are
disjoint from their document/index/clipboard/undo/catalog state. Utility bounds its catalog to bytes240..8431, preserving its existing400-file display limit. No screen-sized
backing image is allocated. Document chrome is repainted separately, so a thumb
change does not expand strip damage to the whole content rectangle.

## Shared modules and document ownership

`TOOLBOX.ROM` remains the common instruction bank. Optional common policy also
lives in `resources/toolbox/{window,raster,scroll,draw,chrome,filename,editor}_client.js`.
The shipping HTML files contain exact inline copies, so the standalone compiler
and host compiler see the same code. `python3 tools/sync_toolbox_clients.py`
checks equality; `--write` refreshes copies. These are ordinary application
instructions with private state, not hidden host-only includes or extra hardware.

The resident session exposes `tbSessionChrome(fn)`, `tbSessionNames(fn)` and
`tbSessionDocument(fn)` to register existing client responsibilities. The shared
chrome callback handles drawing (mode 0), pointer classification (mode 1) and
viewport size changes (mode 2), using the common Window and Control primitives.
Editor/Note retain SOURCE save/new/caret/continuation policy in `editor_client.js`;
Note still launches that same Editor, rather than duplicating an editor.
`tbDocumentContinue`, `tbDocumentSaveAs`, `tbDocumentHeader` and
`tbDocumentSuspend` connect those callbacks to the existing session handoff.
Save confirmation still has Save/Discard/Cancel; only a successful committed
save resumes its requested action. SOURCE, clipboard, undo, file buffers and
per-application heap/globals keep their existing owners and lifetimes.

`UISESS.HTML` is the runnable example: shared menus and file callbacks, draggable
and resizable window, nested clipped panel and **Demo → Scroll panel** using
retained pixels plus exposed-strip repaint. Its descriptors 60256..60383 are
separate from its file-transfer buffer. Use a private test disk for its deliberate
SOURCE/file operations. It is part of the same matched shipping set.

## Typed native transport and exact hardware boundary

Operations 8–11 use little-endian bytes, validate the entire span before writes,
and retain the existing staging-arena discontinuity and bounds:

- `toolbox(8,address,0,0)` returns unsigned U32 (0..4294967295), or -1 invalid.
- `toolbox(9,address,value,0)` writes low32 bits and returns 4.
- `toolbox(10,address,first32,second32)` writes both words and returns 8.
- `toolbox(11,address,value,0)` writes low16 bits and returns 2.

`tbU16` and `tbU32` floor numeric inputs before packing, preserving negative
fraction and two's-complement wrap behavior. `tbPair32`, `tbPack16` and the
existing public `tbSessionU32` use the typed services. Capabilities are cached
once per application. Unsupported typed reads return -1 before issuing the
unsupported operation, so old-bit failure cannot masquerade as 0xffffffff.
`tbUIInit` returns 0 and `tbUIDraw` shows “Toolbox needs matching FPGA” when the
required native services are missing.

Operation 12 takes packed signed16 x/y in a, packed unsigned16 width/height in b,
and c=0 to set the destination scissor. c=1 resets to fullscreen and requires
both a=b=0. It returns 1 or -1. Wide endpoint sums are screen-clamped; empty
clips are valid. Program start/stop/Home reset the hardware boundary. Software
ports supply nesting and restore it before chrome; the hardware owns only the
bounded destination comparator. Existing operations 1–7 retain their counted
request/transaction semantics. This is not an arbitrary graphics interpreter.

This candidate adds required RTL transport (typed access and destination clip),
so installing its disk on an older bit is unsupported. After this interface is
included in a qualified bit, window/control policy, CopyBits composition, patterns,
menus, document callbacks and shared software modules can change with a matched
ROM/LNK/clients/resource disk update and cold restart. New bus access, pixel
formats or hardware capacity still require RTL, Vivado and a new qualified bit.
Free BRAM or free software words alone cannot create a missing hardware port.

The document callback is `fn(action,value)`: action 0 returns the current SOURCE
filename as an ASCII array; 1 requests Save with a continuation action; 2 commits
the already selected name/save request; 3 creates a new document; 4 checks whether
a requested new/open/quit action needs dirty confirmation; 5 handles a dialog
result and returns 1 only if consumed. Continuation values are 0 stay, 1 new,
2 open, 3 quit. The resident session handles ordinary file chooser results when
action 5 returns 0. `editor_client.js` is the concrete implementation for both
Editor and Note; applications with other document types retain their own bytes
and save callback rather than impersonating SOURCE ownership.

The filename callback is `fn(codes,suffix,kind)`: kind 0 normalizes/validates the
mutable 8.3 ASCII name array and returns 1 on success; kind 1 returns whether a
catalog name matches the suffix. The resident session writes an accepted name
into its owned 96..111 handoff bytes. The shared filename module supplies this
policy for Editor, MacPaint and UISESS. Reader and Utility do not own Save As.


The shared `draw_client.js` bounds **emission**, not only destination writes.
`tbDrawBounds` returns a temporary reused local-space rectangle intersected with
the active Port; `tbDrawHit` rejects wholly hidden work, and `tbDrawFill` emits
only the intersecting fill. Editor bounds rows and columns, Reader bounds rows
and glyphs, Utility bounds rows/header, and Finder bounds desktop fills and
skips nonintersecting windows/items. Partial glyphs keep their original source
geometry and use the Port for their remaining edge clip. No per-frame allocation
or hardware-loop shortening is implied by the scissor itself.

Text copying uses actual row/column bands, excluding blank margins: Editor's
(28,94,COLS*8,ROWS*16), and Reader's line-start band plus separately repainted
bottom glyph tail. This prevents new text from being mistaken for retained blank
padding. Utility's direct redraw avoids an unnecessary bitmap read+write pass.
Request-work evidence includes retained-copy source reads and destination writes;
it is separate from elapsed latency, FPGA timing and any all-path speed claim.

Finder still scans/sorts the catalog once per drawn normal window; it reuses
that order for its thumb and items during the same cooperative callback.
Reader still walks preceding line heights and proportional source advances to
locate an exposed strip. Bounded emission does not mean every CPU operation is
bounded to the strip. The request-work report includes these remaining VM
native staging/source accesses, separately from framebuffer walk area.
