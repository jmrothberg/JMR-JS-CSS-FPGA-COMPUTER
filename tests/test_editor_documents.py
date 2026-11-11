"""Editor titles, Save As sidecars, and compiling over an existing program.

Runs storage/EDITOR.HTML and the on-machine compiler chain on the Python
machine (as tests/test_iconedit.py does), each on a scratch card folder.
"""
import re
import shutil
from pathlib import Path

import pytest

from functional_model import jsb_format as jf
from functional_model.jsb_format import ProgramImage
from functional_model.machine import Machine
from hardware_model.js_vm import JsHwVm
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text, encode_html_chunk

ROOT = Path(__file__).resolve().parents[1]
STORAGE = ROOT / "storage"


def _mint(name):
    src = STORAGE / f"{name}.HTML"
    return encode_html_chunk(compile_html_text(src.read_text(), source_path=src))


def _editor(card, doc, text="<html></html>\n"):
    (card / "EDITOR.JSH").write_bytes(_mint("EDITOR"))
    (card / "SYSTEM.SYS").write_bytes((STORAGE / "SYSTEM.SYS").read_bytes())
    (card / doc).write_text(text)
    b = PythonBackend(Machine(storage_root=card))
    b.hard_break(quiet=True)
    assert b.machine.load_source(doc)[0].startswith("LOADED")
    b.machine.open_editor()
    for _ in range(4):
        b.frame_tick()
    return b


ADVANCES = re.search(r'strByte\("([A-Z]+)",i\)-64', (ROOT / "resources/toolbox/ui.js").read_text()).group(1)


def _width(text):
    return sum(ord(ADVANCES[ord(c) - 32]) - 64 for c in text)


def _title_is(b, text):
    """Black title ink in rows 36-55 is `text`, centred in the 8,34,612 window."""
    px = b.machine.canvas.back
    xs = [x for y in range(36, 56) for x in range(30, 600) if px[y * 640 + x] == 0]
    left = 8 + (612 - _width(text)) // 2
    return xs and abs(min(xs) - left) <= 2 and abs(max(xs) - (left + _width(text))) <= 3


def test_editor_title_is_the_document_name(tmp_path):
    b = _editor(tmp_path, "MYPROG.HTM")
    assert _title_is(b, "MYPROG.HTM") and not _title_is(b, "Editor")


def test_unnamed_editor_document_is_untitled(tmp_path):
    b = _editor(tmp_path, "MYPROG.HTM")
    b.machine.unnamed_document = True  # as sysDocument(2,...) leaves it
    b.machine.open_editor()
    for _ in range(4):
        b.frame_tick()
    assert _title_is(b, "untitled")


def test_save_as_new_name_copies_icon_and_art(tmp_path):
    b = _editor(tmp_path, "OLDGAME.HTM")
    icon, art = b"JIC1" + bytes(range(256)) * 4, bytes(range(256)) * 1200  # art spans two reads
    (tmp_path / "OLDGAME.ICN").write_bytes(icon)
    (tmp_path / "OLDGAME.ART").write_bytes(art)
    b.machine.source_name = "NEWGAME.HTM"  # what Save As leaves before it saves
    b.machine.input.key_event(113, "", True)
    b.machine.input.key_event(113, "", False)
    b.frame_tick()
    assert (tmp_path / "NEWGAME.ICN").read_bytes() == icon
    assert (tmp_path / "NEWGAME.ART").read_bytes() == art


def test_save_as_keeps_an_existing_icon_and_skips_documents(tmp_path):
    b = _editor(tmp_path, "OLDGAME.HTM")
    (tmp_path / "OLDGAME.ICN").write_bytes(b"old")
    (tmp_path / "OLDGAME.ART").write_bytes(b"art")
    (tmp_path / "NEWGAME.ICN").write_bytes(b"mine")
    b.machine.source_name = "NEWGAME.HTM"
    b.machine.input.key_event(113, "", True)
    b.frame_tick()
    assert (tmp_path / "NEWGAME.ICN").read_bytes() == b"mine"
    assert (tmp_path / "NEWGAME.ART").read_bytes() == b"art"
    b = _editor(tmp_path, "OLDGAME.HTM")
    b.machine.source_name = "NOTES.TXT"
    b.machine.input.key_event(113, "", True)
    b.frame_tick()
    assert not (tmp_path / "NOTES.ICN").exists()


