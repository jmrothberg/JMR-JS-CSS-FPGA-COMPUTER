# Potential bugs — FPGA-SIM play RTL (code review)

Inspection of the play path: `rtl/engines/jmr_js_vm.sv` (parent FSM),
`jmr_js_vm_exec64.sv`, `jmr_js_vm_exec32.sv`, `sim/sim_main.cpp`, vs
`hardware_model/js_vm.py`, plus `storage/*.HTML` and
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md). No traces. No FPGA-SIM
rerun.

## RTL edits applied this pass (2026-08-19, no run)

`verilator --lint-only` on pkg + value + parent + exec32 + exec64:
**0 errors**, and the warning profile is byte-identical to the pre-edit
baseline (LATCH 234, MULTIDRIVEN 63, WIDTHEXPAND 2318, WIDTHTRUNC 397→396).
Nothing was executed.

| ID | File | What changed |
|---|---|---|
| **49** | `jmr_js_vm_exec64.sv` ports + `jmr_js_vm.sv` per-clock block and `S_PWALK` | **Applied per the addendum's "Better 49", all three steps.** (1) exec64 exports `pc_we`/`pc_waddr`/`pc_op_wdata`/`pc_a1..a5_wdata`/`pc_ccw_wdata` (combinational taps on the values its own arrays take); the parent mirrors them into `pc_op[]`/`pc_a1..a5[]`/`pc_ccw[]` in the **non-reset** branch of the same `always_ff`, gated `jsb_flags[3] && e64_pc_we_q`. `pc_we` defaults to 0 in exec64's `always_comb`, so it is quiet when exec is disabled. (2) `S_PWALK` gets a first-entry `if (state != S_PWALK)` latch — `path_active<=1`, `path_stroke`/`pc_n`/`color`/`ctx_sx,sy,tx,ty` from `e64_*_q`, `pi<=0`. Without it the overlay beat compares the stale `pc_n` (0) and aborts before any NBA lands. (3) Return-IP hole closed on that same first entry with `hs_ip(e64_ip_q)` + `hs_vsp(e64_vsp_q)` — the raster states are not in `hs64`, so the done-path `hs_code(ops_base + ip)` would otherwise re-fetch a stale op and re-issue fill/stroke. No new parent FFs: every `e64_*_q` it reads was already ported and unused. |
| **38** | `jmr_js_vm_exec64.sv` `OP_CALL_METH` | `id_quadcurve` port added (parent already interns it and wires it to exec32) plus the exec32 twin arm writing `pc_op 2` + four Q16 args. Done in the same pass as **49** as the addendum requires — before **49** it would have fed a buffer nothing reads. |
| **47** | `jmr_js_vm.sv` `S_V64_FOREACH` first entry | Mirror exec64's nest push into the parent shadow stack when `e64_vfe_sp_q > vfe_sp`. On that beat `vfe_sp`/`vfe_arr`/`vfe_fn`/`vfe_map` are still the OUTER walk and exec64 saved exactly those at `vfe_s_waddr = old vfe_sp`, so the shadow matches slot for slot. GC root phase 7 now marks real handles instead of `'0`. Re-entry after a callback has `e64_vfe_sp_q == vfe_sp` and does not fire. Stale slots are deliberately **not** cleared on pop: between the pop and the next re-latch the shadow is the outer walk's only root, and marking a stale word is conservative (`v64_gc_mark_task` checks tag/kind/bound/valid), never a fault. |
| **6** | `jmr_js_vm_exec64.sv` implicit `ip >= n_ops` | Added a **guarded** arm *before* the existing `0xfffc`→GC_CLEAR one. Guard is "the walk is still live": `vfe_arr` a live ARRAY handle, `vfe_i != 0`, `vfe_i <= vfe_len` (`vfe_i` is pre-incremented in `S_V64_FOREACH`, so mid-walk is 1..len inclusive; the done path clears `vfe_arr` at `vfe_sp==0`). Body is the `OP_RET_VAL` `0xfffc` continuation minus the find/filter TOS tests. **Deliberately additive** — the leftover-frame case the old arm was written for still takes the old GC_CLEAR path. Deleting the old arm, as the earlier typed patch said, would have dropped `0xfffc` into the `vsp_hs != bsp` fault 1 it was added to dodge. Env recycle omitted (GC reclaims; keeps the diff small). |
| **14** | `jmr_js_vm_exec64.sv` GET_PROP | Deleted the `id_now` ALLOC arm; a bare `.now` read now falls through to the shared string GET_PROP path and returns `V64_UNDEFINED`, which is what PYTHON answers (`js_vm.py` handles `now` only on the method path). `Date.now()` was never on this arm. PACMAN's polyfill body now executes but is inert — `Date.now =` / `window.* =` are SET_PROP on a primitive (no-op, ~5081) and every call site is bare `requestAnimationFrame()` → nid 27. `valloc_now_fn` is left wired but never asserted. |
| **36** | `jmr_js_vm_exec64.sv` `measureText` | `tl = {8'd0, name_blen_rdata[7:0]}` → `tl = name_blen_rdata`. The font scale is still missing and still blocked on **45**. |
| **15** | `jmr_js_vm.sv` tagged KEYEVT | Added `8'd87` / `8'd83` / `8'd80` to the `hp_qt_ff[0]` type-tag list so `e.key` for w/s/p carries type 3 like the id ternary two lines above already did. |
| **10** | `jmr_js_vm_exec32.sv` reset | `saved_sx/sy <= FX_ONE`, `saved_tx/ty <= '0` in the reset branch (same `always_ff`, single driver). They previously had no initial value at all, so a `restore()` before any `save()` drove `ctx_sx` to X/0. |

**OPEN — INVADERS "Space freezes the splash" (trace
`session_20260819_234259_142995_FPGA-SIM.log`).** What is *established*: Space
does start the game (`obj` 23→737, `arr` 18→25), and the first frame that runs
`drawHud()` never finishes — `topip=2305x32988` (the `i < extras` test, 32,988
times in **one** frame; `ip_hist` is cleared per frame), `ipn=4455195`,
`fclk=64000000 fcap=1`, `fault=0`. So `for (let i = 0; i < extras; i++)`
(INVADERS L647, `extras` = 2) does not terminate, the host never gets a
completed frame, and the glass keeps showing the last present — the splash.
**The cause is not yet known.** Ruled out by inspection: slot aliasing
(**50**, retracted — lookups are name-keyed); env overflow (loud fault 3, not
seen); `extras` being undefined (`v64_less` returns 0 for any tagged
non-number, so `i < undefined` is correctly false and would exit at once).
**Leading unverified hypothesis:** `STORE_VAR i` (a1=3, ip 2381) not landing
where `LOAD_VAR i` (a1=3, ip 2305) reads — i.e. the increment writing the
global `vvars` table or a fresh entry while the read stays on the env slot.
That is a *hypothesis*, not a finding; confirm it by dumping the env slot for
name id 73 across two iterations before changing any RTL.

**PACMAN blank screen — trace confirmation, 2026-08-20**
(`session_20260820_002044_280494_FPGA-SIM.log`). PACMAN is *healthy*:
`fault=0`, frames complete at a constant `fclk=690709` (nowhere near the cap),
`swaps` reaches 29, `obj=152 arr=447`. It clears to black and presents, every
frame. Two independent causes, both directly observed:

- **49 is confirmed empirically.** `NOTE PX line=0 circ=0` for **both** titles
  in one session (`dbg_line_px`/`dbg_circ_px` *are* cleared at RUN, so this is
  "never incremented", not a stale reading), while INVADERS shows
  `rect=152064`. PACMAN: `PX line=0 circ=0 rect=0`, `FBRAW nz0=0 nz1=0`.
  PACMAN draws 18 `arc`, 6 `lineTo`, 9 `fill()`, 5 `stroke()`,
  5 `quadraticCurveTo` and only **2** `fillRect` — the black clears, which
  `dbg_rect_px` does not count (`vdraw_color != 0` gate). INVADERS survives
  only because it has 21 `fillRect`.
- **No `fillText` ran either — not explained by 49.** `dbg_txtw` ("last
  fillText pen width", written only in `S_TXT_LD` ~9468 and **not** in the RUN
  clear list) stays frozen at **136**, the value INVADERS left behind, for the
  whole PACMAN run. PACMAN's title stage has three pure-text items ('Pac-Man',
  'Press Enter to start', the copyright line) that would each move it. So the
  per-item `draw` callbacks never execute. Both draw paths go through
  `Array.forEach` — `stage.maps.forEach` (PACMAN.HTML:352) and
  `stage.items.forEach(... item.draw(_context))` (:370) — and `item.draw` is an
  own-property function attached by `Object.assign` in `new Item(options)`.
  A walk that does not iterate, or a CALL_METHOD that misses an own-property
  function, both return undefined **silently with no fault** — exactly this
  signature. Treat as open; do not assume **49** alone fixes PACMAN.

**Binary provenance for that run:** built 19:36:47, newer than every RTL source
(≤19:36:29), so it **already contained** **6** and **47**. #6 is therefore
ruled out as PACMAN's blocker.

## Session 2026-08-20 (late) — the common-issue hunt, verified by probes

Method: minimal Value64 `.JS` probes through `SimBackend` + a new **VARRPEEK**
RPC in `sim_main.cpp` (dumps `varr_valid/len/gen/long/lidx` + 8 raw slots).
Every claim below is probe-verified on the rebuilt binary, not inspection.

**#53 — APPLIED, and it was the common blocker.** `S_HEAP_AWR` and
`S_HEAP_FILL` were the only two direct-entry parent states **without the
first-entry `hs_st` guard** (compare `S_HEAP_WAIT`, which has one). The guard
is not bookkeeping: it is what makes parent `state` follow the exec-issued
transition and disables exec the next beat. Without it, for every exec-issued
array element write: `varr_we = (state == S_HEAP_AWR && hp_slot_arm)` **never
fired** — `a[1] = 7` silently lost the write (VARRPEEK: literal fill intact,
set absent) — and the FILL phase beat ran on the casestate overlay while
`vst_raddr` (gated on parent state) still held the DEFAULT address, so
`a.push(x)` stored a stale stack word: probe VK1 showed `a[0] === a` (the
receiver handle), probe VW2 showed `stack[0]`. **Every `push` / `unshift` /
`a[i]=` on the Value64 path wrote garbage or nothing.** PACMAN items/maps,
ASTEROID rock points, DONKEY frame tables all build through these. Fix: the
canonical `casestate_q != X → hs_st(X)` first-entry on both states, resetting
`hp_slot_arm` / `hp_phase` so the settle beats rerun under the state's own
raddr mux. Two wrong theories preceded it, kept for honesty: (a) "casestate_q
in the vst_raddr mux" — casestate_q lags the combo `casestate` by a beat, so
it changed nothing (the two mux terms are left in; harmless); (b) it was NOT
introduced by this session's edits — **identical failure at git HEAD**, and
the suite's own `VARMAP` test (`steps[0][1] = 7`) FAILS at HEAD: the "passing"
suite is stale, and `PUSH70` only asserts length, never elements.

