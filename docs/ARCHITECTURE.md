# Architecture

This document walks the NLISC-JS game machine block by block and says where
each block lives in the Python Functional Model. Every block on the
(eventual) diagram should have exactly one module; every module corresponds to
a block. That correspondence is the point — SystemVerilog is a translation,
not a redesign.

**Constitution:** [../CONSTITUTION.md](../CONSTITUTION.md) wins on conflict.
**Board / HDMI / input freeze:** [FPGA_BRINGUP.md](FPGA_BRINGUP.md).

**One-page poster** (sibling style to the JMR BASIC Architecture 2.0 diagram):

![JMR JS Computer — Architecture V1 poster](jmr_js_architecture_v1.png)

### Architecture V1 poster errata (AI-rendered image; text noise)

The block diagram is correct: compile-on-RUN, three memory rooms, HDMI scanout
from the **on-chip** dual framebuffer, external SRAM = blitter-source only.
Known text errors baked into the render — trust this list, not the poster
fine print:

- SRAM port contract is `addr[20:0]`, `wdata[15:0]`, `rdata[15:0]`, **`we` /
  `req` / `ack`** at core clock — poster `rge` is a garbled **`req`**.
- 4 MB map: **`0x000000–0x0002FF`** title palette (256 × RGB888 = 768 bytes),
  **`0x000300+`** 8-bpp sprite banks, top reserved. Poster extra zeros
  (`0x00000000` / `0x0003000+`) are wrong.
