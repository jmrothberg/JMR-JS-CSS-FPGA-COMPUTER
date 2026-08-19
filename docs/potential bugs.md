# Potential bugs — FPGA-SIM play RTL (code review)

Inspection of the play path: `rtl/engines/jmr_js_vm.sv` (parent FSM),
`jmr_js_vm_exec64.sv`, `jmr_js_vm_exec32.sv`, `sim/sim_main.cpp`, vs
`hardware_model/js_vm.py`, plus `storage/*.HTML`. No FPGA-SIM rerun.

Re-checked 2026-08-19 against the dirty tree (`jmr_js_vm.sv` +11,
`jmr_js_vm_exec64.sv` +10, `sim/sim_main.cpp` present-exit). **Fix check**
is whether the idea in the last column is still legal and still the right
first patch — not whether anyone has typed it.

A title “freezes” when: FRAME burns 64M (`FB SAME`), `fault` drops `running`,
rAF is not re-armed, paint stops changing, **or a frame takes so many clocks
it looks hung** (graphics / intern).

**Fix rules:** Port A SRAM (never `mem[i] <=` in the 7k FSM). Extra clocks are
legal; a path can still be **slow** — speed it up without breaking wait/`*_rdata`
or synth. Keep gen. One heap. No title name as a gate. Do not raise the 64M
FRAME cap.

Status: **open** = still in RTL. **partial** = attempted or narrowed, still
wrong. **corrected** = gone. **slow** = works, costs clocks; faster is fine if
SRAM and synth stay legal.

---

## Correctness bugs

