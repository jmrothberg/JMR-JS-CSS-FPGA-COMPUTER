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
| Space Invaders | `INVADERS.HTML` | compile → fresh `INVADERS.JSH` |
| Pac-Man | `PACMAN.HTML` | compile → fresh `PACMAN.JSH` |
| Donkey Kong | `DONKEY.HTML` | compile → fresh `DONKEY.JSH` |

**Compile-on-RUN (hard):** source of truth = loaded `.HTML` (editor line
numbers). `RUN` **always** recompiles. `.JSH` = invisible *output* only —
never a LOAD name; **never prefer a pre-existing `.JSH`**. Stale `.JSH` may
be deleted.

Same-stem `NAME.JS` / `NAME.JSB` are **legacy demos**, not product twins.
Optional smoke demos with other names: `RECTDEMO`, `JOYDEMO`, `CLIMB`.
Upstream trees: `storage/games_*` (not DIR / not card).

```text
LOAD "INVADERS.HTML"
RUN
# PYTHON / FPGA-SIM / BOARD — compile current HTML → fresh .JSH → JMR VM

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
| `.JSH` into VM / BRAM | **compile-on-RUN** → fresh bytecode | **yes** (same rule) | yes after matching flash |
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

## Regression seeds

| File | Role |
|---|---|
| `storage/INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML` | **Product titles** (LOAD these) |
| `storage/*.JSH` | Compile-on-RUN *output* only (stale = disposable; not LOAD names) |
| `storage/RECTDEMO.JS` / `JOYDEMO.JS` / `CLIMB.JS` | Optional differently named VM smoke |
| `storage/games_*` | Upstream archive only |

## Host notes (PYTHON)

- **Product path:** `functional_model/` **bytecode VM** — **compile-on-RUN**
  from loaded HTML (fresh `.JSH` output). Preferring a stale disk `.JSH` or
  dukpy in `js_host.py` is **debt to remove**, not truth.
- Use **`.venv`** (Pillow for `drawImage` on the Canvas engine).
- Playable HTML titles declare `<canvas width="640" height="480">`; glass is
  640×480 (DONKEY still `setTransform`s its internal world).
- Esc remains machine quit (games must not steal Esc).
- Never claim FPGA-SIM/BOARD done because Chrome or dukpy painted.
