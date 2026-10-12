# Future potential — ASIC plus external RAM

Not current work. The board stays the Nexys Video **XC7A200T**. Heap, bytecode, and the 640×480 draw bank stay in Block RAM. Do not start a 100T port, a shuttle, or a heap move off-chip from this note.

When this is picked up, the direction is the one BASIC already decided for Architecture 3.0: a small die, VGA, and **one external async RAM chip** for the bulk bytes. On-die SRAM at the density BASIC taped (~31 KB/mm², 80 KB in 2.57 mm²) cannot hold this machine. The draw bank alone is 307 KB. Code plus that frame is ~387 KB before the heap. The OpenFrame cavity is 15 mm² (core about 3000×4500 µm), which holds on the order of 160 KB of SRAM once logic has room.

## What the T200 uses today

The T200 has no SRAM chip on GPIO. It has 512 MB of DDR3 on the FPGA’s dedicated memory pins. `jmr_sram_port` uses the first 4 MB of that DDR3 as the stand-in for an IS61WV204816: palette, sprite pixels, the `getImageData` buffer, and the HDMI front frame. The JS heap and the draw bank are not in that DDR3.

## Shuttle pins

44 user GPIOs, QFN-64. BASIC’s Gate B (2026-08-11, `JMR-BASIC-FPGA-COMPUTER/docs/plans/arch_3.0_external_sram.plan.md`) already fills them:

- **8-bit RAM fits.** 20 address + 8 data + OE + WE = 30 pins. Chip-enable is strapped, not a GPIO. That is a 1 MB part (AS6C8008B-class).
- The other 14 pins are the product: VGA clock, 8-color video (R, G, B, hsync, vsync), µSD (4), UART (2), one audio pin, one status LED. Reset is the package reset. **No pin left.** No keyboard pin in that table.
- The current 16-bit 4 MB contract (21 address + 16 data + OE + WE = 39) leaves 5 pins. That cannot also carry video, the card, and a keyboard. HDMI does not fit this package. Video on the shuttle is VGA.

Art that needs more than 1 MB, or a 16-bit bus, does not fit this pad ring. A future build either stays inside 1 MB × 8, or it is not this shuttle.

## If a 100T board is ever the FPGA step

External RAM plus VGA is what makes the **Block RAM** fit an XC7A100T (135 tiles, 608 KB). The live bit uses 353.5 tiles: draw bank 75, object slots 75, array slots 100, bytecode 20, env slots 10. Those can sit behind the same `jmr_sram_port`, with the A7’s DDR2 in the role the Video’s DDR3 has now. VGA is the small part: the A7-100T has the connector, BASIC already scans 640×480 from it, and the 8-bit indexed palette narrows to 12-bit resistor VGA at the pins.

Lookup tables do not move with the RAM. Run 71c is about 90,400 LUTs. The 100T has 63,400. The stack-result funnel and, if it is still flip-flops, `jn_bucket` have to be sequenced before a 100T bit will place. BASIC’s 100T bit is about 46,000 LUTs.

DDR is not one-cycle RAM. PACMAN paints on the order of 620,000 pixels a frame, one pixel per clock. Putting the draw bank on that bus is the slowdown the fit rules already refused. Keeping the draw bank in Block RAM (75 of 135) and moving the heap and bytecode off-chip still fits the tiles and leaves fill speed alone. Heap reads then want a small on-chip cache.

## What stays true whenever this starts

Same bytecode ISA, same caps (`MAX_OBJ=960`, `ENV_DEPTH=384`, array caps, `MAX_SPR=16`), same generation check, one heap, 640×480 glass. No title-name gates. The external chip is behind `jmr_sram_port`. The programmer does not see banks.
