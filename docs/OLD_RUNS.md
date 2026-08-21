# Old Vivado runs (diary)

**Not the agent brief.** Repairs and Headline:
[FPGA_FIT.md](FPGA_FIT.md). Glass: [SESSION_HANDOFF.md](SESSION_HANDOFF.md).
RTL edits that broke glass: [VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md).

This file is run diary only. Do not resume mid-mapping. Do not raise
synth threads. Do not `bit-fresh` after a crash.

**Log paths:** `build/nexys_video/vivado/jmr_nexys_video.runs/synth_1/top_nexys_video.vds`  
**RSS tracker:** `build/nexys_video/synth_rss.log` (largest Vivado process).

Kill only if the **largest** Vivado process climbs toward ~80 GB **and**
the log is frozen, **or** RSS passes **~100 GB** during technology
mapping (`tcmalloc large alloc`).

---

## V1.0 `make bit` — 2026-08-20 20:53 → 08-21 04:35 — PLACE FAILED

exec32 gone, Port A monsters, `spr_mem` 32 KB / `source_mem` 64 KB.
**2** synth threads. Reused project (not `bit-fresh`).

| Outcome | Detail |
|---|---|
| synth_1 | **100%** — first full DCP on this netlist |
| Technology mapping | elapsed **06:42:11**; peak ~38 GB (held; no OOM) |
| opt_design | OK |
| place_design | **FAILED** — DRC UTLZ-1 (LUT ~1424%, BRAM ~181%, LUTRAM 128%) + REQP-1962 on `imgd_pix` ADDR15 |
| Root cause | BRAM oversub → demote large arrays to LUTRAM → LUT blowup. Fix order: [FPGA_FIT.md](FPGA_FIT.md) |

Do **not** re-run until Phase 3b + BRAM headroom land.

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

---

## 70 GB hang vs mapping OOM vs place UTLZ

| Failure | Tell | Cause |
|---|---|---|
| **70 GB hang** | One process, log frozen, RSS → ~80 GB | `mem[i] <=` in VM FSM → FFs. **Fixed** (Port A). Ledger: [VIVADO_FLATTEN_HUNT.md](VIVADO_FLATTEN_HUNT.md) |
| **Mapping OOM** | `tcmalloc large alloc` ~5 GB, process killed | Fat netlist and/or too many workers. Synth stays **2** |
| **Place UTLZ-1** (this run) | synth OK, place DRC fails | BRAM oversub → LUTRAM demotion → LUT blowup. [FPGA_FIT.md](FPGA_FIT.md) |

`INFO: [Synth 8-7052]` on `u_fb` = framebuffer **is** BRAM (good timing
hint). Ignore. `e32_p_clr` Synth 8-6014 is unused-FF housekeeping, not
the hang.
