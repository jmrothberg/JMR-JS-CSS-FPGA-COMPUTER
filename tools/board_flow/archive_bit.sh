#!/bin/bash
# Archive a run's bitstream with a label so runs never smash each other.
# Usage: archive_bit.sh <run-label> [impl-bit-path]
set -e
LABEL="$1"
BIT="${2:-build/nexys_video/vivado/jmr_nexys_video.runs/impl_1/top_nexys_video.bit}"
mkdir -p build/bits
cp "$BIT" "build/bits/${LABEL}.bit"
echo "archived: build/bits/${LABEL}.bit ($(stat -c %s "$BIT") bytes)"
# FLASH THE .BIT: `openFPGALoader -b nexysVideo -f file.bit` boots; the
# SAME design as .bin blue-screens (2026-08-27 hardware-confirmed — the
# .bin is the 32-bit word byte-swap of the .bit payload, a format
# mismatch for openFPGALoader's flash path, not a design difference).
# The .bin is still archived as a secondary artifact, never the primary.
BIN="${BIT%.bit}.bin"
if [ -f "$BIN" ]; then
  cp "$BIN" "build/bits/${LABEL}.bin"
  echo "archived: build/bits/${LABEL}.bin ($(stat -c %s "$BIN") bytes)"
else
  echo "note: no $BIN alongside the .bit — .bin not archived"
fi
