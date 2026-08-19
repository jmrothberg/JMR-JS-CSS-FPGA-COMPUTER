# JMR JS compatibility matrix (target titles)

Target games drive the language/API set. **Not a full web browser** — no
Fetch/XHR, no WebGL, no general browsing. Goal (same idea as NLISC-BASIC on
T100): **NLISC-JS** — HTML titles, JavaScript ISA, the CSS a game actually
needs — **JMR bytecode VM** on PYTHON → FPGA-SIM → BOARD → ASIC.

**No cheats:** dukpy/Duktape/V8/QuickJS/browser must not be the product CPU.
Chrome may open the same `.HTML` for authoring only. See `CONSTITUTION.md` and
`.cursor/rules/no-dukpy-cheat-native-cpu.mdc`.

## Reference titles (on disk)

**One title = one file.** User always:

```text
LOAD "NAME.HTML"
RUN
```

| Game | Source (LOAD) | On RUN (invisible) |
|---|---|---|
| Space Invaders | `INVADERS.HTML` | compile → ephemeral ProgramImage (code + ASET art) |
| Pac-Man | `PACMAN.HTML` | compile → ephemeral ProgramImage (code + ASET art) |
| Donkey Kong | `DONKEY.HTML` | compile → ephemeral ProgramImage (code + **full-res** ASET art) |
| Asteroids (library) | `ASTEROID.HTML` | compile → ephemeral ProgramImage (vector stroke; no ASET) |
| Aurora (library) | `AURORA.HTML` | compile → ephemeral ProgramImage (fillRect; no ASET) |
| Joystick (library) | `JOYDEMO.HTML` | compile → ephemeral ProgramImage (stick + arrows; no ASET) |
| Mr. Do! (library) | `MRDO.HTML` | compile → ephemeral ProgramImage (portrait 384×480 in 640×480 letterbox; no ASET) |

**Compile-on-RUN (hard):** source of truth = loaded `.HTML` (editor line
numbers). `RUN` **always** recompiles into one versioned in-memory
**ProgramImage**. No sidecar compile file on disk or on the card.

**Asset bank (external SRAM — no `NAME.DAT`):** great graphics stay at full
quality. `RUN` emits `data:image` art (per-title 256-entry palette +
full-resolution 8-bpp banks) as the **ASET section** of the ProgramImage;
the loader streams it into the **external 4 MB SRAM asset bank**
(IS61WV204816 contract — see `docs/ARCHITECTURE.md`). Bytecode carries
descriptors (w, h, SRAM offset) only. Do not pack Donkey sheets into code
BRAM or downscale them to fit.

**Code debt (2026-08-13):** ASET/asset-bank path is **in progress**.
Historic trap: `tools/compile_js.py` `_extract_data_uri_sprites` packed
pixels into the ProgramImage and downscaled (`w*h > 180000`) with an 8-color palette.
PYTHON compile-on-RUN **is** default. Full-game PYTHON ↔ FPGA-SIM match is
**not** done.

Same-stem `NAME.JS` / `NAME.JSB` are **legacy**, not product twins.
`storage/games_*` (not DIR / not card).

```text
LOAD "INVADERS.HTML"
RUN
# PYTHON / FPGA-SIM / BOARD — compile current HTML → ProgramImage → JMR VM

LOAD "PACMAN.HTML"
RUN

LOAD "DONKEY.HTML"
RUN
```

FPGA-SIM / BOARD must RUN vendored HTML via **compile-on-RUN → bytecode into
code BRAM** (never stale sidecar, never Invaders hex, never dukpy). `?NH` =
temporary debt. Do **not** fake FPGA-SIM with `JMR_SIM_HOST=1`.

**Constitution mandate:** product is NOT DONE until all three HTML titles
LOAD + RUN playable on PYTHON **bytecode** → FPGA-SIM RTL → BOARD. HTML
decides keys. No `.bit`/`.bin` until FPGA-SIM is green and the user GUI-tests.

---

## Agent surface checklist (HTML / JavaScript / CSS / Canvas)

**This is the implement-them-all list** for debugging and implementation
agents (same job as the BASIC command list on the sibling). The Frozen ISA
tables later in this file record what the three HTML compiles *emit*. This
section is what to build, what not to build, and whether it is **Complete**
or **TBD**.

A `.HTML` game file is one user document with **four different machines**
inside it. This product is a **Canvas game computer**, not a browser.

