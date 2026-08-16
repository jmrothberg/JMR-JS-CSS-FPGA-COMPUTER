# Session handoff

**2026-08-15 night.** Plan does the work. This file is **current truth only**.

Product plan: `working_html_fpga-sim`. PYTHON glass step is **user-confirmed**.

## User last saw (PYTHON GUI)

| Title | Glass |
|---|---|
| INVADERS | works |
| PACMAN | works |
| DONKEY | works |

User F9 PYTHON: all three `LOAD "NAME.HTML"` / `RUN` play. Do not mark BOARD/ASIC done.

## FPGA-SIM lockstep (in progress)

Value64 RTL matches PYTHON on IIFE + `class` + `new` + method, and on `clear` / `fillRect` / `swapBuffers` pixels. `v64_to_uint32` now uses the IEEE exponent directly (a package-function signed temp was stuck at 0, so every finite Number became 1). Rebuild `sim_server_synth` is current. 17 Value64 ProgramImage checkpoints pass.

Still not F9 FPGA-SIM titles: remaining lockstep is recursive env capacity (RTL `ENV_DEPTH` 32 vs PYTHON 1024; this test hits env overflow at csp=32), plus title constructors/natives (`drawImage`, ctx, rAF HTML). FPGA-SIM `RUN` already streams an ephemeral ProgramImage.

No `.bit`/`.bin` until the user F9-approves FPGA-SIM `(RTL)`.
