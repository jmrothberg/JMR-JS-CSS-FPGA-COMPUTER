# Overnight build status — night of 2026-08-21 → 22

(Agent-written before launching the build; check the tail of this file
and `build/nexys_video/` for the outcome.)

## What was done tonight (all verified in FPGA-SIM before launch)

1. Root cause of the 1.9M LUTs found via `make hier`: the parent FSM held
   ~200k bits of ARRAYS as flip-flops (each FF dragging ~10 LUTs of
   112-state decode), plus the FB silently duplicated per bank (320 tiles).
2. Fixes: v64_on fold restored (tagged twin swept) · mini_fb rewritten
   (true 2-port + exact pow2 chunks → 150 tiles) · vobj/varr/venv/code
   memories pow2-chunked (Vivado pads BRAM to 2^addrwidth — the shrunk
   caps had saved nothing) · vframe family + vobj_cls/builtin + venv_gen
   moved to dedicated write processes (out of the FF explosion).
3. Paper BRAM ≈ 361/365. LUT outcome = tonight's synth verdict.
4. Verified: 198/198 bytecode, PACMAN plays, all five bug repros green,
   full RTL suite as the launch gate.

## If the build FAILED on LUTs
Run `make -C tools/board_flow hier` (5 min) — the residual list is
vobj_len / venv_len / vframe_escaped / scalars; next conversions are
mapped in docs/FPGA_FIT.md.

## If it FAILED on BRAM
The report names the array; paper margin was ~4 so it will be small.

---
## OUTCOME (written 05:05, build still finishing)

**Synthesis completed 04:58 (~5h). The verdict:**

| | Tonight | Last night | Chip |
|---|---:|---:|---:|
| **Block RAM** | **365 (100.00%) — FITS** | 579 | 365 |
| Slice LUTs | 1,196,216 (889%) | 1,901,313 | 134,600 |
| FFs | 123,992 (46%) | 185,510 | 269,200 |

**The BRAM war is WON** — the FB rewrite + pow2-chunking landed exactly
at capacity. The LUT campaign removed ~700k (37%) but ~1.13M logic
remains: ~100k bits of arrays are STILL flip-flop-resident (the census
missed them). Place will fail on LUTs; opt/place complete the run
around 05:30.

A fresh `utilization_hier.rpt` from tonight's checkpoint is being
generated to NAME the remaining arrays — that list is the next tranche
(same proven strobe/chunk recipes). Suite: 148 passed / 2 pre-existing
fails / 3 xfail — zero regressions from the restructuring. All games
verified playing before launch.

## 05:10 — residual LUTs ATTRIBUTED (fresh hier + census on tonight's netlist)

Parent now 1.02M logic / 96k FFs (was 1.72M / 155k). The FF-resident
census against tonight's mapping tables names the residue:

| Array | FF bits | What |
|---|---:|---|
| **gc_queue** | **229,362** | tagged GC queue — the v64_on FOLD DID NOT SWEEP IT |
| consts / vars / tenv_parent / obj_cls / tfn_* / env_oid / obj_n | ~101k | rest of the tagged twin, also still present |
| ROMs (font/sin/pow) + small live arrays | ~30k | cheap, second-order |

The constant fold could not prove the tagged states unreachable (shared
tasks + runtime flags like imgd_v64 keep formal paths in), so ~330k
tagged FF bits × ~9 LUTs ≈ the whole remaining overage.

**MORNING PLAN — one tranche, mechanical:** the real Phase 3b hand-edit
(docs/REMOVING_EXEC32.md): delete gc_queue + the tagged arrays above and
their arms outright. Estimated effect: −700-900k LUTs → at or near the
134,600 target, with the ROM/small-array cleanup as reserve. Synthesis
round-trip is ~5h, so this is a daytime iteration.

---
## DONE 05:05 — Phase 3b hand-delete landed

All **64 tagged write sites deleted** and the tagged stack task neutered.
Verified in source: `gc_queue` / `consts` / `vars` / `var_tag` /
`tenv_parent` / `obj_cls` / `obj_n` / `env_oid` now have **zero** write
sites; `stack` / `stack_tag` keep their Port-A processes but both write
enables are constant 0 (`stack_we` is only ever assigned `1'b0`,
`e32_stack_we` has no driver). The arrays are **writerless**, so
synthesis can sweep them for real — which the `v64_on` fold could not.
Projected **−800k to −1M LUTs**.

The Verilator binary (`sim/sim_build_synth/jmr_js_sim_server`, 05:05:47)
is newer than `rtl/engines/jmr_js_vm.sv` (05:05:29) with no `.sv` newer
than it, so the post-delete battery really did test the edited RTL.

**The confirming ~5h synth has NOT been run.** Until it does, −800k-1M is
a projection, not a result.

