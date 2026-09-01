# JMR JS compatibility matrix (target titles)

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**Learn first:** [JS_COMMANDS.md](JS_COMMANDS.md) — JavaScript you can write,
and the instructions it becomes (34 **opcodes** + native ids). This file is
title status, holes, and the **Version 1.0 / 1.5 / 2.0** plan — not the teaching
list.

This is **copy 2** of the Version 1.0 walls / Version 1.5 console + popular JS /
Version 2.0 machine-work plan
(copy 1 is `.cursor/rules/html-game-v1.mdc`).

**On this page:** [Reference titles](#reference-titles-on-disk) ·
[Version 1.0, 1.5, and 2.0](#version-10-15-and-20) ·
[Agent surface checklist](#agent-surface-checklist-html--javascript--css--canvas) ·
[Frozen machine contract](#frozen-machine-contract) (ABI) ·
[Regression seeds](#regression-seeds)

Target games drive the language/API set. **Not a full web browser** — no
Fetch/XHR, no WebGL, no general browsing. Goal: **NLISC-JS** — HTML titles,
JavaScript **ISA** (Instruction Set Architecture), the CSS a game actually
needs — **JMR bytecode VM** on PYTHON → FPGA-SIM → BOARD → ASIC.

**No cheats:** dukpy/Duktape/V8/QuickJS/browser must not be the product CPU
(copy 1: `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`; copy 2:
[CONSTITUTION.md](../CONSTITUTION.md) Vendored-titles).

**Machine state (2026-09-01):** ONE opcode decoder — `jmr_js_vm_exec64.sv`
(**Value64**). Five titles are **correct** on FPGA-SIM: INVADERS, PACMAN,
DONKEY, ASTEROID, MRDO. FPGA-SIM is a slideshow (PC simulating the chip);
board target **≥ 30 pictures/second**: [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).
Live heap/code caps: [FPGA_FIT.md](FPGA_FIT.md). **V1.0:** compile when you
make the card (`.JSH`). **V1.5 compile is live:** `LOAD` → `EDIT` →
**`COMPILE`** → `RUN`. `RUN` still loads `.JSH`. Typed-at-READY numbered
authoring of *new* programs, and popular JS V1.0 does not have, are leftover.
Version 2.0 is ISA/ASET growth, **not** a named title.

## Reference titles (on disk)

**One title = one file.** User always:

```text
LOAD "NAME.HTML"
RUN
```

| Game | Source (LOAD) | On RUN |
|---|---|---|
| Space Invaders | `INVADERS.HTML` | minted `.JSH` from `card.img` (code + ASET art) |
| Pac-Man | `PACMAN.HTML` | minted `.JSH` from `card.img` (code + ASET art) |
| Donkey Kong | `DONKEY.HTML` | minted `.JSH` from `card.img` (code + **full-res** ASET art) |
| Asteroids (library) | `ASTEROID.HTML` | minted `.JSH` from `card.img` (vector stroke; no ASET) |
| Aurora (library) | `AURORA.HTML` | minted `.JSH` from `card.img` (fillRect; no ASET) |
| Joystick (library) | `JOYDEMO.HTML` | minted `.JSH` from `card.img` (stick + arrows; no ASET) |
| Sound (library) | `SNDDEMO.HTML` | minted `.JSH` from `card.img` (playSfx catalog; Chrome audio, card `sound()` nid 42; no ASET) |
| Mr. Do! (library) | `MRDO.HTML` | minted `.JSH` from `card.img` (portrait 384×480 in 640×480 letterbox; no ASET) |
| Mortal Kombat (library) | `MKBIG.HTML` / `MKBIGCPU.HTML` | **V1.0** — atlases inside 4 MB / 16 SPR. No `MK.HTML` in `storage/` |
| MK PVP (library) | `MKPVP.HTML` | **V1.0** MK-shaped — ≤16 atlases, L/R sheets, no `Object.keys` / negative mirror |

**V1.0 disk is `card.img` (hard):** PYTHON, FPGA-SIM, and BOARD all
`LOAD`/`RUN` that FAT image. `storage/` is the seed — rebuild the card after
edits. Compile is at **card create** (`make_sd_image.py` **mints** `NAME.JSH`).
`LOAD` shows HTML; `RUN` loads that `.JSH`. Do **not** compile `storage/*.HTML`
on host `RUN` as a second path. Never copy `.JSH` from `storage/`. **V1.5
compile is live:** `LOAD` → `EDIT` → **`COMPILE`** → `RUN`. `RUN` still
loads `.JSH` from the card. Typed-at-READY numbered authoring of *new*
programs, and popular JS V1 walls (stdlib + globals; not Canvas gradients /
mouse), are leftover.

**Asset bank (external SRAM — no `NAME.DAT`):** great graphics stay at full
quality. You draw **PNG sheets**; `make_artx.py` writes `NAME.ARTX`. `RUN`
loads that art as the **ASET** (asset) section of the minted ProgramImage;
the loader streams it into the **external 4 MB SRAM asset bank**
(IS61WV204816 contract — [ARCHITECTURE.md](ARCHITECTURE.md)).
**This path is in** (five titles play with ASET art on FPGA-SIM). Do not
pack Donkey sheets into code BRAM or downscale them to fit. Authoring:
[GAME_DESIGN.md](GAME_DESIGN.md) (Art).

Same-stem `NAME.JS` / `NAME.JSB` are **legacy**, not product twins.
`storage/games_*` (not DIR / not card).

```text
LOAD "INVADERS.HTML"
RUN
# PYTHON / FPGA-SIM / BOARD — same card.img; RUN = minted .JSH → JMR VM

LOAD "PACMAN.HTML"
RUN

LOAD "DONKEY.HTML"
RUN
```

PYTHON / FPGA-SIM / BOARD `RUN` vendored HTML via the **card-minted** `.JSH`
(compile was at card create). Do not host-compile `storage/` on `RUN` while
the board plays a different image. Never Invaders hex, never dukpy. `?NH` =
temporary debt. Do **not** fake FPGA-SIM with `JMR_SIM_HOST=1`.

**Constitution mandate:** product is NOT DONE until all three HTML titles
LOAD + RUN playable on PYTHON **bytecode** → FPGA-SIM RTL → BOARD. HTML
decides keys. No `.bit`/`.bin` until FPGA-SIM is green and the user GUI-tests.

---

## Version 1.0, 1.5, and 2.0

This machine ships **generations** of the playable HTML/JS surface. Agents
must not silently raise V1 caps for a library demo, and must not call a
Chrome-only title “done on the machine.”

| | **1.0 (now)** | **1.5 (COMPILE live; leftover below)** | **2.0 (planned)** |
|---|---|---|---|
| **Meaning** | Caps + natives on PYTHON **and** FPGA-SIM. **One disk:** `card.img` for PYTHON / FPGA-SIM / BOARD. Host mint at card-create (`.JSH`). Console is **view-only** (`LIST` / `DIR` / `LOAD`) unless you `COMPILE`. | **Live:** `LOAD` → `EDIT` → **`COMPILE`** → `RUN`. `RUN` still loads `.JSH`. Compiler/editor are card programs, not a new ISA. **Leftover:** typed-at-READY numbered authoring of *new* programs, and popular JS V1 does not have. Same heap/ASET/Canvas caps. | Grow the ISA past V1 walls (sprite count, ASET size, `Object.keys` on RTL, `Math.round`, dotted `new`, `.call`/`.apply`). **No title is the V2 example.** |
| **Acceptance** | `INVADERS` / `PACMAN` / `DONKEY` | Non-art titles compile on the machine (`COMPILE` then `RUN`). Art titles refuse until `ARTPNG.JSH`. Typed-READY `SAVE` optional leftover. | Any `NAME.HTML` that needs those caps. `MKBIG.HTML` / `MKBIGCPU.HTML` stay V1 |
| **Sprites / ASET** | **`MAX_SPR` = 16**, 4 MB bank | **Unchanged** (do not grow heap/ASET for this) | **`MAX_SPR` ≥ 518**, **8 MB** bank |
| **Authoring** | PC + remake `card.img`. `LIST` to learn. Do **not** treat `EDIT` as V1.0 play | **Live:** `EDIT` launches `EDITOR.JSH`; `COMPILE` mints `.JSH`. **Leftover:** numbered lines at `>` for *new* programs; language stdlib/globals (table below). Canvas caps stay | Same glass/`LOAD`/`RUN`; drop V1 HTML shims once V2 rows land |

Do **not** title-gate (`if (stem == "…")`).

### V1.5 — LIVE on the board (2026-09-01, run 67 + the instrumented card)

Shipped shape: `LOAD` → `EDIT` (EDITOR.JSH runs as a GAME — visible
framebuffer, F2 save prints SAVED., F3 quit; NOT the numbered inline
editor) → `COMPILE` (chains ARTSCAN.JSH + COMPILER.JSH from the card,
handles .ART sidecars) → `RUN`. Compile errors print a real message after
?CE. The rest of this section is the original plan, kept for the parts not
yet built (typed-at-READY authoring of NEW programs, numbered edits):

**Built, 2026-08-31.** The machine compiles its own titles. `COMPILE` is a
real verb; the compiler is `ARTSCAN.JSH` + `COMPILER.JSH`, **ordinary
programs on the card** written in the machine's own JS subset and executed by
the same VM that runs the games. The editor is `EDITOR.JSH`, launched by a
bare `EDIT`. Nothing about the ISA changed. **Do not delete**
`storage/EDITOR.HTML`, `storage/ARTSCAN.HTML`, or `storage/COMPILER.HTML`
(`DIR` hides them). [GAME_DESIGN.md](GAME_DESIGN.md#machine-programs-in-storage--do-not-delete).

```
LOAD "BOXES.HTML"      source into SOURCE SRAM
EDIT                   edit it in place (F2 saves, F3 quits; Esc is BREAK)
COMPILE                mint BOXES.JSH on the card
RUN                    the ordinary, untouched RUN path
```

`EDIT` and `COMPILE` **chain-load** their programs rather than `LOAD`ing
them: loading the editor the ordinary way would put the editor's own text in
SOURCE and it would edit itself.

**Status:** all six non-art titles (BOXES, JOYDEMO, SNDDEMO, AURORA, MISSILE,
ASTEROID) compile on the machine and render **RGB-identical** to the host
mint. Art titles refuse loudly with `ART V15` until `ARTPNG.JSH` lands — the
PNG inflate pass. Build a card without sidecars to prove it:

```
python3 tools/make_sd_image.py create card.img --nojsh
```

That ships HTML only, so the machine has to compile each title itself before
`RUN` can find an image. With sidecars present, a working `RUN` proves
nothing about the compiler.

Logged 2026-08-25: BOARD `>` treats a paste or typed `<canvas…>` as a verb
→ `?SN ERROR`. BASIC numbered lines are the glass.

**What the user can do (all the same editor):**

| Action | Glass |
|---|---|
| **Type** HTML | `10 <canvas…>` Enter, `20 <script>` Enter, … then `RUN` |
| **Paste** HTML | Same path as type. Unnumbered paste auto-numbers by **10**; already-numbered lines keep their numbers |
| **Compile / run** | **V1.0:** `RUN` loads the **card-minted** `.JSH` from `card.img` (PYTHON / FPGA-SIM / BOARD). Compile was at `make_sd_image.py create`. **V1.5 (decided 2026-08-31): a bare `COMPILE` verb**, three explicit steps `LOAD` → `COMPILE` → `RUN`. Supersedes the earlier "no extra COMPILE verb / compile-on-RUN" wording: the verb takes no argument (LOAD already parked the source and latched the name, and the VM has **no argument register** on silicon), and separating it keeps a failed compile from looking like a failed RUN. `RUN` itself is **unchanged** — it loads whatever `.JSH` is on the card, minted by the host or by the machine. Missing image → loud `?NH`; a failed compile → `?CE` + the compiler's line message |
| **Replace a line** | `10 body` + Enter (inserts if 10 is new) |
| **Delete a line** | `10` + Enter (number only) — **gone**, not blank. PYTHON today blanks; V1.5 deletes |
| **Insert between** | Numbers go by **10** (`10`, `20`, `30`, …). `15 xyz` lands **between** 10 and 20. Any unused integer is legal (`11`, `25`). `LIST` and `RUN` use **number order** |
| **Edit** | Keep **`EDIT n`** for V1.5 (next typed line replaces that source line). **Also** `10 body` numbered replace at READY. Do **not** add `INSERT` / `DELETE` verbs — insert is an unused number (`15`); delete is `10` + Enter. V1.0 `EDIT` exists but cannot change `RUN` |
| **Save** | `SAVE` / `SAVE name` optional. `RUN` must work with **no** µSD |
| **List** | `LIST` keeps printing those line numbers |

```text
10 <canvas id="c" width="640" height="480"></canvas>
20 <script>
30 var c = document.getElementById("c").getContext("2d");
15 <!-- comment between 10 and 20 -->
RUN
SAVE "BOX.HTML"
```

`RUN` on **V1.0** loads the **minted** card `.JSH` from `card.img`. **V1.5
compile is live:** `COMPILE` mints that sidecar on the machine; `RUN` is
unchanged. Typed/pasted numbered HTML at READY (no `LOAD`) is leftover and
must set `src_is_html` **without FAT**. Missing ProgramImage → loud `?NH`.

**Fit budget (run 33 routed, [FPGA_FIT.md](FPGA_FIT.md) SCOREBOARD):**

| Resource | Used | Free | V1.5? |
|---|---:|---:|---|
| Slice LUTs | 108,777 / 134,600 (**80.8%**) | **25,823** | Console editor **yes**. **V1.5 standalone compile** LUT cost TBD |
| Block RAM | 343.5 / 365 (**94.1%**) | **21.5 tiles** | **Yes if we add no SOURCE BRAM.** HTML source is already in **external SRAM** (`SOURCE_MAX`, `SRC_SRAM_BASE`). A line-number map is a small LUTRAM (prefer that — BRAM is the tight one) |
| Flip-flops | 45,379 / 269,200 (16.9%) | ~224k | Yes |

**Do not** grow `MAX_SPR`, heap, or the 4 MB ASET bank for the console editor.
**V1.5 `COMPILE` is live** (drop card `.JSH` with `--nojsh` to prove it).
Language natives’ LUT cost is **TBD**. Insert/delete in SOURCE is FSM memmove
on the existing SRAM port. **Do not** grow SOURCE into BRAM.

PYTHON already accepts `10 text` at READY; RTL does not. Empty `10` on
PYTHON currently blanks the line — V1.5 is BASIC **delete**.

**Language V1.5 should add** (popular JS V1.0 does not have — author around
on the card today; do **not** grow V1 RTL for one title). Same Canvas caps
(`fillRect` / `arc` / hex `fillStyle`). **Not** this list: Canvas gradients /
`globalCompositeOperation` / mouse (`clientX`) — indexed FB / no mouse port
(**never**).

| Kind | V1.0 today | V1.5 |
|---|---|---|
| **Array** | `push` `pop` `splice` `slice` `join` `indexOf` `filter` `map` `forEach` | **`shift` `unshift` `reverse` `every` `some` `includes` `findIndex`** |
| **Math** | `floor` `abs` `min` `max` `random` `sqrt` `PI` | **`round` `ceil` `sin` `cos` `atan2` `pow` `hypot`** (`round` also on the V2 MK row until it lands) |
| **String** | `length` `+` concat, intern compare | **`charAt` `charCodeAt` `substring`/`slice` `split` `concat` `toUpperCase` `toLowerCase` `includes` `startsWith` `endsWith` `trim` `repeat` `padStart`/`padEnd` `toFixed`** |
| **Number / global** | numbers, `NaN` via ops | **`isFinite` `isNaN` `parseInt` `parseFloat` `Number(...)`** (MISSILE `isFinite` was FPGA-SIM `fault=4` `fsite=60011`) |
| **Time / rAF** | `Date.now()`, `requestAnimationFrame` | **`performance.now`** (alias of frame clock) **`cancelAnimationFrame`** |
| **Keys** | `e.key` + `keyCode` + `joy()` bits | **`e.code`** (`ArrowLeft` / `Space` / `KeyR`) so `keys[e.code]` works |

Regex `match`/`exec` and JSON `parse`/`stringify` stay **walled** (LUT). MK dotted `new` / `.call` / `Object.keys` on RTL stay **V2.0**.

Do **not** add a `shift` opcode to V1 RTL for one title.

### V1.0 hard walls (do not “fix” in RTL for one title)

Documented from real traces (MKPVP on FPGA-SIM / PYTHON):

| Wall | Symptom if ignored | V1 HTML workaround |
|---|---|---|
| `MAX_SPR` = 16 | `ASET has N sprites; RTL MAX_SPR is 16` | ≤16 PNG sheets (`jmr:spr:N`); atlases + crops. Keep sheets **modest** — not one multi-thousand-pixel-wide image (address math + SRAM traffic per lookup). |
| `Object.keys` (nid 41) is **PYTHON/HM only** | FPGA-SIM `fault=5` `fsite=4183` (unknown `CALL_NATIVE`) — the RTL exec64 arm is deliberately unimplemented | No `for…in` / `Object.keys` in an FPGA-SIM title; literal keys. (Compiler lowers `for…in` to `Object.keys` since 2026-08-21, so the loop *parses* — it still faults on RTL.) |
| Negative `setTransform` scale | Fighter draws 1px / vanishes (PYTHON `_xf`) | Left + right sheets; no `sx < 0` mirror |
| Math | Missing native / wrong paint | Only `floor` `abs` `min` `max` `random` `sqrt`. **V1.5:** `round` `ceil` `sin` `cos` `pow` … |
| **`Array.shift()` / `every` / `includes` / `charCodeAt`** | Card mint `CompileError` / `?NH` | Copy down / index / packed digits. **V1.5** natives. |
| `isFinite` / `performance.now` / `cancelAnimationFrame` | FPGA-SIM `fault=4` `fsite=60011` (CALL_VAL not a function); `performance.now` also fails mint if called as a method the wall lists | Frame counter + `Date.now()` / `rAF`. **V1.5** globals. |
| **16 locals per function** (`ENV_SLOTS`) | Card mint `CompileError` (`bfs(): 17 locals…`); `LOAD` HTML still works; `RUN` is `?NH` / FPGA-SIM bounces to READY | Split a helper. Do **not** drop game systems. |
| **`Int32Array` / `Uint8Array` / `Object.create`** | No such ctor on the chip (runtime not-a-function) or mint skip | Ordinary arrays. Grid `N>128` = one array per row. |
| **`ARR_CAP` = 128** | `fault 3` or mint/runtime overflow on a 360-cell `new Array(COLS*ROWS)` | Row arrays (20×18 → 18×20). BFS queue of the whole map: split (3×128). Do **not** shrink the playfield. |
| Canvas gradients / `globalCompositeOperation` / `rgba()` | Missing method or indexed FB | Hex `fillStyle` + `fillRect` / `arc`. **never** (not V1.5). |
| `e.code` | Stick/keys never set `keys.ArrowLeft` | V1: `e.key` + `keyCode`. **V1.5:** intern `e.code`. |
| mouse `clientX` | No mouse port — PYTHON/FPGA-SIM/BOARD never fire mousemove | Keys + `joy()` **required** for the same play. Chrome may also bind mouse. **never** mouse-only. |
| Per-tick maze flood / recursive BFS | Board HDMI **freezes** (one `rAF` never returns). No `ERROR`. PYTHON / FPGA-SIM still look playable. Old `finder` also `fault 3` (~36 objects/call vs 284 free slots). | One-step **chase**. Event-driven in-place flood on place/sell/reset is OK — keep the maze; split grid/queue at `ARR_CAP=128`. No `Array(n).fill().map(()=>Array(m))` on a tick. |
| Fresh `{x,y}` / object literals every frame | Object-heap overflow (`MAX_OBJ=960`, loud `fault 3`) | Reuse one mutable object; write fields. Do **not** hoist per-frame grids to startup (array-heap trap). |
| Assuming a hidden back buffer | Scanout tears through in-progress draws (present pipeline deleted, run 52) | Draw fast with `fillRect` / `drawImage` / `putImageData` (hardware ~1 px/clk). No isolation until you “present.” |
| **`fillText` is one 8×8 bitmap** | 16px HUD after world `setTransform` (`sx≈0.42`) still **k=1** (8 glass px) — “small text” missing on FPGA-SIM. `"Press Start 2P"` / TTF does nothing. Em-dash → `?` | `k = max(1, round(N * sx / 8))`. Glass-space: **8px or 16px**. DNKFAST-style HUD: **32px on Score/Lives only** — do not enlarge title/pause/select. ASCII 32–126. Do **not** add a small font to RTL. [GAME_DESIGN.md](GAME_DESIGN.md) |

Product ISA freeze (three compiles) still defines **Complete** rows above.
Library V1 titles may use only the **intersection** of Complete rows **and**
these walls (FPGA-SIM is stricter than “PYTHON Complete” for some hosts).

### V2.0 requirements — machine targets (no `MK.HTML`)

**`storage/MK.HTML` is gone.** Do not `LOAD` it or treat it as acceptance.
Numbers below are a **2026-08-20 census** of that lost file — they still
size the V2 caps. Land PYTHON → FPGA-SIM → board. No dukpy. No title-name
gates. Re-measure from a real `storage/*.HTML` when one needs them.

**Landed 2026-08-21 (PYTHON-side, zero RTL growth):** unary `+x`
(→ `x-0`), `throw` (soft: evaluate + drop), the `in` operator
(→ `o[k] !== undefined`), `for…in` (both `var k in o` and bare `k in o`,
lowered over a new `Object.keys` native **id 41** — implemented in the
FM and HM; **RTL arm intentionally absent**). All eight existing titles
still compile byte-identically; bytecode suite 198/198.

**Still V2 work (no current title exercises it):** dotted `new`, and
`Function.prototype.call`/`apply`.

#### Inventory (historical — lost `MK.HTML`, 2026-08-20)

| Metric | Value |
|---|---|
| File size | ~2.56 MB |
| Unique ASET sheets (`data:image` after dedup) | **518** |
| Path keys before dedup | 631 |
| Indexed pixel bytes (Σ w×h, 8 bpp) | **4 857 900 (~4.63 MB)** |
| Today’s asset SRAM contract (V1) | **4 MB** (`SRAM_BYTES`, IS61WV204816-class) |
| V2.0 asset SRAM target | **8 MB** (or more); MK needs ~4.63 MB so 8 MB has headroom |
| Glass | 640×480 Canvas |
| Compile today | **Fails** — `EXPECTED '('` at HTML **line 738** (`new mk.arenas.Arena({…})`). The earlier stops (unary `+` line 15, `for…in` line 20) are fixed. |

#### Caps / ASET (must change for this file)

**Read this row against shipped files (measured 2026-08-31).** The census
above is the **lost** fighter HTML. What ships and plays today are
`MKBIG.HTML` / `MKBIGCPU.HTML` (`tools/mkbig.py`), **inside** the V1 bank:

| shipped title | unique sheets | ASET bytes | vs 2,961,408 B wall |
|---|---:|---:|---|
| `MKBIGCPU.JSH` (2.700 MB) | 4 | 2,801,304 | **fits**, 5.4% under |
| `MKBIG.JSH` (2.692 MB) | 3 | 2,797,208 | fits |
| `DNKFAST.JSH` (2.260 MB) | 6 (of 12 URIs — identical ones dedupe) | 2,336,898 | fits |

Nothing in `tools/` sets `JMR_SRAM_BYTES`, so those mints ran with the
`_FB_SRAM_BASE_BYTES` check **active** — the fit is real, not an artefact of
a disabled wall. Locked by
`tests/test_self_hosted_compile.py::test_every_shipped_title_fits_under_the_art_wall`.

| Change | Exact need (historical census) |
|---|---|
| **`MAX_SPR` / `PROGRAM_MAX_SPRITES`** | Set both to **≥ 518** (RTL descriptor RAMs + encode refuse). 16 → 518 is the gap. |
| **Asset SRAM / ASET payload** | Current embeds need **~4.63 MB** indexed pixels (+ 768 B palette) — over today’s **4 MB** V1 bank. **V2.0 rebuilds the asset bank to 8 MB** (or larger if a later title needs it). Same **simple SRAM port** style (`addr`/`wdata`/`rdata`/`we`/`req`/`ack`); widen the address enough for 8 MB+. **ASIC constraint:** still **one chip**, no multi-die / fancy banked access — pick a single parallel async SRAM (or on-die SRAM of that class) that fits the package. FPGA board may keep DDR3 behind the same port (first 8 MB used). Do not silently drop sheets. |
| Heap | Re-check when a title actually needs V2; overflow must stay **loud**. No title-only heap. |

#### Compiler (blocks `RUN` before any VM)

| Gap | Evidence (historical census) |
|---|---|
| **`new` on a dotted member** (`new mk.arenas.Arena(…)`, `new mk.moves.Attack(…)`, …) | **70** `new mk.…` call sites (**39** distinct ctor paths — re-measured 2026-08-21). Compiler stops at line 738 with `EXPECTED '('`. V2 must accept `new Expr.Member(…)`: not just a parse fix — the callee is a **runtime function value**, so exec64 needs construct-on-a-value (allocate, set `this`, run, return the object). The 16×16 class/method intern tables cannot absorb it either (mk.js has ~25 constructor paths), so "treat them as classes" is not a shortcut. |

#### Natives / language (emitted or required by this engine)

| API / behavior | Evidence (historical census) | V2 action |
|---|---|---|
| **`for…in`** (→ needs working **`Object.keys`** on RTL, or a real `for…in` op) | **5** `for…in` loops (controllers, moves map, shim) | Implement **`Object.keys`** `CALL_NATIVE` on PYTHON + exec64 (and keep compiler lowering), **or** a dedicated `for…in` path — FPGA-SIM must not hit `fsite=4183` |
| **`Math.round`** | **2** call sites (+ HTML shim today) | Add **`Math.round`** as a real `CALL_NATIVE` (same shape as `Math.floor`); remove the shim once present |
| **`Math.floor` / `abs` / `min` / `max` / `random`** | Used | Already V1 — keep |
| **`typeof`** | Used | Already V1 — keep |
| **`setInterval` / `addEventListener` / `Image` / `drawImage` / `fillRect` / `fillText` / `createElement` / `querySelector` / `getElementById`** | Used | Already on Completeness tables |
| **`mk.Promise`** | Custom ctor in-file (`new mk.Promise`), **not** ES `Promise`/`async` | No browser Promise ISA required if this stays a plain JS object; do **not** add `async`/`await` for MK |
| **`Function.prototype.call` / `.apply`** (explicit `this`) | **42 sites, 11 distinct targets** — almost all the classic super-constructor pattern `mk.moves.Move.call(this, owner)`; also `Object.prototype.hasOwnProperty.call`, `callback.call`, and 4 `.apply(this, arguments)` | **A real V2 VM capability, not a shim.** exec64 must be able to invoke a runtime function value with a caller-supplied `this` (the machinery exists inside the class-ctor path — `vcall_set_this` — it is simply not exposed to a value call). Pairs with dotted `new` below; ~100–150 lines of exec64, **no new memories**. |
| **`arguments` object** | 2 sites (inside the `.apply` forwards) | Only needed to the depth `.apply` forwarding requires; do not build a full arguments object |

**Not required by that census (do not list as V2 drivers):**
`Math.sin` / `cos` / `atan2` / `hypot` / `ceil` (not referenced), negative
`setTransform` mirror (MK does not call `setTransform`), WebGL, Fetch, Audio.

#### Canvas

| Item | V2 need |
|---|---|
| **3/5/9-arg `drawImage`** | Keep Complete — fighter/arena sheets blit the same as V1 |
| Negative scale `setTransform` | **Not** a V2 driver (optional wider parity; MKBIG uses L/R sheets) |

#### Explicitly still never (V2 does not mean “browser”)

WebGL, Fetch/XHR, real audio graph, CSS layout engine, `eval`, workers,
`window.open` as browsing, ES `async`/`await` — same as V1 **never** rows.

**Done definition for V2.0:** a real `storage/NAME.HTML` that needs the V2
caps compiles; asset bank is **8 MB** (or the chosen larger size) with the
simple single-chip ASIC port rule; `LOAD` + `RUN` plays on PYTHON then
FPGA-SIM (user F9) with **no** dropped ASET art, **no** `Object.keys` /
`for…in` fault, **no** dotted-`new` compile error. Board after F9 approval.
There is **no** `MK.HTML` to compile.

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
| **HTML** | Document structure: tags, ids, one `<canvas>`, `<script>` | Tiny DOM stub + card `LOAD` (HTML) / `RUN` (`.JSH`) | The *file* you `LOAD` |
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

**Silicon vs this table (updated 2026-08-20):** Complete means **PYTHON /
JsHwVm**. A Complete row can still be broken or absent in FPGA-SIM RTL —
that is tracked in [potential bugs.md](potential%20bugs.md), which is the
authority for silicon.

*Implemented 2026-08-20 (midday pass):* `Array.reduce` (**39**),
`Array.slice` (**40**), `Array.sort(cmp)` (**41**), `ctx.textBaseline`
(**37**) — all probe-verified. Found and fixed on the way: expression-bodied
arrows swallowed the argument comma (compiler), a second `filter`/`map` per
program returned its callback un-run (**68**), same-frame `setTimeout`s piled
into one slot and `clearTimeout` cleared the wrong one (**66b**), and
listeners registered during a dispatch ran for the same event (**60**
partial — DONKEY's "Enter twice" flow now works).

*No RTL arm at all* (unchanged): `INSERT` / `DELETE` (**42** **43**),
`toISOString` (**23** — returns undefined), `globalAlpha` (**33** — writes
ignored, fades draw opaque), `ctx.font` size parsing (**45**),
comparator-less `sort()` (no-op). **V1.0:** on-chip compiler is **NOT** —
compile when you make the card (`.JSH`); PYTHON / FPGA-SIM / BOARD all
`RUN` that image from `card.img`.
**V1.5 compile is live** (`COMPILE` on the machine).

*Had an RTL arm that never actually worked* — found and fixed 2026-08-20, so
do not read the "Complete" in the Canvas/Method tables below as "silicon was
fine":

- **#49** `beginPath`/`moveTo`/`lineTo`/`arc`/`fill`/`stroke` — the parent's
  path-command buffer had **no writer**; every path primitive painted
  nothing in every title. Fixed (`quadraticCurveTo`, **#38**, landed in the
  same pass).
- **#53** `push` / `unshift` / `a[i] =` — wrote garbage or nothing.
- **#56** `join` — returned undefined.
- **#51** `drawImage` — a hit blitted zero pixels.
- **#52** prototype methods on `new`-ed objects — invisible.
- **#54** `JSON.parse` / `JSON.stringify` / `getImageData` / `putImageData`.
- **#57** arrays longer than 32 elements — silent halt.

*Fixed 2026-08-20 (later that day)* — the remaining title blockers, all
verified by probes plus gameplay smokes (all four titles play):

- **#58** WIN_FILL's first refill read used the fill's stale address — object
  literals holding 16+-element arrays lost their receiver (PACMAN maze).
- **#61** post-GC alloc committed over a LIVE slot (stale settle) — PACMAN's
  Game closure env died mid-frame (black screen, frozen Date limiter).
- **#62** class-method fast path ran its ALLOC with a stale kind — the call
  returned an empty array without entering the body (INVADERS bunkers).
- **#63** an event-driven title (listeners only, no rAF/timer) halted to
  S_DONE — DONKEY's title ignored Enter.
- **#64** key-event objects were built with len 0 — `e.key`/`e.keyCode`
  undefined.
- **#65** BIND re-injected a stale parent vcsp — +1 frame leak per class
  method call after a getter (DONKEY froze at CSTK).
- **#66** setTimeout starved at 64 (exec never saw fire-time frees).
- **#67** `Image.src` sprite fast-path read the value's slot instead of the
  receiver's — no sprite class, no dims, DONKEY drew no art.

*Known semantics gaps (playable, not blockers):* **#60** listener scoping
(element listeners are global; `.click()` fires every click listener;
listeners added during a dispatch run for the same event — DONKEY's title
Enter also triggers its character-select handler). `.find()` inside a
setTimeout callback returns a wrong value (probe `find-in-settimeout`).

`never` rows stay refusals.

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
| `<img>` / `jmr:spr:N` (PNG → `.ARTX`) | P1 | Art → ASET → SRAM on RUN | Complete |
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

#### Language — future Math natives (V2.0 backlog; not V1.0)

Not in the three-compile ISA freeze. Do **not** grow **V1.0** for these
unless a product title emits them. When scheduled, they are **V2.0**
`CALL_NATIVE`s (same shape as `Math.floor`) on PYTHON + both execs — **never**
title-gated RTL. See [Version 1.0, 1.5, and 2.0](#version-10-15-and-20).

`storage/ASTEROID.HTML` already ships without `Math.sin`/`cos`: it embeds
64-entry `UX`/`UY` unit-vector arrays in the HTML. That is **authoring around
a missing general native**, not an FPGA-SIM / game hardwire. Real
`Math.sin`/`cos` would let any title drop that LUT.

| API | Pri | Why (wider HTML5) | Status |
|---|---|---|---|
| `Math.round` | P2 | Wider HTML5 / historical fighter census | V2.0 |
| `Math.hypot` | P2 | Distance / collision | optional / later |
| `Math.sin` / `Math.cos` | P2 | Motion / FX; ASTEROID uses LUTs instead | optional / later |
| `Math.ceil` / `Math.atan2` | P2 | Smaller game use | optional / later |

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

Fonts are **never** Chrome TTF. PYTHON and RTL `fillText` share one 8×8
bitmap (READY scanout ROM, codes 32–126). `ctx.font = "NNpx …"` stores
**N only** — family/weight are ignored. Glyph scale is
`k = max(1, min(15, round(N * sx / 8)))` (`sx` = `setTransform` a).
Authoring sizes that actually change the picture: at `sx=1`, **8px** (k=1)
and **16px** (k=2). After a DONKEY-style world shrink (`sx ≈ 0.42`), **16px
is still k=1** (8 glass pixels) — bump **only Score/Lives** to **32px**, not
every `fillText`. Do not add a second (small) font to the chip — write the
HTML to the bitmap.
Indexed FB may stub `globalAlpha`. Do not let JS resize HDMI; glass stays
640×480.

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

From `functional_model/machine.py` HELP and `rtl/engines/jmr_console_engine.sv`.
Same verbs on PYTHON and FPGA-SIM; do not add RTL-only commands.
FPGA-SIM debug RPCs (`VMSTAT?`, …) are host helpers, not console verbs.

PYTHON/RTL = the verb exists. That is **not** “known working” on a title.
Silicon holes and HELP-text mismatch:
[potential bugs.md — Monitor](potential%20bugs.md#monitor-ready).

| Command | Pri | PYTHON | RTL | Notes |
|---|---|---|---|---|
| `DIR` | P0 | in | in | Names only (HTML / optional `.JS`) |
| `LOAD "NAME.HTML"` | P0 | in | in | Quotes optional. `LOAD n` (DIR index) is PYTHON. **V1.0:** FAT on `card.img` for PYTHON / FPGA-SIM / BOARD. |
| `RUN` | P0 | in | in | **V1.0:** all three rungs load the **card-minted** `.JSH` from `card.img`. Missing image → `?NH` / `?NB`. **V1.5:** `COMPILE` then `RUN`. |
| `LIST` / `LIST n-m` / `LIST -` | P0 | in | in | HTML line numbers. `-- MORE --` is Space/Enter, not a typed verb. |
| `EDIT n` | P0 | in | in | **V1.0 view-only era:** buffer change does not play (`RUN` is minted `.JSH`). **V1.5 live:** bare `EDIT` launches `EDITOR.JSH`. |
| `INSERT n` | P0 | in | **NOT** (`?SN`) | **42** — not a V1.0 hole. V1.5: unused number, no `INSERT` verb. |
| `DELETE n` | P0 | in | **NOT** (`?SN`) | **43** — not a V1.0 hole. V1.5: `10` + Enter. |
| `REMOVE "NAME"` | P1 | in (file alias of DELETE) | in | File delete on card. Not `DELETE n`. |
| `SAVE` | P1 | in | in | **V1.0:** does not change `RUN` (still `.JSH`). Authoring save is V1.5. |
| `NEW` | P1 | in | in | Clears source; RTL also `halt_pulse`. Same: not authoring until V1.5. |
| `CLS` | P1 | in | in | RTL HELP does not print this verb |
| `HELP` | P1 | in | in | PYTHON lists INSERT/DELETE; RTL prints `DIR LOAD SAVE NEW LIST EDIT RUN` |
| `MEM` | P1 | in | in | RTL prints `FB 640X480` |
| `ESC` | P0 | in | in | Machine BREAK; games must not steal Esc |
| `10 text` (numbered replace) | P1 | in | **NOT** | PYTHON READY only. Leftover typed-READY authoring, not the shipped `EDIT`/`COMPILE` loop. |

##### Version 1.5 — COMPILE live; typed-READY leftover

**V1.0:** `LIST` to learn; typed HTML at `>` is `?SN ERROR` on BOARD. Edit
verbs do not change `RUN`. Full glass, compile path, and LUT/BRAM budget:
[§ V1.5](#v15--type-paste-compile-edit-html-at-ready-no-card-required).

#### Asset / compile pipeline (not a JS API)

| Item | Pri | Status | Don’t |
|---|---|---|---|
| Minted `.JSH` ProgramImage from `card.img` | P0 | **V1.0:** PYTHON / FPGA-SIM / BOARD `RUN` this file (compile at card create). **V1.5:** `COMPILE` on the machine mints the same sidecar | Host-compile `storage/` on `RUN` as a second path |
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
| `playSfx(packed)` / `sound(ch,freq,vol,frames,slide)` nid 42 | P0 | Complete (Chrome `_chromePlay`; card nid 42; mint `-soundoff` stubs) |
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
- **`FLAG_VALUE64` is mandatory** (2026-08-21). `encode_chunk(...,
  value64=False)` raises in Python; the RTL faults **code 9** at
  `S_GOT_HDR2` and never enters an opcode state. The tagged Q16 encoding
  and its decoder are retired — see
  [REMOVING_EXEC32.md](REMOVING_EXEC32.md).

**Machine fault codes** (`VMSTAT fault=`): 1 eval-stack, 2 call-stack /
frame, 3 capacity (heap, timers, arrays), 4 environment handle, 5
unsupported opcode/native, 9 tagged image refused. `fsite=` is the RTL
line-ish site id; `ecode=` mirrors the exec unit's copy.

### Bytecode opcodes (34)

Source: `functional_model/bytecode.py` `Op` and `rtl/engines/jmr_js_vm.sv`
`localparam`. There is no opcode 0. FM and RTL names differ on a few rows;
the **number** is the ABI.

There is **no “known working” column**. An opcode can decode on both rungs
and still fail in a title because the hole is a native, a method, a heap
path, or an unverified loop. Notes cite a
[potential bugs.md](potential%20bugs.md) ID only when that file names this
opcode. Per-API silicon status is under Frozen ISA and the
[compatibility command map](potential%20bugs.md#compatibility-command-map-inspection-only--superseded).

| # | FM mnemonic | RTL | Notes |
|---|---|---|---|
| 1 | `LOAD_CONST` | `OP_LOAD_CONST` | |
| 2 | `LOAD_VAR` | `OP_LOAD_VAR` | a1: 0=env-chain walk, 1=direct global (vvars), 2+slot=verified local hint (speed pass, 2026-08-20) |
| 3 | `STORE_VAR` | `OP_STORE_VAR` | a1 same as `LOAD_VAR` |
| 4 | `ADD` | `OP_ADD` | |
| 5 | `SUB` | `OP_SUB` | |
| 6 | `MUL` | `OP_MUL` | |
| 7 | `DIV` | `OP_DIV` | |
| 8 | `LT` | `OP_LT` | |
| 9 | `GT` | `OP_GT` | |
| 10 | `EQ` | `OP_EQ` | |
| 11 | `JUMP` | `OP_JUMP` | |
| 12 | `JUMP_IF_FALSE` | `OP_JIF` | |
| 13 | `CALL_NATIVE` | `OP_CALL` | Native id in arg0 — table below. |
| 14 | `RETURN` | `OP_RETURN` | |
| 15 | `POP` | `OP_POP` | |
| 16 | `DUP` | `OP_DUP` | |
| 17 | `NEG` | `OP_NEG` | |
| 18 | `NOT` | `OP_NOT` | |
| 19 | `MAKE_ARRAY` | `OP_MAKE_ARR` | |
| 20 | `ARRAY_GET` | `OP_ARR_GET` | |
| 21 | `ARRAY_SET` | `OP_ARR_SET` | |
| 22 | `LET_VAR` | `OP_LET_VAR` | a1 bit0 = call-frame local; a1[7:1] = env slot hint + 1 (0 = none; speed pass, 2026-08-20) |
| 23 | `MOD` | `OP_MOD` | |
| 24 | `CALL_USER` | `OP_CALL_USER` | |
| 25 | `RET_VAL` | `OP_RET_VAL` | Leftover-frame / `forEach` fall-off: **6** |
| 26 | `MAKE_OBJ` | `OP_MAKE_OBJ` | |
| 27 | `GET_PROP` | `OP_GET_PROP` | Bare `.now` vs `Date.now()`: **14** (applied) |
| 28 | `SET_PROP` | `OP_SET_PROP` | |
| 29 | `NEW_OBJ` | `OP_NEW_OBJ` | Nested `new` / IIFE: **7** **8** |
| 30 | `CALL_METHOD` | `OP_CALL_METH` | Holes are per-method (Canvas / Array), not this decode. |
| 31 | `BIT_OR` | `OP_BIT_OR` | |
| 32 | `BIT_AND` | `OP_BIT_AND` | |
| 33 | `MAKE_FN` | `OP_MAKE_FN` | Closures / IIFE flags: **7** **8** |
| 34 | `CALL_VAL` | `OP_CALL_VAL` | IIFE / first-class call: **7** **8** |

### Native IDs (`CALL_NATIVE` / `OP_CALL` arg0)

Source: `functional_model/jsb_format.py` `NATIVE_IDS` (0–41). Aliases share
an id: `console.warn`→0, `addEventListener`→19, `removeEventListener`→36.
Grouped title surface is under Frozen ISA below — this is the numbered ABI.

| Id | Name |
|---|---|
| 0 | `console.log` |
| 1 | `clear` |
| 2 | `fillRect` |
| 3 | `swapBuffers` |
| 4 | `keyLeft` |
| 5 | `keyRight` |
| 6 | `keyFire` |
| 7 | `startLoop` |
| 8 | `keyUp` |
| 9 | `keyDown` |
| 10 | `Math.floor` |
| 11 | `Math.abs` |
| 12 | `Math.min` |
| 13 | `Math.max` |
| 14 | `Math.random` |
| 15 | `Math.sqrt` |
| 16 | `document.getElementById` |
| 17 | `document.querySelector` |
| 18 | `document.createElement` |
| 19 | `document.addEventListener` |
| 20 | `window.addEventListener` |
| 21 | `localStorage.getItem` |
| 22 | `localStorage.setItem` |
| 23 | `JSON.parse` |
| 24 | `JSON.stringify` |
| 25 | `Date` |
| 26 | `Image` |
| 27 | `requestAnimationFrame` |
| 28 | `setTimeout` |
| 29 | `setInterval` |
| 30 | `clearTimeout` |
| 31 | `clearInterval` |
| 32 | `localStorage.removeItem` |
| 33 | `_stub` (unknown CALL_NATIVE → no-op; `window.open`) |
| 34 | `Array` |
| 35 | `Date.now` |
| 36 | `document.removeEventListener` |
| 37 | `window.removeEventListener` |
| 38 | `document.dispatchEvent` |
| 39 | `window.dispatchEvent` |
| 40 | `typeof` |
| 41 | `Object.keys` — **PYTHON/HM only** (compiler `for…in` lowering). No exec64 arm: FPGA-SIM faults loud rather than pretending. |

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
  cheat). One physical SRAM; FPGA-SIM is the `.bin` path. The parent/exec
  dual copies are still real (exec64 owns registers the parent mirrors via
  `hs_*` pokes + one-shot masks) — that skew is the source of most
  historical bugs; see [potential bugs.md](potential%20bugs.md).
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
- `LOAD_VAR`/`STORE_VAR` a1 (speed pass, 2026-08-20): 0 = env-chain walk;
  1 = direct global — emitted for hoisted `function` names AND any site
  whose name is declared by **no** lexically-enclosing function scope (the
  compiler proves the walk could only fall through to vvars; retro-patched
  at the end of `Compiler.compile()`); 2+slot = local with a **verified**
  slot hint — RTL (env-walk phase 5) compares the key at the hinted slot
  first and on mismatch rescans from slot 0, so the #55 inliner-rebind
  rule still holds. `LET_VAR` locals carry the same verified hint in
  a1[7:1] (slot+1, 0 = none; env-walk phase 6; miss falls back to the
  normal find-or-append). PYTHON ignores all hints (dict by name) — same
  ProgramImage, same results, RTL just skips the scans.
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

## Historical snapshots (superseded)

The 2026-08-14 three-column gap list, feature matrix, and Frozen ISA table
do not teach anything the live sections above do not. Git has that snapshot
(`git log -p -- docs/JMR_JS_COMPATIBILITY.md`). Use
[Agent surface checklist](#agent-surface-checklist-html--javascript--css--canvas)
and [Frozen machine contract](#frozen-machine-contract).

---

## Regression seeds

| File | Role |
|---|---|
| `storage/INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML` | **Product titles** (LOAD these; ISA freeze) |
| `storage/ASTEROID.HTML` | Library title (vector Asteroids). Authoring: [GAME_DESIGN.md](GAME_DESIGN.md) |
| `storage/AURORA.HTML` | Library title (fillRect gem hopper) |
| `storage/MRDO.HTML` | Library title (Mr. Do! arcade). Portrait 384×480 letterbox; [GAME_DESIGN.md](GAME_DESIGN.md) |
| `storage/MKBIG.HTML` | **V1.0** library (MK frames packed to 4 MB / 3 atlases) |
| `storage/MKBIGCPU.HTML` | **V1.0** library (MKBIG art + CPU Kano). Ice ball + flame; 4th tiny shots atlas; still ≤16 SPR / 4 MB |
| In-memory ProgramImage | **V1.0:** minted `.JSH` from `card.img` (code + ASET). Not a `storage/` name |
| `storage/JOYDEMO.HTML` | Library smoke (joystick / arrows on Canvas) |
| `storage/SNDDEMO.HTML` | Library smoke (playSfx recipes; Chrome Web Audio, card `sound()` nid 42) |
| `storage/games_*` | Upstream archive only |

## Host notes (PYTHON)

- **Product path:** `functional_model/` **bytecode VM** — **V1.0** `LOAD`/`RUN`
  from project `card.img` (HTML + minted `.JSH`; ASET → FM asset-SRAM model).
  Using dukpy in `js_host.py` is **debt to remove**, not truth. Do not compile
  `storage/*.HTML` on `RUN` as a second path. **V1.5:** `COMPILE` on the
  machine.
- Use **`.venv`** (Pillow for `drawImage` on the Canvas engine).
- Playable HTML titles declare `<canvas width="640" height="480">` and **fill**
  that field. READY letterbox is console text only. Do not letterbox a smaller
  arcade raster inside 640×480. DONKEY may `setTransform` its own world.
- Esc remains machine quit (games must not steal Esc).
- Never claim FPGA-SIM/BOARD done because Chrome or dukpy painted.
