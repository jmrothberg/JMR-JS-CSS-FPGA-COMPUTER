# FPGA bring-up — Digilent Nexys Video (primary)

**Primary board:** Digilent **Nexys Video** — Xilinx/AMD Artix-7 **XC7A200T-1SBG484C**
(“T200” in lab shorthand).

**Working sibling (do not confuse):** `JMR-BASIC-FPGA-COMPUTER` on Digilent
**Nexys A7-100T** (“T100”) already has a **fully working** BASIC-native console
+ USB keyboard. Steal **method** (PYTHON → real FPGA-SIM → board; PIC24
USB→PS/2). Do **not** copy A7 pinouts, BASIC ISA, or VGA assumptions into this
tree. This product is **JS-native** + **HDMI 640×480** on Nexys Video.

**STOP:** Do **not** `make … bit` / flash until FPGA-SIM is perfect for the
feature under test (`check_runtime_parity.py` BATTERY PASS + relevant benches).
Flashing half-broken bits wastes hours.

**Second port (later):** Puzhi **PA-StarLite** (XC7A200T, 1 GB DDR3) — same engines,
different XDC/PHY only after Nexys Video glass works. Do **not** run two board
bring-ups in parallel until monitor + HDMI + INPUT are proven on Nexys Video.

SystemVerilog sources will live in `rtl/`. Simulation uses **Verilator**
(+ cocotb when tests land) under `sim/`. Constraints live under `constraints/`
(board-specific XDC when RTL starts).

---

## Teach-me: RTL → FPGA-SIM → Vivado → `.bit` / `.bin`

```
  You write / we ship          Host (Mac or Linux)         Linux + Vivado              Nexys Video
  ─────────────────            ───────────────────         ────────────────              ───────────
  rtl/*.sv  (RTL)    ──►   Verilator builds         ──►  Vivado synthesizes      ──►  FPGA configures
  SystemVerilog            sim server executable         & implements the chip       from a bitstream
                           GUI F9 = FPGA-SIM             writes .bit / .bin            I/O live
```

### What is RTL?

**RTL** = **Register-Transfer Level** — hardware as registers, wires, and
clocked logic. In this repo: SystemVerilog under `rtl/` (`*.sv`).

| Term | Meaning |
|---|---|
| **RTL** | Hardware at register-transfer level (`rtl/`) |
| **SystemVerilog** | Language of those `.sv` files |
| **Synthesis** | RTL → technology netlist for a specific FPGA family |
| **Implementation** | Place & route onto the real chip |
| **Bitstream** | Configuration image (`.bit` / `.bin`) |
| **FPGA-SIM** | Same RTL simulated via Verilator (not Vivado, not silicon) |

### What is Verilator?

Open-source HDL simulator/compiler: SystemVerilog → C++ model → host
executable. It is **not** an FPGA and **not** Vivado. It does **not** emit
`.bit` / `.bin`.

### What is AMD Vivado?

Vendor tool that turns FPGA RTL into a bitstream. **Linux-only** in this
project’s flow. Mac can run PYTHON + FPGA-SIM; bitstream builds happen on
Linux.

### What are `.bit` and `.bin`?

Two packaging formats of the **same** place-and-route result — not two
designs. Only Vivado (board flow) produces them; Verilator never does.

---

## Debug tiers: PYTHON → FPGA-SIM → BOARD

| Runtime | What it is | Where the “CPU” lives |
|---|---|---|
| **PYTHON** | Functional Model | `functional_model/` |
| **FPGA-SIM** | Same RTL as the board, simulated | Verilator → `sim/sim_build_synth/jmr_js_sim_server` (**default**). Host twin only with `JMR_SIM_HOST=1` — never a silent fallback. |
| **BOARD** | Real Nexys Video (standalone or tethered debug) | Silicon |

Glass discipline: [../.cursor/rules/python-first-parity.mdc](../.cursor/rules/python-first-parity.mdc).

Traces first: [../.cursor/rules/use-existing-traces.mdc](../.cursor/rules/use-existing-traces.mdc).

---

## Before Vivado (after FPGA-SIM works)

- User-visible behaviour already matches on PYTHON and FPGA-SIM.
- Prefer synthesizable constructs (constant-bound loops; avoid vendor
  non-converging `while` patterns).
- Do not invent fit numbers — read the generated fit report after the first
  real `make … bit`.

---

## Board identity (frozen)

| Item | Value |
|---|---|
| Digilent product | **Nexys Video** (primary) |
| FPGA part | **XC7A200T-1SBG484C** |
| External RAM | 512 MiB DDR3 (enough for V1 FB + heap; exact map later) |
| Video | **HDMI Source** (J8) — native **640×480 @ ~60 Hz**, ~25.175 MHz pixel clock |
| Framebuffer | 8 bpp indexed, **256-entry RGB888 palette**, double buffer (2× 307,200 bytes) |
| Keyboard | USB HOST (J15) → PIC24 → PS/2 into FPGA — **standalone typing / EDIT / ESC** |
| Play controls | **Pmod digital joystick / gamepad** (GPIO) on BOARD; **GUI mouse → same joy bitfield** on PYTHON + FPGA-SIM |
| Mouse | **Not V1 standalone USB**; host mouse is joystick emulator in sim only |
| Host link | PROG/UART — flash + **optional debug only** (not required to play) |
| Storage | µSD SPI master wired; FAT32 LOAD engine next |
| openFPGALoader `-b` id | **nexysVideo** |
| Bitstream output path | `build/nexys_video/jmr_nexys_video.bit` |
| Second port | **PA-StarLite** later — HDMI + 40-pin joystick; keyboard needs Pmod (no HID jack) |