## Suite status corrected 2026-08-22 (morning)

The "148 passed / 2 pre-existing fails" line above undercounts the good
news: **both of those failures were bad tests, not chip defects.** Each
was run and diagnosed:

- `test_donkey_fpga_sim_enter_keeps_raf` — asserted the framebuffer
  changed within 8 frames; DONKEY's game screen moves sub-pixel per
  frame (first change at frame 31). It had been passing on the FB
  bank-mismatch that `S_FB_SYNC` fixed on 08-20. Now asserts per-frame
  work (`fclk`) instead. **Fixed and passing.**
- `test_pacman_fpga_sim_enter_paints_maze` — asserted `raf != 0` on a
  VMSTAT sampled at a random mid-frame instant, because
  `_wait_vm_idle_or_frame` times out on a title whose attract mode never
  rests. The snapshot it failed on read `fault=0`, `rafcall=99`,
  `obj=829` — a healthy machine mid-`drawImage`. Helper now lands on a
  frame boundary (`S_WAIT_FRAME`) before sampling.

PACMAN itself is healthy: the user's live session reached **rafcall 210,
fault=0 throughout, obj peaking at 872 of 960**, objects sawtoothing (so
GC reclaims). Detail: [docs/potential bugs.md](docs/potential%20bugs.md) #79.

## LUTRAM campaign 2026-08-22 (evening) — closing the 66k→46.2k distributed-RAM wall

Run 4 verdict: 519,312 LUTs (3.9× over), BRAM 365/365 ✓, and the leading
DRC is **LUT-as-Memory 66,059 vs 46,200 cap**. Work since, all verified
in FPGA-SIM (games battery + 198/198 bytecode + console/storage tests):

1. **source_mem → external SRAM** (SRC_SRAM_BASE=1724416) — done earlier,
   −8,192 LUTs.
