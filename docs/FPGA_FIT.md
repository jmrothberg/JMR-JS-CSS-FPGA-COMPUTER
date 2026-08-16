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

FPGA-SIM (Verilator) and `make -C tools/board_flow bit` compile the **same**
`rtl/*.sv`. There is no synth-only VM. `SYNTHESIS` in the board top is I/O
(clocks, HDMI), not a second heap. ASIC later uses the same **SRAM ports**
(address, we, wdata, registered rdata, 1–2 ports); `ram_style = "block"` is a
Vivado hint, not a Xilinx primitive inside the VM.

**How memories must be coded** (FPGA BRAM and ASIC SRAM macros):

- 1-D arrays, one write + one registered read (true dual-port only for
  CPU+scanout, e.g. char VRAM / mini-FB). Dump shares the CPU read port.
- No reset `for` that writes every cell in one cycle — walk CLS instead.
- Object/array slot scans over clocks; not a combinational compare of all slots.
- Forbidden: `` `ifdef SYNTHESIS `` smaller heaps, combo sim vs BRAM board,
  LUTRAM for megabit arrays, shrinking HTML to fit.

**Heap flatten** (`vobj_key` / `vobj_val` / `varr_val` in `jmr_js_vm.sv`) waits
until the FPGA-SIM agent is not editing that file. Until then Vivado cannot
finish synth — that is a measurement, not a missing board script.

**Last synth probe (2026-08-16, current RTL, no `.bin`):**
`ERROR: [Synth 8-4556]` `vobj_key` size **4,194,304** bits (limit 1,000,000)
in `rtl/engines/jmr_js_vm.sv`. Same class: `vobj_val` ≈ 16.8 Mbit,
`varr_val` ≈ 32 Mbit, still 2-D combo heaps. Char VRAM (`jmr_video_vram.sv`)
is 1W1R Port A + HDMI Port B (no mem reset-for). Re-run `make -C tools/board_flow bit`
after heap flatten; quote `utilization_impl.rpt`, not this probe.

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
