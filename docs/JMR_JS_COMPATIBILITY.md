# JMR JS compatibility matrix (target titles)

Target games drive the language/API set. **Not a full web browser** — no
Fetch/XHR, no WebGL, no general browsing. Goal (same idea as BASIC on T100):
**HTML + JavaScript + the CSS a game actually needs**, as the machine’s native
surface — **JMR bytecode VM** on PYTHON → FPGA-SIM → BOARD → ASIC.

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

**Compile-on-RUN (hard):** source of truth = loaded `.HTML` (editor line
numbers). `RUN` **always** recompiles into one versioned in-memory
**ProgramImage**. `.JSB` / `.JSH` files are not product programs, are never a
LOAD name, and are never persisted or preferred by a runtime.

**Asset bank (external SRAM — no `NAME.DAT`):** great graphics stay at full
quality. `RUN` emits `data:image` art (per-title 256-entry palette +
full-resolution 8-bpp banks) as the **ASET section** of the ProgramImage;
the loader streams it into the **external 4 MB SRAM asset bank**
(IS61WV204816 contract — see `docs/ARCHITECTURE.md`). Bytecode carries
descriptors (w, h, SRAM offset) only. Do not pack Donkey sheets into code
BRAM or downscale them to fit.

**Code debt (2026-08-13):** ASET/asset-bank path is **in progress**.
Historic trap: `tools/compile_js.py` `_extract_data_uri_sprites` packed
pixels into `.JSH` and downscaled (`w*h > 180000`) with an 8-color palette.
PYTHON compile-on-RUN **is** default. Full-game PYTHON ↔ FPGA-SIM match is
**not** done.

Same-stem `NAME.JS` / `NAME.JSB` are **legacy demos**, not product twins.
Optional smoke demos with other names: `RECTDEMO`, `JOYDEMO`, `CLIMB`.
Upstream trees: `storage/games_*` (not DIR / not card).

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
  error. Handles remain stable across collection.
- `+`, `-`, `*`, `/`, `%`, comparisons, NaN, infinities, signed zero, and
  conversion use binary64 behavior in both models. `%` uses truncation toward
  zero. Bitwise operations use ECMAScript `ToInt32`: NaN, infinities, and
  either zero become 0; otherwise truncate toward zero and reduce modulo
  2^32.

### Frames, memories, and collection

- An explicit call frame is
  `(return_ip, base_sp, this, environment, function, result_count, kind)`.
  Return and event/frame boundaries assert the expected stack depth; they do
  not reset `sp` to conceal imbalance.
- General V1 caps are code 32768 words, constants 1024, globals 512, eval stack
  2048 Values, call frames 128, objects 8192, arrays 4096, array elements 128,
  lexical environments 32, timers 8, rAF callbacks 8, and four listeners
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
| `LOAD` `.HTML` + `RUN` | **required** compile-on-RUN (dukpy / stale `.JSH` = debt) | grow until match (no `?NH`) | same as flashed bit |
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

### What INVADARC still forces onto the queue

- Objects, arrays, timers, `getContext`, `fillRect`/`fillText`, Space+Left/Right
- Pause key (letter **P**) vs machine Esc
- Score / lives / wave HUD (`fillText` or future CSS)
- Optional persisted hi-score (`localStorage` beyond in-memory)

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

---

## Frozen ISA (three HTML compiles, 2026-08-14)

This is the **actual** `CALL_NATIVE` / `CALL_METHOD` / Canvas surface emitted
by `INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML`. It is the ISA. Do **not**
grow “popular HTML5” past this list. Status: **done** (PYTHON + RTL), **gap**
(play-blocking or a rung still lies), **never**.

Chrome is authoring only. Fonts are **never** Chrome TTF (PYTHON 8×8 bitmap;
RTL `fillText` is a 64×8 rect stub).

### Natives (`CALL_NATIVE` → `jsb_format.NATIVE_IDS`)

