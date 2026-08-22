# scripts/

Linux helpers: `vivado_env.sh`, setup helpers, smoke gates.

**Order:** perfect **FPGA-SIM** first (the chip simulated: Verilator of the
same `rtl/*.sv`) — `make -C sim sim_server_synth` from repo root; add `-B`
to force Verilator without `clean` — then
`tools/check_runtime_parity.py`. Only then source Vivado and build/flash.

Words: [README.md — Words used](../README.md#words-used-in-this-project).
Board / toolchain: [docs/FPGA_BRINGUP.md](../docs/FPGA_BRINGUP.md)
(the old `LINUX_WORKSTATION.md` was folded into that file). Status:
[docs/SESSION_HANDOFF.md](../docs/SESSION_HANDOFF.md). Fit / next
bitstream: [docs/FPGA_FIT.md](../docs/FPGA_FIT.md).

```bash
source scripts/vivado_env.sh
# NEXT (2026-08-21, once): source list changed + incremental stitch
make -C tools/board_flow bit-fresh
# AFTER that: ordinary bit (not bit-fresh, not make clean) unless the
# source file *list*, MIG (Memory Interface Generator), or XDC changes.
```

Synth **2 threads** (16:17 mapping **OOM** — Out Of Memory — at 7 workers).
Impl **8 threads**. Do not raise synth threads.

**`bit-fresh` is two opposite things:** after a **mid-mapping crash**, do
**not** `bit-fresh` (you throw away MIG/project state and there is no
**DCP** Design CheckPoint until `synth_1` is 100%). After a **file-list
change**, `bit-fresh` **is** required. Full hygiene:
[docs/SESSION_HANDOFF.md](../docs/SESSION_HANDOFF.md) § Synthesis.
