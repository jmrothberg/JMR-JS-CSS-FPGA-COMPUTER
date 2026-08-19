# Session handoff

**2026-08-18 snippet ladder (agent runs it, not F9).** fillRect no
longer needs `obj_ok` (computed args shifted the canvas out of the TOS
window). GET_PROP `.length` / ARR_GET intern wait one extra beat for
Port A `name_blen`/`varr_len`. Global 3rd opcode beat reverted (stalled
FRAME). Rebuild + pytest snippets next. Do not `make bit`.

**2026-08-18 HEAP slot pipeline** in `rtl/engines/jmr_js_vm.sv`
(`hp_slot_pend`, object GET skips the array-long arm). Still Port A. Do
not `make bit`. FIND last-4 cache already landed; play `FRAME` was still
`FB SAME` before this HEAP change — prove INVADERS Space → play
`WAIT_FRAME` / `FRAME` dump.

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
locals/`*_n` only (parent sees `*_q`). Inspect both exec32 and exec64.

---

## 2) FPGA-SIM glass

PYTHON F9 glass is user-confirmed. FPGA-SIM titles are **not** F9-ready.
Do **one** glass step from **Next**. Do not overnight-go.

Re-ran headless on sim binary **12:46** (after §1 `vraf_rdata` / blit /
imgd / sin / txt_buf waits). Prior §2 numbers are stale.

INVADERS splash **paints** (`nz0=19233` `fault=0` `raf=1` `WAIT_FRAME`
`eip=3367`). **Space (32) starts play** (`obj=732` `fault=0`, HUD
CONCAT / `player.update`). Play `animate()` does **not** return to
`WAIT_FRAME` inside a `FRAME` (64M) — `S_JOIN_FIND` intern scan. Enter
is not Start. Agent recipe:
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md) (START HERE).

PACMAN first TICKN `S_JOIN_FIND ip=1877` `vcsp=76` cycling
`vret=16318,13488,13138`. Then **fault 2** `S_IDLE` `vcsp=126`
`eip=13133` `NEW_OBJ Game`. Not HEAP_CMP.

DONKEY **parks** `WAIT_FRAME` `raf=0` `ip=3630` (`update` `RET_VAL` after
`showTitleScreen`). 8× `FRAME`: `nz0=0` `vdraw=0,0,640,479,0`. HTML: rAF
only in `gameState=="game"`.

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

**Keep:** MAKE_FN push `win[1]` + `vst_hold_win`. CALL/CALL_VAL/CALL_METH
**third operand wait**. ALLOC overlay-detect `fr`. Exec identity `ctx_sx`.
Exec `vcsp <= vcsp_n` when the opcode changed depth, raise-only poke when
live. BIND copy from exec **only on IIFE `leave_hold`**. Window `!hs_m_vsp`.
Method-bind GET_PROP sentinel `13'h1FFF`. Do **not** restore `leave_hold`
held in else.

### Next (glass only)

1. **FIND last-4 is in** (`S_JOIN_FIND` FFs, Port A). Splash + Space
   play start still good. First play `FRAME` still caps at 64M
   (`FB SAME`) but sampled state is **`S_V64_EXEC` eip=4504**, not
   `S_JOIN_FIND`. Do **not** add hash→id BRAM until asked. Next glass
   step is whatever still burns 64M in exec/draw — not another FIND
   CAM. Details: [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).

**Stop:** overnight-go, `bit-fresh`, host twin, skip gen,
clone heaps, restore local `name_blen[]`, rewrite HTML, delete files,
`leave_hold` held in else, sticky `hs_m_vcsp` over `vcsp_n`,
`stack[i] <=` / `vobj_alloc[i] <=` in the parent FSM.
