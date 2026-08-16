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

Last RTL lockstep: class `get name()` on GET_PROP now invokes (same stack as CALL_METHOD argc 0). DONKEY floor collision uses `this.marioBottom`; without the getter the overlap test saw `+0` and the player fell through. Same class of miss as a projectile AABB that never sees real edges.

User has **not** F9-approved FPGA-SIM `(RTL)` yet. Please F9 FPGA-SIM `(RTL)` and check DONKEY standing on girders.

FPGA-SIM agent owns `rtl/engines/jmr_js_vm.sv` (do not rewrite heaps in parallel). Fit: same RTL as FPGA-SIM; 2026-08-16 Vivado synth died on `vobj_key` (4.2 Mbit). Char VRAM ports are BRAM-legal. No `.bin` until heap is 1-D 1W1R SRAM **and** that F9.
