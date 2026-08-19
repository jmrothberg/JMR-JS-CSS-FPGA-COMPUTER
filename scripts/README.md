# scripts/

Linux helpers: `vivado_env.sh`, setup helpers, smoke gates.

**Order:** perfect FPGA-SIM first (`make -C sim sim_server_synth` +
`tools/check_runtime_parity.py`). Only then source Vivado and build/flash.

`source scripts/vivado_env.sh` then `make -C tools/board_flow bit`.
Synth **2 threads** (16:17 mapping OOM at 7 workers). Impl **8 threads**.
Do not raise synth threads. Never `bit-fresh` unless MIG/XDC/file list
changed. After synth_1 100%, `post_synth.dcp` exists — mapping cannot
resume mid-step.

See [docs/LINUX_WORKSTATION.md](../docs/LINUX_WORKSTATION.md) and
[docs/SESSION_HANDOFF.md](../docs/SESSION_HANDOFF.md).
