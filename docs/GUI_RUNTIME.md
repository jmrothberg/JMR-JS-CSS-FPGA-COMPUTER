# One matched GUI runtime

Start `python3 gui_jmr_js.py` from a checkout with dependencies installed.
The GUI loads the root Python source and root `card.img`. No private build
manifest or RTL executable is required to start the Python backend.

Both Python and FPGA-SIM execute the serialized `FINDER.JSH` and other programs
from that disk, with its resident Toolbox. Python does not recompile Finder at
startup. The launcher checks disk resources against `CURRENT_SET.json` and
checks resident program instructions against the disk ROM before opening the GUI.
It preserves user documents and never rebuilds or copies a disk at startup.

FPGA-SIM uses the verified local `sim/sim_build_synth/jmr_js_sim_server`.
On this machine it is the exact tested run81 simulator, with matching startup
hex files. On another machine, build a native simulator with
`make -C sim sim_server_synth`. It uses the same root `card.img` through
`JMR_CARD_IMG`. A build receipt checks the executable, root RTL, simulator source and startup
hex before launch. Changed or missing inputs require rebuilding; an old local
binary cannot silently run as current. Missing RTL is an error when selecting
FPGA-SIM; it is not a
Python startup requirement. Python behavior is not FPGA timing evidence.
Run81 implementation fits the resource limits but failed setup timing by
1.652 ns. Its bitstream is unqualified; the next hardware build is held for
architecture review. Passing simulation does not waive timing requirements.
