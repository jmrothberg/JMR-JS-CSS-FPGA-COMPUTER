# scripts/

Linux helpers: `vivado_env.sh`, setup helpers, smoke gates.

**Order:** perfect FPGA-SIM first (`make -C sim sim_server_synth` +
`tools/check_runtime_parity.py`). Only then source Vivado and build/flash.

See [docs/LINUX_WORKSTATION.md](../docs/LINUX_WORKSTATION.md) and
[docs/SESSION_HANDOFF.md](../docs/SESSION_HANDOFF.md).
