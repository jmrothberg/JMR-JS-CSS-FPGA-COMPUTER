# Session handoff — next agent start here

Last updated: 2026-08-13 (ARCHITECTURE CHANGE: external SRAM asset bank replaces
`NAME.DAT` spill — user decision. Mission: PYTHON + FPGA-SIM full-game match)

## Product goal (do not forget)

We already have a **fully working BASIC-native FPGA computer**:

- Repo: `/home/jonathan/JMR-BASIC-FPGA-COMPUTER`
- Board: Digilent **Nexys A7-100T** (Artix-7 **XC7A100T** — “T100”)
- Standalone: VGA + USB keyboard on **J5** + console + games — **keyboard works**

This repo is the **same product idea**, different language and graphics:

- Repo: `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER` (**this** tree)
- Board: Digilent **Nexys Video** (Artix-7 **XC7A200T** — “T200”)
- Native language: **JavaScript** (bytecode + engines), not BASIC tokens
- Glass: **HDMI 640×480** Canvas / FB, not VGA BASIC text strip
- Steal **method** from BASIC (PYTHON → real FPGA-SIM → board). Steal **not**
  A7 pinouts, BASIC ISA, or BASIC LUT history.

**End state:** a fully functional JS-native FPGA computer — tethered **or**
untethered — same experience as BASIC on T100, but JS/CSS-Canvas on T200.

---

## NEW AGENT MISSION (stop here until this is true)

**Goal of this stretch:** `INVADERS.HTML`, `PACMAN.HTML`, `DONKEY.HTML` each
`LOAD` + `RUN` as the **full game** on **PYTHON** and **FPGA-SIM (RTL)**,
and those two **look and play the same** (same glass, same keys, same
graphics quality). Chrome is the visual authoring check, **not** a proof
rung. **Do not flash the board** until the user F9-approves both.

**Definition of done (PYTHON + FPGA-SIM only):**

1. User types only `LOAD "NAME.HTML"` then `RUN` (edit HTML; line numbers =
   that file). Compile-on-RUN every time. Never prefer stale `.JSH`.
2. **Great graphics survive.** Donkey sheets are full quality. Art rides the
   fresh `.JSH` **ASET section** into the **external 4 MB SRAM asset bank**
   (2M × 16 IS61WV204816 contract; FPGA board = DDR3 behind a simple SRAM
   port; ASIC = the real chip — see `docs/ARCHITECTURE.md`). No `NAME.DAT`
   file. EDIT then RUN regenerates everything. Do **not** downscale into
   code BRAM.
3. PYTHON bytecode VM and FPGA-SIM RTL play the **same** title the **same**
   way. Battery stays green. No dukpy. No host twin (`JMR_SIM_HOST=1`).
4. Grow the **VM / compiler / natives / DAT pager** to fit the HTML. Do
   **not** rewrite the three games down to a subset. Do **not** delete files.

**Honest: not done yet (2026-08-13)**

| Item | Reality |
|---|---|
| Compile-on-RUN PYTHON | **Landed** — default HTML path is bytecode; dukpy only if `JMR_HTML_DUKPY=1` |
| Stale `.JSH` preferred | **Fixed on PYTHON** — `RUN` compiles then writes fresh `.JSH` |
| External SRAM asset bank (ASET) | **In progress** — replaces retired `NAME.DAT` spill. Historic trap: `tools/compile_js.py` packed sprites into `.JSH` SPR1 and **downscaled** (`w*h > 180000`, 8-color palette) |
| PYTHON vs Chrome | Invaders playable; Donkey/Pac-Man still VM-gap (sheets, maze, prototypes) — **not** full-game parity |
| FPGA-SIM vs PYTHON | Monitor verbs + HTML RUN path exist; Pac-Man SIM still a **24×24 blit stub**; not full-game match |
| Board | **Out of scope** this stretch. Last bit 03:36 lags the tree. No `.bit`/`.bin` |

Read first: `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`,
`.cursor/rules/python-first-parity.mdc`, `.cursor/rules/never-fake-fpga-sim.mdc`,
[CONSTITUTION.md](../CONSTITUTION.md) MEMORY + vendored-titles,
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md).

**FPGA fit:** [FPGA_FIT.md](FPGA_FIT.md) numbers are the **last routed bit**
(2026-08-13 03:36): **33,639 LUT / 12,872 FF / 2 BRAM / 11,210 slices**.
Morning RTL (640×480 dual FB + card `.JSB` load) is **not** in that report —
refresh `utilization_impl.rpt` after the next WNS≥0 impl. Do not invent counts.

---

## HARD RULES for the next agent

