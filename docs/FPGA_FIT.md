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
The 13 Aug bit below does **not** disprove that: its FB was LUTRAM, not
native 640×480 BRAM. A synth hang (RSS tens of GB, log frozen) is flatten /
FFs, not “needs more LUTs.”

`$readmemh` font lives beside `rtl/engines/jmr_js_vm.sv`. Board asset SRAM is
MIG DDR3 behind `jmr_ddr3_sram_bridge`. Palette BRAM is dual-clock; HDMI game
mode reads it.

---

## Headline (impl, 2026-08-13 03:36, routed)

These counts are the **last published bitstream**, not the 08:49+ RTL (native
640×480 dual FB + card `.JSB` load). Refresh from `utilization_impl.rpt`
after the next WNS≥0 impl before quoting new %. Do not invent counts.

Design: `top_nexys_video` · part: `xc7a200tsbg484-1` · source:
`build/nexys_video/jmr_nexys_video.bin`

| Resource | What it is | Used | T200 budget (XC7A200T) | T200 | T100 budget (XC7A100T) | T100 |
|---|---|---:|---:|---:|---:|---:|
| **LUTs** | Lookup tables — the actual **logic** (AND/OR/mux/small ROM). One LUT ≈ one 6-input function. | **33,639** | 134,600 | **25.0%** | 63,400 | **53.1%** |
|  as logic | Combinational compute (ALU, FSMs, muxes). | 20,895 | 134,600 | 15.5% | 63,400 | 33.0% |
|  as distributed RAM (LUTRAM) | LUTs used as **tiny memories** instead of logic. Mini-FB / work RAM fell back here (synth could not infer BRAM). | **12,744** | 46,200 | 27.6% | ~19,000 | **~67%** |
| **FFs** | Flip-flops — **1-bit registers** that hold state across clocks. | **12,872** | 269,200 | **4.8%** | 126,800 | **10.2%** |
| **BRAM** | Block RAM tiles — dedicated 36 Kb memory blocks (not LUTs). | **2** tiles (1× RAMB36 + 2× RAMB18) | 365 | **0.5%** | 135 | **1.5%** |
| **DSP** | Hard multiply/add blocks (DSP48). | 7 | 740 | 1.0% | 240 | 2.9% |
| **Slices** | Physical **packing boxes** on the die. Each 7-series slice holds 4 LUTs + 8 FFs. Vivado occupies a whole slice even if it only uses part of it, so slice % is usually **higher** than LUT %. Not a thing you write in RTL — it is place-and-route density. | **11,210** | 33,650 | **33.3%** | 15,850 | **70.7%** |

**Read the chart:** LUTs / FFs / BRAM are the real “how big is the design.”
**Slices** are “how many of those 4-LUT boxes did the placer fill.” A design can
be 53% LUTs and ~71% slices on a T100 because packing is never 100% dense, and
LUTRAM can only sit in **SLICEM** boxes (a subset of slices).

---

## Fit verdict

- **T200 (this board):** comfortable. LUTs 25%, slices 33%, FFs/BRAM almost unused.
- **T100 (projection):** counts still fit. Tightest rows are **LUTRAM (~67%)** and
  **slices (~71%)**, not BRAM. A T100 place-and-route could still fail on
  congestion even though LUT/FF/BRAM math looks OK.
- BRAM is almost empty on **this** (03:36) bit because the mini-FB did **not**
  map to block RAM. Morning RTL puts native 640×480 dual FB in BRAM — refresh
  this table after that impl; do not quote these BRAM counts for the new RTL.

---

## Easy mistakes

- **Kill on RSS, not on `e32_p_clr`.** Synth 8-6014 (`e32_p_clr_reg was
  removed`) is unused-FF housekeeping after `top_nexys_video` finishes.
  It is **not** the bug. The hang is Vivado flatten: **RSS tens of GB**
  (08:26: 11→38 GB; 09:43: **69 GB**) while `synth_design` is still 0%.
  8-6014 can still print while RAM explodes — still kill **only** if the
  log is frozen and RSS is still climbing toward ~80 GB on this 128 GB
  host. Do **not** kill at 20 GB (12:50 was too early). Do not restart
  `make bit` until remaining unique-case SRAM reads are `*_rdata`.
- **Heap-name grep empty ≠ cone.** Last hang leftovers were on-chip
  `spr_mem` (blit scratch, ~0.25 MB in the table above — **not** the
  4 MB ASET bank) and `vraf`, not `vobj_*`. Any unpacked `logic foo [0:N-1]`
  with N≳32 and a variable index in the unique case is the same bug.
- **Do not split JOIN/JSON/GC out of `jmr_js_vm.sv`.** Not a task. Maybe
  never. Optional later RTL re-org only if the user asks after legal SRAM
  still cannot synth. Flatten fix is `*_rdata` in the existing unique case.
- **`.bin` megabytes ≠ utilization.** The file is the whole 200T config image.
- **Do not copy BASIC LUT history** into this product. Method only.
- **FPGA-SIM green ≠ synthesizable.** Title RUN in Verilator is not a `.bin`.
  New RTL: unique-case **reads** go through `*_rdata` from the first line
  (`never-fake-fpga-sim` rule 3). Do not grow combo peeks and flatten later.
- **First T200 bit is the slow one.** MIG + full VM synth; later `make -C
  tools/board_flow bit` reuses the project. `bit-fresh` / `clean` = pay first-build
  again. See [FPGA_BRINGUP.md](FPGA_BRINGUP.md).
