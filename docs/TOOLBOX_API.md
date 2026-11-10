# Toolbox API: memory and graphics

Reference for the native `toolbox()` call and the JavaScript helpers built on it.

| For | Read |
|---|---|
| Menus, windows, dialogs, documents, files | [SYSTEM_APPLICATIONS.md](SYSTEM_APPLICATIONS.md) |
| Drawing recipes: coordinates, erase and restore | [TOOLBOX_USAGE.md](TOOLBOX_USAGE.md) |
| How the library is linked, loaded and updated | [RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md) |

Sources: `rtl/engines/jmr_toolbox.sv` (hardware), `functional_model/toolbox.py`
(Python model), `resources/toolbox/toolbox.js` and `ui.js` (helpers).

## The native call

`toolbox(op, a, b, c)` is native 64. Pass all four arguments. It returns a number.
The call is synchronous. It never presents a frame; draw, then let the normal
`requestAnimationFrame` path show the result.

All addresses are **logical byte addresses in the staging arena**, 0–380927
(380928 bytes), the same addresses `stgRead`/`stgWrite` use. The arena is two
physical regions joined at byte 73728; the hardware handles the join. A call
checks its whole range before it writes anything. A bad range returns −1 and
changes nothing. A zero-length range may start at 380928.

| Op | Call | Does | Returns |
|---|---|---|---|
| 0 | `toolbox(0,0,0,0)` | Report the interface | `0x00010fff` (69631): version 1 in the high 16 bits; bit *n*−1 set means operation *n* exists |
| 1 | `toolbox(1,src,dst,n)` | Copy `n` bytes. Overlap is safe in either direction | `n`, or −1 |
| 2 | `toolbox(2,dst,value,n)` | Fill `n` bytes with the low 8 bits of `value` | `n`, or −1 |
| 3 | `toolbox(3,desc,0,0)` | Draw a packed 1/4/8-bit surface rectangle to the framebuffer | source width × height, or −1 |
| 4 | `toolbox(4,desc,0,0)` | Fill a rectangle **inside the surface** with an 8×8 pattern | width × height, or −1 |
| 5 | `toolbox(5,offset,dst,n)` | Copy from the `SYSTEM.SYS` payload loaded at boot | `n`, or −1 |
| 6 | `toolbox(6,srcDesc,dstDesc,0)` | Copy an 8-bit rectangle between arena and framebuffer, any direction | width × height, or −1 |
| 7 | `toolbox(7,srcDesc,dstDesc,0)` | Operation 6 with a Boolean mode, optional mask, optional pattern | width × height, or −1 |
| 8 | `toolbox(8,addr,0,0)` | Read a little-endian u32 | 0–4294967295, or −1 |
| 9 | `toolbox(9,addr,value,0)` | Write the low 32 bits, little-endian | 4, or −1 |
| 10 | `toolbox(10,addr,first,second)` | Write two u32 words | 8, or −1 |
| 11 | `toolbox(11,addr,value,0)` | Write the low 16 bits | 2, or −1 |
| 12 | `toolbox(12,xy,wh,0)` / `toolbox(12,0,0,1)` | Set / reset the framebuffer scissor | 1, or −1 |

For operations 6–11, an argument shown as 0 must be 0 or the call returns −1.
Any other `op` returns −1.

### Operation 5: SYSTEM.SYS bytes

