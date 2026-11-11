# Drawing with the Toolbox

How to pick a drawing call, convert coordinates, and erase what moved.
Call signatures and descriptor fields are in [TOOLBOX_API.md](TOOLBOX_API.md).

| Example | Shows |
|---|---|
| `storage/GRAPHICS.HTML` | Every operation once: memory, packed 1/4/8-bit blits, copy, raster modes, mask, pattern, clipping |
| `resources/toolbox/examples/DAMAGE.HTML` | A moving scene that restores its background from a cache |
| `storage/UISESS.HTML` | A nested port and scrolling by screen-to-screen copy |

## Choose the call

| To draw | Use |
|---|---|
| Solid rectangles, lines, circles, text | Canvas calls (`fillRect`, paths, `fillText`) |
| A 1/4/8-bit sprite, enlarged 1×/2×/4×/8×, with value 0 transparent | `tbBlit` (operation 3) |
| Save, restore or scroll a rectangle of the screen | `tbCopyBits` (operation 6) |
| OR, XOR, AND, invert, a masked shape, an 8×8 pattern fill | `tbRaster` (operation 7) |
| Bulk copy or clear of arena bytes | `tbMove`, `tbFill` |

Replace a whole pixel loop with one call. Do not put a one-byte Toolbox call
inside the old loop.

## Two coordinate spaces

A canvas transform changes canvas calls. It does **not** change Toolbox
descriptors, which are always physical screen pixels. `tbPlaceScreen` and
`tbText` add the current port origin and nothing else.

The game viewport is `setTransform(1,0,0,0.95,0,24)`. The hardware holds the
scale as 16.16 fixed point and truncates, so a logical row `y` lands on
physical row `floor(y*62259/65536)+24`.

To find the physical rectangle a logical rectangle x, y, w, h covers:

```javascript
left   = Math.floor(x);
right  = Math.ceil(x+w);
top    = Math.floor(24+0.95*y) - 1;       // one row of guard
bottom = Math.ceil(24+0.95*(y+h)) + 1;
```

- Clip those edges to the screen and to your cache before computing width
  and height.
- Use the same edges to capture and to restore. Moving the top without
  changing the height leaves trails.
- For a circle, damage the transformed centre ± (radius + 2).
- Widen the rectangle for stroke width and for text above and below the
  baseline.
- A logical height of 1 can truncate to 0 rows. To set one physical pixel,
  switch to the identity transform, `fillRect(px,py,1,1)`, then restore the
  transform.
- For a row of tiles, compute the shared edges once. Truncating each tile's
  height separately leaves gaps.

This covers positive axis-aligned scaling only. Rotation or shear needs all
four corners transformed.

## Erase and restore

1. Lay out descriptors, masks, surfaces and caches at fixed, separate arena
   addresses. Do not borrow bytes another part of the program uses.
2. Draw the static background. Capture it **before** drawing anything that moves.
3. Each frame, keep a list of the rectangles you drew. Keep it separate from
   the actors, so deleting an actor does not lose its rectangle.
4. Next frame, restore **all** old rectangles first, then draw **any** new
   object. Mixing the two lets a restore wipe a sprite just drawn.
5. Record every rectangle the new frame touches: actors, labels, particles,
   selection borders. Overlapping rectangles are fine.
6. When the background itself changes: restore the old actors, clear the
   old tile's whole area, draw the new tile, then capture that area again.
   Transparent pixels do not erase what was there.

After a change of palette, transform or the whole background, redraw
everything and capture again. Cached pixels are palette indices and are
wrong under another palette.

## Descriptor mistakes

- `tbScreen(d)` selects all 640×480. Call `tbRect` on the source **and** the
  destination; both must give the same width and height.
- The destination's source x, y are ignored. Position it with `tbPlace`.
- The source rectangle must fit its surface. Only the destination is clipped.
- A clipped copy still returns the full requested area. Test for −1, not
  for a pixel count.
- Mask rows need ⌈width/8⌉ bytes each and must not overlap an arena
  destination.
- Pattern phase follows destination coordinates in `tbRaster` and surface
  coordinates in `tbPattern`.
- Call `tbMaskOff` and `tbPatternOff`, or rebuild the descriptor, before
  using it for a plain copy.
- `tbCopyBits` takes 8-bit surfaces only. Packed sprites and transparency go
  through `tbBlit`.

## Ports

Inside a window, draw through a port so output is clipped and offset for you.

```javascript
if (tbPortPush(x,y,w,h,ox,oy) >= 0) {
  // canvas calls, tbText, tbPlaceScreen
  tbPortPop();
}
```

Session programs already run inside the window's port. Do not call
`tbPortReset` inside a port.

## Limits

Compiler and runtime limits (locals per function, array size, code size) are
in [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md). Session programs must
keep clear of the [reserved arena bytes](SYSTEM_APPLICATIONS.md#reserved-arena-bytes).