| Native | Titles | Status |
|---|---|---|
| `document.getElementById` / `querySelector` / `createElement` | all | done (DOM stub / canvas elem) |
| `addEventListener` / `removeEventListener` (document/window) | all | done |
| `document.dispatchEvent` / `window.dispatchEvent` | DONKEY | done (immediate fire) |
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
| `new KeyboardEvent(type, {key, keyCode, …})` | DONKEY boot Enter | done (options copied onto the event) |
| `new Event` / `CustomEvent` / `MouseEvent` | DONKEY | done |
| `new Image()` | INVADERS, DONKEY | done (ASET handle) |
| `new Date()` | INVADERS, PACMAN | done (frame clock) |
| `Array(n)` | PACMAN finder `steps` | done (`fill`+`map` nested) |
| `RegExp` literal / `new RegExp` | PACMAN `replace` | done (stub + flags; interned `/g`) |

### Methods (language / VM — not title gates)

| Method | Titles | Status |
|---|---|---|
| `join` | PACMAN (`code.join('')` maze keys) | done (number and string-digit `['1','1','0','0']` hit `case '1100'`) |
| `indexOf` | PACMAN (neighbor bits + beans stringify) | done (`indexOf(1)>-1`; string `indexOf` via `S_IDXSTR`) |
| `fill` / `map` / `filter` / `unshift` | PACMAN finder | done (`fill`+`map` nested; `filter` truthy; `findIndex` identity) |
| `forEach` / `find` / `splice` / `push` | INVADERS, PACMAN | done |
| `replace` (string + RegExp stub) | PACMAN | done (interned `/g` and dynstr) |
| `assign` / `bind` | PACMAN | done |
| `getContext` | all | done |

### Canvas ops

| Op | Titles | Status |
|---|---|---|
| `fillRect` / `clearRect` / `drawImage` / `setTransform` | INVADERS / DONKEY | done |
| `beginPath` / `moveTo` / `lineTo` / `arc` / `stroke` / `fill` / `quadraticCurveTo` | PACMAN (+ INVADERS arc) | done (`join('')` `case '1100'` paints a quarter-arc, not spokes) |
| `fillText` / `measureText` | PACMAN, DONKEY, INVADERS HUD | **never** Chrome font — 8×8 / rect stub |
| `getImageData` / `putImageData` | PACMAN map cache | done (64×64 and 640×480 GET `fcap=0`; 1 px/cycle; do not raise 16M CAP) |
| `lineWidth` / `strokeStyle` | PACMAN | done as path state; color LUT may still miss `#09f` on RTL |

### Never (not in the three compiles as a product API)

WebGL, Fetch/XHR, Audio (`.play` is a stub), TTF/`FontFace`, real `window.open`,
CSS layout engine, browsing.

Play-blocking gaps get **one pytest per gap** in `tests/test_bytecode_js.py`
(RTL twin in `tests/test_rtl_snippets.py` only if play-blocking).

---

## Regression seeds

| File | Role |
|---|---|
| `storage/INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML` | **Product titles** (LOAD these) |
| `storage/*.JSH` | Compile-on-RUN *output* only, code + ASET art (stale = disposable; not LOAD names) |
| `storage/RECTDEMO.JS` / `JOYDEMO.JS` / `CLIMB.JS` | Optional differently named VM smoke |
| `storage/games_*` | Upstream archive only |

## Host notes (PYTHON)

- **Product path:** `functional_model/` **bytecode VM** — **compile-on-RUN**
  from loaded HTML (fresh `.JSH` output; full-quality art → ASET section →
  FM asset-SRAM model). Preferring a stale disk `.JSH` or dukpy in
  `js_host.py` is **debt to remove**, not truth.
- Use **`.venv`** (Pillow for `drawImage` on the Canvas engine).
- Playable HTML titles declare `<canvas width="640" height="480">`; glass is
  640×480 (DONKEY still `setTransform`s its internal world).
- Esc remains machine quit (games must not steal Esc).
- Never claim FPGA-SIM/BOARD done because Chrome or dukpy painted.
