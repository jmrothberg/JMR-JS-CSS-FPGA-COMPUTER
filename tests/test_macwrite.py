"""MACWRITE: a MacWrite word processor written as a card program.

Runs storage/MACWRITE.HTML on the Python machine, types at it and reads the
document from the arena (characters at 69632, styles at 102400, fonts at
135168, line records at 8192). Also checks that Finder opens .WRT and .PNT
files in MacWrite and MacPaint through the same hand-off TRS-80 BASIC uses,
and that MacPaint loads the picture it is handed.
"""
import shutil
import struct
from pathlib import Path

import pytest

from functional_model.jsb_format import FLAG_TOOLBOX, PROGRAM_CODE_WORDS, TOOLBOX_WORDS, ProgramImage
from functional_model.machine import Machine
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text, encode_html_chunk

ROOT = Path(__file__).resolve().parents[1]
STORAGE = ROOT / "storage"
TX, ST, ZT, LT = 69632, 102400, 135168, 8192


def _blob(name):
    src = STORAGE / name
    return encode_html_chunk(compile_html_text(src.read_text(), source_path=src))


class App:
    """One card program on the Python machine, started from the console."""

    def __init__(self, card, prog, arena=None):
        self.b = PythonBackend(Machine(storage_root=card))
        self.b.hard_break(quiet=True)
        for addr, data in (arena or {}).items():
            for i, v in enumerate(data):
                self.b.machine._nat_stg_write(addr + i, v)
        self.b.type_line(f'LOAD "{prog}.HTM"')
        self.b.type_line("RUN")
        self.frames(6)
        assert self.running()

    def running(self):
        return self.b.machine._hw_vm is not None and self.b.machine.running

    def frames(self, n=1):
        for _ in range(n):
            self.b.frame_tick()
            hw = self.b.machine._hw_vm
            assert hw is None or not hw.error, hw.error

    def var(self, name):
        hw = self.b.machine._hw_vm
        return hw._value64_json_host(hw._value_vars[hw.program_image.var_names.index(name)], set())

    def byte(self, addr):
        return int(self.b.machine._nat_stg_read(addr))

    def bytes(self, addr, n):
        return bytes(self.byte(addr + i) for i in range(n))

    def key(self, code, ch=""):
        self.b.key_event(code, ch, True)
        self.b.key_event(code, ch, False)
        self.frames(1)

    def type(self, text):
        for ch in text:
            if ch == "\n":
                self.key(13)
            else:
                self.key(ord(ch.upper()) if ch.isalpha() else ord(ch), ch)

    def name96(self, name):
        for i in range(16):
            self.b.machine._nat_stg_write(96 + i, ord(name[i]) if i < len(name) else 0)

    def text(self):
        return self.bytes(TX, int(self.var("TL")))


def _card(tmp_path, *progs):
    card = tmp_path / "card"
    card.mkdir(exist_ok=True)
    for prog in progs:
        (card / f"{prog}.JSH").write_bytes(_blob(f"{prog}.HTML"))
        (card / f"{prog}.HTM").write_bytes((STORAGE / f"{prog}.HTML").read_bytes())
    for name in ("SYSTEM.SYS", "PAINT.RSC"):
        shutil.copy(STORAGE / name, card / name)
    return card


def _handoff(name, ext):
    """What Finder leaves in the arena when it opens a document."""
    return {30000: name.encode() + b"\0", 30090: ext.encode() + b"\1"}


@pytest.fixture
def writer(tmp_path):
    card = _card(tmp_path, "MACWRITE")
    return App(card, "MACWRITE"), card


def test_image_fits_the_code_window():
    image = ProgramImage(_blob("MACWRITE.HTML"))
    resident = TOOLBOX_WORDS if image.flags & FLAG_TOOLBOX else 0
    assert image.code_end <= (PROGRAM_CODE_WORDS + resident) * 4


def test_typing_wraps_and_save_writes_wrt1(writer):
    w, card = writer
    assert w.var("booted") == 1 and w.var("monoOk") == 1
    words = "MacWrite wraps words at the right margin of the ruler. " * 3
    w.type(words.strip() + "\nEnd.")
    assert w.text() == b"\x01" + words.strip().encode() + b"\rEnd."
    lines = int(w.var("nL"))
    assert lines >= 4                      # ruler, at least two wrapped lines, End.
    starts = [struct.unpack("<I", w.bytes(LT + i * 24, 4))[0] for i in range(lines)]
    assert starts[0] == 0 and starts[1] == 1 and starts == sorted(starts)
    assert w.byte(LT + 19) & 1             # the first line is ruler 0
    for i in range(2, lines - 1):          # wrapped lines start after a space
        assert w.text()[starts[i] - 1] in (32, 13)
    w.name96("DOC.WRT")
    w.key(196)                             # File > Save As..., name chosen
    assert w.var("dirty") == 0 and w.var("named") == 1
    data = (card / "DOC.WRT").read_bytes()
    n = len(w.text())
    assert data[:4] == b"WRT1"
    assert struct.unpack("<IBBH", data[4:12]) == (n, 1, 1, 32)
    assert struct.unpack("<HHHBBB", data[32:41]) == (0, 432, 0, 0, 0, 0)
    assert data[64:64 + n] == w.text()
    assert data[64 + n:64 + 2 * n] == bytes(n) and data[64 + 2 * n:] == bytes(n)