| Layer | What it is | Who owns it on this machine | User analogy |
|---|---|---|---|
| **HTML** | Document structure: tags, ids, one `<canvas>`, `<script>` | Tiny DOM stub + compile-on-RUN loader | The *file* you `LOAD` |
| **JavaScript** | Language: variables, functions, objects, events, timers | **The CPU ISA** (bytecode → VM engines) | BASIC statements |
| **CSS** | How HTML *elements* look (layout, fonts, page colors) | **Almost none in V1** | Not BASIC `COLOR` — that is Canvas paint |
| **Canvas** | A **bitmap drawing API** from `canvas.getContext("2d")` | Hardware Canvas / blitter / FB | BASIC `PLOT` / `LINE` / sprites |

Rule of thumb:

- If it is a **tag** (`<canvas>`, `<script>`, `id="…"`) → **HTML**.
- If it is **logic** (`if`, `for`, `function`, `addEventListener`) → **JavaScript**.
- If it styles the **page** (`display:flex`, `font-family` on a `div`) → **CSS** (do not build a layout engine).
- If it **paints pixels** (`fillRect`, `drawImage`, `fillStyle`) → **Canvas**.

`c.fillStyle = "red"` is **not** a CSS engine. It is a Canvas paint color
string. `el.style.display = "none"` is a **DOM stub**, not CSS layout.

Product ISA freeze: **implement what the three titles emit**, then stop. Do
not grow “popular HTML5” past that unless a title proves it. Priority is
“how likely an HTML/JS arcade game needs it,” clipped by that freeze.

| Pri | Meaning |
|---|---|
| **P0** | Play-blocking for classic 2D HTML games; all three titles need it |
| **P1** | At least one of `INVADERS` / `PACMAN` / `DONKEY` needs it |
| **P2** | Common in HTML5 games, **not** in the three compiles — do not grow V1 |
| **never** | Browser/OS. Stub or refuse. |

**Status column (this row only — not “are the games done?”):**

PYTHON truth for language / DOM / Canvas / host builtins is **JsHwVm** on a
`FLAG_VALUE64` ProgramImage (`tests/test_bytecode_js.py` `test_hw_value64_*`
or an HTML ProgramImage HM test). The old `Machine()` / `_run_js_frames`
Chunk VM is **not** Complete.

| Status | Meaning |
|---|---|
| **Complete** | **This row works on JsHwVm.** Title not playable does not un-Complete it. Chrome/dukpy do not count. |
| **TBD** | Missing, broken, or **FM only — HM test missing**. |
| **never** | Do not implement. |

Monitor verbs (`DIR`, `LOAD`, …) are Machine console, not JsHwVm; Complete
there means the READY command works. Do **not** TBD `DIR` because INVADERS
is unfinished.

When a TBD language/Canvas row starts working: add `test_hw_value64_*` (or
HTML ProgramImage on JsHwVm), then flip **this row** to Complete.

### HTML — document container (not a layout browser)

HTML is the **LOAD file**. `RUN` compiles the `<script>` text and finds the
canvas. The machine does not paginate, reflow, or browse.

#### Implement

| API / construct | Pri | Why games use it | Status |
|---|---|---|---|
| `LOAD "NAME.HTML"` file | P0 | Source of truth | Complete |
| `<canvas id width=640 height=480>` | P0 | The glass | Complete |
| `<script>` inline | P0 | Game code | Complete |
| `document.getElementById` | P0 | Find canvas / stub nodes | Complete |
| `document.querySelector` | P0 | INVADERS uses `"canvas"`, `"#scoreEl"` | Complete |
| `document.createElement` | P1 | Titles construct nodes | Complete |
| `hidden` / ignore overlay markup | P0 | INVADERS has START/HUD divs; **paint HUD on Canvas** | Complete |
| Multiple `<script>` in one file | P1 | Concatenate; don’t poison globals | Complete |
| `<img>` / `data:image` in HTML | P1 | Art → ASET → SRAM on RUN | Complete |
| `<title>`, charset, comments | P2 | Ignore | Complete |

#### Do not implement

| API | Status | Why not |
|---|---|---|
| Layout / reflow / scrolling | never | Not a browser |
| `<iframe>`, navigation, forms as widgets | never | OS/browser |
| External `.js` / `.css` files | never | One title = one `.HTML` |
| Real HTML overlay HUD (`innerHTML` score) | never | Draw `fillText` on Canvas; overlay is stub |
| `document.write`, `innerHTML` as a parser | never | Not the ISA |
| SVG / MathML / video | never | Out of V1 |

INVADERS still talks to stub nodes (`style.display`, `innerHTML`,
`button.click`) to skip a START menu. That is **DOM stub**, not HTML layout.
Prefer Canvas HUD (`fillText` already in the title).

