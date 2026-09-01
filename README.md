# JMR JS Computer

An original **standalone** computer that starts on an **FPGA** (Field-Programmable
Gate Array — a chip you reconfigure from a bitstream file) and is aimed at an
**ASIC** (Application-Specific Integrated Circuit — a custom chip later). It is
an **NLISC** machine (Native Language Instruction Set Computing — the language
you type *is* the chip’s instruction surface). Here that language is
**JavaScript** in HTML5 Canvas games. There is no hidden Z80/RISC-V, no
browser-on-FPGA, and **no dukpy/Duktape/V8 as the machine**.

What you type:

```text
LOAD "NAME.HTML"
RUN
```

**V1.0 disk is `card.img`.** PYTHON, FPGA-SIM, and BOARD all `LOAD`/`RUN`
from that same FAT image (board = `card.img` burned to µSD). `storage/` is
the **seed** only — rebuild with `make_sd_image.py create card.img`. That
step **compiles** each HTML into a minted **`.JSH`** (ProgramImage:
bytecode + **ASET** art). `LOAD` still shows HTML; `RUN` feeds the **JMR
VM** from that `.JSH` (the chip does not compile). Full-quality graphics
stream into the **external 4 MB SRAM asset bank** (Static Random-Access
Memory; ISSI IS61WV204816 contract). On the FPGA board, **DDR3** (board
DRAM) sits *behind* that same simple SRAM port. There is no `NAME.DAT`
file. Chrome may open the same `.HTML` for authoring; **PYTHON / FPGA-SIM /
BOARD** must run the JMR VM. Version 1.0 does **not** ship a general CSS
browser — games draw on **Canvas**. **BRAM** (Block RAM, on-chip) is working
RAM; **µSD** (microSD card) is disk; external SRAM is the art bank.

**Sibling already works:** `JMR-BASIC-FPGA-COMPUTER` on Nexys **A7-100T**
(**T100**) is a working NLISC-BASIC FPGA (VGA + USB keyboard + console). This
repo is the same *kind* of machine for **NLISC-JS + HDMI** on Nexys **Video**
(**T200** / XC7A200T). Steal the *method*, not the BASIC instruction set or
A7 pinout.

**Primary board:** Digilent **Nexys Video** (XC7A200T) — HDMI 640×480, USB
keyboard jack **J15**, Pmod joystick. **PA-StarLite** is a later port.
Development order: **PYTHON bytecode → real FPGA-SIM (perfect) → board → ASIC**.
Do **not** flash the board until the FPGA-SIM battery is green.

**Status (2026-08-27):** banner **V1.0**. Five titles play on FPGA-SIM;
**DIR works on the board** (run 50). Clean bit: run 49b
(`build/bits/run49_DIR-self-heal.bit`). Scoreboard:
[docs/FPGA_FIT.md](docs/FPGA_FIT.md). Speed plan:
[docs/SYNTH_SLOWDOWN_LEDGER.md](docs/SYNTH_SLOWDOWN_LEDGER.md). J15 USB
Host is dead on this unit — type and play from the GUI **PROG tether**.
**V1.0:** compile when you make the card (`.JSH`). **V1.5** tries
standalone compile **and** popular JS V1 lacks. **V2.0** grows the ISA/ASET
(no named title).

**Where to go next**

