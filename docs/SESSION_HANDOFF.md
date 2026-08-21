# Session handoff

## CURRENT STATE — 2026-08-21: V1.0, SYNTHESIS-READY (read this first)

Banner is **V1.0** (RTL + PYTHON + README in parity). The tree is the
one the user synthesizes — see the READY FOR SYNTHESIS block at the top
of [FPGA_FIT.md](FPGA_FIT.md). Landed and smoke-verified on the final
build (all five titles green: DONKEY Mario-stable charsel + game,
PACMAN full game with banks in sync, INVADERS wave, ASTEROID vectors,
MRDO tap→PLAY):

- **exec32 REMOVED** — file deleted (user waiver; git history keeps
  it), instantiation gone, dropped from sim/Makefile and
  vivado_build.tcl, hs32 tied 0, tagged images fault loud at
  S_GOT_HDR2 (fault 9). Verilator eval +16% from the smaller netlist.
  Phase 3b (tagged-arm strip + dead-signal sweep + tagged stack SRAM
  removal) is still TO DO — post-synthesis.
- **Port A'd**: vgc_queue, vconsts, vobj_proto, vfn_proto, vfn_env,
  vfn_bound_this, venv_parent (`*_pa_we/waddr/wdata` strobes, write
  port in the read process, cleared in the FSM default section).
