# JMR JS Computer

An original **standalone** FPGA computer whose **native machine language is
JavaScript** (Canvas game computer). There is no soft CPU, no browser-on-FPGA
cheat, and no hidden general-purpose core: JS → bytecode → microcode + engines.
V1 does **not** ship a general CSS browser — games draw on Canvas.

**Sibling already works:** `JMR-BASIC-FPGA-COMPUTER` on Nexys **A7-100T** (T100)
is a fully working BASIC-native FPGA (VGA + USB keyboard + console). This repo
is the same *kind* of machine for **JS + HDMI** on Nexys **Video** (T200 /
XC7A200T) — steal method, not BASIC ISA or A7 pins.

**Primary board:** Digilent **Nexys Video** (XC7A200T) — HDMI 640×480, USB
keyboard (J15), Pmod joystick. **PA-StarLite** is a later port.
Development order: **PYTHON → real FPGA-SIM (perfect) → board**. Do **not**
flash until FPGA-SIM battery is green. Never fake F9 FPGA-SIM with a host twin.
User-typed glass must match across F9 runtimes (no RTL-only console commands).

**Status for agents:** [docs/SESSION_HANDOFF.md](docs/SESSION_HANDOFF.md)
(keyboard on board is the open silicon issue; keep sim green first).

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
# 3. GUI — one 640×480 glass (text+games); F9 runtimes; arrows+space play

make -C sim sim_server_synth
# 4. Verilator FPGA-SIM binary (REQUIRED for F9 FPGA-SIM; never fake with host twin)
#    Opt-in dukpy twin only: JMR_SIM_HOST=1

python3 tools/check_runtime_parity.py
# 5. PYTHON ↔ FPGA-SIM RTL glass smoke

python3 tools/make_sd_image.py create card.img
# 6a. rebuild FAT32 card.img from storage/

sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image
# 6b. write card.img → physical µSD (lsblk; whole disk not partition)

# 7. ONLY after BATTERY PASS + timing clean — do not flash to “debug” sim gaps:
# source scripts/vivado_env.sh && make -C tools/board_flow bit && make -C tools/board_flow flash
# JP4=boot source only; keyboard in J15 (same PIC24 USB→PS/2 idea as BASIC T100 J5).
# HID hardware isolation (J15→LEDs only; wait until JS Vivado is idle):
# source scripts/vivado_env.sh && make -C tools/hid_led_blink bit flash
```

Day-one: **1 → 2 → 3 → 4 → 5**. FPGA-SIM is **real RTL** after step 4 — do not
treat `host_sim_server.py` as FPGA-SIM unless you set `JMR_SIM_HOST=1` on purpose.
Do not jump to Vivado before PYTHON + FPGA-SIM agree on user-visible behaviour.
Gate: `python3 tools/check_runtime_parity.py` must print **BATTERY PASS**.
Board flash is step 7, last — never a substitute for fixing FPGA-SIM.

**LOAD / paste:** `LOAD INVADERS_FULL.HTML` or `LOAD 3` (DIR index). Quotes optional;
Ctrl-V pastes into the prompt (same idea as the BASIC GUI).


**[CONSTITUTION.md](CONSTITUTION.md) is the specification.** If the code and
the Constitution disagree, the code is wrong.

**Linux day-one:** [docs/LINUX_WORKSTATION.md](docs/LINUX_WORKSTATION.md)

**What is RTL / FPGA-SIM / Vivado / `.bit`?**  
[docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md#teach-me-rtl--fpga-sim--vivado--bit--bin)

**Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

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
| `storage/` | Seeds for card image / demos (`INVADERS_FULL.HTML`, …) |
| `docs/` | Architecture, bring-up, handoff |
| `traces/` | Flight logs — read first when debugging |
| `.cursor/rules/` | Product rules for *this* machine |

---

## License / sibling

Educational FPGA computer project. Sibling method reference (read-only):
`JMR-BASIC-FPGA-COMPUTER` — steal the method, not the BASIC ISA.
