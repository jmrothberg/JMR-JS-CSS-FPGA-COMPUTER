# The VM clock switch

This page records one change: the JavaScript VM moved from divide-by-seven (14.286 MHz) to divide-by-three (33.333 MHz). Fabric and DDR stayed at 100 MHz. Which file to load today is [FPGA_FIT.md](FPGA_FIT.md). Do not add the next run to this page.

The bitstream that contains the switch is [releases/current/fpga.bit](../releases/current/fpga.bit). On the DDR model, the same programs ran at about **2.0×** for Pac-Man and **2.3×** for Donkey Kong versus the divide-by-seven bit. HDMI stayed 60 Hz. That is not a measured board frame rate. [GAME_SPEEDUP_RESULTS.md](GAME_SPEEDUP_RESULTS.md).

The same bit also pipelined exact arithmetic, corrected the method cache, packed ImageData, and presented only the changed blocks. Game source and art were not edited for it. Routed result: setup 0.000 ns, hold +0.040 ns, 87,876 LUTs, 353.5 BRAM, no routing or DRC errors. Reports are in `releases/current/`.

To put that file on a board from the repository root:

```bash
sudo openFPGALoader -b nexysVideo releases/current/fpga.bit
```

Add `-f` and set JP4 to QSPI to keep it after power-off. `sudo` is required when the USB programmer is not writable by your user.