| I want… | Open |
|---|---|
| Words / abbreviations used everywhere | [Words used](#words-used-in-this-project) (this page) |
| What the machine *is* (spec) | [CONSTITUTION.md](CONSTITUTION.md) |
| Blocks, posters, asset-bank port | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| How to write a game | [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) (walls + FAST rules) |
| What JS/Canvas is Complete vs later | [docs/JMR_JS_COMPATIBILITY.md](docs/JMR_JS_COMPATIBILITY.md) |
| Learn the 34 instructions | [docs/JS_COMMANDS.md](docs/JS_COMMANDS.md) |
| Board, Vivado, flash, HDMI | [docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md) |
| **Writing RTL well — area, speed, templates (read BEFORE new RTL or a new chip)** | [docs/RTL_DESIGN_PRINCIPLES.md](docs/RTL_DESIGN_PRINCIPLES.md) |
| **The timing wall — measured logic/route split, root cause, max clock, held fixes** | [docs/TIMING_WALL.md](docs/TIMING_WALL.md) |
| GUI / tooling bugs (host-side only — not the .bit) | [docs/GUI_TOOLING_BUGS.md](docs/GUI_TOOLING_BUGS.md) |
| Fit numbers, next `.bit`, RAM law | [docs/FPGA_FIT.md](docs/FPGA_FIT.md) |
| This week’s status + failed-fix table | [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) |
| If a game looks slow *on the real board* / 30 fps plan | [docs/SYNTH_SLOWDOWN_LEDGER.md](docs/SYNTH_SLOWDOWN_LEDGER.md) |
| Debug doctrine (recurring bug classes) | [docs/potential bugs.md](docs/potential%20bugs.md) |

```
$ python3 run_jmr_js.py
JMR JS-NATIVE-CPU V1.0
READY
> console.log("HELLO")
HELLO
READY
>
```

### Top commands (use these a lot)

```bash
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
# 1. host env (once)

python3 run_jmr_js.py
# 2. terminal glass — PYTHON functional model

python3 gui_jmr_js.py
# 3. GUI — one 640×480 glass (text+games); F9 runtimes; F10 Architecture Monitor
#    F10 monitor + Inspector + board telemetry: docs/ARCH_MONITOR.md
#    Window size is locked at startup (status text must not grow the alleys).
#    Prefers .venv. V1.0 HTML RUN = minted .JSH from card.img (not dukpy).
#    F9 BOARD: PC keyboard = tether (J15 dead). F10 hides the monitor (faster).

make -C sim sim_server_synth
# 4. FAST FPGA-SIM rebuild from repo root (same rtl/*.sv as the chip).
#    Incremental: only runs Verilator if rtl/ or sim/sim_main.cpp is newer
#    than sim/sim_build_synth/jmr_js_sim_server. If Make prints OK and skips
#    Verilator, the binary is already current.
#    Force without wiping obj_dir:
#      make -C sim sim_server_synth -B
#    Do not `make -C sim clean`. Then restart the GUI and F9 FPGA-SIM.
#    Never fake with host twin. Opt-in debug only: JMR_SIM_HOST=1

.venv/bin/python tools/check_runtime_parity.py
# 5. PYTHON ↔ FPGA-SIM RTL glass smoke (bytecode path; no dukpy cheat)

python3 tools/make_artx.py MYGAME      # PNGs → ARTX + ARTJS; wires Chrome __jmrSpr hook
python3 tools/make_artx.py /path/to/game.html  # copy HTML+ARTX+ARTJS into storage/; PNGs stay put
python3 tools/make_sd_image.py create card.img
python3 tools/make_sd_image.py create card.img -nojsh
# 6a. new art title, then card. You write HTML + MYGAME-0.png, MYGAME-1.png, …
#     and `img.src = "jmr:spr:N"` plus window.JMR_SPR listing those PNGs.
#     Do not write .ARTX / .ARTJS by hand (those two tools do). After a PNG
#     edit, re-run make_artx + card create (make_artx also writes ARTJS and
#     wires the Chrome __jmrSpr hook).
#     Card gets HTML + .ARTX (as .ART) + minted .JSH. PNG / ARTJS stay
#     on the host. V1.0 default COMPILES each HTML into NAME.JSH here
#     (the chip does not compile). PYTHON, FPGA-SIM, and BOARD all
#     LOAD/RUN this image. Edit storage/ → rebuild here before F9.
#     Default mints sound() (nid 42). Pass -soundoff to stub those
#     calls (old bits that lack the native). Pass -nojsh to leave
#     title .JSH off so FPGA COMPILE can be tested (compiler-chain
#     .JSH still minted). Chrome Web Audio / ARTJS are never minted.
#     Authoring: docs/GAME_DESIGN.md (Art).

sudo python3 tools/make_sd_image.py burn /dev/sdX
# 6b. make AND burn — rebuild card.img from storage/, then raw-write µSD
#     lsblk first; whole disk (sdb / mmcblk0), not a partition (sdb1)
#     Same -soundoff / -nojsh as create. --keep-image ignores them.

sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image
# 6c. burn only — write the existing card.img as-is (skip rebuild)

source scripts/vivado_env.sh && make -C tools/board_flow bit
# 7. NEXT bitstream (as of 2026-08-22): ordinary `bit`. The one required
#    bit-fresh (exec32 file deleted + incremental stitch had duplicated
#    the framebuffer) was DONE 2026-08-21 and the 08-21 23:50 run already
#    reused that project. The 08-22 Phase 3b hand-delete changed file
#    *contents*, not the file *list*, so it does NOT need another one.
#    Use bit-fresh (not `make clean`) only when the source file *list*,
#    MIG, or XDC changes -- never to recover a mid-run crash.
#    Synth 2 threads / impl 8. Tracker: build/nexys_video/synth_rss.log
#    Do not close this terminal or an agent job — that SIGTERMs Vivado
#    (no .dcp until synth_1 is 100%). Writes both
#    build/nexys_video/jmr_nexys_video.bit (JTAG) and .bin (QSPI).
#    After WNS ≥ 0 → step 8. Last flashed 2026-08-13 03:36 (WNS +0.139).

make -C tools/board_flow flash
# 8. put the new bitstream ON the Nexys Video (PROG USB J12 plugged in).
#    SRAM / JTAG — HDMI live in seconds, GONE when you unplug. Uses the
#    existing .bit. If Make starts Vivado, stop it — rtl/ is newer than
#    the file you already built; load that file instead:
#      openFPGALoader -b nexysVideo build/nexys_video/jmr_nexys_video.bit
#    Survives power-cycle (QSPI, minutes; JP4 = QSPI):
#      make -C tools/board_flow flash-qspi
#    or: openFPGALoader -b nexysVideo -f build/nexys_video/jmr_nexys_video.bin
#    After flash-qspi the monitor goes blank and BUSY blinks (flash-helper,
#    not a fault). Press PROG or power-cycle; DONE lights. Live AND
#    persistent: flash-qspi first, then flash last.
```

Day-one: **1 → 2 → 3 → 4 → 5**. FPGA-SIM is **real RTL** after step 4 — do not
treat `host_sim_server.py` as FPGA-SIM unless you set `JMR_SIM_HOST=1` on purpose.
Do not jump to Vivado before PYTHON + FPGA-SIM agree on user-visible behaviour.
Gate: `python3 tools/check_runtime_parity.py` must print **BATTERY PASS**.
Step **6b** is a new card (make + burn); **6c** burns an image you already
made. Step **7** is Vivado (hours, **your** terminal). Step **8** puts the
`.bit` / `.bin` on the board. Flash only after WNS ≥ 0 — never a substitute
for fixing FPGA-SIM. If that bit **misses** 100 MHz on the JS
core, the hedge is a 50 MHz `core_clk` with DDR3 still on MIG `ui_clk`
(100 MHz) — not a slower DRAM. Future plan:
[docs/FPGA_FIT.md — If timing fails](docs/FPGA_FIT.md#if-timing-fails-wns--0--slow-the-js-core-not-ddr3).

---

## Two copies of every critical “do not”

Six full restatements of the same law caused drift. **One** copy can be
missed. So each critical “do not” lives in **exactly two** places: an
always-on Cursor rule (agents) and one teaching/human page. Other documents
**point** at those two; they do not retell the whole essay.

| Critical “do not” | Copy 1 (agents) | Copy 2 (humans / teach) |
|---|---|---|
| FPGA-SIM **is** the chip. Legal on-chip RAM (**Port A**). Never `mem[i] <=` in the big VM state machine | `.cursor/rules/never-fake-fpga-sim.mdc` | [docs/FPGA_FIT.md](docs/FPGA_FIT.md) **NEVER** table |
| One JavaScript heap; keep **generation** checks | `.cursor/rules/one-heap-keep-gen.mdc` | [docs/potential bugs.md](docs/potential%20bugs.md) Recurring class 1 |
| No dukpy / V8 / browser / soft CPU as the machine; V1.0 `RUN` is minted `.JSH` from `card.img` | `.cursor/rules/no-dukpy-cheat-native-cpu.mdc` | [CONSTITUTION.md](CONSTITUTION.md) Vendored-titles mandate |
| PYTHON → FPGA-SIM → your F9 → board. Agent does not run Vivado | `.cursor/rules/python-first-parity.mdc` | [Method](#method-steal-from-the-basic-sibling--not-the-product) (this page) |
| Do not hardwire `INVADERS` / `PACMAN` / `DONKEY` into the chip | `.cursor/rules/no-game-hardwire.mdc` | [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) |
| Version 1.0 authoring walls; V1.5 console + popular JS; V2.0 is ISA/ASET growth (no title name) | `.cursor/rules/html-game-v1.mdc` | [docs/JMR_JS_COMPATIBILITY.md](docs/JMR_JS_COMPATIBILITY.md) § Version 1.0, 1.5, and 2.0 |
| Read `traces/` before re-running the GUI | `.cursor/rules/use-existing-traces.mdc` | [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) |
| Synth hygiene: 2 workers; when **not** to `bit-fresh`; incremental stitch | [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md) § Synthesis | [docs/FPGA_FIT.md](docs/FPGA_FIT.md) + [docs/OLD_RUNS.md](docs/OLD_RUNS.md) |

**Lesson books that are not a third copy of those laws** (unique history —
keep): [docs/VIVADO_FLATTEN_HUNT.md](docs/VIVADO_FLATTEN_HUNT.md) (what we
broke chasing 70 GB), [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md)
failed-fix table (specific glass mistakes), [docs/RTL_REORG.md](docs/RTL_REORG.md)
JUDGMENT (do not file-move; leftover files).

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
| **Vivado** | AMD/Xilinx FPGA tool | Turns RTL into a **bitstream** (`.bit` / `.bin`). Linux only. **You** run it, not the agent |
| **bitstream** / **`.bit`** / **`.bin`** | — | File that configures the FPGA. `.bit` for JTAG; `.bin` for flash |
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
| **JSH** | — | **V1.0:** ProgramImage minted when you **make the card**. PYTHON, FPGA-SIM, and BOARD all `RUN` this file from `card.img` (chip does not compile). Not copied from `storage/`. **V1.5 tries** compile-on-RUN on the machine |
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
| **Pmod** | Peripheral module | Digilent add-on jacks (joystick on **JB**, optional PS/2 keyboard on **JA**) |
| **T200** | — | Lab name for this Nexys Video (Artix-7 200T) |
| **T100** | — | Lab name for the BASIC sibling’s Nexys A7-100T |
| **V1.0 / V1.5 / V2.0** | product generations | **V1.0** = titles that play; **one disk** = `card.img` for PYTHON / FPGA-SIM / BOARD; compile = **when you make the card** (`.JSH`). **V1.5** tries standalone compile + type/paste/edit at READY **and** popular JS V1 lacks. **V2.0** = bigger ISA/ASET (`MAX_SPR`, 8 MB bank, `Object.keys`, `Math.round`, dotted `new`) — **not** a named title |
| **`?NH`** | no HTML / no minted `.JSH` | Loud miss: missing title path, **or** card-create compile failed so `LOAD` shows HTML and `RUN` refuses. Never “done” |
| **clock** | chip heartbeat | The FPGA steps once per clock. This board’s JS core is ≈ **100 million** clocks per second (100 MHz) |
| **frame** | one picture | One full 640×480 image. Games aim for **60 pictures per second** (about 16.7 milliseconds each) |
| **clocks per frame** | heartbeats to finish one picture | How many clock steps the JavaScript engine needs to draw the next picture. **You do not type this.** **FPGA-SIM is a slideshow** (~800k heartbeats per second of *your* time). The **board** is ~100 million/s (~125× faster), not slower. **30 pictures/s on the board** allows **3.33 million** heartbeats per picture. INVADERS was measured at **10.6 million** (~9 pictures/s on silicon until we cut work). Plan: [docs/SYNTH_SLOWDOWN_LEDGER.md](docs/SYNTH_SLOWDOWN_LEDGER.md) |
| **suite** | automated test set | `pytest` / battery scripts. Not the GUI |
| **xfail** | expected fail | A test we leave red on purpose (a known mismatch). **Not** “the game is broken in F9” |
| **harness** | unattended script | Runs a title without you at the keyboard (headless). Can die on attract-mode after minutes even when *you* can play fine |
| **attract** | demo loop | Title screen / AI demo while nobody is playing (PACMAN ghosts wandering) |

Live **capacity** numbers (objects, environments, code words, sprites) change
when we fit the chip. **One** source of truth:
[docs/FPGA_FIT.md](docs/FPGA_FIT.md) paper budget. Do not copy stale 1024/512
caps from older paragraphs.

**LOAD / paste:** `LOAD "PACMAN.HTML"` (or INVADERS / DONKEY / ASTEROID / AURORA / MRDO / MKPVP / MKBIG / MKBIGCPU / MKCPU / JOYDEMO / SNDDEMO / PACORIG / PACFAST / DNKFAST) then `RUN`. FAST copies keep the original look; measured clocks are in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) (PACFAST **2.8×** PACMAN, DNKFAST **1.65×** DONKEY on FPGA-SIM play `fclk`).
**V1.0** library titles must stay inside the authoring walls in
[docs/GAME_DESIGN.md](docs/GAME_DESIGN.md). On the machine, **V1.0 `LIST`
is view / learn** — no on-chip compiler, so `EDIT` cannot change `RUN`
(that still loads the minted `.JSH`). **V1.5 (planned)** tries to be
**standalone**: type / paste / edit numbered HTML at READY **and**
compile-on-RUN on the machine **and** popular JS V1 does not have
(`Array.shift`, `Math.sin`/`round`, `isFinite`, …). V1.0 compiles when you make the card;
PYTHON / FPGA-SIM / BOARD all `RUN` that `card.img`) —
[docs/JMR_JS_COMPATIBILITY.md § V1.5](docs/JMR_JS_COMPATIBILITY.md#v15--type-paste-compile-edit-html-at-ready-no-card-required).
**V2.0** is ISA/ASET growth, not a named title
([docs/JMR_JS_COMPATIBILITY.md § Version 1.0, 1.5, and 2.0](docs/JMR_JS_COMPATIBILITY.md#version-10-15-and-20)).
Titles are HTML. **V1.0:** compile when you **make the card** (`.JSH`);
PYTHON, FPGA-SIM, and BOARD all `RUN` that image from `card.img`.
Same-stem `.JS` demos are not the product.
Ctrl-V pastes into the prompt.

**[CONSTITUTION.md](CONSTITUTION.md) is the specification.** If the code and
the Constitution disagree, the code is wrong.

**Linux day-one** (GUI, Verilator, Vivado, flash): [docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md).
(The old `docs/LINUX_WORKSTATION.md` was folded into that file.)

---

## NLISC (Native Language Instruction Set Computing)

**RISC** (Reduced) and **CISC** (Complex) argue about the *shape* of the
opcode. **NLISC** is a different axis: **the language the human types is the
instruction surface of the chip.** There is no second machine underneath (no
Z80 + BASIC ROM, no RISC-V + V8). Bytecode is what fetch actually eats;
engines do the work. The BASIC sibling is **NLISC-BASIC**. This repo is
**NLISC-JS**. Same method; different ISA. Full ladder:
[CONSTITUTION.md](CONSTITUTION.md#nlisc-method-js-basic-or-a-later-native-gpu).

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
[CONSTITUTION.md](CONSTITUTION.md#nlisc-method-js-basic-or-a-later-native-gpu).

- Constitution first.
- PYTHON functional model → hardware model on **the bytes RTL gets** → FPGA-SIM → board `.bit`.
- FPGA-SIM RTL **is** the T200 chip (`.cursor/rules/never-fake-fpga-sim.mdc`).
- Uniform glass across F9 runtimes.
- Read `traces/` before repro spam.
- Surgical edits; do not delete files; one README.

This repo is **not** a merge of `JMR-BASIC-FPGA-COMPUTER`. Do not copy BASIC
tokens, microcode, or Nexys A7-100T pinouts here. Board freeze:
[docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md).

---

## Layout

| Path | Role |
|---|---|
| `functional_model/` | Python behavioural truth |
| `hardware_model/` | Explicit clocks / FSMs / memories |
| `runtime/` | PYTHON / FPGA-SIM / BOARD / ASIC-SIM backends |
| `rtl/` | SystemVerilog engines (+ `rtl/video/` HDMI scanout). Navigation: [docs/RTL_REORG.md](docs/RTL_REORG.md) |
| `third_party/digilent_rgb2dvi/` | Digilent HDMI TMDS IP (do not rewrite) |
| `sim/` | Verilator + cocotb |
| `constraints/` | Nexys Video XDC (StarLite later; not A7-100T) |
| `storage/` | Seed only: `NAME.HTML` titles. Rebuild `card.img` after edits |
| `card.img` | **V1.0 disk** for PYTHON / FPGA-SIM / BOARD. FAT HTML + minted `.JSH` |
| `docs/` | Architecture, bring-up, fit, handoff |
| `tools/` | compile, SD image, battery, `golden_frames.py`. `pmod_input_test/` + `hid_led_blink/` = **LED-only** board proofs — not FPGA-SIM ([RTL_REORG.md](docs/RTL_REORG.md#board-led-input-tests--never-fpga-sim)) |
| `traces/` | Flight logs — read first when debugging. `traces/goldens/` = frame diffs |
| `.cursor/rules/` | Product rules for *this* machine (copy 1 of the do-nots) |

---

## License / sibling

Educational FPGA computer project. Sibling method reference (read-only):
`JMR-BASIC-FPGA-COMPUTER` — steal the method, not the BASIC ISA.
