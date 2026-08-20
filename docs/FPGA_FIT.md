# How JMR JS fits the T200 (and would fit a T100)

Same job as the BASIC sibling’s `docs/FPGA_FIT.md` (`JMR-BASIC-FPGA-COMPUTER`):
measured Vivado numbers after a bit finishes. Estimates for this RTL are
the table below; do not quote them as a bitstream.

This bitstream is built for **Nexys Video / XC7A200T** (“T200”). The T100 column
is the **same used counts** against **Nexys A7-100T / XC7A100T** budgets — “would
it fit,” not a T100 `.bin` from this repo.

**Authoritative report:** `build/nexys_video/utilization_impl.rpt` after
`make -C tools/board_flow bit`.

**Unmeasured delta since the last fit run (2026-08-20):** glass debugging
added **14 new exec64→parent output ports** (9 for the path-command mirror
`pc_we`/`pc_waddr`/`pc_op_wdata`/`pc_a1..a5_wdata`/`pc_ccw_wdata` — bug
**#49**; 5 for the JSON seed mirror `js_we`/`js_waddr`/`js_i_wdata`/
`js_ph_wdata`/`vjs_val_wdata` — bug **#54**), plus a handful of parent FFs
(`e64_wr_ok`, `vprom_from_exec`, the 16-entry `pc_*` shadow arrays now
actually written). All are FFs/wires, **no new `mem[i] <=` in the 7k FSM**
and no new SRAM — but the numbers below predate them. Verilator lint is
clean and the warning profile is unchanged; Vivado has **not** been re-run.
Re-measure before quoting fit. Companion: [FPGA_BRINGUP.md](FPGA_BRINGUP.md),
[ARCHITECTURE.md](ARCHITECTURE.md), live status [SESSION_HANDOFF.md](SESSION_HANDOFF.md).

The `.bin` file is ~9.3 MB because that is the **200T configuration image size**,
not how full the chip is.

## Same RTL for FPGA-SIM, `.bin`, and ASIC

Coding law (six rules): `.cursor/rules/never-fake-fpga-sim.mdc`. This file
is **measured numbers**, not a second copy of that list. Live leftovers:
[SESSION_HANDOFF.md](SESSION_HANDOFF.md). Do not quote a new bitstream until
`make bit` actually finishes.

FPGA-SIM and `make -C tools/board_flow bit` compile the **same** `rtl/*.sv`.
`SYNTHESIS` in the board top is I/O (clocks, HDMI), not a second heap.
`ram_style = "block"` is a Vivado hint, not a Xilinx primitive inside the VM.
Clock class **~30 MHz**. Extra GET_PROP clocks (~1 µs worst case vs 16.7
ms/frame) are playable; combo heaps are not a speed win.

**Capacity (leftover block RAM (BRAM) after dual framebuffer (FB)):** T200 ≈
**365** RAMB36 ≈ **1.64 MB**. Dual 640×480×8 FB ≈ **0.6 MB**. Leftover ≈
**1 MB** for code + JS heap + console. Legal: `MAX_OBJ=1024` × 32 × 80b ≈
320 KB plus two-tier arrays (`1536×32` + `128×128`) × 64b ≈ 512 KB plus
`ENV_DEPTH=512` × 16 × 80b `venv_slot` ≈ 80 KB (same in PYTHON). Nested maps
+ JSON clones need ~1152 short arrays; `push` past 32 uses the long bank.
The 8192 / 4096 depths were ~**7 MB** — Verilator runs, the chip cannot.
External **4 MB** static RAM (SRAM) is **ASET art only** — do not put JS
objects there or bump that bank to 8 MB. `cls_mname` / `cls_mip` stay 16×16
(4 Kbit, not a JS heap). True dual-port only for CPU+scanout (video RAM /
FB); dump shares the CPU read port.

## This RTL vs T200 (estimates)

Not a routed report. Tile math is `bytes × 8 / 36 kbit`. 4-bit pixels would
not fix a synth hang (combo `arr[i]`); they would only cut FB BRAM in half
and rewrite the 8-bpp ABI. Replace these numbers from
`utilization_impl.rpt` when the next bit finishes with worst negative slack
(WNS) ≥ 0.

| Component | Estimate | T200 spec (XC7A200T) |
|---|---|---|
| Lookup tables (LUTs), if hierarchy holds | 45k–75k | 134,600 LUTs |
| Flip-flops (FFs), legal SRAM | ~15k class | 269,200 FFs |
| Dual FB 640×480×8 (front+back) | ~0.60 MB / ~133 tiles | 365 BRAM tiles / ~1.64 MB |
| ImageData `imgd_pix` (third 640×480×8) | ~0.30 MB / ~67 tiles | 365 tiles / ~1.64 MB |
| On-chip sprite scratch `spr_mem` | ~0.25 MB / ~57 tiles | 365 tiles / ~1.64 MB |
| Console source `source_mem` | ~0.13 MB / ~29 tiles | 365 tiles / ~1.64 MB |
| JS objects `MAX_OBJ=1024` × 32 × 80b | ~0.31 MB / ~71 tiles | 365 tiles / ~1.64 MB |
| JS arrays `1536×32` + `128×128` × 64b | ~0.50 MB / ~114 tiles | 365 tiles / ~1.64 MB |
| JS env `ENV_DEPTH=512` × 16 × 80b | ~0.08 MB / ~18 tiles | 365 tiles / ~1.64 MB |
| **BRAM rows if all infer as tiles** | **~2.2 MB / ~489 tiles** | **365 tiles / ~1.64 MB** |
| ASET art (4 MB SRAM port) | off-chip (board DDR3) | not BRAM |
| Memory Interface Generator (MIG) FIFOs | extra BRAM, size unknown until impl | inside the 365 |

If every on-chip array infers as BRAM, this RTL is **over** the 365 tiles.
A synth hang (RSS tens of GB, log frozen) is flatten / FFs, not “needs more
LUTs.” Fill the table from `utilization_synth.rpt` when this `make bit`
finishes synth, then `utilization_impl.rpt` after WNS ≥ 0. Do not invent
counts. Keyboard bring-up is [FPGA_BRINGUP.md](FPGA_BRINGUP.md), not a fit
baseline for this VM.

`$readmemh` font lives beside `rtl/engines/jmr_js_vm.sv`. Board asset SRAM is
MIG DDR3 behind `jmr_ddr3_sram_bridge`. Palette BRAM is dual-clock; HDMI game
mode reads it.

---

## Wall-clock benchmark (16:17 `make bit` — first full VM)

**Update this table** when a phase finishes (clock time + RSS from
`build/nexys_video/synth_rss.log` and `synth_1/top_nexys_video.vds`).
Later `make -C tools/board_flow bit` runs (not `bit-fresh`) should beat
these numbers if MIG/project already exist. Do not quote the 13 Aug
keyboard bring-up as this VM’s time.

**Log:** `build/nexys_video/vivado/jmr_nexys_video.runs/synth_1/top_nexys_video.vds`  
**RSS tracker:** `build/nexys_video/synth_rss.log` (largest Vivado process).
Kill only if the **largest** Vivado process climbs toward ~80 GB **and**
the log is frozen, **or** RSS passes **~100 GB** during technology mapping
(`tcmalloc large alloc` in `runme.log`) — that is the 03:15 OOM, not the
70 GB FSM-poke hang. All-Vivado-sum ~70 GB with parent still ~35 GB is
helpers, not the hang. **Never launch 7 synth workers** (synth cap is 2
threads). Place/route stays 8 — do not cap impl for this OOM.

Abbreviations: **RTL** = register-transfer level (Verilog). **MIG** = Memory
Interface Generator (DDR3). **XDC** = pin/clock constraints. **FSM** =
finite-state machine. **RSS** = RAM the process is using. **synth_1** =
Vivado synthesis. **impl_1** = place-and-route + bitstream. **WNS** =
worst negative slack. **DCP** = design checkpoint. **BRAM** = block RAM.

Started **2026-08-18 16:17:50**. **CRASHED ~03:15 2026-08-19** (out of
memory). No `synth_1` DCP — cannot resume mid-step. Tracker saved as
`build/nexys_video/synth_rss.log.prev` on the next `make bit`.

| Step | What it is | Status | Measured | Next-build note |
|---|---|---|---|---|
| Open project, skip MIG | Reuse `build/nexys_video/vivado` | Done (kept) | seconds | **Recovered.** Do not `bit-fresh` |
| RTL elaboration | Read Verilog, build netlist | Done (lost in RAM) | **11 min** (elapsed 00:11:03, peak ~28.5 GB) | Must re-run |
| RTL optimization phase 1 | First cleanup | Done (lost in RAM) | in those 11 min | Must re-run |
| Constraints + timing engine | Apply XDC; start timing | Done (lost in RAM) | **~19 min** from synth start (peak ~35 GB) | Must re-run |
| RTL optimization phase 2 | Long quiet; FSMs; hash/FB as RAM | Done (lost in RAM) | **elapsed 02:39:54** | Must re-run (~2 h 40 m) |
| Cross-boundary / area optimization | Merge/shrink across modules | Done (lost in RAM) | **elapsed 07:06:36** | Must re-run |
| ROM / RAM / DSP / retiming report | Preliminary mapping tables | Done (lost in RAM) | minutes | |
| Apply XDC timing constraints | Clock/path constraints | Done (lost in RAM) | elapsed **07:12:34** | |
| Timing optimization | Timing-driven logic opt | Done (lost in RAM) | elapsed **08:07:08**; peak **~54 GB**; ~55 min | |
| Technology mapping | Map to FPGA cells | **OOM ~03:15** | Started ~00:25; `tcmalloc` **5.2 GB** alloc from 02:45; RSS **58→114 GB**; 7 synth workers | **Fix:** synth `maxThreads=2` only. Impl stays 8. No DCP to resume mapping |
| Rest of synth_1 (write DCP) | `utilization_synth.rpt` when 100% | Never reached | — | |
| impl_1 / place / route / `.bit` / WNS | After synth | Not started | — | |

**Recovered:** Vivado project, MIG DCP, logs. **Not recovered:** in-flight
netlist. Resume is `source scripts/vivado_env.sh && make -C
tools/board_flow bit` (not `bit-fresh`) — redoes ~8 h to the crash point.
Synth uses 2 threads so mapping fits 128 GB; place/route uses 8. You
**cannot** continue at technology mapping: `synth_design` is one step
(UG901). First `.dcp` is written at synth_1 **100%**.

### Why 128 GB RAM + 96 GB swap still died

Two different failures. Do not mix them.

1. **70 GB hang (earlier, Port A):** one process, log frozen, heap written
   from the VM FSM → inferred as flip-flops. **Fixed.** That was not this crash.
2. **03:15 OOM (technology mapping):** Vivado spawned **7** parallel synth
   workers. Each mapping a huge netlist. Tracker: `tcmalloc` asked for
   **5.2 GB** at 02:45 while already ~32–58 GB, then RSS **58→114 GB** in
   ~two minutes. Linux’s OOM killer looks at **physical RAM**, not swap.
   Swap does not help a process that is allocating several GB per second,
   and `tcmalloc` needs a big **contiguous** chunk.

So: **7 workers was the mistake that made 128 GB too small.** One process
peaked ~54 GB in timing optimization and lived. Mapping with 7 copies of
that did not.

**Thread cap (do not slow place/route):** Vivado has **one** parameter
for all of `synth_design` — `general.maxThreads` ([UG901 Multi-Threading
in RTL Synthesis](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Multi-Threading-in-RTL-Synthesis)).
There is no “technology mapping only” knob. Scripts cap **synth** at 2
and restore **8** before `impl_1`. `-jobs` is parallel *runs*, not the
7 mapping workers. `JMR_VIVADO_JOBS` must not be used to raise synth
threads.

**Checkpoints (setting, not a second flow):** `AUTO_INCREMENTAL_CHECKPOINT`
plus `STEPS.*.TCL.POST` write `build/nexys_video/post_synth.dcp` at synth
100% and `post_opt.dcp` / `post_place.dcp` / `post_phys_opt.dcp` /
`post_route.dcp` after those impl steps. A mapping crash still has
**nothing** to reopen. After synth_1 is 100% and RTL is unchanged, the
next `make bit` **skips re-synth** (impl crash must not redo ~8 h). Force
a full synth with `JMR_VIVADO_FORCE_SYNTH=1`. Impl-step DCPs are for a
manual `open_checkpoint` if place/route dies; project mode does not
auto-resume mid-place from a setting.

**Design still has a mapping cost** (not “needs 256 GB”): paper BRAM is
over 365 tiles if everything infers; the crash log also showed some arrays
as **LUTRAM** (`source_mem` RAM256X1S×4096, `vobj_proto`/`vconsts`
RAM64M×352). That makes mapping heavy even at 2 threads. Do not “fix” it
by putting `mem[i] <=` back in the FSM. After a synth_1 DCP, fill
LUTRAM vs BRAM from `utilization_synth.rpt`. Agent recipe:
[LUTRAM leftovers](#lutram-leftovers-not-the-70-gb-hang).

---

## LUTRAM leftovers (not the 70 GB hang)

### What these words mean (LUTRAM, BRAM, Port A)

This is **how Vivado builds a memory**, not JavaScript and not FPGA-SIM
speed. Verilator simulates the SystemVerilog array either way; it does
not care about `RAM64M` vs `RAMB36`.

The T200 has two places for arrays:

| Word | What it is | When it is OK |
|---|---|---|
| **BRAM** | Dedicated RAM tiles on the chip (**365** of them). | Big tables: names, JS stack, console source, heap. |
| **LUTRAM** | The **logic** LUTs (same 134,600 that do AND/OR) wired as a tiny RAM. Vivado prints `RAM64M` / `RAM256X1S`. | Tiny 8-deep FOREACH/rAF saves. **Not** 32K `name_mem` or a 2K stack — that makes synth slow and hungry. |
| **Port A** | The Verilog **shape** Vivado needs to use BRAM: one write pulse, one address, one data; read data **next clock**; **no** reset-clear of the whole array in that process; the 7k-line VM `case` does **not** `mem[i] <=`. Copy `jmr_mini_fb.sv`. The FSM only pulses strobes (`stack_wr`, `imgd_we`, …). | Required for any **large** array that should be BRAM. |

**“LUTRAM → Port A”** means: rewrite the **big** arrays that missed that
template so Vivado can put them in BRAM. Extra clocks OK (wait `*_rdata`).
The 70 GB hang was the opposite (`mem[i] <=` in the FSM → every address
became a flip-flop). Adding `ram_style = "block"` while the poke stays
does **not** fix it.

**Not “put every array in BRAM.”** Paper math is already over 365 tiles
if everything infers. Small 8-entry tables can stay LUTRAM.

**When (serial — do not mix with glass or exec32):** (1) HTML/exec64
glass, (2) unhook exec32 ([REMOVING_EXEC32.md](REMOVING_EXEC32.md)),
(3) **this** Port A pass, then the user runs the next `make bit`.
Exec32 leftover (`stack` 2K×32, `consts`, `stack_tag`, `tfn_*`) is
~10% of the LUTRAM list; killing it does not fix mapping hunger.
Do not start this during a live synth. Do not put everything in
BRAM — paper BRAM is already over 365 tiles if every array infers.
Small 8-deep FOREACH/rAF stacks as LUTRAM are fine.

16:17 crash log mapped these as **LUTRAM** (tiny memories in LUTs) even
though some already have `ram_style = "block"`. That attribute is ignored
when the access is not UG901 Port A (`simple_dual_one_clock.v` /
`rams_sp_wf.v`). Adding `ram_style` and leaving `mem[i] <=` in the FSM is
how you get 8-7186 / LUTRAM / mapping cost — or the 70 GB FF hang if the
array is large enough.

**2026-08-20 live synth RAM-inference paste** still matches 16:17
(`source_mem` RAM256X1S×4096, `vconsts`/`vobj_proto` RAM64M×352) and
adds more JS heap as LUTRAM: `vstack` 2K×64 (×1408), `name_mem` 32K×8
(×1536), `gc_queue` 16K×14 (×1280), `vgc_queue` 4K×64 (×1100),
`varr_tmem` 64K×3 (×1024). That is tens of kLUTs before opcode logic.
T200 has 134,600 LUTs so it can still fit; this is why mapping is slow
at 2 threads. Priority after exec32: `source_mem` first, then those
heap arrays if they still miss. Tagged `stack` 2K×32 (×704) dies with
exec32 — do not Port-A it.

**Do not do this work to “make a title paint.”** Extra clocks OK. One
heap. No second copy. No JOIN/JSON/GC extract. After exec32 is gone,
inspect exec64 and the parent only. Copy `jmr_mini_fb.sv` Port A.
Agent does not run Vivado.

| Array | File | Why it missed BRAM | Safe fix (same behaviour, extra clocks OK) |
|---|---|---|---|
| `source_mem` 128K×8 | `rtl/engines/jmr_console_engine.sv` | RAM process has `if (!rst_n)` **and** only reads when `src_req` (AR 58025 / UG949: reset on the RAM process; gated read ≠ template) | Tiny process: `if (src_we) source_mem[src_addr] <= src_wdata; src_rdata <= source_mem[src_addr];` **no reset** in that block. Grant/reset stay in the FSM. Do not add a second port. |
| `vconsts` 1024×64 | `rtl/engines/jmr_js_vm.sv` | FSM `vconsts[c_i] <=` in `S_V64_CONST_HI` plus mux `vconsts_rdata <= vconsts[e64_vconsts_raddr]`. `e64_poke(6'd14, …)` must use the **same** we/addr/data, not a second write | Declare `vconsts_we/waddr/wdata` like `vvars`. Own `always_ff`. FSM and poke pulse strobes. Wait `vconsts_rdata`. |
| `vobj_proto` 1024×64 | `rtl/engines/jmr_js_vm.sv` | No Port A. FSM `vobj_proto[valloc_i] <=` (ALLOC / proto assign) plus mux read | Same as `vobj_alloc_wr`: `vobj_proto_wr(idx, val)`. One write/clock. GC/HEAP wait `vobj_proto_rdata`. |

`vfn_proto` is the same shape as `vobj_proto` — move it in the same pass
if you touch proto, do not leave one FSM-poked. `arr_len` / `vobj_cls`
are already listed (Synth 8-13159). After the next synth_1 100%, fill
LUTRAM vs BRAM from `utilization_synth.rpt`. If LUTRAM is still high,
the template still missed — do not widen threads.

---

## Live synth log (what you are seeing)

Vivado prints a lot, then goes quiet for hours. That is normal. Watch
`synth_rss.log` (RSS + last `runme` line), not chatty INFO rate.

**`INFO: [Synth 8-7052]`** on `u_core…/u_fb/mem0_reg_*` **“implemented
as a Block RAM”** / “no optional output register”:

- **Good.** The 640×480 framebuffer inferred as **BRAM** (Port A in
  `jmr_mini_fb` / `jmr_video_vram`). That is the opposite of LUTRAM.
- The rest is a **timing hint**, not a failure. The RAMB tile has an
  optional extra output flop Vivado did not absorb. Might matter later
  if WNS is negative at ~30 MHz. Do **not** add registers during this
  run to silence it. Do not treat a wall of 8-7052 as progress or as a
  hang — one line per FB BRAM slice.
- **Where you are:** RAM inference of the glass, **early/mid synth**.
  The long hungry part is still ahead (VM LUTRAM / technology mapping).
  Quiet after these lines is expected.

Ignore unless STATUS becomes failed or RSS climbs toward ~80 GB with a
**frozen** log (then kill). `8-6156` / `8-7080` RAM inference tables
are the LUTRAM vs BRAM list; `8-7052` is not that list.

---

## Headline (this `make bit` — waiting)


Part: `xc7a200tsbg484-1`. Early counts: `build/nexys_video/utilization_synth.rpt`
when `synth_1` hits 100%. Trust: `utilization_impl.rpt` after WNS ≥ 0.

| Resource | What it is | Used | T200 budget |
|---|---|---:|---:|
| **LUTs** | Logic (AND/OR/mux). One LUT ≈ one 6-input function. | — | 134,600 |
|  as LUTRAM | Tiny memories in LUTs instead of Block RAM. | — | 46,200 |
| **FFs** | 1-bit registers. | — | 269,200 |
| **BRAM** | 36 kb tiles. Dual FB + heap must land here. | — | 365 |
| **DSP** | Multiply/add (DSP48). | — | 740 |
| **Slices** | Place-and-route packing (4 LUTs + 8 FFs each). | — | 33,650 |

---

## Fit verdict

No measured VM bitstream yet. Compare **Used** to the T200 budget above, not
to an I/O bring-up image. Tightest expected row is **BRAM** (paper math ~489
tiles if everything infers). LUTRAM high + BRAM low means inference missed.

---

## Easy mistakes

- **LUTRAM leftovers are not a thread-count problem.** `source_mem` /
  `vconsts` / `vobj_proto` — Port A recipe in
  [LUTRAM leftovers](#lutram-leftovers-not-the-70-gb-hang). Do not raise
  synth threads. Do not put `mem[i] <=` back.
- **Do not write big on-chip arrays from the VM FSM.** That was the 70 GB
  blow-up. `imgd_pix` / `spr_mem` / `name_mem` / `json_mem` / `stack` /
  `name_hash_tbl` / `varr_len` / `vobj_alloc` / `vvars` must use a
  tiny `if (we) mem[addr] <= data` process (copy `jmr_mini_fb` Port A).
  The FSM only pulses `*_we` / `*_waddr` / `*_wdata`. Isolated `*_rdata`
  reads while the FSM still did `imgd_pix[i] <=` / `spr_mem[spr_wp] <=`
  still hit **71 GB**. After those writes moved out (15:32), synth held
  **~15 GB** after `e32_p_clr` instead of 8→36→70. Heap-table writes
  (`stack_wr` / `vobj_alloc_wr` / …) moved out the same way. Do not put
  `stack[i] <=` back for a title bug. FOREACH el+idx is `stack_dual_pend`
  (one write/clock). `arr_len` / `vobj_cls` still FSM-poked (8-13159) —
  Port A if you touch them.
- **Kill on RSS, not on `e32_p_clr`.** Synth 8-6014 is unused-FF
  housekeeping, not the cone. The 16:17 run **left `e32_p_clr`** and
  finished RTL Optimization Phase 1. Hang = log frozen **and** RSS climbing
  toward ~80 GB. **Separate:** tech-map OOM = `tcmalloc large alloc` and
  RSS past ~100 GB with **many synth workers**. Synth cap is 2 threads;
  impl stays 8. Tracker: `build/nexys_video/synth_rss.log`.
- **Heap-name grep empty ≠ cone.** `spr_mem` is on-chip blit scratch
  (~0.25 MB — **not** the 4 MB ASET bank). `ram_style = "block"` does not
  save an FSM poke.
- **Do not split JOIN/JSON/GC out of `jmr_js_vm.sv`.** Not a task. Maybe
  never. Linear intern find (`S_JOIN_FIND` one slot/clock, “not a 16-CAM”)
  is **play speed**, not the 70 GB hang — see
  [SYNTH_SLOWDOWN_LEDGER.md](SYNTH_SLOWDOWN_LEDGER.md).
- **`.bin` megabytes ≠ utilization.** The file is the whole 200T config image.
- **Do not copy BASIC LUT history** into this product. Method only.
- **FPGA-SIM green ≠ synthesizable.** Title RUN in Verilator is not a `.bin`.
- **First T200 bit is the slow one.** MIG + full VM synth; later `make -C
  tools/board_flow bit` reuses the project. `bit-fresh` / `clean` = pay first-build
  again. Measured phases: [wall-clock benchmark](#wall-clock-benchmark-1617-make-bit--first-full-vm).
  See [FPGA_BRINGUP.md](FPGA_BRINGUP.md).
