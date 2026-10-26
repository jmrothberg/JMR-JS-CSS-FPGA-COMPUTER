"""A resource-budget failure must stop the implementation flow."""
import os
import shutil
import subprocess
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize('stage,luts,bram,slices,ok', [
    ('synth', 100145, 353.5, 0, True),
    ('place', 90413, 353.5, 27093, True),
    ('impl', 95001, 353.5, 27093, False),
    ('synth', 105001, 353.5, 0, False),
    ('place', 90413, 356, 27093, False),
    ('place', 90413, 353.5, 28603, False),
])
def test_physical_resource_gate(stage, luts, bram, slices, ok):
    if not shutil.which('tclsh'):
        pytest.skip('Tcl missing')
    env = dict(os.environ, JMR_MAX_SYNTH_LUTS='105000', JMR_MAX_LUTS='95000',
               JMR_MAX_BRAM='355.5', JMR_MAX_SLICES='28602')
    script = f'''
source {{{ROOT / 'tools/board_flow/build_gates.tcl'}}}
set report {{| Slice LUTs* | {luts} |
| Block RAM Tile | {bram} |
| Slice | {slices} |}}
if {{[catch {{jmr_resource_gate {stage} $report}} why]}} {{
    puts stderr $why
    exit 1
}}
'''
    result = subprocess.run(['tclsh'], input=script, env=env,
                            text=True, capture_output=True)
    assert (result.returncode == 0) == ok, result.stdout + result.stderr


@pytest.mark.parametrize('next_step', ['phys_opt_design', 'route_design'])
def test_wait_accepts_completed_partial_placement(next_step):
    if not shutil.which('tclsh'):
        pytest.skip('Tcl missing')
    source = (ROOT/'tools/board_flow/vivado_build.tcl').read_text()
    start = source.index('proc jmr_wait_run ')
    end = source.index('\n# synth_design is one atomic step', start)
    script = f'source {{{ROOT / "tools/board_flow/build_gates.tcl"}}}\n'
    script += '''
proc get_runs {run} {return $run}
proc jmr_rss_gb {} {return 0}
proc get_property {key run} {
    if {$key eq "STATUS"} {return "Not started phys_opt_design"}
    return "60%"
}
proc wait_on_run {args} {error "completed placement must not wait again"}
'''.replace('Not started phys_opt_design', 'Not started '+next_step)+source[start:end]+'''
if {[catch {jmr_wait_run impl_1 place_design} why]} {
    puts stderr $why
    exit 1
}
puts PASS
'''
    result = subprocess.run(['tclsh'], input=script, text=True,
                            capture_output=True, timeout=5)
    assert result.returncode == 0, result.stdout+result.stderr
    assert 'PASS' in result.stdout
