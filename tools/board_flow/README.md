# tools/board_flow/

Vivado build for the Nexys Video. Status, limits and the order of steps: [docs/FPGA_FIT.md](../../docs/FPGA_FIT.md).

| File | What it does |
|---|---|
| `ooc_module.tcl` | Synthesizes one module alone and lists paths too deep to route. |
| `synth_gate.sh` | Synthesizes the root RTL into `build/<name>` and runs `synth_gate.tcl`. |
| `synth_gate.tcl` | Checks the VM survived synthesis, reports logic depth per module, runs `opt_design`. |
| `implement.tcl` | Place and route. |
| `refine.tcl` | Post-route repair for a small setup miss; also fixes hold. |
| `qualify_routed_bit.tcl` | Final timing, DRC and resource checks; writes the bitstream. |
| `Makefile` | `make bit`: all of the above in one Vivado project run. `make flash`: load a bit. |
| `vivado_build.tcl` | The project script behind `make bit` and `synth_gate.sh`. |
| `build_gates.tcl` | Resource-limit checks shared by the scripts. |
| `physical_review.tcl`, `report_hier.tcl` | Placement and per-module utilization reports. |
| `audit_audio_reset.tcl`, `audio_reset_exceptions.xdc` | Check the audio reset clock crossing and apply its two timing exceptions. |
| `mig_a.prj` | DDR3 memory controller settings. |
