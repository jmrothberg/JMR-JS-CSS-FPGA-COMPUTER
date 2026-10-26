"""The actual core's board parameter must not truncate to a 16-bit counter."""
import shutil
import subprocess
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[1]


def test_board_frame_cadence():
    if not shutil.which('verilator'):
        pytest.skip('Verilator missing')
    out = ROOT / 'sim/sim_build_cadence'
    out.mkdir(parents=True, exist_ok=True)
    engines = ('jmr_keyboard_fifo jmr_video_vram jmr_console_engine jmr_mini_fb '
               'jmr_fb_present jmr_raster_engine jmr_fb_scanout jmr_rectdemo_engine '
               'jmr_value jmr_js_vm_pkg jmr_js_vm_exec64 jmr_js_vm jmr_sram_model '
               'jmr_palette_bram storage_engine').split()
    command = [
        'verilator', '-cc', '-exe', '-build', '-j', '2',
        '-Mdir', str(out/'obj'), '-o', str(out/'bench'),
        '--top-module', 'jmr_js_core', '-GFRAME_DIV=1666665',
        '-Wno-UNOPTTHREADS', '-Wno-WIDTHEXPAND', '-Wno-WIDTHTRUNC',
        '-Wno-MULTIDRIVEN', '-Wno-LATCH',
        *[str(ROOT/'rtl/engines'/f'{name}.sv') for name in engines],
        str(ROOT/'rtl/phys/sd_spi_master.sv'), str(ROOT/'rtl/jmr_js_core.sv'),
        str(ROOT/'sim/tb_frame_cadence.cpp'),
    ]
    subprocess.run(command, check=True, capture_output=True, text=True)
    result = subprocess.run([str(out/'bench')], cwd=ROOT/'sim', check=True,
                            capture_output=True, text=True)
    assert 'PASS board cadence:' in result.stdout
