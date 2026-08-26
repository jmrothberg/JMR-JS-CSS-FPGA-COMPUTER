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
  synthesize Arrow/Space/Enter — still read `keyCode`. The stick’s four face
  buttons are only two bits: A + C + stick-click = FIRE1 (Space); B + D =
  FIRE2 (Enter). Map those to fire / start / jump — not four distinct actions.

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

## Writing a title that is FAST (measured, not guessed)

Correctness gets you a title that runs. This section gets you one that
plays. Every number here is **measured** — from the PACMAN and INVADERS
frame profiles in
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md#measured-clock-sinks--pacman-play-frame-2026-08-20-statehist), not estimated.

### The budget — this is the number that matters

The board's VM runs at **12.5 MHz** (`ui_clk`÷8; see
[TIMING_WALL.md](TIMING_WALL.md)). So one frame at 30 fps is:

| | |
|---|---|
| **30 fps budget** | **416,667 VM clocks per frame** |
| 60 fps budget | 208,333 clocks |

Measured against that budget, today's titles:

| Title | clocks/frame | actual fps | over budget |
|---|---:|---:|---:|
| PACMAN play | 3,500,000 | **3.6 fps** | **8×** |
| INVADERS play | 10,600,000 | **1.2 fps** | **25×** |

**Read that before optimizing anything.** These are not titles that need
trimming; they need a different drawing strategy. And note the budget is
8× tighter than the 100 MHz numbers the ledger was profiled at.

### What each primitive actually costs

| Operation | Cost | Full-screen (640×480) | % of a 30fps frame |
|---|---|---:|---:|
| `fillRect` | **1 px/clock** | 307,200 clk | **74%** |
| `putImageData` | **2 clk/px** | 614,400 clk | **148%** |
| string `+` / join | **~2,000 clk each** (intern FIND, O(names)) | — | 0.5% each |
| per-op decode | ~1 clk/op | — | — |

**One full-screen clear costs three quarters of your entire frame.** One
full-screen `putImageData` is over budget by itself, before any game
logic runs.

### The four rules, ranked by measured impact

**1. Never draw sprites with per-pixel JavaScript loops.**
This is why INVADERS is the slowest title on the machine: it paints
sprites as a loop of tiny `fillRect`s, and **66% of its 10.6M-clock frame
is per-op execution cost**. A 1×1 `fillRect` pays a full native call —
the call overhead dwarfs the one pixel it paints. Use `drawImage` with a
sprite `Image`, which moves the pixels inside the chip instead of one JS
op per pixel. This single change is worth more than everything else here
combined.

**2. Do not repaint what did not change.**
`fillRect` is 1 px/clock, so painted **area** is the cost — not the number
of calls. Clearing the whole screen each frame spends 74% of the budget
before drawing anything. Repaint only dirty regions: the sprites that
moved, plus the background patch they vacated. PACMAN spends 17% of its
frame on `fillRect` painting roughly two full screens.

**3. Never turn a number into a string. Pass the number to `fillText`.**

> ⚠️ **This rule was wrong in an earlier revision of this file and broke
> five titles.** The earlier text said "build strings once, not per frame,"
> which read as an invitation to hoist `""+score` into a variable. Doing
> that **converts a free path into a leaking one.** Corrected below.

The intern table holds **1024 entries and never releases them.** Every
*distinct* string a title creates takes a permanent slot. So this:

```javascript
_SCORE_STR = "" + _SCORE;                    // WRONG — new slot per score value
context.fillText(_SCORE_STR, x, y);
```

mints a new permanent entry for every score value the player reaches —
0, 10, 20, 30 … — and after ~750 of them the machine halts with
`ERROR: HM VALUE64: string table overflow (1025 > 1024)`. Chrome has no
such table, so this passes in a browser and dies here.

`fillText` renders a **number** argument without interning anything:

```javascript
context.fillText(_SCORE, x, y);              // RIGHT — costs nothing, leaks nothing
```

