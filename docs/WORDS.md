# Words, laws, and the folder map

This is the dictionary and the map. The commands you run are on [the README](../README.md).

## Two copies of every critical “do not”

Six full restatements of the same law caused drift. **One** copy can be
missed. So each critical “do not” lives in **exactly two** places: an
always-on Cursor rule (agents) and one teaching/human page. Other documents
**point** at those two; they do not retell the whole essay.
That pair is for laws that **break the chip or the synth** (illegal RAM,
dual heap, skip-a-rung). **Do not** two-copy how to write a title. FAST
draw/`jmr:spr`/dest-crop lives in [GAME_DESIGN.md](GAME_DESIGN.md)
once; `/640png` first-build is Agent_learning prompts.

| Critical “do not” | Copy 1 (agents) | Copy 2 (humans / teach) |
|---|---|---|
| FPGA-SIM **is** the chip. Legal on-chip RAM (**Port A**). Never `mem[i] <=` in the big VM state machine | `.cursor/rules/never-fake-fpga-sim.mdc` | [FPGA_FIT.md](FPGA_FIT.md) **NEVER** table |
| One JavaScript heap; keep **generation** checks | `.cursor/rules/one-heap-keep-gen.mdc` | [RTL_REORG.md](RTL_REORG.md) |
| No dukpy / V8 / browser / soft CPU as the machine; V1.0 `RUN` is minted `.JSH` from `card.img` | `.cursor/rules/no-dukpy-cheat-native-cpu.mdc` | [CONSTITUTION.md](../CONSTITUTION.md) Vendored-titles mandate |
| PYTHON → FPGA-SIM → your F9 → board. Agent does not run Vivado | `.cursor/rules/python-first-parity.mdc` | [Method](#method-steal-from-the-basic-sibling--not-the-product) (this page) |
| Do not hardwire `INVADERS` / `PACMAN` / `DONKEY` into the chip | `.cursor/rules/no-game-hardwire.mdc` | [GAME_DESIGN.md](GAME_DESIGN.md) |
| Version 1.0 authoring walls; V1.5 COMPILE live + leftover typed-READY / popular JS; V2.0 is ISA/ASET growth (no title name) | `.cursor/rules/html-game-v1.mdc` | [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) § Version 1.0, 1.5, and 2.0 |
| Read `traces/` before re-running the GUI | `.cursor/rules/use-existing-traces.mdc` | [SESSION_HANDOFF.md](SESSION_HANDOFF.md) |
| Synth hygiene: 2 workers; when **not** to `bit-fresh`; incremental stitch | [SESSION_HANDOFF.md](SESSION_HANDOFF.md) § Synthesis | [FPGA_FIT.md](FPGA_FIT.md) NEVER table |
| Poll-fire cooldown (hold-to-repeat, not edge-gate) | `.cursor/rules/poll-fire-needs-cooldown.mdc` | [GAME_DESIGN.md](GAME_DESIGN.md) Input / FAST |
| No splice after kill-calls | `.cursor/rules/no-splice-after-kill-calls.mdc` | [GAME_DESIGN.md](GAME_DESIGN.md) FAST |
| No maze flood on a tick | `.cursor/rules/no-maze-flood-on-tick.mdc` | [GAME_DESIGN.md](GAME_DESIGN.md) FAST |

**Lesson pages that are not a third copy of those laws:**
[SESSION_HANDOFF.md](SESSION_HANDOFF.md) is the session placeholder.
[RTL_REORG.md](RTL_REORG.md) is the current RTL map.
The August Vivado-hunt notes are in `to_delete/notes/`.

---

## Words used in this project

Spell these out once here. Other pages expand the first use, then use the
short form. If a page is opened alone, it should still expand the first
mention.

| Short | Spelled out | Meaning here |
|---|---|---|
| **FPGA** | Field-Programmable Gate Array | Reconfigurable chip on the Nexys Video board |
| **ASIC** | Application-Specific Integrated Circuit | Custom silicon later; same architecture, not a second product |
| **RTL** | Register-Transfer Level | Hardware as registers, wires, clocks. Our files: `rtl/*.sv` |
| **SystemVerilog** / **`.sv`** | — | Language of the RTL |
| **FPGA-SIM** | FPGA simulation | The **same** RTL, simulated with **Verilator** (not Vivado, not a Python fake) |
| **Verilator** | — | Open-source tool: SystemVerilog → C++ → a host executable |
| **Vivado** | AMD/Xilinx FPGA tool | Turns RTL into a **bitstream** (`.bit` / `.bin`). Linux build tool; Verilator does not produce bitstreams |
| **bitstream** / **`.bit`** / **`.bin`** | — | File that configures the FPGA. Use `.bit` for JTAG and this project’s QSPI flash path; `.bin` is a secondary archive |
| **synthesis** / **synth** | — | RTL → netlist for this FPGA family. First long Vivado step (`synth_1`) |
| **place / route** / **impl** | implementation | Fit the netlist onto the real chip |
| **DCP** | Design CheckPoint | Vivado save file. None exists until `synth_1` hits **100%** |
| **WNS** | Worst Negative Slack | Timing: ≥ 0 means the clock was met. Negative WNS is a bad bit |
| **MIG** | Memory Interface Generator | Vivado IP that talks to the board’s DDR3 DRAM |
| **DDR3** | Double Data Rate DRAM, generation 3 | Big off-chip memory on Nexys Video. We hide it behind a **simple SRAM port** |
| **SRAM** | Static Random-Access Memory | Simple memory. **On-chip** (BRAM) vs **external 4 MB asset bank** |
| **BRAM** | Block RAM | On-chip memory tiles (this chip has **365**). Hot path only: screens, code, live JavaScript heap |
| **LUT** | Look-Up Table | The FPGA’s basic logic cell (this chip has ~134,600) |
| **LUTRAM** | LUT used as RAM | Fine for tiny tables. Fatal if a big array is forced here because BRAM ran out |
| **Port A** | — | Legal BRAM shape: tiny write process, address in, data **next** clock. Copy `jmr_mini_fb.sv` |
| **FSM** | Finite State Machine | Clocked `case (state)` that steps the VM |
| **VM** | Virtual machine | Here: the **JavaScript bytecode** engine (`jmr_js_vm.sv`), not a browser |
| **ISA** | Instruction Set Architecture | The 34 numbered opcodes the chip fetches |
| **NLISC** | Native Language Instruction Set Computing | The human language *is* the ISA (JS here; BASIC on the sibling) |
| **bytecode** | — | Compact numbered instructions the compiler emits on `RUN` |
| **opcode** | — | One instruction number (1–34) |
| **native** | — | A built-in the compiler already knows (`Math.floor` → opcode 13 + an **id**) |
| **playSfx** | — | Title helper: packed `[freq, vol, frames, slide, ch, …]`. Chrome: `_chromePlay`. Card: `sound()` nid 42. Catalog: `SNDDEMO.HTML` |
| **sound()** | nid 42 | `sound(ch, freqHz, vol0_15, frames, slide)`. 4-voice PSG (ch 0–2 square, 3 noise). Do **not** write `function sound()`. Mint default-on; `-soundoff` stubs |
| **ProgramImage** | — | Compiled program in memory after `RUN` (code + ASET art). Not a file you type |
| **ASET** | asset section | Palette + sprite pixels inside the ProgramImage; streamed to the 4 MB SRAM bank |
| **ARTX** | art sidecar | Quantized ASET payload beside `NAME.HTML` (`NAME.ARTX`; card 8.3 = `NAME.ART`). Built from `NAME-N.png` by `make_artx.py`. Title source uses `jmr:spr:N`, never inline base64. |
| **ARTJS** | Chrome art | Same quantized sheets as `.ARTX`, as a `.js` file Chrome can load. Built by `make_artjs.py`. **Not** on the card. Open `storage/NAME.HTML` in Chrome to see it. |
| **JSB** | — | On-the-wire encoding of a ProgramImage (`JSB1` magic) |
| **JSH** | — | **V1.0:** ProgramImage minted when you **make the card**. PYTHON, FPGA-SIM, and BOARD all `RUN` this file from `card.img`. Not copied from `storage/`. **V1.5:** `COMPILE` on the machine mints the same sidecar; `RUN` is unchanged |
| **ARTSCAN / COMPILER / EDITOR** | machine programs | HTML in `storage/` plus minted `.JSH` on the card. **Not games.** `EDIT` / `COMPILE` chain-load them. `DIR` hides the stems. **Do not delete.** [GAME_DESIGN.md](GAME_DESIGN.md#machine-programs-in-storage--do-not-delete) |
| **HTML** | HyperText Markup Language | Disk format of a title: `NAME.HTML` |
| **JS** | JavaScript | The language / ISA. `NAME.JS` demos are **not** product twins of `NAME.HTML` |
| **CSS** | Cascading Style Sheets | Page layout. Version 1.0 has almost none — paint on Canvas |
| **Canvas** | HTML5 bitmap drawing | `fillRect` / `drawImage` / … — hardware paint, not CSS |
| **FB** | framebuffer | The 640×480 picture in memory. **Dual FB** = two banks (draw one, show the other) |
| **HDMI** | High-Definition Multimedia Interface | Video out on the Nexys Video (jack J8) |
| **PHY** | physical layer | Pins, HDMI, USB, SD — the board shell around the core |
| **glass** | — | What you see: READY prompt, the game, errors. Must match PYTHON / FPGA-SIM / BOARD |
| **F9** | — | GUI key: pick PYTHON, FPGA-SIM, or BOARD as the live runtime |
| **HOST twin** | — | Python pretending to be FPGA-SIM. Opt-in `JMR_SIM_HOST=1` only — never the default |
| **PYTHON** | — | The fast functional model (`functional_model/`). Same *results* as the chip, not the same wall-clock |
| **HM** | Hardware Model | Python that mirrors clocks / memories (`hardware_model/`) |
| **dukpy** | — | A host JavaScript engine. **Forbidden** as the product CPU |
| **exec64** | — | The only opcode decoder (Value64 numbers). File: `jmr_js_vm_exec64.sv` |
| **exec32** | — | Retired tagged-integer decoder. **Deleted.** Do not resurrect |
| **Value64** | — | How JS values are packed (NaN-box). Every ProgramImage must set this flag |
| **heap** | — | Object / array / environment tables the garbage collector walks |
| **GC** | Garbage Collection | Recycle dead JS objects. **Generation** on a handle must match or the object was recycled |
| **rAF** | `requestAnimationFrame` | Game loop callback once per displayed frame |
| **HUD** | heads-up display | Score / lives text the title draws on Canvas |
| **IIFE** | Immediately Invoked Function Expression | `(function(){…})()` — compiler/VM must not lose the call frame |
| **FAT / FAT32** | File Allocation Table | Filesystem on the µSD card |
| **OOM** | Out Of Memory | Host process killed (Vivado RSS tens of GB), not a JS heap overflow |
| **RSS** | Resident Set Size | How much RAM Vivado is actually using. Watch this, not the log spinner |
| **UG901** | Vivado Synthesis User Guide | AMD’s RAM / case / blocking-assignment rules we must match |
| **XDC** | constraints file | Pin and clock constraints (`constraints/nexys_video.xdc`) |
| **CDC** | Clock Domain Crossing | Moving a signal between two clocks (needs a proper synchronizer) |
| **Pmod** | Peripheral module | Digilent add-on jacks. **JA** PS/2 mouse, **JC** second PS/2 mouse, **JB** joystick. USB keyboard is **J15**, not a Pmod. |
| **T200** | — | Lab name for this Nexys Video (Artix-7 200T) |
| **T100** | — | Lab name for the BASIC sibling’s Nexys A7-100T |
| **V1.0 / V1.5 / V2.0** | product generations | **V1.0** = titles that play; **one disk** = `card.img`; compile = **when you make the card** (`.JSH`). **V1.5 compile is live:** `LOAD` → `EDIT` → **`COMPILE`** → `RUN`. Typed-READY + popular JS V1 lacks is leftover. **`Math.round` is live** (nid 54). **V2.0** = bigger ISA/ASET (`MAX_SPR`, 8 MB bank, `Object.keys`, dotted `new`) — **not** a named title |
| **`?NH`** | no HTML / no minted `.JSH` | Loud miss: missing title path, **or** card-create compile failed so `LOAD` shows HTML and `RUN` refuses. Never “done” |
| **clock** | chip heartbeat | The JavaScript VM steps at **33.333 MHz**. Fabric and DDR user logic run at **100 MHz**. Do not treat those as the same clock. |
| **frame** | one picture | One full 640×480 image. Games aim for **60 pictures per second** (about 16.7 milliseconds each) |
| **clocks per frame** | heartbeats to finish one picture | How many VM steps the JavaScript engine needs to draw the next picture. **You do not type this.** The VM clock is **33.333 MHz**, so 30 pictures/s allows about **1.11 million** steps per picture. **FPGA-SIM is a slideshow** (~800k heartbeats per second of *your* time). Older notes that used a 100 MHz VM clock are in `to_delete/notes/`. |
| **suite** | automated test set | `pytest` / battery scripts. Not the GUI |
| **xfail** | expected fail | A test we leave red on purpose (a known mismatch). **Not** “the game is broken in F9” |
| **harness** | unattended script | Runs a title without you at the keyboard (headless). Can die on attract-mode after minutes even when *you* can play fine |
| **attract** | demo loop | Title screen / AI demo while nobody is playing (PACMAN ghosts wandering) |

Live **capacity** numbers (objects, environments, code words, sprites) change
when we fit the chip. **One** source of truth:
[FPGA_FIT.md](FPGA_FIT.md) paper budget. Do not copy stale 1024/512
caps from older paragraphs.

**LOAD / paste:** `LOAD "PACMAN.HTML"` (or INVADERS / DONKEY / ASTEROID / AURORA / MRDO / MKPVP / MKBIG / MKBIGCPU / MKCPU / JOYDEMO / SNDDEMO / PACORIG / PACFAST / DNKFAST) then `RUN`. FAST copies keep the original look; measured clocks are in [GAME_DESIGN.md](GAME_DESIGN.md) (PACFAST **2.8×** PACMAN, DNKFAST **1.65×** DONKEY on FPGA-SIM play `fclk`).
**V1.0** library titles must stay inside the authoring walls in
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md)
(how-to: [GAME_DESIGN.md](GAME_DESIGN.md)). **V1.0 `LIST` is
view / learn.** **V1.5 compile is live:** `LOAD` → `EDIT` → **`COMPILE`**
→ `RUN`. Typed-at-READY numbered authoring of *new* programs, and popular
JS V1 does not have (`Array.shift`, `Math.sin`, `isFinite`, …),
are leftover —
[JMR_JS_COMPATIBILITY.md § V1.5](JMR_JS_COMPATIBILITY.md#v15--type-paste-compile-edit-html-at-ready-no-card-required).
**V2.0** is ISA/ASET growth, not a named title
([JMR_JS_COMPATIBILITY.md § Version 1.0, 1.5, and 2.0](JMR_JS_COMPATIBILITY.md#version-10-15-and-20)).
Titles are HTML. **V1.0:** compile when you **make the card** (`.JSH`);
PYTHON, FPGA-SIM, and BOARD all `RUN` that image from `card.img`.
Same-stem `.JS` demos are not the product.
Ctrl-V pastes into the prompt.

**[CONSTITUTION.md](../CONSTITUTION.md) is the specification.** If the code and
the Constitution disagree, the code is wrong.

**Linux day-one** (GUI, Verilator, Vivado, flash): [FPGA_BRINGUP.md](FPGA_BRINGUP.md).
(The old `docs/LINUX_WORKSTATION.md` was folded into that file.)

---

## NLISC (Native Language Instruction Set Computing)

**RISC** (Reduced) and **CISC** (Complex) argue about the *shape* of the
opcode. **NLISC** is a different axis: **the language the human types is the
instruction surface of the chip.** There is no second machine underneath (no
Z80 + BASIC ROM, no RISC-V + V8). Bytecode is what fetch actually eats;
engines do the work. The BASIC sibling is **NLISC-BASIC**. This repo is
**NLISC-JS**. Same method; different ISA. Full ladder:
[CONSTITUTION.md](../CONSTITUTION.md#nlisc-method-js-basic-or-a-later-native-gpu).

**JS, not HTML, is the ISA.** HTML is the *disk format and editor surface*:
one title = `NAME.HTML`, line numbers from that file, Canvas in a minimal
container. V1 is not a CSS browser. The user types `LOAD "PACMAN.HTML"`;
the processor is still NLISC-JS. Do not call it an “HTML CPU.”
“HTML5 Canvas computer” is fine on the box.

**Why it exists (TRS-80 tax).** Level II BASIC still needed an interpreter
*and* a copy of a processor. Collapse those into one and the hidden CPU
goes away. That is the product: READY → LOAD → RUN, like the TRS-80, with
Canvas engines instead of a borrowed Z80.

**ASIC advantage — for this class of machine, not versus Chrome.** One
machine, not two: die goes to heap SRAM, dual FB, blitter, and the 4 MB
asset port, not a general CPU plus a runtime in DRAM. `fillRect` /
`drawImage` / rAF / `GET_PROP` are datapaths (extra clocks at core ≈100 MHz
MIG `ui_clk` still hit a 60 Hz frame). Caps are frozen and compile as SRAM;
overflow is loud. No OS, no JIT warmup, scanout from the on-chip front FB.
It will **not** beat a 1 GHz ARM + a browser on raw JS or run the whole web.
It competes with “Z80 + interpreter” and “soft CPU + QuickJS.”

**Naming trap:** 1990s “native” meant compiled machine code, not
interpreted. Here **native** means the language lives in the silicon
(bytecode is the ISA) — no interpreter sitting on a borrowed CPU.

---

## Method (steal from the BASIC sibling — not the product)

This is **copy 2** of the PYTHON → FPGA-SIM → board law (copy 1 is
`.cursor/rules/python-first-parity.mdc`). Same NLISC ladder if you later
build a **language-native GPU** or **update BASIC** (steal method, not
tokens/pins). Python is the fast ruler (same **results**, not the same
wall-clock as the chip). Register-transfer level hardware must execute the
same serialized program. Lockstep before titles. **V1.0:** PYTHON,
FPGA-SIM, and BOARD `LOAD`/`RUN` the same `card.img` (minted `.JSH` on
`RUN`). User F9 before `.bit`. Spec write-up:
[CONSTITUTION.md](../CONSTITUTION.md#nlisc-method-js-basic-or-a-later-native-gpu).

- Constitution first.
- PYTHON functional model → hardware model on **the bytes RTL gets** → FPGA-SIM → board `.bit`.
- FPGA-SIM RTL **is** the T200 chip (`.cursor/rules/never-fake-fpga-sim.mdc`).
- Uniform glass across F9 runtimes. Console text is the RTL reply line.
  Python does not add a longer paragraph. `HELP` is one line. The long
  instructions are `HELP.MD` on the card. A JS result that only Python
  gets is still a bug in RTL.
- Read `traces/` before repro spam.
- Surgical edits; do not delete files; one README.

This repo is **not** a merge of `JMR-BASIC-FPGA-COMPUTER`. Do not copy BASIC
tokens, microcode, or Nexys A7-100T pinouts here. Board freeze:
[FPGA_BRINGUP.md](FPGA_BRINGUP.md).

---

## Layout

| Path | Role |
|---|---|
| `functional_model/` | Python behavioural truth |
| `hardware_model/` | Explicit clocks / FSMs / memories |
| `runtime/` | PYTHON / FPGA-SIM / BOARD / ASIC-SIM backends |
| `rtl/` | SystemVerilog engines (+ `rtl/video/` HDMI scanout). Navigation: [RTL_REORG.md](RTL_REORG.md) |
| `third_party/digilent_rgb2dvi/` | Digilent HDMI TMDS IP (do not rewrite) |
| `sim/` | Verilator + cocotb |
| `constraints/` | Nexys Video XDC (StarLite later; not A7-100T) |
| `storage/` | Seed only: `NAME.HTML` titles. Rebuild `card.img` after edits |
| `card.img` | **V1.0 disk** for PYTHON / FPGA-SIM / BOARD. FAT HTML + minted `.JSH` |
| `docs/` | Architecture, bring-up, fit, handoff |
| `tools/` | compile, SD image, checks. LED and mouse probes are not FPGA-SIM ([RTL_REORG.md](RTL_REORG.md#probe-bits)) |
| `traces/` | Flight logs — read first when debugging. `traces/goldens/` = frame diffs |
| `.cursor/rules/` | Product rules for *this* machine (copy 1 of the do-nots) |

---

## License / sibling

Educational FPGA computer project. Sibling method reference (read-only):
`JMR-BASIC-FPGA-COMPUTER` — steal the method, not the BASIC ISA.
