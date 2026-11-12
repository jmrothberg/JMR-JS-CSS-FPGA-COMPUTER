# The GUI

```sh
JMR_CARD_IMG=card.img .venv/bin/python gui_jmr_js.py
```

One 640×480 window. F8 sends files to the card (same job as `tools/tether_put.py`). F9 cycles the three machines. F10 opens the [Architecture Monitor](ARCH_MONITOR.md). Close this window before `tether_put.py`; only one program can own the USB tether.

| Machine | What runs | Needs |
|---|---|---|
| Python | The Python model in `functional_model/` | nothing else |
| FPGA-SIM | The root `rtl/` compiled by Verilator | `make -C sim sim_server_synth` |
| Board | The Nexys Video over the USB tether | a loaded bitstream |

All three run the programs on `card.img`. Saving a document changes that file.
The GUI never rebuilds the card. FPGA-SIM refuses to start if `rtl/` or
`sim/sim_main.cpp` is newer than the simulator; rebuild it.
Python behaviour is not evidence of FPGA timing.