| ID | Status | Fix check | Where | Bug | Why it freezes | Best fix |
|---|---|---|---|---|---|---|
| **1** | open | **keep** — hash→id BRAM + **byte** confirm. Last-4 stays. Not a CAM. **Do not expect this alone to stop 64M** — a miss is `2*names_n` clocks (≤2k), not 64M. | `S_JOIN_FIND` ~7790 | Linear walk, 2 clk/slot. Last-4 is hash+`jn_len` (u8). `"SCORE "+n` misses last-4 when `n` changes. | HUD slowness + hash collision (**2**). The 64M RPC hang is **5/31** (or a real spin). | Hash→id BRAM, then stream `name_mem` vs `txt_buf`. |
| **2** | open | **keep** — pair with 1. Compare **bytes**, not hash+u8. `jn_len` is already u8 (`TXT_MAX=64`); `name_blen` u16 is for GET_PROP `.length` / measureText (**36**). | FIND hit ~7837 | Match is `name_hash_rdata == jn_h && e32_name_len_tos == jn_len`. No `name_mem` bytes. 16-bit hash × 1024 names will collide. | Wrong intern id → EQ/keys lie. Not a 64M spin by itself. | Stream `name_mem[off+k]` vs `txt_buf[k]`. |
| **3** | open | **keep** — intern small ints without a slot; never alloc with `cc_bok=0`. | FIND alloc ~7868 | Intern never GC’d. Cap 1024 → undefined. Overflow intern without bytes. | HUD/`[key]` die after unique strings fill. | Small-int intern; refuse `cc_bok=0`. |
| **4** | open | **keep** but **not first** — PACMAN `code.join('')` of 0/1 already works. | `S_JOIN` ~7691 | Only folds digits 0–9. Python ToString-joins any elem. | Non-digit join → undefined map. | Fold elems through CONCAT/`txt_buf` (same FIND). |
| **5** | **partial** | **revise** — host present-exit is the right idea; do **not** stop at `dbg_cb_ip <= snap[15:0]`. Require **back in `S_WAIT_FRAME`** (after GC), or leftover GC runs on the next RPC (usually OK) / nid-3 mid-rAF can end the frame early (**31**). `dbg_cb_ip <= 16'h1` is only a skip-draw fallback. Copy `e32_dbg_cb_ip_q` if tagged titles still use that path. | `sim/sim_main.cpp` ~1858–1914; parent ~13660 | Host used to need `cbip != 0`. Agent latched `vraf_snap[i][15:0]` (oid **0** still 0). Host now also ends when `dbg_swap_n != swap0` after `left_wait`. Value64 presents at `S_V64_FRAME_TIMER` if `fb_dirty` (~13741). | Painted frames can finish. FIND-bound frames never present → still 64M (**1**). Skip-draw (no `fb_dirty`) still needs cbip or idle 2000. | Gate present-exit on `st == WAIT_FRAME`. Keep idle 2000 for no-rAF splash. |
| **6** | open | **keep** — delete the **first** `0xfffc` arm only (the `GC_CLEAR` one). Do **not** delete the later arm (~3263) or parent FOREACH done (~11327), which already pops a leftover `0xfffc` whose `bsp` matches `vfe_base+2`. | exec64 implicit RET ~3206 | Fall off `n_ops` with `rip==0xfffc` → `GC_CLEAR` **before** the FOREACH arm. | PACMAN `maps.forEach`: walk dies; leftover rAF → fault 3. | Fall through to the existing `0xfffc` → `S_V64_FOREACH` arm. |
| **7** | open | **keep** — parent **pending frame index**, not `e64-1` vs sticky `hs_m_vcsp`. | `S_V64_ALLOC` `fr` ~10213 | Overlay detect is one case; nested `new` / sticky `hs_m_vcsp` still clobbers caller with `0xfffc`. | Fault 2 on `animate` RET / `NEW_OBJ Game`. | ALLOC writes that slot only. |
| **8** | open | **keep** — keep the first-entry latch. `leave_hold` must plant non-EXEC **before** enable. Do **not** put `leave_hold` in the enable=0 else. | `S_V64_FRAME_RAF` ~13616 | Skip still double-RET → fault 2. | PACMAN halt at rAF return. | Latch + plant. |
| **9** | open | **keep after 6/7** — drop oldest + `dbg_raf_ovf`. Do not skip gen. | exec64 rAF ~3852 | `vraf_n>=8` → fault 3, halt. | Hard halt. | Fix 6/7 first. |
| **10** | open | **keep** — `ctx_sx/sy <= FX_ONE` on exec32 **rst and `p_clr`**. Parent RUN already does this (~6650); exec32 never does. | exec32 rAF ~4929; `ctx_sx` | Silent rAF overflow. `ctx_sx` not `FX_ONE` on rst/`p_clr`. | `raf=0` no fault; or every fillRect clips to 0. | Match exec64. |
| **11** | open | **keep** — one more `WIN_FILL` (or dedicated `vst_raddr` wait), then fault. | exec64 CALL_VAL ~4356 | One refill; second miss → fault 4. | Halt mid-play. | Extra refill. |
| **12** | **partial** | **revise** — HTML `ctx.fillRect` is CALL_METH → `RECT_LD` (~5571). After `hs_st(RECT)`, `state == RECT` so the plant (~11251) **does not run**. Overlay plant is the **nid 2** path (parent still EXEC) and is correct for that path. Dead TOS `vdraw_*_n` on CALL_METH are unused if plant stays gated. | exec64 nid 2 ~3695 vs CALL_METH ~5535; parent RECT ~11249 | Dual path: nid 2 TOS (no transform) vs CALL_METH SRAM+scale. | Not the INVADERS `drawBitmap` freeze (that's G1+FIND+**5**). nid 2 `fillRect` ignores `setTransform`. | Leave CALL_METH. Plant only when overlaying nid 2 (`state != RECT`). |
| **13** | open | **revise** — Value64 `Date.now` / `getTime` / nid 35 already use **`vframe_no`**, and Value64 WAIT_FRAME **does** bump `vframe_no` (~8416). PACMAN skip-draw is **not** “Date.now stays 0” on that path. Still add `time_ms += 17` on the Value64 arm for exec32/`time_ms` readers. | `S_WAIT_FRAME` Value64 ~8398 vs tagged ~8456 | Value64 does not bump `time_ms`. | Tagged/exec32 `Date.now` stuck. | `time_ms += 17` on both arms. |
| **14** | open | **keep** — in-place `vframe_no` mul like nid 35 / CALL `0xfffa` (~4381). Do not ALLOC a fn every GET_PROP. | GET_PROP `id_now` ~4910 | Each `.now` ALLOCs native-35 then CALL. | Heap bump / gen mismatch fault 4. | In-place timestamp. |
| **15** | open | **keep** — sparse keyCode→intern table. Must include **w/s/p** (DONKEY WASD + pause), not only a/d/arrows/Enter/Space. | KEYEVT `e.key` ~8543 | Only Enter/Space/arrows/a/d get a string. Else `e.key` is undefined. | DONKEY `event.key==="Enter"` is interned (OK). `"w"`/`"s"`/`"p"` are not — jump/arrows work, WASD vertical and pause do not. | Table, not a title gate. |
| **16** | open | **keep** — depth 16 or coalesce downs. | kev FIFO ~6162 | Depth 8; drop on full. | Start key lost. | Depth 16. |
| **17** | open | **keep** — drop + `dbg_lis_ovf`, not fault 3. | exec64 addEventListener ~3999 | 16 total / 4 per type → halt. | Halt on noisy bind. | Drop, don’t halt. |
| **18** | **partial** | **revise** — tagged WAIT_FRAME rewind is **retired** (~8482); that arm now starts `S_GC_CLEAR`. Do **not** put `n_obj <= n_obj_keep` back. Leftover: keep watermarks + GC completeness (**30**). | HEAP keep tasks ~1832; WAIT_FRAME ~8475 | Was: nursery rewind recycled live oids. Now: mark/sweep on the tagged arm; Value64 GC after FRAME_TIMER. | Old freeze was `raf=0` / fault 4. | Finish root GC; never skip gen. |
| **19** | **partial** | **revise** — `varr_slot_addr` now uses `{aid[10:0], slot[4:0]}` (~1115); the 10-bit pack that aliased 1024→0 is **gone**. Caps still `OBJ_SLOTS=32` / `ENV_SLOTS=16` / `ARR_CAP=128` / short 32. Loud overflow OK. | parent ~387, ~1115 | Overflow fault/truncate. Alias was 1024..1535 → 0..511. | PACMAN `map[0].length` undefined if overflow, not if alias (decode fixed). | Keep new decode. Loud overflow. |
| **20** | open | **keep** — skip GET until `fb_dirty`; skip cache if `nz==0`. Do not add a second `imgd_pix`. | `S_IMGD_GET` ~9568 | One snapshot buffer. PACMAN `map.cache` can copy empty glass. | Permanent black maze. | Policy, 1 px/clk stays. |
| **21** | open | **keep** — loud overflow; every JSON state must advance. | JSON_CAP 8192 | Overflow / truncate. | Leaderboard hang. | Keep loud; no stuck state. |
| **22** | open | **keep** — extra beat is required. Full replace via CONCAT+FIND. | String.replace ~6129 | Missed wait restarts FIND. | Hang. | Keep beat. |
| **23** | open | **keep** — stub `toISOString` (INVADERS save ~122). localStorage already stubbed. | localStorage / `Date()` | No `toISOString`. | Uncaught throw → halt **on save**, not splash. | Stub method. |
| **24** | **slow** | Extra beat is the Port A settle. Removing it hangs. Faster only if `.length` still waits `name_blen`/`varr_len` `*_rdata`. | GET_PROP `.length` extra beat | One extra clock per `.length`. | Hang if the wait is deleted. | Keep the wait; do not combo-peek. |
| **25** | open | The FETCH arm must stay. New miss paths must also `hs_st(FETCH)`. | `S_HEAP_CMP` ~12144 | Hang if a miss restarts `cls_scan`. | Hang `HEAP_CMP`, `fault=0`. | Any miss → FETCH. |
| **26** | open | **keep** — fail loud if not ASET. Keep gen. | drawImage ASET ~5695 | Miss paints nothing. | DONKEY sheets blank. | Loud miss. |
| **27** | open | **keep** — Enter already interned (**15**). Title branch has no rAF by design (`DONKEY.HTML` ~1089). No `"DONKEY"` gate. | DONKEY `update()` | `gameState=="title"` does not re-arm rAF. Silicon `raf=0`. Correct JS. | Looks frozen after splash. | KEYEVT must deliver `"Enter"`. |
| **28** | open | = **1** | fillText intern FIND | `"SCORE "+n` → CONCAT + FIND. | Same as 1. | Fix 1/2/3. |
| **29** | open | = **G1** + FIND | INVADERS `drawBitmap` | Per-lit-pixel `fillRect`. | Stacks with FIND over 64M. | No sprite ROM. |
| **30** | open | **keep** — drop invalid timer fn; never skip gen. | GC every WAIT_FRAME / FRAME_TIMER | Stale timer fn → fault 4. | Halt. | Drop + keep gen. |
| **31** | open | **keep** — one predicate, typed below. Do not count nid-3 during `S_V64_EXEC`. | `sim/sim_main.cpp` ~1910 | Present-exit does not require `st == WAIT_FRAME`. Value64 swaps at FRAME_TIMER then `S_V64_GC_CLEAR`. nid 3 during EXEC bumps `dbg_swap_n` (~6140). | Next FRAME may start in GC (usually OK). Mid-rAF `swapBuffers` cuts the callback. | `left_wait && st==WAIT && !due && !frame_continue && (swap\|\|cbip)`. |
| **32** | open | **revise** — canvas default fill is **black**. Exec `p_clr` `fill_style_i<=0` (~2261) matches `#000`. Parent RUN `8'd1` (~6571) is white. Unknown CSS also parses to `8'd1` (~5121). | exec64 `p_clr` vs parent RUN | Default 0 vs 1. `ctx_align=0` **is** the right reset. | Glass only if a title paints before `fillStyle`. ASTEROID/INVADERS set style first. | Set **both** exec `p_clr` and parent RUN to `8'd0` (canvas black). |
| **33** | open | **new** — store is already HEAP SET_PROP. Paint must read it. Do not skip gen. One scale (0 / 25 / 50 / 75 / 100) is enough. | exec64 SET_PROP / RECT / TXT | RTL has **no** `globalAlpha`. PYTHON applies it on `fillRect` and skips when alpha==0. | INVADERS mystery/explosions (`c.save(); c.globalAlpha=…; c.restore()` ~173) draw fully opaque. Not a freeze. | Latch on SET_PROP `id_globalalpha`; skip/scale RECT+glyph writes. |
| **34** | open | **new** — one-deep transform stack already exists (`saved_sx` ~5643). Add fill/stroke/align/alpha to the same 1-deep save. | exec64 `id_save`/`id_restore` | `save`/`restore` copy only tx/ty/sx/sy. PYTHON also saves `globalAlpha`. | Nested save (none in titles) would lose transform. INVADERS one-deep save around alpha is OK once **33** latches alpha. | Extend the existing 1-deep FFs. No stack SRAM. |
| **35** | **slow** | Overlay first beat is idle because `vst_raddr` follows `state`, not `casestate` (~2491). Faster only if raddr is valid the same cycle without combo-peek. | RECT_LD / WIN_FILL / BIND | First-entry latch ignores rdata (`state != SELF` / `vst_refill_ret==IDLE`). Extra clocks. | Wrong stack word if beat 0 consumes `vst_rdata`. | Keep the latch unless raddr is fixed first. |
| **36** | open | **keep** — use full `name_blen` (u16), same wait as **24**. | exec64 `measureText` ~5841 | Width is `name_blen_rdata[7:0] * 8`. PACMAN `measureText` ~1024. | HUD/button width wrong if intern len ≥256. Not a freeze. | `{8'd0, name_blen_rdata}` after the existing `hash2` beat. |

**Other agent (not a freeze):** `ctx_align <= 0` on exec64 `p_clr` **corrects** the cross-title `textAlign` leak. It does not fix **10** or **5**.

---

## Graphics that look like a freeze (HTML → RTL)

These are not infinite FSMs. They are **O(pixels × JS calls)** on a 1-pixel-per-clock raster. A painted frame that **finishes** should end via **31** (present), not 64M. G1/G8 look hung when stacked with a host that never exits (**5**) or a real spin (**6**). FIND (**1**) is extra k-clocks, not 64M by itself.

| ID | Status | Fix check | HTML (function) | RTL | Cost | Best fix (VM-wide) |
|---|---|---|---|---|---|---|
| **G1** | open | **keep** — optional “1-bit row run” is language, not an INVADERS ROM. Keep 1 px/clk. Intern `"1"` should last-4 hit after the first cell. | `INVADERS.HTML` `drawBitmap()` ~83 | `RECT_LD` 2 clk/arg × 4, then `S_V64_RECT` 1 px/clk. `fillStyle` once per sprite, not per cell. | ~2k × (8 + ~9 px) ≈ 40k, plus a 307k clear. Looks slow if the host never exits (**5/31**). | Host predicate first. |
| **G2** | open | **keep** — don’t snapshot until `fb_dirty`. Stroke arcs = **G6**. Keep 1 px/clk clears. | `PACMAN.HTML` `Stage.start` ~344; `map.cache` ~360; maze `draw` ~1088 | CLEAR/RECT 307k; `S_IMGD_*` 307k; `S_CIRCLE` bbox `(2r)²`. | Alone ~1–2M (OK). + FIND + **6** + **14** → 64M. Empty cache = black (**20**). | Policy + G6. |
| **G3** | open | **keep** — one outstanding ASET req is legal. No sheet in code BRAM. Title park is **27**, not blit. | `DONKEY.HTML` `update()` ~1059 | `S_BLIT` 2 clk/px (`sram_ack`). | ~0.1–0.5M. | Pipeline ack if Port A allows. |
| **G4** | open | **keep** — clip once; wrap by modulo of points. Not an ASTEROID gate. | `ASTEROID.HTML` `strokeClosed` ~354 / `drawRockWrapped` ~373 | `S_LINE` 1 px/clk × 5 copies × N rocks. | Hundreds of k + FIND HUD. | Clip, don’t 5-stroke. |
| **G5** | open | **leave** — proof full-glass fillRect is playable when FIND is cheap. | `AURORA.HTML` `wipe()` ~60 | `S_V64_RECT` 307k. | ~0.3M. Not a freeze. | None. |
| **G6** | open | **keep** — Bresenham / octant outline, same Port A FB write. Fill stays bbox or scanline. | PACMAN / ASTEROID `arc`+`stroke`; MRDO tunnel | `S_CIRCLE` ~7407 visits **every bbox pixel**. | r=16 → ~1k; maze × many cells. | Outline walk. |
| **G7** | open | = **G1** | `MRDO.HTML` `drawPix()` ~1258 | Same RECT_LD+RECT. | Field redraw looks hung. | FIND + language blit, not a MRDO ROM. |
| **G8** | open | = **1** — glyph `S_TXT_DRAW` ~9422 is cheap. Last-4 misses when `n` changes, then one linear walk. | All HUD `fillText("SCORE "+n)` | CONCAT + FIND then 8×8×k² on-pixels. | ~2k clocks per new HUD string, not 64M. Hash collision is **2**. | Byte-confirm FIND. |
| **G9** | open | = **20** — copy stays 1 px/clk. Do not raise cap. | PACMAN `getImageData`/`putImageData` ~360 | One `imgd_pix[307200]`. | Empty PUT is a black freeze, not a clock freeze. | No GET until paint. |
| **G10** | **slow** | 307k clocks is a full-glass clear. Faster only with another legal FB write port — not `fb[i]<=` in the 7k FSM (70 GB synth). | Full-canvas `fillRect`/`clearRect` | 640×480 = **307 200 clocks** (×2 on PACMAN). | Slow (~10 ms at 30 MHz), not a hang. | Wider Port A, not an FSM poke. |

---

## Slow vs hang (same care: do not break code or synth)

SRAM is address this clock, data next clock. Those extra beats are **slow**,
not leftover junk. You can make a path faster; the wait/`*_rdata` and Port A
shape have to stay legal or Verilator glass and Vivado both die.

| Item | What it is | Constraint if you speed it up |
|---|---|---|
| **24** GET_PROP `.length` extra beat | Slow (1 extra clock) | Still wait `name_blen` / `varr_len` `*_rdata`. Combo-peek hangs HEAP |
| **25** HEAP miss → undefined + FETCH | Correctness, not speed | New miss paths must still `hs_st(FETCH)`. Dropping the arm loops `cls_scan` |
| **35** overlay first beat idle | Slow (1 extra clock on RECT_LD / WIN_FILL) | Do not consume `vst_rdata` until `state` matches and raddr is that slot |
| Other `*_rdata` waits | Slow | Same Port A rule as 24/35 |
| 1 pixel/clock FB write | Slow (307k for a full clear) | Another write port is fine. `fb[i] <=` in the 7k FSM is 70 GB synth |
| One `stack_wr` per clock | Slow (FOREACH el then idx) | Two writes one cycle needs a second RAM port (`stack_dual_pend` is the extra clock) |
| Port A `if (we) mem[waddr] <= wdata` | Legal SRAM | Faster heap is fine; `stack[i] <=` in the FSM is the 70 GB hang |
| FRAME cap 64M | Host timeout, not a speed knob | Raising it hides unfinished rAF; GUI sits on the RPC |
| Nursery rewind `n_obj <= n_obj_keep` | Old “faster GC” | Recycles live oids. Tagged arm already uses `S_GC_CLEAR` |
| `varr_slot_addr` `aid[10:0]` | Correct decode | `aid[9:0]` aliases 1024→0 |
| exec64 `ctx_align <= 0` on `p_clr` | Correct reset | Without it DONKEY `center` leaks into the next title |
| `leave_hold` not in enable=0 else | Correct | Putting it in that else deadlocks `eip=0` |
| Skip gen / clone heaps / title gates | Forbidden | Not a speed-up |

---

## Confidence (bug / fix)

High = seen in RTL with a single causal path. Med = real hole, freeze story depends on another ID. Low = glass or overstated as a 64M hang.

| ID | Bug | Fix | Why |
|---|---|---|---|
| **6** | High | High | First `0xfffc` arm is literally before the FOREACH arm. Delete only that arm. |
| **31** + **5** | High | High | Host C++ is the 64M RPC. Predicate must include `st==WAIT`. `snap[15:0]` is not a callback IP. |
| **15** | High | High | Same mux in tagged KEYEVT and Value64 ALLOC (~8543, ~10667). Add `w`/`s`/`p` (and `id_w` trail hashes). |
| **10** | High | High | exec32 never assigns `FX_ONE`. Parent RUN already does. Copy exec64 rst/`p_clr`. |
| **14** | High | High | GET_PROP `id_now` ALLOCs; CALL `0xfffa` / nid 35 already do the mul. |
| **2** | High | High | Hash+u8 compare is in the hit arm. Byte stream is the only legal confirm. |
| **1** | High as slowness; **Low as sole 64M** | High as hash→id | `2*names_n` ≤ ~2k. Last-4 hits `"1"` / repeated HUD. 64M is **5/31** or a spin. |
| **7** **8** | Med | High | Overlay/`leave_hold` comments match PACMAN fault 2. Pending `fr` + latch; no `leave_hold` in enable=0 else. |
| **13** | Low for Value64 PACMAN | High as hygiene | `Date.now` uses `vframe_no`, which Value64 WAIT bumps. Still `time_ms+=17` for exec32. |
| **12** | Low for HTML play | High as hygiene | CALL_METH never plants. nid 2 still untransformed. |
| **32** | Low | High | Canvas default is black. Both sides `8'd0`. |
| **33** **34** | High as glass | Med | PYTHON has alpha; RTL does not. One-deep save is enough for INVADERS. |
| **20** **G6** | Med | High | Empty ImageData and bbox flood are in RTL. Policy / Bresenham, no second buffer. |
| **24** **35** | Slow | Keep wait | Extra SRAM beats. Faster only if `*_rdata` is still valid. |
| **25** | High | High | Miss must FETCH. Not a speed item. |

---

## Typed patches (high-confidence only)

**6** — in `jmr_js_vm_exec64.sv` implicit `ip >= n_ops`, **delete** the first `vframe_rip_rdata == 16'hfffc` block that goes to `S_V64_GC_CLEAR`. Leave the later `0xfffc` → FOREACH / map-store arm.

**31+5** — in `sim/sim_main.cpp` FRAME, **replace** the two exit tests with one:

```
if (pulsed && left_wait && st == 16u && !due_timer && !frame_continue &&
    (cbip != 0 || swap != swap0)) { got = 1; break; }
```

(`16u` is `S_WAIT_FRAME`.) On rAF fire, `dbg_cb_ip <= 16'h1` (not `vraf_snap[i][15:0]`). Keep idle>2000 for no-rAF splash.

**15** — same keyCode table in tagged KEYEVT and Value64 `vnat_dom==5`: `87→id_w`, `83→id_s`, `80→id_p` (plus existing Enter/Space/arrows/a/d). Intern those names in the trail walk like `id_enter`.

**10** — exec32 `always_ff` rst and `p_clr`: `ctx_sx/sy/saved_sx/sy <= FX_ONE` (copy exec64 ~1724 / ~2247). rAF overflow: fault 3 like exec64, do not silent-drop.

**14** — GET_PROP `id_now`: do the nid-35 `vframe_no` mul in place; do not `S_V64_ALLOC`.

---

## Suggested order (revised)

1. **6** — implicit `0xfffc` → FOREACH.
2. **31** then **5** — one host predicate + `dbg_cb_ip <= 16'h1`.
3. **15** — `w`/`s`/`p` (DONKEY play after Enter).
4. **10** **14** — exec32 scale; Date.now ALLOC.
5. **1+2+3** — FIND (HUD / collision; not the 64M RPC).
6. **7+8+9** — ALLOC / rAF RET.
7. **G6** + **20** — circle outline; ImageData policy.
8. **33** — `globalAlpha` (glass, INVADERS mystery).

Do not start hash→id BRAM until asked. Do not `make bit`.
