# Session handoff

Words: [README.md — Words used](../README.md#words-used-in-this-project).
**FPGA-SIM** = the chip simulated (Verilator of the same `rtl/*.sv`).
**Glass** = READY, the game, errors. **Fit** = does the design fit the
Nexys Video T200 (365 Block RAM tiles).

This page is **this week’s status** plus the **failed-fix table** (glass
mistakes we must not repeat). Fit numbers and the next bitstream command
live in [FPGA_FIT.md](FPGA_FIT.md). Recurring debug classes live in
[potential bugs.md](potential%20bugs.md). **30 pictures/second on the
board:** [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md). FPGA-SIM
is a slideshow (PC faking the chip); the board should be ~125× faster,
not slower.

Critical “do not”s: two copies only — see
[README.md — Two copies](../README.md#two-copies-of-every-critical-do-not).
This file is **copy 2** of (a) read-`traces/`-first and (b) synth hygiene.

---

## CURRENT STATE — 2026-08-21 (22:29): `bit-fresh` **place failed** (same UTLZ-1 class)

**Ladder / Headline:** [FPGA_FIT.md — Live build ladder](FPGA_FIT.md#live-build-ladder--bit-fresh-2026-08-21--place-failed-2229).
Synth finished (~22:03); place died on **too big for the chip** (LUT
**~1413%**, BRAM **~159%**). Make Error = that failure, not a HEARTBEAT
bug. **Do not** re-run overnight until the still-present `u_core` +
`u_corei_10` double-FB / 1.9M LUT cause is fixed.

Banner **V1.0**. Five titles are **correct** on FPGA-SIM (INVADERS, PACMAN,
DONKEY, ASTEROID, MRDO). **User: FPGA-SIM is too slow to play any of
them.** That is Verilator on a PC (~800k heartbeats/s), not the chip.
The real FPGA is ~100 million heartbeats/s — about **125×** faster than
FPGA-SIM, **not slower**. Play on the PC today = F9 **PYTHON**. Product
speed goal = **≥ 30 pictures/second on the BOARD**. Ordered cuts:
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).

**30 pictures/s at 100 MHz** allows **3.33 million heartbeats per
picture.** The FPGA-SIM wait (your PC faking the chip at ~800k
heartbeats/s) is why F9 FPGA-SIM is a slideshow. **Board pictures/s** is
what HDMI should feel like *before* we cut work (measured 2026-08-20;
remeasure after the fit shrink):

| Title | Heartbeats per picture | Board pictures/s | 30 fps? |
|---|---:|---:|---|
| **INVADERS** | **10.6 million** | **~9** | **No** — needs about **3×** less work |
| **PACMAN** | **3.5 million** | **~29** | **Barely** — treat as must-cut |
| **DONKEY** | **0.71 million** | **~140** | **Yes** on paper |
| **ASTEROID** / **MRDO** | not measured yet | ? | First speed job: measure |

INVADERS is the hard one: most of its picture is JavaScript doing a tiny
`fillRect` per pixel. PACMAN’s cost is garbage collection + maze restore +
string FIND. Do not mix this speed work with `bit-fresh`.

Fit repairs landed. **Live caps** (bisect-proven; do not use the
first-round 768/256 shrink):

| Cap | Live | Why not smaller |
|---|---:|---|
| `MAX_OBJ` (JS objects) | **960** | Attract-mode burst ~330 extra objects; 896 pegged |
| `ENV_DEPTH` (call environments) | **384** | 256 recycled PACMAN’s BFS (breadth-first search) mid-recursion |
| `MAX_ARR_LONG` | **12** | Play peak 2; INVADERS bunkers 4 |
| `CODE_WORDS` | **20480** | High-water ~19,527 on the extended PACMAN image |
| `MAX_SPR` (sprite descriptors) | **16** | Version 1.0 wall; Version 2.0 raises this for `MK.HTML` |

Same numbers in the RTL package, hardware model, and `jsb_format.py`. Full
story + the **live build ladder** (steps 1–11, where / ETA):
[FPGA_FIT.md](FPGA_FIT.md). Automated tests that we leave red on purpose
(#70/#71/#72) are **not** “the games are broken” —
[potential bugs.md](potential%20bugs.md).

**This morning (same day):** synth finished, place failed (LUT 1424% /
BRAM 181%). Diary: [OLD_RUNS.md](OLD_RUNS.md). **Current** work is the
live `bit-fresh` ladder in [FPGA_FIT.md](FPGA_FIT.md), not that place-fail.

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

This is **copy 2** of synth hygiene (copy 1 is the NEVER table in
[FPGA_FIT.md](FPGA_FIT.md); run diary [OLD_RUNS.md](OLD_RUNS.md)).

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
