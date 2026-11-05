# Tools

Host programs for the card, the board build, and checks. They are not the
computer. The machine loads `card.img`.

| Folder or script | What it is |
|---|---|
| `make_sd_image.py` | Build `card.img` from `storage/` and mint each `.JSH`. |
| `compile_js.py` | Compile one HTML file and print the size walls. |
| `check_port.py` | Same size check before a title is edited further. |
| `make_artx.py` | PNG sheets to the art sidecars a title loads. It also writes the Chrome `.ARTJS`. |
| `prepare_port.py` | Copy a game into a new directory without changing its bytes. |
| `pick_icon.py` | Choose a desktop icon when a title does not have one. `desktop_icons.py` converts that picture. |
| `build_system_resources.py` | Pack `resources/system/system.json` into `SYSTEM.SYS`. |
| `export_classic_ui.py` | Generate the RTL tables for the shared menus and dialogs. |
| `export_desktop.py` | Desktop rectangles into `jmr_desktop_layout_pkg.sv`. |
| `export_system_menu.py` | Keyboard grid and glyphs into `jmr_system_menu_pkg.sv`. |
| `export_font_rom_hex.py` | READY font into `vectors/font_rom.hex`. |
| `export_reader_font.py` | Markdown-reader sprite from `assets/desktop/`. |
| `selfhost.py` | Size check for the on-machine compiler titles. Tests call it. |
| `board_flow/` | Vivado build. `make -C tools/board_flow bit` is the owner's step, not an agent's. |
| `mouse_probe/` | Small bit that only checks the keyboard and mouse jacks. |
| `pmod_input_test/` | LED proof that a Pmod plug is alive. Not FPGA-SIM. |
| `hid_led_blink/` | LED proof that J15 is delivering PS/2 bytes. Not FPGA-SIM. |
| `audio_beep_test/` | Board beep check. |
| `psg_bench/` | Sound-chip bench. |

`golden_frames.py` compares a title's picture with a saved frame.
Do not add those LED proofs to the JS computer's source list.

These are not the current build. Leave them until a measurement needs them again:

| Script | What it was |
|---|---|
| `check_runtime_parity.py` | Old full battery. The gate is `pytest`. Do not call a run of this a pass. |
| `measure_game_rtl.py`, `profile_game_workload.py`, `build_ddr_latency_sim.py` | How the numbers in `docs/GAME_SPEEDUP_RESULTS.md` were taken. |
| `board_flow/run73o_finalize.tcl`, `run73o_repair_cascade.tcl` | How the run73o bit was finished. The current build is `vivado_build.tcl`. |

`mkbig.py`, `verify_game_speedups.py`, and `board_flow/close_wns.tcl` are in `to_delete/tools/`. The packer read `storage/MK.HTML`, which is gone. The other two are one-shot checks with nothing left to call them.

`toolbox_linker.py` builds the resident native-JavaScript library as TOOLBOX.ROM
and the FPGA factory hex files. HTML marked `jmr-toolbox: resident-v1` is linked
by `compile_js.py`; unmarked programs retain the ordinary compilation path.
After changing library code, relink its clients and publish their matching ROM.
See `docs/RESIDENT_TOOLBOX.md` for the contract and complete menu/dialog example.
`make_sd_image.py` includes .ROM in disk creation and transfer.
