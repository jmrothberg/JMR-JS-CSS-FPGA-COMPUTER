# A200T native JavaScript speed recovery plan

Initial review on 2026-10-26 against source revision `38b6da1`.
The implementation and current validation are recorded in
[GAME_SPEEDUP_RESULTS.md](GAME_SPEEDUP_RESULTS.md). The environment and
baseline statements below describe the initial review, before installing
the tools and implementing the authorized changes.

**Recommendation:** first remove repeated work in the ordinary JavaScript,
then shorten the CPU's lookup/writeback paths, and improve external-memory
traffic where measured. Aim for 3–5× lower **end-to-end frame time** through
these combined changes. Keep JavaScript bytecode as the native ISA and keep
the current FPGA and language contract. A multiplier replacement or clock
change by itself is not a supported 3–5× claim.

## 1. What the evidence establishes

This checkout contains `PACFAST.HTML`, `DNKFAST.HTML`, and `DNKF.HTML`, not
the older `PACMAN.HTML`/`DONKEY.HTML` named in many documents and tests.
The two Donkey versions compile to the same 5,234 instructions and use
different art: product images are 2,369,922 and 1,693,696 bytes respectively.
This review profiles **PACFAST and DNKF**, including DNKF's current full art.
Identify the exact flashed bit and card hashes before comparing board speed.

There is no `build/`, board card image, existing trace set, Vivado executable,
or Verilator executable in this checkout's environment. Consequently:

- Physical numbers below are the **recorded run-71c results**, not new
  synthesis or timing measurements. The run-61 scoreboard in `FPGA_FIT.md`
  is older than the run-71c entry in `SESSION_HANDOFF.md`.
- New measurements are from **fresh product-minted serialized ProgramImage
  words executed by `hardware_model/js_vm.py:JsHwVm`**. They measure dynamic
  bytecodes, source lines, method calls, and operand classes. They do not
  measure RTL cycles, DDR stalls, board FPS, or hardware GC frequency.
- Gameplay samples have no held movement input. They exercise active
  Pac-Man and Donkey's first barrel window, not a complete play-through or
  the maximum barrel population. Longer deterministic input replays remain
  required for acceptance.

Reproduce the evidence without changing the product:

```bash
python3 tools/profile_game_workload.py --output /tmp/game-workload.json
```

The captured result is
[`performance/2026-10-26-game-workload.json`](performance/2026-10-26-game-workload.json).
It includes source/program hashes and per-frame counts. Pac-Man auto-starts
after two rAF callbacks: an extra Enter pauses it. The profiler accounts for
that, and uses separate title/character Enter presses for Donkey.

### Current physical baseline

| Item | Evidence / implication |
| --- | --- |
| JS clock | `rtl/jmr_js_core.sv:18`, XDC generated clock: **100 MHz ÷ 7 = 14.286 MHz** |
| Fast engines | DDR3 bridge, raster, present, scanout remain at **100 MHz** |
| Run-71c LUTs | **90,413 / 134,600 (67.2%)** |
| Run-71c occupied slices | **27,093 / 33,650 (80.5%)**; packing/local routing matter more than headline LUT headroom |
| Run-71c BRAM | **353.5 / 365 (96.85%)**; only **11.5 tiles free** |
| Run-71c timing | overall WNS **+0.311 ns**, WHS **+0.025 ns**, intra-VM slack **+4.268 ns** |
| Build history | 71b routed in 9 minutes; 71c in 19.5 minutes; the initial 71 attempt took substantially longer and failed timing |

Sources: `docs/SESSION_HANDOFF.md`, run-71 entries; source clock and memory
wiring. Retrieve the original routed reports before selecting a new clock.
The recorded intra-VM slack suggests a roughly 65.7 ns limiting path under
the 70 ns constraint; it does **not** establish that 25 MHz will close.

