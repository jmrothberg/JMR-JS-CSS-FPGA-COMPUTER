# Tools

Host programs for the card, the board build, and checks. They are not the
computer. The machine loads `card.img`.

| Folder or script | What it is |
|---|---|
| `make_sd_image.py` | Build `card.img` from `storage/` and mint each `.JSH`. |
| `compile_js.py` | Compile one HTML file and print the size walls. |
| `check_port.py` | Same size check before a title is edited further. |
| `make_artx.py` | PNG sheets to the art sidecars a title loads. |
| `prepare_port.py` | Copy a game into a new directory without changing its bytes. |
| `pick_icon.py` | Choose a desktop icon when a title does not have one. |
| `build_system_resources.py` | Pack `resources/system/system.json` into `SYSTEM.SYS`. |
| `export_classic_ui.py` | Generate the RTL tables for the shared menus and dialogs. |
| `board_flow/` | Vivado build. `make -C tools/board_flow bit` is the owner's step, not an agent's. |
| `mouse_probe/` | Small bit that only checks the keyboard and mouse jacks. |
| `pmod_input_test/` | LED proof that a Pmod plug is alive. Not FPGA-SIM. |
| `hid_led_blink/` | LED proof that J15 is delivering PS/2 bytes. Not FPGA-SIM. |
| `audio_beep_test/` | Board beep check. |
| `psg_bench/` | Sound-chip bench. |

`golden_frames.py` compares a title's picture with a saved frame.
`measure_game_rtl.py` and `profile_game_workload.py` time a title.
Do not add those LED proofs to the JS computer's source list.
