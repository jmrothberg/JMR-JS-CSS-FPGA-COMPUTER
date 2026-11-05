# RTL simulator

Build from the project root: `make -C sim sim_server_synth`.
Launch `.venv/bin/python gui_jmr_js.py`; F9 selects **FPGA-SIM (RTL)**.
The normal executable is `sim_build_synth/jmr_js_sim_server`.
The previous one is `sim_build_ui_parity/`. The last simulator from before
the desktop is `sim_build_run73p_ddr_manual/`. Older builds are in
`../to_delete/sims/`.

The simulator runs the same `rtl/` code as the FPGA. Menus/windows/dialogs
are hardware pixels, not Python drawings. It uses the normal `card.img` unless
`JMR_CARD_IMG` names a different disk; saving changes that disk.

`sim_main.cpp` connects the RTL to the simulated card, memory and GUI transport.
`tb_*` files check individual devices. `sim_build_*` folders are generated builds.

## Finder startup

The GUI uses `FRAME 500000` for system applications so a long paint yields to
mouse/keyboard processing. Plain `FRAME` keeps the existing game behavior.
Bounded slices advance deferred key-release accounting only on completed
frames. Loading also uses bounded clock batches.

The default simulator build sets `BOOT_CLOCK_HZ=1000000` for the cosmetic
startup-screen timer only. Software simulation cannot execute 100 million RTL
clocks per wall-clock second. VM, disk, memory and drawing logic are unchanged;
the board keeps its 100 MHz timer setting. For exact board-duration timer tests:
`make -C sim sim_server_synth -B JMR_SIM_PARAMS=BOOT_CLOCK_HZ=100000000`.
Rebuild normally afterwards to restore the interactive simulator setting.

Test-only `SRAMFILL <word-address> <word-count> <u16-value>` seeds external RAM
to expose uninitialized-state bugs. It does not represent a hardware command
or alter normal boot contents. The cold-Finder regression uses nonzero RAM.

Dual physical mouse report regression: `make -C sim tb_mouse_packet_merge`
from repository root. Covers simultaneous movement, combined buttons, queued
reports and idle backup behavior; physical port wiring still requires a board.

### Resident Toolbox (run77b)

`sim_server_synth` includes the native-JavaScript Toolbox instruction bank.
The `toolbox_code0.hex` and `toolbox_code1.hex` files copied from vectors/
initialize 3072 physical instructions (three BRAM tiles). The remaining 1024
virtual prefix words are fixed jump padding. `toolbox_code.hex` is the complete
4096-word host/linker view.
Boot loads a validated TOOLBOX.ROM before SYSTEM.SYS. `SYS?` reports both statuses
(1 valid, 2 absent, 3 invalid); ROM absence leaves the factory bank intact.
CODEPEEK and the prefetch assertion follow virtual-to-resident code mapping.
Use the matched run77b disk for the TBDEMO software-menu example. The current
call/linking guide is docs/RESIDENT_TOOLBOX.md. RTL tests are
`tests/test_toolbox.py`, `tests/test_toolbox_resident.py` and `sim/tb_toolbox.sv`.