The old 30-FPS plan's **3.33 million cycles/frame** is a 100-MHz *fabric*
budget. At the present JS clock, an entirely VM-bound 30-FPS frame has only
**476,190 VM beats**; 60 FPS has **238,095**. Mixed-clock workloads need a
100-MHz elapsed-cycle measurement, not a count of VM beats divided by 100M.

### New workload measurements

| Workload | Average bytecodes/frame | Median | Largest sampled frame | Source finding |
| --- | ---: | ---: | ---: | --- |
| Pac-Man, first 30 active frames after startup | 72,976 | 61,661 | 235,137 | `_isPower` = **41.6%** of bytecodes; pellet draw traversal = **37.3%** |
| Pac-Man, next 90 frames | 70,976 | 61,646 | 221,778 | `_isPower` = **42.8%**; pellet draw traversal = **38.4%**; `_ghostHome` = **9.6%** |
| Donkey, early 30 active frames | 20,197 | 20,196 | 20,223 | `_dkDirty1` = **46.6%**, `Platform.drawDirty` = **24.5%** |
| Donkey, later 90 frames | 20,203 | 20,208 | 20,235 | Same dominant repair loops; about **33.5 sprite draws/frame** |
| Donkey, next 150 frames including first barrel activity | 22,246 | 20,208 | 31,937 | Repair loops = **47.6% + 23.8%**; about **37.7 sprite draws/frame** |

Percentages count instructions attributed to disjoint source ranges, not
inclusive function times or fractions of FPGA frame time. Regions:
`PACFAST.HTML:36–43`, `1196–1230`, `135–191`;
`DNKF.HTML:1191–1213`, `102–114`. Source locations in the JSON are HTML lines.

One correctness constraint must be addressed early: the **current product
mint of PACFAST overflows the code BRAM trailer by 151 words**. Its code
portion is 82,524 bytes against 81,920 bytes of storage. Instructions fit,
but tail metadata is dropped by the loader. This is already modeled in
`JsHwVm.load_image`; error-free model execution does not establish that all
strings/metadata survive on silicon. Recover that space through source or
compiler code-size reduction before accepting the optimized title. Do not
increase code BRAM or accept silent truncation as a performance solution.

## 2. RTL bottlenecks and work already recovered

| Current implementation | Why it matters | Action |
| --- | --- | --- |
| `jmr_js_vm_exec64.sv:1332,2052,7798`: ordinary nonzero Number MUL uses **53 shift/add beats** | A deliberate fit/timing compromise. Donkey has ~265 such products/early frame, all small integer pairs in this sample | Add a bounded exact fast path if cycle profile justifies it; retain the fallback |
| `exec64:7843`: general DIV uses **107 restoring beats** | Pac-Man position conversion divides by tile size; Donkey repeatedly evaluates `640/1510` and `480/685` | Hoist invariant JS expressions first; existing `/2^k` fast path already exists |
| `jmr_js_vm.sv:9180`: two **16-beat** divides per sprite draw | Repeated sprite shapes redo the same quotient/remainder setup | Small exact shape cache or trivial equal-size bypass only if measured worthwhile |
| Parent `S_HEAP_WAIT/CMP`, exec LOAD_VAR/GET_PROP/calls | Variable loads are ~one third of sampled bytecodes; property/env scans amplify ordinary JS work | Measure beats/lookup, then improve hints or a small validated slot cache |
| Result funnels in parent/exec `vst_wr`, Number ADD/pack logic | Wide shared result selection and deep arithmetic limit clock; historical reports identify costly stack funnels | Register a small number of result classes locally; inspect current critical-path families first |
| `jmr_raster_engine.sv: M_IMGD` | Snapshot restore still requests **one 16-bit external word per 8-bit pixel**; Pac-Man does a full-screen restore each active frame | Measure memory stalls; pack snapshots/use local burst service if they dominate |
| `jmr_ddr3_sram_bridge.sv`, core SRAM arbiter | One BL8 read-cache entry is shared by scanout and raster; present outranks raster; serialized 16-bit clients leave DDR bandwidth unused | Count per-owner stalls/cache thrashing; improve bounded buffering, preserving scanout deadlines |
| `jmr_js_vm.sv:12128`: GC array walk | A two-beat element walk over large live arrays; Pac-Man has ~1,417 live arrays in the sampled model | Measure hardware share; consider conservative reference metadata, not heap expansion |

