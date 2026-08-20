# JMR JS Computer

An original **standalone** FPGA → ASIC **NLISC** computer (Native Language
Instruction Set Computing — see below) whose **native machine language is
JavaScript** (HTML5/Canvas games; minimal CSS as needed). There
is no soft CPU, no browser-on-FPGA, and **no dukpy/Duktape as the machine**:
`LOAD "NAME.HTML"` → edit → **`RUN` always compiles** that HTML → in-memory
ProgramImage (code + ASET art) → bytecode VM + engines. Full-quality
graphics stream into the **external 4 MB SRAM asset bank** (IS61WV204816
contract; FPGA board bridges DDR3 behind the same simple port — no `NAME.DAT`
file). Chrome may open the same `.HTML` for authoring; PYTHON/FPGA-SIM/BOARD
must run the **JMR VM**. V1 does **not** ship a general CSS browser — games
draw on Canvas. BRAM is RAM; µSD is disk; external SRAM is the asset bank.

**Sibling already works:** `JMR-BASIC-FPGA-COMPUTER` on Nexys **A7-100T** (T100)
is a fully working NLISC-BASIC FPGA (VGA + USB keyboard + console). This repo
is the same *kind* of machine for **NLISC-JS + HDMI** on Nexys **Video** (T200 /
XC7A200T) — steal method, not BASIC ISA or A7 pins.

**Primary board:** Digilent **Nexys Video** (XC7A200T) — HDMI 640×480, USB
keyboard (J15), Pmod joystick. **PA-StarLite** is a later port.
Development order: **PYTHON bytecode → real FPGA-SIM (perfect) → board → ASIC**.
Do **not** flash until FPGA-SIM battery is green. Never fake F9 FPGA-SIM with a
host twin; never treat dukpy/Chrome as the machine. User-typed glass must match
across F9 runtimes (no RTL-only console commands).

**Status for agents:** [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md)
(PYTHON glass user-confirmed; FPGA-SIM not F9-ready; do not `make bit`
unless the user asks. J15 USB Host is dead — GUI/PROG tether).
Synth vs play-speed debt (JOIN intern scan, what to keep for Vivado):
[docs/SYNTH_SLOWDOWN_LEDGER.md](docs/SYNTH_SLOWDOWN_LEDGER.md).
History of RTL edits from the 70 GB Vivado hunt (not a current-bug list;
use when tracing what those edits most likely broke):
[docs/VIVADO_FLATTEN_HUNT.md](docs/VIVADO_FLATTEN_HUNT.md).
Tagged Q16 opcode unit is leftover (titles use exec64): plan to unhook
it is [docs/REMOVING_EXEC32.md](docs/REMOVING_EXEC32.md) — after glass,
not in parallel with parent FSM edits. After that unhook, LUTRAM→Port A
(not every array into BRAM):
[docs/FPGA_FIT.md](docs/FPGA_FIT.md#lutram-leftovers-not-the-70-gb-hang).

```
$ python3 run_jmr_js.py
JMR JS-NATIVE-CPU V0.0.1
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
#    Window size is locked at startup (status text must not grow the alleys).
#    Prefers .venv. HTML RUN = compile-on-RUN bytecode (not dukpy).
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

python3 tools/make_sd_image.py create card.img
# 6a. rebuild FAT32 card.img from storage/

sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image
# 6b. write card.img → physical µSD (lsblk; whole disk not partition)

source scripts/vivado_env.sh && make -C tools/board_flow bit
# 7. Vivado synthesis + place/route + .bit  (YOUR terminal, hours).
#    Repo root. Not `bit-fresh`. Not `make clean`. Synth 2 threads /
#    impl 8. Tracker: build/nexys_video/synth_rss.log
#    Do not close this terminal or an agent job — that SIGTERMs Vivado
#    (no .dcp until synth_1 is 100%). After WNS ≥ 0:
#      make -C tools/board_flow flash
#    Last flashed bit 2026-08-13 03:36 (WNS +0.139); tree has newer RTL.
```

Day-one: **1 → 2 → 3 → 4 → 5**. FPGA-SIM is **real RTL** after step 4 — do not
treat `host_sim_server.py` as FPGA-SIM unless you set `JMR_SIM_HOST=1` on purpose.
Do not jump to Vivado before PYTHON + FPGA-SIM agree on user-visible behaviour.
Gate: `python3 tools/check_runtime_parity.py` must print **BATTERY PASS**.
Step **7** is Vivado (hours, your terminal). Flash only after WNS ≥ 0 — never
a substitute for fixing FPGA-SIM.

**LOAD / paste:** `LOAD "PACMAN.HTML"` (or INVADERS / DONKEY / ASTEROID / AURORA / MRDO / JOYDEMO) then `RUN`.
New HTML titles: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).
Only HTML titles. **`RUN` = compile-on-RUN** (in-memory ProgramImage; line
numbers from the HTML). Fat graphics ride the ASET section into the
external SRAM asset bank (invisible plumbing; no `.DAT` file). Same-stem `.JS`
demos are not the product. Ctrl-V pastes into the prompt.