# --- compiling a program that already has a .JSH --------------------------


def _card(tmp_path, title):
    for name in ("COMPILE.LNK", "COMPILER.JSH", "COMPIL2.JSH", "TOOLBOX.LNK", "TOOLBOX.ROM", "JSONRT.JS", "STRRT.JS", "BOTHRT.JS", "LSRT.JS"):
        shutil.copy(STORAGE / name, tmp_path / name)
    if (STORAGE / f"{title}.ARTX").is_file():
        shutil.copy(STORAGE / f"{title}.ARTX", tmp_path / f"{title}.ART")
    return tmp_path


def _compile(card, name, src):
    """The chain as COMPILE starts it: SOURCE named, NAME.ART head staged."""
    m = Machine(storage_root=card)
    m.source_name = name
    m._stage_source(src)
    m._preload_art()
    hw = JsHwVm()
    hw._m = m
    hw.step_budget = 4_000_000_000
    images = {n: ProgramImage((STORAGE / n).read_bytes()) if (STORAGE / n).is_file() else None
              for n in jf.COMPILE_CHAIN}
    images["ARTSCAN.JSH"] = ProgramImage(_mint("ARTSCAN"))
    sel = jf.COMPILE_ENTRY
    for _ in range(16):
        m._cmp_reset()
        hw.load_image(images[jf.COMPILE_CHAIN[sel]])
        assert hw.error is None, hw.error
        if m._cmp_status != jf.CMP_STATUS_NEXT:
            break
        sel = int(m.sram.mem[jf.cstg_word(jf.CSTG_HDR_PROGSEL) * 2])
    return m


def _render(blob):
    vm = JsHwVm()
    vm.load_image(ProgramImage(blob))
    for _ in range(6):
        vm.frame_tick()
    assert vm.error is None, vm.error
    pal = vm.canvas.palette
    return bytes(c for px in vm.canvas.back for c in pal[px])


def test_compile_replaces_an_existing_jsh_and_it_runs(tmp_path):
    card = _card(tmp_path, "BOXES")
    old = _mint("MENUEX")
    (card / "BOXES.JSH").write_bytes(old)
    src = (STORAGE / "BOXES.HTML").read_text()
    m = _compile(card, "BOXES.HTM", src)
    assert (m._cmp_status, m._cmp_len) == (0, 0), m._cmp_message()  # written by COMPILER, not the console
    new = (card / "BOXES.JSH").read_bytes()
    assert new != old and not (card / "BOXES.JS$").exists()
    assert _render(new) == _render(_mint("BOXES"))


def test_failed_compile_keeps_the_old_jsh(tmp_path):
    card = _card(tmp_path, "BOXES")
    old = _mint("MENUEX")
    (card / "BOXES.JSH").write_bytes(old)
    m = _compile(card, "BOXES.HTM", "<canvas></canvas><script>var a = ;</script>")
    assert m._cmp_status not in (0, jf.CMP_STATUS_NEXT)
    assert (card / "BOXES.JSH").read_bytes() == old


def test_compiled_sprite_program_carries_its_art(tmp_path):
    card = _card(tmp_path, "BOMBFAST")
    (card / "BOMBFAST.JSH").write_bytes(b"stale")
    m = _compile(card, "BOMBFAST.HTM", (STORAGE / "BOMBFAST.HTML").read_text())
    assert (m._cmp_status, m._cmp_len) == (0, 0), m._cmp_message()
    new = (card / "BOMBFAST.JSH").read_bytes()
    host = _mint("BOMBFAST")
    ProgramImage(new)
    assert new[new.index(b"ASET"):] == host[host.index(b"ASET"):]