The small arithmetic numbers prevent a misleading priority choice:
265 × 53 × 70 ns is about **0.98 ms/frame** of Donkey MUL engine iterations.
33 × 32 × 70 ns is only **0.074 ms/frame** of sprite divider iterations.
There are additional dispatch/packing costs, but neither term alone
supports a 3–5× game speedup. Pac-Man's ~166 nonzero products similarly
contribute about **0.62 ms** of multiply iterations. Rank changes using
whole-frame timings, not the apparently dramatic 53→N operation ratio.

Several old recommendations are **already implemented**:

- Full-rate `jmr_raster_engine` performs fill/blit/ImageData walks; moving
  these out of the divided VM a second time earns nothing.
- The draw framebuffer is one persistent BRAM bank; the front is DDR3.
  The old 307,200-pixel BRAM copy-back is gone.
- `S_FB_SYNC` no longer waits through the complete present before allowing
  GC/JS work. Draw fences still exist; comments claiming all fences were
  dropped are stale. Faster JS can make these waits visible again.
- FIND has last-four hits and a 1,024-entry bucket cache. The bucket's
  single-write-port repair is in the source. The run-61 FF implementation
  is not evidence that today's bucket still fails BRAM inference.
- Forced-GC/frame-end-GC dedup, safe opcode prefetch, compiler global/slot
  hints, and an eight-entry method-lookup cache already exist.

Preserve these wins and verify their mapping rather than reimplementing
them. `STATEHIST?` currently counts states on **every 100-MHz simulator
tick**, including held divided-clock states; those counters are fabric
elapsed cycles, not counts of VM edges. Keep that distinction explicit.

## 3. Implementation order and decision gates

### A. Establish a board-faithful baseline before RTL changes

1. Record source revision, bit hash, card/JSH hashes, actual divisor, and
   current routed utilization/timing/congestion reports. Repeat the same
   input recording on each candidate. Build a current card once from the
   same source; retain the original for A/B comparisons.
2. Use the existing `STATEHIST?`, `VMSTAT?`, heap split, prefetch, and method
   counters. Add simulation-only counters for retired instructions, actual
   VM edges, MUL/DIV waits, raster active cycles, fence stalls, and each
   SRAM owner's request-to-ack latency. Start/end frame measurements at
   complete callback/frame boundaries and include scheduled GC and visible
   present completion; the `FRAME` RPC's swap return is not enough.
3. Exercise Pac-Man chase/search, turning, pellet depletion, power/eyes,
   death and level change; Donkey moving/jumping/climbing, overlapping
   dirty boxes, multiple barrel populations, death/restart, and pause.
   Track median/p95/p99/max frame time and input response. Save raw data.
4. Test the **real DDR3 bridge** against a behavioral MIG application-port
   responder with realistic/variable command/read latency, refresh stalls,
   and independent write-data readiness. Current `SRAM_INTERNAL=1` replaces
   the bridge with one-cycle memory and cannot predict board bus stalls.
   Do not substitute a host game implementation for the CPU RTL.

Exit: a table of frame time by VM, GC, raster, memory, fence, and idle time;
no double-counting overlapped intervals. Use this to select the next lever.

### B. First performance patch: reduce ordinary JS work, zero new hardware

**Pac-Man:** `beans.draw` scans 28×31 cells and calls `_isPower` for ordinary
uneaten pellets even after those pellets are already baked into ImageData.
Split the cached path: iterate the small existing power-pellet list for
its animated draws; retain the required erase pass for eaten regular
pellets. The first paint keeps its full grid walk. This removes repeated
linear power-list searches without changing the maze or pictures.

