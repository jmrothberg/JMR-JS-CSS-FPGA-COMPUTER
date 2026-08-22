# T200 fit — agent repair brief

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**T200** = this Nexys Video board (Artix-7 **XC7A200T**, 365 **BRAM** Block
RAM tiles, 134,600 **LUTs** Look-Up Tables). **Fit** = does the design
place without over-util. Agent does **not** run **Vivado** (AMD’s FPGA
compiler) — you do:

`source scripts/vivado_env.sh && make -C tools/board_flow bit-fresh`

(once, 2026-08-21: source file list changed). After that, ordinary `bit`
unless the file *list* / MIG / XDC changes. Same `rtl/*.sv` as FPGA-SIM.

This file is **copy 2** of the RAM / “never fake FPGA-SIM” law (copy 1 is
`.cursor/rules/never-fake-fpga-sim.mdc`) and **copy 2** of synth hygiene
(with [SESSION_HANDOFF.md](SESSION_HANDOFF.md) § Synthesis).

One JS heap. Do not extract JOIN / JSON / GC (Garbage Collection) / HEAP
into new modules. Extra clocks OK. **Future plan** if the JS core misses
100 MHz: [If timing fails](#if-timing-fails-wns--0--slow-the-js-core-not-ddr3)
(50 MHz core, DDR3 stays 100 MHz) — not wired yet.

**Board core clock (fact, not a goal):** `core_clk` **is** **MIG**
(Memory Interface Generator) `ui_clk` ≈ **100 MHz** today
(`tools/board_flow/mig_a.prj`: DDR `TimePeriod` 2500 ps → 400 MHz memory,
PHY **4:1** → `ui_clk` 100 MHz; `rtl/top_nexys_video.sv`
`assign core_clk = ui_clk`). Older notes that said “~30 MHz” were a wish
from the BASIC board era — **not** what this tree wires. Vivado does
**not** pick a slower clock if the VM misses 10 ns — see **If timing
fails** below. Do not slow MIG to “fix” **WNS** (Worst Negative Slack).

---

## If timing fails (WNS < 0) — slow the JS core, not DDR3

Publish a `.bit` only if WNS ≥ 0 ([FPGA_BRINGUP.md](FPGA_BRINGUP.md)).
A prior VM map of code RAM to LUTRAM hit ~**−90 ns** WNS (dead tether) —
that is a bad bit, not a board mystery. Negative WNS on the **VM / fabric**
path is the hedge below. Negative WNS **inside MIG** is a different bug
(do not “fix” it by clocking the core slower).

**Do not:**

- Lie in the XDC (`create_clock -period 20` on `clk100` while the pin is
  still 100 MHz).
- Ask MIG for a 50 MHz `ui_clk`. DDR3-800 + PHY 4:1 **locks** `ui_clk` at
  100 MHz; the DRAM min clock is ~300 MHz-class. Slowing `ui_clk` breaks
  calibration.
- Hope Vivado inserts a clock crossing. `assign core_clk = ui_clk` is one
  domain on purpose.

**Do (50 MHz core, 100 MHz memory) — not wired yet; this is the recipe:**

1. **Keep** MIG + `jmr_ddr3_sram_bridge` on `ui_clk` (100 MHz). `app_*`
   must stay synchronous to `ui_clk`.
2. **Make `core_clk` = `ui_clk` / 2** (BUFGCE or FF+BUFG from `ui_clk`,
   then `create_generated_clock`). Related clocks beat a second MMCM.
   Unused board MMCM `CLKOUT1` can also emit 50 MHz, but that MMCM is
   **not** MIG’s — treat that pair as async.
3. **CDC the asset port** between core and bridge. `jmr_sram_port` is
   already hold-`req`-until-`ack`; add a two-clock slice (sync req/addr/data
   into `ui_clk`, ack/rdata back). FPGA-SIM may keep `jmr_sram_model` on
   one clock (`SRAM_INTERNAL=1`).
4. **Sync reset** into the 50 MHz domain (`ui_clk_sync_rst` /
   `init_calib_complete` are 100 MHz). HDMI `pixel_clk` (25 MHz) already
   crosses; leave it.
5. **Retune anything that assumes 100 MHz on `core_clk`:**
   `ps2_rx` `DB_MAX` (Digilent ~19 @ 50 MHz; today 39 @ 100 MHz),
   `jmr_uart_link` / `jmr_i2c_*` `CLK_HZ`, `jmr_js_core` frame tick
   (`100e6/60` → `50e6/60`). SD `INIT_DIV`/`RUN_DIV` scale with this
   module’s `clk` — 50 MHz is still in spec, just slower SPI.

XDC: keep MIG’s 10 ns on `ui_clk`; generated 20 ns on `core_clk`;
false-path / proper sync constraints on the new slice. Rebuild
(`bit-fresh` if the clock net / MIG extra clocks change). Flash only
if **both** clocks report WNS ≥ 0.

This buys a 20 ns budget for the fat JS FSM. It does **not** relax 10 ns
inside MIG+bridge, and it does not make JOIN intern walks cheaper in
wall-clock (half the core Hz). Extra VM states for legal SRAM stay;
do not combo-peek BRAM to “win back” the MHz.

Diaries: [OLD_RUNS.md](OLD_RUNS.md). Glass: [SESSION_HANDOFF.md](SESSION_HANDOFF.md).
Phase 3b **source** sweep (optional cleanup of tagged array declarations):
[REMOVING_EXEC32.md](REMOVING_EXEC32.md). Synthesis already treats the twin
as unreachable via the `v64_on` constant fold (below). External port map:
[ARCHITECTURE.md](ARCHITECTURE.md) § External SRAM.

---

## Plain English — how we fit without watering down the JS Native CPU

**(User plan, 2026-08-21 — reviewed and EXECUTED the same day; see "What
landed" below. Verdict on the review: steps 1/3/4/5/6 were right and are
done — with one twist: step 1's biggest lever turned out to be a 10-line
constant fold, not a 5k-line delete — and the plan was missing the real
first-order cause, an incremental-synthesis stitch that duplicated the
core. The ≤340 paper check closed at ~356/365.)**

**What’s wrong:** the FPGA is trying to hold too much “fast memory” on
itself, so place fails. A lot of that is (a) an old tagged/exec32 twin
no title uses anymore, (b) big buffers that are not in the hot
fetch→JS→paint path, or (c) empty headroom reserved beyond what the
five V1 games actually need.

**How we fix it (still a real JS Native CPU):**

1. **Delete the dead twin** — the old decoder file is gone. The parent
   still *declared* tagged stacks/heaps. The **`v64_on` fold** (below)
   makes `jsb_flags[3]` constant 1 so Vivado proves those arrays
   unreachable and sweeps them — that is the **synthesis** half of
   Phase 3b. A later source-level delete is optional hygiene so the
   `e32_*` naming trap goes away ([REMOVING_EXEC32.md](REMOVING_EXEC32.md)).
   Removing the ghost does not change the language, the heap model, or
   the games.

2. **Keep the real JS CPU fast on-chip** — dual framebuffers, bytecode,
   eval stack, and the live object/array/env tables touched every
   opcode stay in BRAM. We do **not** put the JS heap on DDR3 (that
   would still be “JS” on paper and a slideshow in play).

3. **Move only cold / bursty buffers outside** — ImageData pixels,
   LIST/editor source, blit scratch, JSON scratch — already multi-cycle.
   Same external port as ASET art; they wait on `ack` like the blitter.
   Play loop stays on-chip.

4. **Right-size empty shelves; don’t remove shelves the games use** —
   measure peaks on INVADERS / PACMAN / DONKEY / ASTEROID / MRDO; set
   depths to peak×1.25 with **loud overflow**. Same JS semantics and
   APIs; stop paying BRAM rent for unused empty rooms. Bigger titles
   later = raise caps or grow the external bank (V2/ASIC), not “delete
   Array.”

5. **BRAM whitelist only** — everything else stays small LUTRAM or
   external. That stops Vivado stuffing everything into BRAM, running
   out, demoting to LUTRAM, and exploding to ~2M LUTs.

6. **One paper check before overnight synth** — whitelist tiles must
   sum **≤ 340**. If not, do not run Vivado. Fix the spreadsheet first
   so the next `make bit` has a real shot. The user cannot afford a
   second pass.

**What you still have:** HTML → compile-on-RUN → bytecode ISA on the
chip → Canvas / heap / events in hardware. No dukpy, no soft CPU, no
fake browser. Fit work removes a dead second machine, parks cold
buffers where art already lives, and stops carving BRAM for empty
rooms — it does not delete JS features.

---

## Status — place failed 2026-08-21 04:11; root causes found, fixes LANDED

`synth_1` completed; `place_design` failed UTLZ-1 (LUT 1.92M/134.6k, BRAM
659/365). Forensics on `synth_1/runme.log` (the log accumulates sessions —
the current run starts at its LAST "Start of session") found **three
separate causes**, in order of surprise:

### 1. The netlist was an incremental-stitch DUPLICATE (flow bug — fixed)

`AUTO_INCREMENTAL_CHECKPOINT 1` + project reuse made this synth an
incremental run against the **pre-exec32-delete reference checkpoint**.
The stitched netlist contains the framebuffer pair TWICE
(`u_core/u_fb` AND `u_corei_10/u_fb`): 658 RAMB36 = 338 (VM) + 160 (FB)
+ **160 (stale duplicate FB)** — and an unknowable share of the 1.92M
LUTs is duplicated logic. The 1.92M is therefore **not a measurement of
the design**. Fixed: the Tcl now pins `AUTO_INCREMENTAL_CHECKPOINT 0`,
and the next build MUST be `make -C tools/board_flow bit-fresh` — the
file list changed (exec32 deleted), which was always the documented
bit-fresh trigger. The old "do not bit-fresh" rule was about resuming
after a mid-run crash, not about this.

### 2. BRAM was genuinely over budget, which silently poisoned the LUTs

Single-copy demand was ~500 tiles vs 365. Vivado's resource-aware
inference then **silently demoted textbook Port-A arrays** (`name_mem`,
`spr_mem`, `vgc_queue`, `json_mem` — perfect 1W1R registered-read shapes)
to distributed LUTRAM: 59k LUT-as-memory (cap 46.2k) plus fabric read
muxes and glue in LUT-as-logic. Only 4 arrays warned "Infeasible
attribute"; the rest demoted with **no warning**. Lesson: when BRAM is
over budget, the LUT count lies too — close BRAM first.

### 3. The dead tagged twin still synthesized

`gc_queue` 16K×14 (RAM64M ×1280), `stack`/`stack_tag`, `varr_tmem`
64K×3, `vobj_tmem` 32K×3, `tfn_*` — all present in the mapping report,
plus every `!hp_v64` FSM arm.

## What landed 2026-08-21 (this tree, FPGA-SIM-verified)

| Change | Effect | Verified |
|---|---|---|
| `AUTO_INCREMENTAL_CHECKPOINT 0` + **bit-fresh required** | kills the stitch duplication | flow only |
| `v64_on` fold — the 33 execution reads of `jsb_flags[3]` are constant 1 (tagged images fault 9 at S_GOT_HDR2 **before** execution, reading the raw header word) | Vivado proves the tagged twin unreachable and sweeps it — the synthesis half of Phase 3b without the 5k-line hand edit | 198/198 bytecode tests; five-title behavior unchanged |
| `imgd_pix` (300K×8, **80 tiles**) → external SRAM top-of-bank, words `IMGD_SRAM_BASE=1789952..2M` (1 px per 16-bit word); VM sram port gained a write channel; core arbiter muxes console-first | −80 tiles; getImageData/putImageData now blit-style req/ack | PACMAN plays 40 frames, `imgd=307199/307200`, fault=0 |
| `MAX_ARR_LONG` 128→**32** (measured peak: 2 long arrays) | varr_slot 128→**104** tiles | five-title FM census + PACMAN/DONKEY RTL play |
| `MAX_OBJ` 1024→**768** (first-round; **FINAL is 960** — see paper budget) | vobj_slot 80→**60** tiles at 768; 960 is the bisect-proven first `.bin` | PACMAN play sits at obj≈690 at 768: fits, but forced-GC rose ~4→~10/frame. Attract burst needs 960 |
| `ENV_DEPTH` 512→**256** (first-round; **FINAL is 384** — 256 corrupted PACMAN BFS) | venv_slot 19→**10** tiles at 256 | see paper budget |
| `CODE_WORDS` 32768→**20480** (measured high-water 16443, PACMAN) + write clamp + **loud capacity fault 3 at S_GOT_HDR2** for oversize images; `jsb_format` refuses at encode | code_mem 32→**20** tiles | tools + HM + pkg mirrored |
| `ram_style="distributed"` pinned on `name_mem`, `spr_mem`, `json_mem`, `vstack`, `stack` (~15k LUTs, deliberate) | stops resource-management gambling; ~26 tiles stay free | build |

Two same-day regressions were introduced and fixed during this pass —
both are RECURRING-BUG-CLASS material (`potential bugs.md`):
- **PACMAN froze after splash**: the new `imgd_pend` handshake flag was
  cleared in the FSM's per-beat default section (where the old `imgd_we`
  strobe lived). With the SRAM model's pulsed ack, the two flapping
  signals anti-phase locked and the ack was never consumed. A handshake
  flag is STATE, not a strobe — never put it in the default-clear block.
