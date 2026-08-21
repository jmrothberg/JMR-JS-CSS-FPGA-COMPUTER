# T200 fit — agent repair brief

Nexys Video **XC7A200T** (365 BRAM tiles, 134,600 LUTs). Agent does
**not** run Vivado — user does:
`source scripts/vivado_env.sh && make -C tools/board_flow bit`.
Same `rtl/*.sv` as FPGA-SIM. Law: `.cursor/rules/never-fake-fpga-sim.mdc`.
One JS heap. No JOIN/JSON/GC extract. Extra clocks OK.

Diaries: [OLD_RUNS.md](OLD_RUNS.md). Glass: [SESSION_HANDOFF.md](SESSION_HANDOFF.md).
Phase 3b procedure: [REMOVING_EXEC32.md](REMOVING_EXEC32.md).
External port map: [ARCHITECTURE.md](ARCHITECTURE.md) § External SRAM.

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

1. **Delete the dead twin** — the old decoder file is gone, but the
   parent still builds second stacks/heaps for tagged JS. Nothing
   Value64 uses that. Removing it does not change the language, the
   heap model, or the games; it stops synthesizing a ghost CPU.
   ([REMOVING_EXEC32.md](REMOVING_EXEC32.md) Phase 3b.)

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
| `MAX_OBJ` 1024→**768** (measured peak 567; fn bank shares the cap, fn peak 510) | vobj_slot 80→**60** tiles | PACMAN play sits at obj≈690: fits, but forced-GC rate rose ~4→~10/frame — a known speed cost; the GC-pacing ledger item is the antidote. If a future title faults 3 here, raising MAX_OBJ is the FIRST lever to reconsider |
| `ENV_DEPTH` 512→**256** (measured peak 157) | venv_slot 19→**10** tiles | same runs |
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
Final caps for the FIRST .bin (user call 2026-08-21 evening: margin over
headroom until the real utilization report exists — #79, the PACMAN
pathfinder explosion, kills any cap equally, so extra object slots buy
nothing yet): **MAX_OBJ 896** (non-pow2 is safe: bug #76's OBJ_PHYS
architecture keeps the sliced side arrays at 1024 physical), **ENV_DEPTH
256** (validated: live envs ride ~140 in play), **MAX_ARR_LONG 12**
(measured peak 2; INVADERS bunkers use 4), **CODE_WORDS 20480** (the HM
suite's extended PACMAN image is 19,527 words).

| Item | Tiles |
|---|---:|
| Dual FB (hot, product glass) | 160 |
| `varr_slot` 50688×64 | 99 |
| `vobj_slot` 28672×80 | 70 |
| `venv_slot` 4096×73 | ~10 |
| `code_mem` 20480×32 | 20 |
| `imgd_pix` | **0** (external) |
| name/spr/json/vstack/source/work/gc leftovers | 0 (pinned distributed, ~15k LUTs) |
| vram/font/sbuf/MIG (measured ~0 this synth) | ~1 |
| **Sum** | **~360 of 365** |

Margin ≈ 5 tiles. After the first successful `.bin`, read the REAL
numbers from `utilization_synth.rpt` (the LAST session in runme.log) and
revisit: if BRAM landed comfortably under, `MAX_OBJ` walks back up
toward 1024 (960 = +5 tiles, 1024 = +10) — the user wants that headroom
once #79 is fixed and the report says it fits. LUT-as-logic is **unknown until a clean run** — the
1.92M number was stitch-poisoned. If the fresh synth still shows
LUT-as-logic over ~134k, the next lever is the textual Phase 3b strip
(REMOVING_EXEC32.md) of whatever the `v64_on` fold could not prove dead,
then real ISA-surface decisions — do not touch the heap caps again for
LUTs.

## The next build (user runs, host terminal)

```bash
source scripts/vivado_env.sh
make -C tools/board_flow bit-fresh
```

`bit-fresh` is REQUIRED this once: the source file list changed and the
reused project's incremental reference is the garbage stitched netlist.
MIG regenerates (adds time; deterministic). Synth 2 threads / impl 8
unchanged. After synth_1 100%, fill the Headline from
`build/nexys_video/utilization_synth.rpt` — read the **last** session in
`runme.log` if grepping it.


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
| **Grow heap past** `MAX_OBJ=1024`, arrays `1536×32+128×128`, `ENV_DEPTH=512` without a measured plan | Does not fit; 8192/4096 is banned |
| **Port-A the dead tagged twin** instead of deleting it | Wasted work; ghost stays |
| **Claim “exec32 removed” while dead twins still synthesize** | Half-cut; place still pays for them |
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
| **BRAM** | On-chip tiles (365). Hot path only. |
| **LUTRAM** | LUTs as small RAM. OK for 8-deep; fatal for `name_mem`-class under BRAM pressure. |
| **Port A** | Legal BRAM shape above. |
| **Dead twin** | Tagged arrays still in the parent after Cut A — **must delete** (Phase 3b). |
