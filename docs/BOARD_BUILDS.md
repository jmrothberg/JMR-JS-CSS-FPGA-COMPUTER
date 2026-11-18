# Current board builds and project layout

**Build 99 is the shared JS software set.** Vision is the working board
release. The custom A200T D2-A1 on the C3 motherboard is the next board
target. Its bitstream passed timing and is ready for the first hardware test.
Each target has its own `.bit`. Both use the root `card.img` and the same JS
core, Toolbox, programs, and FAT32 microSD layout.

## Where to find things

- [`A200T_D2A1_BRINGUP/`](../A200T_D2A1_BRINGUP/) is the folder to use at
  the bench. It contains `jmr_js_a200t_d2a1.bit`, `jtag.py`, the wiring guide,
  the simulator shortcut, and the reports for this bitstream. The package
  [manifest](../A200T_D2A1_BRINGUP/MANIFEST.json) records the board, build,
  and file checksums. The package uses the project-root disk image.
- [`releases/current/`](../releases/current/) holds Vision's build 99
  `jmr_js_mac.bit` and its timing, resource, and route reports.
  [`CURRENT_SET.json`](../CURRENT_SET.json) records the current source and
  disk hashes and identifies the Vision bitstream.
- [`rtl/`](../rtl/) holds the shared JS computer and Vision's `top_nexys_video.sv`.
  [`boards/a200t_d2a1/`](../boards/a200t_d2a1/) holds the custom board top,
  HyperRAM controller, C3 input decoder, pin and timing constraints, and
  test and build scripts. See the [A200T source guide](../boards/a200t_d2a1/README.md)
  for rebuild instructions.
- [`storage/`](../storage/) is the source for the files on the card. Root
  [`card.img`](../card.img) is the working build 99 image shared by both
  boards and the simulator. You can move the existing build 99 microSD
  between boards with power off.
- [`sim/`](../sim/) contains the shared FPGA-SIM source. `build/` is for
  checkpoints, generated test output, and history. The qualified Vision
  build is `build/run99b/`, and the qualified A200T build is
  `build/a200t_d2a1/application/`. The selected run78 rollback has its own
  bitstream and disk under `build/run78_clean_architecture/`. The exact
  rollback paths are in [`CURRENT_SET.json`](../CURRENT_SET.json).

The ordered PCB design is in the Macintosh repository at
`hardware/a200t_m2_hyperram_d2a1/`, assembly Y22 / SMT026102765180.
The JS bitstream and its build scripts are in this repository.

## Load either build

Run these commands from the project root. Each loads FPGA configuration
memory for the current power session.

**Custom A200T D2-A1 / C3.** Follow the power and wiring guide, then use
the same external FT2232 **channel B** adapter as the A100T BASIC and
Macintosh boards. Keep the existing C3 USB firmware installed, leave JP1
on pins 1–2, and plug the keyboard and mouse into the motherboard USB.
[A200T first power-on and wiring](../A200T_D2A1_BRINGUP/START_HERE.md)

```sh
python3 A200T_D2A1_BRINGUP/jtag.py check
python3 A200T_D2A1_BRINGUP/jtag.py load
```

`check` verifies the package files. `load` also checks the JTAG device and
loads the A200T `.bit`. Attach the monitor to the C3 VGA output.

**Vision / Digilent Nexys Video.** Connect the USB PROG cable and HDMI.
[Vision wiring and loading guide](FPGA_BRINGUP.md)

```sh
openFPGALoader -b nexysVideo releases/current/jmr_js_mac.bit
```

## What the simulator and board tests cover

**Use the same FPGA-SIM window for software testing.** The regular GUI
can select FPGA-SIM with F9. The shortcut in `A200T_D2A1_BRINGUP/` opens
the same simulator with an A200T title and selects FPGA-SIM automatically.
Either way, it opens the root `card.img`. Run one simulator window at a
time because each can write back its copy of the disk. Try Finder, Editor,
save and reopen, a game, or Compile. The shared desktop tests passed,
including with memory initialized to a nonzero pattern.

**The RAM change is in the hardware build.** FPGA-SIM uses the internal
RAM model in the shared core. On both physical boards, the core sends the
same address, data, read, and write requests out to the board's memory
controller. Vision connects those requests to DDR3. The custom A200T
connects them to its new 50 MHz HyperRAM controller and read-ahead cache.
[Core memory interface](../rtl/jmr_js_core.sv#L1339) ·
[Vision top](../rtl/top_nexys_video.sv#L393) ·
[A200T top](../boards/a200t_d2a1/rtl/top_a200t_d2a1.sv#L166)

- **HyperRAM.** The board testbench ran the controller and FPGA I/O
  primitives from the bitstream sources against Infineon's chip model.
  It passed initialization of both dies, reads and masked writes, cache
  behavior, and addressing at the 32 MiB die boundary. A 320-word video
  row took **24.92 µs** against a **32 µs** deadline. The missing-memory
  test confirmed that the computer stays in reset. The simulation uses a
  shorter startup test range. The actual bitstream writes and reads every
  word of the 64 MiB with an address pattern and its complement.
  [Memory testbench](../boards/a200t_d2a1/tests/tb_sram.sv) ·
  [Packaged test reports](../A200T_D2A1_BRINGUP/reports/)
- **USB input.** The A200T receives the same keyboard and mouse reports
  from the C3 motherboard that the Macintosh FPGA uses. The JS decoder
  passed tests for typing, key releases, modifiers, Escape, arrows, pointer
  motion, and mouse buttons. [Input testbench](../boards/a200t_d2a1/tests/tb_input.sv)

On the physical A200T, allow about 30 seconds for the memory test and startup.
STAT0 reports clock lock, STAT1 reports memory ready and release from reset,
and STAT2 reports a fault. At first boot, confirm Finder About shows **Build
99**, then check VGA, USB input, microSD save and reopen, and sound.
[First-boot checklist](../A200T_D2A1_BRINGUP/START_HERE.md#check-first-boot)

## A200T components, FPGA use, and timing

**U1** is the XC7A200T FPGA. **U6** is the Infineon S80KS5122 64 MiB
HyperRAM. **U5** is configuration flash. **J2** takes the 3.3 V supply,
**U2/L1** generate the core rail, **U4/U7** regulate 1.8 V, and **J3** is
the JTAG header. The custom M.2 connector carries the C3 signals, including
VGA, keyboard and mouse reports, and microSD.

- **LUTs** 94,069 / 133,800 (70.31%)
- **Flip-flops** 41,217 / 267,600 (15.40%)
- **Block RAM** 354.5 / 365 tile equivalents (97.12%), the closest to capacity
- **DSP blocks** 127 / 740 (17.16%)
- **I/O blocks** 52 / 285 (18.25%)

The A200T passed routed timing at **100 MHz fabric**, **33.333 MHz JS
processor**, **50 MHz HyperRAM**, and **25 MHz video**. Worst setup slack
was **+0.002 ns** on a framebuffer write path. Worst hold slack was
**+0.051 ns** and pulse-width slack was **+0.264 ns**. The report shows
zero failing endpoints, routing errors, or DRC errors. Physical testing
is pending. [A200T utilization](../A200T_D2A1_BRINGUP/reports/utilization.rpt) ·
[A200T timing](../A200T_D2A1_BRINGUP/reports/timing.rpt)

Vision build 99 reports **+0.089 ns** setup and **+0.041 ns** hold slack.
[Vision timing](../releases/current/timing.rpt)
