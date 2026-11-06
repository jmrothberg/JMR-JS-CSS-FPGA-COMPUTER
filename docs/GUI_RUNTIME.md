# One matched GUI runtime

Start `python3 gui_jmr_js.py` from a checkout with dependencies installed.
The GUI loads the root Python source and root `card.img`. No private build
manifest or RTL executable is required to start the Python backend.

Both Python and FPGA-SIM execute the serialized `FINDER.JSH` and other programs
from that disk, with its resident Toolbox. Python does not recompile Finder at
startup. The launcher checks disk resources against `CURRENT_SET.json` and
checks resident program instructions against the disk ROM before opening the GUI.
It preserves user documents and never rebuilds or copies a disk at startup.

FPGA-SIM requires a native simulator built on the current machine with
`make -C sim sim_server_synth`. It uses the same root `card.img` through
`JMR_CARD_IMG`. Missing RTL is an error when selecting FPGA-SIM; it is not a
Python startup requirement. Python behavior is not FPGA timing evidence.
No run81 FPGA bitstream is qualified yet.
