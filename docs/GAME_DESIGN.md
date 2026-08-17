# Game design (HTML titles for this machine)

How to write a playable `.HTML` game for the JMR JS Computer. The language
and Canvas surface are specified in [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md).
This file is the **authoring** contract: glass, files, input, and what a
title may assume.

The three vendored titles (`INVADERS.HTML`, `PACMAN.HTML`, `DONKEY.HTML`)
are **acceptance tests**, not the only games the machine may run. A new
title is another `NAME.HTML` on the card. Do **not** add title-name gates
in RTL, the compiler, or natives.

---

## Product loop

```text
LOAD "NAME.HTML"
RUN
```

- **One title = one file** in `storage/`. No external `.js` / `.css`.
- Source of truth is the loaded HTML. `RUN` always recompiles it.
- Chrome may open the same file for authoring. PYTHON bytecode → FPGA-SIM
  RTL → BOARD is the machine. Dukpy / a host twin is not.

After adding or changing a title:

```bash
python3 tools/make_sd_image.py create card.img
```

That seeds the FAT image from `storage/` root files (8.3 names on the card).

---

## Glass

- Native canvas is **640×480**. Declare it in markup:
  `<canvas id="…" width="640" height="480"></canvas>`
- **Games fill that field.** Do not letterbox a smaller arcade raster
  (192×240, 224×256, …) with side gutters to “preserve cabinet aspect.”
  READY console letterbox is monitor text only. After `RUN`, the title
  owns every pixel. Scale play (tiles, sprites, HUD) to 640×480.
- `setTransform` is for a title’s own world (DONKEY) if it needs one — not
  a rule to keep original-resolution bars.
- Do **not** assign `canvas.width` / `canvas.height` after load (that
  clears the bitmap and fights HDMI).
- Draw the whole game on Canvas, including score / lives / attract text
  (`fillText`). Do not rely on HTML overlay HUD (`innerHTML`, layout CSS).
- `body { margin:0; background:#000 }` is Chrome-only chrome. The machine
  ignores page CSS.

---

## Input

- Bind keys in the title (`keydown` / `keyup`). Hardware delivers raw
  `key` + `keyCode` only.
- Typical host strings: `"ArrowLeft"`, `"ArrowRight"`, `"ArrowUp"`,
  `"ArrowDown"`, `" "` (Space), `"Enter"`. Also read `keyCode` (37/39/38/40/32/13)
  so a missing `key` string still plays.
- **Do not steal Esc.** Esc is machine BREAK / READY.
- Joystick bits are optional extras; they must not replace HTML bindings.

---

## JavaScript / Canvas you may use

Stay on the **Complete** rows in the compatibility checklist. In particular:

| Use | Do not use |
|---|---|
| `var` / `let` / `const`, `if`, `for` / `while`, functions, objects, arrays | `eval`, `async`/`await`, `fetch`, modules as a real loader |
| `Math.floor` `abs` `min` `max` `random` `sqrt` `Math.PI` | `Math.sin` `cos` `atan2` (not V1 natives — use a lookup table) |
| `requestAnimationFrame`, `setTimeout` | `Audio` / `.play()` (stub / never) |
| `getContext("2d")`, `fillRect`, `clearRect`, `fillStyle` | `getContext("webgl")`, gradients, filters |
| `beginPath` `moveTo` `lineTo` `arc` `stroke` `fill` `closePath` | `scale()` as a separate call; prefer `setTransform` if you must |
| `strokeStyle` `lineWidth` `save` `restore` `translate` `rotate` | shadows, `globalCompositeOperation`, `strokeRect` |
| `imageSmoothingEnabled = false` | bilinear / filtered upscale (indexed FB is nearest) |
| `fillText` (8×8 bitmap on the machine, not TTF) | CSS layout, overlay DOM score |
| `drawImage` / `Image` + `data:image` (ASET → external SRAM) | packing fat art into code, downscaling to “fit BRAM” |

Vector titles (asteroids-style): stroke polylines on black. Close a polygon
by `lineTo` back to the first point (`closePath` is not required).

Bitmap titles: `fillRect` and/or `drawImage`. Keep `data:image` at full
quality; compile-on-RUN puts art in the ASET section, not code BRAM.

Shatter / split / particles are **ordinary JS arrays** of points or objects.
There is no engine primitive for “break an asteroid.” Caps are VM-wide
(`MAX_OBJ` / `MAX_ARR` / `ARR_CAP`) with loud overflow — size effects to
fit, same as every other `NAME.HTML`.

---

## Disk names

Put `storage/NAME.HTML` in the storage folder (stem ≤ 8 letters so the board
8.3 name stays obvious: `ASTEROID.HTML` → `ASTEROID.HTM`).
`python3 tools/make_sd_image.py create card.img` scans `storage/` and copies
what is there. There is no title list to edit.

`LOAD` uses the HTML name. The card is HTML only.

Library example: `MRDO.HTML` is a portrait 384×480 playfield (2× arcade
192×240) centered in 640×480 with black side letterbox. Tunnels are one
character wide (32px).

---

## Checklist before calling a new title done

1. Self-contained `storage/NAME.HTML`, 640×480 canvas, keys in the file.
2. Chrome opens it (authoring look only).
3. `python3 tools/compile_js.py --html storage/NAME.HTML` succeeds (in memory; no sidecar file).
4. `python3 tools/make_sd_image.py create card.img` lists the 8.3 name.
5. PYTHON `LOAD` + `RUN` plays. FPGA-SIM then board follow the usual
   ladder — do not claim silicon from Chrome.
