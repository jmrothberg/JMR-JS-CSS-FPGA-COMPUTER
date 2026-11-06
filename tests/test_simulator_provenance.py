"""The ordinary FPGA-SIM launch must reject a stale local cache."""
import json
from pathlib import Path
import pytest
from tools.simulator_provenance import digest, inputs, verify


def bundle(root):
    for name, data in {'rtl/core.sv': 'module core;endmodule',
                       'sim/sim_main.cpp': 'int main(){}',
                       'sim/Makefile': 'all:', 'vectors/toolbox_code0.hex': '0',
                       'sim/toolbox_code0.hex': '0',
                       'sim/sim_build_synth/jmr_js_sim_server': 'test binary'}.items():
        p = root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(data)
    binary = root / 'sim/sim_build_synth/jmr_js_sim_server'
    binary.with_suffix('.provenance.json').write_text(json.dumps(
        {'sha256': digest(binary), 'inputs': inputs(root)}))
    return binary


@pytest.mark.parametrize('changed', ['rtl/core.sv', 'rtl/new.sv',
    'sim/sim_main.cpp', 'sim/toolbox_code0.hex', 'vectors/toolbox_code0.hex',
    'sim/sim_build_synth/jmr_js_sim_server'])
def test_stale_cache_rejected(tmp_path, changed):
    binary = bundle(tmp_path)
    verify(tmp_path, binary)
    (tmp_path / changed).write_text('changed')
    with pytest.raises(RuntimeError, match='missing or stale'):
        verify(tmp_path, binary)


def test_missing_receipt_rejected(tmp_path):
    binary = bundle(tmp_path)
    binary.with_suffix('.provenance.json').unlink()
    with pytest.raises(RuntimeError, match='missing or stale'):
        verify(tmp_path, binary)


def test_checkout_can_move(tmp_path):
    import shutil
    binary = bundle(tmp_path / 'before')
    shutil.copytree(tmp_path / 'before', tmp_path / 'after')
    verify(tmp_path / 'after', tmp_path / 'after' / binary.relative_to(tmp_path / 'before'))