**#52 — APPLIED.** NEW_OBJ class-table hit path never linked
`vobj_proto[instance]`; PYTHON links it on every hit
(`_value64_ctor_function_for_class` + `_value_object_protos`). Fix: when the
class name is also a var (`e32_intern_var_ok_rdata`), route through the
existing `S_RD → S_V64_CTOR_VARS` machinery (which links proto AND dispatches
the same ctor ip); pure `class` syntax keeps the inline dispatch. Verified:
`function Stage(){}` + `Stage.prototype.m` + `new Stage()` probes pass; class
syntax regression passes.

**#51 — APPLIED.** `S_BLIT` first-entry latch copying
`rw/rh/rx/ry/x/y/blit_*` from `e64_*_q` (all were ported and unused) +
`hs_ip(e64_ip_q)`/`hs_vsp(e64_vsp_q)`, gated `jsb_flags[3]` so the tagged
path is untouched. Per the Review addendum.

**Probe evidence after all fixes (VG1 = PACMAN's full title-stage shape:
nested `var Stage = function` + `Stage.prototype.createItem` + closure
`_stages[0]` + `items.forEach` + own-prop `item.draw`): 8/8 PASS.**

**Title smoke through the backend (rebuilt binary):**
- PACMAN: `fault=0`, **`nz0=2667`** (was 0 — logo, title text, blink paint),
  obj=466/arr=104 (items real).
