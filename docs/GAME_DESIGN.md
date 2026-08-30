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
| **1.0 (now)** | Frozen caps + natives on PYTHON **and** FPGA-SIM. **One disk:** `card.img` for PYTHON / FPGA-SIM / BOARD. Compile when you **make the card** (minted `.JSH`; chip does not compile) | Product: `INVADERS` / `PACMAN` / `DONKEY`. Library must **author inside** V1 walls (see below). `MKPVP.HTML` is the V1 MK-shaped example. |
| **1.5 (planned)** | Console **authoring** (type / paste / edit) **and try to be standalone** (compile-on-RUN) **and** popular JS V1 does not have (`shift`, `Math.sin`/`round`, `isFinite`, `e.code`, …). Same heap/ASET/Canvas. Not MK. | Same V1 titles. Language + LUT: [JMR_JS_COMPATIBILITY.md § V1.5](JMR_JS_COMPATIBILITY.md#v15--type-paste-compile-edit-html-at-ready-no-card-required). |
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

- **One title = one file** in `storage/` (seed). Rebuild `card.img` after
  edits. No external `.js` / `.css`.
- **V1.0 disk is `card.img`:** PYTHON, FPGA-SIM, and BOARD all `LOAD` that
  HTML from the FAT and **`RUN` the minted `.JSH`**. Compile is at card
  create, not a host recompile of `storage/` on `RUN`.
- **V1.0:** the chip does not compile — **compile when you make the
  card** (`make_sd_image.py` mints `.JSH`).
- Chrome may open the same file for authoring. PYTHON bytecode → FPGA-SIM
  RTL → BOARD is the machine. Dukpy / a host twin is not.
- **V1.5 (planned):** type, paste, or edit numbered HTML at READY; **`EDIT n`
  stays**. **Try to be standalone** (compile-on-RUN on the machine) **and**
  popular JS V1 does not have (`shift`, `Math.sin`/`round`, `isFinite`,
  `e.code`, …). Numbers go by 10 so `15` inserts between `10` and `20`;
  `10` + Enter deletes that line, `10 body` also replaces it. Spec +
  LUT/BRAM budget:
  [JMR_JS_COMPATIBILITY.md § V1.5](JMR_JS_COMPATIBILITY.md#v15--type-paste-compile-edit-html-at-ready-no-card-required).

After adding or changing a title:

```bash
python3 tools/make_sd_image.py create card.img
```

That seeds the FAT image from `storage/` root files (8.3 names on the card).
PYTHON, FPGA-SIM, and BOARD all play this `card.img` — rebuild it before F9
if you changed a title.

---

## Glass

- Native canvas is **640×480**. Declare it in markup:
  `<canvas id="…" width="640" height="480"></canvas>`
- **Games fill that field.** Do not letterbox a smaller arcade raster
  (192×240, 224×256, …) with side gutters to “preserve cabinet aspect.”
  READY console letterbox is monitor text only. After `RUN`, the title
  owns every pixel. Scale play (tiles, sprites, HUD) to 640×480.
- **No hidden back buffer.** Run 52 deleted the present pipeline;
  scanout reads the same bank you draw into. Budget for tearing — do
  not rely on “the frame I’m drawing into is invisible until I say so.”
  If a logic step needs an atomic-looking screen, draw fast with the
  hardware paint natives (`fillRect` / `drawImage` / `putImageData`)
  rather than assuming isolation.
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
| `fillText` — one 8×8 bitmap; `ctx.font = "NNpx …"` size only (see wall below) | TTF / `@font-face` / `"Press Start 2P"` / CSS overlay HUD |
| `drawImage` / `Image` + `data:image` (ASET → external SRAM) | packing fat art into code, downscaling to “fit BRAM” |

Vector titles (asteroids-style): stroke polylines on black. Close a polygon
by `lineTo` back to the first point (`closePath` is not required).

Bitmap titles: `fillRect` and/or `drawImage`. Keep `data:image` at full
quality; card-create compile puts art in the ASET section, not code BRAM.

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
`make_sd_image.py create` **mints** `NAME.JSH` from that HTML. PYTHON,
FPGA-SIM, and BOARD all `RUN` that sidecar from `card.img` (compile is at
card-build, not on the chip, not a host recompile of `storage/`). Never copy
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
| **≤16 ASET sprites** (`MAX_SPR` / SPRD descriptors) | One `data:image` per sheet, not per frame. Pack animations into **atlases**; use **9-arg `drawImage(img, sx,sy,sw,sh, dx,dy,dw,dh)`**. Compile refuses >16 (loud) — do not drop art silently. Keep sheets **modest** — not one enormous multi-thousand-pixel-wide image. Wide atlases mean bigger address math per lookup and more SRAM traffic per frame; let the atlas packer split. |
| **No `Object.keys` / `for…in` on RTL** | The compiler lowers `for (k in obj)` to `Object.keys` (native **41**) — that landed 2026-08-21 and works on PYTHON, but there is **no exec64 arm**, so FPGA-SIM faults loud (`fault=5` `fsite=4183`). For a title that must run on the machine, use literal key lists (`loadOne("arena")` …) or numeric loops. |
| **`Math.round` is not a native** | Only `floor` / `abs` / `min` / `max` / `random` / `sqrt`. Shim it in the HTML (`Math.floor(+x + 0.5)`) — unary `+`, `throw`, and the `in` operator all parse since 2026-08-21. |
| **No negative `setTransform` scale** | Mirroring with `setTransform(-1,0,0,1,x,0)` collapses width on PYTHON `_xf` and is unsafe for parity. Ship **left + right** facing sheets (or always draw unmirrored). Positive scale / DONKEY-style world transforms are fine. |
| **Math natives** | Only `floor` / `abs` / `min` / `max` / `random` / `sqrt`. Embed LUTs for angles if needed (ASTEROID pattern). |
| **Heap / array caps (live silicon)** | Fit pass sized these from real titles. Overflow is **loud** (fault 3). Live numbers: [FPGA_FIT.md](FPGA_FIT.md) (`MAX_OBJ=960`, `ENV_DEPTH=384`, `MAX_ARR_LONG=12`, `ARR_CAP=128`). Do not assume the old 1024/512 headroom. **Reuse objects across frames** — a fresh `{x,y,…}` literal every tick burns the 960-object pool (PACMAN-adjacent object-exhaustion). Keep one mutable object and write its fields. Do **not** hoist per-frame **grids/arrays** to startup to dodge GC (that trades slack for a permanent allocation and overflows the array heap). |
| **No per-tick maze flood** | Recursive BFS + `Array(n).fill().map(()=>Array(m))` every ghost cell **froze the board** (HDMI last frame, no `ERROR`). Empty `finder` → no freeze. One-step on the existing map; door `2` walks **up**. Do **not** grow `ENV_DEPTH`/`CSTK` (chip full). [no-maze-flood-on-tick](../.cursor/rules/no-maze-flood-on-tick.mdc). |
| **Nested literal tables** | Hundreds of tiny `MAKE_ARRAY`s for frame rects work only while under the array caps. Prefer compact atlases + small meta, or parallel number arrays, if you approach the cap. |
| **`fillText` is one 8×8 bitmap (no small TTF)** | Family/weight are ignored. Glyph scale is `k = max(1, min(15, round(N * sx / 8)))` where `sx` is the current `setTransform` x-scale (default 1). Each character is **8k × 8k glass pixels**. There is no 6px/10px/12px face — 10px at `sx=1` still paints the same 8×8 as 8px. **Glass-space HUD (PACMAN / INVADERS):** `8px` (native) or `16px` (2×). **World canvas then `setTransform` onto 640×480 (DONKEY / DNKFAST, `sx ≈ 640/1510 ≈ 0.42`):** `16px` still rounds to **k=1** (8 glass px — easy to miss on FPGA-SIM). Use **`32px` minimum** (k=2) for HUD, **`48px`** (k=3) for titles; drop the baseline so `8*k` glass pixels of height stay on screen; ASCII only (codes 32–126 — em-dash paints `?`). Do not add a second font to RTL. |
| **Glass / Esc / one file** | 640×480 fill; Esc = BREAK; no external `.js`. Present is **gone** (run 52) — scanout reads the draw bank; budget tearing, draw fast. |

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

Rules for writing faster HTML games on this machine, from what has
actually been measured to matter, **roughly in order of impact:**

1. **Never do per-tick pathfinding / flood work.** A maze BFS or
   full-grid clone every frame is the one thing proven to **hard-freeze
   the board** (PACMAN / `PACORIG`). One-step “move toward target” on
   the existing map is fine; full recompute is not. Detail below and
   [no-maze-flood-on-tick.mdc](../.cursor/rules/no-maze-flood-on-tick.mdc).
2. **Never mirror sprites with `setTransform(-1, …)`.** Negative scale
   collapses to **1 pixel** here (`max(1, w*sx)`). Draw two pre-made
   sheets (left-facing and right-facing) and pick between them — which
   is what the MK-style titles already do.
3. **Avoid `for…in` / `Object.keys`.** Not on this VM (FPGA-SIM
   `fault=5` / `fsite=4183`). Index arrays or use a fixed key list.
4. **Reuse objects across frames instead of allocating new ones.** The
   heap is a hard-capped pool (`MAX_OBJ=960`). A fresh `{x,y,…}` literal
   every frame burns that pool and is the shape of the PACMAN-adjacent
   object-exhaustion fault. Keep **one mutable object** and write into
   its fields. (Do **not** hoist per-frame *grids/arrays* to startup —
   that is a different trap; see rule 4 in the historic notes below.)
5. **Prefer the built-in draw calls** (`fillRect`, `drawImage`,
   `putImageData`) **over manual pixel loops.** As of run 50/51 these
   run through a dedicated hardware engine at close to **1 pixel per
   clock**. A hand-written loop of `setPixel`-equivalents runs at
   VM-instruction speed, which is dramatically slower.
6. **Keep sprite sheets modest** and let the atlas system pack them,
   rather than one enormous multi-thousand-pixel-wide image. Wide
   atlases mean bigger address math per lookup and more SRAM traffic
   per frame.
7. **Budget for tearing now that present is gone.** Scanout reads the
   draw bank (run 52 deleted the present pipeline). Do not rely on
   “the frame I’m drawing into is invisible until I say so.” If a
   game-logic step needs an atomic-looking screen, draw fast (rule 5
   already helps) rather than assuming isolation.

> **Silicon cost model (run 51 engine + run 52 present-delete) — the
> numbered historic text below this box is the OLD chip.** The raster
> engine (run 51+) moved every paint walk to the 100 MHz clock, and
> the VM runs div7 (14.3 MHz). Present is **gone**, not “burst.”
>
> | Operation | OLD cost | NEW cost |
> |---|---|---|
> | `fillRect` / `clearRect` | 1 px/VM-clock | **~1 px/100MHz clk — ~14x cheaper** |
> | `drawImage` (atlas) | >=2 VM-clocks/px | **~1 px/clk (word-cached)** |
> | `putImageData` | 2+ clk/px | **~2-3 px per 100MHz clk-pair (DMA)** |
> | `fillText` | glyph px via slow rect | rides the engine — cheap |
> | swapBuffers/present | 768k clk WAIT per frame | **deleted (run 52) — scanout reads the draw bank; tearing is real** |
> | per-op JS, property access | ~1 VM-beat/op | **UNCHANGED — now the dominant cost** |
> | string `+` / join (intern FIND) | ~2,000 clk | UNCHANGED |
> | per-frame allocs / GC churn | GC walks | UNCHANGED (one redundant frame-end GC now skipped) |
>
> Once paint is hardware, **JavaScript ops are the remaining currency.**
> INVFAST: paint is 1.3% of its frame, per-op execution is 75%. Hoist
> invariants out of loops; cache `var p = obj.prop` outside hot loops
> (`S_HEAP_CMP` is ~12% of DNKFAST/INVFAST). Full-screen clears are
> cheap now. Full-screen `putImageData` is **not** — DNKFAST measured
> **~0.92M VM clocks** for one 640×480 blit. Dirty-rect that *redraws
> girder tiles under movers* beat that blit. Dirty-rect whose extra JS
> exceeds a cheap `fillRect` is still a loss. Unchanged capacity laws: `fillText(number)` never
> `""+n` (intern table is 1024, never released); no per-frame grid
> hoists to startup; `Array.slice`/allocs in the frame path still cost
> GC.
>
> **HARD WALL — max 16 locals per function** (params + every `var`).
> The 17th env slot faults 3 on the FIRST call, with healthy heap
> counters (INVFAST 2026-08-28: `animate()` hoisted 24 loop temps and
> black-screened at frame 0). Note the trap: the inlining advice above
> pushes loop temps into one function — split hot logic into helper
> functions instead; the wall is per-function and calls are cheap.
>
> Budget at div7: 60 fps = **238,000 VM beats/frame** of JS+logic (paint
> no longer counts against it in practice). INVFAST-style per-pixel-JS
> remains the one pattern the chip cannot save.

> **FAST vs original (FPGA-SIM play `fclk`, 2026-08-29).** Same pixels
> as PACMAN / DONKEY — not fillRect ghosts or stick mazes. Skip the
> first-play `getImageData` hitch; numbers are steady `rafcall` play.
>
> | Title | clocks/frame | vs original |
> |---|---:|---:|
> | PACMAN | **17.38M** | — |
> | PACFAST | **6.26M** | **2.8×** |
> | DONKEY | **2.72M** | — |
> | DNKFAST | **1.65M** | **1.65×** |
>
> PACFAST: maze ImageData is snapshotted *after* the first beans stamp
> so regular 4×4 pellets live in the blit; later frames draw only the
> four pulsing power arcs and punch eaten cells (`data[y][x]=3`).
> `item.coord = position2coord(...)` must mint a new `{x,y,offset}` —
> writing into `item.coord` mutates `_params.coord` (spawn), so
> `resetItems` respawns on the ghost and drains every life. `ARR_CAP=128`
> — one remaining-pellet array of ~300 dots faults at boot.
>
> DNKFAST: first frame draws every girder. Later frames **black-fill**
> Mario/barrel/**Kong** last boxes, then restore overlapping tiles
> (`Platform.drawDirty`). Dirty-only (no erase) smears in empty space.
> Kong poses do not cover each other — erase the 140×144 box or the
> previous animation frame stays. Do not put `_pel` / frame numbers on
> Mario (`OBJ_SLOTS=32`).

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
- **Reuse is required for per-frame *objects*** — one mutable
  `{x,y,…}` written in place, not a new literal every tick
  (`MAX_OBJ=960`). That is not the same as hoisting a *grid*:
  reuse a handful of coordinate / event objects; do not make a
  per-cell array permanent.
- **Check the budget before hoisting anything:** the `arr=` field in the
  monitor `SNAP` line shows live arrays. If a title is near 1536, it has
  no room for a permanent structure of any size.

**The general lesson behind rules 3 and 4:** this machine's limits are
**capacity**, not just speed — 1024 interned strings, 1536 arrays, and
neither is released. An optimization that converts per-frame work into a
permanent allocation can turn a slow title into one that will not start.
Measure capacity headroom before trading for speed.

**5. Do not flood-fill the maze (or any large grid) on a tick.**
PACMAN ghosts called a recursive BFS that built a fresh 2-D
`Array.fill`/`map` grid plus nested closures every cell. The board VM
runs at **12.5 MHz**; that search never finished inside one
`requestAnimationFrame`, so HDMI froze on the last frame with **no
ERROR**. PYTHON and FPGA-SIM still looked playable (not 60 Hz glass).
Empty `finder` → no freeze, ghosts boxed. Chase with **one-step** on the
existing map (door cell `2` walks **up** out of the house). Do **not**
grow `ENV_DEPTH` / `CSTK` — the T200 is full and new bits fail routing.
Do not add a pathfinding opcode. Rule:
[no-maze-flood-on-tick.mdc](../.cursor/rules/no-maze-flood-on-tick.mdc).
`storage/PACMAN.HTML` = one-step chase; `finder` stays `[]`. Eyes home
is `_ghostHome` (in-place BFS, no clone, once per eye tile) — **not**
the old `finder`. `storage/PACORIG.HTML` = original flood (board freezes).

**Confirmed on silicon 2026-08-27.** The old `finder` allocated, *per
call*: `Array(31).fill(0).map(()=>Array(28).fill(0))` = **32 array
objects**, plus `Object.assign({},defaults,params)` and the `start:{}` /
`end:{}` literals = **~36 heap objects before the search even starts**,
then more per `push`. Four ghosts × 60 fps is ~8,600 objects/second
against **284 free slots** (`MAX_OBJ` 960, PACMAN's steady live 676).
A *single frame* of it eats half the headroom. The replacement
`_ghostStep` (chase) and `_ghostHome` (eyes) allocate **no maze clone** —
they write into `_gs` / `_eh` and one reused number queue. That is the
difference between `fault 3` and a playable board.

**6. Never splice an array in the same synchronous burst as a
score/effect/state-change call. Mark it dead; sweep once, after.**

> ⚠️ **Status 2026-08-29: mitigation, not a proven fix.** Applying this
> to the invader-kill path fixed it, board-confirmed. Applying the
> *identical* shape to the saucer-kill path did **not** fix it — same
> fault, still reproduces. So "several calls then splice, synchronous"
> is not the whole mechanism. Board telemetry pinned the fault
> precisely: `fault 3` at the exact instruction that enters
> `bumpScore()`'s call frame from the saucer-hit call site
> (`bumpScore(UFO_SCORES[shotCount & 15])`) — a specific, deterministic
> site, not a vague accumulation (an earlier draft of this note guessed
> "slow cross-frame leak" without that data; retracted — don't repeat
> the guess, follow the telemetry). Why THIS call to `bumpScore`
> faults while the invader-kill's call to the same function does not is
> still open — RTL side is instrumenting the env pool at exactly this
> call boundary. Apply the pattern below anyway — it is free and it did
> fix one real site — but do **not** treat a title as safe just because
> it follows this rule. If a kill event still freezes after converting
> it, get the exact fault `ip` from the architecture monitor and decode
> it against the compiled bytecode before theorizing further.
>
> **2026-08-29 update — disassembled both sites, found the real
> discriminator.** `bumpScore` is small enough that the compiler's
> tiny-callee inliner (`compiler.py:_try_inline_user_call`) splices it
> directly into the caller at **every** call site — it never emits
> `CALL_USER` at all (verified: zero `CALL_USER` targets point at
> `bumpScore`'s nominal entry; that entry is dead code). So "inlined vs
> not" is not the difference — both are inlined, byte-identical bodies
> (`LET_VAR n → score+=n → …`). What differs is the single instruction
> immediately before that inlined body:
> - invader-kill (works): `LOAD_VAR inv` → **`CALL_METHOD`** (`inv.points()`, a class-method call/return) → inlined `bumpScore`.
> - saucer-kill (faults): `LOAD_VAR shotCount` → `LOAD_CONST 15` → `BIT_AND` → **`ARRAY_GET`** (`UFO_SCORES[shotCount & 15]`, no call at all) → inlined `bumpScore`.
>
> So the saucer path is actually *shallower* (no method call/return
> immediately before the inline), not deeper — ruling out "more nesting
> pressures the pool." Two live, precise hypotheses for RTL to test at
> this exact boundary: (a) a `CALL_METHOD` return does something (frees
> a slot / advances a generation counter) that a bare `ARRAY_GET` never
> does, so the pool is only ever "fresh" going into `bumpScore` when a
> call preceded it; (b) the user's original theory — the *value* itself
> (`UFO_SCORES` reaches 300; `invader.points()` tops out at 30) drives
> a different runtime path once bound to `n`. Compile-time constant
> encoding is identical for both magnitudes (checked — not a storage
> difference), so if (b) is right the divergence is at runtime bind,
> not at compile time. This is as far as static bytecode reading can
> narrow it; the rest needs RTL-side instrumentation at ip ~5328 (was
> 5313 before later edits shifted addresses).
>
> **2026-08-29 later — tried the cheap fix, and a data point that cuts
> against it.** Changed the saucer-kill call site to route through a new
> `Saucer.points(shotCount)` method (returns `UFO_SCORES[shotCount &
> 15]`), so it now compiles to `CALL_METHOD` immediately before the
> inlined `bumpScore`, byte-for-byte the same shape as the working
> invader-kill site (verified by disassembly: both are now `LOAD_VAR →
> CALL_METHOD → LET_VAR n → …`). **Untested on hardware — user tests.**
> Caveat found while checking this: the original, never-rewritten
> `INVADERS.HTML` also computes the saucer score as a bare
> `UFO_SCORES[shotCount & 15]` array index (no method call) and does
> **not** freeze on the board. So a bare array index isn't fatal by
> itself elsewhere in the same codebase — which points back at the
> user's competing theory (INVFAST's ~60fps leaves the VM no idle time
> to reclaim/GC between calls the way INVADERS's much-slower loop does)
> as at least as plausible as the CALL_METHOD-vs-ARRAY_GET theory. Both
> remain open; this fix is cheap and harmless either way, but a fault
> after this change would mean the discriminator is something the
> CALL_METHOD theory doesn't explain — check timing/speed next, not
> another inlining variant.
>
> **2026-08-29 board result: fault MOVED, didn't clear.** New fault ip
> 1531 decodes to the `RET_VAL` inside the new `Saucer.points()` —
> literally the instruction that returns `UFO_SCORES[shotCount & 15]`
> to its caller. This kills the CALL_METHOD theory outright: wrapping
> the lookup in a method call didn't add safety, it just relocated the
> exact same `ARRAY_GET` → return sequence one level in, and the fault
> followed it there. `Invader.points()` also ends every branch in a
> `RET_VAL` (`return 30;` / `return 20;` / `return 10;`) with zero
> issue, so returning a value is not the problem — returning **this
> specific array-derived value** is. Open question only hardware
> testing can answer: does *every* saucer kill freeze regardless of
> which of the 16 `UFO_SCORES` entries `shotCount & 15` lands on, or
> only the one worth 300? That distinguishes "the value 300 specifically
> is poisonous" from "an array-sourced return value is poisonous
> regardless of magnitude" — the two remaining live theories.
>
> **2026-08-29 answer: every saucer kill faults, not just the 300s.**
> Kills "value 300 is specifically poisonous" — with 16 equally-likely
> `UFO_SCORES` entries only one of which is 300, a value-magnitude
> theory would predict ~15/16 saucer kills survive. They don't; it's
> 100%. Also: **the user plays this on keyboard, not joystick.** RTL
> proposed a double-hit theory pinned on run 58's un-deduped *joystick*
> fire button (multiple bullets per press → possible double-kill in one
> frame) — that mechanism cannot apply here; the keyboard input path is
> unrelated hardware. If a double-fire/double-hit mechanism is still
> right, it has to be a keyboard-side analog (e.g. key-repeat/debounce
> launching >1 bullet per press), not the joystick PHY fix landing in
> run 59. Relayed to RTL immediately — don't expect run 59's joystick
> dedup to touch this bug.

INVFAST froze on the board — **only** on a hit, never on a miss, 100%
repeatable — the instant a bullet actually killed an alien. Fault 3,
heap counters (`obj=`, `arr=`, `envl=`) completely flat right up to the
exact frame it happens. **It does not reproduce in Chrome** — this is a
machine-specific wall, not a JS bug; testing in a browser will not
catch it.

The shape every broken site shared:

```javascript
// WRONG — several calls, THEN splice, all in one synchronous pass
bumpScore(invader.points());
createParticles(invader, "#BAA0DE");
invaders.splice(i, 1);
projectiles.splice(j, 1);
```

The *original*, never-rewritten `INVADERS.HTML` never hit this: it
wrapped its entire kill (score, particles, splice) in
`setTimeout(() => {...})`, which by construction only ever runs after
that frame's loops have fully finished — never nested inside them. The
FAST rewrite correctly removed `setTimeout` (rule elsewhere: it is a
per-call allocation) but made the splice synchronous instead, so a kill
now runs several function calls deep, mid-iteration, over the very
arrays it's mutating. Whatever pool that pressures (under RTL
investigation — see `docs/TIMING_WALL.md`/ledger; the leading theory is
the per-call environment pool, exhausted faster than sweep reclaims it)
is a real, load-bearing limit, and the old code never exercised it by
accident.

**The fix — mark-and-sweep, not deferred-and-slow:**

```javascript
// RIGHT — mark now (cheap, no allocation); one array-length pass later
invader.dead = true;
bullet.dead = true;
// ... later, once, after this array's iteration is fully done:
function sweepInvaders(list) {
  var i, w;
  w = 0;
  for (i = 0; i < list.length; i++) {
    if (!list[i].dead) { list[w] = list[i]; w = w + 1; }
  }
  list.length = w;
}
```

Same O(n) cost as the splice it replaces — this is not a speed
trade-off, it is free, and it did fix the invader-kill site. It did
**not** fix the saucer-kill site despite the identical shape — apply
the pattern for the free win, but treat the underlying wall as
unresolved. `storage/INVFAST.HTML`'s `updateInvaderCollision`/
`sweepGridInvaders`/`sweepProjectiles`/`sweepInvaderProjectiles`/
`sweepPowerUps` are the reference pattern.

**Rules:**
- Any array holding game entities that can be "killed" (invaders,
  projectiles, power-ups, particles-with-effects) gets a `.dead`
  (or `.alive`) flag set in its constructor.
- On a kill: run the score/effect/state calls, then set the flag. Do
  **not** call `.splice()` in the same statement block.
- Compact with a plain index-rebuilding loop (shown above) called
  **once**, after the loop that was iterating/checking hits is
  completely finished — never from inside a nested helper that's still
  mid-iteration one or two calls up the stack.
- A **bare** removal with no score/effect call before it (an offscreen
  cull, a simple bounds check) is fine to splice directly — it never
  froze. The wall is specifically "several calls, then remove," not
  array removal itself.

### Never gate drawing on an `Image` object's properties

```javascript
if (sprAtlas.width) {                    // WRONG — undefined on the chip
    c.drawImage(sprAtlas, ...);
}                                        // silently falls through to your
                                         // fallback path: game renders WRONG
```

The chip serves `.width`/`.height` **only as the 640×480 canvas default,
and only when the receiver is a primitive**
(`jmr_js_vm_exec64.sv:5361` — *"Not a live object"*). A sprite handle
created by `Image.src = "data:image/..."` **is** a live object, so reading
`.width` on it returns `undefined`. The guard fails, your fallback runs,
and you get a working-but-wrong game with **no error** — MRDO's player
drew as a white block and its apples and enemies vanished, for exactly
this.

Chrome and PYTHON both return the real width, so **this only bites on
silicon** — which makes it expensive to find.

**Rule: blit unconditionally.** The ASET atlas is compiled into the
ProgramImage and is always present by the time your code runs; there is
nothing to wait for and nothing to check.

```javascript
c.drawImage(sprAtlas, fi * 16, 0, 16, 16, x, y, 16 * sc, 16 * sc);
```

Same for `.complete`, `.naturalWidth`, `.naturalHeight`, and `onload`
gating — none of them mean on the chip what they mean in a browser.
`canvas.width` is fine; it is only `Image` receivers that are affected.

The compiler now refuses these at build time (`V1 WALL: <var>.<prop> is
not readable on the V1.0 chip`), scoped to variables provably assigned
`new Image()`.

### Quick self-check for a new title

- Per-tick BFS / grid clone / `finder`? *(FAST rule 1 — freezes the board)*
- `setTransform(-1, …)` to flip a sprite? *(FAST rule 2 — draws 1 px; use L/R sheets)*
- `for…in` / `Object.keys`? *(FAST rule 3 — faults on the chip)*
- Fresh `{x,y}` / `new` / `{}` every frame instead of one reused object? *(FAST rule 4 — burns `MAX_OBJ=960`)*
- Sprites drawn with `drawImage` / `fillRect` / `putImageData`, not per-pixel JS loops? *(FAST rule 5 — hardware ~1 px/clk)*
- One enormous multi-thousand-pixel-wide sheet? *(FAST rule 6 — split; let the atlas packer work)*
- Assuming a hidden back buffer / `present` isolation? *(FAST rule 7 — present is gone; budget tearing)*
- Any `if (img.width)` / `.complete` / `onload` guard around a draw? *(never — undefined on the chip, renders wrong with no error)*
- Any `"" + number`, or a `*_STR` variable holding a score/timer/coordinate? *(intern table is 1024, never released)*
- Any `.map` / `.slice` / `.split` / per-frame **grid** hoisted to startup? *(reduce them; do NOT make grids permanent)*
- Array-heap headroom (`arr=` in SNAP, cap 1536) before you make anything permanent?

A title that answers the FAST rules above and keeps intern/array
capacity has a real chance at 60 fps on the engine. One that paints
sprites as per-pixel JS will land where INVADERS is.

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
   Card image **mints** a `.JSH` (V1.0 compile-at-card-create).
5. `python3 tools/make_sd_image.py create card.img` lists the 8.3 name.
6. PYTHON `LOAD` + `RUN` from **that `card.img`** plays. **FPGA-SIM** then
   board use the same image — do not claim silicon from Chrome or from a
   `storage/`-only PYTHON path.
