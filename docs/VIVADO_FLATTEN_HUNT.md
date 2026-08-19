# History of edits — Vivado 70 GB hunt (~16–19 Aug 2026)

**Not a current-bug list.** Synth compiles. This is a ledger of RTL we
changed while chasing Vivado RSS ~70 GB / frozen log. Use it when glass
is wrong (black, hung FRAME, dead keys, stuck rAF) to see **what we most
likely broke**, not what is “still the hang.”

File: `rtl/engines/jmr_js_vm.sv` (and exec32/exec64 if they were peeked).
FIND play-speed: [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).
Fit: [FPGA_FIT.md](FPGA_FIT.md).

What the hang **was** (fixed): extra SRAM **ports** inferred as FFs, not
chip BRAM, not the 4 MB ASET bank. Last good T200 bit ~2.8 GB.

1. FSM `mem[i] <=` in the 7k-line `always_ff`. Isolated `rdata <= mem[raddr]`
   while those writes stayed still hit ~71 GB. Writes moved to Port A.
2. Later, past `e32_p_clr`: a **third** live index in the mux `always_ff`
   (cstack TOS+NOS+GC, `to_fn[0]` plus another `to_fn` index, `env_cap[0]`
   tap). `e32_p_clr` 8-6014 unused-FF print was not the hang.

---

## Edits that did **not** fix the hang

Tried, then dropped or left as noise. Do not treat as “the synth bug.”

| Edit | Intent |
|---|---|
| Named unique-case peek hunts | combo `mem[f()]` |
| Split **reads** only; FSM still `mem[i] <=` | AR 58025; still ~71 GB |
| `unique case` → `case`, `casestate_q` | decode shape |
| IEEE mul pulled out of the case | mul in case |
| `ram_style = "block"` with FSM poke still there | hint vs inference |
| JOIN / JSON / GC extracted to new modules | **not done** — dual heap |
| Clone `vvars` / `venv_*` / `vobj_*` in exec | **not done** |
| `` `ifdef SYNTHESIS `` smaller heap | **not done** |
| One-cycle BRAM reset-clear | hang class |
| Two `stack_wr` one clock | extra port; used `stack_dual_pend` |
| Re-edit `S_BLIT` / `spr_mem` / `vraf` / mux split | already done; left |
| Global 3rd opcode wait beat | stalled FRAME; **reverted** |

---

## Edits we kept (synth)

Port A (copy `jmr_mini_fb.sv`): FSM pulses `*_we`/`*_waddr`/`*_wdata` only.
Address this clock, `*_rdata` next. One JS heap, gen check stays. One
`stack_wr` per clock. Mux `always_ff` vs unique-case FSM stay split.

16-deep FFs left as FFs (`vst_win`, `js_val`, `cls_*`, `spr_off`, `kd_slot`).
`storage_engine` `linebuf` left. Opcode `always_comb` locals/`*_n` only.

---

## Edits most likely to have broken glass

Legal SRAM / extra clocks / registered copies. If a title misbehaves, check
these first (wrong wait → stale `0`; window not shifted on push/pop).

| Edit | What to check if glass is wrong |
|---|---|
| Every BRAM read now waits a beat | Same-cycle peek → `0` (oid/len/fn) |
| `S_JOIN_FIND` linear intern scan (CAM gone) | FRAME never finishes; `"SCORE "+n` |
| `S_JOIN` / CONCAT / IDXOF three waits | Slow or wrong join/`+`/`indexOf` |
| Timers: one slot per clock | rAF / timeout late or skipped |
| `to_fn0` tap (no combo `to_fn[0]`) | Wrong timer callback |
| cstack 2-deep TOS/NOS window; GC one slot/clock | Call/return/forEach/key/rAF: `ip`/`this`/`env` |
| FOREACH `stack_dual_pend` | El vs idx off-by-one |
| HEAP GET slot wait; object skips long arm | Wrong property |
| `env_cap` raddr + wait (no `[0]` default) | REL_ENV / fresh env recycle |
| CALL 3rd-operand wait (partially reverted) | Stale operand or extra FRAME stall |
| Parent cstack window vs exec `cs1`/`cs2` | rAF after CALL uses stale TOS |

Do not “fix” glass by peeking BRAM or putting `stack[i] <=` back in the FSM.