- Engines: Event/Timer/**rAF** (`requestAnimationFrame`), not “IAF”.
- Missing compile path → fail loud (**`?NH`**), never fake output. Poster
  “(RUN)” in that warning is wrong.
- Blitter note: “**Pixels** never enter code BRAM.” Poster “Never never”
  is a double-word glitch. There is no `NAME.DAT` file.
- On-chip working set: **microcode ROM** and **FIFOs** are separate items
  (poster jammed them as “microcode ROM FIFOs”).
- FPGA HDMI PHY on this poster (Digilent `rgb2dvi` TMDS, Nexys Video J8) is
  the **board** path. ASIC HDMI is parallel RGB out of the chip through an
  external transmitter — see the ASIC board poster. Neither path scans out
  from asset SRAM.
- ASIC rung “~30 mm² die, custom padring, ~1 MB-class on-chip SRAM” is
  Constitution-frozen. **QFN-100** is a later Rev A package proposal and
  lives on the ASIC board poster, not this one.

**Core zoom-in poster** (sibling style to the JMR BASIC Processor Core
zoom-in diagram) — the JS processor core itself: program sequencer,
`exec64` dispatch (the poster still shows the retired `exec32` twin — see
the errata below), Value64 eval stack, object/heap, native call,
shared engines, compile-on-RUN, three memory rooms, I/O. Render
**2026-08-18** (replaces the draft that still had 8192/4096 heap, ring
recycle, `.JSH` on card, and `CALL_NATIVE`).

![JMR JS Processor Core — zoom-in poster](jmr_js_core_zoom_in.png)

### Core zoom-in poster errata (AI-rendered image; 2026-08-18)

The block diagram and capacities match silicon (`jmr_js_vm.sv` /
`jmr_js_vm_pkg.sv` / `jsb_format.py`): parent SRAM owns the heap; **one
decoder, `exec64`** (the poster's `exec32 | exec64` mux on `flags[3]` was
real when rendered — exec32 was deleted 2026-08-21 and a non-Value64 image
now faults code 9 instead of switching decoders); JSB1 + ASET;
`MAX_OBJ=1024×32`; arrays
`1536×32 + 128×128`; `ENV_DEPTH=512`; generation handles + mark/sweep;
compile-on-RUN never writes `.JSH`/`.JSB` to the card. Known leftover
shorthand baked into the render — trust this list, not the poster fine
print:

- Tag strip is a sample (`int` / `obj` / `arr` / `str` / `fn` / `undef` /
  `elem`). Value64 also has `null` / `bool` / `env`; numbers are IEEE-754,
  not a separate `int` tag.
- Native ID table is a sample of ~40; the ABI is ids **0–40** (includes
  `typeof`).
- `VARS` / `CONSTS` are sibling parent SRAMs, drawn inside the eval-stack
  box.
- `LOAD → EDIT → RUN` — EDIT is optional.
- `~30 mm²` in the on-chip BRAM box is the **whole ASIC die**, not a BRAM
  size.
- Opcode `0D CALL` (native id in arg0) is RTL `OP_CALL`; the FM name is
  `CALL_NATIVE`. Same instruction. 34 opcodes total — full table and native
  ids 0–40:
  [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md#bytecode-opcodes-34).

**ASIC board poster (Rev A proposal)** — QFN-100 chip + external 4 MB asset
SRAM + HDMI transmitter carrier board, sibling style to the JMR BASIC ASIC
board poster:

![JMR JS ASIC — Rev A board poster](jmr_js_asic_board_rev_a.png)

### ASIC board poster errata (AI-rendered image; text noise)

The block diagram, buses, and video path are correct (HDMI scans out from the
**on-chip** front framebuffer; U8 asset SRAM feeds the blitter only). Known
text errors baked into the render — trust this list, not the poster fine print:

- **Proposals, not frozen:** QFN-100 (12×12 mm), TFP410-class HDMI transmitter,
  12-bit DDR RGB video bus, and the power-domain values are Rev A proposals.
  The Constitution freezes only the die target (~30 mm², custom padring,
  ~1 MB-class on-chip SRAM) and the IS61WV204816 asset-SRAM port contract.
- U8 part number must read **ISSI IS61WV204816** (2M × 16, 4 MB).
- SYSTEM RULES §1: garbled bullet should read "Game **art lives** OFF-chip in
  the 4 MB SRAM asset bank (never in **code** RAM)."
- SYSTEM RULES §4: SRAM bullet should read "A[20:0] + DQ[15:0] +
  CE#/OE#/WE#/UB#/LB# (async SRAM bus)"; the microSD/UART/audio bullets are
  garbled — correct text: "microSD SPI (CS/SCK/MOSI/MISO), FAT32:
  NAME.HTML titles; ProgramImage is regenerated in memory", "Console UART via
  CH340/CP2102 micro-USB (debug/tether only)", "Audio PWM → amp → 3.5 mm
  jack (V1-later)".
- PIN SUMMARY table: title should read "(Indicative Budget)"; the
  "RRAM_CTRL" row is spurious; Audio (PWM) count is **2** (PWM_L, PWM_R);
  rows do not sum — authoritative budget: SRAM addr 21 + SRAM data 16 +
  SRAM ctrl 5 + RGB DDR 12 + video sync/clk 4 + PS/2 2 + joystick 6 +
  SPI 4 + UART 2 + audio 2 + clk/rst/test 3 + LEDs 3 + power/gnd 20 = 100.
- BOARD NOTES: "debug/therm" → "debug/**tether**"; "NAME.FMT tiles" →
  "NAME.HTML titles"; ".JSlf" → ".JSH".
- Pin numbers on the QFN drawing are illustrative placement only.

---

## The idea

A conventional computer executes assembly (or a soft CPU), and a runtime /
browser implements JavaScript:

```
CPU  ->  browser / VM  ->  JavaScript
```

This machine reverses that. JS source becomes compact bytecode; bytecode *is*
the machine code:

```
JavaScript  ->  bytecode  ->  processor (microcode + engines)
```

There is no hidden general-purpose core underneath. **No dukpy/V8/browser as
the machine.** This is **NLISC-JS**: JS bytecode is the ISA; HTML is the
title file. V1 is a **Canvas game computer** (HTML titles → JMR bytecode).
Family name: [../README.md](../README.md#nlisc-native-language-instruction-set-computing).

```
NAME.HTML  →  RUN always compiles  →  ephemeral ProgramImage
           →  code → code BRAM, ASET → external SRAM asset bank  →  VM
```

User types only `LOAD "NAME.HTML"` / `RUN`. Chrome may open the same file for
authoring; PYTHON / FPGA-SIM / BOARD / ASIC must run the **JMR VM**.
Not a general HTML/CSS browser in V1.

---

## High level view (V1)

```
USB keyboard ──► keyboard PHY ──┐
                                 ├──► INPUT FIFO → Console / JS events / ESC
Pmod joystick ─► GPIO reader ───┘
                              ↓
                         Lexer / Parser → bytecode
                              ↓
                    Program Sequencer + Dispatch
                              ↓
                         Microcode / JS core
                              ↓
        ┌──────────┬──────────┬──────────┬──────────┐
        │Expression│  Object  │  Canvas  │ Blitter  │
        │  / ALU   │  / Heap  │  Engine  │          │
        └──────────┴──────────┴──────────┴──────────┘
                              ↓
              Paint / Video (palette + HDMI 640×480)
                              ↓
          Framebuffers (V1: dual 640×480 BRAM)

Blitter ◄──► external SRAM asset bank (4 MB, simple SRAM port;
             FPGA board = DDR3 behind a bridge; ASIC = IS61WV204816)
```

Also: String, Event/Timer, Storage, Audio (later) — separate engines, shared
where reuse is honest. **No general CSS engine in V1.**

---

## Instruction flow (target)

| Step | Meaning | FM home (when present) |
|---|---|---|
| 1 | Fetch next bytecode / work unit | Program sequencer |
| 2 | Decode | Dispatch table |
| 3 | Load microcode entry | Microcode ROM |
| 4 | Execute micro-ops (drive engines) | Micro-sequencer |
| 5 | Complete statement / task | Sequencer outcome |

Stalls (e.g. waiting for input, blitter, or a timer) are pipeline stalls, not
host blocks. Compile/parse may take many cycles — that is intentional.

---

## What is deliberately not here

- **No hidden CPU.** Nothing evaluates JS by calling into V8 / QuickJS / a soft core.
- **No merged engines.** Expression, heap, Canvas, blitter, video stay separate.
- **No second JS heap in exec64.** One physical 1-D SRAM; do not skip generation
  to hide exec/parent dual-copy skew. FPGA-SIM is the standalone `.bin` path.
- **No BASIC token tables.** This is not a re-skinned BASIC machine.
- **No Nexys A7-100T assumptions.** Primary board is **Nexys Video** (XC7A200T);
  wiring owned by `FPGA_BRINGUP.md`. PA-StarLite is a later port.
- **No V1 general CSS / full browser.** Canvas + minimal HTML game container.

---

## BRAM / LUT policy

Prefer BRAM for palette, microcode, FIFOs, font, line buffers, bounded stacks,
**and the V1 working set.** Dual **640×480** FB lives in `jmr_mini_fb.sv`
BRAM. Also on-chip: code BRAM, JS heap. Game art lives in the **external
SRAM asset bank** (see below), never in code BRAM. µSD holds `NAME.HTML` +
user files only; the code + ASET ProgramImage is regenerated in memory on
every `RUN` and is not a persistent `.JSB` / `.JSH` sidecar. There is no
`NAME.DAT`. Do not fake a 64K map. Do not pack Donkey `data:image` sheets into
code BRAM or downscale them to “fit.”

**ASIC target (frozen 2026-08-13): ~30 mm² die ("double chip"), our own
custom padring, ~1 MB-class on-chip SRAM.** Use the BRAM the design needs
for speed; never shrink BRAM to chase a small die. Live FPGA chip totals:
[FPGA_FIT.md](FPGA_FIT.md).

---

## External SRAM asset bank

One **4 MByte SRAM, 2M × 16 (ISSI IS61WV204816)** behind a simple
synchronous port. Same port, three implementations; nothing above the port
ever changes:

| Rung | Implementation |
|---|---|
| FPGA-SIM | behavioral 4 MB model behind the identical port (RTL above is real) |
| FPGA board | Nexys Video **DDR3** behind a MIG-based bridge (first 4 MB used) |
| ASIC / final PCB | the real IS61WV204816; trivial timing wrapper |

**Port contract (`jmr_sram_port`, core clock):**

```
addr  [20:0]   16-bit word address (2M words = 4 MB)
wdata [15:0]   write data
rdata [15:0]   read data (valid with ack)
we             1 = write, 0 = read
req            request strobe (hold until ack)
ack            completion strobe (1+ cycles later; bridge may stall)
```

**4 MB map (V1):**

```
0x000000 – 0x0002FF   title palette (256 × RGB888 = 768 bytes)
0x000300 – top        sprite pixel banks (8-bpp indexed, 2-byte aligned)
top of bank           reserved (future FB / heap migration)
```

**V2.0 asset bank (planned — not implemented):** rebuild to **8 MB** (or
larger if a title needs it). Driver: `MK.HTML` ASET is **~4.63 MB** indexed
pixels today. Keep the **same simple port** (`we`/`req`/`ack`, 16-bit data);
widen `addr` for 8 MB+ words. **ASIC rule:** still **one external (or
on-die) SRAM chip** — no multi-chip fancy access / bank gymnastics. FPGA
board may use DDR3 behind the port (first 8 MB). Detail:
[JMR_JS_COMPATIBILITY.md § Version 1.0 vs 2.0](JMR_JS_COMPATIBILITY.md#version-10-vs-20).

**ProgramImage container (JSB encoding + ASET):**

- Header flags: bit0 = v2 trailer (existing), **bit1 = ASET present**. When
  bit1 is set, a `u32 aset_byte_off` (offset from file start) follows the
  12-byte header, before consts.
- Code part (header, consts, ops, v2 trailer) streams to **code BRAM** as
  today. The v2 trailer carries **SPRD** sprite descriptors
  (`n_spr:u16`, then per sprite `w:u16, h:u16, sram_off:u32`) — handles
  only, no pixels. Legacy SPR1 (pixels in trailer) remains only for tiny
  `.JS` demos.
- ASET part at `aset_byte_off`: magic `"ASET"` + `u32 payload_len` +
  payload = palette block (768 bytes) + sprite banks. The loader streams
  the payload to asset SRAM address 0 (palette also loads the palette
  BRAM). `sram_off` descriptors point into this payload.
- Missing/truncated ASET when SPRD expects one → **fail loud** (`?NH`-class
  error), never silent blank sprites.

## FM → RTL correspondence

As modules land, keep a table here: diagram block → `functional_model/…` →
`rtl/…`. Folds must be documented (same rule as the BASIC sibling method).

| Diagram block | Functional Model | RTL |
|---|---|---|
| Console / Machine | `functional_model/machine.py` | `rtl/engines/jmr_console_engine.sv` |
| INPUT / keyboard | FIFO + `ps2_decode` path | `jmr_keyboard_fifo` + `ps2_rx`/`ps2_decode` (board: J15 dead → PROG tether) |
| INPUT / play keys | GUI KEYBITS | `jmr_uart_link` `0xFE` → `joy_in` (SIM + board tether) |
| INPUT / joystick | `functional_model/input_engine.py` | FPGA-SIM: `jmr_js_core.joy_in` (GUI KEYBITS). Board: `rtl/phys/jmr_i2c_joy.sv` via `top_nexys_video`. **Not** `jmr_input_engine.sv` (stub) and **not** `tools/pmod_input_test/` (LED bit) |
| Canvas / FB | `functional_model/canvas_engine.py` | `jmr_mini_fb.sv` native **640×480** dual-buffer BRAM (SIM; next bit) |
| One-glass letterbox | `CanvasEngine.paint_console_letterbox` | `jmr_text_hdmi_scanout.sv` + dual-clock `jmr_video_vram` |
| Bytecode VM | `functional_model/bytecode.py` + `jsb_format.py` | `rtl/engines/jmr_js_vm.sv` (writable ProgramImage BRAM) |
| Storage | `functional_model/storage_engine.py` | `storage_engine.sv` + SD SPI + console load |

**Honest path:** product titles are `*.HTML`. **`RUN` always compiles** the
loaded HTML into one in-memory ProgramImage for the **JMR bytecode VM** on
PYTHON, FPGA-SIM, BOARD, ASIC. Full-quality graphics ride its ASET section
into the external SRAM asset bank (no `NAME.DAT`; EDIT+RUN regenerates
everything). Never persist or prefer a `.JSB` / `.JSH` sidecar. dukpy is a
**cheat / debt** if used as the game engine. Never call dukpy “FPGA-SIM.”
The user only types
`LOAD "NAME.HTML"` / `RUN`.
See [SESSION_HANDOFF.md](SESSION_HANDOFF.md) and
`.cursor/rules/no-dukpy-cheat-native-cpu.mdc`.

---

## Related

- [FPGA_BRINGUP.md](FPGA_BRINGUP.md)
- [FPGA_FIT.md](FPGA_FIT.md)
- [LINUX_WORKSTATION.md](LINUX_WORKSTATION.md)
- [SESSION_HANDOFF.md](SESSION_HANDOFF.md)
