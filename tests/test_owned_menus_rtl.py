"""Exact MacPaint menu contract through the real native RTL parser and mouse path."""
from pathlib import Path
import re
import shutil
import subprocess
import pytest

ROOT = Path(__file__).resolve().parents[1]

def test_macpaint_owned_menus_rtl(tmp_path):
    if not shutil.which("verilator"):
        pytest.skip("Verilator not installed")
    source = (ROOT / "storage/MACPAINT.HTML").read_text()
    spec = re.search(r'ctx.systemMenus="([^"]+)"', source).group(1)
    fixture = tmp_path / "menus.hex"
    fixture.write_text("".join(f"{ord(c):02x}\n" for c in spec))
    obj = tmp_path / "obj"
    files = ["rtl/engines/jmr_classic_ui_pkg.sv", "rtl/engines/jmr_classic_labels.sv",
             "rtl/engines/jmr_classic_ui.sv", "sim/tb_owned_menus.sv"]
    result = subprocess.run(["verilator", "--binary", "--timing", "-j", "4",
        "--top-module", "tb_owned_menus", "--Mdir", str(obj),
        "-Wno-PINMISSING", "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC", *files],
        cwd=ROOT, capture_output=True, text=True, timeout=120)
    assert result.returncode == 0, result.stdout + result.stderr
    result = subprocess.run([str(obj / "Vtb_owned_menus"), f"+length={len(spec)}",
        f"+menus={fixture}"], cwd=ROOT, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS exact MacPaint menus" in result.stdout
