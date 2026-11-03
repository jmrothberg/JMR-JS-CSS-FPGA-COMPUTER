# Current FPGA release — run73o, November 2, 2026

**Selected file: [releases/current/fpga.bit](../releases/current/fpga.bit).** The owner flashed run73o to QSPI with openFPGALoader and reports it running fine on the board. Numeric board FPS and a separate cold-boot test were not reported.

## Files and persistent flash

From the repository root:

```bash
# Keep the new version after power-off:
openFPGALoader -b nexysVideo -f releases/current/fpga.bit
# Load the application immediately after the flash helper finishes:
openFPGALoader -b nexysVideo releases/current/fpga.bit
```

Set JP4 to QSPI. Use `sudo` if your workstation requires it for USB access. For a temporary load only, use just the second command. Already flashed this build? Reorganizing the folders changes no FPGA bytes and needs no reflash.

Use the existing compatible card and continue `LOAD "NAME.HTML"` followed by `RUN`. No card rewrite, ZIP or prepared Donkey Kong package is required. The original matching disk is retained with [run72b](../releases/archive/run72b-2026-10-26/README.md) if a fresh card is ever needed. Read [the current folder README](../releases/current/README.md) for file roles and [standard.json](../releases/standard.json) for exact paths/hashes.

## What improved

General native-JavaScript FPGA changes: 33.333 MHz VM versus 14.286 MHz, pipelined exact arithmetic, corrected method caching, packed ImageData and changed-block display transfers. No game source, rule or artwork was changed for this release. Simulated median processing gains over October 26 run72b are 2.005× Pac-Man and 2.307–2.356× Donkey Kong. These are processing-capacity measurements, not measured board FPS; HDMI stays 60 Hz. [Complete results](GAME_SPEEDUP_RESULTS.md#current-run73o--2026-11-02).

## Validation

The selected O RTL passed its full 578-test suite plus the added timer conversion/arity test (579 distinct passes). Dedicated stalled display-transfer benches and over a million arithmetic bit comparisons also pass. All specified setup/hold/pulse constraints pass on the fully routed bit: setup 0.000 ns rounded (no extra setup margin), hold +0.040 ns, zero routing/DRC errors. Resources: 87,876 LUTs / 28,045 slices / 353.5 BRAM / 128 DSP. Full warnings and timing-coverage limits remain in the qualification reports; no DRC was waived.

The immutable [build-time manifest](../releases/current/evidence/build_manifest.json) predates the owner's board run and this promotion; its earlier "not programmed" / "standard unchanged" fields are historical. The current board report is in [standard.json](../releases/standard.json).

## Revert

Use [the previous run72b README](../releases/archive/run72b-2026-10-26/README.md) for exact rollback commands and its matching disk/checksums. [Earlier versions](../releases/archive/README.md) have their own notes. No old binary or completed checkpoint was deleted. Use `.bit` with openFPGALoader; raw `.bin` files remain secondary historical artifacts.

## Development and GUI

Work in this repository on `main`; keep old versions in folders rather than creating branches or worktrees. `make -C tools/board_flow flash` and `flash-qspi` load the selected release without rebuilding. `bit` is a separate, explicit build action. Matching new RTL builds require the native RTL tests plus timing/resource/DRC gates before selection.

F9 selects BOARD in the GUI. The J15 keyboard remains supported. Tether USB device names and permissions can change after reconnecting; the detailed connection guide is [FPGA_BRINGUP.md](FPGA_BRINGUP.md). `tools/check_runtime_parity.py` is a legacy alias-dependent smoke script; use the recorded regression evidence rather than claiming that script printed BATTERY PASS.
