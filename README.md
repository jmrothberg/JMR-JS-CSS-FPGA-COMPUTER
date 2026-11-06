# JMR JS Computer

Standalone machine. `LOAD` an HTML file, `RUN` the minted `.JSH` on `card.img`. Python, FPGA-SIM, and the board share that image. `storage/` is only the seed.

Keyboard on USB **J15**. PS/2 mouse on **JA** (pin 1 data, pin 3 clock). Second mouse on **JC**. Joystick on **JB**. [Wiring](docs/USB_KEYBOARD_PMOD_MICE.md). [Architecture, Toolbox calls and Macintosh differences](docs/lastrun_ARCHITECTURE.md). [Architecture PNG](docs/diagrams/rarchitecture.png) · [Memory-map PNG](docs/diagrams/memory-map.png). Which bitstream: [docs/FPGA_FIT.md](docs/FPGA_FIT.md).

## Active development candidate: run81 — RTL simulation passed

[Run81 status and evidence](build/run81_mac_native/STATUS.md) records the single active
implementation candidate, its [matched 44-program simulation disk](build/run81_mac_native/card.img),
and the tested source. Focused fullcore RTL checks pass for boot/ROM identity,
Finder menus and selection, Editor handoff/return, CopyBits/masks/patterns/text and
division. Component checks cover the timer, framebuffer and memory services.
The shared normalized-font resources leave 27 resident instruction words free.

**No run81 FPGA build or bitstream yet.** Clock and physical resource gains remain
unmeasured. No physical SD or flash update was made. Root storage and the existing
working image below remain the preserved previous software set; do not mix their
ROM/LNK/SYS with the run81 linked programs. The candidate contains the run80
handoff/pointer fixes plus the reviewed VM, framebuffer and Toolbox changes.

## Preserved run80/root snapshot before run81


**Historical development snapshot — not ready for FPGA installation.** Run80
finished routing at setup -0.170 ns / hold +0.050 ns. The architecture review is
complete and its high-confidence changes are being tested in run81 above; no new
FPGA build has started. Run80 is not strict timing-qualified.

**GitHub snapshot validation (2026-11-05):** the working disk audit found that
its Toolbox ROM differs from the factory instruction vectors and RTL default
identity. The disk has 44 programs; the audit reported six factory-ROM
consistency errors. The current Python test suite also reports failures.
This snapshot is development work; the combined release checks remain open.

The completed package will contain one bitstream, one matched disk and one install guide.

It combines:

- **Hardware:** the Editor application-handoff fix and the pointer coordinate
  crossing fix for reproduced lost updates followed by a large jump.
- **Software:** readable/reverse-highlighted menus, CopyBits redraw corrections,
  Pac-Man startup, INVF bunker edges, Missile cleanup and MacPaint box previews.
- **Toolbox:** the corrected rectangle helper, matching ROM/LNK and all 44
  programs, including eight CB variants and four runnable API examples.

The matching [working disk](card_toolbox_examples_working.img) is prepared and
preserves the previous working image's documents. Root `storage/` contains the
matching program versions. The latest examples revision has not been written to
the physical SD. Keep the ROM, link manifest and linked programs together and
cold restart after an update; the resident library uses all 8191 mutable words.

Read the [graphics/damage guide](docs/TOOLBOX_USAGE.md) and
[UI/session guide](docs/UI_USAGE.md). The examples are `GRAPHICS`, `DAMAGE`,
`UIMAN` and `UISESS`. The graphics gallery passed focused RTL checks; damage and
UI examples have bounded model checks. Physical acceptance remains open, and
we have not yet confirmed that the reproduced pointer defect explains the
reported physical jumps. Keep old games until the CB replacements are confirmed.

<details>
<summary>Rollback and build history</summary>

The [run78 qualified package](build/run78_clean_architecture/final_corrected/README.md)
is preserved as a matched historical rollback. Its bit passes strict timing
(setup 0.000 ns, hold +0.027 ns), routing, DRC, resource limits and the independent
routed memory audit. It lacks the new Editor and pointer hardware fixes.

[Run79 Editor TEST](build/run79_handoff_fix/test/README.txt) fixes handoff only;
setup slack is -0.195 ns, so it is not strict timing-qualified and does not contain
the pointer fix. It is superseded by the intended combined run80 release.
Older run75/run76 builds and the original `card.img` remain preserved.
Agent RAM loading did not change QSPI; the user's current flash contents are unconfirmed.
See [qualification records](docs/FPGA_FIT.md) for details.

</details>

## Commands

### Start

```sh
JMR_CARD_IMG=card_toolbox_examples_working.img .venv/bin/python gui_jmr_js.py
```

One 640×480 window. F9 cycles Python, FPGA-SIM, and the board. F10 opens the Architecture Monitor.

### Build the disk image

Builds a 64 MiB image from the updated `storage/` and compiles each HTML into a `.JSH`. Do this after you edit a title, then reopen the GUI.

```sh
python3 tools/make_sd_image.py create card_new.img
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
sudo openFPGALoader -b nexysVideo build/run78_clean_architecture/qualification_refined/run78_clean_qualified.bit
```

Run78 is the current timing-qualified hardware. Run75 remains a separate rollback with older software and wiring. [Which bit](docs/FPGA_FIT.md). To keep run78 after power-off, set JP4 to QSPI and add `-f`:

```sh
sudo openFPGALoader -b nexysVideo -f build/run78_clean_architecture/qualification_refined/run78_clean_qualified.bit
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
