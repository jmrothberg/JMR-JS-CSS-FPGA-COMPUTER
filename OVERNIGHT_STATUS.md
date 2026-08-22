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
