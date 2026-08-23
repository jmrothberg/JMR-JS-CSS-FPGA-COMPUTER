# BIGGER PART — porting the tagged netlist off the XC7A200T

> **RULED OUT by the user 2026-08-23 ("we are NOT changing FPGA").**
> Kept as reference only; the T200 fit campaign is the committed path.
> Note the fit campaign also shrinks the future SkyWater-130 ASIC die
> (see CONSTITUTION.md § ASIC target) — a bigger FPGA would have removed
> that pressure and left the ASIC problem unsolved.

Tag: `bigger-part-candidate-207k` (commit 30f5fc6, 2026-08-23).
This netlist is fully verified (150/150 RTL suite x5, 198/198 bytecode,
all three games fault-free) and needs **zero RTL changes** to place on a
larger device. It fails T200 placement only on LUT count.

## What this netlist needs

| resource | this design | XC7A200T (fails) | XC7K325T | XCKU040 |
|---|---:|---:|---:|---:|
| Logic LUTs (post-opt DRC) | 165,989 | 134,600 | 203,800 | 242,400 |
| LUTRAM | 43,324 | 46,200 ✓ | 64,000 | 112,800 |
| BRAM 36Kb tiles | 365 | 365 (exactly full) | 445 | 600 |
| FFs | 32,118 | plenty | plenty | plenty |
| DSP | 158 | ✓ | ✓ | ✓ |

Recommended: **Kintex-7 XC7K325T** (e.g. Genesys 2 board, KC705) — same
7-series primitives, same MIG flow, same XDC dialect.

## Port checklist (half a day)
1. `tools/board_flow/vivado_build.tcl`: part string + board constraints
   file for the new board (pinout: HDMI/DVI out, UART, SD SPI, DDR3).
2. Regenerate MIG for the new board's DDR3 (Genesys 2: DDR3 1800;
   mig_a.prj is board-specific). The SRAM bridge contract (req/ack
   held-until-ack, 2M x 16) is unchanged — only the MIG core swaps.
3. `constraints/nexys_video.xdc` -> new board XDC (clock pin, HDMI TMDS
   pins, SD, UART, buttons).
4. rgb2dvi third-party core works on any 7-series/UltraScale.
5. No RTL edits. `SRAM_INTERNAL(0)` path identical.

## Do NOT lose on the way
- BRAM is exactly 365/365 by construction (pow2-exact chunking); on a
  bigger part the chunk spills (varr_slot_c2, code_mem_c1, fb c2/c3,
  vobj_tmem) can return to BRAM by deleting their `ram_style =
  "distributed"` overrides — frees ~17k LUTRAM if wanted, not required.
- Vivado 2026.1 segfaults on module-scope `(* use_dsp *)` on jmr_js_vm
  and jmr_js_vm_exec64 — do not re-add.
- The T200 shrink campaign (OVERNIGHT_STATUS.md) continues in parallel;
  this document is the insurance path, not the abandonment of T200.