1. **Never fake FPGA-SIM.** F9 FPGA-SIM = real Verilator RTL
   (`sim/sim_build_synth/jmr_js_sim_server`). Host twin only with
   `JMR_SIM_HOST=1`. Missing binary → fail loud. Rule:
   `.cursor/rules/never-fake-fpga-sim.mdc`.
2. **Vendored HTML titles MUST RUN.** `INVADERS.HTML` / `PACMAN.HTML` /
   `DONKEY.HTML` LOAD+RUN playable on PYTHON → FPGA-SIM → BOARD.
   `?NH` is temporary tracked debt — never "done." Constitution +
   `.cursor/rules/python-first-parity.mdc`. The **HTML decides the keys**
   (raw keycodes; game handlers bind them). No hardcoded WASD in RTL.
3. **Do NOT rebuild / flash** until **all three HTML games** are green on
   FPGA-SIM *and* the user has personally tested them in the GUI (F9) and
   approved. PYTHON is the control first. Flash only if **WNS ≥ 0**.
4. **Order:** PYTHON perfect → **FPGA-SIM perfect** (user GUI-checks) →
   Vivado bit → SRAM smoke → QSPI. Never `.bit`/`.bin` before that gate.
5. **J15 USB Host is hardware-dead on this T200** (PIC24 never enumerates).
   Play and type from the **GUI / PROG tether**. Build the key-state engine
   so when J15 is fixed, untethered play needs **zero** code changes.
6. When unsure, consult the working BASIC sibling
   `/home/jonathan/JMR-BASIC-FPGA-COMPUTER` (method + monitor + FAT + PS/2).
   Adapt for T200 + HDMI + JS/CSS — never copy A7 pinouts or BASIC ISA.

---

## Honest three-column status (2026-08-13)

| | **PYTHON** (bytecode VM + Pillow) | **FPGA-SIM** (Verilator RTL) | **BOARD** (last SRAM flash) |
|---|---|---|---|
| Monitor | DIR LOAD LIST EDIT CLS RUN HELP | same verbs | tether HELP/READY OK |
| Titles | compile-on-RUN bytecode (DAT spill **not landed**) | HTML RUN path; **not** full-game match yet | bit lags (`?NH` / old hex) |
| Legacy demos | optional `RECTDEMO` / `JOYDEMO` / same-stem `.JS` | `.JSB` on card if present | as flashed |
| Play keys | GUI arrows+Space → KEYBITS | KEYBITS → `joy_in` | GUI → PROG `0xFE`+bits → `joy_in` (J15 dead) |
| Glass | 640×480 letterbox + game FB | native **640×480** game FB | 03:36 bit: letterbox CDC fix; game was still 160×120×4 |
| Cursor blink | GUI cyan block ~2 Hz | HDMI `frame_div[5]` | HDMI blinks |
| Keyboard jack | n/a | PS/2 bench PASS | **J15 dead** |

**Last flashed bit:** `build/nexys_video/jmr_nexys_video.bit` **2026-08-13 03:36**,
**WNS +0.139 ns**, SRAM Done. Contains: dual-clock text VRAM (HDMI glyph CDC),
tether KEYBITS, ALU/MUL pipeline, `keyUp`/`keyDown`, INVADERS hex path.

**Tree ahead of silicon (HTML compile-on-RUN + asset bank):** code BRAM
**32K**, heap, JSB v2 trailer. HTML `RUN` **recompiles** current HTML → fresh
`STEM.JSH` (never overwrite `INVADERS.JSB`; never prefer a stale `.JSH`).
Full-quality `data:image` → `.JSH` ASET section → external SRAM asset bank
(no `NAME.DAT`; do not downscale
sheets into code BRAM). Battery PASS: INVADERS/DONKEY/PACMAN HTML FPGA-SIM
pixels + KEYBITS Left. PACMAN HTML SIM is a **24×24 blit stub** plus
proto/assign/Date — maze/fillText path still weak. **No `.bit`/`.bin` /
Vivado** until you F9-approve all three on FPGA-SIM. Fit numbers will change
(32K code + heap + dual 640×480 FB).

---

## T100 (BASIC, working) vs T200 (JS, this repo)

| | **T100 — BASIC** | **T200 — JS (this repo)** |
|---|---|---|
| Board | Nexys **A7-100T** | Nexys **Video** (200T) |
| Video | VGA | **HDMI** 640×480 — **do not switch this board to VGA** for bad text |
| USB Host jack | **J5** (works) | **J15** (**dead** on this unit) |
| PIC24 role | USB HID → PS/2 Set-2 to FPGA | Same idea; this PIC24 never enumerates |
| FPGA PS/2 pins | `ps2_clk=F4`, `ps2_data=B2` | `ps2_clk=W17`, `ps2_data=N13` (XDC) |
| Proof | Type BASIC at READY | HDMI + PROG tether; **no standalone typing** |
| Host glass | GUI + UART/KEY merge | GUI + FT245 tether (channel **A** / `.0`) + KEYBITS |

