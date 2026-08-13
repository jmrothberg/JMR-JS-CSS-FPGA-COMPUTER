# Linux workstation — day-one cheat sheet

**Find this file:** `docs/LINUX_WORKSTATION.md`  
Board detail: [FPGA_BRINGUP.md](FPGA_BRINGUP.md)  
**Agent status / keyboard / STOP-FLASH:** [SESSION_HANDOFF.md](SESSION_HANDOFF.md)  
**Glossary (RTL, FPGA-SIM, Vivado, `.bit`/`.bin`):**  
[FPGA_BRINGUP.md — Teach-me](FPGA_BRINGUP.md#teach-me-rtl--fpga-sim--vivado--bit--bin)

x86 **Ubuntu/Debian** preferred. Needs a desktop session for the GUI.

**Sibling:** BASIC machine on Nexys A7-100T is already fully working elsewhere —
this workstation builds the **JS** machine on Nexys Video. Do not flash the
T200 board to debug gaps that FPGA-SIM has not passed.

**No cheats:** product = HTML/JS native CPU (FPGA → ASIC). dukpy/host twin are
not the machine. See `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`.

---

## Readiness (honest, 2026-08-13)

Live detail: [SESSION_HANDOFF.md](SESSION_HANDOFF.md).

| Layer | Status |
|---|---|
| Constitution + Cursor rules | Done (no-dukpy native CPU) |
| PYTHON FM / GUI F9 | Letterbox; titles = `*.HTML` **compile-on-RUN** (dukpy / stale `.JSH` = debt) |
| FPGA-SIM (real Verilator RTL) | Same `LOAD HTML` / `RUN` = compile current HTML; host twin forbidden |
| Host twin as “FPGA-SIM” | **Forbidden** unless `JMR_SIM_HOST=1` (debug only) |
| Battery `check_runtime_parity.py` | Must PASS (`.venv/bin/python`) before any flash |
| Board keyboard (J15) | **Dead hardware** — use GUI/PROG tether; do not thrash PS/2 RTL |
| Last SRAM flash | See SESSION_HANDOFF — tree may be ahead of flashed bit |

### Monitor verbs (PYTHON and F9 FPGA-SIM — same glass)

| Verb | Behaviour |
|---|---|
| `DIR` | Catalog |
| `LOAD "NAME.HTML"` | Product titles — quotes optional |
| `LIST` / `LIST -` | Numbered lines; pages with `-- MORE --` |
| `LIST 10-20` / `LIST n` | Range / single display line |
| `EDIT n` | Show line; next Enter replaces it |
| `CLS` | Clear glass |
| `RUN` | **Compile-on-RUN** → JMR bytecode VM (fresh `.JSH`). Not dukpy / not stale sidecar. |

### Play controls

- **Arrows + Space** (and Up/Down as the HTML binds). Mouse stick **off**.
- KEYBITS: Up=1 Down=2 Left=4 Right=8 Fire=16. BOARD: GUI → PROG `0xFE`+bits.
- One glass: letterbox text at READY; full FB while a game RUNs (feature).

Do not invent LUT counts — copy [FPGA_FIT.md](FPGA_FIT.md).
Flash only after battery PASS and timing WNS ≥ 0.

---

## 1. Clone / enter + Python env (no Vivado)

```bash
cd /home/jonathan/JMR-JS-CSS-FPGA-COMPUTER
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 run_jmr_js.py
python3 gui_jmr_js.py
```

`requirements.txt` is pip-only. On Linux, **tkinter** is apt `python3-tk`.

---

## 2. FPGA-SIM (required — real RTL)

```bash
make -C sim sim_server_synth
make -C sim tb_ps2_typing
python3 tools/make_sd_image.py create sim/card.img
.venv/bin/python tools/check_runtime_parity.py   # BATTERY PASS (bytecode path)
```

F9 in the GUI uses this binary. If missing → fail loud; do not fall back to
PYTHON and call it FPGA-SIM. Never use dukpy as “FPGA-SIM.”

---

## 3. Vivado → `.bit` (last; only when green)

```bash
source scripts/vivado_env.sh
make -C tools/board_flow bit
# Confirm timing summary WNS ≥ 0 before flash
make -C tools/board_flow flash          # SRAM smoke first
# make -C tools/board_flow flash-qspi   # only after SRAM smoke
```

Only after all three HTML titles are green on FPGA-SIM **and** you GUI-tested.
