# storage/

Seeds for the machine disk image / demos (FAT32 card image).

| Seed | Role |
|---|---|
| `RECTDEMO.JS` | Hardcoded + bytecode-friendly rects |
| `JOYDEMO.JS` | Joystick-readable demo |
| `INVADERS.JS` (+ `.JSB` via `tools/compile_js.py`) | Native bytecode path on FPGA-SIM / silicon |
| `INVADERS_FULL.HTML` | Full HTML Canvas via dukpy on **PYTHON / host twin only** |

Do not copy BASIC `.BAS` libraries from the sibling repo as the product surface.
Product path: grow bytecode so FPGA-SIM runs real games, then board matches —
dukpy is never “FPGA-SIM.”
