# JMR JS Computer

Standalone machine. `LOAD` an HTML file, `RUN` the minted `.JSH` on `card.img`. Python, FPGA-SIM, and the board share that image. `storage/` is only the seed.

Keyboard on USB **J15**. PS/2 mouse on **JA** (pin 1 data, pin 3 clock). Second mouse on **JC**. Joystick on **JB**. [Wiring](docs/USB_KEYBOARD_PMOD_MICE.md). [Picture of the machine](docs/lastrun_ARCHITECTURE.md). Which bitstream: [docs/FPGA_FIT.md](docs/FPGA_FIT.md).

## Commands

### Start

```sh
.venv/bin/python gui_jmr_js.py
```

One 640×480 window. F9 cycles Python, FPGA-SIM, and the board. F10 opens the Architecture Monitor.

### Build the disk image

Rebuilds `card.img` from `storage/` and compiles each HTML into a `.JSH`. Do this after you edit a title, then reopen the GUI.

```sh
python3 tools/make_sd_image.py create card.img
```

### Write a microSD card

`lsblk` first. Use the whole disk (`sdb`, `mmcblk0`), not a partition (`sdb1`). This rebuilds `card.img`, then writes it. `sudo` is required because it writes the raw device.

```sh
lsblk
sudo python3 tools/make_sd_image.py burn /dev/sdX
```

If `card.img` is already built and you only want to copy it:

```sh
sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image
```

### Load the latest bitstream

Temporary load. HDMI comes up in a few seconds and is gone when you unplug the board. PROG USB is J12. `sudo` is required when the USB device is not writable by your user.

```sh
sudo openFPGALoader -b nexysVideo build/run75_program_system/release/run75_program_finder_SYS_33MHz.bit
```

That file is the newest qualified bitstream, and it is the rollback. It still has the older jacks (mouse on J15, keyboard on JA). The run76 folder is the build in progress and does not have its own `.bit` yet. [Which bit](docs/FPGA_FIT.md). To keep the bitstream after power-off, set JP4 to QSPI and add `-f`:

```sh
sudo openFPGALoader -b nexysVideo -f build/run75_program_system/release/run75_program_finder_SYS_33MHz.bit
```

## Where to read next

| | |
|---|---|
| Dictionary, do-not list, folders | [docs/WORDS.md](docs/WORDS.md) |
| How to write a game | [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) |
| What JavaScript the chip has | [docs/JMR_JS_COMPATIBILITY.md](docs/JMR_JS_COMPATIBILITY.md) |
| Shared menus and windows | [docs/SYSTEM_APPLICATIONS.md](docs/SYSTEM_APPLICATIONS.md) |
| Board, Vivado, HDMI | [docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md) |
| Specification | [CONSTITUTION.md](CONSTITUTION.md) |
