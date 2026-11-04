# FPGA versions

The bits we are keeping live with their builds, not in a pile of older runs.

- **Rollback bit:** [build/run75_program_system](../build/run75_program_system/release/README.md).
- **Build in progress:** [build/run76_usb_keyboard_pmod_mice](../build/run76_usb_keyboard_pmod_mice/README.md). No qualified `.bit` yet.
- **Still in QSPI:** [current/](current/README.md) is run73o until the board is flashed again.
- Older bits and the optional Donkey zip are in `to_delete/releases_archive/` and `to_delete/releases_extras/`.

`current/fpga.bit` is the run73o file that was flashed. [standard.json](standard.json) records that selection.

Use this existing repository on `main`. Do not create branches, extra repositories, or worktrees to save a release. Old experiments are in `to_delete/`.
