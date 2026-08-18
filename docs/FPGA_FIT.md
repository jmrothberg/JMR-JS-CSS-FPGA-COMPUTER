# How JMR JS fits the T200 (and would fit a T100)

Same job as the BASIC sibling’s `docs/FPGA_FIT.md` (`JMR-BASIC-FPGA-COMPUTER`):
measured Vivado numbers after a bit finishes. Estimates for this RTL are
the table below; do not quote them as a bitstream.

This bitstream is built for **Nexys Video / XC7A200T** (“T200”). The T100 column
is the **same used counts** against **Nexys A7-100T / XC7A100T** budgets — “would
it fit,” not a T100 `.bin` from this repo.

**Authoritative report:** `build/nexys_video/utilization_impl.rpt` after
`make -C tools/board_flow bit`. Companion: [FPGA_BRINGUP.md](FPGA_BRINGUP.md),
[ARCHITECTURE.md](ARCHITECTURE.md), live status [SESSION_HANDOFF.md](SESSION_HANDOFF.md).

The `.bin` file is ~9.3 MB because that is the **200T configuration image size**,
not how full the chip is.

## Same RTL for FPGA-SIM, `.bin`, and ASIC

Coding law (six rules): `.cursor/rules/never-fake-fpga-sim.mdc`. This file
is **measured numbers**, not a second copy of that list. Live leftovers:
[SESSION_HANDOFF.md](SESSION_HANDOFF.md). Do not quote a new bitstream until
`make bit` actually finishes.

FPGA-SIM and `make -C tools/board_flow bit` compile the **same** `rtl/*.sv`.
`SYNTHESIS` in the board top is I/O (clocks, HDMI), not a second heap.
`ram_style = "block"` is a Vivado hint, not a Xilinx primitive inside the VM.
Clock class **~30 MHz**. Extra GET_PROP clocks (~1 µs worst case vs 16.7
ms/frame) are playable; combo heaps are not a speed win.

**Capacity (leftover block RAM (BRAM) after dual framebuffer (FB)):** T200 ≈
**365** RAMB36 ≈ **1.64 MB**. Dual 640×480×8 FB ≈ **0.6 MB**. Leftover ≈
**1 MB** for code + JS heap + console. Legal: `MAX_OBJ=1024` × 32 × 80b ≈
320 KB plus two-tier arrays (`1536×32` + `128×128`) × 64b ≈ 512 KB plus
`ENV_DEPTH=512` × 16 × 80b `venv_slot` ≈ 80 KB (same in PYTHON). Nested maps
+ JSON clones need ~1152 short arrays; `push` past 32 uses the long bank.
The 8192 / 4096 depths were ~**7 MB** — Verilator runs, the chip cannot.
External **4 MB** static RAM (SRAM) is **ASET art only** — do not put JS
objects there or bump that bank to 8 MB. `cls_mname` / `cls_mip` stay 16×16
(4 Kbit, not a JS heap). True dual-port only for CPU+scanout (video RAM /
FB); dump shares the CPU read port.

## This RTL vs T200 (estimates)

Not a routed report. Tile math is `bytes × 8 / 36 kbit`. 4-bit pixels would
not fix a synth hang (combo `arr[i]`); they would only cut FB BRAM in half
and rewrite the 8-bpp ABI. Replace these numbers from
`utilization_impl.rpt` when the next bit finishes with worst negative slack
(WNS) ≥ 0.

| Component | Estimate | T200 spec (XC7A200T) |
|---|---|---|
| Lookup tables (LUTs), if hierarchy holds | 45k–75k | 134,600 LUTs |
| Flip-flops (FFs), legal SRAM | ~15k class | 269,200 FFs |
| Dual FB 640×480×8 (front+back) | ~0.60 MB / ~133 tiles | 365 BRAM tiles / ~1.64 MB |
| ImageData `imgd_pix` (third 640×480×8) | ~0.30 MB / ~67 tiles | 365 tiles / ~1.64 MB |
| On-chip sprite scratch `spr_mem` | ~0.25 MB / ~57 tiles | 365 tiles / ~1.64 MB |
| Console source `source_mem` | ~0.13 MB / ~29 tiles | 365 tiles / ~1.64 MB |
| JS objects `MAX_OBJ=1024` × 32 × 80b | ~0.31 MB / ~71 tiles | 365 tiles / ~1.64 MB |
| JS arrays `1536×32` + `128×128` × 64b | ~0.50 MB / ~114 tiles | 365 tiles / ~1.64 MB |
| JS env `ENV_DEPTH=512` × 16 × 80b | ~0.08 MB / ~18 tiles | 365 tiles / ~1.64 MB |
| **BRAM rows if all infer as tiles** | **~2.2 MB / ~489 tiles** | **365 tiles / ~1.64 MB** |
| ASET art (4 MB SRAM port) | off-chip (board DDR3) | not BRAM |
| Memory Interface Generator (MIG) FIFOs | extra BRAM, size unknown until impl | inside the 365 |

