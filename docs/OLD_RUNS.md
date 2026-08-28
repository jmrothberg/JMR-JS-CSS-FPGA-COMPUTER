# Old Vivado runs (diary)

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**Not the agent brief.** Repairs, live caps, and the next command:
[FPGA_FIT.md](FPGA_FIT.md). Glass / failed-fix:
[SESSION_HANDOFF.md](SESSION_HANDOFF.md). RTL edits that broke glass:
[VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md).

This file is run diary only. **Three different deaths** (do not treat them
as one bug):

| Failure | Tell | What to do |
|---|---|---|
| **70 GB hang** | One process, log frozen, RSS (RAM use) climbing toward ~80 GB | `mem[i] <=` in the VM state machine → RAM became flip-flops. **Fixed** (Port A). Do not “fix” glass by putting those writes back |
| **Mapping OOM** (Out Of Memory) | `tcmalloc large alloc`, process killed | Fat netlist and/or too many workers. Synth stays **2** threads |
| **Place UTLZ-1** | synth OK, place DRC fails | BRAM oversub → LUTRAM demotion → LUT blowup. [FPGA_FIT.md](FPGA_FIT.md) |

Do not resume mid-mapping. Do not raise synth threads.
**`bit-fresh`:** never after a mapping *crash*; **yes** after a source
file-*list* change (that is the 2026-08-21 next build).

**Log paths:** `build/nexys_video/vivado/jmr_nexys_video.runs/synth_1/top_nexys_video.vds`  
**RSS tracker:** `build/nexys_video/synth_rss.log` (largest Vivado process).

Kill only if the **largest** Vivado process climbs toward ~80 GB **and**
the log is frozen, **or** RSS passes **~100 GB** during technology
mapping (`tcmalloc large alloc`).

---

## 2026-08-21 place-fails (superseded)

Both **UTLZ-1**, not current work. Morning 04:11: LUT ~1424% / BRAM ~181%
(incremental stitch duplicated the framebuffer). Night 22:29 `bit-fresh`:
LUT ~1413% / BRAM ~159% (`imgd` off-chip; LUTs barely moved). Causes and
what landed: [FPGA_FIT.md](FPGA_FIT.md) § Fit forensics.

---

## Older OOMs (lessons only)

Prior mapping OOMs (2026-08-19 **7** workers; 2026-08-20 **2** workers)
taught: worker caps alone do not fix a fat netlist; no DCP until
synth_1 100%; never `bit-fresh` after a mapping crash. Those netlists
no longer exist (exec32 cut + Port A). Hour-by-hour tables are in git
history if needed.

---

## Checkpoints (why mapping cannot resume)

`synth_design` is one UG901 step. A mapping crash has **nothing** to
reopen. After synth_1 is 100% and RTL is unchanged, the next `make bit`
**skips re-synth**. Force with `JMR_VIVADO_FORCE_SYNTH=1`. Impl-step
DCPs (`post_opt` / `post_place` / …) are for a manual `open_checkpoint`
if place/route dies; project mode does not auto-resume mid-place.

Do **not** kill a live synth to attach checkpoint hooks; hooks only fire
at step end.

`INFO: [Synth 8-7052]` on `u_fb` = framebuffer **is** BRAM (good timing
hint). Ignore. `e32_p_clr` Synth 8-6014 is unused-FF housekeeping, not
the hang.