- **Shrinks**: spr_mem 32KB, source_mem 64KB.
- **Suite**: 143+ passing; remaining deltas are documented xfails
  (#70/#71/#72) and the recalibrated DONKEY two-Enter / MRDO-budget /
  PACMAN-wait-helper tests. Test harness uses a scratch card copy
  (JMR_CARD_IMG) — the user's card.img stays clean.
- **Value64 gap fixes this cycle**: #69 rAF snapshot clobber,
  events-then-rAF per frame (dbg_cb_ip per-frame), KEYBITS bridge (+
  real-KEYEVT supersede — the DONKEY Mario→Luigi phantom),
  dispatchEvent + KeyboardEvent desugar, findIndex, join digit-walk,
  ctx.font revive, natural-size drawImage scaling, replace char,
  dynstr indexOf, halt-state sync.
- **MK.HTML parked** (user decision): parses past the shims (unary +,
  for-in via new Object.keys native 41 — PYTHON-only, RTL nid faults
  loud; throw; `in`), blocked on namespaced ctors + Fn.call —
  ~100-150 lines of exec64 when wanted, AFTER synthesis.
- **Synthesis run**: `source scripts/vivado_env.sh` then
  `make -C tools/board_flow bit` (host terminal, not a sandbox; the
  .venv is irrelevant to synthesis). No bit-fresh/clean after a crash.
- **Next after the user's run**: read utilization_synth.rpt,
  fill the FPGA_FIT Headline, then the speed ledger items (FIND step
  2, IMGD_PUT 2→1, GC pacing) and Phase 3b.

---

## How we got here (2026-08-19 → 08-21) — one paragraph

Three days of work, in order: (a) the **glass hunt** — every title-blocking
correctness bug, ending with all five titles playing; (b) the **speed
pass** — INVADERS 18.6M → 10.6M VM clocks/frame via compiler-proved
globals (`a1=1`, no env walk) and verified slot hints on the env walk;
(c) a **user-run triage** round (DONKEY splash flash, PACMAN maze
persistence, MRDO's start key, the LIST stall, the Mario→Luigi phantom
arrow); (d) the **exec32 cut**, which forced ~10 Value64 gaps into the
open and fixed them; (e) the **Port A / fit pass** and V1.0.

Per-bug root causes live in
**[potential bugs.md](potential%20bugs.md)** — that file, not this one, is
the working record, and its
[RECURRING BUG CLASSES](potential%20bugs.md#recurring-bug-classes--read-this-before-debugging-anything)
section is the distilled version of everything above. The dated status
snapshots that used to sit here (title tables from 08-20 morning /
afternoon / evening) were removed on 2026-08-21: they described states the
tree has moved past, and every one of them is superseded by CURRENT STATE.

---


## 1) Synthesis — the rules that survive every run

Run-by-run diaries are in [OLD_RUNS.md](OLD_RUNS.md); the fit census and
the current run instructions are in [FPGA_FIT.md](FPGA_FIT.md). What
matters here is what those runs *taught*, and it has not changed:

1. **`synth_design` is one step.** There is no DCP until synth_1 hits
   **100%**, so a crash during mapping cannot be resumed — the next `make
   bit` redoes synthesis from scratch. Plan runs accordingly.
2. **Never `bit-fresh` or `make clean` after a crash.** It throws away the
   MIG/project state you still need and buys nothing.
3. **Do not raise the worker count** (`JMR_VIVADO_SYNTH_THREADS`, default
   2) or set `JMR_VIVADO_ALLOW_WIDE=1`. The 2026-08-19 16:17 OOM was 7
   workers on a fat netlist; the 08-20 rerun proved 2 workers alone does
   not save a fat netlist either. **The netlist is the variable** — that
   is why exec32 was cut and the LUTRAM monsters were Port A'd.
4. **Do not kill a live synth to attach checkpoint hooks** — hooks only
   fire at step end, so you lose the run and learn nothing.
5. **Watch RSS, not the log spinner.** A run that is still printing and
   holding steady RSS is healthy; the pathological signature is RSS
   climbing through elaboration with no phase transitions.

For scale: the 2026-08-19 16:17 run OOM'd at technology mapping with RSS
58→114 GB. The 2026-08-21 run (post-cut, post-Port-A) cleared RTL
Elaboration in ~12 min at ~29 GB peak and passed constraint validation at
~21 min / ~38 GB, on a 119 GB machine.


## 2) FPGA-SIM glass — lessons only

The status text that used to fill this section (2026-08-18/19 probe
tables, the 64M-cap hunt, per-title failure numbers) was removed on
2026-08-21: all of it is fixed and the current status is the block at the
top. Two things from it are permanent and stay:

**DONKEY parking at `WAIT_FRAME raf=0` on the title screen is CORRECT JS,
not an RTL bug** — the HTML only re-arms rAF once `gameState=="game"`. An
event-driven screen legitimately has no pending animation frame. Do not
"fix" it in silicon; several hours were lost to this once.

**The `.cursor` rules are binding** (`never-fake-fpga-sim`,
`one-heap-keep-gen`, `python-first-parity`, `use-existing-traces`,
`no-dukpy-cheat-native-cpu`, `no-game-hardwire`, `html-game-v1`).


### Failed-fix ledger (do not repeat)

| Tried | Why it came back |
|---|---|
| Skip `vobj_gen` / clone heaps | Forbidden |
| `leave_hold <= (state != EXEC)` in enable=0 else | Deadlock `eip=0` |
| FETCH trampoline taking JUMP while `vctor_takejmp` | field2 width UNDEF |
| Kind-3 `fr = max(e64-1, vcsp_ff)` | Parent leaked to 193; CALL_USER wrote the wrong frame |
| Sticky `hs_m_vcsp` poke always wins over `vcsp_n` | Nested `new` stayed at depth 1 and clobbered Game's frame[0] |
| Delay `hs_m_vcsp` clear until CALL `opnd2` | INVADERS RET 3367 still `ev=0` |
| Wait-beat `vcsp_n = vcsp_hs` including overlay 0 | FOREACH `hs_vcsp(0)` wiped animate |
| Skip `vfn_valid`/`gen` on rAF | Overnight cheat; forbidden |
| **#46** "one timer per frame" (2026-08-19) | **Retracted.** `bind_k` is zeroed by `S_V64_ALLOC`/`S_V64_CTOR_PAD` on every dispatch, so the scan already restarts and all due timers already drain |
| **#50** compiler inliner slot aliasing (2026-08-19) | **Retracted.** RTL env lookup is name-keyed (`hp_key_n`); the a1 slot is only a scan-start hint. Half-vindicated later as **#55** (the hint skipped the prefix) |
| `casestate_q` added to the `vst_raddr` mux for #53 | `casestate_q` lags combo `casestate` by a beat — changed nothing. The real fix was the `hs_st` first-entry guard |
| `hs_ip`/`hs_vsp` on the `S_CONCAT` guard | Unnecessary; reverted. `S_JOIN`'s **is** needed (probe VX2) |

**Keep:** MAKE_FN push `win[1]` + `vst_hold_win`. CALL/CALL_VAL/CALL_METH
**third operand wait**. ALLOC overlay-detect `fr`. Exec identity `ctx_sx`.
Exec `vcsp <= vcsp_n` when the opcode changed depth, raise-only poke when
live. BIND copy from exec **only on IIFE `leave_hold`**. Window `!hs_m_vsp`.
Method-bind GET_PROP sentinel `13'h1FFF`. Do **not** restore `leave_hold`
held in else.

### Do not do these (standing list)

Overnight-go, `bit-fresh` after a mapping crash, the host twin as
FPGA-SIM, skipping gen-match, cloning heaps, restoring a local
`name_blen[]`, rewriting a title's HTML to dodge a VM bug, deleting files
without asking, `leave_hold` held in the enable=0 else, sticky
`hs_m_vcsp` winning over `vcsp_n`, and `stack[i] <=` / `vobj_alloc[i] <=`
anywhere in the parent FSM.