`offset` counts from the first payload byte, after the 16-byte file header.
`offset + n` must not exceed 24320. The call returns −1 when `SYSTEM.SYS` was
missing or rejected at boot. The data is the boot copy: a new file on disk
takes effect at the next cold start. A program cannot write this area.
Payload layout: [SYSTEM_RESOURCES.md](SYSTEM_RESOURCES.md#binary-format).

### Operation 12: scissor

`xy` packs signed 16-bit x (low half) and y (high half). `wh` packs unsigned
16-bit width and height. The rectangle is clamped to the screen. An empty
rectangle is valid and blocks all drawing. The reset form requires `a = b = 0`.

The scissor filters **framebuffer writes** from canvas calls and Toolbox
operations. It does not change source reads or return values. The machine
resets it when a program starts or stops.

## The 64-byte descriptor

Operations 3, 4, 6 and 7 read a descriptor from the arena. Multi-byte fields
are little-endian. The descriptor is read completely before any pixel is
written, so it may lie inside the surface it describes.

| Bytes | Field | Notes |
|---|---|---|
| 0 | version | 1 |
| 1 | bits per pixel | 1, 4 or 8. Operations 6 and 7 require 8 |
| 2 | flags | Op 3: bit 0 = skip source pixels whose value is 0. Ops 6/7: 0 = arena surface, 2 = framebuffer, nothing else |
| 3 | scale | 1, 2, 4 or 8 (op 3). Ops 6/7 require 1 |
| 4–7 | surface base | arena address, u32 |
| 8–9 | row stride | bytes per row |
| 10–13 | surface width, height | u16 each, nonzero |
| 14–17 | source x, y | u16 each |
| 18–21 | rectangle width, height | u16 each |
| 22–25 | destination x, y | signed 16-bit each |
| 26–29 | clip x, y | signed 16-bit each |
| 30–33 | clip width, height | u16 each |
| 34, 35 | foreground, background | palette indices |
| 36 | raster mode | op 7 only, in the source descriptor |
| 37 | raster flags | op 7 only: bit 0 = mask, bit 1 = pattern |
| 38–39 | reserved | 0 |
| 40–47 | pattern | eight rows, high bit is the left pixel |
| 48–63 | op 3: lookup for 4-bit pixels | sixteen palette indices |
| 48–51, 52–53 | op 7: mask base, mask stride | u32 arena address, u16 bytes per row |

Pixel values are **palette indices**, not RGB. Finder's palette is RGB332
(white is 255). Other programs use their own title palette (white is 1). Do not
carry cached pixels from one palette to another.

Packed pixels: 1-bit rows put the left pixel in bit 7. 4-bit rows put the left
pixel in the high nibble.

### Operations 3 and 4: packed surfaces

The surface must lie inside the arena, the stride must hold a full row, and
the source rectangle must lie inside the surface. Otherwise the call returns −1.

Operation 3 draws to the framebuffer at destination x, y. Each source pixel
covers `scale` × `scale` screen pixels. A 1-bit pixel selects foreground or
background, a 4-bit pixel goes through the lookup, an 8-bit pixel is used
as is. Drawing is clipped to the descriptor clip and to the 640×480 screen.
Negative destinations are allowed. The return value is the source area even
when clipping hides every pixel.

Operation 4 writes foreground or background into the surface itself, chosen by
the pattern bit at the pixel's surface coordinates (modulo 8), so adjacent
fills line up. Neighbouring packed pixels in the same byte are preserved.
Use operation 3 afterwards to show the result.

### Operation 6: rectangle copy

`srcDesc` and `dstDesc` each describe an 8-bit surface.

- An arena surface has flag 0 and must fit the arena with stride ≥ width.
- The framebuffer has flag 2, base 0, stride 640, width 640, height 480.
  It is the drawing buffer, not the displayed front image.
- The source rectangle is source bytes 14–21 and must fit the source surface.
- The destination uses its own bytes 18–21 for size, which **must equal** the
  source size, and bytes 22–25 for position. Its bytes 14–17 are ignored.
- Destination pixels are clipped to the destination surface and to its clip
  (bytes 26–33). Negative positions keep source alignment.
- Overlapping source and destination copy correctly. Two overlapping arena
  surfaces must have the same stride.
- The return value is the requested area, including clipped pixels.

A program stop during a copy can leave the rectangle partly written.

### Operation 7: raster modes

Same rules as operation 6, plus fields in the **source** descriptor.

| Mode (byte 36) | Destination becomes |
|---|---|
| 0 | source |
| 1 | destination OR source |
| 2 | destination XOR source |
| 3 | destination AND NOT source |
| 4 | destination AND source |
| 5 | destination XOR 255 (source value unused) |

Modes work on index bytes. Mode 5 is not an RGB inversion.

- **Pattern** (flag bit 1): the source value is foreground or background,
  chosen by the pattern bit at the **destination** x, y modulo 8. Source
  geometry is still required and checked.
- **Mask** (flag bit 0): one bit per pixel of the request, row by row, left
  pixel in bit 7. A 0 bit leaves the destination alone. Stride must be at
  least ⌈width/8⌉ and stride × height must fit the arena. The mask must not
  overlap an arena destination surface.

## Helpers in `toolbox.js`

These are resident library functions. `d` is the arena address of a 64-byte
descriptor that the program owns.

| Helper | Does |
|---|---|
| `tbMove(src,dst,n)` | Operation 1 |
| `tbFill(dst,value,n)` | Operation 2 |
| `tbResources(offset,dst,n)` | Operation 5 |
| `tbU16(addr,n)`, `tbU32(addr,n)` | Operations 11 and 9. `n` is floored first; negative values wrap as two's complement |
| `tbPair32(addr,a,b)` | Operation 10 |
| `tbSessionU32(addr)` | Operation 8 |
| `tbPack16(a,b)` | Returns `a` in the low 16 bits and `b` in the high 16 bits |
| `tbSurface(d,base,width,height,stride,bits)` | Clear and fill a descriptor: whole surface as source rectangle, scale 1, clip 0,0,640,480 |
| `tbScreen(d)` | Descriptor for the framebuffer (640×480, 8-bit, flag 2) |
| `tbRect(d,x,y,width,height)` | Set source x, y and rectangle size |
| `tbPlace(d,x,y,scale)` | Set destination x, y and scale. Raw descriptor coordinates |
| `tbPlaceScreen(d,x,y,scale)` | `tbPlace` plus the current port origin |
| `tbClip(d,x,y,width,height)` | Set the descriptor clip |
| `tbInk(d,foreground,background)` | Set bytes 34 and 35 |
| `tbBlit(d)`, `tbPattern(d)` | Operations 3 and 4 |
| `tbCopyBits(src,dst)` | Operation 6 |
| `tbRaster(src,dst,mode)` | Write the mode into `src`, then operation 7 |
| `tbPortClip(x,y,w,h)`, `tbPortReset()` | Operation 12. Prefer `tbPortPush`/`tbPortPop` |

The helpers for operations 6–12 return −1 when the capability bit is missing.

`tbScreen` selects the whole screen. Follow it with `tbRect` on **both**
descriptors before a small copy. For an arena destination larger than 640×480,
set its clip with `tbClip`.

```javascript
// The program owns descriptors 100–227 and bytes 2000–6095.
tbScreen(100); tbRect(100,40,60,64,64);
tbSurface(164,2000,64,64,64,8);
var saved = tbCopyBits(100,164);          // screen -> arena
tbScreen(100); tbRect(100,0,0,64,64); tbPlace(100,140,60,1);
var restored = tbCopyBits(164,100);       // arena -> screen, new position
```

```javascript
// A 16x16 one-bit image at 2000, drawn 32x32 and clipped.
tbSurface(100,2000,16,16,2,1);
tbFill(2000,255,32);
tbInk(100,0,1);
tbPlace(100,80,80,2);
tbClip(100,88,80,24,32);
var n = tbBlit(100);
```

## Ports, damage, windows and controls (`ui.js`)

### Ports

A port is a clip rectangle plus a drawing origin.

| Call | Does |
|---|---|
| `tbPortPush(x,y,w,h,dx,dy)` | Intersect the clip with screen rectangle x, y, w, h. Add dx, dy to the origin. Returns −1 and changes nothing if four ports are already open |
| `tbPortPop()` | Restore the previous port. Returns −1 if none is open |
| `tbPortBounds()` | `[left, top, right, bottom, originX, originY]`. Read only |

The clip is in screen coordinates. The origin applies to canvas calls,
`tbText`, `tbPlaceScreen` and `tbSessionTransform`. It does **not** apply to
`tbPlace`, descriptor source coordinates or arena writes. Pop once for each
successful push. `tbUIInit` closes all ports.

### Damage

One rectangle that grows to cover everything reported.

| Call | Does |
|---|---|
| `tbDamage(x,y,w,h)` | Add a screen rectangle. Clipped to x 0–639, y 22–479. Empty rectangles add nothing |
| `tbDamageClip()` | Push the damaged rectangle as a port. Repaint, then `tbPortPop()` |
| `tbDamageClear()` | Empty it |

### Window and control geometry

| Call | Returns |
|---|---|
| `tbWindowPart(x,y,wx,wy,w,h)` | 0 outside, 1 title bar (top 24 rows), 2 close box, 3 grow corner (bottom-right 16×16), 6 content |
| `tbWindowAdjust(rect,dx,dy,grow)` | Nothing. Moves (`grow` 0) or resizes (`grow` 1) `rect = [x,y,w,h]` in place and damages old and new bounds. Position stays in x 0–460, y 22–360; size in 180–612 by 120–420 |
| `tbWindowBounds()` | The session window `[x,y,w,h]`. Read only |
| `tbControlPart(p,start,length,arrow,thumbStart,thumbLength)` | Along one axis: 0 outside, 4 first arrow, 5 last arrow, 8 before thumb, 7 thumb, 9 after thumb |
| `tbControlValue(value,delta,max)` | `value + delta` kept in 0–`max` |

Text and box drawing (`tbText`, `tbTextWidth`, `tbBox`) are listed with the
UI calls in [SYSTEM_APPLICATIONS.md](SYSTEM_APPLICATIONS.md#manual-ui).

## Optional client modules

These are not in the resident library. Each is a file in `resources/toolbox/`,
copied between `// BEGIN shared NAME` and `// END shared NAME` lines in the
HTML programs that use it. `python3 tools/sync_toolbox_clients.py` checks the
copies; `--write` refreshes them.

| Module | Provides |
|---|---|
| `raster_client.js` | `tbMask(d,base,stride)`, `tbMaskOff(d)`, `tbPattern8(d,rows,fg,bg)`, `tbPatternOff(d)`, `tbPaintRect(src,dst,x,y,w,h,rows,fg,bg)` |
| `scroll_client.js` | `tbScrollRect(src,dst,x,y,w,h,dx,dy)` |
| `draw_client.js` | `tbDrawBounds(x,y,w,h)`, `tbDrawHit(x,y,w,h)`, `tbDrawFill(ctx,x,y,w,h,color)` |
| `window_client.js` | `tbWindowFocus(id)`, `tbWindowRemove(id)`, `tbWindowAt(i)` |
| `chrome_client.js`, `filename_client.js`, `editor_client.js` | Session callbacks. See [SYSTEM_APPLICATIONS.md](SYSTEM_APPLICATIONS.md#callbacks) |

- `tbMask` and `tbPattern8` set the operation 7 fields in a source descriptor.
  Turn them off, or rebuild the descriptor, before reusing it.
- `tbPaintRect` fills a screen rectangle with a pattern, at port coordinates.
  It overwrites the two descriptors `src` and `dst`.
- `tbScrollRect` moves the pixels of a port-local rectangle by dx, dy with one
  screen-to-screen copy and damages the exposed strips. It overwrites the two
  descriptors `src` and `dst`. If |dx| ≥ w or |dy| ≥ h it copies nothing,
  damages the whole rectangle and returns 0. On −1, redraw everything.
- `tbDrawBounds` returns the part of a port-local rectangle that is inside
  the current port, as `[left, top, right, bottom]` in a reused array.
  `tbDrawHit` is true when any part is visible. `tbDrawFill` fills only the
  visible part.
- `tbWindowFocus` moves window id 0–7 to the front of a back-to-front list
  and returns it, or −1. `tbWindowRemove` deletes an id and returns the new
  front id, or 255 if none. `tbWindowAt(i)` returns the id at position `i`,
  or 255.

## What needs a new bitstream

A change to `resources/toolbox/*.js` needs a relink and a cold start, nothing
more. A new operation, pixel format, memory range or a larger library bank is
a hardware change. See [RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md#updating-the-library).
