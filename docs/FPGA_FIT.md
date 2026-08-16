# How JMR JS fits the T200 (and would fit a T100)

Same job as the BASIC sibling’s `docs/FPGA_FIT.md` (`JMR-BASIC-FPGA-COMPUTER`):
measured Vivado numbers, not estimates. Do not invent LUT counts.

This bitstream is built for **Nexys Video / XC7A200T** (“T200”). The T100 column
is the **same used counts** against **Nexys A7-100T / XC7A100T** budgets — “would
it fit,” not a T100 `.bin` from this repo.

**Authoritative report:** `build/nexys_video/utilization_impl.rpt` after
`make -C tools/board_flow bit`. Companion: [FPGA_BRINGUP.md](FPGA_BRINGUP.md),
[ARCHITECTURE.md](ARCHITECTURE.md), live status [SESSION_HANDOFF.md](SESSION_HANDOFF.md).

The `.bin` file is ~9.3 MB because that is the **200T configuration image size**,
not how full the chip is.

## Same RTL for FPGA-SIM, `.bin`, and ASIC

**This rule is for every language-native FPGA-SIM** (this JS machine, a BASIC
update, a later native GPU): Verilator is not a second architecture. If the
array cannot become FPGA block RAM / an ASIC SRAM macro, do not ship it in
`rtl/` even when titles look good in sim.

FPGA-SIM (Verilator) and `make -C tools/board_flow bit` compile the **same**
`rtl/*.sv`. There is no synth-only VM. `SYNTHESIS` in the board top is I/O
(clocks, HDMI), not a second heap. ASIC later uses the same **SRAM ports**
(address, we, wdata, registered rdata, 1–2 ports); `ram_style = "block"` is a
Vivado hint, not a Xilinx primitive inside the VM.

Clock class is **~30 MHz** (BASIC native needed work to hold that; do not
assume 100 MHz). Sequential SRAM keeps that clock. A combinational
`for (k)` heap mux would **worsen** WNS. Extra GET_PROP clocks (~1 µs worst
case at 30 MHz vs 16.7 ms/frame) are playable; combo heaps are not a speed
win.

**How memories must be coded** (FPGA BRAM and ASIC SRAM macros):

- 1-D arrays, one write + one registered read (true dual-port only for
  CPU+scanout, e.g. char VRAM / mini-FB). Dump shares the CPU read port.
