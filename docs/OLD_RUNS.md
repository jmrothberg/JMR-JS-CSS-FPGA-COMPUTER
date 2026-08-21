# Old Vivado runs (diary)

**Not the agent brief.** Current fit laws and the Port A recipe:
[FPGA_FIT.md](FPGA_FIT.md). RTL edits that likely broke glass:
[VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md). Live status:
[SESSION_HANDOFF.md](SESSION_HANDOFF.md).

**Live run is first.** Failed runs below predate 2026-08-21, when
exec32 was deleted and the LUTRAM monsters were Port A'd — that netlist
no longer exists. The *lessons* still hold (worker caps
alone do not fix a fat netlist; no DCP until synth_1 100%; never
`bit-fresh` after a mapping crash); the *diagnoses* ("idle exec32 still
dies", "do not Port-A `stack`") are already acted on.

This file is hour-by-hour / log-noise from `make bit` so
FPGA_FIT stays short. Do not resume mid-mapping. Do not raise synth
threads. Do not `bit-fresh` to “recover” a mapping crash.

**Log paths:** `build/nexys_video/vivado/jmr_nexys_video.runs/synth_1/top_nexys_video.vds`  
**RSS tracker:** `build/nexys_video/synth_rss.log` (largest Vivado process).

Kill only if the **largest** Vivado process climbs toward ~80 GB **and**
the log is frozen, **or** RSS passes **~100 GB** during technology
mapping (`tcmalloc large alloc`). All-Vivado-sum ~70 GB with parent
still ~35 GB is helpers, not the 70 GB FSM-poke hang.

---

## V1.0 `make bit` — 2026-08-20 20:53 (in progress)

Same step table as the 16:17 run. **This** netlist is V1.0: exec32 gone,
Port A on the LUTRAM monsters, `spr_mem` 32 KB / `source_mem` 64 KB.
**2** synth threads. Reused the existing Vivado project (not
`bit-fresh`). Started **Thu Aug 20 20:53:46**. Elapsed times are
Vivado’s `Time (s): elapsed` from `synth_design` start (same clock as
16:17). Log: `synth_1/top_nexys_video.vds`. Tracker:
`build/nexys_video/synth_rss.log`.

The tracker’s first line (`tcmalloc: large alloc 4896620544`) is the
**last line of the old concatenated `runme.log`**, not this run dying.

| Step | What it is | Status | This run | 16:17 (for compare) |
|---|---|---|---|---|
| Open project, skip MIG | Reuse `build/nexys_video/vivado` | **Done** | seconds (20:53:34 parent; `reusing …xpr`, MIG skip) | seconds |
| RTL elaboration | Read Verilog, build netlist | **Done** | **elapsed 00:12:08** (wall ~21:05:54); peak **29.4 GB** | 00:11:03; peak ~28.5 GB |
| RTL optimization phase 1 | First cleanup | **Done** | **elapsed 00:12:30** (wall ~21:06:16); peak **29.4 GB** | in those 11 min |
| Constraints + timing engine | Apply XDC; start timing | **in progress** (~21:10) | `Initializing timing engine`; RSS **~35 GB** (same peak as 16:17) | elapsed **00:18:59**; peak ~35 GB |
| RTL optimization phase 2 | Long quiet; FSMs; hash/FB as RAM | not yet | — | elapsed **02:39:54** |
| Cross-boundary / area optimization | Merge/shrink across modules | not yet | — | elapsed **07:06:36** |
| ROM / RAM / DSP / retiming report | Preliminary mapping tables | not yet | — | minutes |
| Apply XDC timing constraints | Clock/path constraints | not yet | — | elapsed **07:12:34** |
| Timing optimization | Timing-driven logic opt | not yet | — | elapsed **08:07:08**; peak ~54 GB |
| Technology mapping | Map to FPGA cells | not yet | 2 workers (do not raise) | **OOM ~03:15**; 7 workers; RSS 58→114 GB |
| Rest of synth_1 (write DCP) | `utilization_synth.rpt` when 100% | not yet | — | never reached |
| impl_1 / place / route / `.bit` / WNS | After synth | not yet | — | not started |

Fill later rows from `Finished … : Time (s): elapsed =` in
`top_nexys_video.vds` as they print. Peak RSS from the tracker.

---

## 16:17 `make bit` — first full VM (OOM ~03:15 2026-08-19)

Started **2026-08-18 16:17:50**. **CRASHED ~03:15 2026-08-19** (out of
memory). **7** synth workers. `tcmalloc` **5.2 GB**. RSS **58→114 GB**.
No `synth_1` DCP — cannot resume mid-step. Tracker copied to
`synth_rss.log.prev` on the next `make bit`.

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
| Technology mapping | Map to FPGA cells | **OOM ~03:15** | Started ~00:25; `tcmalloc` **5.2 GB** from 02:45; RSS **58→114 GB**; 7 workers | Cap synth at **2** threads. Impl stays 8. No DCP |
| Rest of synth_1 (write DCP) | `utilization_synth.rpt` when 100% | Never reached | — | |
| impl_1 / place / route / `.bit` / WNS | After synth | Not started | — | |

**Recovered:** Vivado project, MIG, logs. **Not recovered:** in-flight
netlist. Next `make bit` (not `bit-fresh`) redoes hours.

**What that OOM was:** seven parallel mapping workers, each on a huge
netlist. Linux OOM looks at **physical RAM**, not swap. `tcmalloc` wants
a big **contiguous** chunk. One process peaked ~54 GB in timing-opt and
lived; 7 copies did not. Scripts then capped synth at 2. That cap is
**necessary and not sufficient** (see 2026-08-20).

---

## 2026-08-20 `make bit` — 2 threads, OOM again

User-confirmed **out of memory** at mapping. Synth threads were **2**.
Still no `synth_1` DCP. Do **not** `bit-fresh`. Do **not** raise threads.

| What we saw | What it means |
|---|---|
| Wall of `Synth 8-7052` on `u_fb/mem0_reg_*` | Framebuffer inferred as **BRAM** (good). Timing hint. Not the death. |
| RAM-inference: `source_mem` RAM256X1S×4096, `vstack` RAM64M×1408, `name_mem` ×1536, GC queues, tagged `stack` ×704 | Big JS/console arrays still **LUTRAM**. |
| `tcmalloc: large alloc 4896620544` (~4.9 GB) | Same tell as 16:17 (`tcmalloc` 5.2 GB). |
| OOM / `make … Terminated` | Mapping did not finish. Next `make bit` redoes synth after RTL cleanup. |

**Learn:** 2 workers stopped the *7-copy* 114 GB spike. Mapping this
LUTRAM VM + idle exec32 still dies on 128 GB. Cleanup:
[FPGA_FIT.md](FPGA_FIT.md#cleanup-before-the-next-make-bit-2026-08-20-oom).

### RAM-inference paste (LUTRAM list)

Matches 16:17 leftovers (`source_mem` RAM256X1S×4096, `vconsts` /
`vobj_proto` RAM64M×352) and more JS heap as LUTRAM: `vstack` 2K×64
(×1408), `name_mem` 32K×8 (×1536), `gc_queue` 16K×14 (×1280),
`vgc_queue` 4K×64 (×1100), `varr_tmem` 64K×3 (×1024). Tagged `stack`
2K×32 (×704) dies with exec32 — do not Port-A it.

T200 has 134,600 LUTs so it can still **fit**; this is why mapping is
hungry at 2 threads.

### Live log noise (`Synth 8-7052`)

Vivado prints a lot, then goes quiet for hours. Watch `synth_rss.log`,
not INFO rate.

**`INFO: [Synth 8-7052]`** on `u_fb/mem0_reg_*` “implemented as a Block
RAM” / “no optional output register”:

- **Good.** 640×480 framebuffer is **BRAM** (Port A in `jmr_mini_fb` /
  `jmr_video_vram`).
- The rest is a **timing hint** for later WNS at ~30 MHz. Do **not** add
  output registers to silence it. One line per FB BRAM slice.
- **Where:** RAM inference of the glass, early/mid synth. VM mapping is
  still ahead. Quiet after is expected.

`8-6156` / `8-7080` tables are LUTRAM vs BRAM. `8-7052` is not that list.

**`tcmalloc: large alloc N bytes` then OOM:** the real stop. No synth
DCP. Shrink RTL, then `make bit` at 2 threads.

---

## Checkpoints (why mapping cannot resume)

`AUTO_INCREMENTAL_CHECKPOINT` plus `STEPS.*.TCL.POST` write
`build/nexys_video/post_synth.dcp` at synth **100%** and `post_opt.dcp` /
`post_place.dcp` / `post_phys_opt.dcp` / `post_route.dcp` after those
impl steps. A mapping crash has **nothing** to reopen. `synth_design` is
one UG901 step.

After synth_1 is 100% and RTL is unchanged, the next `make bit`
**skips re-synth**. Force with `JMR_VIVADO_FORCE_SYNTH=1`. Impl-step
DCPs are for a manual `open_checkpoint` if place/route dies; project
mode does not auto-resume mid-place.

Do **not** kill a live synth to attach checkpoint hooks; hooks only fire
at step end.

---

## 70 GB hang vs mapping OOM (detail)

Two different failures (plus the 2026-08-20 2-thread OOM in FPGA_FIT).

1. **70 GB hang:** one process, log frozen, heap written from the VM FSM
   (`mem[i] <=`) → inferred as flip-flops. Isolated `rdata <= mem[raddr]`
   while writes stayed still hit **71 GB**. Writes moved to Port A
   (~15:32) → ~**15 GB** hold after `e32_p_clr`. **Fixed.** Ledger of
   those RTL edits: [VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md).
2. **16:17 mapping OOM:** 7 workers, `tcmalloc` 5.2 GB, RSS 58→114 GB.
3. **2026-08-20 mapping OOM:** 2 workers, `tcmalloc` 4.9 GB. Netlist still
   too fat (LUTRAM + exec32).

`e32_p_clr` Synth 8-6014 is unused-FF housekeeping, not the hang cone.
Hang = log frozen **and** RSS climbing toward ~80 GB.

---

## Unmeasured glass ports (2026-08-20, before this OOM)

Glass debugging added **14** exec64→parent output ports (path-command
mirror `pc_*` — bug **#49**; JSON seed `js_*` — bug **#54**) plus parent
FFs (`e64_wr_ok`, `vprom_from_exec`, `pc_*` shadows). FFs/wires, **no**
new `mem[i] <=`. Fit estimate tables in FPGA_FIT predate them. Re-measure
after a synth that actually finishes.
