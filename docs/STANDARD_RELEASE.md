# Standard FPGA release — 2026-10-26

**run72b_game_speedup_WNS+0.238** is the user-selected Nexys Video A200T
standard. [Release downloads](https://github.com/jmrothberg/JMR-JS-CSS-FPGA-COMPUTER/releases/tag/standard-2026-10-26-run72b) and
[the machine-readable manifest](../releases/standard.json) identify the exact
artifacts. Use source at the release tag for the matching GUI/simulator;
newer development code may use a different input protocol.
New working-tree features require their own simulation, fit,
routing, and timing qualification before replacing this release.

## What improved

The single native Value64 JavaScript CPU keeps the same language and heap
capacities. Exact multiplication skips fixed zero groups; GC skips element
walks only for arrays that never held references; present and ImageData
transfers remove request bubbles. Pac-Man avoids full-grid pellet searches
and reduces map allocation; Donkey Kong narrows ordered collision and dirty
redraw searches. Game rules, art, audio, and resolution are retained.

Median native RTL fabric-cycle gains are **3.76× Pac-Man** and **3.16×
Donkey Kong**. With the real DDR bridge and a modeled 25-cycle read delay,
the gains are 3.05× / 2.93×. Neither model measures live board FPS.
The user reports a working board/tether setup; numeric board FPS remains
unmeasured. [Detailed results](GAME_SPEEDUP_RESULTS.md).

## Files and persistent flash

From the repository root, download the fixed release if the local files are
not already present:

```bash
mkdir -p build/bits
gh release download standard-2026-10-26-run72b \
  --repo jmrothberg/JMR-JS-CSS-FPGA-COMPUTER \
  --dir build/bits --pattern 'run72b*' --pattern SHA256SUMS
(cd build/bits && sha256sum -c SHA256SUMS)
```

Write the matching `run72b_card.img` to the identified removable microSD
using the command below (replace `/dev/sdX` with the verified whole card):

```bash
sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image \
  --image build/bits/run72b_card.img
```

Check
`lsblk` first: a device name such as `/dev/sdb` can change after reconnect.
Move the verified card into the board.

For QSPI persistence, use the **`.bit` container**. The project recorded a
byte-order problem with raw `.bin` flashing; `.bin` remains an archived
secondary artifact, not the recommended `-f` input.

```bash
sudo openFPGALoader -b nexysVideo -f build/bits/run72b_game_speedup_WNS+0.238.bit
# Load the application immediately after the flash helper finishes:
sudo openFPGALoader -b nexysVideo build/bits/run72b_game_speedup_WNS+0.238.bit
```

Set **JP4 to QSPI** for boot after power cycling. Alternatively, press PROG
after the persistent write to boot from QSPI. The flash helper can leave
the screen blank until the application is reloaded or the board reboots.

At READY: `LOAD "PACFAST.HTML"`, then `RUN`; Esc returns to READY for
`LOAD "DNKF.HTML"` / `RUN`. `DNKFAST.HTML` is the alternate full-art variant.

The monitor’s existing R70 banner is not the release identifier; use the
release filename and checksums to identify this build.

## GUI tether access

F9 selects BOARD. If the flight log reports permission denied on channel A
(`/dev/ttyUSB0` in the tested setup), grant access and restart the GUI:

```bash
sudo setfacl -m u:"$USER":rw /dev/ttyUSB0
python3 gui_jmr_js.py
# Permanent group membership takes effect after logout/login:
sudo usermod -aG dialout "$USER"
```

Find the current channel-A node under `/dev/serial/by-id/*-if00-port0`;
channel B (`if01`) is JTAG. Reconnecting USB can change the tty number and
clears a temporary device ACL.

## Validation

Final routed utilization: **92,273 LUTs / 28,583 occupied slices /
353.5 BRAM / 128 DSPs**. Setup **+0.238 ns**, hold **+0.050 ns**, zero
failing endpoints and zero bitstream DRC errors. Routing: **35m48s**;
synthesis: **39m29s**. Source fingerprints match the published hardware.

The matching regression recorded **549 passed, 12 skipped, 2 existing
expected failures, 1 existing non-strict unexpected pass**. Pixel/state
replays cover 900 frames for each of three titles plus 540 frames covering
all 12 Pac-Man levels, final screen, and restart. Direct native RTL image
comparisons also match. [Evidence](performance/2026-10-26-fpga-release.json).

For future source changes, run `python3 -m pytest -q` and the relevant
native RTL benches before a new board build. `tools/check_runtime_parity.py`
is a legacy smoke script: it still requests the absent `INVADERS` alias and
fails before its game checks on this card. The above passing regression is
separate evidence; it is not a claim that this script printed BATTERY PASS.

## Previous binary archive

The previous `.bit` and `.bin` were preserved under
`build/bits/archive/previous_20261026_1538_UNQUALIFIED.*`, with their own
checksums and provenance in `releases/standard.json`, and are release assets.
Their auto-archive label was `UNKNOWN_PREV`; their source revision and timing
are unverified. They are retained for history and are not the new standard.
