# 30 pictures per second — the speed plan

Words: [README.md — Words used](../README.md#words-used-in-this-project).

## Teach-me: FPGA-SIM is slow; the board should not be slower

Two different computers:

| Where you play | What is actually running | How fast the heartbeat is |
|---|---|---|
| **PYTHON** (GUI F9) | A Python program pretending to be the machine | As fast as your PC. This is the playable-on-the-PC path today |
| **FPGA-SIM** (GUI F9) | **Verilator** — your PC simulating **every** chip step in software | About **800,000** simulated heartbeats per **second of wall-clock** |
| **BOARD** (real FPGA) | The same RTL, on silicon | About **100 million** heartbeats per second (**100 MHz**) |

**FPGA-SIM is too slow to play. That is the simulator, not the chip.**
800k vs 100 million is about **125×**. One INVADERS picture that takes
~13 seconds in FPGA-SIM would take ~0.1 second on the board — still not
30 pictures/second, but **much faster than FPGA-SIM**, not slower.

Verilator will **not** become 30 fps for these titles. We already tried
more Verilator threads: they refused or ran *slower*. Do not chase
FPGA-SIM playability as the product goal.

**Product goal (this file):** all five Version 1.0 titles at **at least
30 pictures per second on the BOARD** (100 MHz). PYTHON stays the fast
PC ruler. FPGA-SIM stays the correctness check (it will still look like
a slideshow).

## The 30 fps budget (plain numbers)

30 pictures per second means each picture may cost at most:

**100,000,000 ÷ 30 ≈ 3.33 million heartbeats.**

(60 fps would be 1.67 million — later, not the first target.)

Measured play pictures (2026-08-20, before the last fit shrink; **remeasure**
after the current caps / ImageData-on-SRAM):

| Title | Heartbeats per picture | FPGA-SIM wait (800k/s) | Board pictures/s at 100 MHz | Hits 30 fps on board? |
|---|---:|---:|---:|---|
| **INVADERS** | **10.6 million** | ~13 s | **~9** | **No** — need about **3×** fewer heartbeats |
| **PACMAN** | **3.5 million** | ~4 s | **~29** | **Barely** — GC got heavier after the fit shrink; treat as **must cut** |
| **DONKEY** | **0.71 million** | ~0.9 s | **~140** | **Yes** on paper |
| **ASTEROID** / **MRDO** | not in this table | ? | ? | **Remeasure** (first speed job) |

INVADERS is the hard one: ~66% of its picture is **per-operation JavaScript**
(the HTML draws sprites with a loop of tiny `fillRect`s). Killing FIND /
Garbage Collection alone **cannot** get INVADERS to 30 fps — even if those
went to zero, the remaining ~7 million heartbeats would still be only ~14
pictures/s. PACMAN’s cost is the opposite shape (Garbage Collection +
full-maze `putImageData` + `fillRect` + string FIND).

## Ordered plan (no title-name gates, no Port A undo)

Do **not** mix this with `bit-fresh` / fit. Extra clocks for legal RAM
stay. Do **not** rewrite a title’s HTML to dodge the VM. Do **not**
`if (stem == "INVADERS")`.

0. **Remeasure** all five titles on current RTL (`STATEHIST?` — per-state
   heartbeat counters already in the sim). Fit-pass Garbage Collection
   and ImageData-over-SRAM changed the PACMAN numbers. ASTEROID / MRDO
   have no row yet.
1. **PACMAN / DONKEY / (likely) ASTEROID+MRDO — get comfortably under
   3.33 million** with the cheap VM-wide cuts (already designed here):
   - FIND Step 2 (hash→id Block RAM): −15% PACMAN. Not a CAM.
   - Skip extra end-of-picture Garbage Collection when one already ran
     this picture: −4–6%.
   - `putImageData` 2→1 heartbeat per pixel.
   - `fillRect` 4 pixels per heartbeat last (touches the screen memory
     port). Helps full-screen paints, **not** INVADERS’ 1×1 pixels.
2. **INVADERS — cut per-operation cost (the real 30 fps job).** After
   the 2026-08-20 compiler pass (18.6M → 10.6M), remaining profile is
   ~66% `S_V64_EXEC` and ~37% of those beats are **`S_FETCH_WAIT`**
   (waiting a cycle for the next instruction). Plan, still VM-wide:
   - Shorten FETCH wait where the next instruction is already in a
     register (must stay legal SRAM — address this clock, data next).
   - Make tiny `fillRect` / `CALL_METHOD` cheaper (same path every title
     uses). A 1×1 `fillRect` today pays a full native call.
   - Keep heap slot hints; do not skip generation checks.
3. **Prove 30 fps** with heartbeats ≤ 3.33 million on a play picture for
   each of the five titles, then on the board after your `.bit` (F9
   FPGA-SIM will still be slow — judge 30 fps from the heartbeat count
   and from HDMI, not from Verilator wall-clock).

**Already landed (do not re-do):** last-4 FIND cache; compiler `a1=1`
globals + env slot hints (the 18.6M → 10.6M INVADERS pass).

**Do not:** revert Port A, clone the heap, skip generation, Verilator
`--threads`, raise the 64-million FRAME cap to hide an unfinished
picture, or title-gate.

---

# Intern FIND and the per-state shopping list

**FIND** = looking up a string in the intern table (the chip’s dictionary
of names). Every `"SCORE "+n` does a FIND.

**2026-08-21:** titles are **correct** on FPGA-SIM; FPGA-SIM is **too
slow to play** (simulator). Fit cleanup is **done**
([FPGA_FIT.md](FPGA_FIT.md)). This file is the 30 fps **board** plan.

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

## Safe to edit FIND while a `.bin` is synthesizing?

**Yes**, on FPGA-SIM only (`make -C sim sim_server_synth`). A running
Vivado job ingested `jmr_js_vm.sv` at start; disk edits do not enter it.
Do **not** kill it. Do **not** `bit-fresh` a live crash. After that `.bin`
exists, the **next** `make -C tools/board_flow bit` (not `bit-fresh`,
unless the file list changed) picks up FIND.

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
| Caps `MAX_OBJ=960`, arrays 1536×32+12×128, `ENV_DEPTH=384` | Live fit ([FPGA_FIT.md](FPGA_FIT.md)); do not restore 8192/4096 |
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

**Step 1 — last-hit cache (all FIND): LANDED 2026-08-18.** FFs
`(jn_hit_h, jn_hit_len, jn_hit_id, jn_hit_valid)` plus last-4. Do not
re-implement. Misses still linear-scan.

**Step 2 — faster miss (future plan, still VM-wide):** first use of a new
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