Next, measure whether a sparse list of consumed cells/runs can replace the
remaining whole-grid erase scan. Bound/chunk lists within existing array
caps, reset on level changes, and preserve the exact erased areas. Maintain
a pellet count on actual consumption to replace `_mapHasZero`'s level-end
scan if useful. Do not allocate another permanent grid. `position2coord`
also creates a new object for each actor/frame: introduce explicit reused
per-actor coordinate storage only after checking aliases/reset lifetimes.

The comments say chase is one-step, but `PACFAST.HTML:1317` still calls
`_ghostHome` once per eligible chase frame. Its BFS contributes spikes:
sample maximum >220k versus median ~61.6k instructions. Keep shortest-path
behavior; retain/cache a JS route until the ghost/target tile changes,
or use an ordinary bounded iterative search schedule with equivalent
decisions. Do not silently downgrade ghost behavior or add a maze opcode.
Validate worst-frame latency separately from average speed.

**Donkey:** `_dkBlitBg` repairs old and new Mario/barrel boxes separately;
every `_dkDirty1` rescans all 53 platforms and ten ladders, and each
overlapping platform's `drawDirty` scans all its tiles again. First:

- Hoist constant world-to-glass scales and immutable platform bounds.
  Keep drawing's **15-unit tile pitch** separate from collision's existing
  **20-unit width calculation**; changing one to match the other changes
  the game.
- Compute the first/last possibly overlapping tile arithmetically, clamp
  to the platform, and preserve the original per-tile overlap test/order.
- Coalesce overlapping old/new dirty boxes per actor. Build conservative
  candidate lists for platforms/ladders using their fixed geometry, then
  repair each affected tile once. Keep erase/background/actors/HUD order,
  transparent pixels, Kong poses, and all offscreen clipping correct.
- Extend conservative broad-phase selection to actor/platform collisions
  if needed, preserving original collision order and using the full scan
  whenever the candidate bounds cannot prove equivalence.

Target **50–65% fewer dynamic bytecodes** in representative frames for each
title; this is a testable work-reduction target, not a board-FPS prediction.
These patches consume no RTL resources and recover code space. Verify code
and heap headroom, including inlined params and the 16-local-slot wall.
Retain full-resolution art, all levels, controls, and original motion per
simulation update. Increasing pixels moved per frame does not count as a
CPU speedup. Benchmark the unchanged games separately when assessing
general CPU gains.

### C. CPU changes: improve common JS paths before broad parallelism

Use the new lookup-cycle profile to choose between these small changes:

1. Improve compiler-proven local/global slot addressing or introduce a
   small **location cache** for property/environment lookup. Cache a slot,
   not a second value/heap. Validate handle generation and the key at the
   cached slot using the existing registered memory port; misses take the
   normal scanner. Environment caching additionally needs invalidation for
   nearer-scope shadowing, frame reuse, and RUN. Do not duplicate the
   existing method cache or repeat the slot-hint prefix-skipping bug.
2. Separate hot stack results from cold native/error/format results using
   registered result classes with one final SRAM writer. Pipeline deep
   Number add/normalize/pack paths where current timing reports require
   it. Preserve immediate consumers, branch resolution, parent handoffs,
   prefetch provenance, and the 16-entry stack window.
3. If arithmetic remains material, add an exact small-integer multiply
   fast path (bounded magnitudes, full-width product, binary64 output) and
   an exact power-of-two path. Keep signed zero, subnormal, overflow,
   NaN/Infinity cases on the proven fallback until separately verified.
   Do not change Number to int32/fixed point. General mantissa acceleration
   can use a **shared registered partial-product DSP engine**, targeting
   roughly 10–20 beats rather than an unregistered 53×53 fabric multiply.
   Prototype and measure mapping; avoid a large one-cycle multiplier.

