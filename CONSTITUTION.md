# JMR JS COMPUTER

## Project Constitution v0.2

This document is the architectural specification for the JMR JS Computer
(**NLISC-JS**: Native Language Instruction Set Computing with JavaScript —
the language you type *is* the chip’s instruction surface; an **FPGA**
Field-Programmable Gate Array game computer). Words:
[README.md — Words used](README.md#words-used-in-this-project).
Family name:
[README.md](README.md#nlisc-native-language-instruction-set-computing).

This file is **copy 2** of “no dukpy / vendored HTML
titles” (copy 1 is `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`). Other
critical “do not”s live in two places only — see
[README.md — Two copies](README.md#two-copies-of-every-critical-do-not).

If there is ever a conflict between this document and the implementation,
THIS DOCUMENT IS CORRECT.

The implementation must be changed to match the specification.

Never simplify the architecture without updating this document.

Never replace major architectural concepts because they appear "easier."

The goal is educational elegance, not minimum code.

---

# PROJECT GOAL

Build an original **standalone** NLISC-JS FPGA computer whose native
programming environment is JavaScript, aimed at playing and editing
HTML5/Canvas-style 2D games.

The user never programs a conventional **instruction set architecture**
(ISA — the chip’s native operations — no assembly, no hidden RISC).

JavaScript is parsed into compact **JMR-JS bytecode**; bytecode operations
dispatch FPGA execution engines (microcode + engines). This is NOT:

- a soft CPU running V8 / SpiderMonkey / QuickJS
- a browser-on-FPGA stack with a general-purpose core underneath
- Linux, Chrome/Firefox/WebKit, or a general-purpose HTML/CSS browser
- a port of the JMR BASIC computer with different keywords

It is a new architecture: **JavaScript bytecode is the ISA**; HTML is the
title file (minimal game container), not a second instruction set. Canvas
drawing is hardware-accelerated.

## Vendored-titles mandate (success criteria, non-negotiable)

This is a **real NLISC-JS CPU** (HTML titles, JS ISA, minimal CSS as needed)
— FPGA first, then ASIC. Same method as the NLISC-BASIC sibling; **not** a
browser or dukpy box.

The machine plays real HTML5/Canvas games. One title = one file:
`INVADERS.HTML`, `PACMAN.HTML`, `DONKEY.HTML`. Those **MUST LOAD + RUN with
the same glass on PYTHON → FPGA-SIM → BOARD** (then ASIC).

- **No dukpy cheat.** PYTHON runs the **JMR bytecode VM**. **V1.0 `RUN`**
  loads the minted `.JSH` **ProgramImage** from `card.img` (same bytes on
  PYTHON, FPGA-SIM, and BOARD). Compile happens at **card create**; errors
  must report **line numbers from that HTML**. dukpy/Duktape/V8/QuickJS must
  not be the product execution path. Chrome may open the same `.HTML` for
  authoring only — that does not count as PYTHON/FPGA proof.
- **V1.0 disk is `card.img`:** PYTHON, FPGA-SIM, and BOARD all `LOAD`/`RUN`
  from the same FAT image (project `card.img`; board = that image burned to
  µSD). `storage/` is the **seed only** — rebuild with
  `python3 tools/make_sd_image.py create card.img`. The FPGA has **no
  on-chip JS compiler**. **Compile happens when you make the card** — the
  builder **mints** `NAME.JSH` from the current `.HTML` (never copy a stale
  `.JSH` out of `storage/`). `LOAD` still shows HTML; `RUN` loads that
  minted `.JSH`. Do **not** give PYTHON or FPGA-SIM a host compile-on-RUN
  of `storage/*.HTML` while the board runs the card. **V1.5 compile is
  live:** `LOAD` → `EDIT` → **`COMPILE`** → `RUN`. `RUN` still loads `.JSH`
  from the card. Compiler/editor are ordinary card programs, not a new ISA.
  Typed-at-READY numbered authoring of *new* programs is leftover.
- **Asset bank (external SRAM — replaces the retired `NAME.DAT` spill).**
  Great graphics stay at **full quality**. You draw PNG sheets; `make_artx.py`
  writes `NAME.ARTX`. On every `RUN` the minted `.JSH` carries that art
  (per-title 256-entry palette + full-resolution sprite banks) as the
  **ASET section** of that ProgramImage;
  the loader streams the section into the **external 4 MB SRAM asset bank**
  (see MEMORY). There is **no `NAME.DAT` file**. Do not pack Donkey art into
  code BRAM or downscale sheets to “fit.”
- **No host-twin FPGA-SIM** (FPGA simulation — Verilator of the same RTL).
  F9 FPGA-SIM = Verilator RTL. `JMR_SIM_HOST=1` is explicit debug only.
- `?NH` ("no HTML") is a **temporary, tracked debt** — never an acceptable
  final state. A runtime showing `?NH` for a vendored title means the product
  is **NOT DONE**.
- Proof ladder: PYTHON **bytecode** truth → FPGA-SIM (real Verilator RTL) →
  BOARD → ASIC. Never fake any rung; never call silicon done from Chrome/dukpy.
- **The HTML decides the keys.** Hardware/VM deliver raw key events
  (keycodes); each game's own `keydown`/`keyup` handlers define its bindings.
  No hardcoded key→action maps in RTL.
- Every game feature must work from card + local input alone (untethered).
  Tether = debug mirror only. When the J15 keyboard hardware is fixed, play
  must work standalone with **zero code changes**.
- Same-name `NAME.JS` / `NAME.JSB` are **not** product twins of the HTML
  titles.   Card seeds are `.HTML` (plus optional library HTML like
  `JOYDEMO.HTML`). **V1.0:** PYTHON / FPGA-SIM / BOARD play `card.img`; the
  builder **mints** `.JSH` when you make the card. **V1.5:** `COMPILE` on
  the machine mints the same sidecar (`RUN` is unchanged). See Vendored-titles.

---

# FUNDAMENTAL PHILOSOPHY

Traditional computers: CPU → runtime / browser → JavaScript.

We reverse this:

JavaScript → bytecode → processor (engines + microcode).

Language is the **ISA** (Instruction Set Architecture). Canvas / blitter /
event-loop are first-class machine engines, not library code on a hidden CPU.

---

# NON-NEGOTIABLE DESIGN RULES

1. No Z80 / 6502 / RISC-V / MicroBlaze / soft general-purpose CPU as the
   execution cheat.
2. No JS interpreter or browser engine (dukpy/Duktape/V8/QuickJS/Node) as
   the PYTHON / FPGA-SIM / BOARD / ASIC product path.
3. JavaScript (bytecode) is the architectural instruction surface.
4. User never sees a conventional assembly ISA as the programming model.
5. Architecture must remain understandable (engines, not a monolith).
6. Every subsystem must have a Python reference model.
7. Every FPGA module must correspond to a documented subsystem.
8. Uniform glass: typed / user-visible behavior matches across F9 runtimes
   (PYTHON → FPGA-SIM → BOARD) before a feature is "done."
9. ASIC / tapeout path is out of scope until explicitly opened (do not import
   BASIC ASIC rules by default).
10. **Standalone required:** HDMI + local keyboard + local play controls; a PC
    is not required to use the machine. UART/JTAG are flash/debug only.
11. **FPGA-SIM RTL must be synthesizable SRAM** (Static Random-Access
    Memory: address in this clock, data **next** clock). Same `rtl/*.sv`
    as the `.bin`. One 1-D JavaScript heap. Extra clocks are silicon, not
    a reason to peek. `sim_server_synth` PASS is Verilator, not a
    bitstream. Loud overflow; do not hide it in the 4 MB asset bank.
    **Copy 1** of the RAM law: `.cursor/rules/never-fake-fpga-sim.mdc`.
    **Copy 2:** [docs/FPGA_FIT.md](docs/FPGA_FIT.md) NEVER table. One heap
    + generation: `one-heap-keep-gen.mdc`. Live caps:
    [docs/FPGA_FIT.md](docs/FPGA_FIT.md) paper budget.

---

# DEVELOPMENT ORDER

**PYTHON** = the fast functional model (same *results* as the chip, not the
same wall-clock). **FPGA-SIM** = Verilator of the same RTL as the bitstream.
Do not skip rungs. Spec ladder (copy 2 of the method):
[README.md Method](README.md#method-steal-from-the-basic-sibling--not-the-product).
Copy 1: `.cursor/rules/python-first-parity.mdc`.

Architecture
↓
Python Functional Model (**JMR bytecode VM** — not dukpy)
↓
Python Hardware Model (explicit memories / FSMs / clocks)
↓
SystemVerilog
↓
Simulation (FPGA-SIM / Verilator RTL — never host twin)
↓
FPGA (`.bit` / `.bin` on primary board)
↓
ASIC (only after FPGA honesty)
↓
Optimization

Do not skip steps. Do not ship RTL-only UX that PYTHON / FPGA-SIM reject.
Do **not** flash the board to debug gaps that FPGA-SIM has not already closed.
FPGA-SIM means **real Verilator RTL** of this design — never a silent host twin.

**Uniform glass (F9 PYTHON → FPGA-SIM → BOARD):** every user-typed / user-visible
behaviour must work the same way on the **bytecode** path before board “done.”
User titles: `LOAD "NAME.HTML"` / `RUN` only. **V1.0:** PYTHON, FPGA-SIM,
and BOARD all `LOAD`/`RUN` the same `card.img` (`LOAD` = HTML on FAT;
`RUN` = minted `.JSH` ProgramImage with ASET art; art streams to the
external SRAM asset bank). Do **not** compile `storage/*.HTML` on host
`RUN` as a second path. **V1.5:** `COMPILE` on the machine; `RUN` still
loads `.JSH`. See Vendored-titles.
Cursor rules: `python-first-parity.mdc`, `no-dukpy-cheat-native-cpu.mdc`,
`never-fake-fpga-sim.mdc` (includes: RTL heaps must be SRAM, not Verilator-only
2-D combo arrays; parent `unique case` reads `*_rdata`, never `arr_len[v]`),
`one-heap-keep-gen.mdc` (one physical heap; never skip generation to hide
exec/parent dual-copy skew).

The BASIC sibling (`JMR-BASIC-FPGA-COMPUTER` on Nexys A7-100T) is a **working
reference for method and USB-HID→PS/2 bring-up**, not a pinout or instruction
set architecture source.

## NLISC method (JS, BASIC, or a later native GPU)

This is how to build or **update** an NLISC machine (the native language
*is* the ISA: JavaScript here; BASIC on the sibling; a native GPU would
use a graphics language). Steal this ladder. Do **not** steal the other
product’s tokens, pins, or microcode. Family name / TRS-80 / ASIC write-up:
[README.md](README.md#nlisc-native-language-instruction-set-computing).

**Speed:** Python must stay **fast**. It matches **what** the chip would do
(same program bytes, same numbers, same errors), not **how long** the chip
takes. Do not throttle Python to one hardware clock or one micro-operation
per tick just to “feel like silicon.” Field-programmable gate array
simulation and the board keep real cycle time; Python does not.

1. **Freeze one executable contract.** Numbers, tagged values, stack, heap,
   garbage collection, timers/events, and overflow are written down once.
   Python and register-transfer level (the SystemVerilog hardware
   description) must mean the same bits. Silent stack resets and guessed
   “nursery” rewinds are not garbage collection.
2. **Python executes what the chip receives.** The compiler may use rich
   Python objects while compiling. Parity proof does not: it runs the
   **serialized program** (here: ProgramImage words; BASIC: the token
   stream the engines fetch). A Python `Chunk` or abstract syntax tree
   that the hardware never sees is not a reference. Python may finish
   that program in far fewer host milliseconds than the chip.
3. **Lockstep before programs.** Same blob into Python and Verilator.
   Compare instruction pointer, frames, heap, events, canvas/video, and
   errors at small checkpoints. Do not debug titles/games until those
   **results** match. Lockstep is not “same wall-clock time.”
4. **Replace hardware semantics incrementally.** One engine (Number, heap,
   frames, events). Remove a hack only when its lockstep test passes
   without it. Caps are general and fail loudly. Acceptance titles are
   tests, not `if (PACMAN)` / `if (ADVENT)` gates.
5. **V1.0 `RUN` loads the minted `.JSH` from `card.img`.** PYTHON,
   FPGA-SIM, and BOARD share that image. Compile is at **card create**
   (`make_sd_image.py`), not a host recompile of `storage/` on `RUN`.
   **V1.5:** `COMPILE` on the machine mints `.JSH`; `RUN` is unchanged.
   See Vendored-titles. Fat art
   belongs in the asset bank, not squeezed into code RAM.
6. **PYTHON → real FPGA-SIM → user F9 → board → ASIC.** No host twin as
   the sim default. No `.bit`/`.bin` to “define” a feature FPGA-SIM still
   rejects. Visual play is the user’s F9, not a snippet PASS.
7. **Write FPGA-SIM as if it were the chip.** Same SystemVerilog as the
   `.bin`. SRAM ports from day one — do not grow combo arrays “until games
   work, then flatten.” New unique-case arms **read** `*_rdata` (wait beat);
   do not add `mem[idx]` “just this once.” Shape and depth:
   [docs/FPGA_FIT.md](docs/FPGA_FIT.md). Coding rules:
   `.cursor/rules/never-fake-fpga-sim.mdc`. Examples in-repo:
   `rtl/engines/storage_engine.sv` (`sbuf`), `rtl/engines/jmr_video_vram.sv`
   (Port A), parent JOIN `jn_rd_arm` + `varr_len_rdata`. Skipping generation
   so a second heap would not “look stale” is forbidden. FPGA-SIM must
   remain the path that compiles to a standalone `.bin`.

A native graphics processing unit is the same machine with draw engines as
first-class instruction-set operations (Canvas here; COLOR/SET on BASIC).
It is not a second central processing unit running a browser or a ROM
interpreter.

---

# TARGET HARDWARE

**Primary board:** Digilent **Nexys Video** — Artix-7 **XC7A200T-1SBG484C**.

**Second port (later):** Puzhi **PA-StarLite** (XC7A200T) — same engines,
different pins/XDC only after Nexys Video works. Do not dual-bring-up day one.

Pinouts, clocks, video, input, storage, and fit budgets are owned by *this*
repo’s `docs/FPGA_BRINGUP.md` and `constraints/` — never copy Nexys A7-100T
numbers from the BASIC machine.

**Display (frozen):** HDMI Source, native **640×480 @ ~60 Hz**, 8 bpp indexed,
256-entry RGB888 palette, double-buffered. **V1:** dual FB in BRAM
(`jmr_mini_fb.sv`). On-chip working set = FB + code + heap; game art lives in
the **external SRAM asset bank** (FPGA: board DDR3 hidden behind an SRAM-port
bridge; ASIC / final PCB: one IS61WV204816 chip). See MEMORY.

**Standalone input (frozen):**

- USB HOST keyboard (typing / EDIT / hardware ESC)
- Pmod **digital joystick / gamepad** for play
- USB mouse **not** required for V1 (USB HOST is one device; no Digilent hub)

**This T200 unit:** J15 USB Host is hardware-dead. Type and play from the GUI
PROG tether until RMA. The freeze above is still the product jack. Live status:
`docs/SESSION_HANDOFF.md`.

**Primary development host:** Ubuntu / Debian Linux (day-one path:
[docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md) — GUI, Verilator, Vivado, flash).

Mac remains usable for the Python GUI and Verilator FPGA-SIM; AMD **Vivado is
Linux-only**. Board bitstream build and flash happen on Linux.

Development tools:

Python

Cursor

Vivado (Linux)

Verilator

GitHub

openFPGALoader

---

# USER EXPERIENCE (V1 intent)

Boot into a monitor READY prompt (NLISC-JS glass), not a desktop or browser.

```
JMR JS READY
>
```

Monitor commands (DIR / LOAD / RUN / LIST / EDIT / SAVE / …) load and edit
ordinary `.HTML` titles (the disk format). ESC hard-breaks a running game
back to READY without depending on the program. Same-stem `.JS` files are
leftover demos, not product twins.

V1 goal shape: a useful subset of JavaScript + Canvas for classic 2D arcade
games — not arbitrary modern websites.

The user never needs to know the internal microcode or engine wiring.

---

# MACHINE SURFACE (ISA family)

Architectural surface includes (names evolve; engines stay separate):

- JavaScript statements / expressions / control flow / functions / objects
- Compact JMR-JS bytecode as the native execute form
- `console` I/O verbs that are machine ops, not host cheats
- Canvas 2D ops (fillRect, drawImage, …) → hardware Canvas / blitter
- Minimal HTML container for games (`canvas` + `script`) — not a layout browser
- Event loop / timers / `requestAnimationFrame` (hardware-visible)
- Keyboard + joystick/gamepad input events

**CSS (V1):** do **not** implement a general CSS engine. Games draw on Canvas.
A tiny CSS subset is allowed later only if a target game proves it necessary.

Every opcode / dispatch entry has one microcode path and one implementation.
Full implement / don’t tables (HTML, JavaScript, CSS, Canvas — Complete or
TBD) live in `docs/JMR_JS_COMPATIBILITY.md` **Agent surface checklist**.

---

# CPU ARCHITECTURE

The processor consists of independent hardware engines.

Program Sequencer / micro-sequencer

Lexer / Tokenizer

Parser / bytecode generator (share hardware; compile-time cost OK)

Bytecode execution engine

Expression / ALU / number engine

Object / Heap Engine

String Engine

Canvas Engine

Blitter

Paint / Video Engine (HDMI scanout)

Event / Timer Engine

Keyboard / Console / INPUT Engine

Joystick / gamepad PHY (GPIO)

Storage Engine

Audio Engine (V1 path after graphics games run)

These engines communicate through defined interfaces.

Do not merge them into one giant module.

Share engines; never duplicate. Prefer multi-cycle shared datapaths over
one-cycle-per-op parallelism.

---

# EXECUTION MODEL

Execution is:

.HTML title (JavaScript inside `<script>`)
↓
tokenize / parse
↓
compact JMR-JS bytecode
↓
fetch / decode / dispatch bytecode
↓
execute microcode (drive engines)
↓
fetch next unit

Do **not** execute JavaScript source as one giant RTL state machine.
Bytecode is the native instruction representation. Microcode is architectural
(BRAM / documented store). The programmer never sees it.

---

# MEMORY

Documented map: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (external SRAM
port + 4 MB layout). **Do not impose a fake 64 KB BASIC house.** **BRAM**
(Block RAM, on-chip) is working RAM; **µSD** (microSD) is disk; the
**external SRAM asset bank** holds game art.

**External SRAM asset bank (architecture, 2026-08-13):** one **4 MByte SRAM,
2M × 16 (ISSI IS61WV204816)** behind a simple synchronous port
(`addr[20:0]`, `wdata[15:0]`, `rdata[15:0]`, `we`, `req`, `ack`) at core
clock. The JS CPU / blitter never see controller detail. Same port, three
implementations:

- **FPGA-SIM:** behavioral 4 MB model behind the identical port (the
  VM/blitter RTL above it is the real product RTL — never a host twin).
- **FPGA board:** Nexys Video **DDR3** hidden behind a MIG-based bridge
  presenting the same SRAM port (first 4 MB used).
- **ASIC / final PCB:** the real IS61WV204816 chip; trivial timing wrapper;
  zero RTL changes above the port.

On every `RUN` the compiler emits the title's full-quality art (per-title
256-entry RGB888 palette + 8-bpp indexed sprite banks) as the **ASET
section** of the ephemeral ProgramImage; the loader streams code → code BRAM
and ASET → asset SRAM. Sprite handles/descriptors (w, h, SRAM offset) live
in the ProgramImage; pixels never enter code BRAM. There is **no `NAME.DAT`
file** — that earlier spill design is retired.

**On-chip arrays are SRAM, not simulation tables.** Code, heap, dual FB,
editor buffer, and char VRAM must infer as block RAM (FPGA) / compiled
SRAM (ASIC): 1-D, 1–2 ports, registered read. Verilator happiness is not
proof. Combo 2-D heaps (`vobj_key[obj][slot]` compared in one cycle) and
combo `arr_len[v]` / `obj_n[fo]` inside `unique case (casestate)` are
forbidden even if FPGA-SIM titles look right. Address this clock; consume
`*_rdata` next.

**V1 on-chip working set** (generous — see ASIC target below):

- Dual framebuffer 640×480×8 (front/back)
- Code BRAM (live bytecode after `RUN` — sprite handles, not art)
- JS heap (objects / arrays / strings)
- Editor/source buffer (LIST/EDIT working copy; disk HTML is master)
- Boot / microcode ROM, FIFOs, palette, MMIO

**ASIC target (updated 2026-08-23, supersedes the 2026-08-13 "~1 MB-class
on-chip SRAM" line): SkyWater 130 nm, same process as the BASIC chip, ~2×
its die.** At that node, on-die SRAM is **tens-to-low-hundreds of KB** —
the old ~1 MB-class figure was a node assumption this process cannot meet.
Measured requirement of the current FPGA architecture: **~1.6 MB BRAM +
~0.35 MB LUTRAM (~1.95 MB on-chip)** — a 15-30× gap, so the ASIC is a
**memory-hierarchy redesign, not a port**:

- **On-die (hot set only):** what every opcode touches — vstack (16 KB),
  vvars (4 KB), env/metadata tables (gen/valid/mark, ~10 KB), small caches.
- **External 4 MB SRAM (2M × 16) holds everything else** — framebuffers,
  code, vobj/varr slots, names, sprites. The saving grace: a sky130 core
  clocks ~25-50 MHz (20-40 ns cycles), so the ~10 ns SRAM is
  **one-cycle-class** — external stops being slow at this node.
- **16-bit bus tax:** one 64-bit Value64 = four beats (pipelined ~2 cycles
  at 25 MHz); pairing two SRAMs for a 32-bit bus halves it if the padring
  allows.
- **Template already built:** the 2026-08-23 single-draw-bank design
  (draw bank on fast RAM, front bank external behind a line-FIFO + CDC)
  is the first implemented piece of this hierarchy, not a T200 workaround.
- **Logic area is the second constraint:** ~170k logic LUTs ≈ 2-4 M gate
  equivalents ≈ tens of mm² at 130 nm. Every LUT the fit campaign removes
  is future die area removed; after T200 placement, a gate-count estimate
  against the real die budget is the next ASIC step.

The BASIC CPU's 64 KB on-chip budget does not apply verbatim, but its
*shape* — tiny on-die hot set + external main store — is now this chip's
shape too.

**Disk (µSD FAT32 / project `card.img`), not BRAM:** PYTHON, FPGA-SIM, and
BOARD all play this image. `NAME.HTML` is the user title (`LOAD` / `LIST`).
**V1.0:** compile when you **make the card** — the builder mints `.JSH` so
`RUN` is the same ProgramImage on every rung. **V1.5:** `COMPILE` on the
machine mints that sidecar; `RUN` is unchanged. See Vendored-titles.
Never hard-code addresses throughout the design. Never stuff sprite
megabytes into code BRAM (PNG → `.ARTX` → ASET SRAM).

---

# KEYBOARD / JOYSTICK / STORAGE / VIDEO

Paths for the primary board are owned by `docs/FPGA_BRINGUP.md`.

Contract:

- Keyboard → PHY → INPUT FIFO → Console / JS events
- Joystick/gamepad → GPIO reader → same INPUT FIFO
- Many sources may merge; one INPUT engine
- Storage Engine owns the physical device (ordinary files: `.JS`, `.HTML`, …)
- HDMI scanout reads the front framebuffer independently of JS timing where
  buffering allows; VBlank swap for tear-free animation

Do not assume Nexys A7-100T pinouts.

---

# PYTHON REFERENCE MODEL

Every subsystem exists first in Python.

The Python **bytecode functional model** (JMR VM + engines) is the behavioral
truth for the machine — **not** dukpy/Duktape/V8 executing HTML as a cheat.

Python exposes every internal state.

---

# PYTHON HARDWARE MODEL

The second Python model mirrors FPGA hardware.

Explicit memories.

Explicit stacks.

Explicit state machines.

Explicit clocks.

Explicit interfaces.

The Python Hardware Model and FPGA must produce identical results.

---

# FPGA MODULES

One module per subsystem (logical engines). A logical block may be implemented
as its own `.sv` file or folded into an existing engine when that keeps the
interface clear — document the fold in `docs/ARCHITECTURE.md`.

Do not create giant monolithic modules. Keep optional accelerators separable
so fit pressure can drop a module without breaking the architecture.

---

# FPGA RESOURCE STRATEGY

Target: **XC7A200T** on Nexys Video (larger than XC7A100T).

Architecture must comfortably fit. Soft utilization caps will be recorded in
`docs/SESSION_HANDOFF.md` / fit reports after the first real Vivado build —
do not invent LUT counts.

Share hardware. Reuse ALU, parsers, memory ports, and blitter datapaths.
Multi-cycle ops are acceptable.

---

# TESTING

Do not generate random programs as the primary strategy.

Prefer complete educational apps / demos and real Canvas games as permanent
regressions. Inventory and Complete/TBD checklist:
`docs/JMR_JS_COMPATIBILITY.md` **Agent surface checklist**.

Every accepted program becomes a permanent regression test.

**Read `traces/` first** when debugging runtime differences. Do not re-run
heavy demos to reproduce unless the trace is genuinely missing the answer.
Cursor rule: `.cursor/rules/use-existing-traces.mdc`.

---

# IMPLEMENTATION ORDER (V1 ladder)

1. Constitution + repo skeleton + Cursor rules
2. Python FM console + `console.log` glass
3. Lexer / expression subset + bytecode path in FM
4. Monitor commands (DIR/LOAD/LIST/EDIT/…) in FM
5. Canvas subset + framebuffer model in FM
6. Event / timer / rAF stub
7. Python Hardware Model parity
8. SystemVerilog engines + FPGA-SIM (HDMI + INPUT after glass exists)
9. Nexys Video constraints + Vivado `.bit` / `.bin`
10. Board smoke standalone (HDMI + keyboard + joystick)

Do not start Vivado before PYTHON + FPGA-SIM exist for user-visible behavior.
Phase notes: HDMI test pattern and INPUT PHY are board Phase 1 after FM glass
grows — see `docs/SESSION_HANDOFF.md`.

---

# AGENT IMPLEMENTATION RULES

Agents should never redesign the architecture.

Agents should:

Implement.

Refactor locally.

Improve code quality.

Add tests.

Document changes.

Agents should NOT:

Replace the architecture.

Merge independent engines.

Replace JS with a hidden CPU.

Replace microcode with another architecture.

Remove documentation.

Delete files.

Ship RTL-only glass.

---

# SUCCESS CRITERIA

The computer should feel like an early personal computer transported forward
to JavaScript — READY, LOAD, EDIT, RUN, ESC — not a SoC running a browser.

Internally it should be an entirely original computer.

The code should be understandable by students.

Every subsystem should be independently testable.

Same glass on PYTHON, FPGA-SIM, and board.

Standalone: HDMI out, USB keyboard, Pmod joystick, no PC required to play.

`INVADERS.HTML`, `PACMAN.HTML`, and `DONKEY.HTML` LOAD + RUN and are playable
on all three runtimes (see Vendored-titles mandate). No `?NH` anywhere.

The architecture should be elegant enough that someone reading the repository
understands how a complete computer works from keyboard/joystick input to
HDMI output.
