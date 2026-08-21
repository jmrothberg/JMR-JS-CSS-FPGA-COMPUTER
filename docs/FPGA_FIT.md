# T200 fit — agent handoff (do not crash, do not overflow)

Nexys Video **XC7A200T**. The agent does **not** run Vivado — the user
does, from a host terminal:
`source scripts/vivado_env.sh && make -C tools/board_flow bit`. Same `rtl/*.sv` as FPGA-SIM.
Law: `.cursor/rules/never-fake-fpga-sim.mdc`. Extra clocks OK. One JS
heap. No JOIN/JSON/GC extract. Clock class ~30 MHz.

Diaries of failed runs: [OLD_RUNS.md](OLD_RUNS.md). Live glass:
[SESSION_HANDOFF.md](SESSION_HANDOFF.md).

---

## READY FOR SYNTHESIS — 2026-08-21 (read this first)

Both cleanup jobs below are DONE on this tree; the netlist the last OOM
saw no longer exists. What changed since that run:

1. **exec32 is gone.** `jmr_js_vm_exec32.sv` (5,170 lines) deleted;
   `u_exec32` uninstantiated; dropped from `sim/Makefile` and
   `vivado_build.tcl`. `hs32` is tied 0; the 302 exec32-driven
   `e32_*_q` wires are undriven (read as 0 — the designed raddr
   fall-through). The 74 parent-driven `e32_`-named signals remain (see
   the naming-trap section of REMOVING_EXEC32.md). Verilator eval got
   +16% faster from the smaller netlist alone.
2. **Port A'd the census monsters** (the 8-7186 killers): `vgc_queue`
   (3072×64 — the big miss), `vconsts`, `vobj_proto`, `vfn_proto`,
   `vfn_env`, `vfn_bound_this`, `venv_parent`. Each now has
   `*_pa_we/waddr/wdata` strobes cleared per beat; the single write
   port lives in the read process. FSM pokes on these are GONE.
3. **Shrinks:** `spr_mem` 256KB→32KB (~50 tiles back; all titles are
   ASET) and `source_mem` 128KB→64KB (~13 tiles; card copies are
   line-squashed, only MK.HTM truncates its LIST view).
4. Verified: probe ladder 8/8, PACMAN attract heap-stable through 118
   GCs on the strobed queue, title smokes green on the final build.

**How to run it (the smarter way):** `make bit` is Vivado, not Python —
the .venv (GUI/pytest/compile_js) plays no part. From the repo root, in
a normal host terminal (not a sandbox):

```
source scripts/vivado_env.sh
make -C tools/board_flow bit
```