### JavaScript — the CPU (this is the BASIC command list)

JavaScript **is** the instruction surface. Bytecode is the hidden encoding,
like BASIC tokens.

#### Language — implement

| Feature | Pri | Titles | Status |
|---|---|---|---|
| Number (IEEE-754 binary64) | P0 | all | Complete |
| bool / string / undefined / null | P0 | all | Complete |
| `let`/`var`/`const`, `if`, loops | P0 | all | Complete |
| functions / `this` / closures | P0 | all | Complete |
| objects / arrays | P0 | all | Complete |
| `typeof` | P1 | PACMAN | Complete |
| `class` | P1 | DONKEY (flattened) | Complete |
| ES modules | P1 | DONKEY | Complete (flatten to IIFE; never a real loader) |
| `JSON.parse` / `stringify` | P1 | INVADERS, PACMAN | Complete |
| `Math.floor/abs/min/max/random/sqrt` | P0 | INVADERS, PACMAN | Complete |
| `Date` / `Date.now` | P1 | INVADERS, PACMAN | Complete |
| Array: `push/splice/forEach/map/filter/fill/join/indexOf/find` | P1 | PACMAN, INVADERS | Complete |
| `String.replace` + RegExp stub | P1 | PACMAN | Complete |
| `Object.assign` / `Function.bind` | P1 | PACMAN | Complete |

#### Language — do not implement (V1)

| Feature | Status | Why |
|---|---|---|
| `eval` / `Function("code")` | never | Second compiler in the game |
| `async`/`await`, Promises, `fetch` | never | Network browser |
| `Proxy`, WeakMap, Symbols, BigInt | never | Not in the three compiles |
| Web Workers / SharedArrayBuffer | never | Second CPU |
| Node / `require` / `fs` | never | Not this machine |

#### Host / window builtins (JS calling the machine)

| API | Pri | Titles | Status |
|---|---|---|---|
| `requestAnimationFrame` | P0 | all | Complete |
| `setTimeout` / `clearTimeout` | P0 | all | Complete |
| `setInterval` / `clearInterval` | P1 | games in general | Complete |
| `addEventListener` / `removeEventListener` | P0 | all | Complete |
| `dispatchEvent` + `new KeyboardEvent` | P1 | DONKEY boot Enter | Complete |
| `keydown` / `keyup` (raw key + keyCode) | P0 | all | Complete |
| `Image` + `src` + `onload` | P0 | INVADERS, DONKEY | Complete |
| `localStorage.getItem/setItem` | P1 | INVADERS | Complete |
| `console.log` | P1 | INVADERS, DONKEY | Complete |
| `window.open` | never | PACMAN | never |
| `Audio` / `.play()` | never | INVADERS tags | never |

HTML decides key bindings. Hardware/VM deliver raw keycodes only.

### CSS — almost none (the easy “don’t” list)

**V1: do not implement a CSS engine.** Games draw on Canvas.

`fillStyle = "#33ff66"` is Canvas. Harvest those strings into the **title
palette**. That is not CSS.

#### Implement (tiny, only as paint / stub)

| Item | Pri | What it really is | Status |
|---|---|---|---|
| Named / hex / `rgb()` color **strings** for Canvas | P0 | Paint LUT | Complete |
| `el.style.display = none/block` | P1 | DOM property stub (INVADERS menus) | Complete |
| `body { margin:0; background:#000 }` | never | Chrome authoring only | never |

#### Do not implement

| Feature | Status | Why |
|---|---|---|
| Selectors, cascade, specificity | never | Browser |
| Flexbox, grid, media queries | never | Layout |
| `@font-face` / TTF | never | PYTHON 8×8 bitmap; RTL `fillText` is bitmap/rect stub |
| CSS animations / transitions | never | Use JS + Canvas |
| `classList`, computed style | never | Not the ISA |

If a future title cannot run without CSS layout, that is a **new product
decision**, not a silent engine.

### Canvas — the graphics ISA (`getContext("2d")`)

This is the list that matches BASIC’s “implement the drawing commands.”
`getContext` is the **door**. Without it, every later `c.fillRect` is dead.
INVADERS does:

```javascript
const canvas = document.querySelector("canvas");
const c = canvas.getContext("2d");
```

Only `"2d"`. `"webgl"` is never.

#### Methods / properties — implement

