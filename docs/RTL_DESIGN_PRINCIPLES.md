# RTL design principles — write it right the first time

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**What this is.** Every other RTL doc in this repo is *reactive* — a NEVER
table, a bug ledger, a fit campaign diary. Each entry exists because
something already went wrong. This page is the *proactive* inverse: the
same hard-won knowledge, reorganized as guidance you can read **before**
writing a line of RTL, on this chip or a completely different one.

**Why it exists.** The 2026-08-21→25 fit campaign took ~30 synthesis
cycles to get from 1.9M LUTs to a placing design. A large fraction of
those cycles were spent rediscovering the same handful of structural
mistakes. Most of them were avoidable with upfront guidance rather than
measurement-and-repair.

**Scope.** Chip-agnostic where possible. T200/Vivado-specific numbers and
caps live in [FPGA_FIT.md](FPGA_FIT.md); incident history lives in
[potential bugs.md](potential%20bugs.md); the always-on agent laws live in
`.cursor/rules/`. This page does not restate those — it generalizes them.

---

## 1. Design for part count (area)

### 1.1 Where an array lives is decided by HOW you write it, not by what you ask for

This is the single most expensive lesson of the campaign, learned at least
five separate times (`name_has`, `vstack`, `spr_mem`, the name/fill family,
the "four refusers").

An `(* ram_style = "block" *)` attribute is a **request, not a command**.
The synthesizer honors it only if the code shape can actually support that
implementation. If it can't, it silently builds something far more
expensive — usually flip-flops — and **your tests still pass**, because the
behavior is identical. Only the area report tells you.

**Write it this way from the start:**

```systemverilog
// One dedicated process. One write port. Registered read.
always_ff @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
    rdata <= mem[raddr];       // raddr is a scalar wire
end
```

The big FSM only sets `we` / `waddr` / `wdata` strobes. It never touches
`mem[...]` directly.

**Rules that follow:**
- **Never write `array[i] <= x` inside a large FSM `always_ff`.** That
  single pattern forces flip-flops and, on a big enough array, can cause a
  multi-hour synthesis hang.
- **One write statement, not several.** Three separate conditional writes
  to the same array in one process is unprovable-as-single-port, so RAM
  inference fails. Merge to one prioritized write with muxed
  address/data/enable.
- **Keep the read in the same dedicated process as the write.** Moving only
  the write out is sometimes not enough — the inference template wants
  both together.
- **Verify from the synthesis mapping report, never from the source or the
  attribute.** "It has the attribute and the tests pass" is not evidence.

### 1.2 Wide N-to-1 funnels are the most expensive shape you can build

