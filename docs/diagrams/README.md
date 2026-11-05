# Diagrams

`rarchitecture.svg` is the layered architecture: Finder and applications,
the complete public resident Toolbox call list, system services, SYSTEM.SYS
resources, and FPGA mechanisms. It describes the November 4 development
source; the Toolbox block is not a claim about the older released bits.
`memory-map.svg` holds the detailed 8 MiB physical ranges and explains how
logical Toolbox addresses differ. Keeping it separate makes the architecture
easier to read.
`system-sys.svg` is the `SYSTEM.SYS` path.
`listener_table.svg` is the 16-slot `addEventListener` table.

Layer ownership, Macintosh differences and their rationale, and memory sizes
are in [../lastrun_ARCHITECTURE.md](../lastrun_ARCHITECTURE.md). Release/build
status is in [../FPGA_FIT.md](../FPGA_FIT.md) and
[../TOOLBOX_IMPLEMENTATION_STATUS.md](../TOOLBOX_IMPLEMENTATION_STATUS.md).
Jacks: USB keyboard on J15, PS/2 mouse on JA, second mouse on JC, joystick on JB.
