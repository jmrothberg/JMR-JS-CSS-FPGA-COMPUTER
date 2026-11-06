# Native JavaScript Toolbox — interface v1 (qualified run78 hardware)

The native JavaScript engine remains the CPU. `toolbox(op,a,b,c)` calls a small
100 MHz RTL peripheral through the existing cold service handshake. Python
models the same contract. This interface is new: run75/run76 releases do not
contain it. Development applications using it must be paired with the new
simulator and its matching bitstream. The clean build includes operations 1–7.
Qualification is tracked in [TOOLBOX_IMPLEMENTATION_STATUS.md](TOOLBOX_IMPLEMENTATION_STATUS.md).
Shared software UI calls and resident linking are documented in
[RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md).

## Memory operations

```javascript
var version = toolbox(0,0,0,0); // 65663: version 1, capabilities mask 127
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

The shared JavaScript Toolbox uses these exact glyphs and can read the
label records and dialog settings without opening the disk for each operation.
The existing resource format remains compatible. It does not yet permit
changing the native proportional font advances or defining new native dialogs.

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
Run78 hardware passed strict FPGA implementation qualification. The delivered
64 MiB disk has 44 programs and 42 resident clients, including eight CB variants.
The library uses **8191 of 8191 mutable instructions**, leaving zero spare.
The native ABI and qualified bit are unchanged: audited factory ROM `fd89c8…`
stays in the bit, while disk ROM `f6f805…` replaces it at startup. Factory INIT
and later disk-software evidence are distinct. Final software checks were
bounded; physical user display/input acceptance remains pending. See
[RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md).

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
