# scripts/

`scripts/vivado_env.sh` is an optional, local, Git-ignored helper; it is not
shipped in a fresh clone. Set `VIVADO` to your installed, licensed launcher:

```bash
make -C tools/board_flow bit VIVADO="$(command -v vivado)"
```

Which bitstream to load is [docs/FPGA_FIT.md](../docs/FPGA_FIT.md).
[docs/STANDARD_RELEASE.md](../docs/STANDARD_RELEASE.md) records the VM clock switch. It is not the next file to flash.

**Commands and `bit-fresh` hygiene:**
[docs/FPGA_BRINGUP.md](../docs/FPGA_BRINGUP.md) and
[docs/FPGA_FIT.md](../docs/FPGA_FIT.md).

FPGA-SIM first: `make -C sim sim_server_synth` from repo root.