### Keyboard / play (board)

- **J15 verdict 2026-08-13:** PIC24 enumerates no USB device. Use **F9 BOARD**
  and the **PC keyboard** (tether). Digilent ticket body is in git history /
  earlier handoff revisions — forum:
  https://forum.digilent.com/forum/4-fpga/
- **HDMI back-feeds 5 V** — unplug HDMI before any J15 power-cycle test.
- **JP4 = boot source only** (not a keyboard enable).
- LEDs: LD7=`ps2_strobe`, LD6=`ps2_clk`, LD5=`ps2_data`, LD4=`~sd_cd`,
  LD3=MMCM, LD2=READY, LD1=game_mode, LD0=alive.

---

## Games on disk (one HTML title each)

| Game | Source (LOAD) | Compile output (invisible) | Card 8.3 |
|---|---|---|---|
| Space Invaders | `INVADERS.HTML` | fresh `.JSH` (code + ASET art) | `.HTM` |
| Pac-Man | `PACMAN.HTML` | fresh `.JSH` (code + ASET art) | `.HTM` |
| Donkey Kong | `DONKEY.HTML` | fresh `.JSH` (code + **full-res** ASET art) | `.HTM` |

**Product rule:** real HTML/JS native CPU (FPGA → ASIC). Same `.HTML` in
Chrome (authoring) and on PYTHON/FPGA-SIM/BOARD via **compile-on-RUN
bytecode** — **not dukpy**, **not a stale `.JSH`**. Great graphics stay:
full-quality `data:image` art rides the `.JSH` ASET section into the
external SRAM asset bank (no `NAME.DAT`). EDIT HTML then RUN regenerates
everything. Same-stem `.JS`/`.JSB` are
legacy demos, not twins. Demos: `RECTDEMO` / `JOYDEMO` / `CLIMB`.
`storage/games_*` = upstream only.

HTML titles target **640×480** (PACMAN tile size 14; DONKEY world via
`setTransform`).

```text
# All runtimes (honest path)
LOAD "PACMAN.HTML"   # or DONKEY.HTML / INVADERS.HTML — edit this
RUN                  # ALWAYS compile current HTML → fresh .JSH
                     # (code → code BRAM, ASET art → external SRAM bank)
```

**Compile-on-RUN:** source of truth = loaded HTML (editor line numbers).
`.JSH` is invisible output only — never prefer an old sidecar; stale `.JSH`
may be deleted. **Asset bank:** Donkey-class sheets go full-res into the
ASET section / external SRAM, never packed into code BRAM or downscaled.

Gap list: [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md).
Rule: `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`.

### Constitution mandate (2026-08-13)

`INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML` **MUST RUN** on PYTHON
**bytecode** → FPGA-SIM RTL → BOARD (then ASIC). `?NH` = temporary debt,
not done. HTML decides keys. **No dukpy product path. No `.bit`/`.bin` until
all three are green on FPGA-SIM and the user GUI-tests.**

### Compiler v2 progress (PYTHON — 2026-08-13)

Landed in `functional_model/compiler.py` + `bytecode.py` + `machine.py` +
`input_engine.py`:

- Language: `for`/`for-of`/`switch`/`break`, `&&`/`||`/ternary/`?.`, real `%`,
  `+=`/`++`, `function`/`return`/arrows/`MAKE_FN`/`CALL_VAL` (IIFE), classes +
  getters + class fields, `new` (incl. `var F=function` ctors), arrays/objects,
  `typeof`, regex stubs, trailing commas, `$` ids, multi-`var`, `.35` floats.
- VM: shared `_exec` for `run`/`call_fn`, `forEach`/`reduce`, Image onload,
  canvas swap each HTML frame, `drawImage`→fillRect stub, key-state engine
  (PS/2 Set-2 → keyCode + tether KEYBITS OR).
- **`INVADERS.HTML` / `DONKEY.HTML` / `PACMAN.HTML` PLAY on PYTHON
  compile-on-RUN bytecode** (not dukpy, not a stale `.JSH`). `RUN` always
  recompiles the loaded HTML and writes a fresh internal `.JSH`.
- FPGA-SIM: host compile-on-RUN patches card `.JSH` + `SDRELOAD`, then RTL
  FAT-loads that fresh file (`?NH` if missing — never Invaders hex).
