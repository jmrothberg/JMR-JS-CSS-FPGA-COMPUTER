#!/usr/bin/env bash
set -euo pipefail
board_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$board_dir/../.." && pwd)
cd "$project_dir"
set +u
source scripts/vivado_env.sh
set -u
mkdir -p build/a200t_d2a1
exec 9>build/a200t_d2a1/build.lock
flock -n 9 || { echo 'Another A200T build owns the hardware flow.' >&2; exit 1; }
python3 - <<'PY'
import importlib.util,json
from pathlib import Path
p=Path('boards/a200t_d2a1/test.py');s=importlib.util.spec_from_file_location('checks',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
r=Path('build/a200t_d2a1');d=json.loads((r/'CHECKS.json').read_text())
tested=d.get('interface_inputs', {k:v for k,v in d['hardware_inputs'].items() if k in m.interface_inputs()})
assert d['status']=='PASS' and tested==m.interface_inputs(), 'Run board test.py first; RTL changed'
(r/'hardware_inputs.json').write_text(json.dumps(m.hardware_inputs(),indent=2)+'\n')
PY
touch build/a200t_d2a1/build-start
qualification_log=build/a200t_d2a1/application.log
qualification_recipe=boards/a200t_d2a1/build.tcl
if "$VIVADO" -mode batch -source "$board_dir/build.tcl" -tclargs "$project_dir" "$project_dir/build/a200t_d2a1/application" > "$qualification_log" 2>&1; then
    :
else
    build_exit=$?
    # Repair only a newly routed design stopped by its timing gate. Other
    # failures must remain failures; never resume an older checkpoint.
    if [[ ! build/a200t_d2a1/application/routed.dcp -nt build/a200t_d2a1/build-start ]] ||
       ! rg -q '^Timing gate failed; no bit$' "$qualification_log"; then
        tail -20 "$qualification_log" >&2
        exit "$build_exit"
    fi
    qualification_log=build/a200t_d2a1/qualification.log
    qualification_recipe=boards/a200t_d2a1/qualify_routed.tcl
    "$VIVADO" -mode batch -source "$board_dir/qualify_routed.tcl" -tclargs "$project_dir" > "$qualification_log" 2>&1
fi
"$VIVADO" -mode batch -source "$board_dir/verify_routed.tcl" -tclargs "$project_dir" > build/a200t_d2a1/constraint_reload.log 2>&1
python3 boards/a200t_d2a1/record_qualification.py --log "$qualification_log" --recipe "$qualification_recipe"
