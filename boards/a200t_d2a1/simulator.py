#!/usr/bin/env python3
"""Open the shared JS RTL simulator on the project card image."""
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))


def main():
    os.chdir(ROOT)
    os.environ.pop("JMR_SIM_HOST", None)
    os.environ.pop("JMR_SIM_BUILD", None)
    os.environ.pop("JMR_PYTHON_ONLY", None)
    os.environ.pop("JMR_CARD_IMG", None)
    from tools.gui_runtime import configure
    configure(ROOT)
    import gui_jmr_js as gui
    # C3 UART is occupied by USB HID. Vision's FT245 board connection must
    # never appear as though it is the A200T board in this test window.
    gui._try_board_backend = lambda: None
    gui._try_asic_backend = lambda: None
    app = gui.App()
    app.root.title("A200T JS Computer — FPGA Simulator")
    app._fkey_t = 0
    app._gui_t0 = 0
    if len(app.backends) < 2:
        app.root.destroy()
        raise SystemExit("Build the shared RTL simulator first: make -C sim sim_server_synth")
    app.cycle_runtime()
    app.run()


if __name__ == "__main__":
    main()