When many operations converge on one destination register, the select
logic deciding "which result wins this cycle" grows with the number of
sources *and* the data width. In this design that single structure
(`vst_wdata`, every opcode's result funneling to the stack write) measured
**~34k LUTs** — larger than any array.

**Design for it upfront:** tier the sources. A small hot set gets the fast
direct path; everything else shares a narrower, multi-cycle path. Doing
this from the start is cheap; retrofitting it into a mature decoder is a
multi-day restructure.

### 1.3 Sequential beats parallel, almost every time

Every "do it all at once" structure converted to "do it over several
cycles, reusing small hardware" in this campaign got **dramatically
smaller**: metadata evacuation ~175k LUTs, listener consolidation ~24k,
`linebuf` 3× its estimate.

A parallel structure needs hardware sized for the whole job simultaneously.
A sequential one needs hardware for a single step, used repeatedly. Unless
the operation is genuinely in a per-cycle hot path, prefer sequential.

**Corollary:** a `for` loop in synthesizable RTL is **not** a loop. It fully
unrolls into parallel hardware. `for (int t = 0; t < 16; t++) arr[t] <= x;`
builds sixteen simultaneous write ports, not sixteen sequential writes.

### 1.4 Congestion is a third axis — sharing trades area for local wire density

Section 1.3 said sequential beats parallel, almost every time, for area.
That is still true. But collapsing many parallel structures into one
shared, reused structure does not delete the connections those structures
had — it funnels them through one physical hub instead. **You traded LUT
count for local wire density**, and that trade is invisible in every
utilization report, because utilization is a global percentage and
congestion is local.

Measured on this design: 84.25% global LUT utilization — comfortable —
alongside two placement windows at **113% and 109% congestion**, each
built almost entirely (98–99%) from one module and its heaviest
substructure. Both windows also showed **100% local BRAM demand**. The
same consolidation that shrank the design (§1.1, §1.3) concentrated many
formerly-separate connections onto the handful of shared structures that
replaced them.

**Check `report_design_analysis -congestion` after any large
consolidation refactor, not just `report_utilization`.** A comfortable
global percentage guarantees nothing about local routability. Do this
especially after: collapsing N parallel paths into one reused structure,
converting several arrays to `ram_style="block"`, or building a wide N-to-1
funnel (§1.2 below) — all three concentrate wires by design.

**A useful diagnostic:** if a region fails timing badly *and* the same
region shows up as a congestion hotspot, suspect one root cause, not two.
An over-tight timing target forces the placer to pack a region as densely
as physically possible while still failing to meet it — that packing
pressure is what a congestion report is measuring. Relaxing the timing
target for that region (a slower clock domain, §2.9) often relieves both
symptoms together, because it removes the pressure causing the packing,
not just the timing number.

### 1.5 Do not hand-roll the same operation twice

The campaign found "find the highest set bit" hand-written **four to five
separate times** at different widths, plus multiple ad-hoc RAM write
patterns. Each copy is separate silicon, and each is a separate place a
subtle bug can hide.

Write one width-parameterized implementation, prove it once, call it
everywhere. Cheaper in area *and* in correctness risk.

### 1.6 Know which resource pool you are actually consuming

Utilization percentages can hide a shortage. LUT-as-memory looked
comfortable at 26% of its cap while placement failed repeatedly — because
distributed RAM draws from **SLICEM** slices specifically, a scarcer pool
than "any slice."

Track the constrained sub-resource, not the headline number. On this
family: total LUTs, LUT-as-logic, LUT-as-memory, SLICEM, BRAM tiles, and
DSPs are six separate budgets.

---

## 2. Design for speed (timing)

### 2.1 The one pattern that will destroy your timing

A loop where each iteration's **test depends on a value the previous
iteration computed** cannot be parallelized. It synthesizes as a genuine
serial chain, one level per iteration.

```systemverilog
// CATASTROPHIC — 52 serial levels. Each test needs the prior shift.
for (int k = 0; k < 52; k++)
    if (!work[52]) begin work = work << 1; count = count + 1; end
```

```systemverilog
// FINE — each iteration tests a fixed bit of an unchanging input.
// Synthesizes as a log-depth priority encoder.
for (int k = 0; k < 106; k++)
    if (product[k]) p = k;
```

```systemverilog
// FINE — associative reduction, tools reassociate into a tree.
for (int k = 0; k < 56; k++)
    if (k < shift) sticky = sticky | value[k];
```

**Learn to tell these apart.** The distinction is whether iteration *k*'s
behavior depends on iteration *k-1*'s **computed result**, or only on the
original inputs. This session initially confused the safe forms for the
dangerous one; the difference is worth internalizing.

**When you need one:** use the standard log-depth structure instead —
a leading-zero-counter / priority encoder plus a single barrel shift
(~6 levels for 53 bits, versus 52). It is faster *and* smaller.

### 2.2 Depth and area are different axes — do not infer one from the other

A 477-level carry chain was catastrophic for timing (-250 ns) yet cost
almost nothing in LUTs, because carry chains use dedicated fast-carry
resources. Removing it improved timing enormously while barely moving the
LUT count.

Conversely, a huge array can be timing-innocent. **Measure both
separately.** Never assume "smaller" means "faster" or vice versa.

### 2.3 Delay is logic + route, and route is often the larger half

A real measurement from this campaign: `logic 141.4 ns (47.6%) /
route 155.8 ns (52.4%)`.

- **Logic delay** is structural — how many gates in series. Only RTL
  changes fix it. No routing strategy shortens a 465-level chain.
- **Route delay** depends on physical placement and the router's choices.
  Different seeds and directives genuinely produce different results.

**Practical consequence:** when the gap is large (hundreds of ns), only
RTL changes can close it. When the gap is small (tens of ns), trying
alternate placement seeds and route directives is a cheap, legitimate
lever — and re-routing an existing checkpoint costs minutes, not hours,
because synthesis and placement do not need repeating.

**But do not over-read the route half.** Measured on this design at two
points five-fold apart in magnitude — a −287 ns path (logic 47.6 % /
route 52.4 %) and a −58.7 ns routed path (logic 48.5 % / route 51.5 %) —
**the ratio barely moved.** Route delay was tracking *depth*, not bad
placement: more logic levels means more hops means more wire. The two
halves shrank together because they had one cause. Treat a stable
logic/route ratio across fixes as evidence that depth is still the only
lever, and that seed-chasing will not pay.

### 2.4 Verify what the tool actually built

An area-optimizing directive flattened a wide multiply into a long serial
ripple chain instead of using available DSP blocks — 582 of them sat idle
while the design missed timing by 25×.

Check actual logic-level depth with `report_timing` on the real critical
path. Do not assume the tool made a sensible structural choice.

### 2.5 Census arithmetic operators before anything else

Two combinational 32-bit divides, sitting in one `always_comb` feeding a
register, were the root cause of the worst path — and were found only at
cycle ~31. A 32-bit combinational divide is a ~32-row restoring array; it
is one of the deepest structures you can write by accident, and it looks
like one short line of ordinary arithmetic.

**On day one, grep for `/` and `*` that are not inside a registered
stage.** It costs minutes. Division especially: if a divide is not
explicitly sequential, assume it is a disaster until measured.

Watch for the inner-loop version of this: a value that changes once per
*row* being recomputed once per *pixel*. Hoisting beats pipelining.

### 2.6 When many endpoints fail together, fix the cone, not the path

If several endpoint families fail at nearly the same slack, they usually
share an upstream cone. Fixing the specific endpoint the report named
relieves *that* endpoint and moves the wall one register downstream, for
almost no gain — this happened here: a correct, well-tested fix to the
worst path recovered ~1 ns of ~58, because the shared arithmetic cone
behind it was untouched.

**Diagnose by tracing the fanin cone (`all_fanin`) and intersecting across
several failing endpoints**, not by reading the single worst path. And
never diagnose from cell names — Vivado's auto-generated `_i_N` names
borrow from nearby registers and will send you somewhere else entirely.

### 2.7 The worst path is a poor guide when the tail is dense

Check the *distribution* before planning work. Here, 300 routed paths
spanned −58.7 to −40.2 ns across ~40 endpoint families, with **zero**
shared cells among the top five. Fixing path #1 gained 0.003 ns.

A dense plateau means only whole-class fixes register, and it caps what
any single change can deliver — worth knowing before promising a number.

### 2.8 An area refactor can silently build a timing wall

Flattening arithmetic out of a `case` to save the mux removes the select
logic but *exposes the arithmetic* to a longer path. The area report shows
the win and says nothing about the loss.

Any refactor that moves computation out of a conditional should be
re-timed, not just re-measured for area.

### 2.9 A divided-clock core domain is a permanent architecture choice, not a stopgap

When one module is structurally deep (a CPU core) and everything around
it is timing-critical for other reasons (DRAM controller, video scanout),
give the deep module its own generated clock — a counter-driven BUFGCE
enable, not an MMCM output — and keep everything else on the fast clock.

**Make the divisor a build parameter with a zero-cost passthrough at 1.**
Then this is never a workaround to unwind later: it costs nothing when
the core is fast enough to need no division, and it is a real safety
valve on every day it is not. Do not remove the mechanism once a design
"catches up" to full rate.

**Pick the divisor by measuring, not by halving.** A counter-based divider
supports any integer ratio, not just powers of two. Halve-until-it-passes
is a guess dressed as a plan. The actual process: fix one structural
bottleneck, re-measure the real worst-path delay on the new checkpoint,
set the divisor to the smallest value with genuine margin, confirm by
resynthesizing. Different bottlenecks clear at different divisors — the
next wall after removing one structure is very often a *different*
structure entirely, so a milestone "the fix in hand" buys is rarely the
milestone you were aiming for. Measure after every fix, not just at the
end.

### 2.10 A ~95%-route path with 2 logic levels means you are out of room, not out of ideas

Section 2.3 says a stable logic/route ratio means depth is the lever. The
inverse case is just as diagnostic, and it demands the opposite response.

Measured on run 35: worst path **logic 0.704 ns (5.8%) / route 11.538 ns
(94.2%)**, at **2 logic levels**, with a 93.9% route median across the 60
worst paths. Compare the earlier walls, all roughly half-and-half:
−287 ns at 47.6% logic, −58.7 ns at 48.5%.

**When logic levels are tiny and route is ~95%, there is no RTL fix.** You
cannot simplify a 2-level path. The signal has almost nothing to do; it is
spending its whole budget in transit because the router sent it on a
detour. The cause is physical space, and the levers are: remove logic from
the congested *region* (not from the failing path — they are usually
different modules), or move the region.

**The tell that confirms it:** the failing endpoints are often in *simple,
innocent* modules. Run 35's worst paths were in the rectangle demo engine
— some of the least complex logic on the chip — because it got evicted to
the far side of the die when the router shoved everything apart to escape
a 104% congestion window. Innocent logic failing badly is a space
symptom, never a design symptom.

**Corollary — a routed design is not a working design.** Run 35 reached
0 overlaps and "route_design completed successfully" while WNS went
−0.640 → **−2.735** and TNS −12.8 → **−2,058.7** against the previous run.
The router will trade unlimited timing for legality, and it says so
(`[Route 35-447] the router will prioritize the successful completion of
routing all nets over timing optimizations`). Treat that warning as a
prediction, not a note.

### 2.11 Anything replaced by a behavioral model in simulation is untested

The DDR3 bridge carried three composed defects — a UG586 handshake race
(`app_en` registered one cycle after sampling `app_rdy`, so a refresh
window silently dropped commands), no timeout on the read-wait state, and
a burst-splitting address map. It survived ~35 build cycles and a
183-test suite because **simulation never ran it**: the suite builds with
`SRAM_INTERNAL=1` and a one-cycle behavioral memory that hides both the
protocol and the latency.

One dropped read wedged the arbiter permanently, which presented as a
black screen with a perfect text console — because the text engine was
the one display path that never touched that memory.

**Rules:**
- Enumerate every module the test suite replaces with a model. That list
  is your untested surface, and it is invisible in coverage numbers.
- **Vendor-IP handshakes are the highest-risk instance.** Re-read the
  protocol spec against the RTL by hand; "enable must overlap ready in
  the same cycle" is the exact class of detail a behavioral model erases.
- Every wait-on-external-response state needs a timeout. The SD layer
  above this bridge was fully guarded and still froze, because the stall
  was one layer *below* its timeouts.
- This was the fourth "the tests pass" failure of the campaign, after RAM
  inference, `vst_win`, and the multi-cycle conversions ([§4.2](#42-a-broad-passing-suite-is-not-evidence-for-a-structural-change)).

### 2.12 Timing failure is a correctness problem, not an electrical one

A bitstream that misses timing will not damage hardware. It will produce
metastable, unpredictable behavior — hangs, garbage, different results
each power cycle. Safe to load, useless to trust. Diagnose from the
number, not from board behavior.

---

## 3. Hand-rolling vs. templates vs. sharing

### 3.1 Establish canonical templates on day one

Pick one reference implementation for each recurring shape, and copy it
rather than reinventing:
- **Port-A RAM** — the write/read process in §1.1.
- **Leading-bit finder** — one width-parameterized version.
- **Multi-beat handshake** — one hold-and-serve pattern (`busy` / `done`,
  requester holds state until complete).

Retrofitting a template across a mature codebase costs far more than
adopting it early. Most of the fit campaign was exactly this retrofit.

### 3.2 Share the structure, never share the state

There is a real distinction the campaign had to discover:

- **Sharing an implementation** (one leading-bit-finder function called
  from five sites) is good — less area, fewer bug surfaces.
- **Duplicating live state** (a submodule owning its own copy of a heap
  array) is catastrophic — it goes stale, and it will not fit.

Submodules should own **no arrays**. They reach shared state through
scalar address/data/enable ports with registered reads.

### 3.3 Scratch registers need exactly one owner

Reusing scratch registers (`*_arm`, cursors, temporaries) across unrelated
states is described in the bug ledger as *"the expensive one."* A state
that interrupts a multi-beat walk silently destroys its cursor. Symptoms
depend on what happened in a *previous frame*, which makes them
extraordinarily hard to debug.

Give every multi-beat operation its own registers, or a formal
save/restore. Do not share by convenience.

---

## 4. Correctness disciplines that saved (and cost) the most

### 4.1 Multi-cycle conversions need purpose-built early-read tests

Converting a same-cycle operation to multi-cycle is the highest-risk
routine change in this codebase. If any consumer still assumes the result
is available immediately, it reads a stale value — **and produces a wrong
answer with no fault, no crash, and a fully green broad test suite.**

This class hid a real bug twice. It was caught only by a purpose-built
test targeting the specific failure mode.

**Before any sequentialization: write the gate test first**, covering the
result being consumed by the immediately-next operation in *every* consumer
position (store, compare, chained use, call argument), with exact expected
values. Prove it green on the *unmodified* tree first, so you know the test
itself is sound.

### 4.2 A broad passing suite is not evidence for a structural change

Repeatedly this session: build clean, all games clean, full bytecode suite
clean — and the change was still wrong (`vst_win`'s window shrink, silently
corrupting deep expression nesting) or silently ineffective (`ram_style`
attributes that never took).

Match the test to the failure mode of *this specific change*. General
coverage does not substitute.

### 4.3 Some parameters are language contracts, not tunables

Shrinking the operand window looked like a pure area/perf tradeoff. It was
not: window depth **bounds expression-nesting depth**, because pop-shifts
cannot refill from below the window. Shrinking it was a functionality loss
that only a depth-specific test caught.

Before treating any capacity parameter as tunable, establish what
user-visible contract it encodes.

### 4.4 Measure before you promise, and re-measure after

The campaign's projections were wrong repeatedly in both directions: a
−800k LUT estimate delivered −401k; a "not worth it" area estimate was
30× too high; a directive predicted to give 5–15% gave 34.7%.

Census the actual netlist before committing effort to a lever, and verify
the result afterward. Estimates from source reading are for *ranking*
candidates, never for deciding they are done.

### 4.5 A model that uses a different algorithm cannot validate yours

FM==RTL parity testing proves the two produce the same *answers* on the
cases you tried. It does not prove the RTL's **algorithm** is correct,
and when the model solves the problem a different way, an entire class of
bug becomes structurally invisible.

Measured case (bug #83): the RTL resolves a class method by **scanning a
table**; PYTHON's functional model resolves it from a **dict**. The RTL
scanner had a one-entry pipeline lag — after its priming beat it
re-issued an entry it had already read, so every later comparison
examined the wrong row, and **the last-declared method of any class with
three or more methods could never be found.** DONKEY drew platforms and
ladders but no player, Kong or barrels. PYTHON rendered it perfectly,
because a dict lookup has no index to get wrong.

That divergence cost hours: correct behaviour on the model made it look
like a board or timing problem.

**Rules:**
- **Write down where the model and the RTL use different algorithms.**
  Dict vs linear scan, sort vs insertion, hash vs compare-chain. Each is
  a place parity testing is blind.
- **Test the RTL's algorithm on its own terms**, not just its outputs:
  for a table scan that means first entry, last entry, a middle entry,
  and a full table — bug #83 needed exactly last-of-3, last-of-10 and
  last-of-16 to pin it.
- **Boundary indices are where scan pipelines fail.** A priming beat plus
  an off-by-one in re-issue is invisible everywhere except the last
  element.
- **When the model is right and the hardware is wrong, suspect an
  algorithm the model does not share** before suspecting timing or the
  board. This is the third class of "the tests pass" failure, after
  untested modules (§2.11) and shape-dependent inference (§1.1).

### 4.6 Trust artifacts, not reports of artifacts

Multiple times a number was believed, restated, and acted on before any
file on disk contained it. Reports also go stale: a hierarchy report three
runs old caused a multi-day refactor plan to be recommended for a problem
that had already been solved.

Check the timestamp inside the report. Re-generate before deciding.

---

## 5. Process rules that shortened the loop

- **One variable per experiment.** When two changes land in the same run,
  attribution is lost. Deliberately freezing one run's sources as a clean
  baseline is what identified the FP-add chain unambiguously.
- **Prepare the next fix while the current run bakes.** Synthesis is hours;
  design work is not blocked by it. Insurance work costs nothing if unused.
- **A long-running tool that is silent is not necessarily stuck.** Watch
  resident memory and CPU, not log output. Rising memory with no phase
  transition is pathological; steady memory at full CPU is working.
- **Kill only on evidence.** A stalled optimizer and a slow one look
  identical from outside; distinguish by I/O volume and memory trend.
- **Progress messages describe hope, not outcome.** Only the exit status is
  a result.

---

## Related

- [FPGA_FIT.md](FPGA_FIT.md) — this chip's numbers, caps, NEVER table, live scoreboard
- [TIMING_WALL.md](TIMING_WALL.md) — the measured case study behind §2.3 and §2.5–2.8
- [potential bugs.md](potential%20bugs.md) — incident history and the recurring bug-class taxonomy
- [ARCHITECTURE.md](ARCHITECTURE.md) — what each block is and where it lives
- [CONSTITUTION.md](../CONSTITUTION.md) — what the machine is; wins on conflict
- `.cursor/rules/` — always-on agent laws (copy 1 of the critical prohibitions)
