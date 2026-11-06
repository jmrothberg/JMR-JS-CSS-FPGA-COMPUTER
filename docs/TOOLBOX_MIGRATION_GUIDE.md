# Converting applications to the JMR Toolbox

This guide documents the hardware primitives and migration contract. Shared
software UI calls and resident linking are in [RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md).
Current build/qualification status is in [TOOLBOX_IMPLEMENTATION_STATUS.md](TOOLBOX_IMPLEMENTATION_STATUS.md).
Exact binary layout: [TOOLBOX_API.md](TOOLBOX_API.md).

## Stable primitive interface

The global native function is `toolbox(operation, a, b, c)`. It returns a number.
Supply all four arguments. Native ID 64 is recognized by the host compiler,
on-machine compiler, Python, and current RTL simulator. Old run75/run76 bits
do not implement it. Use the matched development disk/runtime.

- `toolbox(0,0,0,0)`: version and capabilities. Current value is 65663
  (`0x0001007f`). High 16 bits are version 1; low bits 0–6 advertise operations
  1–7 respectively. Do not probe this native on a bitstream predating it.
- `toolbox(1,source,destination,count)`: copy bytes with memmove semantics,
  including overlap in either direction. Returns count or -1.
- `toolbox(2,destination,value,count)`: fill bytes with the low eight bits of
  value. Returns count or -1.
- `toolbox(3,descriptor,0,0)`: copy a packed surface rectangle to the drawing
  framebuffer, with clipping, scaling and optional transparent zero. Returns
  the source rectangle's pixel count or -1, including when clipping hides it.
- `toolbox(4,descriptor,0,0)`: pattern-fill a rectangle in a packed surface.
  Returns its pixel count or -1. It does not draw that surface to the screen.
- `toolbox(5,payloadOffset,destination,count)`: copy from the verified resident
  SYSTEM.SYS payload. Offset zero is the first payload byte, after the file's
  16-byte header. Returns count or -1. Missing/invalid boot resources return -1.

All memory addresses here are **logical staging-arena byte addresses**, not
physical RAM addresses. The arena is 380928 bytes, numbered 0–380927. Pixel
surface storage uses packed bytes within that arena; hardware's underlying
one-byte-per-word layout is handled by the service. Do not multiply addresses
by two. Zero-length copy/fill ranges may start at the arena end. The entire
range/geometry is validated before writing.

## JavaScript helper names

The canonical source is `resources/toolbox/toolbox.js`:

- `tbMove(src,dst,n)` / `tbFill(dst,value,n)` / `tbResources(offset,dst,n)`
  wrap operations 1, 2 and 5 and return their result.
- `tbU16(address,value)` writes a little-endian 16-bit field, including a
  signed coordinate represented in two's complement.
- `tbSurface(d,base,width,height,stride,bits)` initializes a 64-byte descriptor.
  Bits is 1, 4 or 8; stride is logical bytes per source row. It sets a full
  source rectangle, 1× scale and full-screen clipping.
- `tbRect(d,x,y,width,height)` selects the source rectangle.
- `tbPlace(d,x,y,scale)` sets screen placement and scale 1, 2, 4 or 8.
- `tbClip(d,x,y,width,height)` sets an additional screen clip.
- `tbInk(d,foreground,background)` sets palette indices for monochrome copying
  and pixel values for pattern filling.
- `tbBlit(d)` / `tbPattern(d)` execute operations 3 and 4.

For shared residency, mark HTML with `<!-- jmr-toolbox: resident-v2 -->` and use
the host linker. It supplies all library functions from the matching ROM. For
unmarked standalone compilation, inline only required helpers. External
`<script src>` is not supported. Use the documented `tbDialogOpen` API, not
invented browser methods.

