# Future option — ASIC with external RAM

Not current work. The machine is the Nexys Video XC7A200T. Do not start a smaller-FPGA port, a shuttle, or a move of the heap off-chip from this note.

## Where the design stands today

| Thing | Where it lives |
|---|---|
| Heap, application code, Toolbox bank, draw canvas | On-chip block RAM |
| Artwork, front image, SOURCE, staging | External memory, 8 MiB, behind a simple request/acknowledge port (`sram_ext_*` on `jmr_js_core`) |

The external port is 22 address bits, 16 data bits, a request and a write strobe: 40 signals as a parallel RAM. On the board `jmr_ddr3_sram_bridge` serves it from DDR3. In the simulator `jmr_sram_model` serves it. An ASIC would put one asynchronous RAM chip there. Map: [lastrun_ARCHITECTURE.md](lastrun_ARCHITECTURE.md#memory).

## The direction, if this is picked up

A small die, VGA output, and one external asynchronous RAM chip for the bulk bytes, as the sibling BASIC computer does. Package and pad-ring facts are in that repository's plan: `JMR-BASIC-FPGA-COMPUTER/docs/plans/arch_3.0_external_sram.plan.md`.

The pad ring in that plan has 44 user pins:

| Use | Pins |
|---|---|
| 8-bit, 1 MB RAM: 20 address + 8 data + OE + WE (chip-enable strapped) | 30 |
| VGA clock, R, G, B, hsync, vsync | 6 |
| µSD | 4 |
| UART | 2 |
| Audio, status LED | 2 |

That is all 44, with no keyboard pin. This machine's port as it stands (22 + 16 + 2 = 40) would leave 4. A build for that package either fits 1 MB × 8, or it is a different package.

Constraints that follow from this design:

- The draw canvas alone is 307,200 bytes. On-die RAM at shuttle densities cannot hold it together with the heap and code, so bulk memory must be external.
- HDMI needs serializers a small pad ring does not have. Video would be VGA.
- A slow external memory cannot hold the draw canvas: programs write it one pixel per clock. Keep the canvas on-chip and move colder data out first. Heap reads from external memory would need an on-chip cache.

## What stays true

The same bytecode, the same capacity constants (`jmr_js_vm_pkg.sv`), the same generation check, one heap, a 640×480 picture, no title-specific hardware. The external chip sits behind the existing port. A program never sees memory banks.