| API | Pri | Titles | Status |
|---|---|---|---|
| `getContext("2d")` | P0 | all | Complete |
| `fillRect` | P0 | all | Complete |
| `clearRect` | P0 | all | Complete |
| `fillStyle` (hex/named) | P0 | all | Complete |
| `drawImage` (3/5/9 arg) | P0 | INVADERS, DONKEY | Complete |
| `beginPath` / `moveTo` / `lineTo` / `arc` / `fill` / `stroke` | P1 | PACMAN, INVADERS | Complete |
| `closePath` | P1 | PACMAN, MRDO | Complete |
| `quadraticCurveTo` | P1 | PACMAN | Complete |
| `strokeStyle` / `lineWidth` | P1 | PACMAN, INVADERS | Complete |
| `imageSmoothingEnabled` | P1 | DONKEY, MRDO | Complete (false = nearest; indexed FB has no bilinear) |
| `fillText` | P0 | all HUDs | Complete |
| `measureText` | P1 | PACMAN, DONKEY | Complete |
| `font` / `textAlign` / `textBaseline` | P1 | PACMAN, DONKEY | Complete |
| `setTransform` | P1 | DONKEY 1510×685→640×480 | Complete |
| `save` / `restore` | P1 | INVADERS, PACMAN | Complete |
| `translate` / `rotate` | P1 | INVADERS | Complete |
| `globalAlpha` | P1 | INVADERS | Complete |
| `getImageData` / `putImageData` | P1 | PACMAN cache | Complete |
| `canvas.width` / `height` | P0 | all | Complete |

Fonts are **never** Chrome TTF (PYTHON 8×8 bitmap; RTL may be a rect stub
until the bitmap path matches). Indexed FB may stub `globalAlpha`. Do not
let JS resize HDMI; glass stays 640×480.

#### Common in HTML5 games — do not grow V1 unless a title emits it

| API | Pri | Status | Why skip |
|---|---|---|---|
| `strokeRect`, `clip` | P2 | never | Stroke four `lineTo`s or `fillRect` borders; `closePath` is Complete |
| `scale()` (separate from `setTransform`) | P2 | never | DONKEY uses `setTransform` |
| `bezierCurveTo`, `ellipse` | P2 | never | PACMAN uses `arc` + quadratic |
| Gradients / patterns / shadows / filters | P2 | never | Heavy; not in titles |
| `globalCompositeOperation` | P2 | never | Indexed 8-bpp glass |
| `createImageBitmap`, `OffscreenCanvas` | never | never | Browser workers |
| `getContext("webgl")` / WebGPU | never | never | Different GPU |
| `toDataURL` / `toBlob` | never | never | No download |

### Other machine surfaces (not HTML/JS/CSS/Canvas)

#### Monitor commands (READY prompt — the BASIC verbs)

From `functional_model/machine.py` HELP. Same verbs on PYTHON and FPGA-SIM;
do not add RTL-only commands.

| Command | Pri | Status | Notes |
|---|---|---|---|
| `DIR` | P0 | Complete | Names only (HTML / optional `.JS`) |
| `LOAD "NAME.HTML"` | P0 | Complete | Quotes optional |
| `RUN` | P0 | Complete | Verb works (compile-on-RUN). HTML titles not playable is Canvas/JS TBD, not this row. |
| `LIST` / `LIST n-m` / MORE | P0 | Complete | HTML line numbers |
| `EDIT` / `INSERT` / `DELETE` | P0 | Complete | Editor = HTML text |
| `SAVE` / `NEW` / `CLS` / `HELP` / `MEM` | P1 | Complete | |
| `ESC` | P0 | Complete | Machine BREAK; games must not steal Esc |

#### Asset / compile pipeline (not a JS API)

| Item | Pri | Status | Don’t |
|---|---|---|---|
| Compile-on-RUN → ephemeral ProgramImage | P0 | Complete | Do not write a sidecar file. On-chip compiler is still TBD (host compile today). |
| ASET → external 4 MB SRAM | P0 | Complete | Downscale for code BRAM; `NAME.DAT` |
| Dual FB 640×480 | P0 | Complete | 160×120 leftover |

#### Input

| Item | Pri | Status | Don’t |
|---|---|---|---|
| Raw key down/up | P0 | Complete | No title keymap in RTL. |
| Joystick bits | P1 | Complete | Do not replace HTML bindings |

#### Audio / net / storage extras

| Item | Pri | Status |
|---|---|---|
| `Audio.play` | never | never |
| Fetch / XHR / WebSocket | never | never |
| `localStorage` | P1 | Complete (in-memory; card persist not required yet) |

### Agent workflow

