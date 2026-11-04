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

## November 4: responsive Finder startup

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
