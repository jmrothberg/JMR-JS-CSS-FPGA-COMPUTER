# Session handoff — next agent start here

Last updated: 2026-08-12 (FPGA-SIM glass: one prompt, LIST, RUN INVADERS — no .bin yet)

## Product goal (do not forget)

We already have a **fully working BASIC-native FPGA computer**:

- Repo: `/home/jonathan/JMR-BASIC-FPGA-COMPUTER`
- Board: Digilent **Nexys A7-100T** (Artix-7 **XC7A100T** — “T100”)
- Standalone: VGA + USB keyboard on **J5** + console + games — **keyboard works**

This repo is the **same product idea**, different language and graphics:

- Repo: `/home/jonathan/JMR-JS-CSS-FPGA-COMPUTER` (**this** tree)
- Board: Digilent **Nexys Video** (Artix-7 **XC7A200T** — “T200”)
- Native language: **JavaScript** (bytecode + engines), not BASIC tokens
- Glass: **HDMI 640×480** Canvas / mini-FB, not VGA BASIC text strip
- Steal **method** from BASIC (PYTHON → real FPGA-SIM → board). Steal **not**
  A7 pinouts, BASIC ISA, or BASIC LUT history.

**End state:** a fully functional JS-native FPGA computer — tethered **or**
untethered — same experience as BASIC on T100, but JS/CSS-Canvas on T200.

---

## HARD RULES for the next agent

1. **Never fake FPGA-SIM.** F9 FPGA-SIM = real Verilator RTL
   (`sim/sim_build_synth/jmr_js_sim_server`). Host twin only with
   `JMR_SIM_HOST=1`. Missing binary → fail loud. Rule:
   `.cursor/rules/never-fake-fpga-sim.mdc`.
2. **Do NOT rebuild / flash the board** until FPGA-SIM is perfect for the
   feature under test. Flashing broken or half-timed bits wastes hours.
   Prior agents burned time on SRAM flash while WNS was catastrophic (−90 ns)
   and while keyboard on silicon was still unproven.
3. **Order:** PYTHON → **FPGA-SIM perfect** → then (and only then) Vivado bit
   → SRAM smoke → QSPI. Constitution + `python-first-parity`.
4. **Keyboard next.** RTL PS/2 path already passes Verilator
   (`make -C sim tb_ps2_typing`). Board typing still dead → compare to
   **working T100 BASIC** path (below), fix T200 PIC24/HID/bring-up — do not
   thrash unrelated RTL or move JP4.

---

## T100 (BASIC, working) vs T200 (JS, this repo)

| | **T100 — BASIC** | **T200 — JS (this repo)** |
|---|---|---|
| Board | Nexys **A7-100T** | Nexys **Video** (200T) |
| Video | VGA | **HDMI** 640×480 |
| USB Host jack | **J5** | **J15** |
| PIC24 role | USB HID → PS/2 Set-2 to FPGA | **Same idea** (Digilent HID host) |
| FPGA PS/2 pins | `ps2_clk=F4`, `ps2_data=B2` | `ps2_clk=W17`, `ps2_data=N13` (XDC) |
| RTL chain | `ps2_rx` → `ps2_decode` → `keyboard_fifo` → console | Same shape (`jmr_keyboard_fifo`) |
| Proof on working board | Type BASIC at READY; LED/console live | **Not yet on silicon** — sim PASS only |
| Host glass | GUI + UART/KEY merge | GUI + FT245 tether (channel **A** / `.0`) |

**Implication:** T100 proves the **PIC24 USB→PS/2 method works**. T200 should
be the same method on different pins/jack. If `tb_ps2_typing` PASS and board
**LD7 never blinks**, fault is **J15 / PIC24 / keyboard hardware / power
order**, not “rewrite the whole console.” Read BASIC
`docs/FPGA_BRINGUP.md` (PROG vs USB HOST, wired boot keyboard, no hub) — method
only; do not copy A7 XDC into this repo.

### Keyboard checklist (board — after sim stays green)

- Keyboard in **J15 USB Host** (not PROG/UART)
- Plain **wired boot-protocol** HID keyboard; no hub / wireless
- Plugged in **before** power-on; DONE lit
- **JP4 = boot source only** (not a keyboard enable)
- LEDs: **LD7**=`ps2_strobe` blink, **LD6**=`ps2_clk`, **LD5**=`ps2_data`
- Tether `K` lines = scancode ground truth when tethered
- Compare behaviour / docs to working BASIC on T100 with the **same** keyboard
- If a timing-clean JS bit still never blinks LD7: `source scripts/vivado_env.sh && make -C tools/hid_led_blink bit flash` (J15→LED only; do not run while the JS Vivado build is alive)