The DSP option uses existing device capability: AMD documents the DSP48E1
25×18 multiplier and recommends pipelining multiplier designs in
[UG479](https://docs.amd.com/api/khub/documents/gu4oRPFEh_Pm2uaAlfY6Kg/content).
Exact DSP count, latency, and timing are synthesis questions. The recorded
run-61 count was only 128/740 DSPs; obtain the current count first.

Keep these as separate measurable patches. In particular, do not pay for
new arithmetic after source hoisting has removed its workload.

### D. Increase JS clock only after shortening the measured timing cones

Keep fast fabric/MIG at 100 MHz and retain the divisor mechanism. Target
**÷4 / 25 MHz** as a worthwhile intermediate objective, a **1.75×** gain
for genuinely VM-bound work. **÷3 / 33.3 MHz** is a stretch objective
requiring substantially shorter paths, not a constraint-only experiment.

Inspect at least 100 intra-VM paths across endpoint families, plus every
100-MHz↔VM crossing. Choose the smallest integer divisor the redesigned
netlist supports with margin, rather than running full builds for every
divisor. Retiming adds beats: compare **beats × period**, not MHz alone.

Update RTL parameter, generated-clock XDC, and test `_VMDIV` together.
Exercise start/stop, key events, frame ticks, code uploads, ack holding,
fast raster completion, and sound-toggle delivery at the chosen ratio.
Related-domain boundary paths can still have a 10 ns budget. Faster JS
also invalidates the old empirical assumption that the next draw always
arrives after present: verify all draw fences and present ordering again.

### E. Target graphics/GC only to the measured remaining frame fraction

**External-memory traffic:** first retain separate recently used scanout
and raster BL8 lines, or another equally small bounded burst buffer.
Keep the shared 16-bit port and scanout priority. Avoid routing a 128-bit
bus through the VM. Caches must invalidate on overlapping writes, sprite
uploads, and RUN; snapshot changes must never reuse stale pixels.

For Pac-Man, investigate packing two indexed snapshot pixels per SRAM
word, updating GET and PUT together. It halves snapshot read transactions;
it does not halve total frame time. Check odd widths/offsets, partial rows,
zero pixels, clipping, and external-memory layout parity. True streaming
from retained BL8 data can then reduce per-word handshake overhead.

If fill/present bandwidth is still significant, a 32-bit BRAM draw port
with four byte enables is a later option. It can improve large fills and
copy reads without extra framebuffer copies. Verify actual BRAM mapping,
unaligned edges, masked transparent writes, and dump/read arbitration.
AMD's [UG901 memory inference guidance](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Memory-Inference-Capabilities)
supports byte enables; it does not guarantee this particular mapping.

**GC:** preserve forced collections and lifetime checks. If the array
element walk is dominant, consider one conservative sticky
`may_contain_reference` bit per array. Any reference write sets it; it
clears only at safe allocation/recycle. Unknown writers set it. Only arrays
proven to contain no references skip their element walk; the array itself
still participates in root marking, validity/generation, and sweep. Audit
every mutation path before enabling this. Do not repeat the unsafe
one-beat `S_V64_GC_ARR` walk that lost marks under stalls. Do not defer GC
merely to produce a better short benchmark.

The real bridge must retain independent command/data handshakes. AMD's
[UG586 command-path contract](https://docs.amd.com/r/en-US/ug586_7Series_MIS/Command-Path)
accepts commands only when `app_en` overlaps `app_rdy`; the past
sample-ready/enable-next-cycle race must not return during burst changes.

## 4. How the gains can combine — without multiplying incompatible claims

For planning, partition baseline elapsed time into a VM fraction `f` and
remaining graphics/memory time. If VM work falls by `r`, VM clock improves
by `c`, and the remaining fraction improves by `g`, an illustrative model is:

`speedup = 1 / (f/(r*c) + (1-f)/g)`

This is a scenario model, not a measured partition. Actual overlapping
engines/fences must be evaluated from elapsed frame traces.

| Conditional case | Inputs | Whole-frame result |
| --- | --- | ---: |
| Lower objective | 80% VM; 2.5× fewer VM beats; ÷7→÷4; remaining time 2× faster | **3.54×** |
| Upper objective | 80% VM; 3× fewer VM beats; ÷7→÷3; remaining time 2.5× faster | **5.15×** |

If graphics/memory is a larger fraction, prioritize E sooner. If source
changes already reach 3× at ÷7, preserve that routing margin and avoid
unnecessary clock work. If source edits are excluded from a future CPU-only
comparison, measure that comparison independently; the present evidence
does not establish 3–5× from RTL changes alone.

## 5. Fit and routing controls for every RTL candidate

These are **proposed campaign budgets**, not FPGA maxima or measured new
usage. Confirm them against the retrieved run-71c checkpoint:

| Resource / result | Working gate |
| --- | --- |
| BRAM | Prefer unchanged; initial changes **≤ +2 tiles**, total ≤355.5/365 |
| LUTs | Initial total **≤95k**, roughly +4.6k over recorded baseline |
| Occupied slices | Target **≤85%**; reject a local congestion regression even below that |
| DSPs | Budget a small shared unit, initially **≤ +8 DSPs**; verify actual inference |
| Timing | No setup/hold violations, no unconstrained functional paths; seek ≥0.25 ns overall setup margin and useful intra-VM margin |
| Router | No new level-6-or-higher hotspot; compare level-5 windows, direction, and local BRAM pressure against baseline |
| Runtime | Target baseline-like implementation time, roughly 10–25 minutes once project/IP exist; investigate at 30 minutes, terminate an unproductive route around 45 minutes after preserving completed checkpoints |

Add explicit **stop-after-synth / stop-after-place** modes and gates to the
build script before this campaign. Today's script goes from synthesis
straight to `write_bitstream`; post-route reports cannot prevent an
hours-long bad route. Check hierarchical utilization and RAM inference at
synthesis, then packing/congestion/timing at placement before routing.
Router-initial congestion is available only once routing has started;
inspect it at that point, not at placement. AMD's
[UG906 congestion guidance](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Router-Initial-Congestion-Reporting)
supports examining the affected regions/modules and treating higher
congestion as a routing/timing risk.

One RTL feature per candidate; simulation first; route only winners. Keep
two synth threads and bounded implementation threads. Preserve MIG/project
setup, use full synthesis while RTL changes, and reserve `bit-fresh` for
actual file-list/IP/XDC project changes. Archive uniquely named DCPs,
reports, source/constraint hashes, and step durations; never compare stale
checkpoints or overwrite the last known-good bit. Permit at most one
bounded placement retry from the same optimized checkpoint when evidence
points to placement; do not seed-shop against deep logic.

Keep one JS heap, registered SRAM reads, legal consolidated writers,
generation checks, existing heap caps and draw BRAM. No hidden conventional
CPU, host runtime, game-name gates, pathfinding engine, reduced art,
resolution cuts, or heap growth. Free capacity is a routing reserve, not a
target to consume.

## 6. Acceptance and first deliverable

The first implementation deliverable should be **the baseline replay and
the two source-only loop reductions**, with before/after ProgramImages,
code/heap budgets, framebuffer checks, and cycle histograms. It is the
lowest routing-risk way to test the largest new workload findings.

Then select the smallest CPU/memory patch justified by those histograms.
Use the existing immediate-result FP, stack-window-depth, engine ordering,
exact scaled-blit, generation/closure, code-reload/prefetch, and console
gates where affected. Add focused tests for new cache invalidation or GC
metadata behavior. Follow serialized Python model → actual RTL simulation
→ visual review → board. A model pass is not a board-FPS result.

Accept the final system only when both games show **≥3× lower median and
p95 active frame time** on the same board/input replays, with **≥30 rendered
frames/s during sustained play** as the initial usability floor and 60 FPS
where attainable. Report absolute FPS and p99/max stalls as well as the
ratio; include late pellet depletion and dense barrels so an improved
average cannot hide unplayable spikes. Demonstrate correct motion, input,
sprites, backgrounds, score, death/restart, level changes, and long-run
heap stability. Publish the new bit only after the physical and runtime
gates pass. The 5× objective remains a measured stretch result, not a
prerequisite to take a stable, playable 3× improvement.