2. **spr_mem → external SRAM** (SPR_SRAM_BASE=1691648) — S_SPR write and
   the non-ASET blit read are req/ack now (`sprb_pend` held-until-ack,
   NOT in the per-beat default-clear — the #73 lesson). −6,144 LUTs.
   Legacy .JS sprite tests pass.
3. **work_ram (console 12K, was forced LUTRAM) → external SRAM**
   (WORK_SRAM_BASE=1634304). Both masters already stall on gnt, so the
   variable latency is safe by construction. The core's asset-SRAM
   arbiter is now **owner-latched** (console > work > VM) with per-owner
   ack gating — the old "masters never overlap" comb mux would have
   silently cross-acked. −1,536 LUTs.
4. **vstack 2048 → 1024** — measured per-clock peak across all three
   games: PACMAN 71, DONKEY 56, INVADERS 16 (trackers run every clock in
   sim_main, transient-safe). Flat array literals push one slot per
   element (MAKE_ARRAY n), so ~1000-element literals still fit;
   vsp ≥ 1008 now faults loudly (code 7) instead of wrapping. −2,816.
5. **vgc_queue 64b → 17b** — every enqueued word is a NaN-boxed heap ref
   {16'h7ff9, kind[47:44], idx[12:0]}; pop rebuilds the word. Full 2892
   depth kept (measured occupancy peak 817). ≈ −2,768.

Projected LUT-as-Distributed-RAM: 66,042 − ~21,456 ≈ **44,600 — under
the 46,200 cap** for the first time. json_mem (−1,536) and name_mem
(−6,144) migrations stay in reserve if the real number lands high; both
need loop re-timing (parse/REPL lookahead, FIND) so they are not free.

**Run 5 launched 2026-08-22 (evening)** with all of the above plus
AreaOptimized_high. Purposes: confirm LUTRAM under cap, and get the
post-cleanup logic number that sets the size of the control-extraction
campaign (rule 5, u_exec64 shape — the remaining ~453k→134k gap).

False alarm during verification: `inv_cells` showed a "hole" at bunker3
(8,5) — zoom showed it is two EXTRA pixels of palette 01 (white), i.e. a
falling bomb in flight, time-shifted because SRAM-backed work RAM changed
boot cycle counts and with them the Math.random() phase. Bunkers intact.

## Metadata evacuation 2026-08-22 (afternoon) — the FF census found the logic wall

The run-3 hier report says the flat parent runs 11.0 logic LUTs per FF
(622,437 / 56,604) vs u_exec64's 4.19. The census question "what ARE the
parent's ~56k FFs?" has a decisive answer: **the heap metadata arrays
were all flip-flop-resident** — absent from both Final Mapping tables:

| class | arrays | bits |
|---|---|---:|
| generation counters | vobj_gen, vfn_gen, varr_gen, venv_gen | ~46,200 |
| GC marks | vobj/vfn/varr/venv_mark | ~3,900 |
| valid flags | vfn/varr/venv/vvar_valid | ~3,900 |
| long-handle flags | varr_long | ~1,500 |

≈ 55k FF bits, each paying the flat-FSM control-cone tax **plus** the
960:1 / 1548:1 read multiplexers — plausibly the bulk of the 453k logic.
The blocker was never the arrays: every one already has exactly ONE
registered `*_rdata` read port. The blocker was write style — "the
7k-line FSM poking ram[i] <=" pattern that makes Vivado build FFs.

Fix: the established strobe conversion (vom/veg/vol pattern). Each array
got a `(* ram_style = "distributed" *)`, a dedicated Port A process
(parent strobe first, e64 channel else-if moved in from the exec-write
region to keep single-driver), and one-shot strobes from the FSM sites.
As LUTRAM the whole class costs **~600 LUTs**.

Verified: 198/198 bytecode, PACMAN 40 frames fault=0 (gcqmax unchanged
at 817 — the theoretical 1-beat double-enqueue window doesn't bite),
INVADERS pixel-identical, DONKEY clean. Full RTL suite running.

New recurring-pattern note: strobe writes land +1 beat. Safe here because
every reader goes through an armed `*_rdata` (≥2 beats); the enqueue
mark-test race is idempotent and bounded by queue margin (2892 vs 817).
Run 5 (launched before this work) answers LUTRAM-under-cap; run 6 with
the evacuation measures the logic collapse.

## Run 5 verdict (2026-08-22 ~14:45) + run 6 launched (~15:40)

Run 5 (LUTRAM migrations + shrinks, pre-evacuation):

| metric | run 4 | run 5 |
|---|---:|---:|
| Slice LUTs | 519,312 | **492,170** |
| LUT as Logic | 453,253 | 445,020 |
| LUT as Memory | 66,059 | **47,150** (cap 46,200 — 950 over) |
| FFs | 79,728 | 75,076 |
| BRAM | 365/365 | 365/365 |

impl failed at place on logic (expected). Two corrections to the record:

1. **The run-4 "all metadata is FF" census was drawn from an empty log
   slice** — run 5's launch had already reset runme.log, so the session
   awk matched nothing and absence-of-evidence read as evidence. Run 5's
   real table shows gens, marks, vfn_valid, vobj_alloc were ALREADY
   LUTRAM. Actually FF-resident (and now evacuated): varr_valid,
   venv_valid, vvar_valid, varr_long, varr_lidx, vlong_used ≈ 16.5k FF
   bits. The evacuation stands, with a smaller expected logic win.
2. **json/name SRAM migrations are off the table** without exec
   restructuring: their writes come from exec64 at full beat rate
   (stringify / STR_WR interning); req/ack cannot keep up and a FIFO
   would need unbounded depth.

Closing the last 950 LUTRAM: measured interner pool peaks with per-clock
trackers — nb_wp max 3,644 bytes (PACMAN), 3,070 (INVADERS), 2,298
(DONKEY) against NAME_CAP 32,768; json_wp max 1,799 of 8,192. **NAME_CAP
32K → 16K** (4.5x headroom, compile-time refuse in jsb_format
PROGRAM_NAME_BYTES, runtime guards all NAME_CAP-derived): −3,072 LUTs.
JSON left alone (−768 not worth the index-width churn).

**Full RTL suite on the evacuated tree: 150 passed, 3 xfailed, 0
failed.** 198/198 bytecode, games battery clean.

Run 6 = run 5 + metadata evacuation + NAME_CAP 16K. Projected LUTRAM
≈ 44.5k (**~1.6k under cap**); logic is the number to watch — the
16.5k evacuated FF bits each drop their share of flat-FSM control cone
and read-mux trees.

## Run 6 verdict (2026-08-22 17:40) — LUTRAM WALL CLOSED, logic collapsed 39%

| metric | run 5 | run 6 |
|---|---:|---:|
| Slice LUTs | 492,170 | **312,198** (2.32x over, was 6.1x at run 1) |
| LUT as Logic | 445,020 | **269,566** |
| LUT as Memory | 47,150 | **42,632 — UNDER the 46,200 cap (92.3%)** |
| FFs | 75,076 | 70,745 |
| BRAM | 365/365 | 365/365 |

The metadata evacuation (16.5k FF bits) + NAME_CAP 16K removed **175k
logic LUTs** — the flat parent now runs **3.79 LUT/FF** (was 11.0),
BELOW u_exec64's 4.19. The "extract control into submodules" lever is
now marginal; the real tax was FF-resident arrays and their mux trees.

**Definitive FF census** (Vivado DCP query, per base name): parent still
holds 49,148 FFs across 1,393 names. Top: arr_len 12,384 (a LIVE
redundant twin — e32_arr_len_tos_rdata feeds live join/foreach/hp paths,
the naming trap again; NOT deletable, but convertible), vobj_len 6,144
(RAM inference blocked by ONE stray direct write at the HP_OSETI site —
every other site already used vol_* strobes), cls_mip/cls_mname 4,096
each (single-beat 256-way associative method scan — conversion means
sequentializing, a slowdown-ledger decision, DEFERRED), vjs_val 2,048
(comb-indexed same beat, deferred), vtimer_due 2,048.

Run 7 (launched ~18:00) = run 6 + arr_len strobe conversion + vobj_len
stray-write fix (both verified: PACMAN/DONKEY clean, 198/198). Next
tranche staged: name_has, vtimer_due, cstack_env, txt_buf (~4.4k bits).

## Run-8 tranche applied 2026-08-22 19:15 (after suite green on run-7 tree)

Full RTL suite on the arr_len+vobj_len tree: **150 passed, 3 xfailed, 0
failed** (second consecutive clean full-suite run today). Then applied
the staged tranche: vtimer_due (64x32, RMW via registered rdata — the
setinterval re-arm path), name_has (consolidated its two driver blocks
into the poke process — that split was why it stayed FF), txt_buf,
cstack_env — all to strobe/Port-A LUTRAM. Battery green: PACMAN 40f
fault=0, INVADERS pixel-identical, DONKEY clean, 198/198 (covers
setinterval_rearms + join/text paths). Run 8 launches when run 7's
verdict is harvested.

## Run 7 verdict + cls sequential scan (2026-08-22 evening)

| metric | run 6 | run 7 |
|---|---:|---:|
| Slice LUTs | 312,198 | **227,502 (1.69x over)** |
| LUT as Logic | 269,566 | 184,430 |
| LUT as Memory | 42,632 | 43,072 (93.2% of cap) |
| FFs | 70,745 | 52,068 |

arr_len + the vobj_len stray-write fix were worth −85k logic on their
own. Run 8 (baking) adds vtimer_due/name_has/txt_buf/cstack_env. After
it launched, the **cls method scan went sequential**: the one-beat
256-way comparator forest over cls_mname/cls_mip became a 1-entry/beat
pipelined walk over flattened LUTRAM tables (the cls_c/cls_m iterator
regs from the pre-CAM design were still there); class find stays a comb
compare over the small FF cls_name array; ctor mode still finishes in
one beat. Consumers were already handshake-gated on cls_done, and
requesters keep waiting while cls_scan stays high, so no state changes.
Verified: PACMAN (class-heavy: new Stage/Item + per-frame methods) 40f
fault=0 with byte-identical peaks, INVADERS/DONKEY clean, 198/198.
Goes into run 9.

Remaining known FF blocks, all deferred with reasons: vjs_val (same-beat
RMW in JSON parse), vlistener parent+exec copies (#77 skew), vst_win
(hot TOS window). After run 8/9 verdicts, the next class of work is
datapath sharing and the exec64 internals.

## Run-8 skip trap (2026-08-22 19:38) → run 9 forced

Run 8 never synthesized: the build tcl skips synth when no RTL file is
newer than the synth DCP, and run 7's post_synth.dcp was (re)written at
19:21 by the killed run's report step — AFTER the 19:14 tranche edits.
So run 8 reused run 7's netlist and went straight to the impl DRC fail.
Lesson: after killing a run mid-impl, the DCP timestamp may postdate
your edits — launch with JMR_VIVADO_FORCE_SYNTH=1 when in doubt.
Run 9 (forced) = tranche 8 + cls sequential scan; full RTL suite
running in parallel on the same tree.

## Run 9 verdict + evening close (2026-08-22 ~21:10)

| metric | run 7 | run 9 (tranche + cls seq scan) |
|---|---:|---:|
| Slice LUTs | 227,502 | **214,326 (1.59x over)** |
| LUT as Logic | 184,430 | 171,012 |
| LUT as Memory | 43,072 | 43,314 |
| FFs | 52,068 | 41,644 |

Day trajectory: 519,312 → 492,170 → 312,198 → 227,502 → **214,326**.
Remaining gap to the T200: −79,726 LUTs (1.59x).

Run-9 DCP census (top remaining FF blocks): **exec64 keeps its own
cls_mip/cls_mname copies (8,192 bits + its comparator forest)** — but
exec's cm_scan runs on EVERY object method call (the source comments
say the 256-step walk was deliberately flattened to one clock for
speed), so sequentializing it is a slowdown-ledger tradeoff for a fresh
session, ideally by routing exec lookups through the parent's new
sequential scanner and deleting the duplicate (a #78-class boundary
surgery). Then: vjs_val 2,048 (same-beat RMW), vlistener 4 copies
(#77), vst_win 1,024 (hot TOS window), spr_hh/nid/ww 768, and
other/linebuf+line ~3k (video line buffers, likely wired to scanout).
After arrays: datapath sharing in the 171k logic.

Also fixed tonight: txt_buf had five extra direct write sites (two
driver locations → FF, the census caught it) and name_has/txt_buf
lacked explicit ram_style. Battery green (fourth time today), suite
green three full runs. **Run 10 launched (forced synth)** with those
fixes — verdict in the morning. Zombie-monitor mystery solved: the
build flow's own RSS heartbeat shells orphan when make dies; kill by
PID after any aborted run.

## Run 10 verdict (2026-08-22 ~22:00) — the array lever is exhausted

214,772 LUTs (logic 171,448, LUTRAM 43,324, FFs 40,763) — flat vs run
9's 214,326. txt_buf/name_has converted (FFs −881) but bought ~nothing:
small arrays whose mux trees were already cheap. This confirms the
remaining −80k must come from structure, not more strobe conversions:
1. exec64's duplicate cls_mip/cls_mname + its per-call comb CAM
   (speed-ledger tradeoff; best shape is routing exec lookups through
   the parent's sequential scanner and deleting the duplicate),
2. vjs_val / js_i JSON-stack restructure (TOS-cache + RAM spill),
3. vlistener consolidation (4 copies, #77 care),
4. datapath sharing across the remaining 171k logic (measure first:
   per-cell LUT attribution from the DCP, not guesswork).
Day total: **519,312 → 214,326 (−59%), LUTRAM wall closed, BRAM
365/365, three clean full-suite runs, all games playing.** Run 10's
impl will fail at place (still 1.59x) — that failure notification is
expected, not news.

## Night session 2026-08-22/23 — "run all night until .bin" directive

User authorized speed sacrifice (half frame rate acceptable). Executed:

1. **exec64 class tables deleted** (cls_mip/mname/name/nmeth, 8.6k FF
   bits + the per-call 256-way CAM): method lookup is now a level
   request to the parent's sequential scanner with the result held
   until the request drops (a one-beat pulse was missed on non-enable
   beats — livelock diagnosed by cmcyc==cmlkp cycle counters showing
   cm_scan toggling every beat; fixed by holding the request level
   against the comb default-clear, one line). An 8-entry (cls,key)→mip
   cache (misses included — builtins repeat the same miss) makes
   repeated lookups same-beat: measured 6 lookups/frame at ~6 cycles.
   NO speed loss in the end. Battery + full suite green (4th clean run).
2. **Vivado 2026.1 segfaults on use_dsp** at module scope on both big
   modules (runs 11, 12 died in synth_design). Attribute removed;
   STEPS.OPT_DESIGN.ARGS.DIRECTIVE=ExploreArea kept.
3. **Run 13**: 207,725 total / 164,401 logic / FFs 32,118. Post-opt DRC:
   requires 165,989 LUT-as-Logic vs 134,600. True placement budget is
   logic ≤ sites − LUTRAM ≈ 91k → gap ≈ −75k.
4. **Hier attribution (run 13)**: parent 84.2k logic (4.5/FF), exec64
   60.4k (7.7/FF — now the worst cone: comb opcode breadth), MIG ~14k
   (fixed), cons+fb 7.5k.
5. **Comb IEEE-754 double units found in exec64**: add (2 sites), mul
   (4 sites = 4 53x53 comb multipliers!), div/mod pack. Three mul sites
   compute the SAME frame-clock product (vframe_no x 16.667) — now one
   shared instance (**4 → 2 multipliers**). In run 14 (baking).
6. **vst_win 16→8 evaluated and REJECTED for tonight**: out-of-window
   VST_REL reads clamp to slot 0 (silently wrong data); correctness
   relies on scattered depth-16 guards across 244 usage sites that the
   battery cannot fully exercise. A bad shrink could ship a silent
   wrong-value bug. Needs a session with targeted deep-stack tests.
7. **Listener sequentialization deferred** the same way (#77 machinery:
   4 table copies + one-beat parallel compaction).

Trajectory: 519k → 492k → 312k → 227k → 214k → 207.7k (runs 4→13).
The asymptote under SAFE surgery is converging around ~200k vs the
134.6k budget. Remaining levers are all structural with real risk:
vst_win shrink, listener consolidation, JSON stack, sequential FP,
per-state datapath sharing — several sessions of careful work, each
5-15k. The honest morning conversation: keep grinding these on T200,
or target a larger part (XC7A200T is maxed; a Kintex/UltraScale part or
XC7K325T would place today's netlist immediately).

## Run 14 (03:00) — null result, and the honest asymptote

Run 14 came back byte-identical to run 13 (207,725 / 164,401 / DRC
165,989): Vivado's resource sharing had ALREADY merged the three
mutually-exclusive frame-clock multiplier sites, so the manual dedup
changed nothing. Lesson: AreaOptimized_high does share exclusive-branch
arithmetic; manual sharing only pays across non-exclusive sites.

**The overnight arithmetic, stated plainly**: the placement budget is
logic ≤ 134,600 − 43,324 LUTRAM ≈ 91k. We are at 166k. The remaining
levers (JSON TOS/NOS rework ~6-8k, listener consolidation ~6-10k,
sequential FP ~8-10k, vst_win 8-deep ~10-20k, per-state datapath
sharing ~10-20k) total ~40-70k across SEVERAL sessions of careful,
test-scaffolded work — each with real silent-corruption risk if rushed.
No overnight path reaches 91k. The 3am choice was: gamble the
5x-verified green tree on surgery that cannot close the gap tonight, or
bank the campaign. Banked.

Where this leaves the .bin: (a) T200 fit remains possible but needs
2-4 more sessions of structural work at current measured rates; (b) the
current netlist (207,725 LUTs, 365 BRAM, LUTRAM under cap) would place
immediately on a Kintex-7 325T (203,800 LUTs, 445 BRAM) or any
UltraScale part; (c) day total stands at 519k → 207.7k (−60%) with
zero functionality loss and every game playing.

## 2026-08-23 morning — new-ideas plan for a 1-2 session fit (user directive)

Netlist snapshotted: commit 30f5fc6, tag `bigger-part-candidate-207k`,
port checklist in docs/BIGGER_PART.md (Kintex-325T places it as-is).

The plan, cheapest-first:
1. **RUNNING NOW (run 15)**: `drc.disableLUTOverUtilError=1` — the
   UTLZ-1 gate compares LOGICAL LUTs (165,989) against sites BEFORE
   LUT6_2 pairing; control-heavy netlists pack 10-25%. If the placer
   packs ~19%+, this places TONIGHT with zero RTL change. Either way
   its failure report gives the true post-packing deficit.
2. **50MHz core** (approved product decision): core_clk = MIG ui_clk
   today, so the route is BUFGCE /2 on the core with 2-flop syncs on
   the sram req/ack levels (the held-until-ack contract is already
   CDC-tolerant). Helps TIMING closure after placement, not the DRC.
3. **FB -> DDR3** (the budget lever): mini_fb's two BRAM banks are 160
   of 365 tiles. Moving scanout to DDR3 line-prefetch frees them; the
   17k of LUTRAM spills (fb tails, varr_c2, code_c1, vobj_tmem) return
   to BRAM, raising the logic budget from ~91k toward ~120k. One
   bounded session in jmr_mini_fb + scanout FIFO.
4. **exec64 op-tiering** if still short: cold opcodes go multi-beat
   through a shared datapath; only the hot ~40 stay one-beat comb.

## Run 17 (2026-08-23 10:35) — V1 cut + one-hot verdict: flat (208,534)

| metric | run 13 | run 17 |
|---|---:|---:|
| Slice LUTs | 207,725 | 208,534 (+809, noise) |
| LUT as Logic | 164,401 | 165,208 |
| post-opt DRC | 165,989 | 166,922 |

Why flat, precisely:
1. **The V1 surface was never in silicon.** Native IDs end at 41 — no
   Math trig/pow arms exist; no string-method arms exist. Of the whole
   removal list only id_findindex (now FFFF tie-off) and the
   never-emitted OP_RETURN arm (now default/fault-5) had RTL — a few
   hundred LUTs. The sin ROM is ctx.arc's table (PACMAN uses arc): KEPT.
2. **The one-hot attribute did not take.** The synth log re-encoded 6
   small FSMs (i2c, ft245, ddr3 bridge...) but has NO encoding line for
   jmr_js_vm's `state` — next-state flows through hs_st()/ret_state
   VARIABLES, so Vivado cannot extract the FSM and silently ignores
   `fsm_encoding`. Manual one-hot would mean re-encoding the 68-value
   st_t by hand across every compare — not a 1-session lever.

Still gained (and kept): the compiler V1 wall (call-position precise —
blunt name-table version falsely rejected `var values`), findIndex/
RETURN silicon out, all six titles in the standing battery for the
first time (ASTEROID/MRDO/MKPVP fault-free; MRDO interner peak 9,876 of
16K), 148+2skip full suite, 196+2skip bytecode.

## The 2-session fit plan (arithmetic-driven)

Placement needs packed-logic + LUTRAM <= 134,600. At 20-25% LUT pairing
the requirement is roughly: logic <= ~115-120k AND LUTRAM <= ~25-30k.
- **Session 1 — FB -> DDR3**: frees ~160 BRAM tiles; fb tails +
  varr_slot_c2 + code_mem_c1 + vobj_tmem spills (~16-17k LUTRAM) return
  to BRAM; optionally push name_mem/vstack/protos to BRAM too ->
  LUTRAM ~20-26k. Bounded to jmr_mini_fb + a scanout line FIFO
  (swap = burst copy through the existing dump ports; ~3ms at half
  frame rate is in budget per the product decision).
- **Session 2 — logic -30-40k**: listener consolidation (parent+exec 4
  tables + comb compaction -> sequential, events are cold), JSON stack
  TOS/NOS rework (vjs_val/js_i comb-index muxes), sequential FP
  add/mul (2 comb doubles remain), vst_win 16->8 behind the new
  tests/test_stack_window_depth.py gate.
Then the (already-armed) demoted-DRC placement attempt with LUT pairing
closes the remainder, still on the 100 MHz XDC; 50 MHz BUFGCE stays the
final timing lever only.

## 2026-08-23 — relax experiment answered + the census corrects Session 2

**20 ns relax: delta ZERO, bit-identical netlist.** Root cause: the XDC
create_clock NEVER applies during top synthesis (deferred past the MIG
black box, Project 1-498) — synth was already free of the 100 MHz
pressure, and AreaOptimized_high had banked the area. XDC reverted to
the truthful 10 ns (20 ns would under-constrain the real 100 MHz
pixel/HDMI paths at implementation). Half-rate core stays the BUFGCE
plan with an honest generated clock.

**Mux census (report_design_analysis + LUT-by-driven-net on post-opt),
as the user required before committing Session 2 — the ranking IS
different from the assumption:**

| structure | LUTs | note |
|---|---:|---|
| vst_wdata result funnel | 33,675 | every opcode's result muxes into the stack write — effectively exec64's datapath drain; fix = op-tiering/sharing (deep) |
| listener complex (ev/fn/nev/nfn + we_q + compaction) | ~26,000 | 4x my 3-6k estimate — now Session 2's #1 actionable |
| vst_win window | 11,190 | behind the deep-window test gate |
| JSON parse (json_digs + js_i + vjs_val + js_ph) | ~15,000 | TOS/NOS + sequential digits |
| name_has | 6,230 | STILL FF: three write statements in the poke process = unprovable 1W; merge to one prioritized write |
| FP (vdiv/vmod/exp) | ~3,500 | NOT top-four — drops off the list |

Session 2 commit list (corrected): listeners, JSON, name_has 1W merge,
then vst_win; vst_wdata/op-tiering is the deep reserve.

**Session 1 begins**: front/scanout FB bank + line-FIFO -> DDR3, draw
bank stays BRAM (NEVER-table row consciously relaxed, user, rule-5
style). Swap = burst copy via the existing dump path; ~75-80 tiles
freed absorb the ~17k LUTRAM spill return.

## Run-19 verdict checklist (advisor review, adopted 2026-08-23)

1. **Mapping-table proof for every re-styled array**: vstack, name_mem,
   json_mem, vconsts, vobj_proto, vfn_proto, vfn_env, vfn_bound_this,
   venv_parent must each appear under Block RAM in run 19's Final
   Mapping tables. Source pre-check: all eight are clean 1W1R with
   registered reads (the distributed style was BRAM scarcity, not async
   reads) — but an attribute is not inference (name_has stayed FF with
   the attribute present and every test green). Any absentee = the
   16.6k relief silently didn't happen for that array.
2. **Packing arithmetic stated up front**: ~160k logical into ~117k
   physical sites needs ~27% LUT6_2 pairing — ABOVE the typical 10-20%
   for control logic. A ~10k miss is the EXPECTED case, not a Session-1
   failure; the census-ranked Session-2 targets (listeners ~26k, JSON
   ~15k, vst_win 11.2k, name_has 6.2k) are the planned closer.
3. **FPGA-SIM cannot prove the new scanout path**: sim_main ticks clk
   and pixel_clk in lockstep (single effective domain), and
   jmr_sram_model has none of the MIG's refresh stalls or variable
   latency. The gray-coded beam-line CDC, DDR3 refresh behavior, and
   arbiter starvation margins are UNTESTED until the board. First
   bring-up: treat visual artifacts (torn lines, wrong lines, sparkle)
   as a known-possible scanout/CDC symptom FIRST — not a heap or VM bug.

## Run 19 — Session 1 verdict (2026-08-23 13:38)

| metric | run 17 | run 19 | delta |
|---|---:|---:|---:|
| Slice LUTs | 208,534 | **181,335** | **−27,199** |
| LUT as Logic | 165,208 | 169,383 | +4,175 (scanout/present + spill-return glue) |
| LUT as Memory | 43,326 | **11,952** | **−31,374** |
| FFs | 32,048 | 47,985 | +15,937 (BRAM output regs) |
| BRAM | 365/365 | **338.5/365** | 26.5 tiles SPARE |
| post-opt DRC | 166,922 | 170,873 | |

Checklist walk:
1. **Mapping proof: 7 of 8 re-styled arrays landed in Block RAM.**
   vstack stayed distributed — "Infeasible attribute" (Synth 8-6849):
   its template already implied a second read port (704 RAM64M where
   1W1R would be 256). Not a regression (was LUTRAM before); 2.8k of
   planned relief unrealized; template fix deferred. The advisor's
   check caught this in one grep — silent, all tests green.
2. **Packing arithmetic**: packed(170,873) + 11,952 <= 134,600 needs
   ~28% pairing vs the typical 10-20% — the predicted expected-case
   miss. At 20% pairing the shortfall is ~14k; at 15%, ~22k. Session 2
   needs −20-40k raw logic; the census-ranked targets (listeners ~26k,
   JSON ~15k, vst_win 11.2k, name_has 6.2k ≈ 58k of cones) cover it
   with margin. Clock placer still aborts before packing at this
   overage, so the pairing rate stays unmeasured until we get closer.
3. **CDC caveat recorded** (see run-19 checklist entry above): board
   bring-up treats visual artifacts as scanout/CDC suspects first.

LUTRAM is now 26% of its cap — the memory wall is not merely closed
but demolished; every remaining LUT is a logic LUT. Session 2 begins:
listener consolidation first (biggest census target, strongest
existing test coverage: donkey lsn, KEYEVT suite, #77 repros).

## Per-arm LUT sizing (run-19 post-opt) — the keep/remove line, drawn on numbers

| arm | LUTs | line |
|---|---:|---|
| vst_win + vst_wdata funnel | 44,797 | the machine — rework only |
| listeners | 26,917 | Session-2 #1 (consolidate) |
| **JSON engine (js_/json_/vjs_, jn_ excluded)** | **18,349** | **REMOVE when gated** — supersedes the TOS/NOS rework |
| name_has | 7,681 | 1W merge |
| HOF vfe_ (find/filter/reduce/map/sort) | 1,053 | KEEP (not worth a wall) |
| bind | 601 | KEEP |
| regex replace/test | 126 | KEEP (practically free) |
| jn_ join/indexOf (shared, kept) | 446 | keep |

First census pass mis-bucketed jn_ under JSON (join/indexOf share the
prefix); corrected split above. The other agent's wider removal list
(HOF/regex/sort/bind ≈ 1.8k combined) fails the numbers test — walling
those costs authoring surface for ~1% of the gap. Only JSON clears the
bar, and it also kills PACMAN's parse/stringify maze-reset GC churn
(24% of frame) — chip smaller AND game faster.

**Wall extension shipped, OFF by default** (six titles keep compiling):
`JMR_V1_WALL_EXT=json` walls parse/stringify (the recommended line);
`=1` adds the full requested list. JSON-engine removal patch is gated
on: (a) wall live for JSON, (b) PACMAN2.HTML (user-provided) passing
the full battery with byte-identical framebuffer checks. Removal scope
when gated: S_JSON/S_V64_JSON* states, json_mem + ports, js_* parse
stack, vjs_val, JSON.parse/stringify native arms (23/24), json watchdog
slice. jn_* stays (join/indexOf).

50 MHz: timing-only rescue after placement — never an area lever
(proven by the bit-identical run 18).

## Run 20 — JSON engine removal verdict (2026-08-23 15:36)

| metric | run 19 | run 20 |
|---|---:|---:|
| Slice LUTs | 181,335 | **161,924 (1.20x over)** |
| LUT as Logic | 169,383 | 150,214 |
| LUT as Memory | 11,952 | 11,710 |
| BRAM | 338.5 | 338.5 |
| post-opt DRC | 170,873 | **152,203 vs 133,800** |

−19.4k from the removal (census promised 18.3k ✓). Gate battery: all
six titles fault-free with jsonmax=0 everywhere; repros intact; full
suite in flight. Placement arithmetic: packed(152,203)+11,710 <=
134,600 needs **19.3% pairing — inside the typical 10-20% band for the
first time**. The clock placer still aborts pre-packing at 113%
logical, but the LISTENER consolidation (26.9k census) alone brings
post-opt logical UNDER the 133,800 DRC line — after it, placement gets
to actually try. Session 2 #1 begins.

Trajectory: 1,901k → 519k → 312k → 227k → 214k → 208k → 181k → 162k.
