# JMR JS COMPUTER

## Project Constitution v0.2

This document is the architectural specification for the JMR JS Computer
(JavaScript-native FPGA game computer).

If there is ever a conflict between this document and the implementation,
THIS DOCUMENT IS CORRECT.

The implementation must be changed to match the specification.

Never simplify the architecture without updating this document.

Never replace major architectural concepts because they appear "easier."

The goal is educational elegance, not minimum code.

---

# PROJECT GOAL

Build an original **standalone** FPGA computer whose native programming
environment is JavaScript, aimed at playing and editing HTML5/Canvas-style
2D games.

The user never programs a conventional ISA (no assembly, no hidden RISC).

JavaScript is parsed into compact **JMR-JS bytecode**; bytecode operations
dispatch FPGA execution engines (microcode + engines). This is NOT:

- a soft CPU running V8 / SpiderMonkey / QuickJS
- a browser-on-FPGA stack with a general-purpose core underneath
- Linux, Chrome/Firefox/WebKit, or a general-purpose HTML/CSS browser
- a port of the JMR BASIC computer with different keywords

It is a new architecture: **JavaScript (+ minimal game HTML container) is the
instruction surface.** Canvas drawing is hardware-accelerated.

## Vendored-titles mandate (success criteria, non-negotiable)

This is a **real HTML / JavaScript / (minimal) CSS native CPU** — FPGA first,
then ASIC. Same method as the BASIC sibling; **not** a browser or dukpy box.

The machine plays real HTML5/Canvas games. One title = one file:
`INVADERS.HTML`, `PACMAN.HTML`, `DONKEY.HTML`. Those **MUST LOAD + RUN with
the same glass on PYTHON → FPGA-SIM → BOARD** (then ASIC).

- **No dukpy cheat.** PYTHON runs the **JMR bytecode VM**. **`RUN` always
  compiles the loaded `.HTML`** (editor source of truth) into a **fresh**
  internal `.JSH` — never prefer a stale on-disk `.JSH`. Compile errors must
  report **line numbers from that HTML**. dukpy/Duktape/V8/QuickJS must not be
  the product execution path. Chrome may open the same `.HTML` for authoring
  only — that does not count as PYTHON/FPGA proof.
- **No host-twin FPGA-SIM.** F9 FPGA-SIM = Verilator RTL. `JMR_SIM_HOST=1`
  is explicit debug only.
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
  titles. Optional differently named demos (e.g. `RECTDEMO`) may keep bytecode
  smoke. `storage/games_*` = upstream archive only.

---

# FUNDAMENTAL PHILOSOPHY

Traditional computers: CPU → runtime / browser → JavaScript.

We reverse this:

JavaScript → bytecode → processor (engines + microcode).

Language is the ISA. Canvas / blitter / event-loop are first-class machine
engines, not library code on a hidden CPU.

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

---

# DEVELOPMENT ORDER

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
User titles: `LOAD "NAME.HTML"` / `RUN` only. **`RUN` = compile-on-RUN**
(fresh `.JSH` output; never stale sidecar). Cursor rules:
`python-first-parity.mdc`, `no-dukpy-cheat-native-cpu.mdc`,
`never-fake-fpga-sim.mdc`.

The BASIC sibling (`JMR-BASIC-FPGA-COMPUTER` on Nexys A7-100T) is a **working
reference for method and USB-HID→PS/2 bring-up**, not a pinout or ISA source.
---

# TARGET HARDWARE

**Primary board:** Digilent **Nexys Video** — Artix-7 **XC7A200T-1SBG484C**.

**Second port (later):** Puzhi **PA-StarLite** (XC7A200T) — same engines,
different pins/XDC only after Nexys Video works. Do not dual-bring-up day one.

Pinouts, clocks, video, input, storage, and fit budgets are owned by *this*
repo’s `docs/FPGA_BRINGUP.md` and `constraints/` — never copy Nexys A7-100T
numbers from the BASIC machine.

**Display (frozen):** HDMI Source, native **640×480 @ ~60 Hz**, 8 bpp indexed,
256-entry RGB888 palette, double-buffered. **V1 now:** dual FB in BRAM
(`jmr_mini_fb.sv`). External DDR3 remains the target for heap + full FB later.

**Standalone input (frozen):**

- USB HOST keyboard (typing / EDIT / hardware ESC)
- Pmod **digital joystick / gamepad** for play
- USB mouse **not** required for V1 (USB HOST is one device; no Digilent hub)

**This T200 unit:** J15 USB Host is hardware-dead. Type and play from the GUI
PROG tether until RMA. The freeze above is still the product jack. Live status:
`docs/SESSION_HANDOFF.md`.

**Primary development host:** Ubuntu / Debian Linux (day-one path:
`docs/LINUX_WORKSTATION.md` — GUI, Verilator, Vivado, flash).

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

Boot into a monitor READY prompt (JS-native glass), not a desktop or browser.

```
JMR JS READY
>
```

Monitor commands (DIR / LOAD / RUN / LIST / EDIT / SAVE / …) load and edit
ordinary `.JS` game sources. ESC hard-breaks a running game back to READY
without depending on the program.

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
Full tables live in `docs/` once the FM defines them. Freeze exact bytecode
encoding after compatibility inventory (`docs/JMR_JS_COMPATIBILITY.md` when
created).

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

.JS source
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

Documented map only (`docs/MEMORY_MAP.md` when created). Use external DDR3
aggressively. Typical regions:

Boot / microcode ROM (BRAM where useful)

Program / source / bytecode store

JS heap (objects / arrays / strings)

Images / sprites / assets

Front / back framebuffers

Audio samples

Runtime workspace / stacks

MMIO / status

Never hard-code addresses throughout the design. Do not impose a fake 64 KB
architecture.

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
regressions. Inventory target games in `docs/JMR_JS_COMPATIBILITY.md` before
freezing the V1 language/API set.

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
