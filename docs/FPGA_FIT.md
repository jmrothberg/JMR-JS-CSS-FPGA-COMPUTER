# T200 fit — agent handoff (do not crash, do not overflow)

Nexys Video **XC7A200T**. Agent does **not** run Vivado / `make bit` — the
user does, after this RTL lands. Same `rtl/*.sv` as FPGA-SIM.
Law: `.cursor/rules/never-fake-fpga-sim.mdc`. Extra clocks OK. One JS
heap. No JOIN/JSON/GC extract. Clock class ~30 MHz.

Diaries of failed runs: [OLD_RUNS.md](OLD_RUNS.md). Live glass:
[SESSION_HANDOFF.md](SESSION_HANDOFF.md).

---

## What you do (so the next `make bit` does not OOM)

### Cleanup before the next `make bit` (2026-08-20 OOM)

2026-08-20 mapping **OOM'd at 2 synth threads**. Capping workers is
**not enough**. Shrink the netlist, then the user rebuilds.

**Glass is done.** All five HTML titles play on FPGA-SIM (INVADERS,
PACMAN, DONKEY, ASTEROID, MRDO). They are **slow** (clocks per frame /
FIND / 1 px per fillRect) — that is not this job. Do not reopen play
bugs. Do not mix a speed pass with 2–3 on `jmr_js_vm.sv`.

| Order | Job | Why |
|---|---|---|
| 1 | Unhook **exec32** | Idle tagged decoder + `stack` 2K×32 still mapped as LUTRAM. How: [REMOVING_EXEC32.md](REMOVING_EXEC32.md) |
| 2 | **Port A** the LUTRAM monsters | Big arrays built from logic LUTs make mapping hungry. `source_mem` first, then `vstack` / `name_mem` / `gc_queue` / `vgc_queue` if still LUTRAM. Recipe [below](#port-a-recipe). |
| 3 | Stop. User `make bit` (synth **2** threads, impl **8**) | Fill [Headline](#headline-fill-after-synth_1-100). LUTRAM high + BRAM low = template still missed |

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
  T200. Tiny 8-deep FOREACH/rAF may stay LUTRAM. Do not Port-A tagged
  `stack` (it goes away with exec32).
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
| `spr_mem` (blit scratch, not ASET) | ~0.25 MB / ~57 | same |
| `source_mem` | ~0.13 MB / ~29 | same |
| objects 1024×32×80b | ~0.31 MB / ~71 | same |
| arrays 1536×32+128×128×64b | ~0.50 MB / ~114 | same |
| env 512×16×80b | ~0.08 MB / ~18 | same |
| **If all infer as BRAM** | **~2.2 MB / ~489 tiles** | **365 / 1.64 MB — over** |

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