- Simple `.JS` titles still RUN. No `.bit`/`.bin` until F9 FPGA-SIM approval.

### Grow the VM to the HTML (do not shrink the games)

INVADERS bytecode path is playable; keep bindings on `event.key`
(a/d/arrows/space). DONKEY/PACMAN still need more FM/RTL coverage
(prototype `Foo.prototype.x=`, full `drawImage` sheets via the **external
SRAM asset bank**,
path APIs, maze). **Do not edit the three HTML titles down** so they “fit”
a weak VM — grow compiler + VM + asset bank instead.

**Inventory:** INVADERS = first end-to-end (fillRect aliens + PNG ship).
DONKEY = sprite sheets / setTransform (full-res ASET). PACMAN = maze +
prototypes.

---

## Battery (must stay green)

```bash
make -C sim sim_server_synth
make -C sim tb_ps2_typing
.venv/bin/python tools/make_sd_image.py create sim/card.img
.venv/bin/python tools/check_runtime_parity.py   # BATTERY PASS (bytecode / no dukpy cheat)
```

Vivado (**FORBIDDEN until all three HTML games are green on FPGA-SIM and the
user has personally tested them in the GUI**). Only publish if WNS ≥ 0:

```bash
source scripts/vivado_env.sh
make -C tools/board_flow bit
make -C tools/board_flow flash    # SRAM first; QSPI later
```

---

## FPGA-SIM proven (not host twin)

- 64×16 letterbox, origin (64,112); one prompt (strip trailing blanks / bare `>`)
- LIST / MORE / EDIT / CLS; FIFO depth 128
- Product path: `LOAD "*.HTML"` / `RUN` → **compile-on-RUN** → fresh bytecode
  into code BRAM (never prefer stale `.JSH`; never Invaders hex)
- Native **640×480** game FB; tether dump may subsample
- KEYBITS → `joy_in`; GUI mouse stick **OFF**
- PS/2 bench OK; board J15 still dead → PROG tether

## PYTHON proven

- Same monitor verbs; `_keep_fb` after RUN
- Titles: HTML via **compile-on-RUN bytecode** (default). dukpy only `JMR_HTML_DUKPY=1`.
- **Not done:** Chrome-identical full games; external SRAM asset bank (ASET) landing
- GUI letterbox **cyan cursor blink**

## Board proven (update when re-flashed)

- See last flash note above; claim only what that bit actually runs
- HTML on matching bit = compile-on-RUN / fresh `.JSH` VM; tether KEYBITS until J15 fixed

## One glass (FEATURE, not a bug)

READY/monitor = 64×16 letterbox. RUN = full-field game FB. Same 640×480 HDMI
and GUI mirror.

Torn HDMI **glyphs** were clock-domain: VRAM write @ core_clk, async read from
pixel_clk. Fixed like BASIC (`scan_clk=pixel_clk` + aligned scanout).

---

## `(NO VM)` / `?NB` / `?NH`

- Old `(NO VM)` = no bytecode VM (RECTDEMO engine only)
- `?NB` = no companion `.JSB` on the card
- `?NH` = HTML not executable on the RTL VM yet

---

## Next agent priority

1. Land the **external SRAM asset bank** (ASET section; stop packing /
   downscaling Donkey into code BRAM — `NAME.DAT` design is retired).
2. Grow compiler + bytecode VM + natives until all three HTML titles are
   **full games** on PYTHON, then the **same** on FPGA-SIM RTL — look and
   play match. Never dukpy, never host twin, never stale `.JSH`.
3. Keep `tools/check_runtime_parity.py` **BATTERY PASS** after RTL edits.
4. **No board / Vivado / `.bit`** until the user F9-approves PYTHON + FPGA-SIM.
5. Do **not** treat J15 as an RTL bug. Tether until hardware/RMA.
6. Never call `JMR_SIM_HOST=1` “FPGA-SIM.”

## Key files

| Area | Path |
|---|---|
| SIM server | `sim/sim_main.cpp`, `runtime/sim_backend.py` |
| Board tether | `runtime/board_backend.py`, `rtl/engines/jmr_uart_link.sv` |
| Glass | `functional_model/canvas_engine.py`, `rtl/video/jmr_text_hdmi_scanout.sv` |
| VRAM CDC | `rtl/engines/jmr_video_vram.sv` (`scan_clk`) |
| VM | `rtl/engines/jmr_js_vm.sv`, `functional_model/jsb_format.py` |
| Console / JSB load | `rtl/engines/jmr_console_engine.sv` |
| Battery | `tools/check_runtime_parity.py` |
| BASIC reference | `/home/jonathan/JMR-BASIC-FPGA-COMPUTER` (read-only) |
