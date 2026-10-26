# scripts/

`scripts/vivado_env.sh` is an optional, local, Git-ignored helper; it is not
shipped in a fresh clone. Set `VIVADO` to your installed, licensed launcher:

```bash
make -C tools/board_flow bit VIVADO="$(command -v vivado)"
```

Use the [standard release](../docs/STANDARD_RELEASE.md) to program the
accepted bitstream without rebuilding.

**Commands and `bit-fresh` hygiene:**
[docs/FPGA_BRINGUP.md](../docs/FPGA_BRINGUP.md) and
[docs/SESSION_HANDOFF.md](../docs/SESSION_HANDOFF.md) § Synthesis.

FPGA-SIM first: `make -C sim sim_server_synth` from repo root.