**[CONSTITUTION.md](CONSTITUTION.md) is the specification.** If the code and
the Constitution disagree, the code is wrong.

**Linux day-one:** [docs/LINUX_WORKSTATION.md](docs/LINUX_WORKSTATION.md)

**What is RTL / FPGA-SIM / Vivado / `.bit`?**  
[docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md#teach-me-rtl--fpga-sim--vivado--bit--bin)

**Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
(posters: [architecture V1](docs/jmr_js_architecture_v1.png) ·
[core zoom-in](docs/jmr_js_core_zoom_in.png) ·
[ASIC board Rev A](docs/jmr_js_asic_board_rev_a.png) — errata in ARCHITECTURE.md)

**Fit / LUTs / BRAM / slices:** [docs/FPGA_FIT.md](docs/FPGA_FIT.md) — measured
from `build/nexys_video/utilization_impl.rpt`. Do not invent counts.

**Implement / don’t checklist (HTML, JS, CSS, Canvas — Complete or TBD):**
[docs/JMR_JS_COMPATIBILITY.md](docs/JMR_JS_COMPATIBILITY.md#agent-surface-checklist-html--javascript--css--canvas).
Opcodes (34) + native ids 0–40 + READY verbs:
[bytecode ISA](docs/JMR_JS_COMPATIBILITY.md#bytecode-opcodes-34).

---

## NLISC (Native Language Instruction Set Computing)

RISC and CISC argue about the *shape* of the opcode. **NLISC** is a
different axis: **the language the human types is the instruction surface
of the chip.** There is no second machine underneath (no Z80 + BASIC ROM,
no RISC-V + V8). Bytecode is what fetch actually eats; engines do the work.
The BASIC sibling is **NLISC-BASIC**. This repo is **NLISC-JS**. Same
method; different ISA. Full ladder:
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
`drawImage` / rAF / `GET_PROP` are datapaths (extra clocks at ~30 MHz still
hit a 60 Hz frame). Caps are frozen and compile as SRAM; overflow is loud.
No OS, no JIT warmup, scanout from the on-chip front FB. It will **not**
beat a 1 GHz ARM + a browser on raw JS or run the whole web. It competes
with “Z80 + interpreter” and “soft CPU + QuickJS.”

**Naming trap:** 1990s “native” meant compiled machine code, not
interpreted. Here **native** means the language lives in the silicon
(bytecode is the ISA) — no interpreter sitting on a borrowed CPU.

---

## Method (steal from the BASIC sibling — not the product)

Same NLISC ladder if you later build a **language-native GPU** or **update
BASIC** (steal method, not tokens/pins). Python is the fast ruler (same
**results**, not the same wall-clock as the chip); register-transfer level
hardware must execute the same serialized program; lockstep before titles;
RUN compiles loaded source; user F9 before `.bit`. Ladder:
[CONSTITUTION.md](CONSTITUTION.md#nlisc-method-js-basic-or-a-later-native-gpu).

- Constitution first.
- PYTHON functional model → hardware model on **the bytes RTL gets** → FPGA-SIM → board `.bit`.
- FPGA-SIM RTL **is** the T200 chip: `.cursor/rules/never-fake-fpga-sim.mdc`
  + `one-heap-keep-gen.mdc`. Same RTL becomes the `.bin`. Unique-case
  **reads** of heap SRAMs use `*_rdata` after a wait beat from the first
  line — do not peek `mem[idx]` and flatten later.
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
| `hardware_model/` | Explicit clocks / FSMs / memories (later) |
| `runtime/` | PYTHON / FPGA-SIM / BOARD / ASIC-SIM backends |
| `rtl/` | SystemVerilog engines (+ `rtl/video/` HDMI scanout) |
| `third_party/digilent_rgb2dvi/` | Digilent HDMI TMDS IP (do not rewrite) |
| `sim/` | Verilator + cocotb |
| `constraints/` | Nexys Video XDC (StarLite later; not A7-100T) |
| `storage/` | Seeds: `NAME.HTML` titles (card builder copies this folder) |
| `docs/` | Architecture, bring-up, fit, handoff |
| `tools/` | compile, SD image, battery, `golden_frames.py` (Chrome vs PYTHON vs RTL) |
| `traces/` | Flight logs — read first when debugging. `traces/goldens/` = frame diffs |
| `.cursor/rules/` | Product rules for *this* machine |

---

## License / sibling

Educational FPGA computer project. Sibling method reference (read-only):
`JMR-BASIC-FPGA-COMPUTER` — steal the method, not the BASIC ISA.
