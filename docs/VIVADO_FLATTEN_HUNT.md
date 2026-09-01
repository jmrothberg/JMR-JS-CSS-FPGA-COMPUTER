# History of edits — Vivado 70 GB hunt (~16–19 Aug 2026)

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**Not a current-bug list. Not a third copy of the RAM law** (that is
`.cursor/rules/never-fake-fpga-sim.mdc` + [FPGA_FIT.md](FPGA_FIT.md)
NEVER table). This is the **ledger of RTL we changed** while chasing
Vivado RSS (Resident Set Size) ~70 GB / frozen log. Use it when glass is
wrong (black, hung FRAME, dead keys, stuck `requestAnimationFrame`) to
see **what we most likely broke**, not what is “still the hang.”

**What the hang was (fixed):** extra SRAM **ports** inferred as flip-flops,
not chip **BRAM** (Block RAM). Isolated `rdata <= mem[raddr]` while FSM
writes stayed still hit ~71 GB. Writes moved to **Port A**. Last good T200
bit ~2.8 GB.

File: `rtl/engines/jmr_js_vm.sv` (and exec64). Play-speed:
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md). Fit:
[FPGA_FIT.md](FPGA_FIT.md). Old run diaries: [OLD_RUNS.md](OLD_RUNS.md).

Two beats of the hunt (keep as a lesson):

1. FSM `mem[i] <=` in the big `always_ff`. Isolated `rdata <= mem[raddr]`
   while those writes stayed still hit ~71 GB. Writes moved to Port A.
2. Later, past `e32_p_clr`: a **third** live index in the mux `always_ff`
   (cstack TOS+NOS+GC, `to_fn[0]` plus another `to_fn` index, `env_cap[0]`
   tap). `e32_p_clr` Synth 8-6014 unused-FF print was **not** the hang.

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