- ASTEROID: **`nz0=1875`** (was HUD-only), raf alive.
- DONKEY: still text-only (`nz0=446`, `dihit=0 dimiss=0`, `raf=0` at title by
  design — #27). **OPEN:** `showTitleScreen()` creates `new Image()` and sets
  a data-URI `src` per call, deferring every `drawImage` to `onload` — the
  drawImage CALL_METH arm is never reached, so this is the onload-dispatch
  path, not #51 (which is fixed but unexercised until a drawImage runs).
  Next session: trace SET_PROP `id_src` phase 3'd6 / onload firing for
  Images created inside a draw call on a rAF-less state.

**Also this session (probe-verified, no fix attempted):** nested
`function F(){}` DECLARATIONS inside a function compile to `MAKE_FN` + `POP`
— the binding is discarded (`functional_model/compiler.py`). No title hits it
(PACMAN uses `var X = function`), but it silently breaks the F1/F2/F3 probe
shapes. Compiler fix, not RTL.

**Not edited, on purpose — read before asking why:**

- **46 — RETRACTED, it was a false positive.** See its row.
- **38** — moot until **49**: adding a `quadraticCurveTo` arm feeds a buffer nothing reads.
- **39** — the typed patch is **not buildable as written**: `vfe_mode` is `logic [1:0]` in exec64 (~1556), the parent, the port, and `vfe_mode_s[]`, so `vfe_mode == 2'd4` does not exist. Needs either a 3-bit widening in four places or a separate `vfe_reduce` flag, plus a new `vfe_acc` FF **and** its export, plus a nest-stack slot for both, plus a different push order in the parent (`acc, el, idx` instead of `el, idx, arr`) and a different `vfe_fn` source (`VST_AT(base+1)`, since `reduce(cb, init)` puts `init`, not `cb`, on TOS). That is ~150 lines and 2 new ports each way. Today `reduce` returns undefined and INVADERS keeps playing without clearing waves; a wrong implementation faults and halts it. Not done blind.
- **45**, **33**, **37** — glass only, and each needs new ports or new parent interns. **42**/**43** — console only, no effect on the three titles.

---

## Review addendum — 2026-08-19 (evening)

Inspection only. No traces. No run. Applied 6/47/14/36/15/10 still look
right; the holes below are either **new IDs** or **typed patches that
would not actually paint**.

**51 — new, same shape as 49, DONKEY/INVADERS art.** exec64 `drawImage`
hit (~5838) sets `rw_n`/`rh_n`/`rx_n`/`blit_si_n` and `state_n = S_BLIT`.
Parent `S_BLIT` (~8196) has **no first-entry latch**. It reads parent
`rw`/`rh`/`rx`/`ry`/`x`/`y`/`blit_si`/`blit_sx..sh`. Those FFs are
never written from `e64_*_q` (`e64_rw_q` / `e64_blit_si_q` are ported
and unused). `blit_si <=` does not exist anywhere in the parent. `rw`
is only set by `S_XF_APPLY` / arc `S_PDO`. So a hit is `rw==0 || rh==0`
→ `hs_st(S_FETCH_WAIT)` with no pixels. `dbg_di_hit` still increments.
This is **not** **26** (26 is the miss arm). Handoff DONKEY `nz0=0` with
`vdraw=0,0,640,479,0` is a clear then a no-op blit. INVADERS
`drawBitmap` fillRect still works; particle/explosion `drawImage` does
not. **G3** clock math assumes this raster runs.

**49 typed patch is incomplete — do not ship “9 write strobes” alone.**
`enable` is `state == S_V64_EXEC` only (~4001). `S_TXT_LD` / `S_V64_RECT`
work because they have a first-entry `hs_st` **and** sit in `hs64`, so
`ip` stays `e64_ip_q` and `hs_code(ops_base+ip)` on the way out is the
already-incremented fetch. `S_PWALK` / `S_PDO` / `S_LINE` / `S_CIRCLE` /
`S_QSEG` / `S_XF_MUL` are **not** in `hs64` (~4759). During the walk
`ip = ip_ff` (last parent `hs_ip`, often FIND/FOREACH). fill/stroke
also never sets `code_raddr_n` (~6368). Done-path `hs_code(ops_base+ip)`
(~7533) would poke exec to a **stale** address and re-issue fill, or
the overlay beat `pi >= pc_n` (both 0) still aborts before any latch
lands (NBA). Same return-IP hole is on `S_BLIT` (drawImage hit does
not set `code_raddr_n` either, ~5837).

**Better 49** (copy `S_TXT_LD` ~9350, not only the 47 write-strobe):

1. Mirror `pc_we` + `pc_*_wdata` into the parent arrays (still required;
   first-entry cannot copy 16 slots in one cycle without exporting the
   whole buffer).
2. First-entry `if (state != S_PWALK)`: `hs_st(S_PWALK)`; latch
   `path_active` / `path_stroke` / `pc_n` / `pi` / `color` from
   `e64_*_q`; latch `ctx_sx/sy/tx/ty` from `e64_ctx_*_q` (parent
   copies stay identity after RUN — `S_PWALK` and `S_TXT_LD` font
   scale both use the parent FFs).
3. Either add `S_PWALK`/`S_PDO`/`S_LINE`/`S_CIRCLE`/`S_QSEG`/`S_QPX`/
   `S_QPY`/`S_XF_MUL`/`S_XF_APPLY` to `hs64`, **or** `hs_ip(e64_ip_q)`
   + `hs_code(15'(ops_base+e64_ip_q))` + `hs_vsp(e64_vsp_q)` on that
   first-entry (and the same `hs_code` on the done arm). Do **38** in
   the same pass.
4. Prefer (3)+first-entry over “continuous `pc_n <= e64_pc_n_q` every
   EXEC cycle”: the overlay beat still compares the **old** `pc_n`
   unless the first-entry guard skips the walk that clock.

**Better 39** — do **not** widen `vfe_mode` to 3 bits. forEach already
leaves `vfe_map` unused (`V64_UNDEFINED`). Add a 1-bit `vfe_reduce`
(port + nest-stack bit, or even a side FF that first-entry copies).
Seed acc into `vfe_map` from `VST_AT(base+2)` (INVADERS passes `0`).
Parent FOREACH push becomes `acc, el, idx` when the flag is set
(INVADERS only reads two args; PYTHON passes four). On `0xfffc` write
TOS back into `vfe_map`; walk-end `vst_wr(base, vfe_map)`. Empty +
init returns init. **6** is already applied.

**Better 6 leftover:** the applied implicit-RET body skipped the
`OP_RET_VAL` leaf-env recycle (~4504). Callbacks that fall off
`n_ops` will leak `ENV_DEPTH` until GC. Small, same arm; copy the
recycle. Nested leftover-frame: if an inner `0xfffc` is implicit-RET’d
while the outer walk is still live, the new guard treats it as a
current-walk return and can `HP_ASETI` undefined into the **outer**
map. Rare (done path already pops matching `bsp==vfe_base+2`). Do not
delete the old GC_CLEAR arm.

**47 applied is the better of the two typed shapes** (0 new ports).
Typed `vfe_s_we` export is tighter only for the map `S_HEAP_FILL`
window after the exec push and before FOREACH first-entry; AFILL does
not GC, so the hole is theoretical. Stale comment at ~11453 (“parent
`vfe_*_s` is never written”) is leftover.

**Compat table still lies:** `setTimeout` row still says “one timer
per frame” (**46** retracted); `Date.now` row still says bare `.now`
ALLOCs (**14** applied).

PATH_MAX=16 is enough for current titles (PACMAN paths are 1–6
commands; ASTEROID ROCK1 is 11). PYTHON `_raster_path` ignores `Z`, so
exec64 `closePath` as a no-op is parity, not debt.

**50 is already the compiler inline-slot bug** (INVADERS `drawHud` /
`drawCannon`). Verified: `_try_inline_user_call` copies ops as-is
(~569) with the callee's packed `a1`; it does not continue the
caller's `_local_stack`. HTML lines are **678-680** now. Do not reuse
50 for the blit hole — that is **51**.

---

**Current pass — 2026-08-19 (late).** RTL + `hardware_model/js_vm.py` +
`functional_model/machine.py` + `functional_model/compiler.py` +
`functional_model/jsb_format.py` + title HTML. Findings below were reached by
**inspection only — no traces, no run.** The RTL edits listed in the table
above were then applied and lint-checked; nothing was executed.

**Still open, typed, high-confidence — in fix order:** **50** compiler
inline slot alias (`drawHud` / `drawCannon` — INVADERS Space never
presents), **49** parent path buffer has no writer **and** no
first-entry/`hs64`, **51** `S_BLIT` never latches exec drawImage
scalars, **38** exec64 `quadraticCurveTo` (same pass as 49), **39**
`Array.reduce`, **45** exec64 `ctx.font`. **Monitor:** **42** `INSERT`,
**43** `DELETE`.

**Closed this pass:** **6**, **47**, **14**, **36**, **15**, **10** applied
(see the table above). **46** retracted as a false positive.

**Claims corrected this pass — do not re-apply the old ones:** **6** typed
patch was wrong (**replace** the arm, do not delete it — deleting it restores
the fault 1 the arm was added to dodge); **14** demoted High→Low (one property
read at load, not per frame); **33**/**34** PYTHON does **not** blend alpha —
it only skips `fillRect` at alpha==0, so scaling RECT/glyph writes would
*break* parity; **37** PYTHON ignores `textBaseline` too, so it is a browser
gap in *both* models and the location is `S_TXT_LD` ~9438, not `S_TXT_DRAW`;
**36**+**45** need the font scale and a jump to the parent `S_FONTPX`, not an
FF latch; `strokeRect` is PYTHON-**in**; **48** is a shared 128-element cap,
not a silicon bug.

**Landed in earlier passes (do not re-open):** **5** `dbg_cb_ip<=16'h1`, **31**
present-exit `st==16` (`S_WAIT_FRAME`), **15** Value64 `w`/`s`/`p` intern,
**10** exec32 `ctx_sx/sy<=FX_ONE` rst/`p_clr`, **22** replace `hash2` wait,
**32** default fill **black**, FIND byte-miss no longer faults (**3** leftover
is cap/collision), **18**/**19**/**25** as marked. Host FRAME cap is **8M**
(same `FB SAME` on miss). **Fix check** is whether the last column is still
legal — not a license to delete waits or Port A.

Compat [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) **Complete** means
JsHwVm (PYTHON), not FPGA-SIM. The command map below marks silicon **NOT**
when the verb/method has no RTL arm. `never` rows are product refusals, not
debt.

A title “freezes” when: FRAME burns the host cap (`FB SAME`), `fault`
drops `running`, rAF is not re-armed, paint stops changing, **or a frame
takes so many clocks it looks hung** (graphics / intern). A title can
also **look stuck while still ticking** (missing method returns
undefined — **39**). The **quietest** class is a `machine_fault` that
prints nothing: a queue or table that fills faster than it drains
(**46** timers, **17** listeners, **9** rAF, **48** array length) drops
`running` mid-play and the glass simply stops. Check `machine_fault` /
`fault_code` before blaming clocks.

**Fix rules:** Port A SRAM (never `mem[i] <=` in the 7k FSM). Extra clocks are
legal; a path can still be **slow** — speed it up without breaking wait/`*_rdata`
or synth. Keep gen. One heap. No title name as a gate. Do not raise the FRAME
cap.

Status: **open** = still in RTL. **partial** = attempted or narrowed, still
wrong. **applied `<date>`** = edited in this repo on that date, lint-clean,
**not yet run** — see the edits table at the top of this file for exactly what
changed. **corrected** = gone (verified by a run). **slow** = works, costs
clocks; faster is fine if SRAM and synth stay legal.

---

## Correctness bugs

| ID | Status | Fix check | Where | Bug | Why it freezes | Best fix |
|---|---|---|---|---|---|---|
| **1** | open | **keep** — hash→id BRAM + **byte** confirm. Last-4 stays. Not a CAM. **Do not expect this alone to stop a cap** — a miss is `2*names_n` clocks (≤2k), not 8M. | `S_JOIN_FIND` ~7805 | Linear walk, 2 clk/slot. Last-4 is hash+`jn_len` (u8). `"SCORE "+n` misses last-4 when `n` changes. | HUD slowness + hash collision (**2**). Cap hang is a real spin (**6**) or unfinished rAF. | Hash→id BRAM, then stream `name_mem` vs `txt_buf`. |
| **2** | open | **keep** — pair with 1. Compare **bytes**, not hash+u8. `jn_len` is already u8 (`TXT_MAX=64`); `name_blen` u16 is for GET_PROP `.length` / measureText (**36**). | FIND hit ~7852 | Match is `name_hash_rdata == jn_h && e32_name_len_tos == jn_len`. No `name_mem` bytes. 16-bit hash × 1024 names will collide. | Wrong intern id → EQ/keys lie. Not a cap spin by itself. | Stream `name_mem[off+k]` vs `txt_buf[k]`. |
| **3** | **partial** | **revise** — table-full and byte-stage miss no longer `dbg_str_ovf`/fault 5. They push undefined / blank and FETCH. Still no small-int intern; cap 1024 still undefined. | FIND alloc ~7883 | Intern never GC’d. Cap 1024 → undefined HUD. | HUD/`[key]` die after unique strings fill (wrong paint, not halt). | Small-int intern; refuse only real `NAME_CAP` overflow. |
| **4** | open | **keep** but **not first** — PACMAN `code.join('')` of 0/1 already works. | `S_JOIN` ~7688 | Only folds digits 0–9. Python ToString-joins any elem. | Non-digit join → undefined map. Titles do not hit this. | Fold elems through CONCAT/`txt_buf` (same FIND). |
| **5** | **corrected** | Parent `dbg_cb_ip <= 16'h1` (~13702). Do **not** restore `vraf_snap[i][15:0]`. | parent FRAME_RAF ~13699 | Was: oid 0 made cbip 0. | Was: play FRAME never exited on cbip. | Keep the marker. |
| **6** | **applied 2026-08-19** | **revise the patch** — bug confirmed at 3206; **do not simply delete** the arm (see Typed patches). Do **not** touch the later arm (~3262) or parent FOREACH done (~11348), which already pops a leftover `0xfffc` whose `bsp` matches `vfe_base+2`. **APPLIED** — guarded arm added ahead of the old one; see the edits table at the top. | exec64 implicit RET ~3206 | Fall off `n_ops` with `rip==0xfffc` → `GC_CLEAR` + `vgc_halt_after` **before** the `vsp_hs != bsp` check and before the FOREACH arm (~3262), which is therefore dead code on this path. | PACMAN `maps.forEach`: walk dies; leftover rAF → fault 3. | **Replace** the arm's body with the `OP_RET_VAL` `0xfffc` continuation (~4496): restore `vthis`/`venv`, `vcsp-1`, `vsp = vframe_bsp_rdata`, `vfe_mode==2` map-store undefined, `S_V64_FOREACH`. |
| **7** | **partial** | **keep** — overlay for parent-reserve is **in** (`hs_m_vcsp && vcsp_ff == e64+1` → `fr = e64` ~10254). Nested `new` / sticky `hs_m_vcsp` still not a pending-index. Do not put `leave_hold` in enable=0 else. | `S_V64_ALLOC` `fr` ~10254 | One overlay case. Nested `new` / `NEW_OBJ Game` can still clobber with `0xfffc`. | PACMAN fault 2 at `NEW_OBJ Game` (handoff §2). | ALLOC writes that slot only. |
| **8** | **partial** | **keep** — first-entry latch **is in** (`state != S_V64_FRAME_RAF` ~13663). `leave_hold` must plant non-EXEC **before** enable. Do **not** put `leave_hold` in the enable=0 else. | `S_V64_FRAME_RAF` ~13655 | Latch stops the overlay re-enable. Skip double-RET may remain. | PACMAN halt at rAF return if skip still fires. | Latch stays; plant if skip still faults. |
| **9** | open | **keep after 6/7** — drop oldest + `dbg_raf_ovf`. Do not skip gen. | exec64 rAF ~3852 | `vraf_n>=8` → fault 3, halt. | Hard halt. | Fix 6/7 first. |
| **10** | **applied 2026-08-19** (reset half) | **revise/sharpen** — exec32 rst + `p_clr` now `ctx_sx/sy<=FX_ONE` (~1578, ~2369). Leftover confirmed: exec32 `saved_sx/sy` have **no reset value at all** (only `saved_sx <= saved_sx_n` ~1812), so a `restore()` before any `save()` drives `ctx_sx` to X/0 and collapses the frame. exec64 is clean — it resets `saved_sx/sy <= FX_ONE` at both rst (~1726) and `p_clr` (~2249). rAF still silent-drop on exec32. **APPLIED (reset half)** — `saved_sx/sy/tx/ty` now reset. rAF silent-drop still open. | exec32 rAF ~4936; `saved_sx` ~1413 | Tagged fillRect clip-to-0 is gone. | HTML play does not use this path; **exec32 is slated for deletion** ([REMOVING_EXEC32.md](REMOVING_EXEC32.md) Cut A). | Copy exec64 `saved_*` reset + fault 3 — **or land Cut A and drop this ID**. |
| **11** | open | **keep** — one more `WIN_FILL` (or dedicated `vst_raddr` wait), then fault. | exec64 CALL_VAL ~4356 | One refill; second miss → fault 4. | Halt mid-play. | Extra refill. |
| **12** | **partial** | **revise** — HTML `ctx.fillRect` is CALL_METH → `RECT_LD` (~5536). After `hs_st(RECT)`, `state == RECT` so the plant (~11251) **does not run**. Overlay plant is the **nid 2** path (parent still EXEC) and is correct for that path. | exec64 nid 2 ~3695 vs CALL_METH ~5535; parent RECT ~11249 | Dual path: nid 2 TOS (no transform) vs CALL_METH SRAM+scale. | Not the INVADERS `drawBitmap` freeze (that's G1+FIND). nid 2 `fillRect` ignores `setTransform`. AURORA native `fillRect()` in try/catch is this path. | Leave CALL_METH. Plant only when overlaying nid 2 (`state != RECT`). |
| **13** | open | **revise** — Value64 `Date.now` / `getTime` / nid 35 already use **`vframe_no`**, and Value64 WAIT_FRAME **does** bump `vframe_no` (~8445). PACMAN skip-draw is **not** “Date.now stays 0” on that path. Still add `time_ms += 17` on the Value64 arm for exec32/`time_ms` readers. | `S_WAIT_FRAME` Value64 ~8431 vs tagged ~8485 | Value64 does not bump `time_ms`. | Tagged/exec32 `Date.now` stuck. | `time_ms += 17` on both arms. |
| **14** | **applied 2026-08-19** | **demote — one-shot, not per frame.** CALL_METH `.now()` / `.getTime()` already do the in-place `vframe_no` mul with **no** ALLOC (~6357). The GET_PROP arm only fires on a property *read* of `.now`, and the **only** one in any title is `PACMAN.HTML:25 if (!Date.now)` — once, at script load. `PACMAN.HTML:39 Date.now()` is CALL_METH. **APPLIED** — `id_now` GET_PROP arm removed; returns undefined like PYTHON. | GET_PROP `id_now` ~4910 | A bare `.now` read ALLOCs a native-35 fn (`valloc_now_fn`). | One wasted `vfn` slot at load. The ALLOC makes `!Date.now` false, which is also the **correct** answer (polyfill skipped). Not a heap bump, not a freeze. | In-place timestamp when convenient; not before **7**/**8**/**39**. |
| **15** | **applied 2026-08-19** | **confirmed exactly** — Value64 ALLOC (~10704) interns `w`/`s`/`p`. Tagged KEYEVT sets the same ids at ~8599-8601 but the `hp_qt_ff[0]` ternary at ~8603-8610 lists only 13/32/37/39/38/40/65/68 — **w/s/p (87/83/80) fall to type 5**. Both arms live in the **parent**, not exec32, so Cut A does not delete them; `jsb_flags[3]` just makes the tagged one unreachable. **APPLIED** — 87/83/80 added to the tagged `hp_qt_ff[0]` list. | KEYEVT tagged ~8599/8603 vs Value64 ~10704 | Tagged `e.key` for w/s/p is the wrong tag. Value64 HTML is OK. | DONKEY WASD/pause work on Value64. Tagged twin would miss them. | Extend tagged `hp_qt` ternary with 87/83/80 (or let Cut A strand it). |
| **16** | open | **keep** — depth 16 or coalesce downs. | kev FIFO ~6172 | Depth 8; drop on full. | Start key lost. | Depth 16. |
| **17** | open | **keep** — drop + `dbg_lis_ovf`, not fault 3. | exec64 addEventListener ~3999 | 16 total / 4 per type → halt. | Halt on noisy bind. | Drop, don’t halt. |
| **18** | **corrected** | Tagged WAIT_FRAME rewind is **retired** (~8482); that arm now starts `S_GC_CLEAR`. Do **not** put `n_obj <= n_obj_keep` back. Leftover: keep watermarks + GC completeness (**30**). | HEAP keep tasks; WAIT_FRAME ~8475 | Was: nursery rewind recycled live oids. Now: mark/sweep on the tagged arm; Value64 GC after FRAME_TIMER. | Old freeze was `raf=0` / fault 4. | Finish root GC; never skip gen. |
| **19** | **corrected** | Alias decode **gone** (`{aid[10:0], slot[4:0]}` ~1129). Caps still `OBJ_SLOTS=32` / `ENV_SLOTS=16` / `ARR_CAP=128` / short 32. Loud overflow on those caps is leftover, not this bug. Do **not** restore `aid[9:0]`. | parent ~1129 | Was 1024..1535 → 0..511. | PACMAN `map[0]` alias would have been wrong length. | Keep new decode. Loud overflow if you touch caps. |
| **20** | open | **keep** — skip GET until `fb_dirty`; skip cache if `nz==0`. Do not add a second `imgd_pix`. | `S_IMGD_GET` ~9601 | One snapshot buffer. PACMAN `map.cache` can copy empty glass. | Permanent black maze. | Policy, 1 px/clk stays. |
| **21** | open | **keep** — loud overflow; every JSON state must advance. `dbg_json_ovf` still faults 3 (~13895). | JSON_CAP 8192 | Overflow / truncate → halt. | Leaderboard / PACMAN `JSON.stringify(map.data)` hang. | Keep loud; no stuck state. |
| **22** | **corrected** | Extra beat is required. `hash2_q` two-beat wait is **in** (~6147). Do not delete it. | String.replace ~6129 | Was: missed wait restarts FIND. | Was hang. | Keep beat. |
| **23** | open | **keep** — stub `toISOString` (INVADERS save ~122). localStorage already stubbed. LOOKFN miss returns the Date object (builtin 3), so save does **not** throw — `at` is wrong, stringify may bloat (**21**). | `new Date().toISOString()` | No CALL_METH `toISOString`. PYTHON intern-stubs a UTC string from `vframe_no`. | Uncaught only if stringify faults. Not splash. | Stub method; intern one clock string; no ALLOC per call. |
| **24** | **slow** | Extra beat is the Port A settle. Removing it hangs. Faster only if `.length` still waits `name_blen`/`varr_len` `*_rdata`. | GET_PROP `.length` extra beat | One extra clock per `.length`. | Hang if the wait is deleted. | Keep the wait; do not combo-peek. |
| **25** | **corrected** | Miss → undefined + `hs_st(S_FETCH_WAIT)` **is in** (proto miss ~12166). New miss paths must still FETCH. Do **not** drop `cls_done` with no `hs_st`. | `S_HEAP_CMP` ~12166 | Was: miss restarted `cls_scan`. | Was hang `HEAP_CMP` `fault=0` (`{n:1}.missing`). | Keep the FETCH arms. |
| **26** | open | **keep, but 51 first** — fail loud if not ASET. Keep gen. A **hit** that then no-ops in `S_BLIT` is **51**, not this. | drawImage ASET ~5780 | Miss paints nothing (`dbg_di_miss++`, FETCH). | DONKEY sheets blank **on miss**. Hit + blank is **51**. | Loud miss. |
| **27** | open | = HTML design. Enter already interned (**15**). Title **and character-select** have no rAF (`DONKEY.HTML` `update` ~1059: only `gameState=="game"` re-arms). Silicon `raf=0` after splash / after first Enter. No `"DONKEY"` gate. | DONKEY `update()` | Parks in `WAIT_FRAME` until Enter (title→character) then Enter again (character→game). | Looks frozen after splash. Correct JS. | KEYEVT must deliver `"Enter"`. Second Enter starts play. |
| **28** | open | = **1** | fillText intern FIND | `"SCORE "+n` → CONCAT + FIND. | Same as 1. | Fix 1/2/3. |
| **29** | open | = **G1** + FIND | INVADERS `drawBitmap` | Per-lit-pixel `fillRect`. | Stacks with FIND over the cap. | No sprite ROM. |
| **30** | open | **keep** — drop invalid timer fn; never skip gen. FRAME_TIMER pushes `vtimer_fn_rdata` with no `vfn_valid`/gen check (~13755). | GC every WAIT_FRAME / FRAME_TIMER | Stale timer fn → fault 4. | Halt. | Drop + keep gen. |
| **31** | **corrected** | Both host exits require `st==16`. Swap path omits `frame_continue` on purpose (stuck 32-bit `frame_fire` would block every Value64 frame). Do **not** drop `st==WAIT`. Idle 2000 stays for no-rAF splash (**27**). | `sim/sim_main.cpp` ~1910 / ~1935 | Was: present-exit during EXEC/GC cut the callback. | Was: splash died / rAF cut. | Keep `st==16`. Optional: merge the two `if`s. |
| **32** | **partial** | Defaults are black. Unknown CSS still `8'd1` (white) at the final `else` (~5117). **Mechanism verified:** `fill_lut` is not a hardcoded map — the compiler streams an **FSTY** trailer row for *every interned name* `parse_css_color` accepts (`jsb_format.py` ~1046-1062, `canvas_engine.py:102`), and `heap_clr` presets the LUT to `8'hFF` (~6734). So the white `else` is reachable **only** for a color string built at runtime (a fresh intern id with no FSTY row). | exec64 SET_PROP ~5100-5117 | Unknown `fillStyle` → white. | Checked every title: all `fillStyle`/`strokeStyle` values are literals or variables holding literals (MRDO `dirtBright()`/`dirtLine()` return literals). **No current title can reach it.** | Leave as-is, or make the unknown case loud. Do not hardcode a hex map. |
| **33** | open | **revise — PYTHON does not blend.** `js_vm.py` ~2296 reads `globalAlpha` and **only** does `if method == "fillRect" and alpha_f == 0.0: return undefined`. It ignores alpha on `drawImage`, `stroke`, `fillText`, path fill. So scaling RECT/glyph writes would **break** parity, not restore it. | exec64 SET_PROP / RECT | RTL has no `globalAlpha` latch at all (no `id_globalalpha` in either exec or parent). | INVADERS' three uses (~174/193/195) are on `drawImage` and `stroke` — **PYTHON paints those fully opaque too**, so silicon matches today. Low, glass only. | Latch alpha on SET_PROP; skip the `fillRect` arm when alpha==0. Nothing else. Do **not** add a 0/25/50/75/100 scale. |
| **34** | open | **revise — alpha only.** One-deep transform stack is in (`saved_*` ~5645/5656). PYTHON `save` stores exactly `(_tx,_ty,_sx,_sy, globalAlpha)` — it does **not** save fillStyle / strokeStyle / textAlign, so adding those diverges. Verified titles never nest: save/restore counts are 1/1 in INVADERS (~172-198) and 1/1 in PACMAN (~358/361), 0 elsewhere. `rotate` is a PYTHON no-op; exec64 LOOKFN-miss returns the ctx — same visual. `translate` **is** in exec64 (~5665). | exec64 `id_save`/`id_restore` | `save`/`restore` copy tx/ty/sx/sy. PYTHON also saves `globalAlpha`. | Only matters once **33** latches alpha. Not a freeze. | Add **alpha and nothing else** to the existing 1-deep FFs. No stack SRAM. Do not implement rotate. |
| **35** | **slow** | Overlay first beat is idle because `vst_raddr` follows `state`, not `casestate` (~2491). Faster only if raddr is valid the same cycle without combo-peek. | RECT_LD / WIN_FILL / BIND | First-entry latch ignores rdata (`state != SELF` / `vst_refill_ret==IDLE`). Extra clocks. | Wrong stack word if beat 0 consumes `vst_rdata`. | Keep the latch unless raddr is fixed first. |
| **36** | **applied 2026-08-19** (truncation half) | **revise — two defects, not one.** (a) truncation, (b) **no font scale**: `machine.py:898 _nat_measure_text` returns `len(t) * 8 * _font_scale(font)`; exec64 does `vmetrics_w_n = (tl << 3)` (~5862) with `tl = {8'd0, name_blen_rdata[7:0]}`. **APPLIED (truncation half)** — full u16 `name_blen_rdata`. Font scale still blocked on **45**. | exec64 `measureText` ~5841-5862 | Width is `name_blen_rdata[7:0] * 8`. PACMAN `measureText` ~1024; DONKEY ~966 area. | HUD/button width wrong for any scaled font, and for intern len ≥256. Not a freeze. | `{8'd0, name_blen_rdata} << 3` **times the same `txt_k`** the parent computes (~9335-9343). Blocked on **45**. |
| **37** | open | **revise — not a PYTHON parity hole.** `machine.py:889 _nat_fill_text(t,x,y,style,align,font)` has **no baseline argument**, and `js_vm.py` never reads the property: PYTHON is alphabetic-only too. This is a divergence from real browsers in **both** models. `textAlign` **is** latched (`id_textalign` ~5127). Assignment lives in `S_TXT_LD`'s default phase (**~9438**), not `S_TXT_DRAW`. | parent `S_TXT_LD` ~9438 (shared by tagged + exec64) | `txt_y0 <= txt_py - 8*txt_k` always. PACMAN sets `middle`/`top`/`bottom` and twice the **invalid** `'center'` (~1214, ~1239). | Title/HUD/PAUSE sit on the wrong Y — in PYTHON as well, so PYTHON is not the reference here. Not a freeze. | `ctx_baseline` FF (0=alphabetic, 1=top, 2=middle, 3=bottom); latch on SET_PROP; adjust `txt_y0`. **Ignore** unknown strings (keep the current baseline) — that is what browsers do with `'center'`, and PACMAN sets it right after `'top'`/`'bottom'`. Port A legal. |
| **38** | open | **new — confident** — parent `S_PWALK` already rasters `pc_op==2` via `S_QSEG` (~7587). exec32 records it (~4393). exec64 CALL_METH has **no** `id_quadcurve` port/arm. LOOKFN miss returns the ctx (builtin 5) — no fault, no path cmd. | exec64 CALL_METH path ~6239 | `quadraticCurveTo` is a no-op on Value64. | PACMAN ghost skirts missing (HTML ~1349). Maze walls are `lineTo`/`arc` (OK). | Copy exec32 `pc_op_wdata=2'd2` arm into exec64 (same `argc>=4`, `v64_to_fx`). Wire `id_quadcurve` like exec32. |
| **39** | open | **revise — do not widen `vfe_mode`.** See Review addendum “Better 39”: 1-bit `vfe_reduce` + store acc in `vfe_map` (forEach already leaves it UNDEF). INVADERS also requires `grids.length === 0`; `undefined === 0` is still false, so waves never clear. | exec64 CALL_METH array ~5400 | `grids.reduce((t,g)=>t+g.invaders.length,0)` is undefined. | INVADERS `checkVictory` (~610, called ~1167 every play frame): `totalInvaders === 0 && grids.length === 0` never true. Play keeps ticking. | 1-bit flag + acc in `vfe_map`. Same `0xfffc` as forEach (**6** applied). |
| **40** | open | **new — confident, save-only** — no `id_slice` in exec64. Same undefined return as **39**. PYTHON copies `[a:b]`. | INVADERS `list.slice(0,10)` ~126 | Leaderboard keep-10 is undefined. | Save path only. `setLeaderboard(undefined)` → stringify. Not splash. | HEAP copy arm, one slot/clock, like splice subset. |
| **41** | open | **new — confident, save-only** — no `id_sort` in exec64. PYTHON runs the comparator. | INVADERS `list.sort((a,b)=>b.score-a.score)` ~125 | Order is wrong / undefined. | Save path only. | After **39** (comparator CALL). Or no-op + keep list if you only need play. |
| **42** | open | **new — confident, monitor** — `jmr_console_engine.sv` C_EXEC has no `INSERT`. PYTHON `_cmd_insert` and FPGA-SIM `sim_backend.py` mutate the host editor, then still `LINE` the verb → RTL `?SN ERROR`. | READY `INSERT n` | Silicon glass `?SN`. Host RUN can still compile the mutated HTML (split-brain vs LIST/SAVE SOURCE). | Add C_INSERT (shift SOURCE one line, like EDIT grow). Or stop sending INSERT to RTL and print OK from the host only (lies on board). |
| **43** | open | **new — confident, monitor** — RTL verb is `REMOVE "NAME"` (FAT delete). No `DELETE n` line editor. PYTHON aliases `REMOVE`→`DELETE` for files; `DELETE n` is the editor. FPGA-SIM host deletes `_html_lines` then RTL `?SN`. | READY `DELETE n` | Same split-brain as **42**. | Add C_DELETE (shrink SOURCE). Keep `REMOVE` for the file. HELP must list both. |
| **45** | open | **confident, glass — but the fix is bigger than "FF only".** Parent interns `id_font` (~6879) and routes it to **exec32 only** (~3088). exec32 SET_PROP (~3453) seeds `name_rdaddr`/`fp_left`/`fpx_acc`/`ctx_font_px=8` and jumps to the **parent** state `S_FONTPX` (~9283), which walks `name_mem` a byte per clock. exec64 has no `id_font` port and no arm, so Value64 titles keep `ctx_font_px==8` → `txt_k==1`. The parent already implements the whole PYTHON `_font_scale` (`txt_kp = ctx_font_px * ctx_sx`, ~9335-9343). | PACMAN `context.font` ×12 (HUD ~992, ~1183-1242, ~1482); **DONKEY.HTML:966** `ctx.font = '16px …'` | All Value64 glyphs stay 8×8. Not a freeze. | exec64: add the `id_font` port, a SET_PROP arm seeding `name_rdaddr = name_off_rdata` / `fp_left = name_blen_rdata[7:0]` / `fpx_acc = 0` / `ctx_font_px = 8`, then `state_n = S_FONTPX`. Needs **three new exec64→parent handshake outputs** (or a first-entry latch in parent `S_FONTPX`, which it does not have). Do not combo-walk `name_mem`. |
| **46** | **RETRACTED — false positive** | **Do not implement.** The claim was "`S_V64_FRAME_TIMER` fires one timer per frame because the `0xfffe` return re-enters with `bind_k == 65`". `bind_k` does **not** survive the callback: **every** callback dispatch goes through `S_V64_ALLOC`, whose direct-BIND branch sets `bind_k <= 8'd0` (~10346) and whose other branch reaches `S_V64_CTOR_PAD`, which does the same (~11917). So on return `bind_k` is 0 (or a small param count), the `bind_k < 8'd64` scan **restarts**, and the next due timer fires. **The RTL already drains every due timer per frame**, the same way `S_V64_FRAME_KEY` does with `vkey_li` and `S_V64_FRAME_RAF` does with `vraf_i`. | — | — | Residual, unchanged from PYTHON: >64 timers alive in one frame is still `machine_fault` 3 in both models. A `setTimeout(fn,0)` is due at `vframe_no + 1`, so a frame's timers drain on the **next** frame — queue depth is one frame of arming, not a runaway. | None. Left in the table so it is not re-filed. |
| **47** | **applied 2026-08-19** | **NEW — confident.** Parent `vfe_arr_s` / `vfe_fn_s` / `vfe_map_s` (~294/295/304) are **never written anywhere in the parent** — grep shows only the three GC reads. The live nest stack is exec64's own (`vfe_arr_s[vfe_s_waddr] <= …` ~1963, pushed at ~5466-5476, popped ~2287 whose comment states *"parent `vfe_arr_s` is empty"*). **APPLIED** — push mirrored into the parent shadow stack at the `S_V64_FOREACH` first entry. | `S_V64_GC_ROOT` phase 7 ~11005-11020 | GC marks 8 stale/UNDEF parent words instead of the real outer-walk roots. Top-of-nest is fine (`S_V64_FOREACH` first entry latches `vfe_arr/fn/map` from `e64_*_q`, ~11355-11360); **only nested walks lose their roots.** | Mid-walk GC is reachable and non-halting: `S_V64_ALLOC` retry, `S_FREE_ARR` (exec64 ~5440), JSON (~11552, ~11766) all enter `S_V64_GC_CLEAR` with `vgc_halt_after=0` and resume (~11218). INVADERS nests 3-4 deep (`grids.forEach` ~1043 → `grid.invaders.forEach` ~1063 → `projectiles.forEach` ~1085 → `.find` ~1095). Swept `vfe_fn` → fault 4 on resume; swept `vfe_map` → `map`/`filter` writes into a recycled array (silent corruption). | Mark the **exec64** stack: mirror `vfe_*_s` into the parent on `vfe_s_we`, or add read ports and walk exec64's copies in root phase 7. One slot per clock. Keep gen; do not widen the sweep. |
| **49** | open | **revise — 9 strobes are not enough.** See Review addendum “Better 49”: first-entry `hs_st(S_PWALK)` like `S_TXT_LD`, latch `color`/`path_stroke`/`pi`/`ctx_*`, and put the raster states in `hs64` (or `hs_ip`+`hs_code` from `e64_ip_q`). fill/stroke never sets `code_raddr_n`. Overlay beat `pi >= pc_n` still aborts if you only NBA `pc_n` the same clock. | `S_PWALK` ~7528 vs exec64 `pc_we` ~1863 | Parent `pc_*` has no writer; `pc_n`/`path_active` only clear at RUN. exec64 fills its own arrays then `state_n = S_PWALK`. | **`beginPath` / `moveTo` / `lineTo` / `arc` / `fill` / `stroke` paint nothing.** PACMAN maze/ghosts; ASTEROID; MRDO; INVADERS shield. Not a hang. Invalidates **G2**/**G4**/**G6**. A strobe-only fix then stale-`ip` re-fill would hang. | Mirror `pc_we` **and** first-entry / `hs64` as in the addendum. Do **38** and **51** in the same pass (same latch pattern). |
| **50** | **RETRACTED — my error, do not act on it** | Claimed the compiler's inliner made `scale`↔`extras` and `y`↔`i` alias because `_var_a1` packs `a1 = 2+slot` and the inlined body restarts slot numbering. **The premise was false: the RTL does not address locals by that slot.** `OP_LOAD_VAR` issues `HP_GETPROP` with `hp_key_n = {7'd0, code_rdata[16:8]}` — **the name id is the key** — and uses `hp_slot_n = a1 - 2` only as a *scan start hint*. That is the same name-keyed lookup PYTHON does (`js_vm.py:_value64_load_var`, "Dict is still keyed by name id"). Different names cannot collide, so there is no aliasing. Verified further: both `extras` and `i` are properly declared (`LET_VAR ... a1=1` at 2272 / 2304), their scan-start hints (0 and 1) match their real env indices, `LET_VAR` overwrites an existing key rather than appending, and env overflow is a loud fault 3 (`venv_len >= ENV_SLOTS`, ~12377) which the trace does not show (`fault=0`). | — | — | **One compiler, one ProgramImage, both executors resolve locals by name.** The FPGA does **not** need its own compiler for this. | None. Kept only so the wrong theory is not re-derived. The real cause of the INVADERS freeze is still **open** — see the note under the edits table. |
| **48** | — | **NEW — checked, shared cap, NOT a silicon bug.** exec64 `push` faults 3 when `varr_len + argc > ARR_CAP` (128) (~5326); `js_vm.py` ~2337 raises the identical fault at `ARRAY_ELEMENTS = 128`. Parity. | exec64 `id_push` ~5325 / `js_vm.py` ~2336 | INVADERS `particles` = 24 permanent stars + 8 per explosion, with the splices deferred by **46** → can cross 128. | Both models halt. Product cap, not debt. **Fixing 46 keeps the array bounded**; do not raise `ARR_CAP` to paper over it. | None. Listed so it is not re-filed as a new bug. |
| **51** | open | **NEW — confident, same class as 49.** Parent `S_BLIT` (~8196) has no `state != S_BLIT` latch. exec64 hit (~5834) plants `rw_n`/`blit_si_n`/`state_n = S_BLIT` and does **not** set `code_raddr_n`. Parent `rw`/`blit_si`/`blit_sx` are never assigned from `e64_*_q` (`blit_si <=` does not exist). `rw==0` → immediate FETCH, `dbg_di_hit++`, 0 pixels. | `S_BLIT` ~8196 vs exec64 drawImage ~5755 | Value64 `drawImage` 3/5/9 is a silent no-op on **hit**. | DONKEY title/play sheets blank (handoff `nz0=0`). INVADERS explosions / `translate`+`drawImage`. Not **26** (miss), not **27** (rAF park), not **50** (compiler loop). **G3** never runs. | First-entry latch of `e64_rw/rh/rx/ry/x/y` + `e64_blit_*` + `hs_ip`/`hs_code` from `e64_ip_q` (or add `S_BLIT` to `hs64`). Same pass as **49**. Loud **26** stays for real misses. |

**Other agent (not a freeze):** `ctx_align <= 0` on exec64 `p_clr` **corrects** the cross-title `textAlign` leak. It does not fix **10** or **37**.

**Checked, not a new ID:** `Math.PI` compiles to `LOAD_CONST` (not a GET_PROP). `translate` is in exec64. `rotate` is a PYTHON **no-op** (exec64 LOOKFN-miss returns ctx — same). `Array.fill` / `unshift` / `assign` / `bind` / `forEach` / `map` / `filter` / `join` / `indexOf` / `replace` are in exec64. `console.log` is a bounded counter (DONKEY `Mario.update` log is cheap). `closePath` is after `fill` in PACMAN ghosts. Optional chaining / templates / `for-of` are compiler → ordinary ops. `joy()` is JOYDEMO only. `lineWidth` stores on HEAP; PYTHON `_line` and RTL `S_LINE` are both 1 px — not a parity hole. `String.split` is PYTHON-only; no title emits it.
**PACMAN's rAF polyfill (~24-46) is inert in silicon and harms nothing:**
`window.requestAnimationFrame` compiles to `LOAD_VAR window` + `GET_PROP`
(`compiler.py` ~1612 only keeps `window.x(...)` as a native **call**), the
receiver is an interned *string*, and the exec64 string-handle GET_PROP arm
returns `V64_UNDEFINED` for anything but `.length`/`.now` (~4907-4942). The
four `window.* =` / `Date.now =` assignments are SET_PROP on a primitive,
which exec64 correctly no-ops (~5081-5093). The regex literal is a
`LOAD_CONST` (`compiler.py` ~1497) and `.test()` is a LOOKFN miss → undefined.
Every call site is bare `requestAnimationFrame(fn)` → `CALL_NATIVE` nid 27
(~339, 386, 388, 1514). So the polyfill never installs — which also retires
the old "PACMAN rAF polyfill reads `Date.now`" motivation under **14**.
**`e32_name_*_tos` are parent-owned**, not exec32 outputs (parent read-port
mux ~5627-5653); the Value64 FIND/CONCAT/TXT paths depend on them, so Cut A
must keep the mux and retire only the `e32_intern_tos` default.
`Array.findIndex` is interned by the parent (~6836) and has no exec64 arm —
same undefined return as **39** — but **no title emits it**, so no ID.

---

## Compatibility command map (inspection only)

Compat **Complete** = JsHwVm. This table is silicon vs that claim. **NOT** =
no RTL verb/method arm (LOOKFN-miss / undefined / `?SN`). **never** = do not
build. **host** = FPGA-SIM Python helper, not the console FSM.

### Monitor (READY)

| Command | PYTHON | FPGA-SIM / board RTL | Bug |
|---|---|---|---|
| `DIR` | in | in (`C_DIR*`) | — |
| `LOAD "NAME.HTML"` | in | in (`C_LD_*`; FPGA-SIM `SRCLOAD` skips FAT) | — |
| `RUN` | in (host compile-on-RUN) | in (`C_JSB_TETHER`). On-chip compiler **NOT**. Missing stream → `?NH` / `?NB` | debt, not a play ID |
| `LIST` / `LIST n-m` / MORE | in | in (`C_LIST*` / `C_LIST_MORE`) | — |
| `EDIT n` | in | in (`C_EDIT*`) | — |
| `INSERT n` | in | **NOT** (host mutates `_html_lines`, RTL `?SN`) | **42** |
| `DELETE n` | in | **NOT** (RTL has file `REMOVE` only) | **43** |
| `REMOVE "NAME"` | alias of file DELETE | in (`C_RM`) | — |
| `SAVE` | in | in (`C_SV_*`) | — |
| `NEW` | in | in (clears SOURCE + `halt_pulse`) | — |
| `CLS` | in | in (`C_CLS`) | — |
| `HELP` | in (lists INSERT/DELETE) | in (prints `DIR LOAD SAVE NEW LIST EDIT RUN` only) | **42** **43** HELP text |
| `MEM` | in | in (prints `FB 640X480`) | — |
| `ESC` | in (BREAK) | in (`kbd==0x1B` clears `game_mode`) | — |

### HTML / host builtins (titles emit these)

| API | PYTHON | exec64 | Bug |
|---|---|---|---|
| `<canvas>` / `<script>` / `getElementById` / `querySelector` / `createElement` | in | in (nids 16–18) | — |
| overlay `hidden` / `style.display` stub | in | in (`id_disp`) | — |
| `data:image` → ASET | in | in (stream + blit) | **26** miss; **51** hit is also silent |
| `requestAnimationFrame` | in | in (nid 27) | **5** done; **9** cap; **6** leftover rAF |
| `setTimeout` / `clearTimeout` / `setInterval` / `clearInterval` | in (drains **all** due per frame) | in (nids 28–31); **also drains all due** (**46** retracted) | **30** stale timer fn |
| `addEventListener` / `removeEventListener` | in | in | **17** halt at 16/4 |
| `dispatchEvent` + `new KeyboardEvent` | in | in (`NEW_OBJ` + nid 38/39) | — |
| `keydown` / `keyup` (`e.key` / `keyCode`) | in | Value64 intern `w`/`s`/`p` **in**; tagged leftover | **15** tagged only |
| `Image` + `src` + `onload` | in | in | — |
| `localStorage.*` | in (RAM) | in (RAM) | — |
| `Date` / `Date.now` / `getTime` | in | CALL_METH nid 35 / `vframe_no` **in**; bare `.now` read is undefined (**14** applied) | **14** (low, done) |
| `Date.prototype.toISOString` | intern stub | **NOT** | **23** |
| `JSON.parse` / `stringify` | in | in | **21** cap halt |
| `Math.floor/abs/min/max/random/sqrt` | in | in (nids 10–15) | — |
| `typeof` | in | in (nid 40) | — |
| `console.log` / `warn` | in | in (nid 0, counter) | — |
| `window.open` | **never** (`_stub`) | **never** (nid 33) | — |
| `Audio` / `.play` | **never** | **never** | — |
| `eval` / `async` / `fetch` / Workers / Node | **never** | **never** | — |

### Language methods (Frozen ISA)

| Method | PYTHON | exec64 | Bug |
|---|---|---|---|
| `push` / `pop` / `unshift` / `splice` | in | in | — |
| `forEach` / `map` / `filter` / `find` | in | in | **6** first `0xfffc` |
| `join` / `indexOf` / `replace` | in | in | **1** **2** **4** **22** done |
| `fill` (Array) / `assign` / `bind` | in | in | — |
| `Array.reduce` | in | **NOT** (returns undefined) | **39** |
| `Array.findIndex` | in | **NOT** (parent interns `id_findindex`, no exec64 arm) | no title emits it |
| `Array.slice` | in | **NOT** | **40** |
| `Array.sort` | in | **NOT** | **41** |
| `RegExp` / `replace` stub | in | in | **22** done |
| `class` / closures / IIFE flatten | in | in | **7** **8** nested `new` |
| `String.split` | in | **NOT** | no title emits it — do not grow |

### Canvas (`getContext("2d")`)

| API | PYTHON | exec64 | Bug |
|---|---|---|---|
| `getContext` / `fillRect` / `clearRect` | in | in (CALL_METH) | **12** nid-2 ignores transform |
| `fillStyle` / `strokeStyle` | in | in (separate latches) | **32** unknown CSS → white |
| `drawImage` 3/5/9 | in | records in exec; parent `S_BLIT` never latches | **51** (hit no-op) **26** (miss) **G3** |
| `beginPath` / `moveTo` / `lineTo` / `arc` / `fill` / `stroke` / `closePath` | in | records in exec; parent `S_PWALK` empty | **49** (no paint) **G6** |
| `quadraticCurveTo` | in | **NOT** (LOOKFN miss) | **38** |
| `lineWidth` | store; stroke 1 px | store; `S_LINE` 1 px | not a parity hole |
| `imageSmoothingEnabled` | in (nearest) | in (latch, blit nearest) | — |
| `fillText` | 8×8 × font scale | 8×8; font scale **NOT** | **28** **45** **G8** |
| `measureText` | `len*8*_font_scale` | full `name_blen` (**36** applied); **no scale** | **36** (needs **45**) |
| `font` | in | **NOT** (no exec64 arm) | **45** |
| `textAlign` | in | in (`ctx_align`) | — |
| `textBaseline` | **NOT** (`_nat_fill_text` has no baseline arg) | **NOT** (`txt_y0` alphabetic) | **37** (browser gap in both) |
| `setTransform` / `translate` | in | in | — |
| `rotate` | **no-op** | LOOKFN miss (same visual) | **34** |
| `save` / `restore` | tx/ty/sx/sy + alpha (nothing else) | tx/ty/sx/sy only | **33** **34** |
| `globalAlpha` | **skip `fillRect` at alpha==0 only** — never blended | **NOT** latched | **33** (low) |
| `getImageData` / `putImageData` | in | in (one `imgd_pix`) | **20** **G9** |
| `canvas.width` / `height` | in | in | glass stays 640×480 |
| `strokeRect` | **in** (`machine.py:902 _nat_stroke_rect`, 4 edges) | **NOT** | no title emits it — do not grow |
| `clip` / `scale()` / `bezierCurveTo` / gradients / WebGL | **never** (V1) | **never** | — |

### Asset / input (not JS verbs)

| Item | PYTHON | FPGA-SIM | Bug |
|---|---|---|---|
| Compile-on-RUN ProgramImage | in (host) | host stream into code BRAM | on-chip compiler **NOT** |
| ASET → 4 MB SRAM | in | in | **26** |
| Dual FB 640×480 | in | in | **G10** 307k clk |
| Raw keys | in | in (FIFO depth 8) | **16** |
| Joystick bits | in | in (`joy_in`) | JOYDEMO only |

---

## Graphics that look like a freeze (HTML → RTL)

These are not infinite FSMs. They are **O(pixels × JS calls)** on a 1-pixel-per-clock raster. A painted frame that **finishes** should end via **31** (present), not the host cap. G1/G8 look hung when stacked with a real spin (**6**) or a method that never returns to WAIT (**39** is logic, not clocks). FIND (**1**) is extra k-clocks, not the cap by itself.

| ID | Status | Fix check | HTML (function) | RTL | Cost | Best fix (VM-wide) |
|---|---|---|---|---|---|---|
| **G1** | open | **keep** — optional “1-bit row run” is language, not an INVADERS ROM. Keep 1 px/clk. Intern `"1"` should last-4 hit after the first cell. | `INVADERS.HTML` `drawBitmap()` ~83 | `RECT_LD` 2 clk/arg × 4, then `S_V64_RECT` 1 px/clk. `fillStyle` once per sprite, not per cell. | ~2k × (8 + ~9 px) ≈ 40k, plus a 307k clear. Looks slow if the callback never parks. | Host predicate first (**31** in). |
| **G2** | open | **keep** — don’t snapshot until `fb_dirty`. Stroke arcs = **G6**. Keep 1 px/clk clears. | `PACMAN.HTML` `Stage.start` ~344; `map.cache` ~360; maze `draw` ~1088 | CLEAR/RECT 307k; `S_IMGD_*` 307k; `S_CIRCLE` bbox `(2r)²`. | Alone ~1–2M (OK). + FIND + **6** + **14** → cap. Empty cache = black (**20**). | Policy + G6. |
| **G3** | open | **51 first** — blit never runs on Value64 today (`rw==0` abort). After **51**, one outstanding ASET req is legal. Title/character park is **27**. | `DONKEY.HTML` `update()` ~1059 | `S_BLIT` 2 clk/px (`sram_ack`) — **unreachable** until **51**. | 0 today; ~0.1–0.5M after. | Latch exec blit scalars, then pipeline ack if Port A allows. |
| **G4** | open | **keep** — clip once; wrap by modulo of points. Not an ASTEROID gate. | `ASTEROID.HTML` `strokeClosed` ~354 / `drawRockWrapped` ~373 | `S_LINE` 1 px/clk × 5 copies × N rocks. | Hundreds of k + FIND HUD. | Clip, don’t 5-stroke. |
| **G5** | open | **leave** — proof full-glass fillRect is playable when FIND is cheap. | `AURORA.HTML` `wipe()` ~60 | `S_V64_RECT` 307k. | ~0.3M. Not a freeze. | None. |
| **G6** | **partial** | **keep** — outline via `path_stroke \|\| d2 >= r2in` is **in** (~7441). Still walks every bbox pixel. Bresenham / octant would be faster. Fill stays bbox or scanline. | PACMAN / ASTEROID `arc`+`stroke`; MRDO tunnel | `S_CIRCLE` ~7422 visits **every bbox pixel**. | r=16 → ~1k; maze × many cells. | Outline walk. |
| **G7** | open | = **G1** | `MRDO.HTML` `drawPix()` ~1258 | Same RECT_LD+RECT. | Field redraw looks hung. | FIND + language blit, not a MRDO ROM. |
| **G8** | open | = **1** — glyph `S_TXT_DRAW` ~9422 is cheap. Last-4 misses when `n` changes, then one linear walk. | All HUD `fillText("SCORE "+n)` | CONCAT + FIND then 8×8×k² on-pixels. | ~2k clocks per new HUD string, not the cap. Hash collision is **2**. | Byte-confirm FIND. |
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
| **25** HEAP miss → undefined + FETCH | **Corrected** | New miss paths must still `hs_st(FETCH)`. Dropping the arm loops `cls_scan` |
| **35** overlay first beat idle | Slow (1 extra clock on RECT_LD / WIN_FILL) | Do not consume `vst_rdata` until `state` matches and raddr is that slot |
| Other `*_rdata` waits | Slow | Same Port A rule as 24/35 |
| 1 pixel/clock FB write | Slow (307k for a full clear) | Another write port is fine. `fb[i] <=` in the 7k FSM is 70 GB synth |
| One `stack_wr` per clock | Slow (FOREACH el then idx) | Two writes one cycle needs a second RAM port (`stack_dual_pend` is the extra clock) |
| Port A `if (we) mem[waddr] <= wdata` | Legal SRAM | Faster heap is fine; `stack[i] <=` in the FSM is the 70 GB hang |
| FRAME cap (now 8M in `sim_main.cpp`) | Host timeout, not a speed knob | Raising it hides unfinished rAF; GUI sits on the RPC |
| Nursery rewind `n_obj <= n_obj_keep` | Old “faster GC” | Recycles live oids. Tagged arm already uses `S_GC_CLEAR` |
| `varr_slot_addr` `aid[10:0]` | **Corrected** decode | `aid[9:0]` aliases 1024→0 |
| exec64 `ctx_align <= 0` on `p_clr` | Correct reset | Without it DONKEY `center` leaks into the next title |
| `leave_hold` not in enable=0 else | Correct | Putting it in that else deadlocks `eip=0` |
| One timer per frame (**46**) | **Not** slow — a correctness cap | Draining the whole due set costs clocks per frame; that is legal. Do not raise `TIMER_QUEUE_DEPTH` instead |
| `ARR_CAP` 128 push fault (**48**) | Shared product cap | PYTHON faults at the same 128. Fix **46** so deferred splices land; do not raise the cap |
| Skip gen / clone heaps / title gates | Forbidden | Not a speed-up |

---

## Confidence (bug / fix)

High = seen in RTL with a single causal path from title HTML. Med = real hole, freeze story depends on another ID. Low = glass or overstated as a cap hang.

| ID | Bug | Fix | Why |
|---|---|---|---|
| **6** | **High** | **applied** | First `0xfffc` arm sits before the FOREACH arm. Fixed by adding a *guarded* arm ahead of it, **not** by deleting it — deleting drops `0xfffc` into the `vsp_hs != bsp` fault 1. |
| **38** | **High** | **High** | exec64 has no `id_quadcurve`; parent already draws `pc_op==2`. Copy exec32 arm. |
| **39** | **High** | **High** | `id_reduce` interned, never wired. CALL_METH returns undefined. INVADERS wave-clear is this compare. |
| **50** | **retracted** | — | Premise disproved: RTL env lookup is name-keyed (`hp_key_n`), the a1 slot is only a scan-start hint. No aliasing. |
| **49** | **High** | **High** (strobe **plus** first-entry/`hs64`) | `pc_*` has no writer. 9 strobes alone still abort on overlay (`pi>=pc_n`) or poke stale `ip` on the way out. See addendum. |
| **51** | **High** | **High** | Same overlay class as 49: `S_BLIT` never latches `e64_rw_q` / `e64_blit_si_q`. Hit is a no-op. |
| **46** | **retracted** | — | `bind_k` is zeroed by `S_V64_ALLOC` (~10346) / `S_V64_CTOR_PAD` (~11917) on every dispatch, so the scan already restarts and all due timers already drain. |
| **47** | **Med-High** | **applied** | Parent `vfe_*_s` were write-never; exec64 owns the nest stack. Bit nested walks + mid-walk GC — both present in INVADERS. |
| **14** | **Low** (was High) | **High** | Only `PACMAN.HTML:25 if (!Date.now)` reads it, once at load; `Date.now()` is CALL_METH and already allocation-free. |
| **2** | **High** | **High** | Hash+u8 compare is in the hit arm. Byte stream is the only legal confirm. |
| **37** | **Med** as glass | **High** | `txt_y0` is hard-coded — **but PYTHON is alphabetic-only too**, so this is a browser gap, not a parity hole. Judge it against the real browser, not against PYTHON. |
| **33** **34** | **Low** as glass | **High** | PYTHON only *skips* `fillRect` at alpha==0 and never blends; INVADERS uses alpha on `drawImage`/`stroke`, which PYTHON also paints opaque. RTL matches today. |
| **23** **40** **41** | **High** as save | **High** (23/40) / Med (41) | INVADERS `addScore` only. Play does not call them. |
| **42** **43** | **High** as monitor | **High** | C_EXEC has no INSERT/DELETE. Host editor lies. |
| **45** | **High** as glass | Med | `id_font` never enters exec64. PACMAN HUD + DONKEY ~966. Fix needs 3 new handshake outputs (or a parent `S_FONTPX` first-entry latch), not an FF. **36** rides on it. |
| **1** | High as slowness; **Low as sole cap** | High as hash→id | `2*names_n` ≤ ~2k. Last-4 hits `"1"` / repeated HUD. Cap is **6** or unfinished rAF. |
| **7** **8** | Med | High | Overlay/`leave_hold` **partial** in RTL. Nested `new` still PACMAN fault 2. Pending `fr` + latch; no `leave_hold` in enable=0 else. |
| **15** | **Low** for HTML play | **applied** | Value64 `w`/`s`/`p` were already in; the tagged `hp_qt` leftover is now closed. |
| **5** **31** | — | — | **Corrected.** Do not drop `st==16`. |
| **10** | Low for HTML | **applied** (reset half) | exec32 scale was in; `saved_*` now reset too. Silent rAF drop still open. |
| **13** | Low for Value64 PACMAN | High as hygiene | `getTime` uses `vframe_no`, which Value64 WAIT bumps. |
| **12** | Low for HTML play | High as hygiene | CALL_METH never plants. nid 2 still untransformed. |
| **32** | Low | High | Defaults black. Unknown CSS still white. |
| **20** **G6** | Med | High | Empty ImageData and bbox flood are in RTL. Policy / Bresenham, no second buffer. |
| **19** | — | — | Alias **corrected**. Do not restore `aid[9:0]`. |
| **22** **25** | — | — | Replace wait / FETCH arms **in**. Do not delete. |
| **24** **35** | Slow | Keep wait | Extra SRAM beats. Faster only if `*_rdata` is still valid. |

---

## Typed patches (high-confidence only)

**46 — RETRACTED, do not type it.** `bind_k` is zeroed by `S_V64_ALLOC`
(~10346) and `S_V64_CTOR_PAD` (~11917) on every callback dispatch, so the scan
already restarts on the `0xfffe` return and every due timer already drains.
The walkthrough below is kept only to show why the "one per frame" reading of
the state was wrong — the state *is* a three-way chain: 

```
if (state != S_V64_FRAME_TIMER)   hs_st(S_V64_FRAME_TIMER);   // overlay entry
else if (bind_k < 8'd64)          ...scan for best due...     // 2 clk / slot
else if (vt_found)                ...fire it, bind_k <= 65... // -> S_V64_ALLOC
else                              ...fb_swap + GC_CLEAR...    // present
```

The callback returns with `rip == 16'hfffe` → `state_n = S_V64_FRAME_TIMER`,
but the overlay entry only does `hs_st(...)`; `bind_k` is still 65 and
`vt_found` is 0, so the next beat falls into the present branch. **One timer
per frame.** In the fire branch, where it already does
`vt_found <= 1'b0; bind_rd_arm <= 1'b0;` before `hs_st(S_V64_ALLOC)`, also
re-arm the scan:

```
bind_k      <= 8'd0;
vt_best_due <= 32'sh7fffffff;
vt_best_id  <= 32'sh7fffffff;
```

so the return re-scans from slot 0 and presents only when a **full** scan
finds nothing due. **Termination is safe:** `vframe_no` does not advance
inside a frame, and both nid 28/29 clamp `frames >= 1`, so a timer armed or
re-armed by a callback is due at `vframe_no + 1` at the earliest and cannot
re-fire in the same frame. Cost is one 64-slot scan (~128 clocks) per fired
timer — ~8k clocks for a full queue, nothing against the 8M cap. Do **not**
raise `TIMER_QUEUE_DEPTH`; keep the `vtimer_n >= 7'd64` fault loud.

**47** — mirror exec64's forEach nest stack into the parent so GC can mark it.
exec64 already computes the push at ~5466-5476 (`vfe_s_we`, `vfe_s_waddr`,
`vfe_arr_s_wdata` / `vfe_fn_s_wdata` / `vfe_map_s_wdata`) and the parent
already has the symmetric **pop** handshake (`hs_m_vfe_pop`, ~11395 and
~13341). Export those four signals from exec64 and, in the parent, write
`vfe_arr_s[waddr] / vfe_fn_s[waddr] / vfe_map_s[waddr]` from them on the
strobe. Root phase 7 (~11005-11020) then marks real handles instead of
`'0`. Second choice — add read ports and walk exec64's copies directly — is
8×64b×3 of extra parent read mux for no gain. Either way: one slot per clock,
keep gen, do not widen the sweep. Nothing else in phase 7 changes.

**6** — **corrected patch.** Do **not** just delete the first `vframe_rip_rdata == 16'hfffc` block (~3206–3218). The `if/else if` chain is

```
if (vcsp_hs != 0) begin
    if (vframe_rip_rdata == 16'hfffc) ...GC_CLEAR...        // arm A, ~3206
    else if (vsp_hs != vframe_bsp_rdata) fault 1;           // ~3220
    else begin ... 0xffff / 0xfffe / 0xfffd / 0xfffc ... end // ~3262
```

so deleting arm A drops every `0xfffc` frame into the `vsp_hs != vframe_bsp_rdata`
fault-1 check — which is exactly the `one_fe nops fault 1` that arm A's own comment
says it was added to dodge (falling off `n_ops` normally leaves the last expression
value above `bsp`). **Replace** arm A's body with the `OP_RET_VAL` `0xfffc`
continuation (~4496): recycle the leaf env, `vthis_n = vframe_this_rdata`,
`venv_n = vframe_env_rdata`, `vcsp_n = vcsp_hs - 1`, `vsp_n = vframe_bsp_rdata`,
the `vfe_mode == 2'd2` `HP_ASETI` map-store of `V64_UNDEFINED`, then
`state_n = S_V64_FOREACH`. The later arm (~3262) then stays dead but harmless;
parent FOREACH-done (~11348) still pops any leftover frame whose `bsp == vfe_base+2`.

**38** — in exec64 `OP_CALL_METH`, after `id_lineto` (~6279), add the exec32 twin:

```
end else if (code_rdata[23:8] == id_quadcurve && argc >= 12'd4) begin
    if (pc_n < 5'(PATH_MAX)) begin
        pc_we = 1'b1; pc_waddr = pc_n[3:0]; pc_op_wdata = 2'd2;
        pc_a1_wdata = v64_to_fx(`VST_AT(base + 12'd1));
        pc_a2_wdata = v64_to_fx(`VST_AT(base + 12'd2));
        pc_a3_wdata = v64_to_fx(`VST_AT(base + 12'd3));
        pc_a4_wdata = v64_to_fx(`VST_AT(base + 12'd4));
        pc_n_n = pc_n + 5'd1;
    end else dbg_path_ovf_n = dbg_path_ovf + 16'd1;
    vst_wr(base, V64_UNDEFINED);
    vsp_n = base + 12'd1; ip_n = ip + 16'd1;
    code_raddr_n = 15'(ops_base + ip + 16'd1);
    state_n = S_FETCH_WAIT;
end
```

Wire `id_quadcurve` through the exec64 port list (parent already interns it). Do not add a second path SRAM.

**39** — do **not** use `vfe_mode==2'd4` (`vfe_mode` is 2 bits). 1-bit `vfe_reduce` + store acc in `vfe_map` (forEach already leaves it UNDEF). Seed from `VST_AT(base+2)`. Parent FOREACH push `acc, el, idx` when the flag is set. On `0xfffc` write TOS into `vfe_map`; walk-end `vst_wr(base, vfe_map)`. Extra clock for the third stack word (`stack_dual_pend` style). **6** is applied.

**49** — see Review addendum “Better 49”. Strobe mirror of `pc_we` is step 1. First-entry `hs_st(S_PWALK)` + latch `color`/`path_stroke`/`pc_n`/`pi`/`ctx_*` + `hs64` (or `hs_ip`/`hs_code` from `e64_ip_q`) is required or the walk aborts / re-fetches fill.

**51** — `S_BLIT` first-entry, same shape as `S_TXT_LD`:

```
if (state != S_BLIT) begin
    hs_st(S_BLIT);
    rw <= e64_rw_q; rh <= e64_rh_q;
    rx <= e64_rx_q; ry <= e64_ry_q;
    x  <= e64_x_q;  y  <= e64_y_q;
    blit_sx <= e64_blit_sx_q; blit_sy <= e64_blit_sy_q;
    blit_sw <= e64_blit_sw_q; blit_sh <= e64_blit_sh_q;
    blit_si <= e64_blit_si_q;
    hs_ip(e64_ip_q);
    hs_vsp(e64_vsp_q);
    hs_code(15'(ops_base + e64_ip_q));
end else if (rw == 10'd0 || rh == 10'd0) ...
```

Also set `code_raddr_n` on the exec64 hit arm (fillText already does). Add `S_BLIT` to `hs64` or keep the `hs_ip`/`hs_code` plant. Do not combo-peek `spr_off`.

**14** (**low — do last**) — GET_PROP `id_now`: do the nid-35 `vframe_no` mul in place; do not `S_V64_ALLOC`. One wasted `vfn` slot at load is the whole cost; `Date.now()` already takes the CALL_METH arm (~6357).

**37** — **corrected patch, and note there is no PYTHON reference for it.**
Neither `id_textbaseline` nor `id_top` / `id_middle` / `id_bottom` exists
anywhere today (parent interns `id_center` only, for `textAlign`), so this
starts with **new parent trail hashes**, not just an exec64 arm. Then:
exec64 SET_PROP latches a `ctx_baseline` FF (0=alphabetic, 1=top, 2=middle,
3=bottom); parent `S_TXT_LD` default phase (**~9438**, not `S_TXT_DRAW`)
replaces `txt_y0 <= txt_py - 16'(8 * txt_k)` with

```
top     : txt_y0 <= txt_py;
middle  : txt_y0 <= txt_py - 16'(4 * txt_k);
bottom  : txt_y0 <= txt_py - 16'(8 * txt_k);
default : txt_y0 <= txt_py - 16'(8 * txt_k);   // alphabetic, today's behaviour
```

**Unknown strings must be ignored** — keep the current `ctx_baseline` — which
is what a browser does with an invalid value, and is exactly what PACMAN's two
`'center'` writes (~1214, ~1239) need: they follow `'top'` and `'bottom'`
respectively. Do **not** map `center` to middle. Port A legal (FFs only).

**15 leftover** — tagged KEYEVT `hp_qt_ff[0]` ternary: add `8'd87` / `8'd83` / `8'd80`. Value64 HTML already works.

**23** — CALL_METH `toISOString`: intern a fixed `"1970-01-01T00:00:00.000Z"` plus `vframe_no` seconds, or the PYTHON `strftime` stub from `vframe_no * 1000/60`. No ALLOC.

Do **not** re-type **31+5** — they are in.

---

## Suggested order (revised)

**6**, **47**, **14**, **36**, **15**, **10** are **applied** — see the edits
table at the top of this file. **46** is retracted. What is left:

1. **50** — compiler inline slot alias. INVADERS Space never presents
   (`drawHud` / `drawCannon`). Compiler only; do not patch RTL.
2. **49** + **51** — parent raster overlay. Path buffer has no writer
   **and** no first-entry/`hs64`; `S_BLIT` never latches exec drawImage
   scalars. Same pass: first-entry latch like `S_TXT_LD`. Turns on a
   dormant renderer (PACMAN/ASTEROID/MRDO paths, DONKEY sheets).
3. **38** — exec64 `quadraticCurveTo`, **in the same pass as 49**, never
   before it.
4. **39** — `Array.reduce` (INVADERS wave-clear). 1-bit `vfe_reduce` +
   acc in `vfe_map`; do not widen `vfe_mode`.
5. **7+8+9** — ALLOC / rAF RET (PACMAN `NEW_OBJ Game`).
6. **45** (+ the **36** font scale) — `font` into exec64, then measureText.
   **37** only if you are chasing the browser, not PYTHON.
7. **1+2+3** — FIND (HUD / collision; not the cap).
8. **20** + **G6** — ImageData policy; circle outline. Re-cost **G6** after
   **49**: today it never runs.
9. **23+40** — INVADERS save (after play works).
10. **42+43** — READY `INSERT` / `DELETE` (board editor).
11. **33** / **32** — alpha==0 skip, unknown-CSS: low, do last.
12. Remaining exec32 leftovers — hygiene, or let
    [REMOVING_EXEC32.md](REMOVING_EXEC32.md) Cut A retire them.

Do not start hash→id BRAM until asked. Do not `make bit`.
