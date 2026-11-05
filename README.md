# JMR JS Computer

Standalone machine. `LOAD` an HTML file, `RUN` the minted `.JSH` on `card.img`. Python, FPGA-SIM, and the board share that image. `storage/` is only the seed.

Keyboard on USB **J15**. PS/2 mouse on **JA** (pin 1 data, pin 3 clock). Second mouse on **JC**. Joystick on **JB**. [Wiring](docs/USB_KEYBOARD_PMOD_MICE.md). [Architecture, Toolbox calls and Macintosh differences](docs/lastrun_ARCHITECTURE.md). Which bitstream: [docs/FPGA_FIT.md](docs/FPGA_FIT.md).

## Toolbox development

The new shared native-JavaScript Toolbox adds bulk graphics/memory operations
and software menus/dialogs. [Calls and migration guide](docs/RESIDENT_TOOLBOX.md),
[primitive reference](docs/TOOLBOX_API.md), and [build status](docs/TOOLBOX_IMPLEMENTATION_STATUS.md).
Run77d is building with CopyBits included. Its hardware, Toolbox ROM and
relinked applications are frozen together under `build/run77d_copybits_toolbox/`.
The matched disk and simulator checks pass. Run77e builds a measured menu-parser
timing repair in parallel; run77f adds a tested registered startup identity check.
All use the same ROM/disk; none is qualified yet. Newly compiled
Toolbox programs require a Toolbox-capable bit: do not pair them with run75/run76.
Existing released bits and the main card image are preserved. Run77b/run77c are
older development snapshots without CopyBits; they are not the target release.

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

That file is the newest qualified bitstream, and it is the rollback. It still has the older jacks (mouse on J15, keyboard on JA). Run76 now has an [experimental test bit](build/run76_usb_keyboard_pmod_mice/test/README.md) with the new jacks and menus; setup timing misses by 0.355 ns. [Which bit](docs/FPGA_FIT.md). To keep the bitstream after power-off, set JP4 to QSPI and add `-f`:

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
