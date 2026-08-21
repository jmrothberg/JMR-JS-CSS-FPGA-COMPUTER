# Intern FIND — play speed (not the T200 OOM)

**2026-08-21:** five titles **play** on FPGA-SIM; they are **slow**. This
file is clocks-per-frame, not synth OOM. The bitstream cleanup
([FPGA_FIT.md](FPGA_FIT.md): exec32 cut + LUTRAM Port A) is **done** — the
tree is synthesis-ready, so the items here are now the next work after the
user's `make bit`. Do not mix a FIND/speed pass with a fit pass.

**Two different speeds — do not confuse them.** (a) *VM clocks per frame*:
what this file tracks; it is what makes the real FPGA fast or slow. (b)
*Verilator host throughput*: ~800k clk/s after the exec32 cut (+16% from
the netlist shrink alone, measured 2026-08-21), which only affects how
long FPGA-SIM takes on the workstation. A win in (a) helps both.

**2026-08-21 (fit pass) deltas — remeasure after the next profile:**
the object heap shrank to 768 (PACMAN rides ~690), which raised forced
GC from ~4 to ~10 runs/frame — the GC line below is now UNDERSTATED, and
the "GC frame-end skip / pacing" item is promoted to the top of this
ledger. `putImageData`/`getImageData` now stream over the external SRAM
port (~2-3 clk/px vs 2, plus ack), so S_IMGD_PUT is modestly slower on
the board path. Both were deliberate fit-for-speed trades
([FPGA_FIT.md](FPGA_FIT.md)).

# Measured clock sinks — PACMAN play frame (2026-08-20, STATEHIST?)

3.5M clk/frame, 4 GC runs/frame. The whole frame, ranked:

| State | /frame | % | What |
|---|---:|---:|---|
| `S_V64_GC_*` (all) | ~850k | **24%** | 4 mark-sweeps per frame. Every one is a **forced alloc-failure GC** (arr heap 1352/1536 live — ~180 slack, PACMAN churns temp arrays through it 4×/frame) plus the scheduled frame-end pass. `S_V64_GC_ARR` alone is 19% (element walk of ~1350 live arrays). |
| `S_V64_RECT` | ~620k | 17% | fillRect at 1 px/clock (~2 full screens painted per frame). |
| `S_IMGD_PUT` | ~615k | 17% | putImageData full-maze restore at **2 clk/px**. |
| `S_JOIN_FIND` | ~560k | 15% | intern FIND. The last-4 cache (Step 1) landed but PACMAN mints fresh dynamic strings per frame (score text, JSON keys) — every miss is still O(names_n). **Step 2 (hash→id) is where this goes away.** |
| `S_FB_SYNC` | ~307k | 8% | post-present bank copy (canvas persistence — cost by design, 1 px/clk). |
| `S_V64_EXEC`+fetch | ~300k | 8% | per-op decode. |
| `S_HEAP_*` | ~190k | 5% | walks (post speed-pass hints). |

INVADERS play is the opposite shape: 10.6M clk/frame, ~66% S_V64_EXEC
(per-op cost of JS per-pixel sprite loops), heap walks 10%.

Candidate cuts, cheapest-first, each its own pass with its own FPGA-SIM
run (all reduce clocks → speed **both** FPGA-SIM and the board):

