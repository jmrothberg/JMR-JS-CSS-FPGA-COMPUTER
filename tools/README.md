# Tools

Host programs for the card, the board build, and checks. They are not the
computer. The machine loads `card.img`.

| Folder or script | What it is |
|---|---|
| `make_sd_image.py` | Build `card.img` from `storage/` and mint each `.JSH`. Updates `CURRENT_SET.json` for the project card. |
| `update_current_set.py` | Rewrite `CURRENT_SET.json` (the hash list the GUI checks) from the files present; `--bit` records a qualified bitstream. |
| `compile_js.py` | Compile one HTML file and print the size walls. |
| `check_port.py` | Same size check before a title is edited further. |
| `make_artx.py` | PNG sheets to the art sidecars a title loads. It also writes the Chrome `.ARTJS`, which stays on the host (build 96 does not put it on the card). |
| `prepare_port.py` | Copy a game into a new directory without changing its bytes. |
| `pick_icon.py` | Choose a desktop icon when a title does not have one. `desktop_icons.py` converts that picture. |
| `make_classic_icons.py` | Draws the black and white MacPaint and MacWrite icons and the document icons (`PNTDOC`, `WRTDOC`, `BASDOC`) as `storage/NAME.ICON`. |
| `build_system_resources.py` | Pack `resources/system/system.json` into `SYSTEM.SYS`. |
| `export_classic_ui.py` | Generate the RTL tables for the shared menus and dialogs. |
| `export_desktop.py` | Desktop rectangles into `jmr_desktop_layout_pkg.sv`. |
| `export_system_menu.py` | Keyboard grid and glyphs into `jmr_system_menu_pkg.sv`. |
| `export_font_rom_hex.py` | READY font into `vectors/font_rom.hex`. |
| `export_reader_font.py` | Markdown-reader sprite from `assets/desktop/`. |
| `selfhost.py` | Size check for the on-machine compiler titles. Tests call it. |
| `toolbox_linker.py` | Link `resources/toolbox/` into `TOOLBOX.ROM`, `TOOLBOX.LNK` and `vectors/toolbox_code*.hex`. |
| `toolbox_state.py`, `toolbox_manifest.py` | Linker passes: group library state per application; version the linked identities. |
| `sync_toolbox_clients.py` | Keep the shared Toolbox client scripts identical in every HTML program. |
| `software_ui.py`, `materialize_software_ui.py` | Turn declarative menu and window markup into Toolbox calls. |
| `build_paint_resources.py` | Pack MacPaint artwork from `resources/macpaint/` into its resource file. |
| `make_artjs.py` | Chrome-side art for a title, from its `.ARTX`. |
| `golden_frames.py` | Compare a title's picture in Chrome, Python and FPGA-SIM. |
| `generate_architecture_diagram.py` | Regenerate `docs/diagrams/`. |
| `gui_runtime.py`, `simulator_provenance.py` | GUI start-up checks: which card and simulator to use, and that the simulator matches `rtl/`. |
| `verify_current_set.py`, `audit_toolbox_release.py` | Check the source tree and a card against `CURRENT_SET.json`. |
| `inventory_ui_migration.py` | List which programs still use a hardware UI service. |
| `board_flow/` | Vivado build. See [board_flow/README.md](board_flow/README.md). |
| `mouse_probe/` | Small bit that only checks the keyboard and mouse jacks. |
| `pmod_input_test/` | LED proof that a Pmod plug is alive. Not FPGA-SIM. |
| `hid_led_blink/` | LED proof that J15 is delivering PS/2 bytes. Not FPGA-SIM. |
| `audio_beep_test/` | Board beep check. |
| `psg_bench/` | Sound-chip bench. |
| `desktop_icons.py` | Turns a picture into the 32×32 `.ICN` the card builder writes. |
| `make_finder_about_art.py` | Builds the Enterprise stencil in Finder's About box from `resources/system/art/`. |
| `make_prince_art.py` | Builds Prince's four sheets from the Apple II level layout and the Macintosh paintings. |
| `make_vigil_art.py` | Draws Vigil's sheets. Vigil is not in `storage/` yet. |
| `tether_put.py` | Sends files to the board's card over USB. Same path as the GUI's F8. A file over 512 KB that is already on the board has to be in the Trash first (build 96). |
| `vigil_parity.py`, `vigil_fpga_check.py`, `vigil_probe.py`, `vigil_shots.py` | Compare and play Vigil on the Python model and the simulator. |

The LED and probe folders are separate small designs; they are not part of the computer's source list.
