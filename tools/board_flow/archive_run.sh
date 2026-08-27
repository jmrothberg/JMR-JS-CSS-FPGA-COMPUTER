#!/bin/bash
# Archive a run's precious implementation artifacts (checkpoints, timing
# reports, console log) BEFORE launching the next run in the shared
# build/nexys_video directory. Runs never smash each other:
# bits via archive_bit.sh, everything else via this.
# Usage: archive_run.sh <run-label> [impl-dir]
set -e
LABEL="$1"
IMPL="${2:-build/nexys_video/vivado/jmr_nexys_video.runs/impl_1}"
DEST="build/runs/${LABEL}"
mkdir -p "$DEST"
shopt -s nullglob
n=0
for f in "$IMPL"/*.dcp "$IMPL"/*.rpt build/nexys_video/run*_console.log; do
  cp -n "$f" "$DEST/" && n=$((n+1))
done
echo "archived $n artifacts to $DEST"
