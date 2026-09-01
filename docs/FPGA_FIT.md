# T200 fit — agent repair brief

Words: [README.md — Words used](../README.md#words-used-in-this-project).

---

## SCOREBOARD — update this table every run (one screen)

**Last bitstream on disk: run 61 — routed 2026-08-30 14:03, TIMING CLEAN**
(`build/bits/run61_findcache_bucket_WNS+0.120.bit`). Live board bit.
**WNS +0.120 / WHS +0.050.** Payload: FIND 1024-entry hash→id bucket +
concat-handoff cache arming (the 4-way FF cache had been blind to concat
since birth). PACMAN 11.58M → 10.90M VM beats/frame (×1.54 vs run 57).
div7 = 14.3 MHz. Reports:
`build/runs/run61_findcache_bucket_dedup_WNS+0.120/`.
**Fit is solved. Timing is solved.** The JS core runs on a divided clock
so 100 MHz fabric/DDR3 still close. Hedge:
[If timing fails](#if-timing-fails-wns--0--slow-the-js-core-not-ddr3).

Source: `build/runs/run61_findcache_bucket_dedup_WNS+0.120/utilization_impl.rpt`
(Design State: Routed, 2026-08-30 14:03). Chip: XC7A200T, 134,600 LUTs /
269,200 FFs / 365 BRAM tiles / 740 DSP48E1.

| Resource | Used | Budget | % | State |
|---|---:|---:|---:|---|
| **Slice LUTs (total)** | **100,429** | 134,600 | **74.6%** | **fits — 34,171 free** |
| LUT as Logic | 97,428 | 134,600 | 72.4% | fits |
| LUT as Memory (LUTRAM) | 3,001 | 46,200 | 6.5% | fits — 43k free |
| — Distributed RAM | 2,984 | — | — | RAMD64E 1,988 + RAMD32 1,500 + RAMS32 472 |
| — Shift register | 17 | — | — | SRL16E |
| Slice Registers (FF) | 55,200 | 269,200 | 20.5% | fits — see FIND-bucket note |
| **Slice (packing)** | **31,633** | 33,650 | **94.0%** | **tightest resource on the chip** |
| — SLICEL / SLICEM | 20,636 / 10,997 | — | — | — |
| F7 Muxes | 8,271 | 67,300 | 12.3% | fits |
| F8 Muxes | 2,868 | 33,650 | 8.5% | fits |
| Unique control sets | 2,778 | 33,650 | 8.3% | fits |
| **Block RAM tiles** | **352.5** | 365 | **96.6%** | fits — 12.5 tiles free |
| RAMB36 | 329 | 365 | 90.1% | — |
| RAMB18 | 47 | 730 | 6.4% | ×0.5 = 23.5 tiles |
| DSP48E1 | 128 | 740 | 17.3% | fits |
| Bonded IOB | 93 | 285 | 32.6% | fits |
| BUFGCTRL | 5 | 32 | 15.6% | fits |
| MMCME2 | 3 | 10 | 30.0% | fits |
| PLLE2 | 1 | 10 | 10.0% | MIG |
| CARRY4 (primitives) | 4,632 | — | — | timing cone — no longer binding |
| **`place_design` / `route_design`** | — | — | — | **completed, 0 overlaps** |
| **WNS (100 MHz, 10 ns)** | **+0.120 ns** | ≥ 0 | — | **MET — published by the gate** |
| **WHS (hold)** | **+0.050 ns** | ≥ 0 | — | **MET** |

**FIND-bucket note (why FFs jumped vs run 60):** `jn_bucket` is 1024×24
with `ram_style = "block"` but inferred as flip-flops — BRAM tiles are
**identical** to run 60 (352.5), LUTRAM identical (3,001), FFs
30,468 → **55,200** (+24,732 ≈ 1024×24). Control-sets report names
`jn_bucket[N][23]_i_1` per row. Write is still an FSM poke
(`jn_cache_remember` → `jn_bucket[jn_h] <=` from the parent case).
`ram_style` does not save that. The extra ~13.8k LUTs are the decode /
1024:1 read mux, not new JS state.

**Primitive detail** (run 61; regenerate from `utilization_impl.rpt`
section 8 — do not hand-maintain):

| LUT | | Flop & Latch | | Memory / other | |
|---|---:|---|---:|---|---:|
| LUT6 | 48,487 | FDRE | 53,306 | RAMD64E | 1,988 |
| LUT5 | 20,411 | FDSE | 836 | RAMD32 | 1,500 |
| LUT4 | 15,785 | FDCE | 949 | RAMS32 | 472 |
| LUT3 | 13,812 | FDPE | 107 | SRL16E | 17 |
| LUT2 | 12,938 | LDCE | 2 | RAMB36 / RAMB18 | 329 / 47 |
| LUT1 | 2,149 | | | MUXF7 / MUXF8 | 8,271 / 2,868 |
| INV | 3 | | | CARRY4 | 4,632 |

BRAM tiles = 329 × RAMB36 + 47 × RAMB18 × ½ = **352.5 / 365**.

### Why placement, not size, decides whether this design routes

Runs 44–46 are the controlled proof: run 46 carries **+5,000 LUTs over run 44**
on identical BRAM and DSP, and it is the one that both routed and closed
timing. **A route failure here is a placement diagnosis until proven
otherwise.** How to write: [RTL_DESIGN_PRINCIPLES.md](RTL_DESIGN_PRINCIPLES.md).

### Trajectory (milestones only)

| Milestone | Slice LUTs | Lesson |
|---|---:|---|
| Pre-campaign | 1,901,313 | FSM-as-FF + duplicated FB |
| First under budget (run 27–28) | 131,314 | BRAM first, then place |
| First timing-clean (run 46) | 110,532 | Placement strategy, not fewer LUTs |
| Leanest published (run 60) | 86,628 | |
| **Live (run 61)** | **100,429** | SCOREBOARD above |

Git has every intermediate run. Closed/dead levers stay below.

### FIT levers — closed out, kept for the record

Listener consolidation, `vst_win` (16->8 attempted, **reverted** — silent
correctness bug at deep nesting, see `tests/test_stack_window_depth.py`),
`name_has`/`vlong_used`/name-family 1W merges, the LUTRAM->BRAM sweep, and
`linebuf`->BRAM collectively closed the fit gap. **Do not revisit `vst_win`
without the pop-refill detector design — the shrink is a language-contract
change, not a free cut.**

**Dead levers — do not retry:** 20 ns clock relax (bit-identical netlist;
XDC never applies at synthesis), one-hot `fsm_encoding` (parent FSM not
extractable through `hs_st()`/`ret_state`), HOF/regex/sort/bind walls
(confirmed by real census: regex ~126 LUTs, sort's removable share <300
LUTs — both done anyway for the correctness catch, see `potential
bugs.md`, not for area), Verilator `--threads` (1 OS thread, single flat
`always_ff` will not partition), Default vs ExploreArea opt-directive
shopping (±250 slices, not a real lever — RTL fixes are).

---

**T200** = this Nexys Video board (Artix-7 **XC7A200T**, 365 **BRAM** Block
RAM tiles, 134,600 **LUTs** Look-Up Tables). **Fit** = does the design
place without over-util. Agent does **not** run **Vivado** (AMD’s FPGA
compiler) — you do:

`source scripts/vivado_env.sh && make -C tools/board_flow bit-fresh`

(once, 2026-08-21: source file list changed). After that, ordinary `bit`
unless the file *list* / MIG / XDC changes. Same `rtl/*.sv` as FPGA-SIM.

This file is **copy 2** of the RAM / “never fake FPGA-SIM” law (copy 1 is
`.cursor/rules/never-fake-fpga-sim.mdc`). Synth hygiene **copy 1** is
[SESSION_HANDOFF.md](SESSION_HANDOFF.md) § Synthesis; this NEVER table
plus [OLD_RUNS.md](OLD_RUNS.md) are the taxonomy.

One JS heap. Control-only extraction allowed since 2026-08-22 (u_exec64
shape: no arrays, scalar ports, registered reads); never extract-with-copies JOIN / JSON / GC (Garbage Collection) / HEAP
into new modules. Extra clocks OK. **Future plan** if the JS core misses
100 MHz: [If timing fails](#if-timing-fails-wns--0--slow-the-js-core-not-ddr3)
(50 MHz core, DDR3 stays 100 MHz) — not wired yet.

**This campaign is also the ASIC diet (2026-08-23):** the target is
SkyWater 130 nm at ~2× the BASIC die, where ~170k logic LUTs ≈ tens of
mm² of standard cells — every LUT removed here is future die area
removed. [CONSTITUTION.md](../CONSTITUTION.md) § ASIC target.

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
Phase 3b: [REMOVING_EXEC32.md](REMOVING_EXEC32.md). External port map:
[ARCHITECTURE.md](ARCHITECTURE.md) § External SRAM.

---

## JS core clock and crossing strobes

**Depth is the lever.** Slow paths were ~50% logic / ~50% route because they
were deep, not because placement was unlucky. Combinational divides in sprite
math were the worst cone. Product fix: **run the JS VM on a divided clock**
(today ÷7 ≈ 14.3 MHz) and keep DDR3 / scanout on 100 MHz. Do not slow MIG.
Hedge recipe: [If timing fails](#if-timing-fails-wns--0--slow-the-js-core-not-ddr3).
How to write so this does not come back: [RTL_DESIGN_PRINCIPLES.md](RTL_DESIGN_PRINCIPLES.md).

**If you change `VM_CLK_DIV`, these crossings are silent when wrong.**

**Class A — fast→slow strobes the VM will miss** (1-fast-cycle pulse). Stretch
to ≥N fast cycles or handshake: `sram_ack`, `code_we` (burst), `frame_tick`,
`key_evt_stb`, `stop`, `start`.

**Class B — slow→fast strobes that become N cycles wide.** Edge-qualify in the
fast domain: `fb_swap`, `fb_we` (idempotent, low risk), `sram_req` (safe if
`sram_ack` is Class A–fixed).

**Class C — levels / data qualified by a listed strobe:** `joy_in`,
`fb_present_busy`, `busy`, `done`, `sram_addr/we/wdata`, key codes, code write
addr/data.

---

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
  clean on FPGA-SIM; 512 is the pre-fit fallback (+5 tiles).
  **BOARD 2026-08-26 (#84):** 384 + recursive `finder` still froze HDMI
  (SIM Pac-Man still moved). **Do not raise `ENV_DEPTH` 384→512 or
  `CSTK`** — the T200 is full and new bits fail routing. V1 HTML:
  one-step chase (`storage/PACMAN.HTML`); original flood is
  `PACORIG.HTML` (will freeze). Do not add a pathfinding opcode.
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

## Fit forensics (lesson only)

Place-fails were **UTLZ-1**: incremental stitch duplicated the framebuffer;
BRAM oversub demoted Port-A arrays to LUTRAM; tagged twin survived a constant
fold. Hand-delete: [REMOVING_EXEC32.md](REMOVING_EXEC32.md). Taxonomy:
[OLD_RUNS.md](OLD_RUNS.md).

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
| **Extract WITH heap-array copies** (any submodule owning/duplicating a heap array) | Second heap; goes stale. Control-only extraction in the u_exec64 shape is ALLOWED (2026-08-22) |
| **Put `vobj_slot` / `varr_slot` (the heap) or the DRAW bank on external/DDR3** | Cripples the JS Native CPU: S_V64_RECT writes 1 px/clock, PACMAN paints ~620k px/frame — a DDR3 draw bank multiplies frame cost through the bridge. **CONSCIOUS RELAXATION 2026-08-23 (user, rule-5 style): the FRONT/scanout bank + line-FIFO MAY move to DDR3** — scanout is sequential/prefetchable, swap becomes a burst copy (~3ms, in budget at the accepted half frame rate), and the ~75-80 freed BRAM tiles absorb the ~17k LUTRAM spill return. The draw bank stays BRAM. |
| **dukpy / V8 / soft CPU / execute JS source as one RTL FSM** | Not this machine — bytecode ISA only |
| **Title-name gates** (`if (stem == "PACMAN")`) | Forbidden hardwire |
| **Grow heap past live caps** without a measured plan (`MAX_OBJ=960`,
  arrays `1536×32 + 12×128`, `ENV_DEPTH=384` — [paper budget](#paper-bram-budget-single-copy--final-after-the-play-test-round)).
  Do not restore `8192`/`4096` | Does not fit |
| **Port-A the dead tagged twin** instead of leaving it unreachable | Wasted work; ghost stays |
| **Claim “exec32 removed” while ignoring the `e32_*` naming trap** | 74 parent-owned `e32_*` signals are live silicon — [REMOVING_EXEC32.md](REMOVING_EXEC32.md) |
| **`bit-fresh` to "recover" a mid-run crash** (it is REQUIRED after a file-list change — those are different situations); raise `JMR_VIVADO_SYNTH_THREADS`; `JMR_VIVADO_ALLOW_WIDE=1`; `drc.disableLUTOverUtilError` | Loses MIG/project for nothing. (The DRC demotion itself became a sanctioned experiment 2026-08-23 — user-directed, to let placement attempt LUT pairing; it stays set in vivado_build.tcl.) |
| **`AUTO_INCREMENTAL_CHECKPOINT 1`** or any incremental synth while the RTL is changing | Stitches against a stale reference — the 04:11 netlist held the FB twice and ~2x logic; place cannot fix a garbage netlist |
| ~~Agent runs Vivado / `make bit`~~ | Overridden 2026-08-22 by the user ("start the .bin yourself"): the agent runs builds directly; kill leftover heartbeat shells by PID after any aborted run |
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
| **Dead twin** | Tagged (pre-Value64) arrays declared in the parent after Cut A. `v64_on` fold did **not** sweep them. Source delete **done 2026-08-22** — [REMOVING_EXEC32.md](REMOVING_EXEC32.md). Do not Port-A them |
| **WNS** | Worst Negative Slack — timing. Publish a `.bit` only if WNS ≥ 0 |
| **MIG** | Memory Interface Generator — DDR3 controller. `ui_clk` ≈ 100 MHz |
