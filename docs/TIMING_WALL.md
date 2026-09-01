# Why the JS core does not run at 100 MHz

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**What this phrase meant.** The FPGA’s JavaScript engine was asked to
finish too much work in **one 100 MHz clock beat** (10 nanoseconds).
Timing slack went **negative** — the clock “hit a wall.” That is a
failed bitstream, not a mysterious board bug.

**What measurement taught.** The slow paths were about **half logic,
half wires**. Route delay tracked **path depth**, not unlucky placement.
Seed-chasing does not fix that. Two combinational **divides** in the
sprite math were the worst cone (an area hoist that bought a timing
problem).

**What we do instead.** Do **not** slow DDR3 / MIG `ui_clk` (100 MHz).
Do **not** move to a bigger FPGA. **Run the JS core on a divided clock**
(today ÷7 ≈ 14.3 MHz) and keep DRAM and scanout on the fast clock.
Live numbers and the 50 MHz hedge recipe:
[FPGA_FIT.md](FPGA_FIT.md) SCOREBOARD and
[If timing fails](FPGA_FIT.md#if-timing-fails-wns--0--slow-the-js-core-not-ddr3).
Which strobes must be stretched or edge-qualified when `VM_CLK_DIV`
changes: [FPGA_FIT.md — JS core clock](FPGA_FIT.md#js-core-clock-and-crossing-strobes).

**How to write so it does not come back.**
[RTL_DESIGN_PRINCIPLES.md](RTL_DESIGN_PRINCIPLES.md) §2 (depth, divides,
÷N core clock, congestion).

Run-by-run ledgers (30–68) are **git history**, not a live page.