`tbScreen(d)` initializes the 8-bit drawing-framebuffer descriptor;
`tbCopyBits(src,dst)` checks capability bit 5 and performs raw rectangle
transport. See [the full contract](TOOLBOX_API.md#general-bitmap-transport-and-software-copybits).

## Example: a clipped monochrome image

Reserve descriptor bytes 100–163 and image bytes 2000–2031 in this example.
These are examples, not system-wide allocations; choose non-conflicting
addresses for the real application.

```javascript
tbSurface(100,2000,16,16,2,1);
tbFill(2000,255,32);
tbInk(100,0,1);       // fixed palette: black foreground, white background
tbPlace(100,80,80,2); // 16x16 image becomes 32x32 on screen
tbClip(100,88,80,24,32);
var result=tbBlit(100);
```

Keep the existing requestAnimationFrame/presentation path. A blit writes the
back buffer; it does not swap. One-bit rows have their leftmost pixel in the
high bit. Four-bit surfaces use high nibble first and descriptor bytes 48–63
as the palette-index lookup. Eight-bit surfaces contain palette indices
directly. The values are not CSS colors; never assume custom per-app palette
indices from another program. Finder uses RGB332 indices (white255); ordinary application PAL white is1.
Never transfer cached indices between palette owners.

For a pattern, place eight row bytes at descriptor offsets 40–47, set ink and
background, and call `tbPattern`. Pattern coordinates are anchored at the
surface origin, so adjacent rectangles line up. Blit afterward to display it.
Use descriptor flag bit 0 for transparent-zero blits; all other flag bits are
reserved. Bounds/zoom errors return -1 rather than clipping invalid sources.
Only destination drawing is clipped.

## Instructions for the conversion agent

1. Preserve current behavior and the user's newest source edits. Read the app's
   memory map and inventory every buffer before assigning descriptor/surface
   addresses. In MacPaint, the document, Undo and clipboard occupy both halves
   of the arena; they are not free scratch memory.
2. Start with byte-copy and clear loops. Replace an entire transfer with one
   bulk call; do not wrap a one-byte Toolbox call inside the old pixel loop.
   Check that the requested range is owned by the application.
3. Replace repeated image-pixel draws with packed surfaces where the palette
   and source semantics match. Keep solid rectangles as existing `fillRect`
   calls: that operation is already hardware-accelerated. Raw 8-bit rectangle
   transport `toolbox(6,src,dst,0)` is implemented in the new source. Check
   capability bit 5 and use the exact rules in [TOOLBOX_API.md](TOOLBOX_API.md).
   Frozen run77b/run77c builds do not contain it. Packed formats remain on
   operation 3; operation 6 does not implement full QuickDraw raster modes.
4. Preserve Undo, clipping, scrolling, zoom, mouse-down/up edges and event
   listeners. Repaint only changed areas where possible. Do not add per-frame
   disk reads or allocate a second full-screen BRAM image.
5. Check the returned status. Handle unavailable SYS resources with an explicit
   fallback. Resource reads use the boot snapshot; writing SYSTEM.SYS on disk
   does not reload it while programs are running.
6. For software menus use the event-loop contract and scratch ownership in
   RESIDENT_TOOLBOX.md, with TBDEMO.HTML as the example. Preserve application
   About text and dirty-document confirmation. The clean core removed replaced native menus and dialogs; shared JavaScript
   owns them. Essential boot/Terminal/recovery hardware remains. No RTL edits are
   required to convert an application.
7. Compile with `tools.compile_js.compile_html_text` / `encode_html_chunk`,
   respecting the existing code/name/variable limits. Test representative
   pixels, overlap/Undo and a short mouse interaction in Python and FPGA-SIM.
   Do not claim an overall speed factor from reduced call counts alone.
8. Publish HTML and its matching JSH together to the development disk. Preserve
   old board-compatible files and the user's other documents. Do not replace
   the physical board disk with Toolbox applications until its bit supports
   native 64.

This API accelerates primitives; it does not expand the total arena, increase
program limits, alter the VM clock, or automatically port an app's UI.

## Runnable graphics examples

See TOOLBOX_USAGE.md and GRAPHICS.HTML / DAMAGE.HTML in the reviewed examples
package. They cover operations0–7, six raster modes, mask/pattern controls,
physical viewport conversion and deletion-safe previous-frame damage.

`tbRaster(src,dst,mode)`, `tbMask(d,base,stride)`, `tbMaskOff(d)`,
`tbPattern8(d,rows,fg,bg)`, `tbPatternOff(d)` and `tbPaintRect` are shared
software helpers for operation7; see TOOLBOX_API.md for exact fields.
Operation6 copies 8-bit rectangles; operation7 adds byte Boolean modes and
optional one-bit mask/pattern. Both require equal source/destination sizes.
