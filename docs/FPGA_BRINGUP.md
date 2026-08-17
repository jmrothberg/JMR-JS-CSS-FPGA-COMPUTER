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

SystemVerilog lives in `rtl/`. Simulation uses **Verilator** under `sim/`.
Constraints: `constraints/nexys_video.xdc`.

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

**Trap:** Verilator will happily simulate a 2-D `logic` heap you compare
with `for (k)` inside `always_ff`. That loop **unrolls** into a combinational
mux. Real FPGA block RAM and ASIC SRAM are: address in, write enable, **data
out next clock**, 1–2 ports. FPGA-SIM that only works because of combo
arrays is **not** board-ready (Vivado `Synth 8-4556` / LUT explosion). Write
memories as SRAM from the first RTL line — same files as the `.bin`. Rule:
[FPGA_FIT.md](FPGA_FIT.md), Constitution § language-native method step 7.

### What is AMD Vivado?

Vendor tool that turns FPGA RTL into a bitstream. **Linux-only** in this
project’s flow. Mac can run PYTHON + FPGA-SIM; bitstream builds happen on
Linux.

### What are `.bit` and `.bin`?

Two packaging formats of the **same** place-and-route result — not two
designs. Only Vivado (board flow) produces them; Verilator never does.

---

## Debug tiers: PYTHON → FPGA-SIM → BOARD → ASIC

| Runtime | What it is | Where the “CPU” lives |
|---|---|---|
| **PYTHON** | **JMR bytecode VM** — **compile-on-RUN** | `functional_model/` (in-memory ProgramImage, code + ASET art) |
| **FPGA-SIM** | Same RTL as the board, simulated | Verilator → `sim/sim_build_synth/jmr_js_sim_server` (**default**). Host twin only with `JMR_SIM_HOST=1` — never a silent fallback. |
| **BOARD** | Real Nexys Video (standalone or tethered debug) | Silicon |
| **ASIC** | Same ISA after FPGA honesty | — |

Titles: `LOAD "NAME.HTML"` / `RUN` only. Never call Chrome or dukpy a rung.
Fat graphics ride the ProgramImage ASET section into the external SRAM asset bank
(no `NAME.DAT` file).

Glass: [../.cursor/rules/python-first-parity.mdc](../.cursor/rules/python-first-parity.mdc),
[../.cursor/rules/no-dukpy-cheat-native-cpu.mdc](../.cursor/rules/no-dukpy-cheat-native-cpu.mdc).

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
| External RAM | 512 MiB DDR3 → bridged as the **4 MB SRAM asset bank** (2M × 16 IS61WV204816 contract; simple SRAM port; ASIC uses the real chip). See `docs/ARCHITECTURE.md` |
| Video | **HDMI Source** (J8) — native **640×480 @ ~60 Hz**, ~25.175 MHz pixel clock |
| Framebuffer | 8 bpp indexed, **256-entry RGB888 palette**. FPGA-SIM / next bit: dual **640×480** BRAM. Last flash (03:36): 160×120 scaled |
| Keyboard | USB HOST (J15) → PIC24 → PS/2. **Classic boot-protocol keyboard PASS 2026-08-15.** Some modern HID keyboards light LD14 but never clock PS/2. Pmod JA is the fallback. |
| Play controls | GUI arrows+Space → KEYBITS (BOARD: PROG `0xFE`+bits). Mouse stick **off**. Pmod joy later |
| Mouse | **Not V1 standalone USB** |
| Host link | PROG FT245 (ch A / `.0`) — flash + tether glass + play keys |
| Storage | µSD SPI + FAT32: `NAME.HTML` (LOAD). Compile-on-RUN stays in memory. |
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
rtl/video/jmr_text_hdmi_scanout.sv  (640×480 timing → vid_pData / HSync / VSync / DE)
        ↓
Digilent rgb2dvi  (PixelClk ~25.175 MHz → TMDS)
        ↓