1. Work **one layer** at a time. `getContext` is Canvas, but it is reached
   through HTML (`querySelector("canvas")`) + JS (`CALL_METHOD`).
2. PYTHON bytecode first, then hardware model executing the **same
   ProgramImage**, then RTL.
3. Do not add P2 / `never` APIs to “make games nicer.” The three compiles
   **are** the ISA.
4. Flip **TBD → Complete** on a language/Canvas/host row when a
   `test_hw_value64_*` (or HTML ProgramImage on JsHwVm) proves **that row**.
   Do not TBD `DIR` because INVADERS is unfinished. Do not mark Complete
   because Chrome or the old Chunk VM looked good.

---

## Frozen machine contract

This contract is shared by the Python hardware model and RTL. The functional
Python `Chunk` is a compiler oracle only; parity requires executing the exact
serialized ProgramImage bytes.

### ProgramImage

- Magic remains `JSB1`; `flags` carries the versioned section contract.
- One image contains code words, constants, names/classes, opcode-to-HTML
  source lines, sprite descriptors, palette, and ASET payload.
- The image exists in memory for the current `RUN`. Tests may keep golden
  images under test/build output, but product storage contains `NAME.HTML`.
- Every section has an explicit byte length and must fit before execution.
  Bad magic, unknown required flags, overlap, truncation, or capacity excess
  halts with a machine error; no section is silently clipped.

### 64-bit Value ABI

All stack, variable, object, array, environment, callback, and native-held
values are one 64-bit word.

- Any word not using the reserved tagged-NaN prefix is an IEEE-754 binary64
  Number. Numeric NaNs are canonicalized to `0x7ff8000000000000`.
- Tagged values use prefix `0x7ff9` in bits 63:48, a four-bit kind in bits
  47:44, a 12-bit generation in bits 43:32, and a 32-bit payload in bits
  31:0.
- Kinds are: undefined `1`, null `2`, bool `3`, string `4`, object `5`, array
  `6`, function `7`, element `8`, and lexical environment `9`.
- Bool payload is exactly 0 or 1. Handle kinds use `(generation,index)`;
  dereferencing a free slot or mismatched generation is a loud stale-handle
  error. Handles remain stable across collection. **Do not skip gen-match**
  in FPGA-SIM RTL to hide exec64/parent dual-copy skew (2026-08-17 overnight
  cheat). One physical SRAM; FPGA-SIM is the `.bin` path.
- `+`, `-`, `*`, `/`, `%`, comparisons, NaN, infinities, signed zero, and
  conversion use binary64 behavior in both models. `%` uses truncation toward
  zero. Bitwise operations use ECMAScript `ToInt32`: NaN, infinities, and
  either zero become 0; otherwise truncate toward zero and reduce modulo
  2^32.

### Frames, memories, and collection

- `MAKE_FN` a1: bit7 = arrow (lexical `this`), bit6 = IIFE. `CALL_VAL` of an
  IIFE whose captured word is **not** an environment is a **flat call**: no
  ENV is allocated, and `LET_VAR` locals (a1 bit0) store globals. Nested
  IIFE that captured an ENV still gets a per-call environment. Same
  ProgramImage on PYTHON and FPGA-SIM.
- An explicit call frame is
  `(return_ip, base_sp, this, environment, function, result_count, kind)`.
  Return and event/frame boundaries assert the expected stack depth; they do
  not reset `sp` to conceal imbalance.
- General V1 caps are code 32768 words, constants 1024, globals 512, eval stack
  2048 Values, call frames 128, objects 1024, arrays 512, array elements 64,
  lexical environments 32, timers 64, rAF callbacks 8, and four listeners
  per event type. Reaching a cap triggers collection where legal, then halts
  loudly if capacity is still unavailable.
- Heap slots have allocation bits, generation counters, mark bits, kind, and
  fixed-capacity payload. Mark/sweep runs only at safe points.
- Roots are globals, the eval stack, every call frame and lexical environment,
  document/window listeners, rAF callbacks, timers, arrays/objects reachable
  from those roots, and handles held by native/Canvas operations.
- Collection follows every marked handle recursively, then frees unmarked
  slots and increments their generations. There are no frame watermarks,
  nursery rewinds, grace-frame guesses, or recycled live callback IDs.
  Marking a live slot **without** matching the handle generation is not
  collection — it is hiding a second copy of the heap.

### Deterministic event and failure contract

- One frame advances the machine clock by 1000/60 ms. Random uses one
  explicitly seeded deterministic generator.
- Raw key down/up events are queued once. Event order at a frame safe point is
  input, rAF snapshot, then due timers; callbacks queued during a snapshot run
  on a later frame.
