# Session handoff

Words: [README.md — Words used](../README.md#words-used-in-this-project).
**FPGA-SIM** = the chip simulated (Verilator of the same `rtl/*.sv`).
**Glass** = READY, the game, errors. **Fit** = does the design fit the
Nexys Video T200 (365 Block RAM tiles).

This page is **this week’s status** plus the **failed-fix table** (glass
mistakes we must not repeat). Fit numbers: [FPGA_FIT.md](FPGA_FIT.md).
Recurring debug classes: [potential bugs.md](potential%20bugs.md).
**30 pictures/second on the board:** [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).

Critical “do not”s: two copies only — see
[README.md — Two copies](../README.md#two-copies-of-every-critical-do-not).
This file is **copy 2** of read-`traces/`-first and **copy 1** of synth
hygiene (copy 2 of hygiene: [FPGA_FIT.md](FPGA_FIT.md) NEVER +
[OLD_RUNS.md](OLD_RUNS.md) taxonomy).

---

## CURRENT STATE

Live numbers: [FPGA_FIT.md](FPGA_FIT.md) SCOREBOARD. Clock hedge:
[FPGA_FIT.md — If timing fails](FPGA_FIT.md#if-timing-fails-wns--0--slow-the-js-core-not-ddr3).
Board fps plan: [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).
exec32: [REMOVING_EXEC32.md](REMOVING_EXEC32.md).

Caps: [FPGA_FIT.md](FPGA_FIT.md) paper budget. Three tests are **xfail**
(#70/#71/#72) — not “the games are broken”:
[potential bugs.md](potential%20bugs.md).

---

## How we got here (2026-08-19 → 08-21) — one paragraph

Three days, in order: (a) the **glass hunt** — every title-blocking
correctness bug, ending with all five titles playing; (b) a **speed
pass** that cut how many chip heartbeats INVADERS needed for one picture
(18.6 million → 10.6 million) via compiler-proved globals; (c) user-run
triage (DONKEY splash, PACMAN maze, MRDO start key, LIST stall,
Mario→Luigi phantom arrow); (d) the **exec32 cut**, which forced Value64
gaps into the open; (e) the **Port A / fit pass** and V1.0.

Per-bug root causes: **[potential bugs.md](potential%20bugs.md)**. Start at
[RECURRING BUG CLASSES](potential%20bugs.md#recurring-bug-classes--read-this-before-debugging-anything).

---

## 1) Synthesis — the rules that survive every run

This is **copy 1** of synth hygiene (copy 2 is the NEVER table in
[FPGA_FIT.md](FPGA_FIT.md); failure taxonomy [OLD_RUNS.md](OLD_RUNS.md)).

1. **`synth_design` is one step.** There is no **DCP** (Design CheckPoint)
   until `synth_1` hits **100%**. A crash during mapping cannot be resumed —
   the next `make bit` redoes synthesis from scratch.
2. **`bit-fresh` has two opposite meanings.** After a **mid-run crash**:
   never `bit-fresh` / `make clean` — that throws away MIG (Memory Interface
   Generator) / project state you still need. After a **source file-list
   change** (exec32 deleted, or the incremental stitch duplicated the
   framebuffer): `bit-fresh` **is** required, once. That is the 2026-08-21
   next build.
3. **Do not raise the worker count** (`JMR_VIVADO_SYNTH_THREADS`, default
   2) or set `JMR_VIVADO_ALLOW_WIDE=1`. The 2026-08-19 16:17 **OOM** (Out
   Of Memory) was 7 workers on a fat netlist; 08-20 proved 2 workers alone
   does not save a fat netlist either. **The netlist is the variable.**
4. **Do not kill a live synth to attach checkpoint hooks** — hooks only
   fire at step end, so you lose the run and learn nothing.
5. **Watch RSS** (Resident Set Size — how much RAM Vivado is using), not
   the log spinner. Healthy: still printing, RSS holding. Pathological:
   RSS climbing through elaboration with no phase transitions.
6. **`AUTO_INCREMENTAL_CHECKPOINT` stays 0** while RTL is changing. The
   04:11 netlist stitched against a pre-exec32-delete checkpoint and
   **drew the framebuffer twice**. Place cannot fix a garbage netlist.

For scale: 2026-08-19 16:17 OOM’d at technology mapping (RSS 58→114 GB).
The 2026-08-21 V1.0 run **finished synth** then **failed place** — see
[FPGA_FIT.md](FPGA_FIT.md).

---

## 2) FPGA-SIM glass — lessons only

**DONKEY parking at `WAIT_FRAME raf=0` on the title screen is CORRECT JS,
not an RTL bug** — the HTML only re-arms `requestAnimationFrame` once
`gameState=="game"`. An event-driven screen legitimately has no pending
animation frame. Do not “fix” it in silicon; several hours were lost to
this once.

Read `traces/` first (copy 2; copy 1 is `.cursor/rules/use-existing-traces.mdc`).
Newest `traces/*_FPGA-SIM.log`: start at the **end** (fault / trap / typed
lines), then the micro-op tail.

### Failed-fix ledger (do not repeat)

These are **specific** glass mistakes, not a third copy of the Port A law.

| Tried | Why it came back |
|---|---|
| Skip `vobj_gen` / clone heaps | Forbidden — [one-heap-keep-gen](../.cursor/rules/one-heap-keep-gen.mdc) |
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

### V1.5 board bring-up handoff (2026-09-01)

EDIT/COMPILE/RUN is LIVE on glass (run-67 bit + the instrumented card).
Cross-lane facts every session needs:

- **storage/COMPILER.HTML + ARTSCAN.HTML now carry `MSG_OFF = 128`** (was
  0 — the console prints from CSTG_HDR_MSG=128; every ?CE was mute since
  birth). Keep 128 in any new chain program.
- **COMPILER.HTML sanitizes the art flag** (`hasArt = (flag === 1)`) and
  guards `artNspr()` ≤ 64 + all `_gw` writes (`dgFail` prints ASCII
  numbers through ?CE). Reason: on the BOARD the arena flag byte (65) read
  back garbage for a no-art title and the art-append path ran a copy off
  the arena end — the long fault-5-at-ip-23 hunt. ROOT CAUSE STILL OPEN
  (console SRAM write → VM read via the DDR3 bridge; sim-invisible).
  Run 68's G-line ({fsite, fault_arg} per fault) is armed for it.
- The CSTG arena is **380,928 words** (CSCR 73,728 + CIMG 307,200, one
  flat byte space). PAL_OFF ≈ 137K is normal.
- The editor is a GAME (running=1 while editing); F2 save prints SAVED.;
  the delete verb is REMOVE. GUI forwards F-keys to titles; F12 = leave.

### RUN 69 BUG LIST (2026-09-01 — collected, NOT started; user gate)

RTL candidates, in priority order:
1. **VM f64 MUL loses the mantissa at ~2^52-scale operands** — root of the
   w64 constant collapse (0.64->0.5, 640->512). Compiler sidesteps it now;
   the VM corner remains. Needs: FM≡HM extreme-magnitude MUL/MOD/DIV tests,
   then the RTL fix or a documented precision envelope.
2. **Art-flag byte misread** (console SRAM write -> VM read via the DDR3
   bridge; board-only, sim-invisible). Shielded by content sanitation;
   R68's G-line reports {fsite, arg} when it next fires — root-cause then.
3. **Post-exit console drain eats fast typed input** (the type-COMPILE-
   twice effect). Drain should swallow only the terminating key, not a
   time window.
4. Minor: ?CE VM-stopped exit can stream a stale message area; audit
   cmp_msglen handling on the no-cdone path.
5. **`drawImage` dest `clip_u` drops source (2026-09-02).** PYTHON/Chrome
   keep a negative dest origin and skip OOB pixels (source follows the
   full rect). exec64 `clip_u` forces dest x/y to 0 and still DDA from
   source 0 — a billboard with `dx<0` smears the left of the sheet onto
   `x=0` (PYTHON/Chrome clean; FPGA-SIM/BOARD only). `clip_u` was the
   fillRect no-wrap fix (`jmr_js_vm.sv` “no wrap — sparse BOARD bug”);
   blit needs the **visible intersection**: crop `blit_sx/sy/sw/sh` by
   the discarded dest, then clamp. Raster `inb` already skips +overflow.
   Do not rewrite a title to dodge this (standing list).
6. **SAVE-as drops the .ART sidecar** (user 2026-09-01: "we don't want to
   go back to the host"). DESIGN CHOSEN: the HTML declares its art bank —
   `<script data-art="INVF.ART">` beside the sprite shim. ARTSCAN reads it,
   writes the name to the arena NAME_BUF area, cdone(0x86 = "stage this
   named art, then chain to PROGSEL"); the console reuses the mint-as
   name path (jsb_name_src=2) into the existing C_ART_OPEN..C_ART_FLAG
   staging, then loads COMPILER. No declaration → today's by-title-name
   staging (backward compatible). Forks share one art bank, no copies,
   reboot-safe. Host mint (make_sd_image, peer lane) must honor the same
   declaration so host and machine mints agree. Copy-on-save rejected:
   duplicates 100KB+ per fork, single-channel storage makes it awkward.

Content/toolchain (not run-gated, mostly peer lane):
- window.open-class browser APIs now stub to 33 in the on-machine compiler
  (574bbb4) — extend natInit as real needs appear.
- Inline-art titles: migrate remaining data-URI titles to .ARTX; that (not
  removing the LIST squash) is what makes every title compile unhacked —
  ARTSCAN refuses inline art regardless of squash.
- On-machine compiler fixes 2026-09-01 night (all in storage/COMPILER.HTML,
  minted): typeof via interned name (not raw 40), window.* unknown APIs →
  stub 33, CALL_VAL argc in arg0, MAKE_FN IIFE bit6. Found by diffing the
  machine-minted .JSH against the host mint at raw-operand level; the
  CALL_VAL bug reproduced in sim as fault 4 at Enter (keydown dispatcher).