def test_finder_hand_off_reopens_a_document(writer, tmp_path):
    w, card = writer
    w.type("Second time around.")
    w.key(174)                             # Bold, for what is typed next
    w.type(" Bold")
    w.name96("BACK.WRT")
    w.key(196)
    saved = w.text()
    again = App(card, "MACWRITE", _handoff("BACK.WRT", "WRT"))
    assert again.text() == saved
    assert again.var("named") == 1 and again.var("dirty") == 0
    assert again.byte(30090) == 0          # the hand-off is used once
    assert again.bytes(ST + len(saved) - 4, 4) == b"\1\1\1\1"


def test_text_files_open_and_save_as_plain_text(writer):
    w, card = writer
    (card / "NOTES.TXT").write_bytes(b"one\r\ntwo\n\tthree")
    w.name96("NOTES.TXT")
    w.key(193)                             # File > Open..., file chosen
    assert w.text() == b"\x01one\rtwo\r\tthree"
    w.type("!")
    w.key(195)                             # File > Save keeps it plain text
    assert (card / "NOTES.TXT").read_bytes() == b"!one\ntwo\n\tthree"


def test_styles_undo_find_and_change(writer):
    w, _ = writer
    w.type("red fish blue fish")
    w.key(165)                             # Select All
    w.key(174)                             # Bold
    w.key(172)                             # Monaco
    n = len(w.text())
    assert w.bytes(ST + 1, n - 1) == b"\1" * (n - 1)
    assert w.bytes(ZT + 1, n - 1) == b"\4" * (n - 1)
    w.key(160)                             # Undo the font change
    assert w.bytes(ZT + 1, n - 1) == bytes(n - 1)
    w.key(168)                             # Change...
    w.type("fish")
    w.key(9)
    w.type("cat")
    w.key(13)                              # Return: Find Next
    assert (w.var("sA"), w.var("sB")) == (5, 9)
    y0 = 58 + int(w.var("VT"))
    w.b.set_mouse(9 + 470, y0 + 66, 1)     # Change All
    w.frames(1)
    w.b.set_mouse(9 + 470, y0 + 66, 0)
    w.frames(1)
    assert w.text() == b"\x01red cat blue cat"


def test_esc_on_a_changed_document_asks_to_save(writer):
    w, card = writer
    w.type("Unsaved")
    w.key(27)
    assert w.running() and w.var("ask") == 1
    w.key(27)                              # Esc cancels the question
    assert w.running() and w.var("ask") == 0
    w.key(27)
    w.key(13)                              # Save: untitled, so it asks for a name
    assert w.running() and w.var("wantSA") == 1
    w.type("KEPT")
    w.key(13)
    w.frames(3)
    assert (card / "KEPT.WRT").read_bytes()[64:72] == b"\x01Unsaved"
    assert not w.running()


def test_macpaint_opens_a_picture_from_the_hand_off(tmp_path):
    card = _card(tmp_path, "MACPAINT")
    page = bytearray(92160)
    page[16 * 288 + 8] = 0x10              # one black pixel at 16,16
    page[100 * 288:100 * 288 + 50] = b"\x22" * 50
    (card / "DOT.PNT").write_bytes(b"PNT3" + struct.pack("<HH", 576, 320) + bytes(page))
    p = App(card, "MACPAINT", _handoff("DOT.PNT", "PNT"))
    p.frames(4)
    assert p.byte(30090) == 0
    assert p.bytes(4096, 92160) == bytes(page)


def _finder(tmp_path, monkeypatch):
    monkeypatch.setenv("JMR_FINDER", "builtin")
    for prog in ("MACPAINT", "MACWRITE"):
        (tmp_path / f"{prog}.HTM").write_text("x")
        (tmp_path / f"{prog}.JSH").write_bytes(b"JSH")
    (tmp_path / "TEST.PNT").write_bytes(b"PNT3")
    (tmp_path / "TEST.WRT").write_bytes(b"WRT1")
    src = STORAGE / "FINDER.HTML"
    image = ProgramImage(encode_html_chunk(compile_html_text(src.read_text(), source_path=src)))
    machine = Machine(storage_root=tmp_path)
    machine._start_html_image(image, share_machine=True)
    for _ in range(8):
        machine.frame_tick()
    return machine


def _slots(machine):
    rd = machine._nat_stg_read
    out = {}
    for s in range(int(rd(16386))):
        a = 8192 + s * 32
        n = int(rd(a))
        out[bytes(int(rd(a + 1 + i)) for i in range(n)).decode()] = (int(rd(a + 13)), int(rd(a + 15)))
    return out


@pytest.mark.parametrize("name,prog,ext", [("TEST.PNT", "MACPAINT.HTM", b"PNT"), ("TEST.WRT", "MACWRITE.HTM", b"WRT")])
def test_finder_shows_and_opens_pictures_and_documents(tmp_path, monkeypatch, name, prog, ext):
    machine = _finder(tmp_path, monkeypatch)
    kind, flags = _slots(machine)[name]
    assert kind == 2                       # a document, not a hidden sidecar
    assert flags & 64 and not flags & (2 | 16 | 32)
    for ch in "TEST":
        machine.input.key_event(ord(ch), "", True)
        machine.input.key_event(ord(ch), "", False)
        machine.frame_tick()
    if ext == b"WRT":                      # TEST.PNT sorts first; step to TEST.WRT
        machine.input.key_event(39, "", True)
        machine.input.key_event(39, "", False)
        machine.frame_tick()
    machine.input.key_event(161, "", True)  # File > Open
    machine.frame_tick()
    assert machine._finder_request == (prog, 0)
    rd = machine._nat_stg_read
    assert bytes(int(rd(30000 + i)) for i in range(9)) == name.encode() + b"\0"
    assert bytes(int(rd(30090 + i)) for i in range(4)) == ext + b"\1"
