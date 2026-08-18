# Session handoff

**2026-08-18 (headless, not an F9).** Live notes. Two topics below (synth vs
glass) — not a required two-agent split. Do **not** tell the user to F9 the
three games yet.

Product: a **standalone NLISC-JS computer** on Nexys Video **T200**.
Not a browser. Not dukpy. FPGA-SIM and the `.bin` are the same `rtl/*.sv`.

Law: `never-fake-fpga-sim`, `one-heap-keep-gen`, `python-first-parity`,
`no-dukpy-cheat-native-cpu`. ABI: [`docs/JMR_JS_COMPATIBILITY.md`](JMR_JS_COMPATIBILITY.md).

**Any RTL edit** (glass, HEAP, exec, new opcode): extra clocks OK. No clone
heaps. No `leave_hold` in else. Large on-chip arrays (`imgd_pix`, `spr_mem`,
`name_mem`, `json_mem`, and anything else MB-class) write only through
`*_we` / `*_waddr` / `*_wdata` into a tiny `if (we) mem[addr] <= data`
process — same as `jmr_mini_fb`. Do **not** poke `mem[i] <=` from the
parent FSM. Isolated `*_rdata` reads with FSM writes still left in blew
~70 GB. Do not mix a title-bug hunt into a flatten pass.

---

## 1) RTL review / synthesis

**What stopped the 70 GB blow-up (2026-08-18 15:32):** the FSM must **not**
poke the big on-chip pictures. `imgd_pix` (307200×8), `spr_mem` (256K×8),
`name_mem` (32K), `json_mem` (8K) now write only in a tiny
`if (we) mem[addr] <= data` process (copy `jmr_mini_fb` / `jmr_video_vram`
Port A). The 7k-line `always_ff` sets `imgd_we` / `spr_we` / `name_we` /
`json_we` + waddr/wdata. After `e32_p_clr` this run held **~15 GB** + one
busy core (old curve was 8→36→70 GB in minutes). Fit: [FPGA_FIT.md](FPGA_FIT.md).
Do **not** `bit-fresh`.

**Failed (do not repeat):** named unique-case peek hunts; splitting **reads**
only into `rdata <= mem[raddr]` while the FSM still did `imgd_pix[i] <=` /
`spr_mem[spr_wp] <=` (15:22 synth still hit 71 GB). `casestate_q`,
`unique`→`case`, pulling IEEE mul out of the case — same wall. `e32_p_clr`
8-6014 is unused-FF housekeeping, not the cone.

**Tracker:** `build/nexys_video/synth_rss.log` (RSS + last runme line every
10 s). The log stays on `e32_p_clr` during RAM infer; watch **RSS**, not a
new print. Host **128 GB**. Kill only if log frozen **and** RSS climbing
toward ~80 GB. Do not kill a ~15 GB hold with a busy core.

Do **not** touch: glass, `leave_hold`, `keep_hierarchy`, `storage_engine`
`linebuf` 8-4767, clone heaps. Do **not** extract JOIN/JSON/GC. Leave
16-deep FFs (`vst_win`, `js_val`/`vjs_val`, `cls_*` 16×16,
`spr_off`/`spr_ww`/`spr_hh`, `kd_slot`).

Opcode `always_comb` locals/`*_n` only (parent sees `*_q`). Inspect both
exec32 and exec64.

---

## 2) FPGA-SIM glass

PYTHON F9 glass is user-confirmed. FPGA-SIM titles are **not** F9-ready.
Do **one** glass step from **Next**. Do not overnight-go.

Re-ran headless on sim binary **12:46** (after §1 `vraf_rdata` / blit /
imgd / sin / txt_buf waits). Prior §2 numbers are stale.

INVADERS splash **paints** (`nz0=19233` `vdraw=70,68,500,7` `fault=0`
`raf=0` `WAIT_FRAME`). Enter arms HEAP (`hp_cmd=5`). **Space → fault 3**
`S_IDLE` `eip=5127` `addEventListener` `vcsp=4`
`vret=65533,5081,3362,2641` `obj=142` `arr=31`. Not a no-op.

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
| INVADERS title | splash `nz=19233` `raf=0`; **Space fault 3** at `addEventListener` |
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

1. **INVADERS Space fault 3** `eip=5127` `addEventListener` after splash
   (`raf=0` at `WAIT_FRAME`, then key HEAP). `vret=65533,5081,3362,2641`.
   Prove ALLOC/listener vs heap cap. Do not skip gen.
2. **PACMAN fault 2** `vcsp=126` cycling `vret=16318,13488,13138`
   (`POP` after top IIFE / createStage IIFE / `LET_VAR stage`). First
   TICKN already nested at `S_JOIN_FIND ip=1877`. Prove nested CALL_VAL
   / createStage vs ALLOC overlay. Do not skip gen. Do not rewrite HTML.
3. **DONKEY title art.** HTML does **not** re-arm rAF on the title branch.
   `showTitleScreen`: `clearRect` + `Image` data-URI `onload` `drawImage` +
   `fillText` at y=500/600 in world space after `setTransform`. Headless
   `nz=0` is the black clear; onload/drawImage/fillText must land on 640×480.
4. Only then F9 FPGA-SIM `(RTL)` on the three games.

**Stop:** overnight-go, `make bit` / `bit-fresh`, host twin, skip gen,
clone heaps, restore local `name_blen[]`, rewrite HTML, delete files,
`leave_hold` held in else, sticky `hs_m_vcsp` over `vcsp_n`.
