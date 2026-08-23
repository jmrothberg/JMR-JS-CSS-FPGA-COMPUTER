# Potential bugs — FPGA-SIM play RTL (working record)

Words: [README.md — Words used](../README.md#words-used-in-this-project).
**FPGA-SIM** = the chip simulated. **RTL** = Register-Transfer Level
(`rtl/*.sv`). **rAF** = `requestAnimationFrame`. **GC** = Garbage Collection.

This file is **copy 2** of “one heap / dual-copy skew / generation”
debug doctrine (copy 1 is `.cursor/rules/one-heap-keep-gen.mdc`). Start at
[RECURRING BUG CLASSES](#recurring-bug-classes--read-this-before-debugging-anything)
before chasing a title name.

**2026-08-21 night — user: all five titles work fine.** This file is no
longer a “games are broken” list. Left below: (a) automated tests we
leave red on purpose (#70/#71/#72 — you never see these in the GUI) and
(b) a later **board** speed pass if pictures cost too many chip
heartbeats ([SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md)).
**#79** is a script that ran PACMAN’s demo loop with nobody playing; keep
the analysis so we do not shrink `ENV_DEPTH` to 256 again. Same-day GUI
bugs **#73/#74/#77/#78** stay **FIXED**.

**How to read this file:** chronological working record — newest session
on top. Each entry keeps *evidence* and *root cause* because the same
classes recur. Entries are marked FIXED / OPEN / RETRACTED in place.

**Do not start at the 2026-08-19 “Correctness bugs” table** — those
statuses have drifted. It is kept because the *analysis* columns still
describe the code paths (especially FIND speed-debt **#1/#2/#3**).

Live caps: [FPGA_FIT.md](FPGA_FIT.md) (`MAX_OBJ=960`, `ENV_DEPTH=384`,
`MAX_ARR_LONG=12`, `CODE_WORDS=20480`). Play-speed:
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).

Inspection of the play path: `rtl/engines/jmr_js_vm.sv` (parent FSM),
`jmr_js_vm_exec64.sv` (the only decoder since 2026-08-21), `sim/sim_main.cpp`, vs
`hardware_model/js_vm.py`, plus `storage/*.HTML` and
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md).

## Session 2026-08-21 (night) — #79 NOT A PLAY BLOCKER (user: titles work); analysis kept; caps FINAL 960 / 12 / 384 / 20480

**#79 — user play is fine; NOT REPRODUCED on 2026-08-22.** Do not reopen
as “PACMAN is broken.” Fresh evidence from the user's own live FPGA-SIM
session (`traces/session_20260822_112810`): **rafcall 210** reached with
`fault=0` / `efault=0` / `strovf=0` / `fsite=0` at every one of 304
samples, peak `obj=872` (cap 960), peak `envl=131` (cap 384), zero
`txtmiss` / `dimiss`. Objects **sawtooth** — 558 → 872 → 653 → 684 — so
the collector is reclaiming; the #79 signature was `obj` climbing
monotonically to peg. The automated smoke independently reached
rafcall=99 with `fault=0` and `obj=829`. The long-horizon headless
attract death at rafcall≈114 has not been seen on today's RTL, and the
two suite failures previously cited as its evidence were test bugs (see
below). Keep the caps lesson; treat the pathology as unconfirmed rather
than fixed until a long unattended run is deliberately repeated. A headless harness once died on long unattended attract
(pathfinder `push` at ip 822 / `ARR_CAP=128`). That is a **lesson** (do
not shrink `ENV_DEPTH` to 256; attract bursts need `MAX_OBJ=960`), not
the current F9 status. Original write-up left below so the mistake is
not repeated.

**#79 — (original, harness):** PACMAN's object/array demand exploded over
minutes of attract and could kill a heap cap. That PREDATED the fit
pass: the 2026-08-20 (pre-fit) tree failed the same pytest with
**obj=1024 PEGGED** and fault 3 at rafcall=103. Today's caps only moved
the time of death in that harness (768 → pegged at rafcall≈33; 960 →
objects fit at 921 but the pathfinder's frontier array hit `ARR_CAP=128`,
fault 3 fsite=5218 at ip 822).

Evidence pinned by the fault trace: ip 822 = `new_list.push(to)` in
PACMAN's BFS pathfinder (`_render`/`next` around HTML line 212). The
frontier is guarded by `if (!steps[to.y][to.x])` — a 31-row
array-of-arrays of visited marks. A frontier > 128 on a 28-wide maze
means the GUARD IS FAILING (visited cells re-enqueue), which also
explains the object churn (four `{x,y}` literals per expanded cell).
Prime suspect: nested-array element reads/writes (`steps[y][x]`)
degrading after GC — use-after-recycle of the row arrays or an
element-marking gap — i.e. recurring class 1/gen-match territory. NOT
caused by the fit caps; raising caps will not fix it.

**RESOLVED 2026-08-22 — both were BAD TESTS, not #79 and not the chip.**
The two residual suite failures (`test_pacman_fpga_sim_enter_paints_maze`,
`test_donkey_fpga_sim_enter_keeps_raf`) were attributed here to "#79 plus
the documented _wait helper flakiness". That attribution was wrong on
both halves, and the "documented" flakiness was never documented anywhere
— the phrase cited nothing. Each was run, and each failed for its own
mechanical reason:

- **DONKEY** failed on `assert later != play` — "the framebuffer changed
  within 8 frames". Measured: the picture is byte-identical for frames
  1-30, changes at 31 (2076 bytes = one sprite stepping a single glass
  pixel), holds again to 44. Motion on that screen is **sub-pixel per
  frame**. The check only ever passed BEFORE `S_FB_SYNC` (4188e01,
  08-20), when the two FB banks held different images and consecutive
  `FB?` reads differed even when the scene did not — i.e. it was passing
  on the bank-mismatch bug that fix removed. Replaced with a per-frame
  work check (`fclk`), which is what "keeps rAF" actually means.
- **PACMAN** failed on `assert "raf=0" not in vmstat` at the BOOT check,
  with `sname=S_V64_ALLOC`, `fault=0`, `rafcall=99`, `obj=829`,
  mid-`drawImage` at pixel 307199/307200. `_wait_vm_idle_or_frame`
  samples once per 20M-clock slice against a ~3.9M-clock frame, so it
  practically never catches the frame-end window; on a title whose
  attract mode never rests it timed out and returned a **random
  mid-frame instant**, where `raf=0` is correct because the callback has
  not re-registered yet. Fixed in the helper: on timeout spend one
  `FRAME` rpc to land at `S_WAIT_FRAME` — the same boundary the GUI
  samples at, where every sample in the user's live trace reads `raf=1`.

Neither failure was evidence of anything about the RTL.

**#79 refinement from the user's own flight trace (session_20260821_165151):**
30 frames of healthy play at obj=568/arr=1194, then **+354 objects inside
ONE frame** at rafcall=33 — the guard fails wholesale in a single
pathfinder invocation (fault 3 fsite=5218 ip=822), deterministically
around the same rafcall. Not a slow leak: one finder call explodes.
Suspect list narrows to what that first big finder call does differently
(likely the first long-path search when a ghost re-targets).

**Bisect session (2026-08-21 night): the user was RIGHT that the crash
"related to our changes" — two of the fit shrinks broke PACMAN, found by
single-cap bisection against the pre-fit worktree:** ENV_DEPTH=256
corrupted the BFS (live envs recycled mid-recursion → the flood — the
envl≈140 "validation" was a between-frame sample that missed the
recursion peak: transient vs steady-state measurement, add to the
lessons); MAX_OBJ 768/896 died on the legitimate ~330-object attract
burst (4 ghosts' JSON+BFS in one frame). #78 and the v64_on fold were
individually exonerated by toggle-revert probes. Residual: attract still
dies at rafcall≈114 (pre-fit died at ≈103 with FULL caps — same #79
long-horizon pathology). Also found pre-existing on BOTH trees: a
prototype-method parity break (`function M(){this.own=...}` +
`M.prototype.p=...` → `inst.p()` diverges from FM) — separate from the
flood, needs its own entry when investigated.

**Caps FINAL for the first .bin (bisect-proven):**
MAX_OBJ **960**, ENV_DEPTH **384**, MAX_ARR_LONG **12**, CODE_WORDS
**20480**. Paper BRAM
~365/365 — knife-edge, accepted eyes-open; the one-line fallback if
place overflows is MAX_OBJ=896 (-5 tiles). All five cap sites in sync:
parent, pkg, HM, jsb_format, sim_main.

## Session 2026-08-21 (evening) — #77 listener dual-copy skew, #78 promote resume skew: the REAL DONKEY and INVADERS bugs

The user's play reports survived the #74/#76 fixes and forced two more
rounds. Both real causes are RECURRING CLASS 1 (dual-copy skew) — worth
reading together as a case study in why that class is #1.

**#77 — FIXED: removeEventListener compacted only EXEC's listener table.**
User evidence: DONKEY still flipped Mario→Luigi, now traced to a REAL
in-game ArrowRight (not a phantom key). DONKEY removes the charsel
`choose` listener at game start (`removeEventListener("keydown",
this.choose)`) — correct JS, works in Chrome and PYTHON. The RTL keeps
TWO listener tables: exec64's copy (compacted by the remove, count
handshake updated) and the parent's copy (read by the kev dispatch walk)
— the compaction strobe `e64_vlistener_repl` reached the parent's port
list and was NEVER APPLIED. After a mid-dispatch remove the walk ran the
REMOVED listener and dropped a live one. Minimal repro: remove-inside-
dispatch left the removed listener firing and lsn counting the other one.
Fix: the removee (ev, fn) rides the single-slot wdata channel on the repl
beat and the parent compacts its own copy — over ALL 16 slots, skipping
UNDEFINED pairs, because on the apply beat the muxed count is already the
NEW value.
*Verification lesson: two earlier "Mario→Luigi fixed" verdicts (#phantom
edges, #74) passed because the probe idled in-game. Verify with the
user's actual gesture — press the arrow IN the game.*

**#78 — FIXED: exec-requested S_ARR_PROMOTE resumed the decoder on stale
state — every promote after the first lost its boundary element.** User
evidence: INVADERS bunkers 2/3/4 drew with a one-block hole at the same
cell — cells[32], the exact ARR_SHORT_CAP promote boundary — on the
INITIAL screen (bunker 1 clean; PYTHON and Chrome clean). Beat-level
$fdisplay tracing proved: promote copy correct, boundary WRITE correct
when it happens, ip stable — but on resume the promote jumped straight
back to S_V64_EXEC with a STALE code_rdata and a stale eval-stack
window. CALL_METH push then read its receiver one slot off (got the
pushed OBJECT, not the array), arr_ok failed, and the push fell into the
generic method path and vanished: len never bumped, pushes 33+ landed
one slot early, slot 32 held the NEXT iteration's object ({n:33}) whose
`alive` read undefined — the hole. The FIRST promote survived only
because its stale window happened to be coherent.
Fix: exec-requested promotes resume through the standard
`hs_ip(e64_ip_q); hs_code(ops_base+e64_ip_q); hs_st(S_FETCH_WAIT)` path
(same idiom as every other parent state) — the re-decoded push cannot
re-promote because `varr_long` is now set. Parent-requested promotes
(JSON parse) keep their direct return.
*Lesson (add to class 3, first-entry guards): the guard family has a
mirror — the LAST-EXIT rule. A parent state that exec entered must
return through S_FETCH_WAIT with a re-armed fetch, never jump directly
to S_V64_EXEC; the decoder's comb inputs (code_rdata, the vst window,
every *_rdata) are otherwise whatever the interrupted flow left behind.
S_ARR_PROMOTE was the only state that broke this rule.*

Verified after both fixes: minimal repros green (8/8 arrays, 4/4
class-ctor bunkers, removed listener stays dead), INVADERS bunkers
identical, and the previously-failing checkpoint/title suite tests
rerun.

## Session 2026-08-21 (afternoon) — #76 physical-vs-logical depth: the cap shrinks corrupted adjacent state

**#76 — FIXED: slice-width writes into shrunk side arrays are OOB in the
Verilated model.** User evidence: INVADERS draws its initial screen with
one missing bunker cell at the SAME position — row 2, col 10 — in every
bunker except the first (PYTHON and Chrome clean); PACMAN silently
bounced to READY (no error text = not a capacity fault) minutes into
play; DONKEY confirmed fixed.

Cell (2,10) is `cells[32]` — the 33rd push, the exact `ARR_SHORT_CAP`
short→long promote boundary. The per-handle side arrays (`vobj_alloc`,
`vobj_gen/len/cls/builtin/mark/proto`, `vfn_*`, `venv_valid/gen/len/
parent/mark`, `env_cap`, `vlong_used`) are written through FIXED-WIDTH
slices (`[9:0]` obj, `[8:0]` env, `[6:0]` long) at the exec-write block,
the pokes, and the GC. When the caps were 1024/512/128 the slice width
equalled the depth, so any sliced index was architecturally in-bounds.
After the fit-pass shrink to 768/256/32, a sliced write above the cap
became an **out-of-bounds write over whatever member sits next in the
Verilated model** — deterministic adjacent-state corruption. First
victim: the promote path's boundary element on every promote after the
first. PACMAN's silent death is the same corruption reaching the
rAF/listener state (script "ends", VM halts cleanly, monitor READY).

**Fix — physical depth = 2^slice-width, logical cap unchanged:** the 25
side arrays keep 1024/512/128 physical rows (`OBJ_PHYS`/`ENV_PHYS`/
`LONG_PHYS`); allocation is still bounded by `MAX_OBJ=768`/
`ENV_DEPTH=256`/`MAX_ARR_LONG=32`, and rows above the cap are inert (no
scan reads them). The BRAM savings survive intact: the big slot arrays
(`vobj_slot` 24576, `venv_slot` 4096, `varr_slot` 53248, `code_mem`
20480) use COMPUTED addresses from claim-bounded values, not slices.
Also sliced the one full-width writer (`vlong_used[varr_lidx_rdata]` →
`[6:0]` in the GC sweep).

*Lesson (new recurring class): a pow2 cap is load-bearing geometry.
Before shrinking any cap, grep every write to every array sized by it —
if writes go through bit slices instead of compared indices, the
physical depth must stay 2^slice-width or every slice must be re-audited.
The non-pow2 caps that already existed (MAX_ARR_SHORT 1536) are
compare-guarded precisely because they were never pow2.*

## Session 2026-08-21 (later) — #75 stale harness caps, INVADERS bunker verdict, PACMAN 5-min fault open

**#75 — FIXED (harness, class-5): sim_main's heap-scan constants lagged the
RTL cap shrinks.** `VM_MAX_OBJ`/`VM_MAX_ARR`/`VM_ENV_DEPTH` in
`sim/sim_main.cpp` stayed at 1024/1664/512 while the RTL arrays shrank to
768/1568/256 — every `VMSTAT obj=`/`arr=` scan read past the end of the
Verilated arrays and counted garbage (INVADERS printed `obj=772` with a
768-cap heap, which cost an hour chasing a phantom allocator overflow;
the claim paths are in fact compare-bounded and the caps are safe).
Constants synced + a new `envl=` live-env stat added. *Lesson: the C++
harness is a FIFTH copy of the cap numbers — add it to the drift
checklist alongside parent/pkg/HM/jsb_format.*

**INVADERS "bunker holes" — NOT A BUG.** Bunkers are ~124 `{x,y,alive}`
cells; alien bombs call `Bunker.hitAt(cx,cy,2)` ("bunker blocks alien
bombs", max 3 arcade bombs) and carve a ~1-block crater. Three top-edge
craters at score 0 after a minute of marching is the game working as
designed. PYTHON shows different damage because `Math.random` is a
different sequence there (LFSR vs Python RNG) — bomb columns/timing will
never match across runtimes. Headless RTL at wave start reproduces
intact bunkers.

**PACMAN faults to monitor after ~5 minutes of GUI play — OPEN, under
measurement.** Steered headless play is clean past 220 frames (~15
GUI-minutes equivalent), so the trigger is something the synthetic
steering does not do (ghost-eat popups, death/restart, level clear) or a
slow env climb against the shrunk ENV_DEPTH=256. Note the FM census that
sized the caps was **splash-biased for some titles** (its key injection
never started INVADERS: census said 87 objects, in-game reality is ~570
— 55 invaders + ~496 bunker cells). The `envl=` stat exists precisely to
re-census in-play on RTL. If env climbs: ENV 384 costs +4 tiles
(budget 360/365); a monotonic climb would instead mean a retention bug
worth finding. Ask the user what error text the monitor printed —
the fault code names the resource.

## Session 2026-08-21 (fit pass) — #73 imgd handshake lock, #74 DONKEY phantom second window

Context: the T200 fit pass ([FPGA_FIT.md](FPGA_FIT.md)) moved `imgd_pix`
to external SRAM, shrank MAX_OBJ/MAX_ARR_LONG/ENV_DEPTH/CODE_WORDS to
measured envelopes, and constant-folded the 33 execution reads of
`jsb_flags[3]` (`v64_on`). Two regressions shipped in the first build and
were caught by the user's play test within the hour.

**#73 — FIXED: PACMAN froze after splash (imgd req/ack anti-phase lock).**
The new `imgd_pend` flag was cleared in the FSM's per-beat default
section — the line where the old `imgd_we` BRAM strobe used to live.
`imgd_pend` is handshake STATE (held until `sram_ack`), not a strobe.
The SRAM model's ack is a one-beat pulse that re-fires every other beat
while req is held; with `imgd_pend` flapping at the same period the two
locked anti-phase and the ack was never consumed — S_IMGD_GET wedged at
the maze cache, which is "froze right after the splash". Fix: the flag
is not in the default-clear block. Evidence: PACMAN then played 40
frames, fault=0, `imgd=307199/307200`.
*Lesson (new sub-class of the shared-scratch pattern): when converting a
strobe-based path to a req/ack path, every flag that survives more than
one beat must move OUT of the default-clear section — grep the default
block for the signal name before reusing a line.*

**#74 — FIXED: DONKEY Mario→Luigi returned (second phantom-arrow window).**
The 2026-08-20 fix cleared captured KEYBITS joy edges when a real KEYEVT
DISPATCHED — which requires the real event to already be in kev_q. The
surviving window: an edge captured at a frame_tick while `vlistener_n`
was momentarily 0 (DONKEY re-registers listeners on screen swap) or
before the KEYEVT RPC landed. That edge sat armed and converted into a
synthetic arrow at the first eligible frame — seconds into the game,
flipping the charsel listener's character. Fix: the KEYEVT ENQUEUE
strobe also clears both edge registers and re-baselines `prev_joy`, so
captured edges only ever convert for a real joystick (KEYBITS with no
KEYEVT twin — the JB stick). Safe against same-beat capture: the strobe
never coincides with frame_tick (own RPC window). Evidence: GUI-faithful
charsel (KEYBITS+KEYEVT both channels), then 150 idle frames — histogram
stable, no flip, `kevq=0/0`.
*Lesson: a "fixed" race deserves a search for its siblings — the fix
condition ("already queued") was narrower than the capture condition.*

Also measured, not a bug: MAX_OBJ 768 raises PACMAN's forced-GC rate
from ~4 to ~10 per frame (obj rides ~690). Correct, slower; the GC
pacing item in [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md) is
the antidote, and MAX_OBJ is the first lever to revisit if a title
faults 3.


### #80 pattern note — strobe-converted metadata arrays land +1 beat (2026-08-22)

The heap metadata arrays (gens, marks, valids, varr_long) moved from
flip-flops to LUTRAM via the vom/veg strobe pattern. A strobe write lands
one beat after the FSM site that armed it. Every current reader goes
through an armed `*_rdata` port (≥2 beats later), so no path sees stale
data — but any NEW code that writes metadata and re-reads the same slot
on the next beat will. If you add such a path, either forward the write
(vol/vel bypass pattern) or arm the read one beat later.


### #81 FIXED 2026-08-23 — callee `var` locals alias the caller's frame when called from a method (FM == RTL, both wrong)

Minimal repro (2026-08-23, found converting the ghost-update fixture off
JSON): a plain global function with `var i/j/row` locals, CALLED FROM AN
OBJECT METHOD whose own scope uses the same names, loops forever — the
callee's loop variables read/write the CALLER's bindings (i < row.length
never terminates). The same function called from top level is correct.
FM and RTL agree exactly (parity holds on the wrong answer), so no test
caught it until a fixture collided. Likely the same root as the logged
prototype-method parity break. Workaround until fixed: unique local
names in functions callable from methods (PACMAN2's helpers and the
suite fixtures now use `_cm_*` prefixes). Repro fixture:
tests/test_rtl_snippets.py ghost-update test with the one-line
`function f(src){var out,j,row,r,i...}` variant.

**FIX (compiler-only, functional_model/compiler.py for-init):** `for
(var i...)` inside a function emitted STORE_VAR — the walk-and-write op
that lands on the CALLER's binding when the name isn't declared in this
frame. let/const already had the guard (LET_VAR a1=1: declare/store in
THIS call env, still re-inits every entry); `var` now joins it, and
for-init names are `_note_local`'d so the a1=1 global retro-patch stops
mislabeling their sites. No FM/HM/RTL runtime change — the runtimes
always executed LET_VAR correctly; the compiler just never emitted it
here. Verified: repro returns 105 (was 9); 216/216 bytecode+console
suites; all seven titles compile. The `_cm_*` collision-proof naming in
fixtures/PACMAN2 is no longer load-bearing but harmless.

### #82 OPEN — DIR's MORE pager eats typing with no visible prompt (user report 2026-08-23)

User glass: after `dir`, typed characters do not echo and each Enter
prints a bare READY line; recovery only after many Enters ("could not
type until here"). Flight log `session_20260823_183331` shows the
mechanism: `GLASS DIR -- MORE --` then `MORE page=1`, then every
keystroke arrives as `rpc KEY` (pager/game path) with NO `LINE` rpcs —
the keys are consumed as page-advances until the listing drains. The
bug is not the pager; it is that the `-- MORE --` prompt was NOT
visible on screen (screenshot shows bare `>`/READY cycles), so the
modal state is silent. Suspects in order: (a) the MORE prompt/exit path
in `jmr_console_engine.sv` regressed in the fit campaign's u_cons
slimming (15,214 → 6,046 LUTs, file in the active diff); (b) GUI key
routing stays in pager mode a beat too long. FM console MORE tests pass
(216/216), so it is RTL-or-GUI, not the model. Filed during run 20 —
console RTL deliberately untouched until the campaign tree settles.

## RECURRING BUG CLASSES — read this before debugging anything

Five patterns produced the overwhelming majority of the bugs in this file.
If **glass** (READY / the game / errors) is wrong, start by asking which
of these it is. Teach-yourself: **parent** = `jmr_js_vm.sv` (heap, paint,
events); **exec** = `jmr_js_vm_exec64.sv` (opcode decoder); they talk
through `hs_*` handshake tasks. **Port A** = legal on-chip RAM (address
this clock, data next clock).

### 1. Parent/exec dual-copy skew

exec64 owns registers; the parent mirrors them through `hs_*` tasks that
set a one-shot `hs_m_*` mask, and reads are muxed `hs_m ? parent_ff :
e64_*_q`. Anything that reads a parent FF **outside** the states in the
`hs64` mux gets a stale value.

*Tells:* a value that is right inside the opcode and wrong one state
later; a completion that pushes to the wrong stack slot; a checkpoint
hash that differs while the heap matches.
*Examples:* the script-end halt hashed a stale `vsp`/`vcsp`/`vthis`/`venv`;
`vkey_ln` latched the parent's stale listener count; `v64_repl`/`repl_rch`
only ever lived in exec FFs so `replace` completed down the 32-bit path.
*Fix shape:* seed from `e64_*_q` at the point of use, or poke the parent
FF **and** set its mask.

### 2. Registered raddr → registered rdata: two beats, not one

Every big array is Port A: address this clock, data **next** clock, and
the address mux itself is often gated by a flag that is set with `<=`
(so it reads 0 during its own set beat — that is a *third* beat of lag if
you gate on it).

*Tells:* every element of a walk reads the same wrong value, or reads one
row behind; a length/flag test that "can't" fail does.
*Examples:* `join` gated its name-hash raddr on `jn_name_arm` and every
string digit came back `"0"` (so `"1100"` interned as `"0000"`);
`replace`'s replacement char read the pattern's row; #58's WIN_FILL.
*Fix shape:* gate the mux on a flag that is already high on the beat the
data is consumed (`jn_slot_arm`), or add an explicit settle beat.

### 3. Exec-entered parent state with no first-entry guard

When exec sets `state_n` to a parent state, the parent's seeds may live
only in exec FFs. Without a first-entry arm the walk runs on garbage — or
re-decodes forever.

*Tells:* a frame that burns the 64M cap in one state; a walk that starts
from a previous walk's numbers.
*Examples:* S_SQRT (PACMAN stuck on splash); S_FONTPX and S_V64_DISPATCH
needed one by construction when added.
*Fix shape:*
```systemverilog
if (state != S_X && jsb_flags[3] && e64_leave_hold) begin
    hs_st(S_X);
    /* copy seeds from e64_*_q */ hs_ip(e64_ip_q); hs_vsp(e64_vsp_q);
end else begin /* the walk */ end
```

### 4. Shared scratch registers with no owner — **the expensive one**

`bind_k`, `bind_rd_arm`, `vfe_rd_arm`, `jn_slot_arm`, `hp_proto_arm`,
`valloc_rd_arm` and friends are reused by unrelated states. A state that
interrupts a multi-beat walk silently destroys its cursor.

*Tells:* a walk produces a plausible but wrong result; behavior depends on
what happened in the *previous* frame.
*Example:* **#69** — the FRAME rpc can return with the rAF snapshot
half-done; the next frame's event dispatch reuses `bind_k` in the
listener scan; the resumed copy loop is skipped and `vraf_snap[0]` still
holds a stale fn, so the machine "ran the rAF callback" but executed a
keyup **listener** and the game loop died.
*Fix shape:* every multi-beat walk resets its own cursor in its own
first-entry guard, and any state that dispatches mid-boundary work resets
the cursors it may have clobbered. See
[RTL_REORG.md](RTL_REORG.md#maintenance-backlog-do-these-instead) item 1.

### 5. A test/harness artifact that looks exactly like an RTL bug

*Examples this cycle:* a probe that reused one sim session "showed"
findIndex returning a string (it was the previous program's intern
table); a suite run raced a `rm -f` of the binary and reported 139 skips;
DIR "not listing .HTML" was 40 leftover probe files scrolling the list
off an unpaged screen; PACMAN "leaking objects" was a helper waiting for
an idle window heavy frames never show.
*Rule:* before believing a weird result, reproduce it in a **fresh sim
with a fresh card**. The test harness now copies `card.img` to a scratch
per session — keep it that way.

### Retracted theories (do not re-derive these)

| Idea | Why it was wrong |
|---|---|
| **#46** "one timer per frame" | `bind_k` is zeroed by `S_V64_ALLOC` / `S_V64_CTOR_PAD` on every dispatch, so the timer scan already restarts and all due timers drain. The state is a three-way chain, not a one-shot. |
| **#50** compiler inliner slot aliasing | RTL env lookup is **name-keyed** (`hp_key_n`); the `a1` slot is only a scan hint. Half-vindicated later as **#55**: the hint was used as a scan *start* and skipped the prefix — fixed by always scanning from 0, then re-introduced safely in 2026-08-20's speed pass as a *verified* hint (compare at the hinted slot, full rescan on mismatch). |
| "Skip gen-match to hide dual-copy skew" | Forbidden. It hides class 1 instead of fixing it, and corrupts handles across GC. |
| "Extract JOIN/JSON/GC/HEAP into modules" | That is a second heap. See `one-heap-keep-gen`. |

---

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

## #69 — FIXED: rAF queue died when an event dispatch interleaved a half-done snapshot

**Repro (Value64, minimal):** register a keyup listener + a rAF `tick`
that re-arms itself. `KEYEVT 40 1; FRAME; KEYEVT 40 0; FRAME; FRAME`
(the up strobed in a DIFFERENT inter-frame window than the down, so it
is not tap-deferred). Result: the listener runs (released=1 ✓) but
`vraf_n` ends 0 with `rafcall` stuck at 1 — the game loop silently
stops. Works fine when an rAF-only frame separates the two events
(`down; F; F; up; F` is green), which is why titles play: the sim's
tap-deferral inserts that spacing for same-window taps.

**Where it lives:** the parent WAIT_FRAME v64 boundary — event dispatch
(kev) then rAF snapshot (`vraf_snap` copy + `hs_vraf_n(0)`) then
S_V64_FRAME_RAF callback call. In the failing interleave the callback's
`requestAnimationFrame` re-arm (`vraf_n_n = vraf_n + 1`, exec64 ~4066)
is lost — final muxed `vraf_n` reads 0. Prime suspect: the
`hs_vraf_n(0)` one-shot mask/absorb ordering when the SAME boundary
already did an event dispatch (S_V64_ALLOC handoff) before the
snapshot; the parent mask-clear beats (6083/6273) and the exec frozen-
absorb (`if (hs_m_vraf_n) vraf_n <= p_vraf_n`, exec64 ~2403) interleave
differently there. Not diagnosed to the beat.

**ROOT CAUSE (beat-level trace via new RAFTRACE RPC):** the FRAME rpc
can return to the host with the boundary's rAF snapshot HALF-DONE
(`jn_slot_arm=1`, copy loop pending). The next frame dispatches the
queued key event first, and the listener scan (S_V64_FRAME_KEY)
**reuses `bind_k`** — clobbering the interrupted snapshot's cursor. On
resume the copy loop is skipped (`bind_k >= vraf_n`) and `vraf_snap[0]`
still holds a STALE fn: the walk then "called the rAF callback" but ran
the keyup LISTENER (trace showed the callback executing the listener's
ips), while the real tick entry had already been cleared by
`hs_vraf_n(0)` — game loop dead. **Fix:** every kev-dispatch branch in
the v64 WAIT_FRAME arm now resets `jn_slot_arm`/`bind_rd_arm`/
`vfe_rd_arm`, restarting the snapshot cleanly from phase 1 after the
events drain. Verified: KEYBITS and KEYEVT down/up in consecutive
frames keep raf=1 and rafcall climbing.

**Blast radius:** pre-existing (reproduces on committed HEAD f242854
and with plain KEYEVT — not from the KEYBITS bridge or Phase 1/2).
Likely explains several event-driven snippet failures
(player_x_moves_on_key, title_gamestate_enter_advances, DONKEY/PACMAN/
MRDO fpga_sim tests) and can bite real play when two key events land in
consecutive frames with no rAF frame between. Fix in its own session
with a beat-level trace of hs_m_vraf_n / e64_vraf_n_q / vraf_n_ff
through the failing boundary.

**Fixed alongside (same triage):** (a) script-end halt now syncs
`hs_ip(e64_ip_q)`/`hs_vsp(e64_vsp_q)` before S_DONE — the value64
checkpoint parity tests hashed a stale parent vsp=1 + leftover stack
word (pre-existing on HEAD); (b) KEYBITS edges now reach Value64:
the v64 WAIT_FRAME arm never computed joy edges nor dispatched them
(tagged-arm only), so a physical-joystick press was invisible to v64
listeners — edges are now captured in the v64 frame beat and converted
to synthetic kev_q entries (one edge/frame, `vlistener_n != 0` gate,
same no-double-fire rule as the tagged arm), reusing the proven KEYEVT
dispatch + e.key interning.

## Value64 gaps closed during the exec32 cut (2026-08-20, cont.)

- **dispatchEvent implemented for Value64** (nid 38/39 + CALL_METH arm;
  existed only in exec32 — DONKEY's synthetic boot Enter silently
  no-op'd, the real cause behind the "Enter twice" quirk #60). The
  guard `if (document.dispatchEvent)` reads truthy (primitive GET_PROP
  arm answers id_disp), the REAL event object rides hp_wval to a new
  S_V64_DISPATCH state (slot walk finds .type; enum tail, after
  S_FB_SYNC, mirrored in jmr_js_vm_pkg), and the FRAME_KEY listener
  scan runs in custom mode (vkey_custom; vkey_ln latched from
  e64_vlistener_n_q — the parent ff is stale; resume ip/vsp latched at
  entry because the muxed values reflect the LISTENER's exec run by
  scan end).
- **new KeyboardEvent/Event/CustomEvent/MouseEvent desugared in the
  compiler**: `new KeyboardEvent(T, O)` now compiles to
  `Object.assign({type: T}, O)` (MAKE_OBJ / SET_PROP / CALL_METHOD
  assign — proven on both runtimes). The tagged RTL had a native ctor
  arm; Value64 never did, so the ctor ran off n_ops with an unbalanced
  stack (fault 1 site 3198) — this plus the missing dispatchEvent was
  the whole DONKEY synthetic-boot-Enter story.
- **String.replace replacement char**: consumed one settle beat early —
  read the PATTERN's hash row ('c' became junk); and the len==1 gate
  tested the RECEIVER's blen (that raddr moved to the receiver
  yesterday). Third settle beat (opnd2) + gate dropped.
- **indexOf on a dynstr receiver**: OGETI nat=3 was missing the exec
  latches its own comment claimed ("same latch as replace") — stale
  hp_vbase/ip parked the program at the CALL ip; and the needle byte
  read name_rdata with an un-aimed cursor — now name_hash_raddr targets
  the needle during FETCH_WAIT (single-char interns hash to their
  byte) and S_IDXSTR gets hs_hp_vbase/hs_ip/hs_vsp.


All were tagged-only features/behaviors the encoding flip exposed; each
verified by probe before the suite rerun:

- **Events-then-rAF now share a frame** (browser order): `dbg_cb_ip` was
  sticky — set at the first rAF ever, cleared only at RUN — so the host
  FRAME rpc's "callback done" break fired as soon as an event dispatch
  returned to WAIT_FRAME; every event frame ended before its own rAF.
  Now cleared at the v64 frame_tick beat. (This plus #69 is what the
  MRDO/player_x/title_gamestate family needed.)
- **findIndex implemented in exec64** (existed only in exec32):
  `vfe_findidx` flag on the find-mode walk, vfe_reduce-style
  save/restore; hit pushes the AGETI slot (the index), miss pushes -1.
- **join of string-digit elements** ("1100" → "0000"): the
  name_hash/name_len raddr mux terms for S_JOIN gated on `jn_name_arm`,
  which reads 0 during its own set beat — the reads landed one row
  stale and every interned digit failed the len==1 test, coercing to 0.
  Gate on `jn_slot_arm` (high during the name-arm beat, varr_rdata
  settled). NAMEPEEK RPC added to dump the intern table.
- **ctx.font size parse revived**: S_FONTPX had NO entry (died with the
  tagged path) — every v64 fillText drew at the 8px default scale.
  exec64's ctx SET_PROP arm now routes string font values to S_FONTPX
  (intern id via hp_key, BIND-style first-entry seed); the font
  property is not heap-stored (write-only in titles).
- **Natural-size drawImage under setTransform**: the argc<5 dest-size
  leg took sprite w/h raw while the explicit-dw/dh leg multiplied by
  ctx_sx/ctx_sy — a 2x transform drew 1x (both ASET and SPR paths,
  one shared block). Now scaled and clipped identically.

## #70/#71/#72 — OPEN parity/pathology gaps (found by the exec32 cut, pre-existing)

- **#70 queues-hash parity:** value64 rAF/timer queue serialization hash
  differs RTL vs HM in `raf_timer_order_checkpoint` (frames/vars/heap
  now match after the halt sync). Content/order of the queue words in
  CHECKPOINT? vs the HM model. xfail'd with this id.
- **#71 fault-state parity:** at a call-overflow fault HM keeps sp=1,
  RTL reports 0 (`recursive_capacity_checkpoint`). Halt-sync covers the
  clean-GC halt only, not the fault path (many fault sites). xfail'd.
- **#72 class-in-IIFE ctor storm:** `new P()` on a class returned from
  an IIFE allocates ~950 objects and GC-storms through S_V64_CTOR_PAD
  before completing (`calls_checkpoint` 4th param). Pre-existing on
  HEAD f242854 — a wall-clock flake boundary in tests and a real
  inefficiency (likely the ctor retry loop re-allocating per pass).
  xfail'd with this id; fix alongside the GC/alloc work.

**Halt-sync (extended):** the script-end S_DONE beat now absorbs
`ip/vsp/vcsp/vthis/venv` from exec (was ip/vsp only) — checkpoint
`frames` parity exact for scalar + calls + closures + dom/foreach.
The old tagged-twin scalar checkpoint test is deleted (Phase 1 doc:
the value64 twin is the product-encoding test).

## Session 2026-08-20 (evening) — user-run triage #2 (MRDO / DONKEY LUIGI / LIST)

Three user reports from trace session_20260820_143114; all fixed and
probe-verified (probe13 8/8, PACMAN/DONKEY/MRDO smokes green):

1. **MRDO stuck at splash** — NOT stuck, and not slow: the game runs its
   rAF loop fine (~9M clk/frame). Root cause chain: (a) a frame that
   dispatches a KEYEVT does NOT run the rAF callback (the listener
   returns to `n_ops`, ending the frame); (b) sim frames take seconds of
   wall time, so a human Enter tap's down+up land in one batch — held
   flags (`startHeld`) pulse 1→0 across two event-only frames and
   `tickGame` never observes the key held. Fix in **sim_main.cpp only**
   (real hardware runs frames in real time): KEYEVT defers a keyup that
   arrives in the same inter-frame window as its keydown until TWO
   FRAME rpcs later (down-dispatch frame, held rAF frame, up-dispatch
   frame). Verified: a tap now takes MRDO ATTRACT→PLAY and the field
   paints. False alarm during diagnosis: VVARPEEK var ids must come
   from `chunk.names` order minus natives (the encoder's table), NOT
   from code-traversal order — wrong mapping "showed" corrupt globals.
2. **DONKEY: picking LUIGI brought the old KONG splash back** — the
   frame-end present swaps banks, and the charsel repaints only a 36×21
   selector arrow; the swap exposed the stale two-presents-ago bank
   (the splash). The fb_dirty gate (which fixed the *flashing*) made it
   sticky instead. Real fix: **S_FB_SYNC** — after every frame-end
   present, copy the just-presented front bank into the new back bank
   (1 px/cycle, ~307k clocks per dirty frame), restoring browser canvas
   persistence semantics. Traps hit on the way, all fixed: (a) the new
   state MUST be appended at the END of the st_t enum — sim_main
   hardcodes state numbers (S_WAIT_FRAME=16 in the FRAME rpc's exit
   predicate; STATEHIST indices) and a mid-enum insert wedged every
   frame at the cap; (b) the copy's own fb_we must not re-mark
   fb_dirty — gate checks `state != S_FB_SYNC && casestate_q !=
   S_FB_SYNC` (the last write drains one beat after leaving the
   state), else every frame re-presents forever; (c) dump-read data
   lags `fb_dump_addr` by TWO beats (addr FF + BRAM output reg) — the
   write trails `clr_idx` by one or the copy shifts +1px per present
   (probe: green rect crept 100→102). New `fb_dump_front` port wired
   from u_fb's front-bank dump in jmr_js_core. Verified: charsel
   persists across LUIGI/Mario picks with no splash return; explicit
   `swapBuffers()` (.JS probes) intentionally does not sync.
3. **Monitor stalls on `list`** — LIST streams the CARD copy through
   the RTL console line buffer; one 100KB+ base64 sprite line = MB of
   SPI reads = minutes. The card copy of .HTM/.HTML is display-only
   (compile-on-RUN reads the host storage/ file; the board runs .JSH),
   so `tools/make_sd_image.py` now squashes card-copy lines over 200
   chars to `<LINE n: EMBEDDED DATA k CHARS OMITTED>`
   (`squash_long_html_lines`, applied at image build AND
   patch_card_file). DONKEY card copy: 1.37MB → 30KB; `list` of DONKEY
   now pages in ~1s and LOAD dropped to 0.3s. card.img rebuilt.

DONKEY "moves so slowly on game screen": measured ~713k clk/frame —
same league as PACMAN; that is Verilator wall-time, not a VM bug.

## Session 2026-08-20 (afternoon) — THE SPEED PASS (1.75× fewer clocks)

User report: all four titles play but INVADERS is unplayably slow. Profiled
with a new `STATEHIST?` RPC (per-state cycle counters + env/obj/cmd/phase
splits, sim_main.cpp only). INVADERS in play burned **18.6M VM clocks per
frame**; 48% of ALL cycles were S_HEAP_CMP, and 92% of that was **ENVWALK**
— the env-chain scan behind every variable access, 2 beats per slot, always
from slot 0 (the #55 rule).

Three changes landed (probes 8/8, p58c, replace/assign/sqrt probes, and all
four title smokes green; INVADERS now **10.6M clocks/frame, −43%**):

1. **Compiler: provable globals get `a1=1`** (direct vvars, no walk).
   Env chains are lexical, so a LOAD/STORE_VAR site whose name is declared
   by NO enclosing function scope can only ever resolve to vvars. New
   uncapped per-function shadow sets (`_scope_sets` — the 16-entry
   `_local_stack` maps drop overflow names so they can't answer this)
   feed a retro-patch at the end of `Compiler.compile()`. Deferred to
   compile-end because `var` hoisting lets a use be emitted before its
   declaration is seen. INVADERS: 713 sites now a1=1, 74 keep the walk.
2. **RTL: verified slot-hint for local LOAD/STORE_VAR (env phase 5).**
   a1>=2 seeds the walk at slot a1-2 and compares the key there FIRST; on
   any mismatch (or hint >= len) the parent restarts a full scan from
   slot 0. #55 stays honored — the hint is never trusted, it only
   short-circuits the common case. Hot craters loop (INVADERS line
   409-416 dx/dy/r, ~26k iterations/frame) went from full scans to one
   compare.
3. **RTL+compiler: verified slot-hint for local LET_VAR (env phase 6).**
   LET_VAR local now carries its env slot in a1[7:1] (slot+1; 0 = none).
   Phase 6 checks the hinted slot; hit → write in place, miss → normal
   phase-2 find-or-append from slot 0. Re-`let` in loop bodies was 57%
   of remaining walk time. First declaration in a fresh env still walks
   (append must prove the name absent).

Phase numbers 5/6 collide with the Image.src width/height chain ONLY
lexically — those live in the `hp_cmd==HP_SETPROP && !hp_env` object arm;
the new checks sit inside the `hp_env` arm. S_HEAP_WR's env arm is
phase-agnostic, so hinted hits write exactly like scanned hits.

**Failed experiment (reverted):** Verilator `--threads 8` refuses
(UNOPTTHREADS — the VM is one giant sequential always block);
`--threads 2` built but ran ~1.5× SLOWER (41.7s vs 27.5s per frame wall).
Do not retry threads without first breaking up the FSM.

**Remaining speed profile (INVADERS play, after the pass):** S_V64_EXEC
66% (per-op decode + fetch settle — the next frontier is per-op overhead:
~37% of exec-unit beats are S_FETCH_WAIT), S_HEAP_CMP 10% (46% of that =
hinted loads, 31% = object GET_PROP scans). PACMAN game frames are ~0.7M
clocks — INVADERS is the outlier because of its per-pixel JS loops.

## Session 2026-08-20 (midday) — language-feature pass

With all four titles playing, the compatibility gaps that the titles actually
use were implemented and the bugs found on the way fixed. All verified by
probes (34/34) plus fresh gameplay smokes of all four titles on the final
binary.

**New features:**
- **#39 Array.reduce** — rides the FE walk: 1-bit `vfe_reduce`, accumulator
  in `vfe_map` (GC-marked with the map shadow), `(acc, elem, i, arr)` argc-4
  binding, callback return threads the acc. INVADERS' wave-clear
  (`grids.reduce((total,g) => total + g.invaders.length, 0)`) now counts.
- **#40 Array.slice** — result array via the filter/map S_FREE_ARR scan, new
  parent state `S_V64_SLICE` (AGETI→ASETI reference copy). Negative and
  missing args clamp per spec.
- **#41 Array.sort(cmp)** — new parent state `S_V64_SORT`: bubble passes, one
  comparator call per compare through the FE callback plumbing
  (`vfe_sort` flag; cmp result rides `vfe_map`). Sort returns the receiver;
  argc==0 / len<2 is a no-op. INVADERS' leaderboard order works.
- **#37 ctx.textBaseline** — `ctx_baseline` exec latch (top/middle/bottom;
  unknown strings ignored, per browser), S_TXT_LD y0 offset select.

**New bugs found & fixed on the way:**
- **compiler: expression-bodied arrows ate the argument comma** —
  `arr.reduce((t,g) => t + g.n, 0)` parsed `t+g.n, 0` as a comma expression:
  the callback returned 0 and argc collapsed to 1. Arrow bodies now parse at
  assignment level (`_ternary`), like arguments.
- **#68 S_FREE_ARR had no first-entry guard and was missing from hs64** —
  a SECOND filter/map in one program exited its result-array scan into the
  stale parent hp_ret (S_V64_FOREACH) and re-dispatched the CALL_METH per
  iteration: filter()/map() returned the callback fn and never ran it, or
  clobbered a LIVE array (aid 0) with the result. Guard + hs64 added; the
  scan now settles properly.
- **#66b setTimeout/clearTimeout slot scans tested slot i against
  valid[i-2]** (registered raddr export + registered rdata = 2-beat lag):
  every same-frame setTimeout after the first piled into ONE slot (last
  writer wins — INVADERS' deferred kill timers vanished, 6 registered → 2
  fired), and clearTimeout cleared the wrong slot. Both scans now hold the
  raddr two beats per slot. Probe: 6 timers register, all 6 fire in order
  with correct captured closure values; targeted clearTimeout cancels
  exactly its timer.
- **#60 (partial) listeners registered during a dispatch ran for the same
  event** — vlistener count snapshot (`vkey_ln`) at key-event dispatch.
  DONKEY's title now stops at character select ("Enter twice" as designed).

**Remaining gaps (documented, non-blocking):**
- `toISOString` returns undefined (no char heap to build the string) —
  INVADERS stores `at: undefined` in a saved score.
- `globalAlpha` writes are ignored (fades draw fully opaque) — #33.
- `sort()` without a comparator is a no-op (returns the receiver unsorted).
- Element-targeted listeners still fire globally on raw keys, and `.click()`
  has no Value64 arm (fires nothing) — the harmful `.click()`-fires-all
  variant of #60 cannot occur.
- `ctx.font` size parsing (#45), `INSERT`/`DELETE` monitor commands
  (#42/#43): untouched.

## Session 2026-08-20 (morning) — ALL FOUR TITLES PLAY

Continuing the same pass: after #58/#61/#62 landed, each title's next blocker
was root-caused and fixed in turn. **PACMAN, INVADERS, ASTEROID and DONKEY all
enter their game screens, draw, animate and take input in FPGA-SIM.**

**#63 (CLOSED) — event-driven titles halted:** RET_VAL at top of an empty
call stack halts to S_DONE unless rAF or a timer is live
(`vgc_wait_after = raf|timer`). DONKEY's title screen is EVENT-driven — no
rAF, no timer, just keydown listeners — so the VM halted and Enter was never
dispatched. Fix: `vlistener_n != 0` keeps the VM parked at S_WAIT_FRAME (all
three exec64 sites).

**#64 (CLOSED) — key-event objects built with n=0:** KEYEVT's HP_OSETI enters
S_HEAP_WR directly (never through HEAP_WAIT/CMP), and the vobj_len raddr mux
had no S_HEAP_WR arm — the final `vobj_len_rdata < qn+slot` gate read a STALE
address; a stale len >= 3 skipped the len write, so e.key / e.keyCode /
e.type all read undefined (DONKEY's `event.key === "Enter"` gate never
matched; small probes passed by stale-luck). Fix: S_HEAP_WR arm → hp_oid.

**#65 (CLOSED) — BIND completion re-injects stale parent vcsp:** every BIND
completion pokes hs_vcsp(vcsp_ff), but vcsp_ff only tracks parent POKES; a
getter dispatch inside the previous call raises it and exec-side RETs never
lower it. The next exec-entered BIND (class-method call) then absorbed the
stale ff; the kind-3 ALLOC commit saw `ff == e64+1`, treated the call as
parent-reserved, wrote the frame one slot high and leaked +1 vcsp per call
(DONKEY Mario.collision per platform per frame → fault 2 at CSTK). Fix: the
exec-entered BIND first-entry latch (same block as #62) also does
hs_vcsp(e64_vcsp_q); parent-initiated BINDs never run that arm.

**#66 (CLOSED) — two vtimer_n copies, setTimeout starves:** exec's copy only
saw exec's +1s (setTimeout) and -1s (clearTimeout); the parent decrements on
FIRE and never told exec. Exec's count climbed monotonically to 64 and every
later setTimeout faulted 3/3816 (DONKEY schedules several per barrel). Fix:
the parent timer mirror now also adjusts the parent FF on exec set/clear
(parent FF = truth), and the frozen exec absorbs p_vtimer_n.

**#67 (CLOSED) — SET_PROP fast-paths aimed vobj reads at the VALUE:** exec's
vobj_raddr mux used `VST_AT(vsp-1)` for everything but CALL_METH; SET_PROP's
receiver is at vsp-2. The Image.src jmr:spr fast-path's
`vobj_builtin_rdata == 2` check therefore read the string-id slot and never
fired: no FFC sprite class, no dims — DONKEY drew NO art (dihit=0) while
plain SET_PROPs kept working through the parent walk (it re-reads by hp_oid).
Fix: OP_SET_PROP arm reads vsp-2. DONKEY's game screen went from 215 to
~60,000 non-zero pixels, animating.

**Semantics gap noted (not a blocker):** listeners added DURING a dispatch
are invoked for the SAME event (browser defers to the next event) — DONKEY's
title Enter therefore also fires the character-select startGame it just
registered, skipping the character-select screen (single Enter instead of
"Enter twice"). Playable; fix later by snapshotting vlistener_n at dispatch.

**Verification (this build):** probe13 8/8, p58c 5/5, p62b 4/4, p63 3/3,
pdonk 3/3, pdonk2 2/2; PACMAN plays (maze/beans/ghosts/HUD, steering);
ASTEROID plays (mode=PLAY, vectors accumulate, thrust+fire ok); DONKEY plays
(sprites drawn, per-frame animation, ArrowRight moves); INVADERS re-smoke in
flight at write time (previous build after #62: full 55-invader wave, no
fault, HUD + sprites drawn — see below if changed).

## Session 2026-08-20 (early morning) — three root causes closed

**#58 (CLOSED — real root cause at last):** not the promote copy and not the
window-shift depth. The `vst_raddr` mux's S_HEAP_FILL arm keyed on
`casestate_q == S_HEAP_FILL`, which lags one beat — so the FIRST
`S_V64_WIN_FILL` beat after a make_arr fill still presented
`hp_vbase + hp_aslot` (the LAST ELEMENT's slot) as the read address. The
refill's first consumed rdata was that element: `win[1]` got e.g. 15.0 where
the receiver object should be, and SET_PROP silently dropped `{m:[16+]}`.
Fix: exclude the lagged beat (`&& state != S_V64_WIN_FILL`). Verified: VN8/15/
16/17/20 all PASS; probe13 ladder 8/8. Chasing it also surfaced a LET_VAR
first-decode-beat stale-TOS hazard that turned out to be a probe-reading
artifact (the vvar writes were landing at the right slots — the disassembly
operand is not the vvar slot; slot map comes from the name intern order).

**#61 (NEW, CLOSED) — post-GC alloc clobbers a LIVE slot; THE PACMAN killer:**
the GC sweep's resume path re-enters `S_V64_ALLOC` with `valloc_rd_arm` still
set from the exhausted pre-GC scan. The first scan beat then trusted
`*_valid_rdata` whose read address was still the sweep's `vgc_env_i`
(casestate_q lag) — the just-freed slot, rdata 0 — and committed the new env
over LIVE slot 0 (`venv_next` was reset to 0 by the sweep): `venv_len[0]`
wiped, parent rewritten, gen UNCHANGED, so every stale handle now resolved to
the new occupant. PACMAN's Game closure env (holding `_stages`, `_index`,
`_events`) is env slot 0 (first env allocated at boot) and died on the first
mid-frame GC — every later frame `_stages[_index]` read undefined, all draws
silently skipped (black screen), and the Date frame-limiter froze the loop.
Fix: `valloc_rd_arm <= 1'b0` in the sweep resume, forcing a fresh settle read.
Same hazard covered obj/arr/fn allocs. **PACMAN NOW PLAYS** — maze, beans,
pacman, ghosts, score HUD all draw every frame, steering works, no fault.

**#62 (NEW, CLOSED) — class-method fast path allocs with stale kind (the real
INVADERS Space fault):** exec's CALL_METH class-table hit (`cm_mip`) sets
`valloc_kind_n = 3` and enters S_V64_BIND with `bind_ret = S_V64_ALLOC`. But
`assign valloc_kind = (state == S_V64_ALLOC || hs_m) ? valloc_kind_ff : e64_q`
prefers the PARENT FF once state is ALLOC, and this path never poked the FF.
The ALLOC then ran with whatever the last exec-initiated alloc left behind —
after `junk = []` that is kind=1/count=0 — so `bunkers[bi].hitAt(...)` pushed
an EMPTY ARRAY as its "result", never entered the method body, left its args
on the stack, and leaked a call frame per invocation; RETs then warped into
top-level code (re-running the boot particles loop + `animate()`), vfe hit 8
→ fault 3 fsite 5298. Minimal repro: `class B{...}; var b=new B();
var junk=[]; b.hitAt(1,2,2)` — ANY object/array literal between instance use
and a class-table method call. Fix: BIND's exec-entry first-entry latch now
also pokes `hs_valloc_kind/i/retried` from the exec q's (same discipline as
ALLOC's own first-entry). All p62 repro cases PASS.

**Note on #60 (listener scoping):** the "animate stacked three deep" fault
previously blamed on #60 was actually #62. Element-scoped listeners are still
global in RTL (a real compatibility gap — `.click()` fires all click
listeners), but with #62 fixed the Space fault is gone; whether any title
still trips over #60 is retested below.

**Debug tooling added (sim_main.cpp):** IPTRACE arm survives FRAME
(user-armed flag) and records exec vsp per ip; `VSTWATCH <slot>` (vstack BRAM
write watch), `VVWATCH <slot>` (vvars write watch), `BEATLOG <ip>` (per-beat
signal log), `ENVWATCH`/`ENVDUMP`/`ESLOTS <eid>` (env valid/parent/binding
dumps), `GCSNAP?` (roots at GC entry + mark bits at sweep), `FWATCH` (vcsp /
vframe_return_ip transitions), `VFE?` (forEach nest stack with entry ips).

## Session 2026-08-20 (late night) — user-run triage

**Harness bug that poisoned this session's first hour:** `sim_main.cpp`'s
`KEYEVT` parses codes with `sscanf("%u")` — **decimal** — and my probe harness
sent hex ("KEYEVT 0d 1" → code 0, down 0). Every "wrong-listener dispatch"
finding from those probes was an artifact; with decimal codes the dispatch is
correct (probe VK4L: down event → down handler). The GUI always sent decimal,
so no user-visible behavior was involved. Also confirmed: the CONCAT-guard
`hs_ip/hs_vsp` I added last session was unnecessary — reverted (join's kept;
verified needed by VX2). #56 was bisect-cleared (reverted → no change →
restored).

**INVADERS (user: "Space returns to monitor"):** the new fault handler works
as designed — the VM FAULTED and was kicked back to the console. Forensics
from the new trace lines: `fault=3 fsite=5298` (forEach nest cap), `vcsp=24`
with a repeating frame group `(fffc, fffc, 416, 0,0,0, 5081)` — `animate()`
stacked THREE deep. Root cause is **#60 (NEW): listener scoping** — RTL
`addEventListener` on an ELEMENT registers globally, and `.click()` fires
EVERY click listener. The user pressed **Enter** on the splash: the
`playerName` Enter handler fired (should be scoped to that input) →
`saveScoreBtn.click()` → all click listeners including the start button's →
`startGame()` (possibly repeatedly) → `animate()` re-entered → 8 concurrent
forEach walks → fault 3. **Space starts the game correctly** (verified in
harness: obj 23→93, no fault). Fix: store the target oid in `vlistener` and
match it on dispatch; `.click()` dispatches only to the same element.

**ASTEROID (user: "does not go to the game"):** could NOT reproduce — with a
new `VVARPEEK` RPC, after Enter the real globals read `mode=1.0 (PLAY)`,
`tick` counting, `startHeld` edge behaving; attract rocks now draw (they did
not before #49/#55, so the attract screen LOOKS different from last run —
possible source of the perception). If it recurs in the GUI, the trace now
contains enough to compare (`VVARPEEK 84` = mode).

**PACMAN (maze + instant YOU WIN):** both remain explained by **#58**
(ARR_PROMOTE copy corrupts a >32-element array's early slots). The maze data
AND the beans data are ~33-row arrays; the corrupted beans copy makes
`JSON.stringify(beans.data).indexOf(0) < 0` true on frame 1 → instant win,
and the maze draw walks corrupted rows → nothing strokes. Everything else in
the chain is now probe-verified working. **#58 is the single remaining PACMAN
bug.**

**DONKEY:** unchanged — Image-onload art path; additionally its
`event.key === "Enter"` gate sits behind the same #60 scoping question.

**Debug tooling added:** `VVARPEEK <slot>` (one Value64 global + valid bit)
in `sim_main.cpp`; harness note: KEYEVT codes are DECIMAL.

## Session 2026-08-20 (night) — six-item pass

**#56 — APPLIED.** exec64's `vst_we_q` is registered; exec freezes after
issuing a multi-beat parent op, so the stale write request REPLAYED on the
returning FETCH_WAIT beat, overwriting the parent's result. Victim: `join('')`
— the arm pre-writes UNDEFINED at the result slot, `S_JOIN_FIND` writes the
interned handle, the replay clobbered it back to UNDEFINED (`joinmiss=0`, no
fault). Ops whose real result IS undefined (fill/stroke) hid the class. Fix:
`e64_wr_ok` — an exec write is valid exactly one beat after an enabled exec
beat — gating both the vstack port and the window plant. **This was PACMAN's
maze wall gate** (`switch(code.join(''))`).

**#57 — APPLIED.** `vprom_ret_eff = jsb_flags[3] ? e64_vprom_ret_q : ...` had
fixed exec-requested array promotes but broke PARENT-requested ones:
`S_V64_JSON_PARSE` sets the parent `vprom_ret`, exec's copy is reset-0 =
S_IDLE, so parsing an array longer than 32 rows (PACMAN's maze shape)
promoted and then 'returned' into a **silent halt** (VRING:
`S_ARR_PROMOTE → S_IDLE`, fault=0). Fix: `vprom_from_exec` — the promote
first-entry guard fires only for exec entries; both JSON sites mark parent
ownership.

**#54 refinements — APPLIED.** `S_IMGD_PUT` seeds (`imgd_x0/y0` were exec FFs,
worked only because the GET left 0,0; `hs_vnat_base(hp_vbase)`/`hs_ip` on the
`S_V64_OGETI_NAT` nat==1 hand-off); `hs_ip`/`hs_vsp` added to the NAMCPY /
V64_JSON / JSON_PARSE / S_JOIN / S_CONCAT first-entry guards (completions
re-fetch code from the PARENT ip; PACMAN faulted at SET_PROP after its first
maze `getImageData` until this landed — VRING pinned it).

**Items 5+6 (GUI/monitor) — APPLIED in `runtime/sim_backend.py`:**
the GUI letterbox paints from `_typed_log`, never the raw glass, so the RTL's
`?FN FILE NOT FOUND` / `?SN ERROR` replies were invisible — now mirrored into
the console log (verified: typed_log carries them in order). The LOAD wait
loop bails on `?FN`/`?SN` instead of spinning 500×20000 ticks. Traces: the
sim's fault-frozen cycle ring is armed at spawn (`RINGSTOP -1`) and a VM
fault now logs `VRING` + `PX` forensics lines.

**STILL OPEN after this session:**
- **#58 — ARR_PROMOTE copy corrupts contents** (probe `VB1J`/`VB6J`:
  33-row JSON round trip completes but early slots dangle, GC sweeps the
  rows; arr count drops). This is the LAST blocker for PACMAN's maze —
  everything upstream (join, indexOf, JSON, imgd, promote-return) now
  passes in isolation; the faithful wall-draw replica (VPW2) strokes 154
  line px. The real maze uses a >32-row data array; its promoted copy's
  early slots are bad. Next: VARRPEEK the long row after VB6J.
- **#59 — CTOR_VARS ctor_ip==FFFF branch loses `this`** (probe VPI2:
  top-level `var M = function(){ this.data = 5; }; new M()` → data
  undefined, no fault). No current title uses global var-fn ctors
  (PACMAN's are env-local, INVADERS/DONKEY use `class`/`function`), so
  glass-impact nil today.
- DONKEY art: Image-onload dispatch (unchanged, see previous block).
- INVADERS "Space does not advance": **rerun on this binary** — the old
  freeze was `drawHud`'s inlined `drawCannon` reading `i`/`extras` via
  the slot hints #55 removed; likely fixed, unverified.

## Session 2026-08-20 (later) — PACMAN game screen + ASTEROID rocks

User report: PACMAN reached the game screen but drew no maze/pacman and said
"YOU WIN!" immediately; ASTEROID played (ship turns/shoots) but spawned no
rocks. Probe-verified fixes, in dependency order:

**#54 — APPLIED.** Four more #53-class direct-entry states without first-entry
guards, now guarded with seed copies + `hs_ip(e64_ip_q)`/`hs_vsp(e64_vsp_q)`:
- `S_NAMCPY` (JSON.parse of an interned string faulted 1 at the next LET_VAR,
  fsite 3423 — every seed lived in exec FFs, parent copies never written);
- `S_V64_JSON` (stringify: **plus** exec's `js_we` seeded `vjs_val[0]` into
  exec's OWN array copy while the parent walker read the parent's — mirrored
  via new `js_we_q`/`js_waddr_q`/`*_wdata_q` taps, #49-style);
- `S_V64_JSON_PARSE` (guard gated on `state !=` too — parent-side entries from
  NAMCPY must not be clobbered);
- `S_IMGD_GET` (PACMAN's maze `getImageData` cache — all `imgd_*` seeds).
The `hs_ip` matters: completions end with `hs_code(ops_base + ip)` on the
PARENT ip; without the latch PACMAN's first maze cache completed then decoded
a stale op and faulted 1 (VRING forensics: `RINGSTOP -1` + `VRING?` froze on
the fault and showed IMGD completing at the right sp, then EXEC at the right
ip with wrong code). This mattered only once #53 made the JSON round-trip
reachable — the fault was younger than the session but the hole was not.
Result: `JSON.parse(JSON.stringify([[..],[..]]))` — **PACMAN's maze deep-copy
at PACMAN.HTML:291, the single cause of both "no maze" and "instant YOU
WIN"** — passes; PACMAN runs its 1.28M-clock cache frames with fault=0.
Still imperfect, no title uses them in play: `JSON.parse("5")` (bare scalar)
and `JSON.parse('{"a":1}')` (object root) return wrong non-faulting values.

**#55 — APPLIED.** The env-walk **slot hint** (`hp_slot = a1 - 2`) seeded the
scan START, but the walk runs hint..len-1 and never revisits the skipped
prefix. The compiler inliner can rebind a name at a LOWER slot than the
inlined body's hint (probe VR1F: `function place(sz){ return spawn(sz, 1); }`
with callee param also named `sz` — inlined, `sz` at slot 0, hint slot 1 —
LOAD_VAR returned undefined, fell to vvars, no fault). This is the retracted
**#50** half-vindicated: lookups ARE name-keyed, but the slot still mattered
as a scan start. PYTHON ignores the hint entirely. Fix: both exec64 hint
sites now `hp_slot_n = 5'd0` — always scan from 0; envs are <=16 slots,
extra beats legal. This was **ASTEROID's missing rocks**: `spawnRock`'s
inlined body read its fields as undefined, `rockRad(undefined)` → NaN →
clipped. Probe VR1 (exact spawn shape) passes; bisect probes VR1A-K/Q/R all
pass.

**Verification:** full ladder 8/8 (arrays, proto, closures, forEach, class),
JSON probes VQ2/VQ3/R2 pass, PACMAN smoke fault=0 through the maze-cache
frames with objects growing on Enter, ASTEROID smoke fault=0. #55 was
bisect-cleared of the transient PACMAN fault (reverted → fault persisted →
restored).

**Debug tooling added to `sim_main.cpp`:** `VARRPEEK <aid>` (Value64 array
tables + 8 raw slots). Existing `RINGSTOP -1` + `VRING?` (fault-frozen cycle
ring) proved decisive — use it first next time.

**Still open after this round:** DONKEY art (Image-onload dispatch, see
previous session block); JSON scalar/object roots (above); the exec-direct
`S_HEAP_WR` measureText metrics write (same class, unguarded, glass-only);
nested `function` declarations discarded by the compiler (MAKE_FN + POP).

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

## Correctness bugs — 2026-08-19 review snapshot (statuses have drifted)

**Read the status column as "what we believed on 2026-08-19", not as
current truth.** Almost everything marked *open* here was fixed later that
week; **user play is fine.** Suite xfails **#70 / #71 / #72** are at the
top of this file. **#79** is a harness lesson, not a title bug.
Kept because the *analysis* columns (where, why, cost) are still the best
description of those code paths — especially **#1/#2/#3**, the intern FIND
scan, which is genuinely still open and now has measured numbers in
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).

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

## Compatibility command map (inspection only) — superseded

**Use [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) instead**; its
Frozen ISA tables are maintained and carry the 2026-08-21 additions
(`findIndex`, `dispatchEvent`, `ctx.font`, `Object.keys` nid 41, …). This
table is a 2026-08-19 silicon-vs-claim audit, kept only because its
per-verb "what the RTL actually does" notes occasionally explain a console
behavior the compat doc states more briefly.

Opcode numbers, FM/RTL mnemonics, and native ids 0–41:
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md#bytecode-opcodes-34).

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

## Graphics that look like a freeze (HTML → RTL) — **architecture lesson, keep**

Per-ID statuses below are stale (**51** landed; **31** landed; the blit
runs). The **cost model is the lesson and it is still exact**: this is a
1-pixel-per-clock raster, so a full 640×480 paint is ~307k clocks and a
title that paints two full screens per frame cannot be "fixed" by chasing
a phantom infinite loop. Measured per-state numbers now live in
[SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).

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

## Cut 2026-08-21: "Confidence" / "Typed patches" / "Suggested order"

Those three sections were the **2026-08-19 pre-fix planning** for bugs that
have since been fixed, retracted, or superseded — a to-do list of work that
is done. They were the most misleading thing in this file: a reader landing
there saw open items that are closed.

What they contained that still matters is preserved above:
- the retraction lessons (**#46**, **#50**) → *Retracted theories* in
  [RECURRING BUG CLASSES](#recurring-bug-classes--read-this-before-debugging-anything);
- the applied fixes → the dated session entries, each with its root cause;
- the still-open speed items (FIND hash→id, the 1 px/clock raster cost) →
  [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md), which has measured
  per-state clock numbers instead of estimates;
- the remaining suite notes → **#70 / #71 / #72** (xfails, not F9 play);
  **#79** is a harness/attract lesson, not a play blocker.

Recover the originals with `git log -- "docs/potential bugs.md"` if you
ever need the 2026-08-19 reasoning.