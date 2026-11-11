"""Icon Editor lists programs that have no icon yet, and Save creates NAME.ICN.

Runs storage/ICONEDIT.HTML on the Python machine (as tests/test_trsbasic.py
does) with a card holding one program with an icon and one without.
"""
from pathlib import Path

from functional_model.desktop_icons import GENERIC_PROGRAM_ICON
from functional_model.machine import Machine
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text, encode_html_chunk

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "storage" / "ICONEDIT.HTML"
NAMES, ICON, LX, LY, ROWH = 16384, 8192, 28, 92, 18


def _names(rd, count):
    out = []
    for k in range(count):
        a = NAMES + k * 16
        name = "".join(chr(int(rd(a + i))) for i in range(15)).split("\0")[0]
        out.append((name, int(rd(a + 15))))
    return out


def test_program_without_icon_is_listed_and_save_creates_it(tmp_path):
    card = tmp_path / "card"
    card.mkdir()
    (card / "ICONEDIT.JSH").write_bytes(encode_html_chunk(compile_html_text(SRC.read_text(), source_path=SRC)))
    (card / "ICONEDIT.HTM").write_bytes(SRC.read_bytes())
    (card / "SYSTEM.SYS").write_bytes((ROOT / "storage" / "SYSTEM.SYS").read_bytes())
    (card / "ICONEDIT.ICN").write_bytes(GENERIC_PROGRAM_ICON.encode())
    (card / "MYPROG.JSH").write_bytes(b"\0" * 64)
    (card / "MYPROG.HTM").write_bytes(b"<canvas></canvas>")

    b = PythonBackend(Machine(storage_root=card))
    b.hard_break(quiet=True)
    b.type_line('LOAD "ICONEDIT.HTM"')
    b.type_line("RUN")
    for _ in range(8):
        b.frame_tick()
    hw = b.machine._hw_vm
    rd = b.machine._nat_stg_read
    var = lambda n: int(hw._value64_json_host(hw._value_vars[hw.program_image.var_names.index(n)], set()))
    names = _names(rd, var("count"))
    assert ("MYPROG.ICN", 1) in names, names
    assert ("ICONEDIT.ICN", 0) in names, names  # has an icon: listed as before
    assert names.count(("MYPROG.ICN", 1)) == 1, names  # .JSH and .HTM give one entry

    k = names.index(("MYPROG.ICN", 1))
    y = LY + k * ROWH + 4
    b.set_mouse(LX + 10, y, 1)
    b.frame_tick()
    b.set_mouse(LX + 10, y, 0)
    b.frame_tick()
    assert var("sel") == k
    assert bytes(int(rd(ICON + i)) for i in range(4)) == b"JIC1"

    b.key_event(160, "", True)   # File > Save
    b.key_event(160, "", False)
    for _ in range(4):
        b.frame_tick()
    icn = card / "MYPROG.ICN"
    assert icn.is_file() and icn.read_bytes()[:4] == b"JIC1" and len(icn.read_bytes()) == 1160
    assert int(rd(NAMES + k * 16 + 15)) == 0