- Machine errors include ProgramImage validation, stack/frame imbalance,
  stale handle, bad tag/kind, and every capacity overflow. Errors stop
  execution and remain visible to the monitor and conformance checkpoint.

---

## Three-column gap list (honest)

| Feature / API | PYTHON (bytecode VM) | FPGA-SIM (RTL VM) | FPGA board |
|---|---|---|---|
| `LOAD` `.HTML` + `RUN` | **required** compile-on-RUN (dukpy = debt) | grow until match (no `?NH`) | same as flashed bit |
| numbers / bool / strings | grow to HTML needs | grow | grow |
| `let` / arithmetic / `if` / loops | grow | grow | grow |
| arrays / objects / `this` / classes / functions | **required for HTML titles** | **required** (gap until done) | same |
| `setInterval` / `setTimeout` / rAF | required | required | required |
| `canvas.getContext('2d')` 640×480 | required | required | required |
| `fillRect` / paths / transform / `fillText` | as titles need | as titles need | same |
| `drawImage` / `Image` PNG | as titles need | as titles need | same |
| keydown/keyup (HTML decides bindings) | KEYBITS / host | `joy_in` / PS/2 | tether until J15 fixed |
| heap / GC / objects in **JMR** VM | required (not dukpy) | required | required |
| ProgramImage into VM / BRAM | **compile-on-RUN** → ephemeral bytes | **yes** (same bytes) | yes after matching flash |
| external SRAM asset bank (ASET) | **required** — full-res art via FM SRAM model | **same** (stream ASET → SRAM port; blit from SRAM) | same after matching flash |
| standalone keyboard | GUI / host | Verilator PS/2 OK | **dead J15** — PROG tether |

Columns mean **JMR VM parity**, never “dukpy can do it so PYTHON is done.”

### What PACMAN forces onto the queue

- Path drawing (`arc` maze + characters), `getImageData` cache, `FontFace` stub
- Multiple `<script>` eval (strict `game.js` must not poison `index.js` globals)
- Dynamic palette so maze/sprites are not 8 VGA slots
- Objects / timers / rAF in the **bytecode VM** (not a host JS engine)

### What sprite DONKEY (DKJS) forces onto the queue

- ES modules → flattened IIFE bundle (host `html_loader` skips `type=module`)
- `drawImage` PNG sprites, `measureText`, `setTransform`, WASD + Enter
- Canvas element is **640×480**; DKJS world stays 1510×685 via `setTransform`
- Title → character select → play (auto-Enter ×2 after rAF)

### What INVADERS.HTML (PNG) forces onto the queue

- `Image.onload` after `src` (must fire even if onload assigned later)
- `drawImage` for ship/invader PNGs; audio `play()` stubs
- DOM `button.click` to skip a CSS START menu

### What MRDO.HTML forces onto the queue

Library title (not ISA freeze). Universal 1982 arcade rules from StrategyWiki /
Wikipedia / KLOV — **portrait 384×480** (2× 192×240) centered in 640×480
with black side letterbox, matching the vertical cabinet.

- Tile dirt grid + 4-way dig; cherries in 2×4 groups; six apples that crush
- Bouncing power ball (reform delay grows; prize resets it)
- Red creeps → striped drillers; center prize → freeze + Alphamonster + 3 Munchers
- EXTRA pen (letter every 5000); four clear conditions including diamond
- Pixel `fillRect` sprites; `imageSmoothingEnabled = false`; HUD on Canvas

### What FPGA-SIM has today (board after next matching flash)

Natives in `functional_model/jsb_format.py` / `jmr_js_vm.sv`:

`console.log`, `clear`, `fillRect`, `swapBuffers`, `keyLeft`, `keyRight`,
`keyFire`, `keyUp`, `keyDown`, `startLoop` — enough for `INVADERS.JS` /
`PACMAN.JS` / `DONKEY.JS`, not for the HTML titles. The **03:36** board bit
still has Invaders hex / 160×120 FB only.

---

## Feature matrix (planning)

