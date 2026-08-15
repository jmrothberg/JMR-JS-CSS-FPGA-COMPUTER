# JMR JS Computer

An original **standalone** FPGA → ASIC computer whose **native machine
language is JavaScript** (HTML5/Canvas games; minimal CSS as needed). There
is no soft CPU, no browser-on-FPGA, and **no dukpy/Duktape as the machine**:
`LOAD "NAME.HTML"` → edit → **`RUN` always compiles** that HTML → fresh
internal `.JSH` (code + ASET art) → bytecode VM + engines. Full-quality
graphics stream into the **external 4 MB SRAM asset bank** (IS61WV204816
contract; FPGA board bridges DDR3 behind the same simple port — no `NAME.DAT`
file). Never prefer a stale
`.JSH`. Chrome may open the same `.HTML` for authoring; PYTHON/FPGA-SIM/BOARD
must run the **JMR VM**. V1 does **not** ship a general CSS browser — games
draw on Canvas. BRAM is RAM; µSD is disk; external SRAM is the asset bank.

**Sibling already works:** `JMR-BASIC-FPGA-COMPUTER` on Nexys **A7-100T** (T100)
is a fully working BASIC-native FPGA (VGA + USB keyboard + console). This repo
is the same *kind* of machine for **JS + HDMI** on Nexys **Video** (T200 /
XC7A200T) — steal method, not BASIC ISA or A7 pins.

**Primary board:** Digilent **Nexys Video** (XC7A200T) — HDMI 640×480, USB
keyboard (J15), Pmod joystick. **PA-StarLite** is a later port.
Development order: **PYTHON bytecode → real FPGA-SIM (perfect) → board → ASIC**.
Do **not** flash until FPGA-SIM battery is green. Never fake F9 FPGA-SIM with a
host twin; never treat dukpy/Chrome as the machine. User-typed glass must match
across F9 runtimes (no RTL-only console commands).

**Status for agents:** [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md)
(J15 USB Host is dead on this T200 — GUI/PROG tether; FPGA-SIM is ahead of
the 03:36 flashed bit).

```
$ python3 run_jmr_js.py
JMR JS-NATIVE-CPU V0.0.1
READY
> console.log("HELLO")
HELLO
READY
>
```

### Top 6 commands (use these a lot)

```bash
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
# 1. host env (once)

python3 run_jmr_js.py
# 2. terminal glass — PYTHON functional model

python3 gui_jmr_js.py
# 3. GUI — one 640×480 glass (text+games); F9 runtimes; F10 Architecture Monitor
#    Window size is locked at startup (status text must not grow the alleys).
#    Prefers .venv. HTML RUN = compile-on-RUN bytecode (not dukpy / not stale .JSH).
#    F9 BOARD: PC keyboard = tether (J15 dead). F10 hides the monitor (faster).

make -C sim sim_server_synth
# 4. Verilator FPGA-SIM binary (REQUIRED for F9 FPGA-SIM; never fake with host twin)
#    Opt-in host twin ONLY for debug: JMR_SIM_HOST=1 (not product)

.venv/bin/python tools/check_runtime_parity.py
# 5. PYTHON ↔ FPGA-SIM RTL glass smoke (bytecode path; no dukpy cheat)

python3 tools/make_sd_image.py create card.img
# 6a. rebuild FAT32 card.img from storage/

sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image
# 6b. write card.img → physical µSD (lsblk; whole disk not partition)

# 7. ONLY after BATTERY PASS + timing WNS ≥ 0:
# source scripts/vivado_env.sh && make -C tools/board_flow bit && make -C tools/board_flow flash
# JP4=boot source only. J15 USB Host is dead on this board — play via GUI tether.
# Last flashed bit 2026-08-13 03:36 (WNS +0.139); tree has newer JSB/640 FB RTL.
```

Day-one: **1 → 2 → 3 → 4 → 5**. FPGA-SIM is **real RTL** after step 4 — do not
treat `host_sim_server.py` as FPGA-SIM unless you set `JMR_SIM_HOST=1` on purpose.
Do not jump to Vivado before PYTHON + FPGA-SIM agree on user-visible behaviour.
Gate: `python3 tools/check_runtime_parity.py` must print **BATTERY PASS**.
Board flash is step 7, last — never a substitute for fixing FPGA-SIM.

**LOAD / paste:** `LOAD "PACMAN.HTML"` (or INVADERS / DONKEY) then `RUN`.
Only HTML titles. **`RUN` = compile-on-RUN** (fresh internal `.JSH`; line
numbers from the HTML). Fat graphics ride the `.JSH` ASET section into the
external SRAM asset bank (invisible plumbing; no `.DAT` file). Never type
`.JSH` as a LOAD name. Same-stem `.JS`
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

**Session status:** [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md)

---

## Method (steal from the BASIC sibling — not the product)

- Constitution first.
- PYTHON functional model → FPGA-SIM → board `.bit`.
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
| `storage/` | Seeds: `NAME.HTML` titles (`.JSH` = compile output, code + ASET art) |
| `docs/` | Architecture, bring-up, fit, handoff |
| `tools/` | compile, SD image, battery, `golden_frames.py` (Chrome vs PYTHON vs RTL) |
| `traces/` | Flight logs — read first when debugging. `traces/goldens/` = frame diffs |
| `.cursor/rules/` | Product rules for *this* machine |

---

## License / sibling

Educational FPGA computer project. Sibling method reference (read-only):
`JMR-BASIC-FPGA-COMPUTER` — steal the method, not the BASIC ISA.
