#!/bin/bash
# Synthesize the root RTL into build/<name>, then run synth_gate.tcl.
# Stops before placement. Usage: tools/board_flow/synth_gate.sh run91
set -eo pipefail
cd "$(dirname "$0")/../.."
name=${1:?run name}; out="$PWD/build/$name"; mkdir -p "$out"
source scripts/vivado_env.sh
export JMR_RUN_LABEL=$name JMR_STOP_AFTER=synth JMR_VIVADO_SYNTH_THREADS=2
export JMR_MAX_SYNTH_LUTS=116000 JMR_MAX_LUTS=106500 JMR_MAX_BRAM=365 JMR_MAX_SLICES=32900
"$VIVADO" -mode batch -log "$out/synth.log" -nojournal \
    -source tools/board_flow/vivado_build.tcl -tclargs "$PWD" "$out" fresh > "$out/synth_console.log" 2>&1 \
    || { echo "SYNTH_FAILED"; grep -B2 -A6 -m1 '^ERROR\|^couldn.t\|while executing' "$out/synth_console.log" | cut -c1-200; exit 1; }
echo "undriven nets: $(grep -c 'Synth 8-3848\]' "$out/synth_console.log" || true)"
grep -E 'Slice LUTs|Block RAM Tile' "$out/utilization_synth.rpt" | head -2 | cut -c1-70
"$VIVADO" -mode batch -nojournal -log "$out/gate.log" \
    -source tools/board_flow/synth_gate.tcl -tclargs "$out" > "$out/gate_console.log" 2>&1 || true
grep -E '^(LIVENESS|DEPTH|OPT_|ERROR)' "$out/gate_console.log" | cut -c1-200