- **DONKEY Mario→Luigi returned**: yesterday's dispatch-time supersede
  only fires when the real KEYEVT is already queued. An edge captured
  while `vlistener_n` was momentarily 0 (screen swap) sat armed and
  converted into a phantom arrow seconds later. Now real KEYEVT traffic
  clears captured KEYBITS edges at **enqueue** as well and re-baselines
  `prev_joy`. Verified: 150 idle frames post-charsel, histogram stable.

## Paper BRAM budget (single copy — FINAL after the play-test round)

The first shrink round set MAX_OBJ=768 and PACMAN **pegged the object
heap in play** (fault 3 at obj=768, GC thrashing ~13/frame — the FM
census was splash-biased). User call: stay near 1024 for future titles.
Final caps for the FIRST .bin — **bisect-proven on the real titles**
(2026-08-21 evening; the earlier "measured" shrinks were sized on
splash-biased and between-frame data and two of them broke PACMAN):

- **MAX_OBJ 960**: the attract-mode ghost-AI tick (4× JSON.parse maze +
  BFS in ONE frame) legitimately bursts ~330 objects over ~570 steady
  live. 896 pegged at rafcall 30; 960 clears it.
- **ENV_DEPTH 384**: 256 CORRUPTED PACMAN — the finder's recursive BFS
  transiently holds ~300 envs (the between-frame envl≈140 missed the
  recursion peak); at 256, live envs were recycled mid-recursion and
  callbacks ran on broken environments (the maze-flood). 384 proven
  clean; 512 is the pre-fit fallback (+5 tiles).
