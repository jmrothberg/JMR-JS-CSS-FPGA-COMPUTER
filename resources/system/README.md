# Editable system appearance

Edit `system.json`, then run from the project root:

```sh
.venv/bin/python tools/build_system_resources.py --image card.img
```

This writes `storage/SYSTEM.SYS` and replaces only `SYSTEM.SYS` on the simulator
card. Close and reopen `gui_jmr_js.py`, then use F9 to select FPGA-SIM. It reads
resources at startup. No Verilator, Vivado or `.bit` build is needed after a
resource-only edit. Python reads the same binary from its mounted disk.

- `system.json`: the editable source (JSON data, not JavaScript).
- `defaults.json`: reference for the built-in fallback; leave it alone when
  making disk-only changes. Changing it is a hardware-default maintenance task.

See [SYSTEM_RESOURCES.md](../../docs/SYSTEM_RESOURCES.md) for the exact limits,
examples and a ready-to-copy instruction for an agent.
