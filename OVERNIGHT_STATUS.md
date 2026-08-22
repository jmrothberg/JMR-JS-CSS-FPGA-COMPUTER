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

---
## DONE 05:05 — Phase 3b hand-delete landed

All **64 tagged write sites deleted** and the tagged stack task neutered.
Verified in source: `gc_queue` / `consts` / `vars` / `var_tag` /
`tenv_parent` / `obj_cls` / `obj_n` / `env_oid` now have **zero** write
sites; `stack` / `stack_tag` keep their Port-A processes but both write
enables are constant 0 (`stack_we` is only ever assigned `1'b0`,
`e32_stack_we` has no driver). The arrays are **writerless**, so
synthesis can sweep them for real — which the `v64_on` fold could not.
Projected **−800k to −1M LUTs**.

The Verilator binary (`sim/sim_build_synth/jmr_js_sim_server`, 05:05:47)
is newer than `rtl/engines/jmr_js_vm.sv` (05:05:29) with no `.sv` newer
than it, so the post-delete battery really did test the edited RTL.

**The confirming ~5h synth has NOT been run.** Until it does, −800k-1M is
a projection, not a result.

## Suite status corrected 2026-08-22 (morning)

The "148 passed / 2 pre-existing fails" line above undercounts the good
news: **both of those failures were bad tests, not chip defects.** Each
was run and diagnosed:

- `test_donkey_fpga_sim_enter_keeps_raf` — asserted the framebuffer
  changed within 8 frames; DONKEY's game screen moves sub-pixel per
  frame (first change at frame 31). It had been passing on the FB
  bank-mismatch that `S_FB_SYNC` fixed on 08-20. Now asserts per-frame
  work (`fclk`) instead. **Fixed and passing.**
- `test_pacman_fpga_sim_enter_paints_maze` — asserted `raf != 0` on a
  VMSTAT sampled at a random mid-frame instant, because
  `_wait_vm_idle_or_frame` times out on a title whose attract mode never
  rests. The snapshot it failed on read `fault=0`, `rafcall=99`,
  `obj=829` — a healthy machine mid-`drawImage`. Helper now lands on a
  frame boundary (`S_WAIT_FRAME`) before sampling.

PACMAN itself is healthy: the user's live session reached **rafcall 210,
fault=0 throughout, obj peaking at 872 of 960**, objects sawtoothing (so
GC reclaims). Detail: [docs/potential bugs.md](docs/potential%20bugs.md) #79.
