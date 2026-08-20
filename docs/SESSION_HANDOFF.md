# Session handoff

## CURRENT STATE — 2026-08-20 later (read this first)

Everything below the horizontal rule is older context; the **rules** and
**failed-fix ledgers** there are still binding, the **title status** in §2
is superseded by this block.

Live bug list + full reasoning: **[potential bugs.md](potential%20bugs.md)**
(IDs up to **#67**). That file, not this one, is the working record.

**Titles, harness-verified on the 2026-08-20 (later) binary — ALL FOUR PLAY:**

| Title | State |
|---|---|
| ASTEROID | **plays** — Enter → PLAY, thrust/fire, vectors draw |
| INVADERS | **plays** — Space starts, full 55-invader wave updates per frame, sprites+HUD draw, Enter safe |
| PACMAN | **plays** — maze/beans/ghosts/score draw every frame, steering works |
| DONKEY | **plays** — Enter enters game, sprites drawn (~60k px), animates, ArrowRight moves (one Enter reaches the game — listener-scoping quirk #60 skips the character-select stop) |

Language-feature pass (same day, after the titles played): **#39 reduce** ·
**#40 slice** · **#41 sort(cmp)** · **#37 textBaseline** implemented;
compiler arrow-comma bug, **#68** (filter/map scan re-entry), **#66b**
(setTimeout slot-scan 2-beat lag; clearTimeout wrong slot), **#60 partial**
(dispatch listener snapshot — DONKEY "Enter twice" correct) fixed. 34/34
probes + all four titles re-verified on the final binary.

Fixed in this later pass: **#58 real cause** (WIN_FILL stale first read) ·
**#61** post-GC alloc clobbers a live slot (THE PACMAN killer) · **#62**
class-method alloc stale kind (THE INVADERS Space fault) · **#63**
event-driven titles halted (DONKEY Enter dead) · **#64** key-event objects
n=0 (e.key undefined) · **#65** BIND stale-vcsp frame leak (DONKEY froze) ·
**#66** setTimeout starvation at 64 · **#67** Image.src fast-path read the
wrong stack slot (DONKEY had no art). Regressions green: probe13 8/8, p58c
5/5, p62/p63/pdonk suites all pass.

**Fixed this run (all probe-verified, lint-clean, in the rebuilt binary):**
**#6** forEach fall-off · **#47** GC roots for the exec nest stack ·
**#14** `.now` ALLOC · **#36** measureText u16 · **#15** tagged w/s/p ·
**#10** exec32 `saved_*` reset · **#49** the parent path renderer had **no
writer at all** (every `arc`/`lineTo`/`fill`/`stroke` painted nothing in
every title) · **#38** quadraticCurveTo · **#51** `S_BLIT` latch ·
**#52** NEW_OBJ prototype link · **#53** `S_HEAP_AWR`/`S_HEAP_FILL` missing
first-entry guard (**every** `push`/`unshift`/`a[i]=` wrote garbage or
nothing) · **#54** four more unguarded direct-entry states (NAMCPY, JSON,
JSON_PARSE, IMGD_GET) + their `hs_ip` · **#55** env-walk slot hint skipped
the prefix · **#56** exec's registered stack write **replayed** and
clobbered parent results (killed `join('')`) · **#57** parent-requested
array promote returned into `S_IDLE` (silent halt).

**The one pattern behind most of it:** a parent state entered *directly by
exec64* needs the canonical first-entry guard
(`if (casestate_q != X) begin hs_st(X); …latch seeds from e64_*_q…;
hs_ip(e64_ip_q); hs_vsp(e64_vsp_q); end`). Without `hs_st` the parent
`state` never advances, so state-gated write-enables never fire; without the
seed copy the arm reads parent FFs nothing wrote; without `hs_ip` the
completion's `hs_code(ops_base + ip)` re-fetches a stale opcode. **Audit any
new `state_n = S_*` in exec64 against this.**

**Open, in priority order:**
1. **#58** — `S_ARR_PROMOTE` copy corrupts a >32-element array's early
   slots. Sole remaining PACMAN blocker (maze data *and* beans data are
   ~33 rows; corrupt beans ⇒ instant win, corrupt maze ⇒ nothing strokes).
   Repro: `JSON.parse` a 33-row array, `VARRPEEK` the promoted long row.
2. **#60** — listeners register globally and `.click()` fires *every* click
   listener. INVADERS Enter → playerName handler → `saveScoreBtn.click()` →
   start button → `animate()` re-entered 3 deep → fault 3 (`fsite=5298`).
   Fix: store target oid in `vlistener`, match on dispatch.
3. DONKEY art — `showTitleScreen()` defers every `drawImage` to
   `Image.onload`; `dihit=0` means drawImage is never reached.
4. **#59** — global `var M = function(){ this.x=… }` + `new M()` loses
   `this` (no title hits it today).

**Debug tooling added to `sim/sim_main.cpp` this run** (use these before
theorising):

| RPC | Gives you |
|---|---|
| `RINGSTOP -1` then `VRING?` | 48-cycle ring, **freezes on fault / running-drop** — the run-up to any halt. Armed automatically at spawn now. |
| `VARRPEEK <aid>` | Value64 array `valid/len/gen/long/lidx` + 8 raw slots |
| `VVARPEEK <slot>` | one Value64 global + valid bit |
| `IDS?` | method-intern id registers + `names_n` |
| `PXCNT?` | `line=` / `circ=` / `rect=` pixel counters — **`line=0 circ=0` means the path walker never ran** |

**Harness trap that cost an hour:** `KEYEVT <code> <down>` parses **decimal**
(`sscanf %u`). Sending `KEYEVT 0d 1` = code 0. The GUI always sent decimal;
only agent probes were affected.

**Flight log now carries fault forensics** (`runtime/sim_backend.py`): a VM
fault logs `VRING` + `PX` lines, and RTL error replies (`?SN`, `?FN`) are
mirrored into the GUI console (they were on the glass but the letterbox
paints from `_typed_log`, which never received them).

---

**2026-08-18 (headless, not an F9).** Live notes. Two topics below (synth vs
glass) — not a required two-agent split. Do **not** tell the user to F9 the
three games yet.

Product: a **standalone NLISC-JS computer** on Nexys Video **T200**.
Not a browser. Not dukpy. FPGA-SIM and the `.bin` are the same `rtl/*.sv`.

Law: `never-fake-fpga-sim`, `one-heap-keep-gen`, `python-first-parity`,
`no-dukpy-cheat-native-cpu`. ABI: [`docs/JMR_JS_COMPATIBILITY.md`](JMR_JS_COMPATIBILITY.md).

**Glass / title debug (INVADERS Space, PACMAN fault 2, DONKEY art) — do
not undo Port A.** Extra clocks OK. No clone heaps. No `leave_hold` in
else. The 7k-line FSM must **not** write these arrays with `mem[i] <=`
(that was the 70 GB synth hang). Use the tasks already in `jmr_js_vm.sv`:
`stack_wr`, `vobj_alloc_wr`, `varr_len_wr`, `name_hash_wr`, `vvars_wr`,
`json_putc`, or `imgd_we`/`spr_we`/`name_we`/`json_we`. One stack write
per clock — FOREACH el then idx is `stack_dual_pend` (do not fire two
`stack_wr` in one cycle). Wait `*_rdata`, never combo-peek BRAM. Do not
extract JOIN/JSON/GC. Do not skip gen. Running `make bit` already ingested
the file at start; further RTL edits are the **next** bit, not the live one.

---

## 1) RTL review / synthesis

**16:17 `make bit` OOM ~03:15 2026-08-19** at **technology mapping**
(RSS 58→114 GB, `tcmalloc` 5.2 GB, 7 workers). No synth DCP — **cannot
resume mapping** (`synth_design` is one step). MIG/project kept. Resume
`make bit` (not `bit-fresh`): synth **2 threads**, impl **8**. First DCP
is synth_1 100% (`post_synth.dcp`). LUTRAM leftovers (`source_mem`,
`vconsts`, `vobj_proto`) — Port A, not `ram_style` + FSM poke:
[FPGA_FIT.md](FPGA_FIT.md#lutram-leftovers-not-the-70-gb-hang). Do **not**
`bit-fresh`. Do **not** kill a live synth to attach checkpoint hooks;
hooks only fire at step end.

**16:17 `make bit` (this VM file):** Port A for pictures (`imgd_pix` /
`spr_mem` / `name_mem` / `json_mem`) **and** heap tables (`stack` 1W2R,
`name_hash_tbl` TOS+NOS, `varr_len`, `vobj_alloc`, `vvars`). This run
**left `e32_p_clr`**, finished RTL Elaboration + Optimization Phase 1
(~11 min, peak ~28.5 GB), log still printing. That is further than every
prior hang (those froze on `e32_p_clr` and never printed again). Fit:
[FPGA_FIT.md](FPGA_FIT.md) (LUT table **and** wall-clock
benchmark — update the phase table when a step finishes). Flatten-hunt vs Port A hang:
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md). Early LUT/BRAM: `utilization_synth.rpt` when
`synth_1` is 100%. Do **not** `bit-fresh`.

**Failed (do not repeat):** named unique-case peek hunts; splitting
**reads** only into `rdata <= mem[raddr]` while the FSM still did
`imgd_pix[i] <=` / `spr_mem[spr_wp] <=` (15:22 synth still hit 71 GB).
`casestate_q`, `unique`→`case`, pulling IEEE mul out of the case — same
wall. `e32_p_clr` 8-6014 is unused-FF housekeeping, not the cone. Synth
8-13159: `vobj_cls` / `arr_len` still dissolved to FFs (FSM still pokes
them). If you touch those, Port A like the others — do not add more
`mem[i] <=`.

**Tracker:** `build/nexys_video/synth_rss.log` (RSS + last runme line
every 10 s). Watch **RSS** and whether the log still prints. Host
**128 GB**. Kill only if the log is frozen **and** RSS is climbing toward
~80 GB. A ~28 GB hold with new phase lines is progress, not the 70 GB
flatten.

Do **not** extract JOIN/JSON/GC. Leave 16-deep FFs (`vst_win`,
`js_val`/`vjs_val`, `cls_*` 16×16, `spr_off`/`spr_ww`/`spr_hh`,
`kd_slot`). `storage_engine` `linebuf` 8-4767 stays. Opcode `always_comb`
locals/`*_n` only (parent sees `*_q`). Inspect both exec32 and exec64
until the ISA cut in [REMOVING_EXEC32.md](REMOVING_EXEC32.md) lands
(do not start that cut in parallel with glass).

---

## 2) FPGA-SIM glass

PYTHON F9 glass is user-confirmed. FPGA-SIM titles are **not** F9-ready.
Do **one** glass step from **Next**. Do not overnight-go.

**SUPERSEDED — see the CURRENT STATE block at the top of this file.** The
numbers in the rest of §2 are from 2026-08-18/19 and describe failures that
are fixed (PACMAN's `NEW_OBJ Game` fault 2; INVADERS' 64M `S_JOIN_FIND`
cap). Kept for the *reasoning*, not the status.

DONKEY's diagnosis here is still accurate: it **parks** `WAIT_FRAME`
`raf=0` because the HTML only re-arms rAF in `gameState=="game"` — that is
correct JS, not an RTL bug.

### What worked (this session)

| Program | Result |
|---|---|
| `constructor(){ this.n = f(); }` | **paints** `nz0=64` `fault=0` |
| `rAF(tick)` fillRect loop | **`WAIT_FRAME raf=1` `nz0=64`** |
| top-level `forEach` then `rAF` | **`WAIT_FRAME raf=1`** |
| `forEach` **inside** `animate` then rAF | **`WAIT_FRAME raf=1`** (was rAF overflow 3) |
| nested `forEach` then rAF | **`WAIT_FRAME raf=1`** |
| `p.update()` class method inside `forEach` then rAF | **`WAIT_FRAME raf=1`** |
| `ctx.fillRect` after `getContext` | **`WAIT_FRAME raf=1` `nz0=800`** |
| INVADERS title | splash `nz=19233` `raf=1`; Space play `obj=732` `fault=0`; no play `WAIT_FRAME` in 64M (`JOIN_FIND`) |
| `{n:1}.missing` then rAF | **`WAIT_FRAME raf=1 fault=0`** (was HEAP_CMP forever) |
| PACMAN title | **fault 2** `vcsp=126` at `NEW_OBJ Game` |
| DONKEY title | `WAIT_FRAME` `raf=0` `nz0=0` `vdraw=0,0,640,479,0` |

Parent-reserve ALLOC (FOREACH / FRAME_RAF / LOOKFN / getter / onload) poked
`hs_vcsp(e64+1)` the cycle **before** ALLOC. Exec had not absorbed it, so
`fr = e64-1` overwrote the caller with `0xfffc` (animate `RET_VAL` fault 2 /
leftover rAF overflow). Fix: if `hs_m_vcsp && vcsp_ff == e64+1`, `fr = e64`.

Exec `ctx_sx`/`ctx_sy` were 0 after rst (`fillRect` clip to 0). Init `FX_ONE`
on rst and `p_clr`. Parent GOT_HDR already did; exec fillRect uses exec FFs.

HEAP_CMP `cls_done` after GET_PROP miss: if no getter/method and proto is
not an object, push undefined and FETCH (do not drop `cls_done` with no
`hs_st` — that restarts `cls_scan`).

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

### Next (glass only)

**Superseded — the ordered queue is in the CURRENT STATE block at the top
(#58, then #60, then DONKEY onload).** The 64M-cap hunt this section
describes is done: no title caps any more. Do **not** add hash→id BRAM
until asked.

**Stop:** overnight-go, `bit-fresh`, host twin, skip gen,
clone heaps, restore local `name_blen[]`, rewrite HTML, delete files,
`leave_hold` held in else, sticky `hs_m_vcsp` over `vcsp_n`,
`stack[i] <=` / `vobj_alloc[i] <=` in the parent FSM.