### HDMI pipeline (lean)

**Do not hand-roll TMDS.** Use Digilent’s vendored `rgb2dvi` IP
(`third_party/digilent_rgb2dvi`, from [vivado-library](https://github.com/Digilent/vivado-library)
`ip/rgb2dvi`). Our scanout only produces RGB + sync:

```text
8-bit framebuffer pixel
        ↓
256-entry palette → 24-bit RGB
        ↓
rtl/video/jmr_hdmi_scanout.sv  (640×480 timing → vid_pData / HSync / VSync / DE)
        ↓
Digilent rgb2dvi  (PixelClk ~25.175 MHz → TMDS)
        ↓
HDMI Source (J8)  — pins in constraints/nexys_video.xdc (Digilent master XDC)
```

**First silicon (console):** `rtl/top_nexys_video.sv` is a PHY shell around
`jmr_js_core` — READY text on HDMI + USB-HID PS/2 keyboard + µSD SPI. Same
core as Verilator FPGA-SIM. `RUN` plays RECTDEMO on a mini canvas (Esc back).

```bash
source scripts/vivado_env.sh
make -C sim sim_server_synth          # FPGA-SIM RTL binary
make -C tools/board_flow bit
make -C tools/board_flow flash-qspi   # set JP1 to QSPI first
# HDMI: type HELP / DIR / RUN  (keyboard in USB HID port; USB cable optional after QSPI)
```

Volatile SRAM-only load (lost on unplug): `make -C tools/board_flow flash`.

openFPGALoader board id: **`nexysVideo`**. Bitstream: `build/nexys_video/jmr_nexys_video.bit`.

### QSPI flash gotcha — "it worked, then it restarted"

`flash-qspi` loads a small **flash-helper circuit into the FPGA** to program
the SPI flash chip. While it runs (and after it finishes) the FPGA is running
that helper, **not** our computer — the monitor goes blank and the **BUSY LED
blinks** (JTAG traffic). This is normal, nothing is broken.

**After `flash-qspi`: press the PROG button (JP4 = QSPI) or power-cycle.**
The FPGA then boots our design from flash and DONE lights.

To end up *live immediately* and *persistent*, flash in this order:
`flash-qspi` first, then `flash` (SRAM) last.

### PROG-cable tether — Runtime:BOARD mirror (T100 method)

Same USB cable as JTAG (J12 PROG). The bitstream streams:

- Text: `S<rowhex>:` + 64 chars per row (letterboxed in GUI like HDMI 640×480)
- Game: `P<rr>:` + 160 hex nibbles (mini-FB 160×120 ×4 → full GUI glass)
- Keys: `K` line on each USB Host `ps2_strobe` (flight-log proof)

Every host byte lands in the keyboard FIFO. **F9 → BOARD** mirrors HDMI.

Nexys Video's FT2232 **channel A** is the FT245 FIFO (DPTI), not a UART — RTL
`jmr_ft245_async` speaks that FIFO; Linux exposes it as the `/dev/ttyUSB*`
whose USB location ends in `.0`. Channel B (`.1`) is **JTAG** — never the
tether. `JMR_JS_SERIAL` overrides autodetect.
Gates: `make -C sim tb_uart_link tb_ft245`.

### Buttons & LEDs (frozen — do not reshuffle)

- **BTNC (center button, B22) = reset**, like the T100/BASIC board habit.
  CPU RESET (red, G4) also resets.
- **LD7** = `ps2_strobe` blink (USB Host J15 scancode only — not tether)
- **LD6** = raw `ps2_clk` (idle high)
- **LD5** = raw `ps2_data`
- **LD4** = `~sd_cd` (card present)
- **LD3** = MMCM locked, **LD2** = READY, **LD1** = game_mode, **LD0** = alive
- **PS/2 is RX-only** (Digilent / BASIC T100 method). No host `0xFF`/`0xF4`.
  Keyboard in **J15 USB Host**.
- **JP4 = FPGA boot source only** (JTAG / QSPI / USB-SD). It does **not**
  enable the keyboard. Do not move JP4 to “fix” typing.
- **BUSY LED blinking = host JTAG/flash traffic**, not a fault.

### Silicon honesty (RUN)

- `LOAD RECTDEMO.JS` + `RUN` → mini-FB rectangles (hardcoded engine)
- `LOAD INVADERS.JS` + `RUN` → **bytecode VM** (`jmr_js_vm` + `invaders_jsb.hex`)
- Other LOADs without bytecode → `?NB` (no bytecode)
- Esc exits game_mode (priority over busy)

### FPGA-SIM battery (before every flash)

```bash
make -C sim sim_server_synth
make -C sim tb_ps2_typing
python3 tools/make_sd_image.py create sim/card.img
python3 tools/check_runtime_parity.py   # must print BATTERY PASS
```

Do **not** flash the board until that battery is green **and** you are
intentionally proving silicon for a feature that already matches on FPGA-SIM.
Also check Vivado timing (WNS ≥ 0). A prior VM build mapped code RAM to
distributed LUT RAM and produced ~−90 ns WNS / dead tether — that is not a
“board mystery,” it is a bad bit.

### T100 vs T200 keyboard (same method, different board)

| | T100 BASIC (working) | T200 JS (this board) |
|---|---|---|
| Board | Nexys A7-100T | Nexys Video |
| USB Host | **J5** | **J15** |
| PIC24 | USB HID → PS/2 Set-2 | same Digilent idea |
| FPGA pins | F4 / B2 | **W17 / N13** (`constraints/nexys_video.xdc`) |
| Video | VGA | HDMI |

If Verilator `tb_ps2_typing` PASS and **LD7 never blinks**, debug **PIC24 /
J15 / keyboard / power-order** like the BASIC bring-up docs — do not rewrite
console RTL or move JP4. Prefer the **same wired keyboard** that works on T100.

### Keyboard checklist (if LD7 never blinks)

RTL path is proven by `tb_ps2_typing`. Then check hardware only:

- Keyboard in **J15 USB Host** (not UART / not PROG)
- Wired **boot-protocol** keyboard preferred; no hub / wireless dongle
- Plug in before power-on; DONE lit; JP4 = boot source only (not a keyboard fix)
- Tether `K` lines / LD7 = scancode proof
- Compare to working T100 BASIC with the same keyboard
- Watch **LD14 (BUSY)** after DONE: Digilent RM — rapid short blink = PIC24 got an HID report (independent of our RTL)

### Foolproof HID LED blinker (if JS `.bit` never blinks LD7)

This is **not** BASIC on T200. It is a tiny RX-only design: J15 PIC24 → PS/2 `W17`/`N13` → LEDs. No HDMI, no VM, no tether. Own Vivado project under `build/hid_led_blink/` so it cannot clobber the JS bit build.

One line (after the JS Vivado run is **idle**):

```bash
source scripts/vivado_env.sh && make -C tools/hid_led_blink bit flash
```

Keyboard in **J15** before power; DONE lit. Then:

| LED | Meaning |
|---|---|
| **LD0** blinking | FPGA fabric is alive |
| **LD6** on (idle) | `ps2_clk` pulled high — PIC24/bus idle |
| **LD5** on (idle) | `ps2_data` pulled high |
| **LD4** flickers (~170 ms) | PIC24 toggling clock right now (HID→PS/2 activity) |
| **LD3:1** counter changes | decoded bytes (one press+release = 3 bytes) |
| **LD7** toggles on a key | a scancode byte was received (toggle, not blink) |

If LD0 lives but LD6/LD5 stay off, or LD7/LD4 never move: **J15 / PIC24 / keyboard hardware**, not the JS console. If LD7 toggles here but the JS `.bit` does not: JS RTL/timing. Official Digilent UART demo (optional): [Nexys-Video-Keyboard](https://github.com/Digilent/Nexys-Video-Keyboard).

Known Digilent constraints (not a secret silicon workaround): FPGA must be programmed first (PIC24 stays in config mode until DONE); FPGA pull-ups required; **no hubs**; one wired keyboard; do **not** drive `ps2_clk` low (that inhibits the device — `jmr_ps2_host` TX was removed for this).

Traces: `traces/session_*.log` (PYTHON) and `session_*_FPGA-SIM.log`.
See [SESSION_HANDOFF.md](SESSION_HANDOFF.md) for current agent priorities.

No HDMI Sink, DisplayPort, higher modes, or audio-over-HDMI for V1.

### Standalone input (non-negotiable)

The machine must run **without a PC**: HDMI monitor + USB keyboard + Pmod
joystick. UART/JTAG are for programming and optional debug only.

| Role | Plug | Path |
|---|---|---|
| Typing / EDIT / ESC | USB keyboard → USB HOST | PIC24 → PS/2 → keyboard PHY → INPUT FIFO |
| Play (move/fire) | Digital joystick/gamepad → Pmod | GPIO reader → INPUT FIFO |
| Mouse | — | Out of V1 |

Many physical sources merge into **one INPUT FIFO** → INPUT engine → monitor /
JS events (pattern cite: BASIC sibling UART/`KEY` + PS/2 FIFO merge in
`JMR-BASIC-FPGA-COMPUTER/docs/FPGA_BRINGUP.md` — method only).

---

## Related

- [LINUX_WORKSTATION.md](LINUX_WORKSTATION.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [SESSION_HANDOFF.md](SESSION_HANDOFF.md)
