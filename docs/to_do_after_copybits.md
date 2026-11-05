# To do after CopyBits

Raw 8-bit transport is now in the working source; frozen run77b/run77c bits
do not contain it. Do not edit these games until the new interface has passed
matched-runtime acceptance. The call is
`toolbox(6, src, dst, 0)`. Its implemented subset is specified in
[TOOLBOX_API.md](TOOLBOX_API.md#general-bitmap-transport-and-software-copybits). The descriptor bytes are
in [TOOLBOX_API.md](TOOLBOX_API.md).

Start only when operation 6 is advertised. Operations 1–5 are capability bits
0–4, so operation 6 is bit 5:

```javascript
if ((toolbox(0,0,0,0) & 32) == 0) stop
```

A result of -1 from `toolbox(6, …)` means stop. Do not write a byte loop
instead.

## What an agent copies

The framework is `after_copybits_example.html` at the top of this repository.
It is not a card program. Do not copy it into `storage/`. Do not mint it.

Paste its functions into the program's existing script. There is no
`<script src>`. Delete every function the program does not call. The demo
at the bottom of the file is the pattern, not part of the paste.

1. Draw the still picture once, with no movers in it.
2. `prepareMaps()` once, then `savePlayfield()` once.
3. Each later frame: `cbBack(mover)`, draw the mover, `cbKeep(mover, x, y, w, h)`.
4. When the still picture itself changes, draw that change, then
   `noteChange(x, y, w, h)` for that rectangle only.

The saved picture is the full 640×480 glass at arena byte 0. Descriptors
are at 308000 and 308064. Move the picture and both descriptors together
if those bytes are taken. Do not overlap them. MacPaint and Finder already
use the arena. Do not edit those two.

Each game below is an edit to its draw path, not a new program.

## Games to edit

| File | Replace | Lines to change | Difficulty |
|---|---|---|---|
| `storage/DNKF.HTML` | The black box plus the girder and ladder redraw under Mario, each barrel, and Kong | about 25 | Easy, except world coordinates. Glass x is `worldX * (640/1510)`. Glass y is `24 + worldY * ((480-24)/685)`. |
| `storage/MKBA.HTML` | The full arena picture drawn every frame. Restore each fighter's old box. | about 20 | Easy |
| `storage/MKCA.HTML` | Same as MKBA | about 20 | Easy |
| `storage/BOMBFAST.HTML` | The tile redraw under movers. One rectangle per mover. | about 25 | Easy |
| `storage/FLDF.HTML` | The every-cell grass fill. `noteChange` when a tower is placed. | about 40 | Medium |
| `storage/CENTIPED.HTML` | The full clear and the redraw of every mushroom. `noteChange` when a mushroom is hit. | about 40 | Medium |
| `storage/PACFAST.HTML` | The full maze `putImageData` every frame. `noteChange` on the eaten pellet. | about 50 | Medium |
| `storage/MRDOF.HTML` | The full dirt `putImageData` every frame. `noteChange` on the dug cell. | about 50 | Medium |

Easy means the still picture never changes during play. Medium means one
small `noteChange` after the picture changes. None of these is a rewrite.
All eight together are a few hundred lines.

## Leave these alone

`INVF.HTML`, `ASTEROID.HTML`, `TANK.HTML`, `BOXES.HTML`, `BOXES2.HTML`,
`AURORA.HTML`, `MISSILE.HTML`, `DOOM3DFI.HTML`, `2DFANTA2.HTML`. Their
frames are black or drawn new. CopyBits has nothing to put back.
`MACPAINT.HTML` and `FINDER.HTML` are not in this list.