**Rules:**
- **Pass numbers directly to `fillText`.** Never `"" + n`, never a
  `*_STR` mirror variable.
- **Draw a label and its value as two `fillText` calls**, not one joined
  string: `fillText("SCORE", x, y)` then `fillText(score, x+48, y)`.
  Literals cost one permanent slot each — fine. *Values* must never
  become strings.
- **Only if a title already builds strings every frame** is there
  anything to optimize, and the fix is to remove the concatenation, not
  to cache it. Caching a value-derived string still leaks one slot per
  distinct value.
- A string built from a **bounded** set (level names, a fixed menu) is
  safe. A string built from a score, timer, coordinate, or any unbounded
  counter is a leak.

Cost, for reference: each intern FIND walks up to ~2,000 clocks, and
PACMAN spends **15%** of its frame in `S_JOIN_FIND`. But the overflow is
the real hazard — it stops the machine, not just slows it.

**4. Reduce allocation — but do NOT convert temporaries into permanents.**

> ⚠️ **This rule was also wrong in an earlier revision and broke PACMAN.**
> It said "allocate your arrays once at startup and reuse them." On this
> machine that trades a *transient* cost for a *permanent* one, and there
> is almost no permanent capacity left.

Allocation churn does cost: GC is PACMAN's largest sink at **24% of the
frame, 4 mark-sweeps per frame**. But the array heap holds **1536 arrays**
and PACMAN already sits at **1352 live — about 180 slack.** Hoisting a
few per-frame grids to startup made it permanent and produced
`ERROR: HM VALUE64: array heap overflow (1549 > 1548)`.

**A temporary array is free capacity — GC reclaims it. A hoisted one is
capacity you never get back.**

**Rules:**
- **Do not pre-allocate grids, maps, or scratch structures at startup**
  to avoid per-frame allocation. That is the trade that breaks titles.
- The right fix is to **allocate less**, not to allocate earlier:
  compute values without building an intermediate array, avoid `.map` /
  `.slice` / `.split` where a plain loop over the existing array works,
  and do not build a lookup table for something you can index directly.
- **Reuse is safe only for a small, fixed number of objects** — one
  reusable event object or coordinate object, not a per-cell grid.
- **Check the budget before hoisting anything:** the `arr=` field in the
  monitor `SNAP` line shows live arrays. If a title is near 1536, it has
  no room for a permanent structure of any size.

**The general lesson behind rules 3 and 4:** this machine's limits are
**capacity**, not just speed — 1024 interned strings, 1536 arrays, and
neither is released. An optimization that converts per-frame work into a
permanent allocation can turn a slow title into one that will not start.
Measure capacity headroom before trading for speed.

### Quick self-check for a new title

- Sprites drawn with `drawImage`, not per-pixel loops? *(rule 1)*
- Any full-screen clear or `putImageData` in the frame loop? *(rule 2 — that alone can exceed the budget)*
- Any `"" + number`, or a `*_STR` variable holding a score/timer/coordinate? *(rule 3 — this overflows the 1024-entry intern table and halts the machine)*
- Any `[]`, `{}`, `new`, `.map`, `.slice`, `.split` inside the frame loop? *(rule 4 — reduce them; do NOT hoist them to startup)*
- Does the title have array-heap headroom (`arr=` in SNAP, cap 1536) before you make anything permanent? *(rule 4)*

A title that answers "no" to the last three and "yes" to the first has a
real chance at 30 fps. One that answers the other way will land where
INVADERS is.

### What is being fixed in the machine (do not design around these)

Some of the cost is the chip's, and is on the roadmap — do not contort a
title to dodge these:

- intern FIND hash→id (removes most of the 15% string cost)
- `putImageData` 2→1 clk/px
- `fillRect` 4 px/clock
- skipping the scheduled frame-end GC when a forced GC already ran

Rules 1–4 above are the **authoring** half, and they are worth more than
the machine-side fixes for a title shaped like INVADERS.

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