| Feature | PACMAN.HTML | DONKEY.HTML | INVADERS.HTML | Implement |
|---|---|---|---|---|
| numbers / bool / strings | yes | yes | yes | V1 bytecode |
| arrays / objects / prototypes | yes | yes | yes | JMR VM (not dukpy) |
| ES6 class / modules | no | **yes** (flattened) | no | JMR VM |
| functions | yes | yes | yes | JMR VM |
| setInterval / rAF | yes | yes | yes | JMR VM |
| fillRect / clearRect | yes | yes | yes | engines |
| path / arc | **yes** | some | no | engines |
| fillText | HUD | **yes** | HUD | engines |
| drawImage PNG | no (paths) | **yes** | **yes** | engines |
| keyboard (HTML binds) | yes | yes | yes | KEYBITS / joy_in |
| CSS (game HUD) | wanted | wanted | wanted | later tiny subset |
| Audio | stub | stub | stub | later |
| WebGL / Fetch | no | no | no | NEVER |

Library HTML (`ASTEROID`, `AURORA`, `JOYDEMO`, `MRDO`) uses the same V1 surface. MRDO is a
**portrait** 384×480 tile title (side letterbox on 640×480). Do not stretch
the cabinet raster.

---

## Frozen ISA (three HTML compiles, 2026-08-14)

This is the **actual** `CALL_NATIVE` / `CALL_METHOD` / Canvas surface emitted
by `INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML`. It is the ISA. Do **not**
grow “popular HTML5” past this list.

**Agents:** product Complete/TBD lives in **Agent surface checklist** above.
Rows here that say **done** mean “the compile emits it / some code exists,”
not that PYTHON + FPGA-SIM titles are accepted. Chrome is authoring only.

Chrome is authoring only. Fonts are **never** Chrome TTF (PYTHON 8×8 bitmap;
RTL `fillText` is a 64×8 rect stub).

### Natives (`CALL_NATIVE` → `jsb_format.NATIVE_IDS`)

| Native | Titles | Status |
|---|---|---|
| `document.getElementById` / `querySelector` / `createElement` | all | done |
| `addEventListener` / `removeEventListener` (document/window) | all | done |
| `document.dispatchEvent` / `window.dispatchEvent` | DONKEY | done |
| `new KeyboardEvent` / `Event` / `CustomEvent` / `MouseEvent` | DONKEY boot Enter | done PYTHON+RTL (`NEW_OBJ` copies type+options) |
| `requestAnimationFrame` / `setTimeout` / `clearTimeout` | all | done |
| `Math.floor` / `abs` / `min` / `max` / `random` / `sqrt` | INVADERS, PACMAN | done |
| `JSON.parse` / `JSON.stringify` | INVADERS, PACMAN | done (nested + interned parse; stringify finishes FRAME) |
| `Array` ctor | PACMAN | done (`fill`+`map` nested rows writable) |
| `Image` | INVADERS, DONKEY | done (ASET handle) |
| `Date` / `Date.now` | INVADERS, PACMAN | done (frame clock) |
| `localStorage.*` | INVADERS | done (in-memory) |
| `typeof` | PACMAN | done PYTHON+RTL (interned result; `"number"` not intern-0) |
| `window.open` | PACMAN | **never** (no-op / `_stub`) |
| `console.log` / `console.warn` | INVADERS, DONKEY | done |

### Constructors (`NEW_OBJ` / `NEW`)

| Construct | Titles | Status |
|---|---|---|
| `new KeyboardEvent(type, {key, keyCode, …})` | DONKEY boot Enter | done |
| `new Event` / `CustomEvent` / `MouseEvent` | DONKEY | done |
| `new Image()` | INVADERS, DONKEY | done (ASET handle) |
| `new Date()` | INVADERS, PACMAN | done (frame clock) |
| `Array(n)` | PACMAN finder `steps` | done (`fill`+`map` nested) |
| `RegExp` literal / `new RegExp` | PACMAN `replace` | done (stub + flags; interned `/g`) |

### Methods (language / VM — not title gates)

| Method | Titles | Status |
|---|---|---|
| `join` | PACMAN (`code.join('')` maze keys) | done |
| `indexOf` | PACMAN (neighbor bits + beans stringify) | done |
| `fill` / `map` / `filter` / `unshift` | PACMAN finder | done |
| `forEach` / `find` / `splice` / `push` | INVADERS, PACMAN | done |
| `replace` (string + RegExp stub) | PACMAN | done (interned `/g` and dynstr) |
| `assign` / `bind` | PACMAN | done |
| `getContext` | all | done (`test_hw_value64_p0_getcontext_fillrect_paints`) |

### Canvas ops

