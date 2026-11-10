# functional_model/

The machine in Python: the JavaScript compiler, the bytecode it emits, and a
model of every engine. The GUI's Python mode runs this; the card builder uses
its compiler to make each `.JSH`.

| File | What it is |
|---|---|
| `compiler.py`, `bytecode.py`, `jsb_format.py` | JavaScript → bytecode → `.JSH` file. |
| `html_loader.py` | Pulls the script out of an HTML program. |
| `machine.py` | The whole computer; ties the engines together. |
| `canvas_engine.py`, `input_engine.py`, `storage_engine.py`, `sram_engine.py`, `memory.py`, `memory_map.py` | One engine each. |
| `toolbox.py`, `toolbox_rom.py` | Resident Toolbox calls and their ROM. |
| `desktop.py`, `classic_ui.py`, `system_menu.py`, `system_window.py`, `system_resources.py`, `desktop_icons.py`, `font8.py` | Finder, menus, windows, fonts. |
| `console.py`, `trace.py` | Text console of the Python model; tracing. |
| `js_host.py` | Runs a program's JavaScript in dukpy as a reference picture. It is not the machine. |
| `add_proof.py` | Compiler pass that proves an addition is numeric. |
| `*_runtime.js` | JavaScript linked into compiled programs. |
