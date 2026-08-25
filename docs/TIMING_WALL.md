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

---

## Related

- [FPGA_FIT.md](FPGA_FIT.md) — caps, NEVER table, live scoreboard
- [RTL_DESIGN_PRINCIPLES.md](RTL_DESIGN_PRINCIPLES.md) — the proactive rules
- [potential bugs.md](potential%20bugs.md) — incident history
