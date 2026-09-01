# The timing wall — measured, run 30 (routed) and run 31 (placed)

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**What this is.** An independent measurement pass over the two checkpoints
on disk, done to answer one question — *can we still split logic vs. route
delay for the −58.7 ns path if routing failed?* — and to find what comes
next. Method: read-only `open_checkpoint` on copies, `report_timing`,
`all_fanin` cone tracing. Live runs untouched.

**Headline.** The −58.7 ns number is real and routed, its breakdown is
below, and the fix already applied to it moved the wall rather than
removing it. Both of the two worst path families share one root cause:
**two combinational divides** at
[jmr_js_vm.sv:1622](../rtl/engines/jmr_js_vm.sv#L1622).

---

## 1. Yes, the breakdown was obtainable — and it is better than estimated

Routing failing does **not** block this analysis. `post_phys_opt.dcp` is
written *before* `route_design` runs, so a route failure never touches it.
Better still, run 30 **did** route, and `post_route.dcp` (00:06) survived —
so the −58.7 ns number is not an estimate at all:

| Run 30 worst path — **actually routed** | |
|---|---|
| Slack | **−58.737 ns** |
| Endpoint | `u_core/u_vm/fb_waddr_reg[7]/CE` |
| Data path delay | 68.267 ns |
| **Logic** | **33.094 ns (48.5 %)** |
| **Route** | **35.173 ns (51.5 %)** |
| Logic levels | 100 — CARRY4=72, DSP48E1=2, LUT3=18, LUT6=6 |

Compare with the original −287 ns path: logic 47.6 % / route 52.4 %.
The magnitude fell ~5×; **the ratio did not move.**

That is the most useful single observation here. Route delay is not
tracking bad placement — it is tracking *depth*. More logic levels means
more hops means more route. The two halves shrink together because they
have the same cause. **Depth is the only real lever; seed-chasing is not.**

## 2. The two next slowdowns

| Family | Routed slack | Levels | Logic / route | Source |
|---|---|---|---|---|
| `sram_addr` | −57.524 | 101 (CARRY4=74) | 50.6 % / 49.4 % | `pix8` DSP |
| `vst_wdata` (vm) | −53.995 | 91 (CARRY4=44) | 39.9 % / 60.1 % | `vframe_no` |
| `vst_wdata` (exec64) | −53.404 | 98 (CARRY4=33) | 29.2 % / 70.8 % | `vsp` |
| `vtimer_due_wdata_q` | −52.583 | 80 (CARRY4=43) | 37.3 % / 62.7 % | `code_mem` |

`sram_addr` is **the same cone** as `fb_waddr` — same divides, different
endpoint. The `vst_wdata` pair is the known funnel, and it is
route-dominated (60–71 %), consistent with a wide fan-in select rather
than a deep chain.

## 3. Root cause, confirmed structurally

The fanin startpoints of `sram_addr_reg[17]` are exactly
`blit_sx/sy/sw/sh`, `rw`, `rh`, `spr_ww` (256 bits), `spr_off`, `blit_si` —
a one-to-one match with the `always_comb` at
[jmr_js_vm.sv:1620](../rtl/engines/jmr_js_vm.sv#L1620). Verified by cone
tracing, not by cell names (Vivado's `_i_N` names are unreliable evidence).

That block computes, combinationally, in one cycle:

```systemverilog
sx = blit_sx + 16'((32'(x) * 32'(blit_sw)) / 32'(rw));   // divide
sy = blit_sy + 16'((32'(y) * 32'(blit_sh)) / 32'(rh));   // divide
spr_so = spr_off[blit_si] + 22'(sy) * 22'(spr_ww[blit_si]) + 22'(sx);
```

**These are the only two combinational divides in the VM.** A 32-bit
combinational divide is a ~32-row restoring array — that is the CARRY4=72
chain. The cone holds 2,024 CARRY4, 228 DSP48E1, 3,086 LUTs.

The block comment says the divides were *deliberately hoisted here* to
flatten `spr_off`/`spr_ww` out of a unique case. That was an **area** fix
that bought a timing wall.

## 4. What we should learn from finding this so late

- **The applied fix targeted the endpoint, not the source.** Commit
  `98826be` correctly moved the multiply and bounds compare off the put
  beat. But `spr_so[0]` still selects `pix` at
  [8661](../rtl/engines/jmr_js_vm.sv#L8661), and `pix != 0` still gates
  `fb_we`. The divide cone stayed in the CE path, and `spr_so` still feeds
  `sram_addr` directly. Result: the wall moved from `fb_waddr` to
  `sram_addr` and lost ~1 ns of its ~58. **When several endpoints fail
  together, fix the shared cone, not the reported path.**
- **The worst path is a poor guide when the tail is dense.** 300 routed
  paths span −58.7 to −40.2, across ~40 endpoint families with *zero*
  shared cells among the top five. Fixing path #1 gains 0.003 ns. Only
  whole-class fixes register.
- **An area refactor can silently create a timing wall.** Flattening logic
  out of a case statement removes the mux but exposes the arithmetic.
  Nothing in the area report shows this.
- **We should have censused arithmetic operators early.** Two greps —
  combinational `/` and `*` outside a registered stage — would have found
  this in minutes, at any point in the last 30 cycles.

## 5. Where this actually leaves the clock

Slack scales one-for-one with period, so the measured numbers give:

| | Routed (run 30) | Placed est. (run 31) |
|---|---|---|
| WNS @ 100 MHz | −58.737 ns | −46.261 ns |
| Min period | 68.74 ns | 56.26 ns |
| **Max clock** | **≈ 14.5 MHz** | ≈ 17.8 MHz (optimistic) |

**50 MHz is not within reach of the current RTL.** At 20 ns the routed WNS
would still be −48.7 ns. Note also that run 31's −46.3 is a *pre-route
estimate* and run 30's −58.7 is *routed*; they are not comparable, and
routed numbers here came in worse than placed ones.

Also: **no `.bit` exists for `nexys_video`.** Run 30 routed but no
bitstream was written.

## 6. Should we prepare these fixes now and hold them?

**Yes — prepare, do not queue.** Rationale:

- Run 31 is a route-directive retry on an unchanged netlist. It cannot
  improve on ~−46 ns; it can only decide whether that netlist routes. Its
  outcome does not change any of the work below, so preparing in parallel
  costs a run of nothing.
- Even a complete win on the divide cone only moves WNS from −58.7 to
  about **−54.0** (the next wall, `vst_wdata`). That is ~10 % of the gap to
  50 MHz. Worth knowing *before* anyone spends a cycle expecting more.

Prepared in priority order, held until run 31 reports:

1. **Sequentialize the two divides** (biggest, and it cuts area too). The
   design already owns a registered restoring divider (`div_uq`, 48
   cycles). `sx`/`sy` change once per blit *row*, not per pixel — so this
   is a hoist out of the inner loop, not just a pipeline. Should remove
   most of 2,024 CARRY4 as well.
2. **Register `spr_so` / `spr_raddr`.** `x`/`y` are stable across the
   blit's req/ack wait — the same argument `98826be` already used for
   `blit_waddr_q`. Cheap, low risk, and it cuts the cone from *both*
   `sram_addr` and the `fb_we` CE.
3. **Investigate multicycle constraints for the handshake families.**
   Several failing endpoints are computed at REQ and consumed at ACK,
   several cycles later. A *justified* `set_multicycle_path` costs zero
   area and zero RTL risk. Must be proven from the FSM, never assumed — an
   unjustified one is a silent correctness hazard.

Gate each with a purpose-built early-read test before the change, per
[RTL_DESIGN_PRINCIPLES.md §4.1](RTL_DESIGN_PRINCIPLES.md).

**The honest read:** these get us to roughly 15–18 MHz, not 50. Closing to
50 MHz means restructuring the `vst_wdata` funnel too, which is the
multi-day job. A ~15 MHz bitstream that runs is worth having first.

## 7. Clock strategy — slow the VM, not the board

**Do not lower the global clock.** Two measurements say so.

**(a) 25 MHz does not work; 12.5 MHz does.** Slack scales 1:1 with period,
so from the routed −58.737 ns at 10 ns:

| Core period | Clock | WNS | |
|---|---|---|---|
| 40 ns (÷4) | 25 MHz | **−28.74 ns** | fails |
| 70 ns (÷7) | 14.3 MHz | +1.26 ns | too tight |
| **80 ns (÷8)** | **12.5 MHz** | **+11.26 ns** | **passes** |
| 100 ns (÷10) | 10 MHz | +31.26 ns | passes, wide |

**(b) A global slowdown breaks video.** `core_clk` is the MIG's `ui_clk`
([top_nexys_video.sv:89](../rtl/top_nexys_video.sv#L89)) — tied to DDR3,
which cannot run at 12 MHz. And `jmr_fb_scanout` line-buffers on
`core_clk`: 320 SRAM fetches per video line, one line every 32 µs at the
25 MHz pixel clock — **one fetch per 100 ns**. At 100 MHz core that is 10
cycles per fetch. At 12.5 MHz it is 1.25, and at 25 MHz it is 2.5. Both
are impossible through a req/ack round trip. Scanout would fall behind and
the display would break.

**But the VM alone can be slowed, and that is sufficient.** Of the 6,000
worst failing paths on the routed checkpoint, **6,000 are wholly inside
`u_core/u_vm`** — start *and* end. Zero failing paths touch scanout, the
SRAM bridge, the console engine, HDMI or the MIG.

So: keep the board at 100 MHz; run `u_core/u_vm` at `ui_clk`÷8 = 12.5 MHz.
The XDC already anticipates the mechanism — *"Half-rate core = BUFGCE /2
with a real generated clock"*
([nexys_video.xdc:12](../constraints/nexys_video.xdc#L12)). The VM already
talks to the outside through req/ack handshakes, so the boundary is
already multi-cycle by construction; those crossing paths stay on the fast
clock and must still meet 10 ns, which they do today.

**Note this does not make the divide fixes redundant** — but it does cap
what they buy. Removing the whole divide cone moves the VM wall to ~−54 ns
(64 ns), which still needs ÷7. The divisor stays 8 either way. Their real
value is area (≈2,000 CARRY4) and headroom, not a better clock. Reaching
÷4 (25 MHz) needs the `vst_wdata` funnel restructure too.

**The non-VM logic has no real timing problem.** Worst path touching
nothing in the VM is −23.583 ns — but it is **1 logic level** (one LUT6):
logic 0.580 ns (1.8 %) / route 32.399 ns (98.2 %), from
`u_core/u_demo/fb_we_reg` to the framebuffer BRAM. That is pure placement
spread — the demo engine landed a die away from `u_fb` because the VM's
115 k LUTs squeezed everything else apart. It is not a structural failure
and it will close on any sane placement once the VM shrinks, or with a
pblock. Do not spend RTL effort on it.

**Run 30 is fully routed — 0 unrouted nets.** A bitstream can be written
from `post_route.dcp` in minutes. Bitstream generation was never the
blocker; correctness at 100 MHz was.

**Games run 8× slower at 12.5 MHz.** That is the honest cost, and a
working slow bitstream is still the first one we would have.

## 8. ÷8 boundary inventory (independent cross-check)

Every `jmr_js_vm` port, classified by what the ÷8 clock does to it. Two
opposite failure modes — and both are silent.

### Class A — fast→slow strobes the VM will *miss*

A 1-fast-cycle pulse is invisible to a clock that samples every 8th cycle.
**Each of these must be stretched to ≥8 fast cycles or converted to a
handshake.**

| Signal | Driver | Consequence if missed |
|---|---|---|
| `sram_ack` | [jmr_js_core.sv:411](../rtl/jmr_js_core.sv#L411) | **Deadlock** — VM holds `sram_req` forever. Highest priority. |
| `code_we` (burst) | [console:1740](../rtl/engines/jmr_console_engine.sv#L1740), 1816 | 7 of 8 program words lost → **corrupt program** |
| `frame_tick` | [jmr_js_core.sv:313](../rtl/jmr_js_core.sv#L313) — 1 cycle per ~1.67M | `startLoop`/rAF stalls or runs erratically |
| `key_evt_stb` | top-level PS/2 | dropped keystrokes |
| `stop` | [jmr_js_core.sv:330](../rtl/jmr_js_core.sv#L330) — `kbd_push && ESC` \| `halt_pulse` | ESC / halt ignored |
| `start` | [jmr_js_core.sv:329](../rtl/jmr_js_core.sv#L329) | VM may never start |

### Class B — slow→fast strobes that become 8 cycles *wide*

A 1-slow-cycle assertion is 8 fast cycles long. Fast consumers act eight
times. **Each must be edge-qualified in the fast domain.**

| Signal | Consumer | Consequence |
|---|---|---|
| `fb_swap` | [fb_present.sv:45,47](../rtl/engines/jmr_fb_present.sv#L45) — `if (swap && busy) swap_pend <= 1` | spurious second present / double flip |
| `fb_we` | `mini_fb` | 8 identical writes to one address — idempotent, low risk |
| `sram_req` | bridge | safe by handshake, **provided `sram_ack` is fixed** |

### Class C — safe as-is

`joy_in`, `fb_present_busy`, `busy`, `done`, `fb_dump_sel/addr`,
`sram_addr/we/wdata`, `key_evt_code/down`, `code_waddr/wdata` — levels, or
data qualified by a strobe already listed above. `fb_dump_back`'s
"registered one cycle after `fb_dump_addr`" assumption
([jmr_js_vm.sv:10047](../rtl/engines/jmr_js_vm.sv#L10047)) gains slack
under ÷8, it does not lose it.

### Two structural fixes that beat stretching

1. **`code_mem_c0`/`c1` should become a true dual-clock BRAM.** Today read
   and write share one process on `clk`
   ([jmr_js_vm.sv:125–132](../rtl/engines/jmr_js_vm.sv#L125)). Block RAM
   supports independent clocks per port natively — write port on the fast
   clock, read port on the slow one. That removes the code-load hazard
   outright instead of handshaking it, at zero cost. Keep the single-write
   / co-located-read shape or RAM inference will drop
   ([§1.1](RTL_DESIGN_PRINCIPLES.md)).
2. **`mini_fb` already has a separate `wr_clk` port**
   ([jmr_mini_fb.sv:16](../rtl/engines/jmr_mini_fb.sv#L16)). Drive it from
   the slow VM clock and `fb_we`/`fb_waddr`/`fb_wdata` need no treatment
   at all.

## 9. Roadmap past ÷8 — measured, not staged by powers of two

**Do not preset a ÷8 → ÷4 → ÷2 staircase.** The divider
([jmr_js_core.sv:341](../rtl/jmr_js_core.sv#L341)) is a plain counter
compared against `VM_CLK_DIV-1` — it supports **any integer divisor**, not
just powers of two, and `VM_CLK_DIV==1` already collapses to a zero-cost
passthrough (`g_vmclk_pass`). There is no reason to round to 4 or 2
specifically; there is every reason to pick the smallest divisor the
*measured* post-fix worst path actually supports.

Projected margin at each divisor, from run 30's routed intra-VM families:

| Divisor | Period | `fb_waddr`/`sram_addr` (pre-fix, −68/−67ns paths) | `vst_wdata` (unrelated to divides, −63.5/63.8ns paths) |
|---|---|---|---|
| ÷4 | 40 ns | −28 ns | **−24 ns** |
| ÷6 | 60 ns | −8 ns | **−4 ns** |
| ÷7 | 70 ns | +2 ns | **+6 ns** |
| ÷8 | 80 ns | +12 ns | +16 ns |

The staged divide fix ([§7 lever 1](#6-should-we-prepare-these-fixes-now-and-hold-them))
removes the `fb_waddr`/`sram_addr` column entirely — but `vst_wdata` is a
**different structure** (the N-to-1 funnel, [RTL_DESIGN_PRINCIPLES
§1.2](RTL_DESIGN_PRINCIPLES.md)) and is untouched by it. That makes **÷7
the honest next milestone once the divide fix lands** — it comes free,
no new work. ÷6 is marginal (−4 ns, may close with route variance alone).
÷4 needs the funnel restructure regardless of anything else — treat it as
a separate project, not a smaller step.

**Process for any future push:** fix one structural bottleneck → open the
new checkpoint and re-measure the actual worst-path delay → set
`VM_CLK_DIV` to the smallest value with real margin → re-synthesize to
confirm. Never set the divisor from a projection alone
([§4.4](RTL_DESIGN_PRINCIPLES.md)).

## 10. Run 31's failure was congestion, not a seed — measured, same root cause

Both the default router and an `Explore` retry failed run 31's route at
identically 3,865 node overlaps. Same number twice means the placement was
congestion-infeasible, not seed-unlucky — confirmed by opening the exact
`post_phys_opt.dcp` both attempts routed
(`report_design_analysis -congestion`):

| Window | Congestion | RAMB (local) | Composition |
|---|---|---|---|
| East | 113% | 100% | `u_vm` 60% + `u_vm/u_exec64` 39% |
| West | 109% | 100% | `u_vm` 60% + `u_vm/u_exec64` 38% |

Global utilization was 84.25% — comfortable. The congestion is entirely
local, and entirely inside the same module that owns every failing timing
path. See [RTL_DESIGN_PRINCIPLES §1.4](RTL_DESIGN_PRINCIPLES.md) — this is
the visible cost of the consolidation that got the design to fit at all.

**Read on run 32:** the same over-tight timing target that produces the
timing wall is also very likely what forced this packing — the placer
squeezing `u_vm` as dense as physically possible while still failing to
hit 10 ns. Run 32's 80 ns VM budget removes that pressure. Expect
congestion to ease along with timing, not as two separate fixes — but
this is a prediction pending a real `report_design_analysis -congestion`
on run 32's own placement, which I will check the moment it reaches
place/phys_opt.

## 11. Run 35 — routed, and worse for it (the congestion tax, measured)

Run 35 carried the DDR3 bridge fix, `u_stor` LBA splits, the storage
watchdog, console parse pipe, CCS and `ds_guard`. It **routed
successfully** — 0 overlaps after 4h35m — and came out far worse than the
run it replaced:

| | Run 33 | **Run 35** |
|---|---|---|
| WNS | −0.640 | **−2.735** |
| TNS | −12.8 | **−2,058.7** |
| WHS (hold) | +0.051 | **−0.147** |
| Route time | ~40 min | **4h 35m** |

**Cause: the router bought legality with wire.** Its own opening warning
was the prediction — *"congestion is preventing the router from routing
all nets; the router will prioritize the successful completion of routing
all nets over timing optimizations."* Run 35's placement carried a **104%
congestion window** (East, `u_exec64` 60% + `u_vm` 38%, RAMB and DSP both
100% locally) where run 33's placement had **no window above level 5** —
on identical BRAM (343.5, 94.11%), identical DSPs (141), +399 LUTs.

**The delay split proves it is space, not structure:**

| Path | Logic | Route | Levels |
|---|---|---|---|
| −287 ns (original wall) | 47.6% | 52.4% | 465 |
| −58.7 ns (blit divides) | 48.5% | 51.5% | 100 |
| **Run 35 (−2.735)** | **5.8% (0.704 ns)** | **94.2% (11.538 ns)** | **2** |

Route median across the 60 worst paths: **93.9%**. And the worst
endpoints are `u_core/u_demo` — the rectangle demo, among the simplest
logic on the chip — evicted across the die when the router spread
everything to escape the window. See [RTL_DESIGN_PRINCIPLES
§2.10](RTL_DESIGN_PRINCIPLES.md).

**Consequence:** no RTL change can fix a 2-level path. These endpoints
need only 0.704 ns of logic against a 10 ns budget — they close the
instant the wire is short. The fix is room in the window, which is what
run 36's blit-DDA provides (~2k CARRY4 removed from that region's
dominant occupant).

**Also retired:** the `AltSpreadLogic_high` contingency placement
(WNS −0.995, TNS −77.9 across 290 endpoints, WHS +0.051). Spreading logic
broke the congestion but lengthened nets globally — trading the problem
rather than removing it. Two independent attempts to rearrange the same
netlist both failed; the netlist is what has to change.

## 12. Where timing landed (runs 40–44)

After the ÷8 clock and the bridge fix, timing became a tail-chase rather
than a wall. Trajectory at the 100 MHz domain (the VM's ÷8 paths have
never failed since):

| Run | WNS | WHS | Note |
|---|---:|---:|---|
| 32 | −1.249 | +0.052 | first ÷8 route |
| 33 | −0.640 | +0.051 | |
| 36 | −0.415 | +0.053 | bridge fix + blit-DDA |
| 40 | ~−0.3 | + | sidecar RUN, DIR ESC, PS/2 keyCode |
| 41 | — | — | **route process SIGKILLed** at ~3 h, 790 overlaps, no verdict |
| 42 | −0.112 | +0.054 | |
| **43** | **−0.112** | **+0.054** | identical to 42 |

**Run 43's entire failing set is two paths:**

| Slack | Endpoint | Levels | Logic / route |
|---|---:|---|---|
| −0.112 | `u_core/u_stor/state_reg[1]` | 6 | 3.198 ns (33%) / 6.547 ns (67%) |
| −0.018 | `u_core/u_cons/state_reg[4]` | 11 | 2.414 ns (24%) / 7.451 ns (76%) |

Both are **route-dominated with shallow logic** — 6 and 11 levels. By
[§2.10](RTL_DESIGN_PRINCIPLES.md) that means placement, not structure:
there is essentially no logic left to remove. A **placement seed sweep**
is the appropriate lever, not further RTL. Runs 42 and 43 landing on an
identical WNS suggests the same path under the same placement strategy
rather than a hard structural floor.

**Process lessons from this stretch:**

- **Run 41 was lost to a `Killed` route process, not a timing failure** —
  ~3 hours of converged routing discarded because the flow has no
  checkpoint recovery and treats a killed step as a failed run.
- **Runs share one output directory.** `build/nexys_video/` holds a single
  `post_*.dcp` set and one `impl_1` bitstream slot, so each run erases the
  previous one's checkpoints and reports. Only `run<N>_console.log` and
  anything copied to `build/bits/` survive. Run 36 got its own directory
  when it needed to run in parallel — that pattern is worth making the
  default.
- **`archive_bit.sh` saved only the `.bit`.** The board's SD/flash path
  takes the `.bin`, so archived runs were not directly flashable; fixed
  2026-08-26 to archive both.

## Run-45 congestion campaign (2026-08-26)

Run 45's default-placement route failed (2,426 overlaps). Re-placed the
same post-opt netlist from its checkpoint to isolate the placement
variable:

| Placement | Router | Result |
|---|---|---|
| default (impl_1) | default | FAIL — 2,426 overlaps |
| `-directive Explore` | Explore | FAIL — 3,171 overlaps |
| `-directive AltSpreadLogic_high` | default | **ROUTED** — WNS −0.502, WHS +0.050 |

The Explore placement's own congestion report names the problem: one
**level-5 East window at 120%** (CLB X49Y54–X80Y85), composition 61%
`u_exec64` + 38% rest of `u_vm`, LUTRAM 29% / MUXF 43% of the window,
BRAM columns inside it 100% occupied. AltSpreadLogic_high cut it to 104% (window moved north,
LUTRAM 65% of contents — the incompressible core; the spread logic
left) and the default router closed it. It is a single over-dense VM
dispatch cluster packed against the BRAM columns — not diffuse
pressure — so router effort cannot fix it; only spreading placement can.
The VM runs at 12.5 MHz (80 ns period), so spreading it is timing-free.

### Run ledger (45 →), Congestion_SpreadLogic_high

`JMR_VIVADO_STRATEGY=Congestion_SpreadLogic_high` → place `AltSpreadLogic_high`,
phys_opt `AggressiveExplore`, route `AlternateCLBRouting`; synth stays
`AreaOptimized_high`, opt `ExploreArea`. **Treat this as the default strategy.**

| Run | WNS | WHS | Gate | Carried |
|---|---:|---:|---|---|
| 45 | route FAILED | — | — | 2,426 overlaps after 4h26m on default placement; recovered to −0.502 by re-placing with AltSpreadLogic_high |
| **46** | **+0.017** | +0.055 | **published** | **first timing-clean bit in project history**, after ten runs of negative slack |
| 46nc | −0.174 | +0.050 | override | `JMR_NOCACHE` A/B twin — identical RTL but for the bridge cache; the delta is placement noise, not the cache |
| 47 | +0.039 | +0.036 | published | DIR `ds_base` fix (cold DIR read LBA 1 past 16 entries) |
| 48 | +0.130 | +0.050 | published | continuous D-line telemetry, E-line state beat, console-idle V heartbeat, phantom `-- MORE --` fix |
| 49 | −0.166 | — | **refused** | DIR handshake self-heal — the new retry qualifier landed in the console dispatch cone |
| **49b** | **+0.180** | +0.051 | **published** | same content, retry qualifier registered out of the cone (`7f4f113`) — best margin to date |

Five clean gates in seven attempts on this strategy, and both failures were
diagnosed and fixed on the next attempt. Timing is no longer the campaign's
binding constraint.

**Flow traps found along the way:**

- `set_property strategy` **RESETS the run's step options** — `BIN_FILE` must be
  re-applied after it, or the run ships no `.bin` (bit us on run 46).
- `wait_on_runs` needs a `catch`, or a route failure aborts the script before
  the checkpoint-recovery branch can run (run 45 died that way).
- Runs shared one output directory and overwrote each other's checkpoints;
  `archive_run.sh` plus the never-smash guard (`7b9071a`) now archive every
  impl bitstream before a launch and label gate-refused ones `WNSFAIL`.
- **Flash the `.bit`, never the `.bin`.** `openFPGALoader -f <bit>` boots;
  the same design flashed as `.bin` blue-screens. The two files carry identical
  logic — the `.bin` is the 32-bit word byte-swap of the `.bit` payload — so it
  is a packaging mismatch, not a design fault.


## Why the wall came down — the placement finding

Runs 44–46 are the controlled experiment, and the answer is not the one
everybody reached for first:

| | run 44 | run 45 | **run 46** |
|---|---:|---:|---:|
| Slice LUTs | 105,532 | 106,079 | **110,532** |
| LUT as Logic | 96,691 | 97,238 | **101,691** |
| Slice Registers | 46,092 | 46,132 | **46,186** |
| BRAM tiles | 344 | 344 | **344** |
| DSP48E1 | 139 | 139 | **139** |
| Placement | default | default / Explore | **AltSpreadLogic_high** |
| Result | routed, −0.897 | **FAILED**, 2,426 overlaps | **routed, +0.017** |

Run 46 carries **+5,000 LUTs over run 44** and **+4,453 over the run that
failed**, on identical BRAM and DSP — and it is the only one of the three that
both routed *and* closed timing. **Size decided none of it; placement decided
all of it.**

The BRAM-pressure hypothesis (344/365 = 94.2%, pinning logic to fixed columns)
is *not* what blocked run 45 — the same 344 tiles routed clean once the
surrounding logic was spread. 94.2% BRAM is real fragility; it is not the
operative variable.

**Standing rule: a route failure on this design is a *placement* diagnosis
until proven otherwise.** Read the congestion window composition from
`report_design_analysis -congestion` before touching RTL or resource counts.
The congestion is one over-dense VM dispatch cluster (`u_exec64` ~61% +
rest of `u_vm` ~38% of a level-5 window at 120% East) packed against the BRAM
columns — router effort cannot fix that, and `route_design -directive Explore`
failed *worse* than default. Only spreading placement works, and the VM runs at
12.5 MHz so spreading it is timing-free.

Reaching for utilization cuts first cost most of 2026-08-26.

**Second lesson from the same day: telemetry cannot see a stale artifact.**
The PACMAN `fault 3` that ran alongside this campaign was real and correctly
reported, in a program that had already been fixed — `card.img` had been minted
18 minutes before the fix. Verify what the board is actually running before
trusting any board-vs-sim comparison. See
[FPGA_BRINGUP.md](FPGA_BRINGUP.md#-a-stale-cardimg-makes-the-board-run-a-program-you-already-fixed).

## Run 50 — DIR WORKS ON THE BOARD (2026-08-27, first working directory)

**The board verdict that matters: the user flashed run 50 and DIR works
— the first bit in project history with a working directory.** The
runs-long wedge family (stale `ds_base` run 47, phantom `-- MORE --` run
48, C_DIR_CH starvation + lost work-port acks runs 49/50) is closed by a
three-layer defense, all netlist-verified in run 50's `post_synth.dcp`
before flashing:

| Layer | Commit | Cells in run 50 |
|---|---|---|
| DIR catalog restart (3 retries, then loud ?IO) | 7f4f113 | dir_hs_retry x9 |
| C_DIR_CH dropped mem-pulse reissue (idempotent, until granted) | 11c2869 | dir_hs_wd x60 |
| work-port ack-loss watchdog (41 us reissue, vm_ack_hold class) | 86a6af2 | work_wd x35 |

Run 50 also carried the first two pieces of the run-51 speed set:
**C3** (rAF timestamp sequential — `vm_clk` slack measured **+4.73 →
+6.23 ns** at div8, the comb 53x53 deleted) and **C4** (redundant
frame-end GC skip).

**Timing: WNS −0.214 / WHS +0.050 — publish refused**, bit preserved
(WNSFAIL label) and flashed under the standing small-negative policy;
the board result above is its vindication. The three failing families
are shallow placement-band paths (fbscan y_core_q→sram_addr −0.214
LL10-11, stor dent→state −0.208 LL11, cons line_len→reply_idx −0.147
LL14) — inside the ±0.19 noise the run-46 nocache A/B measured on
identical RTL, untouched by the speed set. Archived complete:
`build/runs/run50_dir-fixes_c3c4_WNS-0.214/` (checkpoints + WNSFAIL
bit). Run 49b (same DIR self-heal base, pre-C_DIR_CH-reissue) published
clean at +0.180 — `build/bits/run49_DIR-self-heal.bit` remains the best
clean bit on disk.

**Run 51** (launched 2026-08-27 ~21:20, bit-fresh — file list grew
`jmr_raster_engine.sv`): everything above plus the full-rate
raster/blit/imgd engine at div8. FPGA-SIM measured before launch:
DNKFAST in-game 3.98M → 1.89M core clk/frame (**2.10x**), MRDOFAST
4.03M → ~1.75M (**~2.2x**); 187/187 battery + 193/193 bytecode + 22
exact-pixel gates at the launch configuration. div7 is run 52's single
variable (run 50 measured the vm_clk wall at 73.8 ns as-placed — div7
needs ~3.8 ns of route recovery under pressure). The flow now archives
`congestion_impl.rpt` + 100-path timing distributions every run.

## Run 51 — the 2x engine bit, timing clean via contingency (2026-08-28 03:38)

**WNS +0.002 / WHS +0.025 — publishable.**
`build/bits/run51_engine2x_raster_div8_WNS+0.002.bit` (+ routed DCP in
`build/runs/run51_engine2x_WNS+0.002/`). Payload: C3 sequential rAF
timestamp, C4 GC skip, full C1 raster/blit/imgd engine (incremental
dest address per peer review), div8, on the run-50 DIR fixes. FPGA-SIM
measured before launch: DNKFAST in-game 2.10x, MRDOFAST ~2.2x.

**How it closed — the two-horse lesson, again.** The in-flow placement
(AltSpreadLogic_high via the 3-for-3 strategy) produced a timing-dead
arrangement: converged to 0 overlaps at WNS −1.83 / TNS −4,685, then
spent 6+ hours ripping up for ~0.4 ns of recovery. A parallel re-place
from the SAME netlist's opt checkpoint under **AltSpreadLogic_low**
placed+routed in **58 minutes** straight to +0.002. Same class as run
35-vs-36 and the 46nc A/B: on this design, placement arrangement
dominates everything, and a second directive from the opt checkpoint is
minutes-cheap insurance that should run by default whenever a route's
first intermediate WNS lands worse than −1.

Two flow traps caught tonight, both fixed in the tcl:
- `set_property strategy` RESETS step options and silently wiped the
  TCL.POST checkpoint hooks (run-46 BIN_FILE class): run 51 wrote no
  flow-level post_*.dcp all night — the ones on disk were run 50's.
  Vivado's native impl_1/*.dcp saved the contingency. Hooks re-applied
  after strategy, next to BIN_FILE.
- Per-run congestion + timing-distribution reports now archive with
  every run (run 51 is the first carrier).

Utilization (synth): the 2x payload is congestion-NEGATIVE — LUTs
+1,324 (+1.2%) for the whole engine, registers −2.6k, DSP −11 (the
53x53 and spr_so multiply cones), BRAM −0.5 vs run 49b.

Board next: flash run 51 — DIR regression check (run 50 was the first
working DIR; run 51 carries the same fixes), then the FAST fleet.

## Run 52 — clean on the first attempt, and the route collapsed to 16 minutes (2026-08-28 05:54)

**WNS +0.007 / WHS +0.050, gate self-published, div7 aboard.**
`build/bits/run52_present-del_vstack_div7_WNS+0.007.bit`
(tree 7324fb9; full archive + sim snapshot in
`build/runs/run52_present-del_vstack_div7_WNS+0.007/`).

**The route took 15m52s** — against 1h06m (run 46), 2h+ (run 50), and
6h+ (run 51's doomed horse). The payload REMOVED the congestion that
made routing a coin flip:

| Piece | Effect |
|---|---|
| present pipeline deleted (scanout reads mini_fb Port B) | S_FB_SYNC's 768,008 clk/frame gone from EVERY title; 2 SRAM clients + the DDR3 front deleted; scanout can never starve on the bridge (run-32/33 class dead). Cost: single-buffer tearing (user-accepted) |
| vstack -> BRAM (1W merge, name_has recipe) | Infeasible-attribute warning GONE from synth — ~700 SLICEM freed inside the old hot cluster after 9 runs of silent LUTRAM |
| stor name_hit registered | run-50's -0.208 family retired (zero beats; dent[0..10] stable >=21 beats pre-EVAL) |
| div7 (12.5 -> 14.3 MHz) | the 1.3 ns route-recovery bet PAID: vm_clk closed at the 70 ns budget |

Measured (FPGA-SIM, swap-to-swap fclk = core clk = board wall-clock):
MRDOFAST **891k clk/frame at div8** = 4.52x vs the 2026-08-27 baseline
(S_FB_SYNC absent from the profile); with div7 ≈ ~120 fps class.
DNKFAST projected ~2.6x. Battery: 380 passed / 1 known content failure
(extended-PACMAN image 20,680 > CODE_WORDS — HTML-side trim item).

Flow fixes proven in this run: the strategy-reset hook-wipe fix (all
post_*.dcp written) and the per-run congestion/timing-distribution
reports (auto-archived).

Board queue: run 51 (+0.002, div8, engine-only) then run 52 (+0.007,
div7 + present-deletion). DIR regression check on each — both carry the
run-50 DIR fixes.

---

## Runs 53/54 — two structural cones, priced by four failed placements (2026-08-28)

Run 53 (present restored + BL8 burst writes + joystick VM fix + div7):
**WNS -0.530**, all worst paths through the raster engine's row-wrap DDA
(ay -> so recompute, 9 logic levels born in one combinational wrap arm).
Run 54 (DDA precomputed into registers + I2C joystick PHY rework):
**WNS -0.270**, new leader `vm_sram_req -> fbscan linebuf CE` — the
arbiter's per-client ACK gates keyed on the COMBINATIONAL `sram_owner`,
dragging the VM's request cone into every client's clock enable. A
logically-false path (owner can't change mid-grant) made physically real.

Both cones were then priced as STRUCTURAL by re-placement A/B on their
own post-opt netlists (replace51.tcl, minutes each, no resynth):

| Netlist | Directive | WNS |
|---|---|---|
| run 53 | Default | -0.765 |
| run 53 | AltSpreadLogic_high | (worse, abandoned) |
| run 54 | AltSpreadLogic_low (51's winner) | -0.635 |

No directive could rescue either — placement was already near-optimal;
the logic depth itself was the wall. Both got RTL fixes in run 55:
DDA next-row precompute registers (with an imgd hold-guard for w==1
rows) and ACK gates moved to the REGISTERED `sram_owner_q` (every ack
source already lands >=1 cycle after grant, so _q is always valid).

**Rule earned:** when a re-place sweep can't move WNS by more than
~0.1, stop sweeping — the cone is structural; fix the RTL.

Board findings this cycle (run 54 flashed at -0.270 for testing only):
DIR fine, display clean (present restored), but DNKFAST bounced to
monitor and INVFAST black-screened — both proved CONTENT bugs, not
marginality (DNKFAST: rAF listener leak, HTML-side fbf7b6a; INVFAST:
animate() carried 24 locals against the 16-env-slot wall — fault 3 on
frame 0; found via bytecode prologue disassembly, fixed HTML-side by
splitting a helper, and the new compile-time locals check found the
same class latent in MISSILE). Joystick lag/jam root-caused in the I2C
PHY: 10 ms polls starved the NullLab device; final PHY = 40 ms polls,
250 us inter-register gaps, hold-last-state on transient bad batches,
and boot-time center calibration with relative hysteresis (don't touch
the stick during the first second after power-on).

Suite hardening from the same investigation: `_vmstat_int` matched
"fault=" inside "efault=" — every fault assertion in the battery read
the wrong field (1218c78 fixes it to field-boundary tokens). The full
battery re-run under honest assertions: 188 passed, 0 failures.

---

## Run 55 — vm_clk CLOSED (+4.05), sunk by two clk100 stragglers (2026-08-29 01:36, WNS -0.466)

The all-fixes run (owner_q ack gates + DDA precompute + calibrated
joystick PHY + present restored + BL8 burst + div7). The headline: the
owner_q and DDA fixes WORKED — **vm_clk met with +4.052 ns to spare**,
the deepest margin the VM has ever posted at div7. Both run-53/54
structural cones are dead.

What failed was the 100 MHz side, 49 endpoints in exactly two families:
- `u_cons line_len -> reply_idx CE` (-0.466, the run-50 -0.147 item,
  deferred then as "if it resurfaces" — it did, 3x bigger): the C_EXEC
  dispatch ladder was fully predicated EXCEPT the raw `line_len == 0`
  at the ladder ROOT, above every registered p_*_q. Fixed for run 56
  with `p_empty_q` (same 2-cycle-stable contract).
- `u_sram_br wc_data/rdata CE` (-0.116 down to -0.004): the new BL8
  write-combine's 128-bit CE fan — route-recovery class, left to run
  56's placement relief (bridge semantics stay untouched: sim-invisible,
  board-critical).

Lesson recorded: a deferred small-negative path does not stay small —
the placer spends the slack you leave on the table. Retire the whole
gate-band family when the recipe is one registered predicate.

Board note: the -0.466 bit is preserved (never-smash) but NOT for
long-session play; run 54's -0.270 showed content-independent fine, so
55's bit is a valid joystick-feel A/B if wanted before 56 lands.

---

## Run 57 — CLEAN (+0.063), and the route collapsed again (2026-08-29 08:15)

First publishable bit since run 52. Payload on top of run 56's tree:
joystick PHY v3b (settle window + drift re-centering + stuck-release
watchdog + phantom-release filter), the fbscan linebuf 1W byte-stagger,
banner R57. Whole flow — synth to bit — in ~80 minutes, against 4-6 h
routes for runs 53-55.

What closed it (the congestion campaign, by the numbers):
- LUTRAM eviction (run 56 payload): 9 arrays to BRAM, LUT-as-RAM
  6,072 -> 2,628; six 1,843-fanout LUTRAM read-mux nets deleted.
- fbscan linebuf: ram_style="block" had been silently infeasible since
  the module was born (dual-write) — 2048-deep buffer built from
  16,496 FFs + ~10.6k LUTs of muxes, the largest non-VM LUT sink on
  the chip. The 1W byte-stagger merge collapsed it to the 1 BRAM tile
  its own comment always claimed. Found by hierarchical checkpoint
  census (report_utilization -hierarchical on run 55's post_route).
- cons p_empty_q retired run 55's -0.466 leader.

**Rule earned:** grep every build's synth log for `Synth 8-6849`
(Infeasible ram_style) — three of the design's biggest congestion
sources (vstack, the LUTRAM nine, fbscan) were all this one warning,
ignored across dozens of runs. Remaining known: name tables x3 +
vobj_len (shared-read-register class, documented, deferred).

Bit: build/bits/run57_joyv3b_fbscan-bram_evict_div7_WNS+0.063.bit —
the board-acceptance bit for joystick v3b. +0.063 is 30x the margin of
run 51's +0.002 (the MK-marginality bit) but still modest: board
verdict decides long-session confidence.

---

## Run 56 — the control arm: eviction alone was NOT enough (2026-08-29 08:45, WNS -0.396 refused)

Same tree as run 57 minus the fbscan fix and joystick v3b. 5.5-hour
route to -0.396, leader `cons line_len -> state_reg` (the LIST-parse
`line_len == 4`, shallow enough to close in a healthy chip — run 57
closed it with identical console RTL — but the first casualty under
placement stress; retired anyway with p_len4_q for run 58).

Read as an A/B against run 57 (+0.063, 80-minute flow): the LUTRAM
eviction helped but **the fbscan linebuf conversion was the decisive
congestion lever** — one dual-write line buffer masquerading as
16,496 FFs + 10.6k LUTs was the difference between a 5.5 h failing
route and an 80-minute clean one.

---

## Runs 58/59 — the console parse family retired for good (2026-08-29 evening)

Run 58 (joy VM edge fix + GC/FIND accel): WNS -0.261, TNS -0.261 — ONE
path, `cons line_len -> reply_idx/R` через the C_PF2 filename parse:
`line[line_len-1]` is a 128:1 char mux evaluated inside the reply
steering. Two placement horses (Default -0.040, AltSpreadLogic_high
-0.085) narrowed but could not close a mux that size.

Run 59 (dual-path keydown dedup + PHY v3c + the line_tail_q hoist +
PF-skip machinery dormant behind JMR_PF_SKIP): **WNS +0.034 CLEAN**.
The hoist moved the char mux into the registered predicate block
(line_len is >=2 beats stable there — the same contract as every
p_*_q). That is the THIRD console-parse cone to fail a run (p_empty_q,
p_len4_q, line_tail_q) — the family is now fully registered; nothing
raw remains between line_len/line[] and dispatch or reply logic.

Bit: build/bits/run59_dedup_cons-tail_v3c_div7_WNS+0.034.bit — boots
R59. Board acceptance: single-shot fire per press (the dual-interface
pad dedup), joystick v3c, DIR, display. NOTE: the INVFAST saucer fault
is NOT expected to change on 59 (keyboard-input bug, prime suspect =
grids-leak object exhaustion, MAX_OBJ 960 — see the plan's open-debt
entry; H-line telemetry queued for run 60 makes it visible live).

---

## RUNS 65-68 — the V1.5 editor/compile bring-up (2026-08-31 .. 09-01)

| Run | WNS/WHS | Payload | Verdict |
|---|---|---|---|
| 65 | +0.197/+0.037 | editor-as-game, compile+ARTX ABI, src_len 2FF CDC, src_bank belt-clears, jn_bucket 1W | published; two-horse re-place recovered a −1.001 route collapse (65d) of the SAME verified netlist |
| 66 | +0.383/+0.042 | full PS/2 keyCode map (F-keys/BS/Shift — kev path had letters/arrows only), sticky-cdone clear at p_clr, SAVED. reply (dead row 11) | best margin since run 60; board revealed the cdone RACE |
| 67 | +0.133/+0.050 | cdone edge gate (accept only after seen-LOW since launch — the p_clr clear rides vm_clk and loses to the clk100 console every time) | board COMPILE finally ran the full chain; died at the art-flag content bug |
| 68 | (see archive) | banner V1.5 R68, G-line fault telemetry ({fsite, fault_arg}), exec64 fault_site adoption | the V1.5 keeper |

The failure that was NOT timing: the board compile fault-5 was a garbage
art-flag byte (console SRAM write read back wrong by the VM through the
DDR3 bridge — sim-invisible, SRAM_INTERNAL). Fixed by content sanitation
in COMPILER.HTML; root cause open, G-line armed for it. Full forensics:
memory/board-compile-bringup.md.

The 65d lesson repeated run-46's: a −1.0 WNS with hundreds of tiny misses
after a congestion-thrash route is a PLACEMENT verdict, not a netlist one —
re-place the same post_opt.dcp (replace51.tcl, two directives) before
touching RTL.

---

## Related

- [FPGA_FIT.md](FPGA_FIT.md) — caps, NEVER table, live scoreboard
- [RTL_DESIGN_PRINCIPLES.md](RTL_DESIGN_PRINCIPLES.md) — the proactive rules
- [potential bugs.md](potential%20bugs.md) — incident history
