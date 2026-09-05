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

### RUN 71 — IMPLEMENTED 2026-09-05 (tree ready; synthesis waits for the user)

Scope chosen by the user: transfer checking, no lock-ups, STATUS, cheap
language gaps, load-speed instrument; congestion-neutral, no clock change,
capacity growth dropped (the "15 dead BRAM tiles" premise was wrong: the
tag twins and json_mem are live in v64; only tenv_parent is dead).

- **0 editor retirement**: the 23 `C_EDIT_*` inline numbered-line states are
  gone (console 128/128 -> 105/128 before this run's +4). `EDIT n` and typed
  numbered lines answer ?SN; EDITOR.JSH is the editor.
- **A CRC-32 on 0xFC/0xFD**: frame = tag, u32 len, payload, crc32 LE.
  uart_link JSH_C0..C3 verify; mismatch -> `?CK` (reply row 16; reply_sel
  now 5 bits) and the stream is discarded (SOURCE emptied / program not
  started). board_backend appends zlib.crc32 and resends x3 on ?CK. Sim:
  `TETHER_CRCERR 1` injects the flag. Board-side 0xFD path is board-only
  (sim JSHLOAD bypasses the tether).
- **B SD watchdog**: S_SD_WAIT times out (~1.3 s), aborts the SPI master
  (new `abort` input), poisons the mount, answers ?IO. Sim: `SD_HANG 1`.
- **G STATUS**: `NAME <t> LEN <n> [TRUNC] HTML|JS|-- FAULT <site> <arg>`
  (2 console states reusing the LOADED/LIST printers; vm_gdbg -> console).
- **F language-lite**: natives 55 isFinite, 56 isNaN, 57 Math.ceil; alias
  performance.now = Date.now; host compiler desugars a.includes(v) to
  !(a.indexOf(v) < 0). PEER LANE TODO: the on-machine COMPILER.HTML has the
  natInit rows (done here) but still needs the `.includes(` desugar in its
  method-call path (emit indexOf + LOADC 0 + LT + NOT) to match the host.
  e.code and Array.shift/unshift were left out (event construction / RTL
  array ops — run 72 candidates).
- **C instrument**: E line is now `Exxyyzzzz` (zzzz = storage op duration
  x256 clk); flight log prints `op_ms=`. Burst loads NOT built — measure
  first per the approved plan.
- **H**: [Errno 5] on a tether write reopens the USB port once and retries.
- Banner `V2.0 R71`. Gates: CRC put, SD hang, STATUS, natives checksum
  (all pass); full battery on the final binary pending at write time.

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

6. **Big-file put — DONE in run 71 as tag 0xFB** (user 2026-09-04/05: ".artx
   files ALSO, and they are big"). F8's 0xFC put fills the 64 KB SOURCE
   window, so .ART banks over 64 KB (MKBA/MKCA 2.8 MB, DNKF 1.66 MB) were
   skipped "?TR (SOURCE 64K)". Now `runtime/board_backend.py` routes any
   file > SOURCE_MAX through 0xFB: same framing as 0xFC (tag, u32 LE
   length, payload, CRC-32 trailer), `jmr_uart_link` raises
   `jsb_tether_big`, the console stages the bytes into the CART bank
   packed 2 B/word (`C_BIG_TETHER`/`C_BIG_WR`, +2 encodings → 111/128),
   and the typed `SAVE "NAME.ART"` pumps CART to the card through the
   mint's art-append loop (cmp_save_mode + cmp_art_mode with img_len 0,
   reply SAVED). Bad CRC → `?CK`, nothing staged, host resends ×3;
   over 2,961,408 B → SAVE says `?TR`. Sim rpc `BIGFILE <path>`; gates in
   tests/test_console_log.py (roundtrip byte-exact, ?CK-then-recover).
   **Bug found on the way:** the console's bank-1 SRAM client wrote every
   word as `{8'd0, byte}`, so the on-machine art stager (C_ART_GBW) held
   each low byte in `art_word` and never wrote it — an art title compiled
   ON THE MACHINE got a payload with every even byte zeroed (never seen on
   glass because no art title had been board-compiled yet; INV2 said NO
   ART first). Fixed with `src_w16`/`src_wlo` (16-bit write when set);
   the big-put roundtrip gate exercises the same write and append paths.

7. **storage_engine S_SD_WAIT has no watchdog** (board 2026-09-05): a SAVE
   of a 5.5 KB .JSH sat in state 0x09 (waiting on sd_ack) for ~85 s, then
   completed; a following DIR wedged the same way until power-cycle. The
   engine must time out a stuck SD transaction (deselect, re-init at
   INIT_DIV, report ?IO) instead of waiting forever. Card health/seating is
   the likely trigger, the wedge is ours. DONE in run 71 (item B): 27-bit
   watchdog in S_SD_WAIT (~1.3 s) → S_SD_ABORT deselects, the SPI master
   idles, the console gets ?IO; sim rpc `SD_HANG`, gate
   test_rtl_sd_hang_reports_io_and_recovers.

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
