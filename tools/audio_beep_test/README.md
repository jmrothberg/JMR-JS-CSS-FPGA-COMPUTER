# Audio beep test — phase 0 of the line-out PSG

Smallest possible bitstream that makes a sound on the Nexys Video's
**J5 line-out**. No VM, no HDMI, no DDR3, no SD card. If this is silent,
the fault is the codec / clock / wiring — not the console. That is the
entire point of doing it before touching `rtl/`.

Plan: `~/.cursor/plans/fpga_line-out_psg_416b9773.plan.md` (todo `beep-test`).

## Run it

```bash
source scripts/vivado_env.sh
make -C tools/audio_beep_test bit flash
```

Then plug headphones or powered speakers into **J5** (line out).
Expect a **440 Hz beep pulsing about twice per second**.

Build is small and quick. It refuses to start while another Vivado is
running, so let any `board_flow` run finish first.

## What it does

| Block | File | Notes |
|---|---|---|
| 12 MHz MCLK | `top_audio_beep_test.sv` | private MMCM, 100 MHz × 12 ÷ 100 |
| Codec register init | `jmr_adau1761_cfg.sv` | write-only I2C, addr `0x3B`, 16-bit subaddress |
| I2S master + tone | `jmr_i2s_beep.sv` | BCLK = MCLK/4, LRCLK = MCLK/256 → fs = 46.875 kHz |

The FPGA is I2S **master** (drives BCLK and LRCLK); the codec is slave.
MCLK is used directly — no codec PLL — which is why 12 MHz gives a clean
256×fs.

## LEDs (LD0 leftmost) — read these before concluding "no sound"

| LED | Meaning |
|---|---|
| LD0 | MMCM locked (12 MHz MCLK exists) |
| LD1 | I2C init sequence finished |
| LD2 | every I2C byte ACKed → **codec is present and talking** |
| LD3 | at least one NACK (sticky) → I2C / wiring fault |
| LD4 | blinking ≈1.4 Hz → I2S frame clock running |
| LD5 | blinking ≈2 Hz → tone gate open, sound should be audible now |
| LD6–7 | I2C step counter high bits — shows where it stalled |

Diagnosis when you hear nothing:

- **LD0 dark** — clock problem; nothing downstream is meaningful.
- **LD3 lit** — the codec never acknowledged. Check the I2C address
  (`0x3B` → write byte `0x76`), the W5/V5 pins, and the pull-ups.
- **LD2 lit, LD4 dark** — codec configured but no frame clock; the I2S
  divider or its reset is wrong.
- **LD2 + LD4 + LD5 all healthy but silent** — the plumbing is right and
  the suspect is the **register table** (see below). This is the most
  likely outcome of a first attempt.

## The honest caveat

The clocking, I2C framing and I2S timing here are structural and easy to
verify from the LEDs. The **ADAU1761 register values** in
`jmr_adau1761_cfg.sv` were written from the datasheet's programming model
rather than copied from a known-good board bring-up, so they are the most
likely thing to need a tweak. They are a plainly-formatted table at the
top of that file, one line per register, each commented with intent —
edit, rebuild, reflash.

If LD2 is lit the codec is definitely alive and listening, which means any
remaining silence is a register-value problem and **not** a hardware or
wiring problem. That distinction is worth the whole test.

## Rules this test obeys

- Own build directory (`build/audio_beep_test/`); never touches
  `build/nexys_video*` or `sim/sim_build_synth`.
- These `.sv` files are **not** in `sim/Makefile` `CORE_SRCS` and **not**
  in `tools/board_flow/vivado_build.tcl`.
- The I2C master here is a deliberate snapshot, not a reuse of
  `rtl/phys/jmr_i2c_master.sv` — an audio experiment must not be able to
  perturb the live joystick PHY.
- 0 BRAM, 0 DSP, no DDR3, no SD.
