#!/bin/bash
# Archive a run's bitstream with a label so runs never smash each other.
# Usage: archive_bit.sh <run-label> [impl-bit-path]
set -e
LABEL="$1"
BIT="${2:-build/nexys_video/vivado/jmr_nexys_video.runs/impl_1/top_nexys_video.bit}"
mkdir -p build/bits
cp "$BIT" "build/bits/${LABEL}.bit"
echo "archived: build/bits/${LABEL}.bit ($(stat -c %s "$BIT") bytes)"