1. **FIND Step 2** (hash→id, this file's own plan): −15% PACMAN. Contained.
2. **S_IMGD_PUT 2→1 clk/px**: pipeline the linear copy exactly like
   S_FB_SYNC's addr/data trailing pattern. −8% PACMAN. One state.
3. **Skip the scheduled frame-end GC when a forced GC already ran this
   frame** (flag set by the alloc-retry GC entries, cleared at frame
   end): −4-6%. Scheduling only; forced GCs still run on pressure.
4. **fillRect 4 px/clock** (mini_fb write port 8→32-bit + byte enables,
   aligned bursts; S_CLEAR/S_RECT/S_FB_SYNC writers): −12% PACMAN and
   big for DONKEY/INVADERS full-screen paints. Touches the FB port —
   medium risk, do LAST.
5. GC_ARR per-array "no-refs" skip bit: biggest GC lever but easy to
   corrupt the heap — **not** low-risk; design first.

# START HERE — intern FIND is slow for every title

**2026-08-18 INVADERS splash sprites:** F9 bars-only (`nz=19233`). CALL_METH
fillRect/clearRect now WIN_FILL-reloads `vst_win` (SRAM truth) then retries
native; `cm_win` holds across `leave_hold`. `hs_vsp(e64_vsp_q)` stays.
User F9s. Do not `make bit`. Do not combo-peek BRAM.

**2026-08-18 HEAP slot pipeline (FPGA-SIM, still Port A):** same-oid/eid
key walk stays in `S_HEAP_CMP` with `hp_slot_pend` (1 extra clock for
`*_rdata` + overlay latch). Object/env GET skips the `varr_long` arm.
Class-table miss stays in CMP (FF match already one clock). Do not
combo-peek BRAM. Do not `mem[i] <=` from the FSM.

**2026-08-18 last-4 FIND cache (FPGA-SIM):** in `S_JOIN_FIND` only
(`jn_hit_*` FFs, one Port-A compare/clock, no CAM, no title gate).
Splash still `WAIT_FRAME` `fault=0` `nz=19233`. Space still starts play
(`obj=732` `fault=0`). First play `FRAME` still `FB SAME` `fcap=1`
`fclk=64000000` *before* HEAP pipeline. **Sampled state moved to
`S_V64_EXEC` / `S_HEAP_WAIT`, not `S_JOIN_FIND`.** FIND is no longer the
cap-time stall. Ledger step 2 (hash→id BRAM) not started.

**CRITICAL — do this before any other glass/RTL hunt.**
Without a faster intern FIND, games **cannot** finish a play frame on
FPGA-SIM. Other patches (PACMAN ctor, extra waits, HTML, FRAME cap)
**will not help.** Headless proof: Space starts INVADERS play
(`obj=732` `fault=0`) then **~800 million clocks** still in
`S_JOIN_FIND`; `FRAME` returns `FB SAME`. Paint/keys/heap are far
enough. The frame never **ends**. This FIND change is VM-wide (every
title that does `"…" + n` / join / `fillText`). It is not optional
polish and not a one-game hack.

**Rule 1:** never hardwire a title. No `if (stem == "INVADERS")`, no
alien/maze/DK constants, no buffer sized to one HTML. The three games
are **acceptance tests**. The ISA is bytecode. Law:
`no-game-hardwire.mdc`, `never-fake-fpga-sim.mdc`, `one-heap-keep-gen.mdc`.

You are **not** fixing the 70 GB Vivado hang (Port A — keep it). You are
making **`S_JOIN_FIND` fast for any compiled HTML** that concatenates or
interns strings (`"SCORE "+n`, maze codes, `fillText`, `arr.join`).
That same FIND is why F9 cannot finish an INVADERS play `FRAME`; PACMAN
and DONKEY pay the same scan whenever they intern. One VM change, all
titles.

Do not run Vivado / `make bit`. Do not start a second bug until FIND
repeat-hits are fast and a play `FRAME` dumps FB.

---

## PASTE TO NEXT AGENT — restore play speed without undoing Port A

**This FIND cache is mandatory for playable F9.** Skip it and no other
fix will make a play `FRAME` complete. Do not work PACMAN/DONKEY/ctor
until repeat intern hits are fast.

**Do not `git revert`, `git reset`, or restore an old `jmr_js_vm.sv`.**
That old tree wrote `stack[i] <=` / `imgd_pix[i] <=` from the parent FSM
and hung Vivado at **70 GB**. The slow intern scan is **speed debt after
Port A**, not a reason to throw Port A away.

**Do not revert PACMAN ctor / ALLOC overlay / `ctx_sx` / HEAP_CMP /
`leave_hold` / gen checks.** Those are glass correctness. FIND is the
play-speed job.

**One change, one file, one state.**

File: `rtl/engines/jmr_js_vm.sv` only. State: `S_JOIN_FIND` (~line 7629).
Today `jn_i` walks `0 .. names_n-1`, two clocks per slot, every `"SCORE "+n`.

Add four flip-flops plus one try flag (names already in this file: `jn_h`,
`jn_len`, `jn_i`, `names_n`):

- `jn_hit_h`, `jn_hit_len`, `jn_hit_id`, `jn_hit_valid`
- `jn_cache_try` (so a miss does not loop on the cached id)

**Do not edit** the `name_hash_tbl` Port A process (`if (name_hash_we)` /
`rdata <= mem[raddr]`). **Do not edit** the `name_hash_raddr` mux — it
already uses `jn_i[9:0]` in `S_JOIN_FIND`. Point `jn_i` at the cached id
and the existing wait (`jn_rd_arm`) + compare already works:

```
name_hash_rdata == jn_h && e32_name_len_tos == jn_len
```

(`e32_name_len_tos` is already `name_len_tbl[jn_i]` in FIND.)

On FIND entry (`if (state != S_JOIN_FIND)` beat): if `jn_hit_valid`,
`jn_i <= jn_hit_id`, `jn_cache_try <= 1`. Else `jn_i` stays 0 (today).

On compare **hit** (existing `stack_wr` / `vst_wr` + FETCH): also store
that id/hash/len into the four FFs, `valid=1`.

On compare **miss** while `jn_cache_try`: `jn_i <= 0`, `jn_cache_try <= 0`,
`jn_rd_arm <= 0`, stay in FIND (linear scan as today).

On **alloc** (existing `name_hash_wr` + `names_n+1`): update the four FFs
to the new id.

Clear `jn_hit_valid` on reset and wherever `names_n` is zeroed (RUN /
heap clear). Do not skip that or a stale id after LOAD is a wrong string.

**Legal writes in this edit:** `stack_wr` / `vst_wr` / `name_hash_wr`
already on the hit/alloc arms — do not add `stack[i] <=` or
`name_hash_tbl[i] <=`. One `stack_wr` per clock. Extra clocks OK.
No new module. No CAM in `unique case`. No title name as a gate.
Do not raise the 64M `FRAME` cap. Do not `make bit`. Rebuild with
`make -C sim sim_server_synth`, then restart the GUI / headless sim.

**Prove (INVADERS is the test, not a special case):** splash
`WAIT_FRAME` `fault=0` → `KEYEVT 32 1` → play `WAIT_FRAME` `fault=0`
inside a `FRAME` (today: 64M clocks still in `S_JOIN_FIND`). `FRAME`
must dump FB, not `FB SAME`. Same RTL must intern `"SCORE "+n` for any
HTML.

**If that still cannot finish a frame:** HUD often interns **several**
different strings per `animate()` (`"SCORE "+n`, `"HI "+n`, …). A
single last-hit thrashes. Same FIND, still FFs: last **four**
`(hash,len,id)` slots, probe them one Port A compare each (still
`jn_i` + `jn_rd_arm`), then linear scan. That is still this job, not
a new architecture. If four still cannot finish a frame: **stop and
ask** (hash→id BRAM, §4 step 2). Do not add a 16-wide CAM. Do not poke
Port A arrays from the FSM. Do not touch PACMAN `intern_ctor` /
DONKEY onload as a substitute.

---

## Safe while the first `.bin` is still synthesizing?

**Yes.** The 16:17 `make bit` already ingested `jmr_js_vm.sv` at start.
Edits on disk do **not** enter that job. Do **not** kill it. Do **not**
start a second Vivado. Do **not** `bit-fresh`.

This FIND work is **FPGA-SIM only**: `make -C sim sim_server_synth`,
restart the sim/GUI, debug. That is the minutes-long path. The running
bitstream compile is hours and is the **previous** RTL (Port A, no
FIND cache). After that `.bin` exists, the **next** `make -C
tools/board_flow bit` (not `bit-fresh`) picks up FIND. Two compiles of
the same file is normal. Do not wait for silicon to debug FIND.

---

## Other flatten-hunt mistakes — would they make it 10×?

**Almost none.** The measured 64 million clock stall is intern FIND
walking up to 1024 names, twice, **every** `"…" + n`. That is ~2000
clocks per concat. Extra `*_rdata` waits are 1–4 clocks. Do not “fix”
those this pass — they are the legal SRAM shape.

| Flatten leftover | Clocks (order) | 10× play? | This pass |
|---|---|---|---|
| **`S_JOIN_FIND` linear intern** | ~2 × `names_n` (up to ~2000) **per concat**, many concats per frame | **Yes. This is the 10×–1000×.** | **Do this** |
| Last-1 cache vs 3–4 HUD strings | Last-1 misses all but one concat/frame | Maybe the difference between “better” and a finished `FRAME` | Last-**4** FFs if last-1 is not enough |
| `S_JOIN` / `S_CONCAT` 3 waits (`jn_rd_arm` / slot / name) | +2 clocks on an already-legal path | No (2 vs 2000) | Keep waits. Do not combo-read |
| CONCAT digit loop | one subtract/clock of the integer | No once FIND hits | Leave |
| Class scan `cls_scan` | 16 classes × 16 methods FFs | No (~256 clocks) | Leave. Not 1024 objects |
| `intern_var[id]` | already index + wait | No | Leave |
| Timer due / compact | 64 slots × 2 clocks **once per frame** | No (~128 vs 64M) | Leave |
| cstack refill | 2-deep window | No | Leave |
| `sin_q` / arc 4 beats | per trig, not HUD intern | No | Leave |
| HEAP extra wait beat | +1 per GET_PROP | No (~1 µs, already in FPGA_FIT) | Leave |
| Exec CALL third-operand wait | +1 per call | No | Leave (glass) |
| `casestate_q` / `unique`→`case` / IEEE mul moved | decode shape, failed 70 GB hunts | No intern O(n) | Do not churn |

So: **one real speed revert** (FIND cache). Everything else on that list
was either required for Port A or is noise next to FIND. Do not open a
second flatten hunt while INVADERS play still dies in `S_JOIN_FIND`.

---

## What is broken (plain)

Intern find walks `names_n` (up to 1024) **one id per clock**. Every
`+` / join that builds a string does that. Repeat lookups of the **same**
string still rescan from 0.

**Acceptance (not a special case):** `INVADERS.HTML` splash works
(`WAIT_FRAME` `fault=0` `nz0≈19233`). Space (keycode 32) starts play
(`obj=732` `fault=0`). Play `animate()` does `"SCORE "+score` etc. and
never returns to `WAIT_FRAME` in 64M clocks (~800M still not enough).
GUI `FRAME` → `FB SAME`. Same FIND path would starve any title’s HUD.

Do not rewrite any `.HTML`. Do not skip PACMAN/DONKEY **semantics** —
just do not start a second architecture hunt. They ride this FIND fix.

---

## What you change (one place, VM-wide)

File: `rtl/engines/jmr_js_vm.sv`  
State: `S_JOIN_FIND` (search `not a 16-CAM`).

Today: `jn_i` counts `0 .. names_n-1`. Each step: hash `raddr`, wait,
compare. ~2000 clocks per intern.

Add four flip-flops: last intern **hash**, **length**, **id**, **valid**.
Every FIND in the machine uses this (not “the INVADERS cache”).

When FIND starts:

1. If valid, set existing `name_hash_raddr` to the cached **id** (Port A,
   data next clock).
2. If `name_hash_rdata` and length match → that **id**, same writeback
   as today’s hit (`vst_wr` / `stack_wr`), FETCH. **Do not scan.**
3. Else existing `jn_i` loop. On hit or alloc, update the FFs.

Never `stack[i] <=`. Never combo `name_hash_tbl[i]` for many `i`.
No new module. No title name in comments as a gate.

---

## How you know it worked

```
unset JMR_SIM_HOST
make -C sim sim_server_synth -B
```

Titles are tests. Prove FIND on INVADERS play (worst measured JOIN),
not a private snippet that the chip never runs:

1. Load `storage/INVADERS.HTML`.
2. `TICKN` → `WAIT_FRAME` `fault=0` splash.
3. `KEYEVT 32 1` (Space).
4. `TICKN` → `WAIT_FRAME` again `fault=0` (today: does not happen).
5. `FRAME` prints `FB 640 480 …`, not `FB SAME`.
6. `nz0` moves vs splash.

A tiny HTML that `rAF`s `"SCORE "+0` `fillText` in a loop must also
reach `WAIT_FRAME` quickly — same FIND, no title stem.

If FIND still sits at one `eip` for many `TICKN 20000`: cache not
wired, or hash/len never match. `VMSTAT?` + `IPTRACE?`. Do not add
PACMAN ctor patches.

If repeat strings are fast but **every new** intern still costs a full
table walk and a frame still cannot finish: **stop and ask** (hash→id
BRAM, still VM-wide). Do not raise the 64M cap. Do not add a CAM.

---

## Do not touch (this is how we wasted 10 passes)

- Port A `if (we) mem[waddr] <= wdata` blocks.
- `stack[i] <=` / `vobj_alloc[i] <=` in the big FSM.
- Title-named gates, rewrite HTML, skip gen, clone heaps.
- PACMAN intern_ctor / DONKEY onload as a substitute for FIND.
- `make bit`. New debug programs. New README.

`VMSTAT?`, `IPTRACE`, `FBRAW?` already exist in `sim/sim_main.cpp`.

---

## Why (one paragraph)

Vivado hung at 70 GB because the VM FSM **wrote** big memories.
Fix: Port A. **Keep that.** Intern find was then linearized so the
unique case would not grow RAM ports. That full-table walk is **not**
required to keep Port A. Every title that builds strings needs FIND
fast on **repeats**. The last-hit FFs are language/VM, not a game.

Background / later hash→id BRAM: §1–4 below.

---

## 1) The bug that was actually synthesis

**Symptom:** Vivado RSS 8 → 36 → **70 GB**, log frozen. Heap as FFs
(Synth **8-3967** / **8-4767**).

**Cause:** large unpacked arrays written from the parent VM `always_ff`
(`imgd_pix[i] <=`, `spr_mem[spr_wp] <=`, later the same class:
`stack[i] <=`, `vobj_alloc[i] <=`, …). Isolated `rdata <= mem[raddr]`
**while those writes stayed in the FSM** still blew 71 GB (15:22). Moves
writes to a tiny Port A process (`if (we) mem[waddr] <= wdata`) → ~15 GB
hold after `e32_p_clr` (15:32). That is UG901 simple dual-port / AR 58025
territory.

**Keep forever:**

- Pictures + heap tables: `jmr_mini_fb`-shaped Port A. FSM only pulses
  `*_we` / `*_waddr` / `*_wdata` (`stack_wr`, `vobj_alloc_wr`,
  `varr_len_wr`, `name_hash_wr`, `vvars_wr`, `json_putc`, `imgd_we` / …).
- One stack write per clock (`stack_dual_pend` for FOREACH el then idx).
- Address in this clock, `*_rdata` next. No combo `mem[f()]` in
  `unique case`.
- No one-cycle reset-clear of BRAM. No `ifdef SYNTHESIS` smaller heap.
- `arr_len` / `vobj_cls` are still FSM-poked (8-13159) — Port A if touched.

`e32_p_clr` Synth 8-6014 is unused-FF housekeeping, **not** the hang.
Kill synth only if the log is frozen **and** RSS is climbing toward ~80 GB.

Failed hunts that did **not** stop the 70 GB wall (do not repeat as “the
fix”): named unique-case peek hunts; `casestate_q`; `unique` → `case`;
pulling IEEE mul out of the case; read-port-only splits.

---

## 2) What we then did while chasing the wrong bug

After Port A, glass still looked broken (black, hung `FRAME`, mid-rAF
present). Agents assumed **more flatten**, and turned every table walk
into **one index + wait + compare**, including places that were never the
70 GB cone.

**Measured INVADERS (headless FPGA-SIM, 2026-08-18):**

| Step | Result |
|---|---|
| Splash | `WAIT_FRAME` `fault=0` `raf=1` `nz0=19233` (bars + `fillText`) |
| Space | `fault=0` `obj=732` — **play started** (`drawHud` CONCAT, `player.update`) |
| One play `animate()` | Does not return to `WAIT_FRAME` inside 64M clocks |
| Sample during play | `sname=S_JOIN_FIND` at HUD `"SCORE "+n` / `"HI "+n` intern find |

`S_JOIN_FIND` comment in `jmr_js_vm.sv`: *one intern slot/clock via
`name_hash_rdata` (not a 16-CAM)*. `name_hash_tbl` is already Port A
BRAM (1024×16). The CAM was killed so the unique case would not grow N
RAM ports. Linear scan of `names_n` (up to 1024) × 2 clocks (arm +
compare) × every string concat / join is what F9 hits. GUI `FRAME` then
returns `FB SAME` (`fcap=1`) — comment in `sim/sim_main.cpp` already
names INVADERS `drawBitmap` + this cap.

PYTHON F9 was never this slow (behavioral intern). Titles “used to work”
on illegal combo/CAM/FSM pokes; legal SRAM + linear JOIN is the crawl.

`GET_PROP` extra clocks at core ≈100 MHz (MIG `ui_clk`; old notes said ~30 MHz wish) were documented as playable
([FPGA_FIT.md](FPGA_FIT.md) ~1 µs vs 16.7 ms/frame). **Full intern-table
JOIN per HUD concat and per bitmap path is not in that budget.**

---

## 3) Ledger — keep vs speed-debt

### A. Must keep (real UG901 / hang)

| Change | Why it stays |
|---|---|
| Port A write processes for `imgd_pix`, `spr_mem`, `name_mem`, `json_mem`, `stack`, `name_hash_tbl`, `varr_len`, `vobj_alloc`, `vvars` | 70 GB cause |
| `*_rdata` wait; no combo peek | AR 58025 / 8-3967 |
| No `mem[i] <=` in the 7k-line FSM, including glass/debug | Putting `stack[i] <=` back **is** the hang |
| One `stack_wr` per cycle | Dual write = two ports / hang class |
| Caps `MAX_OBJ=1024`, arrays 1536×32+128×128, `ENV_DEPTH=512` | Chip BRAM, not flatten |
| Generation check on handles | Product (`one-heap-keep-gen`), not synth |

### B. Speed debt — flatten hunts that were **not** the 70 GB bug

These are the “we hurt the code” list. Restore **speed** only with the
same Port A shape (scalar `raddr`, registered `rdata`). Do not put a CAM
or `mem[i]` compare back inside `unique case`.

| Location (parent `jmr_js_vm.sv` unless noted) | What it does now | Why it was done | Play cost | Legal restore (synth must bless) |
|---|---|---|---|---|
| **`S_JOIN_FIND`** | `jn_i++` through `names_n`; 2 clocks/slot | “not a 16-CAM” | Any title intern (`+`, join, HUD `fillText`); INVADERS play is the measured 64M miss | Last-hit intern cache (FFs, still one `name_hash_rdata` wait). Or hash-bucket. **Not** a CAM in unique case. **Not** a JOIN module. **Not** a title gate. |
| `S_JOIN` / `S_CONCAT` / `S_IDXOF` | `jn_rd_arm` + `jn_slot_arm` + `jn_name_arm` (3 waits before one elem) | flatten: long then slot then name_hash | Every `arr.join` / `+` / `indexOf` | Keep waits (rdata is real). Do not merge into combo reads. |
| `S_CONCAT` digit loop | one subtract/clock of `P10[cc_pi]` | serial integer fold | `"SCORE "+n` every HUD | Fine at core ≈100 MHz if JOIN_FIND hits. JOIN is the long pole. |
| Timer due / compact | **one `to_delay` slot/clock** (“not 64 SRAM ports”) | flatten hunt | rAF/timer fire walks 64 | Sequential walk is legal; 64 combo ports are not. Leave unless a tiny due-FF set exists. |
| cstack refill | **one slot/clock** into 2-deep window | flatten hunt | call/return | Keep window FFs; do not combo `cstack[i]` from unique case. |
| `sin_q` / arc | 4 beats wait ROM | flatten: not function peek | `fillText`/arcs | Keep; not INVADERS play. |
| HEAP long→slot | extra `HEAP_WAIT` beat | flatten: `varr_long` then slot | GET_PROP/SET_PROP | Keep wait; `cls_*` 16×16 FFs already exist — do not linear-scan 1024 objects for one property. |
| Exec CALL third-operand wait | extra EXEC beat | glass (operand SRAM), not 70 GB | every call | Keep until exec window is proven; not JOIN. |
| `unique`→plain `case`, `casestate_q`, IEEE mul out of case | decode shape | failed 70 GB hunts | LUT/timing, not intern O(n) | Do not churn again for glass. |

### C. Do not treat as synth; do not undo for speed

Skip gen / clone heaps / second `vvars` in exec / `leave_hold` in enable=0
else / sticky `hs_m_vcsp` / rewrite any title HTML / raise Python to match
slow RTL / title-named speed paths.

Sim-only: `FRAME` cap 64M in `sim/sim_main.cpp` **hides** an unfinished
rAF (`FB SAME`). Raising the cap makes F9 freeze longer; it does not make
silicon hit 60 Hz. Fix JOIN, do not ship a 512M cap as the game.

---

## 4) Plan to give synthesis (JOIN intern — VM-wide)

**Goal:** intern FIND on **repeat** strings is O(1) wait, not O(`names_n`).
Any title’s `animate()` that concats HUD / join / `fillText` can return to
`S_WAIT_FRAME` in well under 64M clocks. No JOIN module. No combo
`name_hash_tbl[i]`. No title stem.

**Step 0 — prove (glass, already true on INVADERS as test):** Space
reaches play (`obj=732`, `eip` in `drawHud` / `player.update`,
`fault=0`). Sample: `S_JOIN_FIND` walking intern ids.

**Step 1 — last-hit cache (all FIND):** FFs
`(jn_hit_h, jn_hit_len, jn_hit_id, jn_hit_valid)`. On `S_JOIN_FIND` entry,
set `name_hash_raddr = jn_hit_id`, wait one clock, if
`name_hash_rdata == jn_h && e32_name_len_tos == jn_len` → same id, FETCH.
Else linear scan; on hit/alloc update the FFs. Same Port A mux. Repeat
`"SCORE "+0` / any interned concat hits; `char_id[]` already covers
single-char `str[i]`.

**Step 2 — faster miss (synth, still VM-wide):** first use of a new
string must not be O(`names_n`) if frames still cannot finish. Hash→id
Port A RAM or bucket chain — budget in [FPGA_FIT.md](FPGA_FIT.md). Not
a CAM. Not a new JOIN module.

**Step 3 — acceptance:** INVADERS Space → play `WAIT_FRAME` + `FRAME`
`got=1` (test). Same RTL must not contain a title name. Then F9. Agent
does not run Vivado.

**If BRAM is over 365 tiles:** do not “save” JOIN by putting intern in
LUTRAM/FFs. Cut or share a real tile; intern find is not optional for
`fillText` / `+`.

---

## 5) How to talk about this in a synth review

1. **Hang cone** = FSM writes to big memories. Port A is the fix. Done;
   do not reopen for titles.
2. **Play cone** = intern find is a full-table scan because we flattened
   a CAM. That scan is **not** required by UG901. A registered 1-compare
   /clock CAM was the over-correction.
3. Extra `*_rdata` waits on heap/name/imgd **are** required. Do not merge
   them. Do not add more waits on a hunch.
4. One new BRAM for hash→id is a **fit** question, not a flatten question.
   Quote `utilization_synth.rpt` when synth_1 is 100%; do not invent LUTs.
