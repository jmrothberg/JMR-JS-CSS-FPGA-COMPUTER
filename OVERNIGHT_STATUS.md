# Overnight build status — night of 2026-08-21 → 22

(Agent-written before launching the build; check the tail of this file
and `build/nexys_video/` for the outcome.)

## What was done tonight (all verified in FPGA-SIM before launch)

1. Root cause of the 1.9M LUTs found via `make hier`: the parent FSM held
   ~200k bits of ARRAYS as flip-flops (each FF dragging ~10 LUTs of
   112-state decode), plus the FB silently duplicated per bank (320 tiles).
2. Fixes: v64_on fold restored (tagged twin swept) · mini_fb rewritten
   (true 2-port + exact pow2 chunks → 150 tiles) · vobj/varr/venv/code
   memories pow2-chunked (Vivado pads BRAM to 2^addrwidth — the shrunk
   caps had saved nothing) · vframe family + vobj_cls/builtin + venv_gen
   moved to dedicated write processes (out of the FF explosion).
3. Paper BRAM ≈ 361/365. LUT outcome = tonight's synth verdict.
4. Verified: 198/198 bytecode, PACMAN plays, all five bug repros green,
   full RTL suite as the launch gate.

## If the build FAILED on LUTs
Run `make -C tools/board_flow hier` (5 min) — the residual list is
vobj_len / venv_len / vframe_escaped / scalars; next conversions are
mapped in docs/FPGA_FIT.md.

## If it FAILED on BRAM
The report names the array; paper margin was ~4 so it will be small.

---
## OUTCOME (written 05:05, build still finishing)

**Synthesis completed 04:58 (~5h). The verdict:**

| | Tonight | Last night | Chip |
|---|---:|---:|---:|
| **Block RAM** | **365 (100.00%) — FITS** | 579 | 365 |
| Slice LUTs | 1,196,216 (889%) | 1,901,313 | 134,600 |
| FFs | 123,992 (46%) | 185,510 | 269,200 |

**The BRAM war is WON** — the FB rewrite + pow2-chunking landed exactly
at capacity. The LUT campaign removed ~700k (37%) but ~1.13M logic
remains: ~100k bits of arrays are STILL flip-flop-resident (the census
missed them). Place will fail on LUTs; opt/place complete the run
around 05:30.

A fresh `utilization_hier.rpt` from tonight's checkpoint is being
generated to NAME the remaining arrays — that list is the next tranche
(same proven strobe/chunk recipes). Suite: 148 passed / 2 pre-existing
fails / 3 xfail — zero regressions from the restructuring. All games
verified playing before launch.

## 05:10 — residual LUTs ATTRIBUTED (fresh hier + census on tonight's netlist)

Parent now 1.02M logic / 96k FFs (was 1.72M / 155k). The FF-resident
census against tonight's mapping tables names the residue:

| Array | FF bits | What |
|---|---:|---|
| **gc_queue** | **229,362** | tagged GC queue — the v64_on FOLD DID NOT SWEEP IT |
| consts / vars / tenv_parent / obj_cls / tfn_* / env_oid / obj_n | ~101k | rest of the tagged twin, also still present |
| ROMs (font/sin/pow) + small live arrays | ~30k | cheap, second-order |

The constant fold could not prove the tagged states unreachable (shared
tasks + runtime flags like imgd_v64 keep formal paths in), so ~330k
tagged FF bits × ~9 LUTs ≈ the whole remaining overage.

**MORNING PLAN — one tranche, mechanical:** the real Phase 3b hand-edit
(docs/REMOVING_EXEC32.md): delete gc_queue + the tagged arrays above and
their arms outright. Estimated effect: −700-900k LUTs → at or near the
134,600 target, with the ROM/small-array cleanup as reserve. Synthesis
round-trip is ~5h, so this is a daytime iteration.
