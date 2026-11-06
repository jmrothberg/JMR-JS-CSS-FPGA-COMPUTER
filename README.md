# JMR JS Computer

Standalone machine. `LOAD` an HTML file, `RUN` the minted `.JSH` on `card.img`. Python, FPGA-SIM, and the board share that image. `storage/` is only the seed.

Keyboard on USB **J15**. PS/2 mouse on **JA** (pin 1 data, pin 3 clock). Second mouse on **JC**. Joystick on **JB**. [Wiring](docs/USB_KEYBOARD_PMOD_MICE.md). [Architecture, Toolbox calls and Macintosh differences](docs/lastrun_ARCHITECTURE.md). [Architecture PNG](docs/diagrams/rarchitecture.png) · [Memory-map PNG](docs/diagrams/memory-map.png). Which bitstream: [docs/FPGA_FIT.md](docs/FPGA_FIT.md).

## GitHub source snapshot

The root RTL, `storage/`, Toolbox and `card.img` are the matched
`run81-current-source` set recorded in `CURRENT_SET.json`. Verify them with
`python3 tools/verify_current_set.py`. No qualified run81 bitstream is included.
`card.img` is the only current disk image. Older images are retained locally
in ignored rollback storage and in Git history.

The completed run81 FPGA implementation fits the resource limits but failed
setup timing by 1.652 ns. Targeted corrections and fresh RTL/Python checks are
in progress; no replacement build has started. The default local RTL simulator
startup issue is repaired, with a binary/source/startup-data freshness guard.
The prior 38-pass/one-startup-failure result describes the old local executable.
The Python GUI runs from the published root source and `card.img`, with no
private build directory required. FPGA-SIM needs a native build on your machine:
`make -C sim sim_server_synth`. See [GUI runtime](docs/GUI_RUNTIME.md).

## Current set

Use the root `rtl/`, root `storage/` and [card.img](card.img) together.
The active source is run81. No run81 FPGA bitstream is qualified yet;
older bitstreams must not be paired with this disk.

Read the [graphics/damage guide](docs/TOOLBOX_USAGE.md),
[UI/session guide](docs/UI_USAGE.md), and [hardware status](docs/FPGA_FIT.md).

## Commands

### Start

```sh
JMR_CARD_IMG=card.img .venv/bin/python gui_jmr_js.py
```

One 640×480 window. F9 cycles Python, FPGA-SIM, and the board. F10 opens the Architecture Monitor.

### Build the disk image

Developer rebuild only: this replaces `card.img` from `storage/` and compiles the programs. Preserve any user documents before rebuilding, then regenerate the current-set manifest and verify the matched set before publishing. For normal use, keep the supplied `card.img`.

```sh
python3 tools/make_sd_image.py create card.img
```

### Write a microSD card

Use the supplied `card.img` without rebuilding it. Hardware use remains pending
a matching qualified run81 bitstream. When ready, identify the whole SD device
with `lsblk`, then write the image (this overwrites the selected device):

```sh
lsblk
sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image
```

### Bitstream status

No qualified run81 bitstream is available. See [hardware status](docs/FPGA_FIT.md)
for the qualification record; older builds are rollback history.

## Where to read next

| | |
|---|---|
| Dictionary, do-not list, folders | [docs/WORDS.md](docs/WORDS.md) |
| How to write a game | [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) |
| What JavaScript the chip has | [docs/JMR_JS_COMPATIBILITY.md](docs/JMR_JS_COMPATIBILITY.md) |
| Shared menus and windows | [docs/SYSTEM_APPLICATIONS.md](docs/SYSTEM_APPLICATIONS.md) |
| Board, Vivado, HDMI | [docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md) |
| Specification | [CONSTITUTION.md](CONSTITUTION.md) |
