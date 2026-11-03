import json
import subprocess
import sys
from pathlib import Path

from tools.check_port import check

ROOT = Path(__file__).resolve().parents[1]


def test_port_check_distinguishes_source_window_from_compiled_capacity(tmp_path):
    path = tmp_path/'GAME.HTML'
    path.write_text('<!--' + 'x'*66000 + '--><script>var n=1;</script>')
    report = check(path)
    assert report['usage']['source_bytes'] > report['limits']['source_bytes']
    assert report['usage']['code_bytes_including_trailers'] < 81920
    assert report['warnings'] and not report['errors']


def test_port_check_flags_compiled_api_without_rtl_execution(tmp_path):
    path = tmp_path/'GAME.HTML'
    path.write_text('<script>var o={x:1};var keys=Object.keys(o);</script>')
    report = check(path)
    assert any('Object.keys' in error for error in report['errors'])


def test_port_check_compile_error_is_a_readable_report(tmp_path):
    path = tmp_path/'BAD.HTML'
    path.write_text('<script>var = ;</script>')
    result = subprocess.run([sys.executable, str(ROOT/'tools/check_port.py'),
                             str(path), '--json'], capture_output=True, text=True)
    assert result.returncode == 1
    assert not result.stderr
    assert 'HTML line' in json.loads(result.stdout)['errors'][0]
