# Start the A200T JS computer

Use this package only on the **A200T D2-A1 / C3 motherboard**, order Y22 / SMT026102765180. It is a first-board test candidate using the shared JS build 99 software. Keep the working Vision setup and the working A100T Macintosh card intact.

## Connect with power off

1. Check the new card's fit and power rails before programming: current-limited **3.3 V** at card J2; expected core approximately 1.0 V and auxiliary/memory rails 1.8 V. Do not apply 5 V to J2. The M.2 socket does not power the card. Check temperatures and underside/header clearance.
2. Use the same card power wires as the A100T: motherboard J11 pin 1 → card J2 pin 1 (3.3 V), and J11 pin 2 → J2 pin 2 (ground).
3. Connect the same external FT2232 channel B adapter: card J3 pin 2 → GND; pin 3 TCK → BD0; pin 4 TMS → BD3; pin 5 TDI → BD1; pin 6 TDO → BD2. Leave the adapter's 3.3 V wire disconnected from J3 pin 1, as with the working A100T setup.
4. Disconnect the motherboard micro-USB data cable and other FT2232 adapters while programming. Keep motherboard USB-C power connected. Leave JP1 on **1–2**, and leave the already working keyboard/mouse U3 firmware alone. Plug USB input into the motherboard and connect its VGA output to the monitor.

## Use the matching microSD

Use the existing build 99 Vision microSD card for the first boot. Power off before moving it between boards. Both boards use the same JS software and FAT32 layout. The A200T changes the FPGA connections for keyboard, mouse, video and RAM, and uses the same SD controller in the shared JS core.

To prepare another microSD for convenience, use the project’s `../card.img`. Close the simulator first, identify the removable card with `lsblk`, and run the following from this folder. This erases the selected card and verifies the write.

```sh
sudo python3 ../tools/make_sd_image.py burn /dev/sdX --image ../card.img --keep-image
```

Replace `/dev/sdX` with the actual removable card, not a partition or system drive. Insert it while board power is off.

## Load temporarily over JTAG

Run these commands from this package folder:

```sh
python3 jtag.py check
python3 jtag.py detect
python3 jtag.py load
```

Detection must show **one XC7A200T, ID 03636093**. The loader requires exactly one connected FT2232 adapter and rejects an A100T or a second device in the JTAG chain. This loads FPGA SRAM and disappears at power-off; it does not replace flash. No new motherboard USB image is required.

## Check first boot

Allow about 30 seconds for the full memory self-test and startup picture. STAT0 indicates clock lock; STAT1 indicates that memory checks passed and the computer was released from reset; STAT2 indicates a memory, input-frame or VM fault. These are logical motherboard status nets.

Finder should show build 99 in About. Check pointer direction, left/right/middle button press and release, typing, Shift/Ctrl/Alt, Escape and arrow keys. Open Editor, type and save a disposable document, return to Finder, run a game and return, and try Compile. Check sound and sustained video while loading art. Cold-start and reset again. If STAT2 reports a fault or video never starts, stop at that finding and retain the test results; do not replace the card with a Vision/A100T bitstream.

Physical acceptance remains open until the new board passes these checks. Record power/temperature, memory self-test, video, USB input, SD save/reopen and sound. Only then consider persistent flash programming or promoting this target. Keep Vision as the working release meanwhile.

## Separate simulator window

On the prepared workstation, open `Start A200T Simulator.desktop`. The labeled window runs the existing JS RTL simulator using the project’s `../card.img`, just like the Vision simulator. Close one simulator window before opening the other. Each loads the image into memory and can write it back, so simultaneous sessions could overwrite saves. The keyboard and HyperRAM interface test results are in `reports/`.
