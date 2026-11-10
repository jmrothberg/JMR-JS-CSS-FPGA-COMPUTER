# runtime/

The GUI's three back ends. Each gives the GUI the same interface to a machine.

| File | Machine |
|---|---|
| `backend.py` | Shared interface and the Python model back end. |
| `sim_backend.py` | The Verilator simulator in `sim/`. |
| `board_backend.py` | The FPGA board over the USB PROG cable. |
| `finder_tether.py` | The Finder service protocol the simulator and board back ends share. |
| `asic_sim_backend.py` | Empty slot for a future ASIC simulator. |
| `flight_log.py` | Writes a session log to `traces/`. |
| `vm_state_names.py` | VM state numbers to names. |
| `active_gui.json` | Which source, card and simulator the GUI uses. |
