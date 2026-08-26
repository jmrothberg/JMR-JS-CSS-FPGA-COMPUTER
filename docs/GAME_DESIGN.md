# Game design (HTML titles for this machine)

Words: [README.md — Words used](../README.md#words-used-in-this-project).

How to write a playable `.HTML` game for this **NLISC-JS** machine
(Native Language Instruction Set Computing — JavaScript is the
**ISA** Instruction Set Architecture; HTML is the title file). The
language and Canvas surface are specified in
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md). This file is the
**authoring** contract: glass, files, input, and what a title may assume.

This is **copy 2** of “do not hardwire game names / write inside Version 1.0
walls” (copy 1 is `.cursor/rules/no-game-hardwire.mdc` +
`html-game-v1.mdc`). Measured Version 2.0 numbers for `MK.HTML` live in
[JMR_JS_COMPATIBILITY.md § Version 1.0, 1.5, and 2.0](JMR_JS_COMPATIBILITY.md#version-10-15-and-20)
— do not raise caps in RTL for one title.

**Product generations:**

| Gen | Meaning | Titles |
|---|---|---|
| **1.0 (now)** | Frozen caps + natives on PYTHON **and** FPGA-SIM. **BOARD:** compile when you **make the card** (minted `.JSH`; chip does not compile) | Product: `INVADERS` / `PACMAN` / `DONKEY`. Library must **author inside** V1 walls (see below). `MKPVP.HTML` is the V1 MK-shaped example. |
| **1.5 (planned)** | Console **authoring** (type / paste / edit) **and try to be standalone** (compile-on-RUN on the machine; drop card `.JSH` if it fits) | Same V1 titles/walls. Not MK. Glass + LUT/BRAM budget: [JMR_JS_COMPATIBILITY.md § V1.5](JMR_JS_COMPATIBILITY.md#v15--type-paste-compile-edit-html-at-ready-no-card-required). |
| **2.0 (compiler front end started)** | Machine changes so **`MK.HTML` as embedded today** runs | Acceptance: `MK.HTML`. Need **`MAX_SPR` ≥ 518**, asset bank **8 MB** (or more; ASIC: one chip, simple port), dotted **`new mk.…`**, **`.call`/`.apply`**, **`Object.keys` on exec64**, **`Math.round`**. Parse gaps (unary `+`, `for…in`, `throw`, `in`) landed 2026-08-21. Detail: [JMR_JS_COMPATIBILITY.md § Version 1.0, 1.5, and 2.0](JMR_JS_COMPATIBILITY.md#version-10-15-and-20). |

V1 / V1.5 / V2 surface backlog: [JMR_JS_COMPATIBILITY.md § Version 1.0, 1.5, and 2.0](JMR_JS_COMPATIBILITY.md#version-10-15-and-20).
Agent rule: `.cursor/rules/html-game-v1.mdc`.

The three vendored titles (`INVADERS.HTML`, `PACMAN.HTML`, `DONKEY.HTML`)
are **V1.0 acceptance tests**, not the only games the machine may run. A new
title is another `NAME.HTML` on the card. Do **not** add title-name gates
in RTL, the compiler, or natives.

---

## Product loop

```text
LOAD "NAME.HTML"
RUN
```

- **One title = one file** in `storage/`. No external `.js` / `.css`.
- Source of truth is the loaded HTML. PYTHON / GUI **`RUN` recompiles it**.
- **V1.0 BOARD:** the chip does not compile — **compile when you make the
  card** (`make_sd_image.py` mints `.JSH`).
- Chrome may open the same file for authoring. PYTHON bytecode → FPGA-SIM
  RTL → BOARD is the machine. Dukpy / a host twin is not.
- **V1.5 (planned):** type, paste, or edit numbered HTML at READY; **`EDIT n`
  stays**. **Try to be standalone** (compile-on-RUN on the machine). Numbers
  go by 10 so `15` inserts between `10` and `20`; `10` + Enter deletes that
  line, `10 body` also replaces it. Spec +
  LUT/BRAM budget:
  [JMR_JS_COMPATIBILITY.md § V1.5](JMR_JS_COMPATIBILITY.md#v15--type-paste-compile-edit-html-at-ready-no-card-required).

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
  Poll `joy()` each frame (bits: 1=up 2=down 4=left 8=right 16=FIRE1 32=FIRE2)
  and OR into the same held flags as keys (`JOYDEMO.HTML`). RTL may also
  synthesize Arrow/Space/Enter — still read `keyCode`.

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

`LOAD` uses the HTML name. The card holds `.HTML` / `.HTM`. **V1.0:**
`make_sd_image.py create` **mints** `NAME.JSH` from that HTML so the FPGA
can `RUN` with no PC (compile is at card-build, not on the chip). Never copy
a stale `.JSH` from `storage/`. **V1.5 tries standalone** compile-on-RUN on
the machine. The card builder copies **root** `storage/*.HTML`. `storage/games_*`
is the upstream archive — not DIR, not the card. Same-stem `NAME.JS` /
`NAME.JSB` are leftover demos, not product twins.

Library example: `MRDO.HTML` is a portrait 384×480 playfield (2× arcade
192×240) centered in 640×480 with black side letterbox. Tunnels are one
character wide (32px).

---

## V1.0 authoring walls (library titles — learned from MK / MKPVP)

Stay on **Complete** rows **and** these machine caps. Prefer hacking the
**HTML** for library demos; grow the **ISA** only on the V2.0 backlog (do
not title-gate RTL).

| Limitation | How to write the HTML |
|---|---|
| **≤16 ASET sprites** (`MAX_SPR` / SPRD descriptors) | One `data:image` per sheet, not per frame. Pack animations into **atlases**; use **9-arg `drawImage(img, sx,sy,sw,sh, dx,dy,dw,dh)`**. Compile refuses >16 (loud) — do not drop art silently. |
| **No `Object.keys` / `for…in` on RTL** | The compiler lowers `for (k in obj)` to `Object.keys` (native **41**) — that landed 2026-08-21 and works on PYTHON, but there is **no exec64 arm**, so FPGA-SIM faults loud (`fault=5` `fsite=4183`). For a title that must run on the machine, use literal key lists (`loadOne("arena")` …) or numeric loops. |
| **`Math.round` is not a native** | Only `floor` / `abs` / `min` / `max` / `random` / `sqrt`. Shim it in the HTML (`Math.floor(+x + 0.5)`) — unary `+`, `throw`, and the `in` operator all parse since 2026-08-21. |
| **No negative `setTransform` scale** | Mirroring with `setTransform(-1,0,0,1,x,0)` collapses width on PYTHON `_xf` and is unsafe for parity. Ship **left + right** facing sheets (or always draw unmirrored). Positive scale / DONKEY-style world transforms are fine. |
| **Math natives** | Only `floor` / `abs` / `min` / `max` / `random` / `sqrt`. Embed LUTs for angles if needed (ASTEROID pattern). |
| **Heap / array caps (live silicon)** | Fit pass sized these from real titles. Overflow is **loud** (fault 3). Live numbers: [FPGA_FIT.md](FPGA_FIT.md) (`MAX_OBJ=960`, `ENV_DEPTH=384`, `MAX_ARR_LONG=12`, `ARR_CAP=128`). Do not assume the old 1024/512 headroom. |
| **Nested literal tables** | Hundreds of tiny `MAKE_ARRAY`s for frame rects work only while under the array caps. Prefer compact atlases + small meta, or parallel number arrays, if you approach the cap. |
| **Glass / Esc / one file** | 640×480 fill; Esc = BREAK; no external `.js`. |

**V1 MK-shaped title:** `storage/MKPVP.HTML` — 3 atlases (arena + Sub-Zero +
Kano), L/R sheets, slim 2P engine, V1 Math only.

**V2.0 goal title (Chrome / authoring today; machine later):**
`storage/MK.HTML` — measured needs: **518** ASET sheets (`MAX_SPR` ≥ 518),
**~4.63 MB** indexed pixels → rebuild asset bank to **8 MB** (or more;
ASIC must stay **single-chip** with a **simple** SRAM port — no fancy
multi-die access). Also compiler **`new mk.…`** and **`Function.prototype.call`/`.apply`**
(42 sites — the super-constructor pattern; a real VM capability, not a
shim), plus **`Object.keys` on exec64** and **`Math.round`**. The smaller
parse gaps (unary `+`, `for…in`, `throw`, `in`) are **done**. Full table: [JMR_JS_COMPATIBILITY.md § Version 1.0, 1.5, and 2.0](JMR_JS_COMPATIBILITY.md#version-10-15-and-20).
Until those land, do not expect `LOAD "MK.HTML"` + `RUN` on FPGA-SIM.

---

## Checklist before calling a new **V1.0** title done

1. Self-contained `storage/NAME.HTML`, 640×480 canvas, keys in the file.
2. Stays inside **V1.0 authoring walls** (sprites ≤16, no `for-in` /
   `Object.keys`, no negative scale mirror, V1 Math).
3. Chrome opens it (authoring look only).
4. `python3 tools/compile_js.py --html storage/NAME.HTML` succeeds (in memory).
   Card image **mints** a `.JSH` (V1.0 BOARD compile-at-card-create).
5. `python3 tools/make_sd_image.py create card.img` lists the 8.3 name.
6. PYTHON `LOAD` + `RUN` plays. **FPGA-SIM** then board follow the usual
   ladder — do not claim silicon from Chrome or from PYTHON alone.
