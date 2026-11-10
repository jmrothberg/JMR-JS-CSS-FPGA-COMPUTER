# vectors/

ROM images the RTL loads at build time. Generated; do not edit by hand.
The simulator and Vivado builds copy them next to the sources.

| Files | Made by |
|---|---|
| `font_rom.hex` | `tools/export_font_rom_hex.py` |
| `desktop_*.hex` | `tools/export_desktop.py` |
| `system_*.hex` | `tools/export_system_menu.py` |
| `classic_*.hex` | `tools/export_classic_ui.py` |
| `toolbox_code*.hex` | `tools/toolbox_linker.py` from `resources/toolbox/` |
| `invaders_jsb.hex` | `tools/compile_js.py`; a program built into the simulator for tests. |
