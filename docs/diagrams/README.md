# Diagrams

[Architecture PNG](rarchitecture.png) is the layered architecture: Finder and applications,
the complete public resident Toolbox call list, system services, SYSTEM.SYS
resources, and FPGA mechanisms. Its active-set banner tracks the single current
RTL/software/disk/bitstream candidate; build qualification remains separate.
[Memory-map PNG](memory-map.png) holds the detailed 8 MiB physical ranges and explains how
logical Toolbox addresses differ. Keeping it separate makes the architecture
easier to read.
[System resources PNG](system-sys.png) is the `SYSTEM.SYS` path.
[Event listeners PNG](listener_table.png) is the 16-slot `addEventListener` table.

PNG is the viewing format for the user's iPhone. Editable SVG sources remain
alongside each PNG. `python3 tools/generate_architecture_diagram.py` regenerates
the architecture/memory sources and exports every diagram at 2× resolution;
install the dependencies from `requirements.txt` first.

Layer ownership, Macintosh differences and their rationale, and memory sizes
are in [../lastrun_ARCHITECTURE.md](../lastrun_ARCHITECTURE.md). Release/build
status is in [../FPGA_FIT.md](../FPGA_FIT.md) and
[../TOOLBOX_IMPLEMENTATION_STATUS.md](../TOOLBOX_IMPLEMENTATION_STATUS.md).
Jacks: USB keyboard on J15, PS/2 mouse on JA, second mouse on JC, joystick on JB.