HDMI Source (J8)  — pins in constraints/nexys_video.xdc (Digilent master XDC)
```

**First silicon (console):** `rtl/top_nexys_video.sv` is a PHY shell around
`jmr_js_core` — READY text on HDMI + µSD SPI. Same core as Verilator FPGA-SIM.
J15 works with a **classic USB keyboard**. Type from J15 or Pmod JA; play from **F9 BOARD** GUI tether or the JB stick.
Do **not** raise HDMI resolution or switch this T200 to VGA for torn glyphs
(that was VRAM CDC; dual-clock scan port).

```bash
source scripts/vivado_env.sh
make -C sim sim_server_synth          # FPGA-SIM RTL binary (obj_dir incremental)
make -C tools/board_flow bit          # publish only if WNS ≥ 0
make -C tools/board_flow flash        # SRAM first
# HDMI: READY letterbox; play via GUI arrows+Space
```

**First T200 `.bin` vs later:** the first `make -C tools/board_flow bit` creates
the Vivado project, generates DDR3 MIG, and fully synthesizes `jmr_js_vm`
(often **1–3 hours**; log may go quiet while CPU stays busy). Later `bit`
**reuses** `build/nexys_video/vivado` (skip MIG generate, incremental DCP).
Use `make -C tools/board_flow bit-fresh` only if MIG / XDC / source *list*
changed. Do not `make -C tools/board_flow clean` between RTL tweaks — that
forces another first-build. `JMR_VIVADO_JOBS` (default 2) — this design is
RAM-heavy.

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

Every host byte lands in the keyboard FIFO. **F9 → BOARD** mirrors HDMI and
sends play KEYBITS (`0xFE` + 6-bit field) because J15 cannot.

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
  Product jack is **J15 USB Host** (classic keyboard PASS 2026-08-15; some modern HID keyboards do not emit PS/2).
- **JP4 = FPGA boot source only** (JTAG / QSPI / USB-SD). It does **not**
  enable the keyboard. Do not move JP4 to “fix” typing.
- **BUSY LED blinking = host JTAG/flash traffic**, not a fault.

### Silicon honesty (RUN)

- User product path: `LOAD "*.HTML"` + `RUN` → **compile-on-RUN** →
  ProgramImage into the JMR VM. Full-quality graphics stream from the
  ASET section into the external SRAM asset bank (never pack Donkey
  art into code BRAM; no `NAME.DAT`). Never dukpy on silicon.
- `?NH` = HTML path debt (temporary). Missing compile path → fail loud
  (not Invaders hex lie).
- Esc exits game_mode

Last SRAM image: **2026-08-13 03:36**, WNS **+0.139 ns** (HDMI VRAM CDC +
tether KEYBITS). See [SESSION_HANDOFF.md](SESSION_HANDOFF.md).
Rule: `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`.

### FPGA-SIM battery (before every flash)

```bash
make -C sim sim_server_synth
make -C sim tb_ps2_typing
python3 tools/make_sd_image.py create sim/card.img
.venv/bin/python tools/check_runtime_parity.py   # must print BATTERY PASS
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

If Verilator `tb_ps2_typing` PASS and **LD7 never blinks**, this unit’s **J15 /
PIC24 is dead** (proven 2026-08-13). Use the GUI tether. Do not rewrite
console RTL or move JP4.

### Keyboard checklist (if LD7 never blinks)

RTL path is proven by `tb_ps2_typing`. Then check hardware only:

- **Unplug HDMI before any keyboard power-cycle test.** A connected HDMI
  monitor back-feeds 5 V into the board (keyboard LED stays lit with SW8
  off), so the keyboard never truly resets and the PIC24 never re-enumerates
  it. T100 never hit this — VGA carries no 5 V. Found 2026-08-13.
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

### Pmod input LED test (PS/2 keyboard + I2C joystick + J15 USB)

Own Vivado project under `build/pmod_input_test/` so it cannot clobber `build/nexys_video`. JA + JB stay as before. J15 USB: **classic keyboard PASS 2026-08-15 (user).** The earlier “no scancodes / LD14 only” keyboard was HID that the PIC24 does not translate to PS/2. Use a wired boot-protocol / “classic” USB keyboard on **J15** (no hub). Gaming/NKRO/wireless often enumerates (LD14) and never clocks W17. JA Pmod + JB stick still work on this same LED bit.

```bash
source scripts/vivado_env.sh && make -C tools/pmod_input_test bit flash
```

| Device | Plug | Pins |
|---|---|---|
| USB keyboard | **J15 USB Host** | PIC24 → PS/2 `W17`/`N13` (pull-ups) |
| Pmod PS/2 | **JA top row** | Data=JA1 (AB22), Clock=JA3 (AB20), GND=JA5, VCC=JA6 3.3 V |
| Mini I2C gamepad @ 0x5A | **JB** PH2.0→Dupont | SCL=JB1 (V9), SDA=JB2 (V8), G=JB5, V=JB6 3.3 V |

