"""Actual BRAM read latency, SRAM stalls, queued presents and clear exactness."""
import shutil
import subprocess
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[1]


def test_present_stream_exact_under_backpressure():
    if not shutil.which('verilator'):
        pytest.skip('Verilator missing')
    out = ROOT / 'sim/sim_build_synth/present_stream'
    out.mkdir(parents=True, exist_ok=True)
    command = [
        'verilator', '-cc', '-exe', '-build', '-j', '2',
        '-Mdir', str(out/'obj'), '-o', str(out/'bench'),
        '--top-module', 'tb_present_stream',
        '-Wno-WIDTHEXPAND', '-Wno-WIDTHTRUNC',
        str(ROOT/'sim/tb_present_stream.sv'),
        str(ROOT/'rtl/engines/jmr_fb_present.sv'),
        str(ROOT/'rtl/engines/jmr_mini_fb.sv'),
        str(ROOT/'sim/tb_present_stream.cpp'),
    ]
    subprocess.run(command, check=True, capture_output=True, text=True)
    result = subprocess.run([str(out/'bench')], check=True, capture_output=True, text=True)
    assert 'PASS present:' in result.stdout
    print(result.stdout)


def test_present_stream_through_real_ddr3_bridge():
    if not shutil.which('verilator'):
        pytest.skip('Verilator missing')
    out = ROOT / 'sim/sim_build_synth/present_bridge'
    out.mkdir(parents=True, exist_ok=True)
    command = [
        'verilator', '-cc', '-exe', '-build', '-j', '2',
        '-Mdir', str(out/'obj'), '-o', str(out/'bench'),
        '--top-module', 'tb_present_bridge',
        '-Wno-WIDTHEXPAND', '-Wno-WIDTHTRUNC',
        str(ROOT/'sim/tb_present_bridge.sv'),
        str(ROOT/'rtl/engines/jmr_fb_present.sv'),
        str(ROOT/'rtl/engines/jmr_mini_fb.sv'),
        str(ROOT/'rtl/engines/jmr_ddr3_sram_bridge.sv'),
        str(ROOT/'sim/tb_present_bridge.cpp'),
    ]
    subprocess.run(command, check=True, capture_output=True, text=True)
    result = subprocess.run([str(out/'bench')], check=True, capture_output=True, text=True)
    assert 'PASS real DDR3 bridge:' in result.stdout
    print(result.stdout)


def test_imagedata_stream_through_real_ddr3_bridge():
    if not shutil.which('verilator'):
        pytest.skip('Verilator missing')
    out = ROOT / 'sim/sim_build_synth/raster_bridge'
    out.mkdir(parents=True, exist_ok=True)
    command = [
        'verilator', '-cc', '-exe', '-build', '-j', '2',
        '-Mdir', str(out/'obj'), '-o', str(out/'bench'),
        '--top-module', 'tb_raster_bridge',
        '-Wno-WIDTHEXPAND', '-Wno-WIDTHTRUNC',
        str(ROOT/'sim/tb_raster_bridge.sv'),
        str(ROOT/'rtl/engines/jmr_raster_engine.sv'),
        str(ROOT/'rtl/engines/jmr_ddr3_sram_bridge.sv'),
        str(ROOT/'sim/tb_raster_bridge.cpp'),
    ]
    subprocess.run(command, check=True, capture_output=True, text=True)
    result = subprocess.run([str(out/'bench')], check=True, capture_output=True, text=True)
    assert 'PASS ImageData real DDR3 bridge:' in result.stdout
    print(result.stdout)
