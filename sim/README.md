# RTL simulator

Build from the project root: `make -C sim sim_server_synth`.
Launch `.venv/bin/python gui_jmr_js.py`; F9 selects **FPGA-SIM (RTL)**.
The normal executable is `sim_build_synth/jmr_js_sim_server`.

The simulator runs the same `rtl/` code as the FPGA. Menus/windows/dialogs
are hardware pixels, not Python drawings. It uses the normal `card.img` unless
`JMR_CARD_IMG` names a different disk; saving changes that disk.

`sim_main.cpp` connects the RTL to the simulated card, memory and GUI transport.
`tb_*` files check individual devices. `sim_build_*` folders are generated builds.
The old simulator is preserved at `../build/rtl_system_parity/jmr_js_sim_server_before`.
Current UI acceptance logs and screenshots are under `../build/rtl_system_parity/`.