If every on-chip array infers as BRAM, this RTL is **over** the 365 tiles.
A synth hang (RSS tens of GB, log frozen) is flatten / FFs, not “needs more
LUTs.” Fill the table from `utilization_synth.rpt` when this `make bit`
finishes synth, then `utilization_impl.rpt` after WNS ≥ 0. Do not invent
counts. Keyboard bring-up is [FPGA_BRINGUP.md](FPGA_BRINGUP.md), not a fit
baseline for this VM.

`$readmemh` font lives beside `rtl/engines/jmr_js_vm.sv`. Board asset SRAM is
MIG DDR3 behind `jmr_ddr3_sram_bridge`. Palette BRAM is dual-clock; HDMI game
mode reads it.

---

## Headline (this `make bit` — waiting)

Part: `xc7a200tsbg484-1`. Early counts: `build/nexys_video/utilization_synth.rpt`
when `synth_1` hits 100%. Trust: `utilization_impl.rpt` after WNS ≥ 0.

| Resource | What it is | Used | T200 budget |
|---|---|---:|---:|
| **LUTs** | Logic (AND/OR/mux). One LUT ≈ one 6-input function. | — | 134,600 |
|  as LUTRAM | Tiny memories in LUTs instead of Block RAM. | — | 46,200 |
| **FFs** | 1-bit registers. | — | 269,200 |
| **BRAM** | 36 kb tiles. Dual FB + heap must land here. | — | 365 |
| **DSP** | Multiply/add (DSP48). | — | 740 |
| **Slices** | Place-and-route packing (4 LUTs + 8 FFs each). | — | 33,650 |

---

## Fit verdict

No measured VM bitstream yet. Compare **Used** to the T200 budget above, not
to an I/O bring-up image. Tightest expected row is **BRAM** (paper math ~489
tiles if everything infers). LUTRAM high + BRAM low means inference missed.

---

## Easy mistakes

- **Do not write big on-chip arrays from the VM FSM.** That was the 70 GB
  blow-up. `imgd_pix` / `spr_mem` / `name_mem` / `json_mem` / `stack` /
  `name_hash_tbl` / `varr_len` / `vobj_alloc` / `vvars` must use a
  tiny `if (we) mem[addr] <= data` process (copy `jmr_mini_fb` Port A).
  The FSM only pulses `*_we` / `*_waddr` / `*_wdata`. Isolated `*_rdata`
  reads while the FSM still did `imgd_pix[i] <=` / `spr_mem[spr_wp] <=`
  still hit **71 GB**. After those writes moved out (15:32), synth held
  **~15 GB** after `e32_p_clr` instead of 8→36→70. Heap-table writes
  (`stack_wr` / `vobj_alloc_wr` / …) moved out the same way. Do not put
  `stack[i] <=` back for a title bug. FOREACH el+idx is `stack_dual_pend`
  (one write/clock). `arr_len` / `vobj_cls` still FSM-poked (8-13159) —
  Port A if you touch them.
- **Kill on RSS, not on `e32_p_clr`.** Synth 8-6014 is unused-FF
  housekeeping, not the cone. The 16:17 run **left `e32_p_clr`** and
  finished RTL Optimization Phase 1 (~28.5 GB peak, log still printing).
  Hang = log frozen **and** RSS climbing toward ~80 GB. Tracker:
  `build/nexys_video/synth_rss.log`.
- **Heap-name grep empty ≠ cone.** `spr_mem` is on-chip blit scratch
  (~0.25 MB — **not** the 4 MB ASET bank). `ram_style = "block"` does not
  save an FSM poke.
- **Do not split JOIN/JSON/GC out of `jmr_js_vm.sv`.** Not a task. Maybe
  never. Linear intern find (`S_JOIN_FIND` one slot/clock, “not a 16-CAM”)
  is **play speed**, not the 70 GB hang — see
  [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).
- **`.bin` megabytes ≠ utilization.** The file is the whole 200T config image.
- **Do not copy BASIC LUT history** into this product. Method only.
- **FPGA-SIM green ≠ synthesizable.** Title RUN in Verilator is not a `.bin`.
- **First T200 bit is the slow one.** MIG + full VM synth; later `make -C
  tools/board_flow bit` reuses the project. `bit-fresh` / `clean` = pay first-build
  again. See [FPGA_BRINGUP.md](FPGA_BRINGUP.md).
