# Board bring-up — Digilent Nexys Video

How the machine sits on the board, how to load a bitstream, and the small test bits that check one jack at a time.

- Which bitstream to load, how to build one, resource limits: [FPGA_FIT.md](FPGA_FIT.md)
- Plugs, pins and keyboard troubleshooting: [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md)
- What the board reports over the cable: [ARCH_MONITOR.md](ARCH_MONITOR.md)

The machine runs without a PC: HDMI monitor, USB keyboard, mouse, µSD card. It boots into Finder. The PROG cable is for loading the bitstream and for optional monitoring.

## The board

| Item | Value |
|---|---|
| FPGA | Artix-7 `xc7a200tsbg484-1` |
| Board clock | 100 MHz (pin R4) |
| Fabric and DDR3 user clock | 100 MHz, from the DDR3 controller |
| VM clock | 33.333 MHz: the 100 MHz clock gated to one edge in three |
| Pixel clock | 25 MHz |
| DDR3 controller reference | 200 MHz |
| Audio master clock | 12 MHz |
| External memory | 512 MB DDR3 (`MT41K256M16`). The machine uses an 8 MiB window: 4M words of 16 bits. Map: [lastrun_ARCHITECTURE.md](lastrun_ARCHITECTURE.md#memory). |
| Video | HDMI Source jack J8, 640×480, 8-bit pixels through a 256-entry palette |
| Storage | µSD in SPI mode, FAT32 |
| Audio | ADAU1761 codec, line-out jack J5 |
| Host link | PROG jack J12, FT245 FIFO |
| Reset | BTNC (centre button) or CPU RESET |
| Constraints | [constraints/](../constraints/README.md) |

HDMI signalling is Digilent's `rgb2dvi` (`third_party/digilent_rgb2dvi`). The scanout only makes RGB and sync.

## LEDs

| LED | Meaning |
|---|---|
| LD7 | Toggles on each scancode byte from the J15 keyboard |
| LD6 | J15 PS/2 clock line (idle high) |
| LD5 | J15 PS/2 data line (idle high) |
| LD4 | Card present |
| LD3 | Clock generator locked |
| LD2 | Loader idle (`ready_lit`) |
| LD1 | A program owns the screen (`game_mode`) |
| LD0 | On: bitstream loaded |

Jumper JP4 selects where the FPGA boots from (JTAG, QSPI, USB/SD). It has nothing to do with the keyboard.

## Order of work

1. Make it work in the simulator: `make -C sim sim_server_synth`, then run it ([sim/README.md](../sim/README.md)). The simulator compiles the same RTL as the board.
2. Build the bitstream: [FPGA_FIT.md](FPGA_FIT.md). Vivado runs on Linux only.
3. Load it (below).

Do not load a bit for a feature that does not yet work in the simulator.

## Loading a bitstream

`FLASH_BIT` names the bit to load. The Makefile's default path does not exist, so always pass it. [FPGA_FIT.md](FPGA_FIT.md) says which bit.

```bash
make -C tools/board_flow flash      FLASH_BIT=/path/to/file.bit   # into the FPGA; lost at power-off
make -C tools/board_flow flash-qspi FLASH_BIT=/path/to/file.bit   # into flash; boots by itself with JP4 on QSPI
```

Both use `openFPGALoader -b nexysVideo`.

After `flash-qspi` the FPGA is running the flash-programming helper, not the machine: the screen is blank and the BUSY LED blinks. Press PROG or power-cycle. To be running at once and also persistent, run `flash-qspi` first and `flash` second.

## The card

The board reads programs from the µSD card, never from `storage/`. `tools/make_sd_image.py create card.img` builds the image. One file goes to the card already in the board with `python3 tools/tether_put.py storage/NAME.HTML` while Finder is in front and the GUI is closed. A whole new card is `sudo python3 tools/make_sd_image.py burn /dev/sdX`. Commands: [README](../README.md).

## PROG cable tether

The PROG cable carries JTAG and the tether. The FT2232's channel A is the tether: Linux shows it as the `/dev/ttyUSB*` whose USB location ends in `.0`. Channel B (`.1`) is JTAG. Set `JMR_JS_SERIAL` to override autodetection.

Permission denied on the port is a host setting:

```bash
sudo usermod -aG dialout "$USER"     # then log out and in
```

Host to board, by first byte:

| Byte | Meaning |
|---|---|
| `FA` | Finder service request: 23-byte body plus CRC32 |
| `FB` | Large file |
| `FC` | SOURCE text |
| `FD` | Program image |
| `FE` | Joystick bits (one byte follows) |
| other | A key |

`FB`, `FC` and `FD` are followed by a 32-bit little-endian length and the payload. Board to host is telemetry: [ARCH_MONITOR.md](ARCH_MONITOR.md#board).

Tether RTL tests: `make -C sim tb_uart_link tb_ft245`.

## Probe bits

Small separate designs that test one jack. They are not the machine and not the simulator. Each has its own top, constraints and build folder, and must never be added to the machine's file lists.

```bash
source scripts/vivado_env.sh
make -C tools/<probe> bit flash
```

| Probe | Build folder | What it checks |
|---|---|---|
| `tools/hid_led_blink` | `build/hid_led_blink` | J15 delivers PS/2 bytes |
| `tools/pmod_input_test` | `build/pmod_input_test` | Treats JA as a keyboard. The machine uses JA as a mouse. |
| `tools/mouse_probe` | `build/mouse_probe` | Mouse and keyboard, shown on HDMI |
| `tools/audio_beep_test` | `build/audio_beep_test` | A 440 Hz beep on J5. See its [README](../tools/audio_beep_test/README.md). |

The probes' LED meanings below are their own. They are not the machine's.

### `hid_led_blink`

Keyboard in J15 before power.

| LED | Meaning |
|---|---|
| LD0 blinking | FPGA is running |
| LD3–LD1 | Count of bytes received |
| LD4 | PS/2 clock is toggling now |
| LD5, LD6 | Data and clock lines (on when idle) |
| LD7 | Toggles on each scancode byte |

LD0 blinks but LD5/LD6 stay off, or LD4/LD7 never move: the fault is the jack, the board's USB bridge, or the keyboard. LD7 toggles here but not on the machine bit: the fault is in the machine RTL or its timing.

### `pmod_input_test`

This probe treats JA as a keyboard. The machine treats JA as a mouse. On J15 it transmits `F4` until the device acknowledges, which the machine never does.

| LED | Meaning |
|---|---|
| LD0, LD1, LD2, LD3 | Stick left, up, down, right |
| LD4 | J15 device acknowledged `F4` (solid) |
| LD5 | J15 scancode byte |
| LD6 | Stick answers (solid). Slow blink: FPGA running, no stick. |
| LD7 | JA keyboard: pulse per character |

### `mouse_probe`

HDMI shows a cursor, a left box, a right box and a scroll track.

| Target | Plugs |
|---|---|
| `make -C tools/mouse_probe bit` | Mouse on J15, keyboard on JA |
| `make -C tools/mouse_probe bit-ja-mouse` | Keyboard on J15, mouse on JA (data pin 1, clock pin 3) — the machine's arrangement |

| LED | Meaning |
|---|---|
| LD0 | Heartbeat |
| LD1, LD2, LD3 | Left, right, middle button |
| LD4 | Wheel notch |
| LD5 | Mouse is streaming |
| LD6, LD7 | Clock and data lines |
