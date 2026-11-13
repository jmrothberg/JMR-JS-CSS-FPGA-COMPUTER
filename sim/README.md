# sim/

The RTL simulator. It compiles the root `rtl/` with Verilator, so it runs the
same hardware description as the FPGA. Menus and windows are drawn by that
hardware, not by Python.

| Command (from the repository root) | What it does |
|---|---|
| `make -C sim sim_server_synth` | Builds `sim_build_synth/jmr_js_sim_server`, the simulator the GUI uses (F9 → FPGA-SIM). |
| `python3 sim/user_loop.py` | Boot, open Editor (role 1) on a new document titled untitled, quit to Finder, twice; a game; Compile. Must pass before any FPGA build. |
| `python3 sim/alert_check.py` | A crashing program and a missing program each return to Finder with an alert; Return and Esc dismiss it. |
| `python3 sim/document_check.py` | Editor title is the document name; Save As a new name copies NAME.ICN and NAME.ART; Compile replaces an existing NAME.JSH (stand-in last chain step) and it runs. |
| `python3 sim/esc_check.py` | Esc cancels Save As in the Editor without quitting; three Escs stop a program that hangs. |
| `python3 sim/macwrite_check.py` | MacWrite saves and reopens a `.WRT`; MacPaint saves and reopens a `.PNT`. Builds its own card and does not touch `card.img`. |
| `python3 sim/cpi_profile.py [out.json]` | VM clocks per instruction, by opcode, for Finder idle, Finder with the mouse moving, Space Invaders, Donkey Kong and MacPaint drawing (40 frames each, about 30 minutes). `JMR_SIM_BUILD=<dir>` profiles another simulator build. Builds its own card. |
| `make -C sim tb_mouse_packet_merge` (and other `tb_*` targets) | Checks one device. |

| File | What it is |
|---|---|
| `sim_main.cpp` | Connects the RTL to a simulated card, memory and the GUI. |
| `host_sim_server.py` | Python stand-in used only when `JMR_SIM_HOST=1`. |
| `tb_*` | Testbenches for single modules. |
| `*.hex` | ROM images copied from `vectors/` by the build. |
| `sim_build_synth/` | Generated. |

The simulator uses `card.img` unless `JMR_CARD_IMG` names another image; saving changes that image.

The build sets `BOOT_CLOCK_HZ=1000000` so the startup screen does not take
minutes of wall time. Nothing else is scaled. For board-length timers:
`make -C sim sim_server_synth -B JMR_SIM_PARAMS=BOOT_CLOCK_HZ=100000000`.

`SRAMFILL <word-address> <word-count> <value>` is a simulator-only command that
fills external RAM, to expose code that depends on memory starting at zero.