- **MAX_ARR_LONG 12** (play peak 2; INVADERS bunkers 4), **CODE_WORDS
  20480** (HM suite's extended PACMAN image is 19,527 words).

| Item | Tiles |
|---|---:|
| Dual FB (hot, product glass) | 150–160 (see note) |
| `varr_slot` 50688×64 | 99 |
| `vobj_slot` 30720×80 | 75 |
| `venv_slot` 6144×73 | ~14 |
| `code_mem` 20480×32 | 20 |
| `imgd_pix` | **0** (external) |
| name/spr/json/vstack/source/work/gc leftovers | 0 (pinned distributed) |
| misc | ~2 |
| **Sum** | **~360–370 of 365** |

**FB note:** the 160 figure (80 RAMB36/bank) was measured on the GARBAGE
stitched netlist; the optimal TDP mapping is 75/bank = 150. A clean
synth decides — which is the point of this build. If the report lands
over 365, the trims in order: ENV 384 already taken; `MAX_ARR_LONG` 8
(−1); our HM raf test shrunk so CODE can drop to 18432 (−2); then the
real unlock is packing `vobj_slot`'s 16-bit key field down to ~10 bits
(−8..14 tiles, mechanical but wide). If it lands comfortably under,
ENV_DEPTH 512 (+5) buys back pre-fit attract longevity headroom.

**User (2026-08-21 night): titles work.** A script once left PACMAN on the
demo loop (nobody playing) and it died around picture-callback 114. That
does **not** change the memory shapes this build bakes, and it is **not**
the next glass hunt. Play is the product.

## Live build ladder — `bit-fresh` 2026-08-21 — **PLACE FAILED** (22:29)

**Ended** Fri Aug 21 **22:29** EDT. Synth **OK**; place **UTLZ-1** (same
class as morning). The `make` Error / `jmr_wait_run impl_1` HEARTBEAT
traceback is **not** a separate Tcl bug — Vivado exited because place
refused; the wait loop just printed the stack.

| # | Step | Status (this run) | Last failed (04:11) |
|---|---|---|---|
| 1 | MIG / project (`bit-fresh`) | **done** | reused (stale) |
| 2–5 | Elabor → opt → map | **done** (~14:46→~21:55) | done |
| 6 | **synth_1 100%** + DCP | **done** ~22:03 | done |
| 7 | Util report | **new** 22:05 — see Headline | LUT 1424% / BRAM 181% |
| 8 | `opt_design` | **done** ~22:08–22:28 | OK |
| 9 | `place_design` | **FAILED** 22:29 UTLZ-1 | **FAILED** UTLZ-1 |
| 10–11 | route / bit / WNS | never reached | never |

### Headline (synth util 22:05) vs morning

| | This `bit-fresh` | Morning place-fail |
|---|---:|---:|
| Slice LUTs | **1,901,313 (1413%)** | 1,917,043 (1424%) |
| LUT as Memory | **57,851 (125%)** | 59,057 (128%) |
| Block RAM tiles | **579 (159%)** | 659 (181%) |
| FFs | OK (~69%) | OK |
| DSP | OK (~21%) | OK |

BRAM dropped by **~80 tiles** (matches parking `imgd_pix` off-chip). LUT
count barely moved — still ~**14×** over the chip. Place dies in seconds
once DRC runs; that is expected when util is this high.

**Still in this synth log (problem):** both `u_core/u_fb` **and**
`u_corei_10/u_fb` (duplicate framebuffer hierarchy again), plus
`Synth 8-7048` BRAM over-util (Used=1157 sites). `bit-fresh` did **not**
clear the double-FB / LUT explosion. Do **not** start another overnight
build until that is understood — re-running the same netlist wastes ~8 h.

**Do not** set `drc.disableLUTOverUtilError` to “force” a bit.

Logs: `tools/board_flow/vivado.log` (UTLZ-1 block ~22:29);
`build/nexys_video/utilization_synth.rpt` (22:05);
`…/impl_1/.place_design.error.rst`.

```bash
# DO NOT re-run until double-FB / 1.9M LUT root cause is fixed
# source scripts/vivado_env.sh && make -C tools/board_flow bit-fresh
```

### Forensics on this run (2026-08-21 late night)

1. **The doubling is not an incremental artifact** — this was a clean
   project. Elaboration instantiates every module ONCE (`(0#1)` in the
   log); the second `u_corei_10/u_fb` hierarchy first appears at **Start
   Technology Mapping**. The `i_N` / `__GCB0` names are Vivado
   parallel-synthesis PARTITION cells — current theory: the partition
   stitch fails to deduplicate on this design. The BRAM arithmetic says
   the duplication is real cells: morning 659 = 2×160 (two FB pairs) +
   339 (VM, old caps) exactly; tonight 579 = 2×160 + 208 (VM, new caps)
   + ~51 (source_mem/work_ram/etc still carrying `ram_style="block"`).
2. **Agent error inflated tonight's LUTs**: the `v64_on` constant fold
   was left temporarily reverted from the PACMAN cap bisection, so this
   run synthesized the whole dead tagged twin again (`stack`,
   `gc_queue`, `*_tmem`, `tfn_*` are back in the mapping tables).
   Restored and re-verified (suite green, PACMAN probe clean) — the next
   synth sweeps them.

### NEXT STEP — 5 minutes, no resynthesis, BEFORE any new build

```bash
source scripts/vivado_env.sh
make -C tools/board_flow hier
```

Opens the EXISTING `post_opt.dcp` (22:27) and writes
`build/nexys_video/utilization_hier.rpt` — per-instance LUT/BRAM to
depth 3 — and prints whether `u_corei_10` is a real top-level cell.
One report answers both open questions: how much of the 1.84M LUTs is
the duplicate tree, and which module holds the rest.

### VERDICT from utilization_hier.rpt (2026-08-21 22:49) — mystery solved

**There is NO duplicate hierarchy.** One u_core, one u_fb — the
`u_corei_10` names in the synth log are phantom partition labels; the
netlist is single-copy. Forget the stitch theory; synth threads stay 2.

The real attribution, from the per-instance table:

| Instance | Logic LUTs | FFs | BRAM | Verdict |
|---|---:|---:|---:|---|
| `(u_vm)` parent FSM | **1,721,397** | 155,482 | 258 | THE problem |
| `u_exec64` | 69,026 | 16k | 0 | healthy |
| `u_fb` | 567 | 27 | **320** | maps at 2.1× optimal (~150) — separate fix |
| `u_stor` | 21,442 | 4k | 0 | bloated but minor |
| everything else | ~8k | — | 0 | fine |

**Why 1.72M:** the parent holds ~155k FFs, and in one flat 112-state
process every FF drags ~9-10 LUTs of replicated state-decode/enable
logic. The FF count is dominated by ARRAYS still implemented as
flip-flops — the exact pathology the Port A law exists for. The
FF-resident census (declared arrays absent from both RAM mapping
tables):

| Array family | FF bits | Fate |
|---|---:|---|
| tagged twin (`consts`,`vars`,`tenv_parent`,`obj_cls`,`tfn_*`,`env_oid`) | ~100k | **swept free** next run — the v64_on fold is restored (it was accidentally reverted for THIS run) |
| `vframe_*` (7 arrays × 128) | ~35k | reads ALREADY registered → full Port A, ≈1 BRAM tile; consolidate the two writer sites through one strobe |
| `vobj_cls`/`vobj_len`/`vobj_builtin` | ~26k | strobe-ify writes → LUTRAM (async reads preserved) |
| `cstack_*` (6 × 128) | ~12k | audit: partly tagged (fold may sweep) |
| `venv_gen`/`venv_len` | ~9k | strobe-ify like venv_parent was |
| ROMs (`font_rom`,`sin_q`,`pow31_tbl`) + small | ~19k | cheap as-is; optional |

Post-campaign estimate: FF arrays ~10-15k bits + ~20k scalar FFs at a
smaller per-FF cost (array-decode replication gone) → the honest answer
arrives from the next `make hier`, but the path from 1.72M to the
chip's 134k is now a sequence of PROVEN-RECIPE conversions, not a
mystery. u_fb's 320→~150 mapping fix is the BRAM sibling task.

**Per-array hazard rule for the strobe conversions:** a strobed write
lands one beat later — scan every write→read-within-1-beat pair before
converting (the #76/#78 lesson family).


## Overnight campaign 2026-08-21/22 — the full restructuring (user directive: fix it, no functionality loss, launch the bit)

Executed after the hier report attributed 1.72M LUTs to the parent's
FF-resident arrays and 320 BRAM to the FB's silent triplication:

1. **v64_on fold restored** — sweeps the dead tagged twin (~100k FF bits
   + its decode).
2. **jmr_mini_fb rewritten**: (a) Port A now has ONE write-priority
   address (the old separate dump_raddr read made a 3rd port and Vivado
   DUPLICATED each bank: 320 tiles); (b) each bank decomposed into exact
   pow2 chunks 256K+32K+8K+4K (zero padding) → **75 tiles/bank, 150
   total**. Registered chunk selects keep the 1-beat read contract.
3. **Every big heap memory pow2-chunked** (Vivado pads BRAM to
   2^addresswidth; the non-pow2 shrinks had saved zero tiles):
   vobj 16K+8K+4K+2K = 75t · varr 32K+16K+2K = 99t · venv 4K+2K = 15t ·
   code 16K+4K = 20t. All boundaries mirrored in sim_main accessors.
4. **vframe record family (6 arrays) → dedicated write process**
   (parent strobe + exec channel; reads were already registered) —
   ~30k FF bits leave the big process. vframe_escaped stays as 128 flat
   FFs (partial-field writers).
5. **vobj_cls / vobj_builtin / venv_gen → dedicated metadata process**
   (15+3 write sites converted to strobes; exec channels moved).
   vobj_len / venv_len DELIBERATELY stay FFs: their read-modify-write
   sites ride the 2-beat heap loop where a +1-beat strobed write could
   be re-read stale.

**Paper BRAM: fb 150 + vobj 75 + varr 99 + venv 15 + code 20 + misc ≈
361/365.** LUT outcome unknown until this synth — the FF-array census
says most of the 1.72M multiplier is gone; residuals are vobj_len/
venv_len/escaped/scalars.

Verified before launch: 198/198 bytecode suite, PACMAN 40-frame play,
promote/listener/bunker/DONKEY-gesture reproductions, full RTL suite as
the launch gate. The user explicitly directed the agent to launch this
build.

## NEVER do these — they break the machine or the build

Violating these is how we got 70 GB hangs, OOM mapping, and fake glass.
Law detail: `.cursor/rules/never-fake-fpga-sim.mdc`,
`one-heap-keep-gen.mdc`, `no-dukpy-cheat-native-cpu.mdc`.

| NEVER | What breaks |
|---|---|
| **`mem[i] <=` / `stack[i] <=` / `vobj_alloc[i] <=`** (etc.) inside the big VM FSM `always_ff` on a large array | **~70 GB synth hang** — RAM becomes FFs. Glass/debug must use tasks too |
| **`ram_style = "block"` while an FSM poke remains** | LUTRAM demotion or the hang; attribute does not save a bad template |
| **Two `stack_wr` in one clock** | Illegal dual write. FOREACH uses `stack_dual_pend` (extra clock) |
| **Peek Port A arrays same cycle** — must wait `*_rdata` | Wrong data / race; never “peek” to make a title paint |
| **Mix blocking `=` and NBA `<=` in one sequential block** | UG901 — bad inference |
| **Reset-clear a whole BRAM in one cycle** / reset inside the RAM process | AR 58025 — breaks BRAM inference (`source_mem`-class) |
| **`unique case` that combo-indexes big unpacked arrays** | Parallel ports / giant mux (use plain `case` on opcode) |
| **Second JS heap** inside exec (private `vvars` / `stack` / `vobj_*` / …) | Will not fit; goes stale; black PACMAN. One heap, keep gen-match |
| **Skip gen-match** on object handles | Silent use-after-recycle |
| **Extract JOIN / JSON / GC / HEAP into new modules** for fit | Forbidden architecture churn |
| **Put whole `vobj_slot` / `varr_slot` or scanout FB on external/DDR3** | Cripples the JS Native CPU / pixel path |
| **dukpy / V8 / soft CPU / execute JS source as one RTL FSM** | Not this machine — bytecode ISA only |
| **Title-name gates** (`if (stem == "PACMAN")`) | Forbidden hardwire |
| **Grow heap past live caps** without a measured plan (`MAX_OBJ=960`,
  arrays `1536×32 + 12×128`, `ENV_DEPTH=384` — [paper budget](#paper-bram-budget-single-copy--final-after-the-play-test-round)).
  Do not restore `8192`/`4096` | Does not fit |
| **Port-A the dead tagged twin** instead of leaving it unreachable | Wasted work; ghost stays |
| **Claim “exec32 removed” while ignoring the `e32_*` naming trap** | 74 parent-owned `e32_*` signals are live silicon — [REMOVING_EXEC32.md](REMOVING_EXEC32.md) |
| **`bit-fresh` to "recover" a mid-run crash** (it is REQUIRED after a file-list change — those are different situations); raise `JMR_VIVADO_SYNTH_THREADS`; `JMR_VIVADO_ALLOW_WIDE=1`; `drc.disableLUTOverUtilError` | Loses MIG/project for nothing, or papers over over-util |
| **`AUTO_INCREMENTAL_CHECKPOINT 1`** or any incremental synth while the RTL is changing | Stitches against a stale reference — the 04:11 netlist held the FB twice and ~2x logic; place cannot fix a garbage netlist |
| **Agent runs Vivado / `make bit`** | User only, host terminal |
| **Pretend PYTHON or host twin is FPGA-SIM** | Fake machine |

### How to write on-chip RAM (legal)

```systemverilog
// GOOD — Port A / tasks only (FSM sets strobes)
stack_wr(sp, alu_r, tag);
vobj_alloc_wr(valloc_i[9:0], 2'd1);
// BAD — 70 GB
stack[sp] <= alu_r;
vobj_alloc[valloc_i] <= 2'd1;
```

Copy `jmr_mini_fb.sv`. One `we`/`addr`/`data`; read next clock; **no**
reset-clear in the RAM process; clear strobes every beat; RUN-init via
strobe / `heap_clr`. Cold buffers (once moved) use `jmr_sram_port`
(`req`/`ack`) — not a second on-chip poke path.

| Word | Meaning |
|---|---|
| **BRAM** (Block RAM) | On-chip tiles (**365** on this chip). Hot path only: dual framebuffer, bytecode, live JS heap |
| **LUT** (Look-Up Table) | FPGA logic cell (~134,600). **LUTRAM** = a LUT used as tiny RAM — OK for 8-deep; fatal for `name_mem`-class under BRAM pressure |
| **Port A** | Legal BRAM shape: `if (we) ram[waddr] <= wdata; rdata <= ram[raddr];` with **scalar** we/addr/data. FSM only pulses strobes |
| **Dead twin** | Tagged (pre-Value64) arrays still *declared* in the parent after Cut A. **Synthesis:** `v64_on` fold makes them unreachable. **Source delete:** optional; do not Port-A them |
| **WNS** | Worst Negative Slack — timing. Publish a `.bit` only if WNS ≥ 0 |
| **MIG** | Memory Interface Generator — DDR3 controller. `ui_clk` ≈ 100 MHz |