- No reset `for` that writes every cell in one cycle — walk CLS instead.
- Object/array slot scans over clocks; not a combinational compare of all slots.
- Forbidden: `` `ifdef SYNTHESIS `` smaller heaps, combo sim vs BRAM board,
  LUTRAM for megabit arrays, shrinking HTML to fit.
- **Capacity:** T200 ≈ **365** RAMB36 ≈ **1.64 MB**. Dual 640×480×8 FB ≈
  **0.6 MB**. Leftover ≈ **1 MB** for code + JS heap + console. Legal slot
  BRAMs: `MAX_OBJ=1024` × 32 × 80b ≈ 320 KB plus `MAX_ARR=512` × `ARR_CAP=128`
  × 64b ≈ 512 KB plus `ENV_DEPTH=512` × 16 × 80b `venv_slot` ≈ 80 KB
  (PYTHON `hardware_model/js_vm.py` matches). Ten live nested number-array
  maps need >256 arrays; env depth 512 is the BRAM trade. The 8192 / 4096
  / 128 depths were ~**7 MB** — same class of fake as combo 2-D (Verilator
  runs; the chip cannot). Overflow loud. External **4 MB** SRAM is **ASET
  art only** — do not put JS heap there or bump that bank to 8 MB.
- **Vivado SV:** no nested part-select (`rdata[79:64][9:0]` → Synth 8-2599).
  Use `rdata[73:64]` or a wire. No 2-D env table (`venv_val[h][k]` →
  Synth 8-4556 at 1,048,576 bits). No `for (i = j; i < N)` (Synth 8-3380;
  rewrite `for (i = 0; i < N) if (i >= j)`). No nested `for` over
  `ENV_DEPTH` (walk `S_REL_ENV` / find-free FSMs). `vstack` 1W1R like
  `vobj_slot` (Synth 8-7186 if combo/multi-port). No `function automatic`
  peek from the giant `unique case` (Synth 8-660 `vst_at`); combo `vst_peek`
  wire + TOS window FFs only — not a third BRAM port.

**Heap flatten (2026-08-16):** 1-D `vobj_slot` / `varr_slot` / `venv_slot` 1W1R,
`S_HEAP_*` (env via `hp_env`, stop at `venv_len`). Nested select at stringify
is `vobj_rdata[73:64]`. Caps are the leftover-BRAM depths above. `cls_mname` /
`cls_mip` stay 16×16 (4 Kbit method table, not a JS heap). Do not bump asset
SRAM to 8 MB.
`utilization_impl.rpt` after a successful `make -C tools/board_flow bit`
(other agent, after user F9). Pre-flatten probe: Synth 8-4556 `vobj_key`
4.2 Mbit. After env flatten, synth reached ~7 min then died on loops
(8-3380 `remove_key_listener`, 1024×1024 `release_env_to`) and `vstack`
8-7186. Those are now FSM / 1W1R. Next gate was Synth 8-660 `vst_at`
(function from unique case) — now `vst_peek` wire. `$readmemh` font lives
beside `rtl/engines/jmr_js_vm.sv`. Board asset SRAM is MIG DDR3 behind
`jmr_ddr3_sram_bridge` (not `jmr_sram_model` in leftover BRAM). Palette BRAM
is dual-clock; HDMI game mode reads it.

---

## Headline (impl, 2026-08-13 03:36, routed)

These counts are the **last published bitstream**, not the 08:49+ RTL (native
640×480 dual FB + card `.JSB` load). Refresh from `utilization_impl.rpt`
after the next WNS≥0 impl before quoting new %. Do not invent counts.

Design: `top_nexys_video` · part: `xc7a200tsbg484-1` · source:
`build/nexys_video/jmr_nexys_video.bin`

| Resource | What it is | Used | T200 budget (XC7A200T) | T200 | T100 budget (XC7A100T) | T100 |
|---|---|---:|---:|---:|---:|---:|
| **LUTs** | Lookup tables — the actual **logic** (AND/OR/mux/small ROM). One LUT ≈ one 6-input function. | **33,639** | 134,600 | **25.0%** | 63,400 | **53.1%** |
|  as logic | Combinational compute (ALU, FSMs, muxes). | 20,895 | 134,600 | 15.5% | 63,400 | 33.0% |
|  as distributed RAM (LUTRAM) | LUTs used as **tiny memories** instead of logic. Mini-FB / work RAM fell back here (synth could not infer BRAM). | **12,744** | 46,200 | 27.6% | ~19,000 | **~67%** |
| **FFs** | Flip-flops — **1-bit registers** that hold state across clocks. | **12,872** | 269,200 | **4.8%** | 126,800 | **10.2%** |
| **BRAM** | Block RAM tiles — dedicated 36 Kb memory blocks (not LUTs). | **2** tiles (1× RAMB36 + 2× RAMB18) | 365 | **0.5%** | 135 | **1.5%** |
| **DSP** | Hard multiply/add blocks (DSP48). | 7 | 740 | 1.0% | 240 | 2.9% |
| **Slices** | Physical **packing boxes** on the die. Each 7-series slice holds 4 LUTs + 8 FFs. Vivado occupies a whole slice even if it only uses part of it, so slice % is usually **higher** than LUT %. Not a thing you write in RTL — it is place-and-route density. | **11,210** | 33,650 | **33.3%** | 15,850 | **70.7%** |

**Read the chart:** LUTs / FFs / BRAM are the real “how big is the design.”
**Slices** are “how many of those 4-LUT boxes did the placer fill.” A design can
be 53% LUTs and ~71% slices on a T100 because packing is never 100% dense, and
LUTRAM can only sit in **SLICEM** boxes (a subset of slices).

---

## Fit verdict

- **T200 (this board):** comfortable. LUTs 25%, slices 33%, FFs/BRAM almost unused.
- **T100 (projection):** counts still fit. Tightest rows are **LUTRAM (~67%)** and
  **slices (~71%)**, not BRAM. A T100 place-and-route could still fail on
  congestion even though LUT/FF/BRAM math looks OK.
- BRAM is almost empty on **this** (03:36) bit because the mini-FB did **not**
  map to block RAM. Morning RTL puts native 640×480 dual FB in BRAM — refresh
  this table after that impl; do not quote these BRAM counts for the new RTL.

---

## Easy mistakes

- **Synth ≠ fit.** Use `utilization_impl.rpt` (routed), not the synth report.
- **`.bin` megabytes ≠ utilization.** The file is the whole 200T config image.
- **Do not copy BASIC LUT history** into this product. Method only.
- **FPGA-SIM green ≠ synthesizable.** Verilator will simulate 2-D combo heaps that
  Vivado rejects (`Synth 8-4556`) and that ASIC SRAM cannot implement.
- **First T200 bit is the slow one.** MIG + full VM synth; later `make -C
  tools/board_flow bit` reuses the project. `bit-fresh` / `clean` = pay first-build
  again. See [FPGA_BRINGUP.md](FPGA_BRINGUP.md).