Match **labels** on the stick (G V SDA SCL), not wire colors. Do **not** use JXADC (VADJ ~2.5 V). JA VCC is 3.3 V — if the PS/2 keyboard stays dark, Pmod JP1 → external 5 V (VE) from board 5 V0; FPGA CLK/DATA stay 3.3 V. If the stick’s red LED never lights, power V from 5 V0 but keep SDA/SCL at 3.3 V. Never put 5 V on FPGA pins.

LED row, **LD0 on the left** (both live at once):

| LED | Meaning |
|---|---|
| **LD0** | stick LEFT |
| **LD1** | stick UP |
| **LD2** | stick DOWN |
| **LD3** | stick RIGHT |
| **LD4** | USB: **solid ON** = PIC24 ACKed `0xF4`. Off = still retrying / no PS/2 device clocks. |
| **LD5** | USB scancode (`ps2_rx`). Type after LD4 is on. |
| **LD6** | I2C ACK: **solid** = stick talking; **slow blink** = FPGA alive but no stick; **off** = bit not running |
| **LD7** | Pmod keyboard: ~200 ms pulse per decoded character |

Diagonals light two direction LEDs. Stick A/B still work in RTL but are not on LEDs (LD4/LD5 are USB).

USB vs LD14: BUSY flash + **no LD4** = PIC24 got HID but is not clocking PS/2 to the FPGA. BUSY + **LD4 flicker** + **LD5 pulse** = USB reached the FPGA. Pmod JA still only LD7.

**Board PASS 2026-08-15 (user):** J15 classic USB keyboard + JA Pmod keyboard + JB stick. J15 was not dead hardware.

**JS board top:** J15 + JA + JB are in [`rtl/top_nexys_video.sv`](../rtl/top_nexys_video.sv) and [`tools/board_flow/vivado_build.tcl`](../tools/board_flow/vivado_build.tcl). The next `make -C tools/board_flow bit` writes `build/nexys_video/jmr_nexys_video.bit` and `.bin` with all three ORed with the PROG GUI tether (cable optional). FPGA-SIM / PYTHON unchanged — F9 still uses the PC keyboard.

### Pmod input on the JS console (JA keyboard + JB stick)

Same plugs as the LED test. No FPGA-SIM edits. J15 `ps2_rx` stays; `jmr_ps2_host` stays off. Frozen JS LEDs unchanged (LD7 is still J15 only).

| Role | Plug |
|---|---|
| Type at READY | **J15** classic USB keyboard, or Pmod PS/2 on **JA** (also GUI tether) |
| Play | Mini I2C stick on **JB** (also GUI arrows) |

`joy_in = uart_joy_bits | {FIRE2, FIRE1, RIGHT, LEFT, DOWN, UP}` from I2C. NACK → stick bits 0.

Traces: `traces/session_*.log` (PYTHON) and `session_*_FPGA-SIM.log`.
See [SESSION_HANDOFF.md](SESSION_HANDOFF.md) for current agent priorities.

No HDMI Sink, DisplayPort, higher modes, or audio-over-HDMI for V1.

### Standalone input (non-negotiable)

The machine must run **without a PC**: HDMI monitor + USB keyboard + Pmod
joystick. UART/JTAG are for programming and optional debug only.

**This T200 unit:** J15 works with a **classic** USB keyboard. Some modern HID keyboards never become PS/2 (LD14 only). Type on J15 or **Pmod PS/2 (JA)**. Play on the **JB** stick or GUI arrows.

| Role | Plug | Path |
|---|---|---|
| Typing / EDIT / ESC | J15 classic USB, or Pmod PS/2 on **JA** | J15/`JA` `ps2_rx` → keyboard FIFO (GUI tether still ORed) |
| Play (move/fire) | Mini I2C stick on **JB** | I2C `0x5A` OR GUI KEYBITS → `joy_in` |
| Mouse | — | Out of V1 |

Many physical sources merge into **one INPUT FIFO** → INPUT engine → monitor /
JS events (pattern cite: BASIC sibling UART/`KEY` + PS/2 FIFO merge in
`JMR-BASIC-FPGA-COMPUTER/docs/FPGA_BRINGUP.md` — method only).

---

## Related

- [LINUX_WORKSTATION.md](LINUX_WORKSTATION.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [FPGA_FIT.md](FPGA_FIT.md)
- [SESSION_HANDOFF.md](SESSION_HANDOFF.md)
