# A200T D2 A1 bring up

This target runs the shared build 99 JS computer on the **A200T D2-A1 card and C3 motherboard**. The ordered design is in `/home/jonathan/Macintosh/hardware/a200t_m2_hyperram_d2a1`, order Y22 / SMT026102765180. The FPGA is **XC7A200T-1FBG484I** and memory is **S80KS5122GABHI020, 64 MiB**.

The Vision release remains `releases/current/jmr_js_mac.bit`, with root `storage/` and `card.img`. This directory is an isolated board candidate, not a replacement active release. No PCB, ordered manufacturing file or motherboard USB firmware is changed.

## Ready to test folder

The checked package is in `A200T_D2A1_BRINGUP/` at the project root. `package.py` publishes it after the board build passes routing, setup/hold, DRC and internal clock coverage and verifies the source snapshot.

The package contains the A200T `.bit`, `jtag.py`, checksums, reports and `START_HERE.md`. The matching build 99 image is the project’s `card.img`. A200T and Vision use the same SD controller and software, so the existing build 99 microSD can be moved between the two boards for testing. The loader uses the same external FT2232 **channel B** as the working A100T BASIC and Macintosh images and checks the device identity before temporary SRAM loading.

The prepared candidate meets setup, hold and pulse-width timing at the original clocks (setup slack 0.002 ns; hold slack 0.051 ns), with zero routing or DRC errors. Reports retain DSP pipelining, BRAM asynchronous-control and unused-load advisories. The CDC report retains critical/unknown classifications for asynchronous input ports, held audio payloads and the stopped-RWDS receive mailbox; its summary reports zero unsafe endpoints. The mailbox is captured after the strobe stops and has an explicit 20 ns settling bound. These reports and protocol simulations support first-board testing; power, physical I/O, temperature, video, storage and sound still require acceptance on the returned board.

## Simulator window

From this repository:

```sh
.venv/bin/python boards/a200t_d2a1/simulator.py
```

This opens a labeled instance of the existing GUI, selects FPGA-SIM and uses the project’s writable `card.img`. Run one simulator window at a time because each process can write its in-memory image back to disk. C3 uses its UART for USB input, so the launcher selects the simulator without loading the Vision FT245 backend.

There is no second computer implementation to maintain. Board-specific simulations below exercise the actual input decoder, memory PHY and cache bridge. A GUI image alone cannot validate those interfaces.

## Board changes

- The shared JS core retains 100 MHz fabric, 33.333 MHz VM, 60 Hz software frames and 25 MHz 640×480 video. The C3 shell outputs parallel RGB444 and active-low VGA syncs in place of Vision's TMDS encoder.
- The existing CH9350L/U3 report-forwarding firmware remains installed. JP1 stays on pins 1–2 for keyboard/mouse. Full reports generate JS press/release events and pointer coordinates; Escape, modifiers, navigation and function keys are translated for the JS system rather than Macintosh scan semantics.
- HyperRAM starts at 50 MHz with a source-synchronous delayed-RWDS read path. CR1 is broadcast to both dies and read back separately, as are both device IDs. Aligned eight-word writes and 32-word read-ahead bursts cannot cross the 32 MiB die boundary. The existing shared burst cache and write-combine logic remain in use. A board-local read-ahead buffer serves four eight-word cache lines per physical read. The vendor-model test fetches a 320-word video row in 24.92 microseconds, within its 32-microsecond deadline; physical video acceptance remains open.
- Before releasing the JS core, the hardware writes and reads **every word in the full 64 MiB**, first with an address-derived pattern and then its complement. Allow about 30 seconds for first boot. A memory timeout, ID/configuration mismatch or data mismatch holds the computer in reset and asserts STAT2.
- The PSG is shared; the new shell converts its I2S sample stream to the C3 PWM audio output. Sound, monitor compatibility and memory throughput still require physical acceptance.

## Rebuild and checks

Source the workstation Vivado environment before running Tcl. Keep one hardware build owner. Do not run the Vision and A200T builds concurrently.

```sh
source scripts/vivado_env.sh
.venv/bin/python tools/verify_current_set.py
.venv/bin/python sim/user_loop.py
/usr/bin/python3 boards/a200t_d2a1/check_pins.py /home/jonathan/Macintosh/hardware/a200t_m2_hyperram_d2a1/M2_A200T_64MB_D2_A1_KICAD.zip
python3 boards/a200t_d2a1/test.py
bash boards/a200t_d2a1/build.sh
python3 boards/a200t_d2a1/package.py
```

The memory tests use the retained Infineon September 2026 model with the Macintosh repository's documented CA[37:16] address correction. The original vendor file is preserved there. Simulator limitations include an unsupported vendor `$skew` check; physical I/O timing is checked separately by the implementation constraints. Simulation shortens the **BIST range only**, while preserving the transaction state machine and actual Xilinx primitives. The hardware default scans all 64 MiB.

Check `build/a200t_d2a1/` for logs. Passing model tests is not a physical board test. The ordered PCB is preserved; this firmware pin audit does not requalify its footprints or manufacturing.