| Op | Titles | Status |
|---|---|---|
| `fillRect` / `clearRect` / `drawImage` / `setTransform` | INVADERS / DONKEY | done |
| `beginPath` / `moveTo` / `lineTo` / `arc` / `stroke` / `fill` / `quadraticCurveTo` / `closePath` | PACMAN (+ INVADERS arc) | done |
| `imageSmoothingEnabled` | DONKEY, MRDO | done (nearest blit; false stored) |
| `fillText` / `measureText` | PACMAN, DONKEY, INVADERS HUD | **never** Chrome font — 8×8 / rect stub (HM `fillText`/`measureText` tests exist) |
| `getImageData` / `putImageData` | PACMAN map cache | done |
| `lineWidth` / `strokeStyle` | PACMAN | done |

### Never (not in the three compiles as a product API)

WebGL, Fetch/XHR, Audio (`.play` is a stub), TTF/`FontFace`, real `window.open`,
CSS layout engine, browsing.

Play-blocking gaps get **one pytest per gap** in `tests/test_bytecode_js.py`
(RTL twin in `tests/test_rtl_snippets.py` only if play-blocking).

### FPGA-SIM tests: small twins, not a second title suite

A **larger FPGA-SIM suite is the wrong knob**. `tests/test_rtl_snippets.py`
already has ~100 RTL cases. Each boots Verilator. A 200-line PACMAN-finder
clone (`test_rtl_ghost_update_leaves_start_cell`) fails as “nz < 50” and
then the agent debugs the **test**, not exec64. Tokens burn there.

**Faster and cheaper:** grow `test_hw_value64_*` (PYTHON / JsHwVm, same
ProgramImage). That is seconds, no `sim_server`. FPGA-SIM pytest is only
the **twin of a play-blocking RTL hole** after PYTHON already passes the
same JS.

| Do | Do not |
|---|---|
| One behavior, 5–15 lines of JS/HTML | Miniature INVADERS/PACMAN/DONKEY |
| Same source string on PYTHON then RTL | RTL-only expected numbers with no HM twin |
| `fault=0` + **one** pixel `(x,y)` or one `VMSTAT?` field | `nz >= 50` / “looks painted” |
| Map to a `docs/potential bugs.md` ID (6, 15, 14, 31) | “cover Canvas” in one test |
| Reuse `_sim` / `_patch_html` / `_fb_pix` already in `test_rtl_snippets.py` | New harness, new assert language, `FRAME` 64M in pytest |

**Shape an agent can write without guessing** (HTML FLAG_VALUE64, like titles):

```html
<canvas id="c" width="640" height="480"></canvas>
<script>
var c = document.getElementById("c").getContext("2d");
function tick() {
  c.fillStyle = "#fff";
  c.fillRect(10, 10, 4, 4);
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
</script>
```

Assert `fault=0` and `_fb_pix(raw, 11, 11) != 0`. That is bug **12**/G1
shape. For **15**: `keydown` + `e.key === "w"` then one `fillRect`. For
**6**: `forEach` that falls off the callback (no `return`) then rAF still
paints. If the snippet needs a comment to explain the maze, it is too big
— use the real `.HTML` + traces instead.

Visual play stays **F9 FPGA-SIM**, not a snippet PASS. Do not mark a
compat row Complete from Chrome or from a fat RTL snippet.

---

## Regression seeds

| File | Role |
|---|---|
| `storage/INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML` | **Product titles** (LOAD these; ISA freeze) |
| `storage/ASTEROID.HTML` | Library title (vector Asteroids). Authoring: [GAME_DESIGN.md](GAME_DESIGN.md) |
| `storage/AURORA.HTML` | Library title (fillRect gem hopper) |
| `storage/MRDO.HTML` | Library title (Mr. Do! arcade). Portrait 384×480 letterbox; [GAME_DESIGN.md](GAME_DESIGN.md) |
| In-memory ProgramImage | Compile-on-RUN code + source map + descriptors + ASET; never a storage name |
| `storage/JOYDEMO.HTML` | Library smoke (joystick / arrows on Canvas) |
| `storage/games_*` | Upstream archive only |

## Host notes (PYTHON)

- **Product path:** `functional_model/` **bytecode VM** — **compile-on-RUN**
  from loaded HTML (ephemeral ProgramImage; full-quality art → ASET section →
  FM asset-SRAM model). Writing a compile sidecar, or
  using dukpy in `js_host.py`, is **debt to remove**, not truth.
- Use **`.venv`** (Pillow for `drawImage` on the Canvas engine).
- Playable HTML titles declare `<canvas width="640" height="480">` and **fill**
  that field. READY letterbox is console text only. Do not letterbox a smaller
  arcade raster inside 640×480. DONKEY may `setTransform` its own world.
- Esc remains machine quit (games must not steal Esc).
- Never claim FPGA-SIM/BOARD done because Chrome or dukpy painted.
