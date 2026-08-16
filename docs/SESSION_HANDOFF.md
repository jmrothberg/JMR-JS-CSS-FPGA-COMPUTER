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

## FPGA-SIM lockstep (headless pixels green — waiting F9)

`make -C sim sim_server_synth` is current. Same ProgramImage stream as PYTHON. Headless pixel gates on real RTL (`sim/sim_build_synth/jmr_js_sim_server`, no host twin):

| Title | Gate | Result |
|---|---|---|
| INVADERS | held-left FB changes, `fclk` ≤ 16M | passed |
| PACMAN | Enter leaves splash, maze `nz` ≥ 1000, next FRAME differs | passed |
| DONKEY | title `nz` ≥ 50, Enter keeps rAF, FB keeps changing | passed |

Last RTL lockstep: LT/GT ToNumber (non-Number → `+0`, same as PYTHON) so DONKEY `jumpHeight >= 750` before the first jump no longer `fault=5`.

User has **not** F9-approved FPGA-SIM `(RTL)` yet.

No `.bit`/`.bin` until that F9.
