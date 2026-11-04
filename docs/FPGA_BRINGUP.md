> Current jacks: [USB keyboard on J15, PS/2 mice on JA and JC](USB_KEYBOARD_PMOD_MICE.md). Dated sections below record the bits they were written for. They do not change the current jacks.

# FPGA bring-up — Digilent Nexys Video (primary)

Kept qualified bitstream: [run75 source and .bit](../build/run75_program_system/release/README.md).
The latest build is [run76](../build/run76_usb_keyboard_pmod_mice/README.md). Older build trees are in `to_delete/`.

Words: [README.md — Words used](../docs/WORDS.md#words-used-in-this-project).

**Primary board:** Digilent **Nexys Video** — Xilinx/AMD Artix-7
**XC7A200T-1SBG484C** (“**T200**” in lab shorthand — the 200T chip).

This page teaches **RTL → FPGA-SIM → Vivado → `.bit`**, the board jacks,
and flash. It is **not** a third copy of the RAM law (that is
`.cursor/rules/never-fake-fpga-sim.mdc` + [FPGA_FIT.md](FPGA_FIT.md)
NEVER table). Linux workstation notes that used to live in
`LINUX_WORKSTATION.md` are **here**.

**Working sibling (do not confuse):** `JMR-BASIC-FPGA-COMPUTER` on Digilent
**Nexys A7-100T** (“**T100**”) already has a **fully working** NLISC-BASIC
console + USB keyboard. Steal **method** (PYTHON → real FPGA-SIM → board;
PIC24 USB→PS/2). Do **not** copy A7 pinouts, BASIC ISA, or VGA assumptions
into this tree. This product is **NLISC-JS** + **HDMI 640×480** on Nexys
Video.

**STOP:** Do **not** `make … bit` / flash until FPGA-SIM is perfect for the
feature under test (matching Python/native RTL regressions + relevant benches;
[the clock-switch record](STANDARD_RELEASE.md)).
Flashing half-broken bits wastes hours.

## Current standard

Which bit is the rollback, which folder is in progress, and which image is still in QSPI: [FPGA_FIT.md](FPGA_FIT.md). The VM on the qualified bits is 33.333 MHz. Fabric and DDR stay at 100 MHz.
Historical dated notes below do not select the current release. `flash` / `flash-qspi` load `releases/current/fpga.bit` without starting a new build.

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
Full dictionary: [README.md — Words used](../docs/WORDS.md#words-used-in-this-project).

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
arrays is **not** board-ready (Vivado flatten: RSS tens of GB after
`top_nexys_video` synthesizes; unused-FF `e32_p_clr` is not the bug).
`unique case (casestate)` that **reads** `arr_len[v]` / `obj_n[fo]` /
`spr_mem[so]` is the same class as combo `always_comb` — one cone, every
arm a port. Heap-name grep empty is not the cone. Write memories as SRAM
from the first RTL line: address this clock, `*_rdata` next. Same files
as the `.bin`. Rule: [FPGA_FIT.md](FPGA_FIT.md),
`.cursor/rules/never-fake-fpga-sim.mdc`, Constitution § NLISC method step 7.

**Trap (2026-08-17 overnight cheat):** Verilator will also happily simulate
**two** copies of `vvars` / `venv_*` / `vobj_*` (exec64 private + parent GC).
The leftover T200 BRAM cannot hold both, and they go stale. Do **not** strip
generation / gen-match so the copies would not “look stale.” That produced
four glass symptoms (PACMAN black FB, rAF `fn`, Date throttle,
INVADERS/DONKEY/MRDO skew) — it is **one** cheat, not four title bugs.
FPGA-SIM must stay the path that `make -C tools/board_flow bit` compiles to
a standalone `.bin` (HDMI + local keyboard). See `one-heap-keep-gen.mdc`.

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
| **PYTHON** | **JMR bytecode VM** — **V1.0:** `card.img` HTML + minted `.JSH` | `functional_model/` (same ProgramImage as FPGA-SIM / BOARD) |
| **FPGA-SIM** | Same RTL as the board, simulated — **same `card.img`** | Verilator → `sim/sim_build_synth/jmr_js_sim_server` (**default**). Host twin only with `JMR_SIM_HOST=1` — never a silent fallback. |
| **BOARD** | Real Nexys Video. **V1.0:** `RUN` uses `.JSH` from the burned `card.img`. **V1.5:** `COMPILE` on the chip mints that sidecar. | Silicon |
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
  non-converging `while` patterns). Parent unique-case **reads** of heap
  SRAMs use `*_rdata` after a wait beat — do not add `mem[idx]` in a new
  arm. `.cursor/rules/never-fake-fpga-sim.mdc` rule 3.
- Do not invent fit numbers — read the generated fit report after the first
  real `make … bit`.

---

## Board identity (frozen)

| Item | Value |
|---|---|
| Digilent product | **Nexys Video** (primary) |
| FPGA part | **XC7A200T-1SBG484C** |
| External RAM | 512 MiB DDR3 behind an **8 MiB** port (`addr[21:0]`). The byte map is [lastrun_ARCHITECTURE.md](lastrun_ARCHITECTURE.md). |
| Video | **HDMI Source** (J8) — native **640×480 @ ~60 Hz**, ~25.175 MHz pixel clock |
| Framebuffer | Native **640×480**, 8 bpp / 256-entry RGB888 palette. One persistent BRAM canvas; present copies to the DDR front image. The GUI mirror comes back over the PROG cable and cannot keep up with 60 Hz. HDMI is the picture. |
| Keyboard | **J15** USB host. Plugs, pins, and what J15 cannot do: [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md). |
| Play controls | Keyboard arrows/Space/Enter → KEYEVT (`keyCode` 37–40 / 32 / 13). GUI arrows+Space → KEYBITS (BOARD: PROG `0xFE`+bits). Pmod stick on **JB**. |
| Mouse | **JA** PS/2, second mouse on **JC**, stick on **JB**. [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md). |
| Host link | PROG FT245 (ch A / `.0`) — flash + tether glass + play keys |
| Storage | µSD SPI + FAT32: `LOAD` reads HTML; `RUN` loads the card-minted `.JSH` including full ASET art. |
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
Type from the **J15** USB keyboard. The pointer is the **JA** PS/2 mouse (JC is the second mouse). Play from the **JB** stick or the F9 BOARD tether.
Do **not** raise HDMI resolution or switch this T200 to VGA for torn glyphs
(that was VRAM CDC; dual-clock scan port).

```bash
export VIVADO="$(command -v vivado)"
make -C sim sim_server_synth          # FPGA-SIM; -B to force (not clean)
make -C tools/board_flow bit          # publish only if WNS ≥ 0
make -C tools/board_flow flash        # SRAM first
# HDMI: READY letterbox; play via GUI arrows+Space
```

**First T200 `.bin` vs later:** the first `make -C tools/board_flow bit` creates
the Vivado project, generates DDR3 MIG, and fully synthesizes `jmr_js_vm`
(often **1–3 hours** on a small design; a past full-VM run passed 8 hours and then ran out of memory). Later `bit`
**reuses** `build/nexys_video/vivado` (skip MIG generation; reuse an unchanged, source-verified synthesis DCP).
Changed RTL gets full synthesis with automatic incremental checkpoints off.
Use `make -C tools/board_flow bit-fresh` when the source *list*, MIG
(Memory Interface Generator), or XDC (pin/clock constraints) changed —
**including the 2026-08-21 next build** (exec32 deleted + incremental
stitch). Do **not** `bit-fresh` to “recover” a crash *during* mapping:
there is no **DCP** (Design CheckPoint) until `synth_1` is 100%, and you
throw away MIG/project state. Do not `make -C tools/board_flow clean`
between RTL tweaks. Synth **2 threads**. Full hygiene:
[SESSION_HANDOFF.md](SESSION_HANDOFF.md) § Synthesis.

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

For the standard release, the exact persistent command is:

```bash
sudo openFPGALoader -b nexysVideo -f releases/current/fpga.bit
sudo openFPGALoader -b nexysVideo releases/current/fpga.bit
```

Use `.bit` for this flash path; keep `.bin` as a secondary archive. See
[the clock-switch record](STANDARD_RELEASE.md).

### PROG-cable tether — Runtime:BOARD mirror (T100 method)

Same USB cable as JTAG (J12 PROG). The bitstream streams:

- Text: `S<rowhex>:` + 64 chars per row (letterboxed in GUI like HDMI 640×480)
- Game: `P<rr>:` + 160 hex nibbles (mini-FB 160×120 ×4 → full GUI glass)
- Keys: `K` line on each USB Host `ps2_strobe` (flight-log proof)

Every host byte lands in the keyboard FIFO. **F9 → BOARD** mirrors HDMI and
sends play KEYBITS (`0xFE` + 6-bit field) because J15 cannot. **F8**
sends SOURCE as `0xFC` + u32 LE length + payload, then types `SAVE "NAME"`.
HTML RUN streams `.JSH` as `0xFD` + u32 LE length + payload.

Nexys Video's FT2232 **channel A** is the FT245 FIFO (DPTI), not a UART — RTL
`jmr_ft245_async` speaks that FIFO; Linux exposes it as the `/dev/ttyUSB*`
whose USB location ends in `.0`. Channel B (`.1`) is **JTAG** — never the
tether. `JMR_JS_SERIAL` overrides autodetect.
Gates: `make -C sim tb_uart_link tb_ft245`.

**Permission denied opening `/dev/ttyUSB0`:** this is host device access,
not evidence of a bad bitstream. Run
`sudo setfacl -m u:"$USER":rw /dev/ttyUSB0`, restart the GUI, and select BOARD.
For permanent access, `sudo usermod -aG dialout "$USER"`, then log out/in.
Use the current channel-A node (`*-if00-port0`); leave channel B for JTAG.

### Live board telemetry

The machine reports its own faults on the PROG tether. **Decode tables:**
[ARCH_MONITOR.md](ARCH_MONITOR.md).

**Stale `card.img` looks like a VM bug.** If HTML in `storage/` is newer than
`card.img`, the board is running an old program. Rebuild before drawing a
conclusion from a fault. A halt and a hang look the same on glass — the V-line
is what distinguishes them. In the Inspector, `—` means **not transmitted**,
not zero.


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

- User product path: `LOAD "*.HTML"` + `RUN`. **V1.0:** PYTHON, FPGA-SIM,
  and BOARD all play project `card.img` (`RUN` = minted `.JSH`; the chip
  does not compile). Rebuild the card after `storage/` edits.

> ### ⚠️ A stale `card.img` makes the board run a program you already fixed
>
> The board never reads `storage/*.HTML`. It reads the **minted `.JSH`
> baked into `card.img`**. Edit a title, skip the card rebuild, and the
> board keeps playing the old code — silently, with no warning anywhere.
>
> **This cost a full day, 2026-08-26/27.** `card.img` was minted 21:51;
> `storage/PACMAN.HTML` was fixed at 22:09 — **18 minutes later**. The
> board then ran the *unfixed* PACMAN across runs 45, 46 and the nocache
> A/B, faulting every time, while the working version sat in the repo for
> ~13 hours. Bitstreams, timing closure and a DDR3 cache A/B were all
> investigated before anyone checked the card's timestamp. Rebuilding the
> card fixed it outright.
>
> Worse, it silently invalidates sim-vs-board comparisons: FPGA-SIM
> compiles from `storage/`, the board plays the card. "It faults on the
> board but not in sim" meant only that the two were running **different
> programs**.
>
> **Check before every board debugging session:**
>
> ```bash
> ls -l --time-style=+"%m-%d %H:%M" card.img storage/*.HTML | sort -k6,7
> ```
>
> If any title is newer than `card.img`, rebuild the card before drawing
> a single conclusion from the board. **V1.5:** `COMPILE` on the machine
> mints `.JSH`; `RUN` is unchanged. Full-quality graphics stream from the
> ASET section into the external SRAM asset bank (never pack Donkey
> art into code BRAM; no `NAME.DAT`). Never dukpy on silicon.
- `?NH` = HTML path debt (temporary). Missing compile path → fail loud
  (not Invaders hex lie).
- Esc exits game_mode

Historical SRAM image: **2026-08-13 03:36**, WNS **+0.139 ns** (HDMI VRAM CDC +
tether KEYBITS). See [SESSION_HANDOFF.md](SESSION_HANDOFF.md).
Rule: `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`.

### Simulation gates for a new source build

```bash
make -C sim sim_server_synth          # same RTL; do not clean
.venv/bin/python -m pytest -q
make -C sim tb_uart_link tb_ft245
```

The standard release has frozen regression evidence in
[STANDARD_RELEASE.md](STANDARD_RELEASE.md). The legacy
`check_runtime_parity.py` alias assumption is recorded there; do not
misreport its result as BATTERY PASS.

Do **not** flash a new source build until its matching regressions pass **and** you are
intentionally proving silicon for a feature that already matches on FPGA-SIM.
Also check setup **and** hold timing and the area gates. The current VM
already runs at 100 MHz ÷ 3; fabric and DDR stay at 100 MHz. A fabric-to-VM
path can still require 10 ns, so changing the VM divider does not remove
that constraint. Repair the measured cone or qualify its CDC/pipeline;
never relax constraints just to publish a bit. Numbers: [FPGA_FIT.md](FPGA_FIT.md).

### T100 vs T200 keyboard (same method, different board)

| | T100 BASIC (working) | T200 JS (this board) |
|---|---|---|
| Board | Nexys A7-100T | Nexys Video |
| USB Host | **J5** | **J15** |
| PIC24 | USB HID → PS/2 Set-2 | same Digilent idea |
| FPGA pins | F4 / B2 | **W17 / N13** (`constraints/nexys_video.xdc`) |
| Video | VGA | HDMI |

If Verilator `tb_ps2_typing` PASS and **LD7 never blinks**, check the
keyboard before calling the jack dead. J15 works with a wired boot-protocol
keyboard. HDMI back-feed and a wireless dongle both look like a dead PIC24.
[USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md). Do not rewrite
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

This is **not** FPGA-SIM and **not** BASIC on T200. It is a tiny RX-only design: J15 PIC24 → PS/2 `W17`/`N13` → LEDs. No HDMI, no VM, no tether. Own Vivado project under `to_delete/hid_led_blink/` so it cannot clobber the JS bit build or `sim/sim_build_synth`. Do not add `tools/hid_led_blink/` to `CORE_SRCS`.

One line (after the JS Vivado run is **idle**):

```bash
export VIVADO="$(command -v vivado)" && make -C tools/hid_led_blink bit flash
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

### HDMI mouse probe (cursor, two buttons, wheel)

**Not FPGA-SIM** and **not** the JS `.bit`. Own Vivado project under
`build/mouse_probe/` so it cannot clobber `build/nexys_video`. The
node-locked license is uncounted, so this build may run beside the JS
build. Do not add `tools/mouse_probe/` to `CORE_SRCS` or the JS
board-flow file list.

Run:

```bash
source scripts/vivado_env.sh
make -C tools/mouse_probe bit flash
```

Mouse in **J15** before power. HDMI on **J8**. The glass is 640×480:

| On screen | What it proves |
|---|---|
| Arrow follows the mouse | movement |
| Left lamp and the left box turn green | left button, and the cursor is over that box |
| Right lamp and the right box turn red | right button |
| Middle lamp turns yellow | middle button, if the mouse has one |
| White marker moves in the center track | scroll wheel. Three white pips above the track mean the mouse answered wheel ID `03`. One red pip means this port is a 3-byte mouse and the wheel byte is not there |
| Bottom center box, and the line above it | each new letter or digit. The line holds the last 32 |
| *(2026-11-03)* no GO TO KEY button, no F10 | removed. Keyboard and mouse are separate plugs. Nothing switches |

**Mouse-only PASS 2026-11-02 (owner).** Cursor, left button, right button, and the scroll wheel all worked on J15 with this probe. That is one mouse. It does not make a keyboard-and-mouse combo work. Limits: [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md).

Plugs, pins, parity, and what J15 cannot do are [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md). This probe's LEDs: LD0 heartbeat, LD1 left, LD2 right, LD3 middle, LD4 wheel notch, LD5 stream ready, LD6 clock, LD7 data. The November 3 keeper that typed a keyboard on JA was the opposite of the current plugs. Blue lights on a Pmod only prove power.

### Pmod input LED test (PS/2 keyboard + I2C joystick + J15 USB)

**Not FPGA-SIM.** No VM, no HDMI, no F9. Own Vivado project under
`to_delete/pmod_input_test/` so it cannot clobber `build/nexys_video` or
`sim/sim_build_synth`. Do not add `tools/pmod_input_test/*.sv` to
`sim/Makefile` `CORE_SRCS`. Different top (`top_pmod_input_test`). The machine's plugs are [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md). Wall:
[RTL_REORG.md](RTL_REORG.md#probe-bits).

J15 USB: **classic keyboard PASS 2026-08-15 (user).** LD14 with no clock is a keyboard the PIC24 does not translate. Use a wired boot-protocol keyboard on J15. This LED bit still accepts a Pmod keyboard on JA and the stick on JB. The machine's mouse is also on JA. [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md).

```bash
export VIVADO="$(command -v vivado)" && make -C tools/pmod_input_test bit flash
```

| Device | Plug |
|---|---|
| USB keyboard | **J15** |
| Pmod PS/2, to see LD7 | **JA** top row. Pins are on the wiring page. This LED bit treats JA as a keyboard. The machine treats JA as the mouse. |
| Mini I2C gamepad at `0x5A` | **JB** |

Match the stick labels (G, V, SDA, SCL), not the wire colors. If the stick's red LED never lights, power V from 5 V0 and keep SDA and SCL at 3.3 V. Pins and the VB jumper: [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md).

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

### Plugs on the current bit

J15 is the USB keyboard. JA and JC are PS/2 mice. JB is the stick. Pins and the limits are [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md). The LED meanings above belong to those probes, not to the machine.

`joy_in = uart_joy_bits | {FIRE2, FIRE1, RIGHT, LEFT, DOWN, UP}` from I2C. NACK → stick bits 0.

Traces: `traces/session_*.log` (PYTHON) and `session_*_FPGA-SIM.log`.
See [SESSION_HANDOFF.md](SESSION_HANDOFF.md) for current agent priorities.

No HDMI Sink, DisplayPort, higher modes, or audio-over-HDMI for V1.

### Standalone input (non-negotiable)

The machine must run **without a PC**: HDMI monitor + USB keyboard + Pmod
joystick. UART/JTAG are for programming and optional debug only.

**This T200 unit:** keyboard on J15, mouse on JA, second mouse on JC, stick on JB. Some HID keyboards never become PS/2 (LD14 only). [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md).

| Role | Plug | Path |
|---|---|---|
| Typing / EDIT / ESC | **J15** USB keyboard | J15 `ps2_rx` → keyboard FIFO (GUI tether still ORed) |
| Play (move/fire) | Mini I2C stick on **JB** | I2C `0x5A` OR GUI KEYBITS → `joy_in` |
| Mouse | **JA** PS/2, **JC** second mouse | Both hosts share one pointer. The mouse does not feed `joy()`. |

Many physical sources merge into **one INPUT FIFO** → INPUT engine → monitor /
JS events (pattern cite: BASIC sibling UART/`KEY` + PS/2 FIFO merge in
`JMR-BASIC-FPGA-COMPUTER/docs/FPGA_BRINGUP.md` — method only).

---

## Related

- [ARCH_MONITOR.md](ARCH_MONITOR.md) — V-line / D-line decode tables, and what BOARD cannot report
- [ARCHITECTURE.md](lastrun_ARCHITECTURE.md)
- [FPGA_FIT.md](FPGA_FIT.md)
- [SESSION_HANDOFF.md](SESSION_HANDOFF.md)
- Isolated J5 line-out beep (not JS `board_flow`): [../tools/audio_beep_test/README.md](../tools/audio_beep_test/README.md)


## GUI congestion policy — November 3, 2026

The owner requests **no further game speed benchmarks** for this work. Keep the
VM at 33.333 MHz and fabric at 100 MHz. Use static timing/resource
checks and necessary functional GUI checks. Do not reduce game capacity or speed
to fit the GUI. Current jacks are J15 USB keyboard, JA PS/2 mouse, JC second
mouse, JB joystick.

The checkpoint below is the QSPI image (run73o), not the rollback. The rollback bit is run75. [FPGA_FIT.md](FPGA_FIT.md). Path: `to_delete/archive/run73-development-2026-11-02/release/qualified_post_route.dcp`.
Its SHA256 is `1b473a2a203de4b86e34a5eb133cbd1b7661cf808059e4ab027de4766bfd0eaa`,
matching the release manifest. Preserve compatible hard-macro locations from
this reference rather than letting a small GUI revision reshuffle the computer.
Validate names, primitive types, relevant settings and legal sites first.
**Do not copy general SLICE placements or locations for changed blocks.**

The A200T has 134,600 LUTs, 269,200 FFs, 11,550 SLICEM sites and 365 BRAM36 equivalents. The I
placement used 355.5 BRAM and 10,237 SLICEM sites. Spare LUT/FF totals do not imply
spare local routing or memory-capable slices. Seven-series packing also requires
compatible clock/enable/reset signals within a slice; control sets increased
from 1,929 in the working reference to 2,333 in I.

Choose GUI resources deliberately: large state memories belong in BRAM when
possible; small local tables/queues can use LUTRAM/SRL; short-lived local control
can use FFs. Do not replace a large RAM with a scattered LUTRAM crossbar merely
to save one block. The GUI's four inferred DSPs implement small constant address/
scrollbar arithmetic; local carry/LUT logic is a tested alternative, leaving CPU
math DSPs alone. An isolated attribute-only test removed all four. Its font-ROM
BRAM trade saved only 101 LUTs in the two isolated modules, so do not assume that
extra BRAM is worthwhile without full-context evidence.

Resource evidence and validated location helpers are in
`to_delete/run74i_bram_labels/a200_resource_review/`. The controlled placement-only
check is `to_delete/run74j_stable_computer/`; it uses the existing compiled I netlist,
376 matching RAM and 116 matching DSP locations, without resynthesizing CPU logic.
J's placement-only check produced a new 103% eastward congestion hotspot and
was stopped before routing. Matching individual macro settings did not prove
that fixing their entire group would help: associated logic and DSP cascades
also affect placement. Do not carry those blanket anchors into the next build.

The measured I route failed at -0.629 ns setup. Its worst GUI paths are page
caption formatting, the asynchronous mouse-queue read into VM dispatch, and
menu-byte decoding into command-table enables. The next revision, run74k,
snapshots caption digits with the existing frame state, registers the FIFO head
with empty/last-word bypass, and locally predecodes metadata bytes. Menu
throughput stays one byte per fabric clock. CPU/game code and clocks remain
unchanged; no game-speed benchmarks are required. Focused old/new RTL checks
passed for queue corner cases, parser output, and Finder pixel writes.

These checks are not a timing-qualified release. All normal routed setup/hold/
pulse/clock/route/DRC/READ_FIRST gates remain required before programming.

Primary AMD guidance:
- [UG949: Reusing Placement Results](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Reusing-Placement-Results)
- [UG474: CLB Resources](https://docs.amd.com/r/en-US/ug474_7Series_CLB/7-Series-FPGA-CLB-Resources)
- [UG474: Distributed RAM Applications](https://docs.amd.com/r/en-US/ug474_7Series_CLB/Distributed-RAM-Applications)
- [UG949: Reducing Control Sets](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Reducing-Control-Sets)
- [UG901: USE_DSP](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/USE_DSP)