---

## Where FPGA-SIM stands (honest)

Battery gate (must stay green; re-run after every RTL change):

```bash
make -C sim sim_server_synth
make -C sim tb_ps2_typing
python3 tools/make_sd_image.py create sim/card.img
python3 tools/check_runtime_parity.py   # expect BATTERY PASS
```

**Already proven on real RTL FPGA-SIM (not host twin):**

- One glass: 64×16 letterbox, origin (64,112), shared `paint_console_letterbox`
- True lowercase + JS punctuation font (`font8.py` → `font_rom.hex`)
- LIST braces + lowercase on RTL
- `FB?` exports mini-FB; RUN RECTDEMO pixels visible
- Bytecode VM `jmr_js_vm.sv` (BRAM single-port fetch — **required** for timing;
  distributed-RAM multi-port version destroyed WNS)
- RUN INVADERS.JS paints on sim (~5008 nonzero pixels); Esc exits
- PS/2 waveform bench types `help` → HELP reply
- **GUI glass (F9 FPGA-SIM):** one prompt (RTL `>` is not doubled in yellow);
  `LOAD "invaders"` + `LIST` + `RUN` shows 5008 pixels; `KEYBITS` reaches RTL.
  Host overlay no longer wipes the game. **No .bin/flash this pass.**

**Not done / broken / do not claim “shipped”:**

- **Board keyboard** — open; next agent’s primary silicon I/O task *after* sim
  stays green (no flash until you know what you are proving)
- **Arbitrary HTML Canvas games on RTL** — PYTHON/dukpy can run
  `INVADERS_FULL.HTML`; silicon/sim native path is **bytecode**
  (`INVADERS.JS` / `.JSB`), not dukpy. Growing the VM + compile path so
  FPGA-SIM runs real game JS (then board matches) is the product path —
  **no faking with host twin as “FPGA-SIM”**
- **Load arbitrary `.JSB` from µSD** — INVADERS still largely from
  `invaders_jsb.hex` in BRAM; card `.JSB` auto-compile exists in
  `make_sd_image` / `compile_js.py` but full card→VM path needs finish
- **Do not flash** until the feature under test is perfect on FPGA-SIM and
  timing is met (WNS ≥ 0). Last bad flash: silent tether after −90 ns WNS

---

## `(NO VM)` / `?NB`

- Old `(NO VM)` = no bytecode VM (only RECTDEMO engine)
- Now: `jmr_js_vm.sv`. Missing companion bytecode → `?NB`

## One glass (640×480)

HDMI truth: **64 cols × 16 rows**, 8×16 cells, origin **(64,112)**.
PYTHON / sim_backend / board_backend all use
`CanvasEngine.paint_console_letterbox`.

## LEDs (frozen)

LD7=`ps2_strobe`, LD6=`ps2_clk`, LD5=`ps2_data`, LD4=`~sd_cd`,
LD3=MMCM, LD2=READY, LD1=game_mode, LD0=alive.

## Next agent priority (recommended)

1. **Keep FPGA-SIM green** — re-run battery after any VM/keyboard/RTL edit.
2. **Keyboard:** diff T100 working bring-up vs T200; prove LD7 / `K` on board
   only after a **timing-clean** bit built for that purpose — not before sim
   keyboard benches still pass.
3. **HTML/game path on RTL:** expand bytecode + natives so FPGA-SIM plays
   real Canvas-style games without dukpy; then board parity tethered + standalone.
4. **Docs stay honest** — never mark board “done” from sim alone.

## Key files

| Area | Path |
|---|---|
| SIM server | `sim/sim_main.cpp`, `runtime/sim_backend.py` |
| Glass | `functional_model/canvas_engine.py`, `font8.py` |
| VM | `rtl/engines/jmr_js_vm.sv`, `functional_model/jsb_format.py` |
| Console | `rtl/engines/jmr_console_engine.sv` |
| PS/2 bench | `sim/tb_ps2_typing.cpp` |
| Battery | `tools/check_runtime_parity.py` |
| BASIC reference (read-only) | `/home/jonathan/JMR-BASIC-FPGA-COMPUTER` |
