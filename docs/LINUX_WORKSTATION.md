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

---

## Readiness (honest, 2026-08-12)

| Layer | Status |
|---|---|
| Constitution + Cursor rules | Done |
| PYTHON FM glass / GUI F9 | Working (letterbox console + demos) |
| FPGA-SIM (real Verilator RTL) | Working for console / LIST / RECTDEMO / INVADERS.JS / PS2 bench |
| Host twin as “FPGA-SIM” | **Forbidden** unless `JMR_SIM_HOST=1` |
| Battery `check_runtime_parity.py` | Must PASS before any flash |
| Board keyboard (J15) | **Open** — sim PASS; silicon typing not proven |
| Vivado bit / flash | **Do not** until sim-perfect for the feature; check WNS ≥ 0 |

Do not invent LUT counts. Do not start Vivado before PYTHON + FPGA-SIM agree.

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
python3 tools/check_runtime_parity.py   # BATTERY PASS
```

F9 in the GUI uses this binary. If missing → fail loud; do not fall back to
PYTHON and call it FPGA-SIM.

---

## 3. Vivado → `.bit` (last; only when green)

```bash
source scripts/vivado_env.sh
make -C tools/board_flow bit
# Confirm timing summary WNS ≥ 0 before flash
make -C tools/board_flow flash          # SRAM smoke first
# make -C tools/board_flow flash-qspi   # only after SRAM smoke
```

Gold synthesizability gate remains Vivado on Linux — not Mac Verilator.
Keyboard: J15 USB Host (PIC24→PS/2), same *idea* as BASIC T100 J5.
HID isolation (only if JS bit LD7 stays dark; wait for JS Vivado to finish):
`source scripts/vivado_env.sh && make -C tools/hid_led_blink bit flash`

---

## Related

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [SESSION_HANDOFF.md](SESSION_HANDOFF.md)
- [../CONSTITUTION.md](../CONSTITUTION.md)
- [../README.md](../README.md)
