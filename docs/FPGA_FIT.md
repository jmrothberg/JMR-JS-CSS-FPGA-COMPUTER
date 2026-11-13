# FPGA build: status, limits, how to build

Board: Nexys Video, XC7A200T-1. VM clock 33.333 MHz; fabric and DDR3 100 MHz.
These clocks do not change to make timing.

## Status

| | Bitstream | Timing | Use |
|---|---|---|---|
| Current | `releases/current/jmr_js_mac.bit` (build 99: `build/run99b`, placement `build/run99b/p_ExtraTimingOpt`) with a card made from the current source | met (setup +0.089 ns, hold +0.041 ns); DRC 0 errors; 98,403 LUTs, 354 BRAM, 30,625 slices | Finder-only. This is the bit to load. It has no Toolbox: it needs a card with `TOOLBOX.ROM`. Finder's About shows "Build 99" on a matching card. |
| Previous | build 98, `releases/current/jmr_js_mac.bit` at commit cdb489d (build 97 at d6dbe8e) | met (setup +0.007 ns, hold +0.025 ns) | Roll back to it (with its own card) if build 99 fails on the board. |
| Rollback | `build/run78_clean_architecture/qualification_refined/run78_clean_qualified.bit` with `build/run78_clean_architecture/final_corrected/card.img` | met (setup 0.000 ns, hold +0.027 ns) | An earlier bit that still boots. It shows a command line between programs. Not in git. |

Load a bitstream: `openFPGALoader -b nexysVideo <file.bit>` (add `-f` with JP4 on QSPI to keep it after power-off).

## Known gaps in the current source

1. Timing margin is thin. Build 99 meets setup by +0.089 ns and hold by +0.041 ns with ExtraTimingOpt placement (build 98: +0.007/+0.025, build 97: +0.003/+0.050). The remaining paths are a flat spread of about twenty within 0.1 ns: storage state decode (`dent`/`ent_clus`/`ds_sect` → `state`), console `state_q` enables, framebuffer bank mux → Toolbox `fbq`, `sram_rdata` → Finder FS `result`, VM float multiply pack (`fpm_acc` → `vst_wdata`), VM code-RAM write address.
2. The console state decode is 21–24 logic levels under `AreaOptimized_high` and 12 alone.
3. A 50 MHz VM clock (BUFGCE divide by 2, the only faster synchronous choice) fails by 8.1 ns on about 27,000 VM endpoints after placement; see [NEXT_BUILD.md](NEXT_BUILD.md#not-in-build-98-and-why).

## Release limits

| Check | Limit |
|---|---|
| Setup and hold slack | ≥ 0, no false-path or multicycle waivers added to get there |
| Routing, DRC | complete, 0 errors |
| LUTs / BRAM tiles / slices | ≤ 106,500 / ≤ 365 / ≤ 32,900 |
| Simulator user loop | passes on the same RTL |

## How to build

Cheapest check first. Do not start a step whose predecessor failed.

| Step | Command | Time | Pass |
|---|---|---|---|
| Simulator | `make -C sim sim_server_synth` | 3 min | builds |
| User loop | `python3 sim/user_loop.py` | 20 min | `USER_LOOP_PASS` |
| One module | `vivado -mode batch -source tools/board_flow/ooc_module.tcl -tclargs <module> clk AreaOptimized_high <file.sv>` | 4–10 min | no `DEEP` lines |
| Synthesis | `tools/board_flow/synth_gate.sh runNN` | 50 min | `LIVENESS_PASS`, 0 undriven nets, no `DEPTH` lines |
| Place and route | `vivado -mode batch -source tools/board_flow/implement.tcl -tclargs build/runNN [place directive] [output dir]` | 30 min | `ROUTED_SETUP` and `ROUTED_HOLD` ≥ 0 |
| Repair (only if setup misses by < 0.5 ns) | `vivado -mode batch -source tools/board_flow/refine.tcl -tclargs <output dir>` | 20–40 min | `REFINED_SETUP` and `REFINED_HOLD` ≥ 0 |
| Qualify | `vivado -mode batch -source tools/board_flow/qualify_routed_bit.tcl -tclargs $PWD <routed.dcp or refined.dcp> build/runNN_release <name>` | 3 min | writes `<name>.bit` |

Run `source scripts/vivado_env.sh` first. `make -C tools/board_flow bit` runs synthesis through bitstream in one go; use it only once the staged steps pass.

## Rules that save build time

1. A path with more than about 12 logic levels at 100 MHz will not route. Fix it in the RTL; placement directives do not rescue it.
2. Check a module alone before a full build. It shows the same deep paths in a tenth of the time.
3. No undriven nets. Synthesis treats them as don't-care and may delete live logic; simulation reads zero, so the two disagree. Vivado warning `Synth 8-3848` must be absent.
4. Confirm the mapped VM is whole right after synthesis (`synth_gate.tcl` does this).
5. Register signals that cross between modules.
6. `AreaOptimized_high` saves LUTs and adds logic levels. Measure both before choosing.
7. Smaller RTL is not easier routing. Look at the failing endpoints, not totals.
8. Check that an attribute landed on the mapped cell; do not trust the source line.
9. No blanket `KEEP`/`DONT_TOUCH`, no blind floorplans. The only pblock is the SRAM bridge.
10. An RTL change needs new synthesis. A placement-only experiment reuses `optimized.dcp`: a miss under 0.1 ns is worth one or two other placement directives; a larger miss is an RTL problem.
11. Synthesizing one module as a separate block gives it shallower logic but more LUTs and worse routing. Keep the design flat.
12. A card-only change needs no FPGA build.
13. This Vivado license refuses `report_qor_assessment`, `report_qor_suggestions` and incremental implementation. Use `report_design_analysis`, `report_methodology`, `report_high_fanout_nets`.

RTL coding rules are in [RTL_DESIGN_PRINCIPLES.md](RTL_DESIGN_PRINCIPLES.md).