`vivado_env.sh` sets `VIVADO=`; without it Make prints `Set VIVADO=…`
and stops. (`cd tools/board_flow && make bit` is the same thing.)
Guards are already the Makefile defaults: synth **2** threads, impl 8 —
do NOT raise
`JMR_VIVADO_SYNTH_THREADS`, do NOT set `JMR_VIVADO_ALLOW_WIDE=1`, do
NOT `bit-fresh`/`clean` after a mapping crash (no DCP until synth_1
hits 100%). If synth_1 completes, fill the [Headline](#headline-fill-after-synth_1-100)
from `build/nexys_video/utilization_synth.rpt` — LUTRAM high + BRAM low
means an inference template still missed somewhere; paste the report
and the census below finds it. The remaining narrow-table swarm
(vobj_len/obj-cls class, ~150Kb total) is still FSM-poked by design —
small enough to survive mapping, first candidates if LUTRAM is high.

---

## What was done before (kept for history)

### Cleanup before the next `make bit` (2026-08-20 OOM) — DONE 2026-08-21

2026-08-20 mapping **OOM'd at 2 synth threads**. Capping workers was
**not enough**, so the netlist was shrunk first. All three steps below are
complete; kept for the reasoning, not as a to-do.

**Glass is done.** All five HTML titles play on FPGA-SIM (INVADERS,
PACMAN, DONKEY, ASTEROID, MRDO). They are **slow** (clocks per frame /
FIND / 1 px per fillRect) — that is not this job. Do not reopen play
bugs. Do not mix a speed pass with a fit pass on `jmr_js_vm.sv`.

| Order | Job | Result |
|---|---|---|
| 1 | Unhook **exec32** | **done** — file deleted, both build lists cleaned, `hs32` tied 0. [REMOVING_EXEC32.md](REMOVING_EXEC32.md) |
| 2 | **Port A** the LUTRAM monsters | **done** — `vgc_queue` `vconsts` `vobj_proto` `vfn_proto` `vfn_env` `vfn_bound_this` `venv_parent`, plus `spr_mem` 256K→32K and `source_mem` 128K→64K. Recipe [below](#port-a-recipe). |
| 3 | Stop. User `make bit` (synth **2** threads, impl **8**) | **the current step** — fill [Headline](#headline-fill-after-synth_1-100). LUTRAM high + BRAM low = template still missed |

Do not raise `JMR_VIVADO_SYNTH_THREADS` or set `JMR_VIVADO_ALLOW_WIDE=1`.
Do not `bit-fresh` / `clean` after a mapping crash. Mapping cannot resume
(no DCP until synth_1 **100%**). Step 2 does not speed FPGA-SIM play.

---

## What you never do (crash / no-fit)

- **`mem[i] <=` in the 7k-line VM FSM** on a big array → 70 GB hang (RAM
  becomes flip-flops). Use `stack_wr` / `vobj_alloc_wr` / `varr_len_wr` /
  `name_hash_wr` / `vvars_wr` / `json_putc` / `imgd_we`. One `stack_wr`
  per clock (`stack_dual_pend` for FOREACH). Wait `*_rdata`.
- **`ram_style = "block"` while the poke stays** → LUTRAM or that hang.
- **Every array into BRAM** → paper math **~489 tiles vs 365** on the
  T200. Tiny 8-deep FOREACH/rAF may stay LUTRAM. Do not Port-A the tagged
  `stack` / `gc_queue` / `vars` / `tfn_*` family — they **disappear** with
  the Phase 3b sweep (~430 Kb), so converting them is wasted work.
- Grow heap past `MAX_OBJ=1024`, arrays `1536×32+128×128`, `ENV_DEPTH=512`.
  8192/4096 does not fit. JS objects are not the 4 MB ASET SRAM.
- Split JOIN/JSON/GC into new modules.

---

## Words (LUTRAM, BRAM, Port A)

### What these words mean (LUTRAM, BRAM, Port A)

Vivado **build** of a memory. Not FPGA-SIM speed. Verilator does not care.

| Word | Meaning | T200 |
|---|---|---|
| **BRAM** | Dedicated RAM tiles | **365** tiles (~1.64 MB). Dual 640×480 FB uses ~0.6 MB. Leftover ~1 MB for code+heap+console. |
| **LUTRAM** | Logic LUTs used as RAM (`RAM64M`, `RAM256X1S`) | 134,600 LUTs total. Fine for 8-deep saves. Hungry if `name_mem` / `vstack` / `source_mem` land here — that is the 2026-08-20 OOM. |
| **Port A** | Verilog shape that infers BRAM: one `we`/`addr`/`data`; read next clock; **no** reset-clear in that process; FSM only pulses strobes. Copy `jmr_mini_fb.sv`. | Required for **large** arrays. |

---

## LUTRAM leftovers (not the 70 GB hang)

## Measured FSM-poke census (2026-08-20, full scan — supersedes guesses)

Every `mem[i] <=` inside the main always_ff (5951–14911), scanned
mechanically (nested-index aware). These are the arrays Vivado will NOT
put in BRAM today no matter the `ram_style` attribute (8-7186). The
RUN-init region (~6394–6452, S_GOT_HDR2) also pokes many of them — a
Port A conversion must move that init onto the strobe path or the
`heap_clr` walker, not leave a second write port behind.

**Monsters missed by the old recipe (fix these, they survive exec32):**

| Array | Shape | FSM writes | Note |
|---|---|---|---|
| `vgc_queue` | 3072×64 = 192 Kb | 4 | **Biggest miss.** Value64 GC mark queue — stays after exec32. |
| `vfn_env` | 1024×64 | 4 | closure env per fn |
| `vfn_bound_this` | 1024×64 | 4 | bind() this per fn |
| `venv_parent` | 512×64 | 1 | env parent chain |
| `vconsts` | 1024×64 | 1 (6986) | already in recipe |
| `vobj_proto` / `vfn_proto` | 1024×64 each | 4 / 5 | already in recipe |

**Narrow-table swarm (6–16 bits × 1024–1536; individually small, ~150 Kb
+ mux LUTs in total — Port A opportunistically after the wide ones):**
`vobj_len`(11 wr) `vobj_cls`(5) `vobj_gen` `vobj_builtin`(11)
`vfn_entry/nparam/gen/valid` `varr_gen/lidx` `venv_gen/len/valid`
`vvar_valid` `name_off/blen` `name_len_tbl` `intern_var/_ok` `char_id`.

**Do NOT Port-A these — they die with the exec32 tagged-arm strip
(Phase 3b), converting them is wasted and delays the cut:**
`gc_queue` (16384×14 = **224 Kb**, the single biggest LUTRAM item),
`stack`/`stack_tag` (2048), `vars`/`var_tag`/`var_init` (512),
`obj_n`/`obj_cls`, `tfn_entry/nparam/parent/this`, `tenv_parent`,
`arr_len`, `env_oid`/`env_free`. Total ≈ 430 Kb of would-be LUTRAM
that simply vanishes.

**Fine as-is (small):** `vframe_*` (128), `vtimer_*` (64), listener/kd/ku
slots, exec64 internals (`cls_*` 16×16). `vstack`/`vvars`/`venv_slot`/
`vobj_slot`/`varr_slot`/`code_mem`/`name_mem`/`json_mem`/`imgd_pix`/
`spr_mem` already use the strobe pattern (write via `*_wr` task strobes
+ dedicated process) — verified clean.

## Port A recipe

| Array | File | Miss | Fix |
|---|---|---|---|
| `source_mem` 128K×8 | `rtl/engines/jmr_console_engine.sv` | Reset + gated read in the RAM process (AR 58025). 2026-08-20: `RAM256X1S × 4096` | `if (src_we) source_mem[src_addr] <= src_wdata; src_rdata <= source_mem[src_addr];` **no reset** in that block. |
| `vconsts` 1024×64 | `rtl/engines/jmr_js_vm.sv` | FSM `vconsts[c_i] <=` + mux read | `vconsts_we/waddr/wdata` like `vvars`. Wait `vconsts_rdata`. Same strobes for `e64_poke`. |
| `vobj_proto` 1024×64 | same | FSM poke + mux read | `vobj_proto_wr` like `vobj_alloc_wr`. One write/clock. |

Same pass: `vfn_proto`. If you touch `arr_len` / `vobj_cls` (still FSM-poked,
8-13159), Port A them too. 2026-08-20 also showed `vstack` / `name_mem` /
GC queues as LUTRAM — after exec32, those next if they still miss.

---

## T200 budgets (do not invent counts)

Fill **Used** from `build/nexys_video/utilization_synth.rpt` then
`utilization_impl.rpt` when WNS ≥ 0. `.bin` ~9.3 MB is the whole 200T
image, not fullness. Dual FB + heap must be **BRAM**, not LUTRAM/FFs.
ASET art is off-chip (DDR3 behind the 4 MB SRAM port). MIG FIFOs count
inside the 365.

| Component | Estimate | T200 |
|---|---|---|
| LUTs (if hierarchy holds) | 45k–75k | 134,600 |
| FFs (legal SRAM) | ~15k class | 269,200 |
| Dual FB 640×480×8 | ~0.60 MB / ~133 tiles | 365 tiles / 1.64 MB |
| `imgd_pix` | ~0.30 MB / ~67 | same 365 |
| `spr_mem` (blit scratch, not ASET) | **~0.03 MB / ~7** (was 0.25 MB / ~57 before the 2026-08-21 shrink) | same |
| `source_mem` | **~0.06 MB / ~15** (was 0.13 MB / ~29) | same |
| objects 1024×32×80b | ~0.31 MB / ~71 | same |
| arrays 1536×32+128×128×64b | ~0.50 MB / ~114 | same |
| env 512×16×80b | ~0.08 MB / ~18 | same |
| **If all infer as BRAM** | **~2.2 MB / ~489 tiles** at the 2026-08-20 census; **~420 after** the exec32 cut + shrinks, and Phase 3b removes ~430 Kb more | **365 / 1.64 MB** |

Paper math is a planning tool, not a measurement: several of these arrays
legitimately stay in LUTRAM or get packed. **The synth report is the
truth** — fill the Headline below from it before believing any row here.

---

## Headline (fill after synth_1 100%)

Part `xc7a200tsbg484-1`.

| Resource | Used | T200 |
|---|---:|---:|
| LUTs | — | 134,600 |
|  as LUTRAM | — | 46,200 |
| FFs | — | 269,200 |
| BRAM tiles | — | 365 |
| DSP | — | 740 |
| Slices | — | 33,650 |

LUTRAM high + BRAM low = inference still missed. WNS ≥ 0 is the bit.

---

## Three crashes (do not “fix” the wrong one)

| Crash | Cause | You |
|---|---|---|
| 70 GB hang | `mem[i] <=` in FSM | Never put it back |
| 16:17 OOM | **7** mapping workers | Synth stays **2** |
| 2026-08-20 OOM | 2 workers, netlist still fat | Steps 2–3 above |

Ignore `Synth 8-7052` on `u_fb` (framebuffer **is** BRAM). `tcmalloc large
alloc` ~5 GB = mapping dying. Detail: [OLD_RUNS.md](OLD_RUNS.md).
