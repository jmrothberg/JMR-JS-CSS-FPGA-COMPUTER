# Overnight fit campaign (08-21→22) — not live status

**Not live status.** Scoreboard and levers:
[docs/FPGA_FIT.md](docs/FPGA_FIT.md). Clock / timing:
[docs/TIMING_WALL.md](docs/TIMING_WALL.md) (what the phrase meant) and
[docs/FPGA_FIT.md](docs/FPGA_FIT.md) (numbers + hedge).

The night-by-night diary lived here. Git still has it
(`git log -- OVERNIGHT_STATUS.md`). Lessons that still teach:

- A parent FSM that holds big arrays as flip-flops explodes LUT count.
  Write **Port A** (tiny write process). Copy 2:
  [docs/FPGA_FIT.md](docs/FPGA_FIT.md) NEVER.
- **Do not retry `vst_win` shrink** without a pop-refill detector — silent
  correctness bug at deep nesting (`tests/test_stack_window_depth.py`).
- ExploreArea stall was a mux, not “Vivado is slow.” Fence / RTL fix;
  directive shopping is a dead lever.
- A bigger FPGA was **ruled out**: [docs/BIGGER_PART.md](docs/BIGGER_PART.md).
