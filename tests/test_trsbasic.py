"""TRSBASIC: a TRS-80 Level II BASIC interpreter written as a card program.

Runs storage/TRSBASIC.HTML on the Python machine, types BASIC at it and reads
its 64x16 text screen from the arena (bytes 4096-5119). No hardware help is
involved: the program is ordinary JavaScript on the normal VM.
"""
import shutil
from pathlib import Path

import pytest

from functional_model.jsb_format import FLAG_TOOLBOX, PROGRAM_CODE_WORDS, TOOLBOX_WORDS, ProgramImage
from functional_model.machine import Machine
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text, encode_html_chunk

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "storage" / "TRSBASIC.HTML"
SCREEN = 4096


def _blob():
    return encode_html_chunk(compile_html_text(SRC.read_text(), source_path=SRC))


class Basic:
    def __init__(self, card):
        self.b = PythonBackend(Machine(storage_root=card))
        self.b.hard_break(quiet=True)
        self.b.type_line('LOAD "TRSBASIC.HTM"')
        self.b.type_line("RUN")
        self.frames(4)
        assert self.b.machine.running

    def frames(self, n=1):
        for _ in range(n):
            self.b.frame_tick()
            hw = self.b.machine._hw_vm
            assert hw is None or not hw.error, hw.error

    def var(self, name):
        hw = self.b.machine._hw_vm
        return hw._value64_json_host(hw._value_vars[hw.program_image.var_names.index(name)], set())

    def screen(self):
        rd = self.b.machine._nat_stg_read
        rows = []
        for r in range(16):
            rows.append("".join(chr(int(rd(SCREEN + r * 64 + i))) for i in range(64)).rstrip())
        return rows

    def type(self, text):
        for ch in text:
            code = ord(ch.upper()) if ch.isalpha() else ord(ch)
            self.b.key_event(code, ch, True)
            self.b.key_event(code, ch, False)
            self.frames(1)
        self.b.key_event(13, "Enter", True)
        self.b.key_event(13, "Enter", False)
        self.frames(1)

    def ready(self, limit=4000):
        n = 0
        while int(self.var("md")) == 1 or int(self.var("md")) == 3:
            assert n < limit, "\n".join(self.screen())
            self.frames(5)
            n += 5

    def do(self, line):
        self.type(line)
        self.ready()


@pytest.fixture
def basic(tmp_path):
    card = tmp_path / "card"
    card.mkdir()
    (card / "TRSBASIC.JSH").write_bytes(_blob())
    (card / "TRSBASIC.HTM").write_bytes(SRC.read_bytes())
    (card / "SYSTEM.SYS").write_bytes((ROOT / "storage" / "SYSTEM.SYS").read_bytes())
    for name in ("GUESS.BAS", "PRIMES.BAS"):
        shutil.copy(ROOT / "storage" / name, card / name)
    return Basic(card), card


def test_image_fits_the_code_window():
    image = ProgramImage(_blob())
    resident = TOOLBOX_WORDS if image.flags & FLAG_TOOLBOX else 0
    assert image.code_end <= (PROGRAM_CODE_WORDS + resident) * 4


def test_expressions_and_strings(basic):
    m, _ = basic
    m.do('PRINT 1+2*3;2^10;-2^2;7 MOD 3;1/3;1E6;.001;NOT 0;5 AND 3;5 OR 3')
    assert " 7  1024 -4  1  .333333  1E+06  1E-03 -1  1  7" in m.screen()
    m.do('A$="HELLO":PRINT MID$(A$,2,3);LEFT$(A$,2);RIGHT$(A$,2);LEN(A$);ASC("A");CHR$(66);STR$(-1.5);VAL("2E2")')
    assert "ELLHELO 5  65 B-1.5 200" in m.screen()
    m.do('PRINT INSTR("HELLO","LL");INSTR(3,"ABCABC","B");STRING$(3,"*");"AB"<"AC";INT(-2.5);FIX(-2.5)')
    assert " 3  5 ***-1 -3 -2" in m.screen()


def test_program_control_flow(basic):
    m, _ = basic
    for line in (
        '10 DIM A(3,3):FOR I=0 TO 3:FOR J=0 TO 3:A(I,J)=I*J:NEXT J,I',
        '20 GOSUB 100:ON 2 GOTO 30,40',
        '30 PRINT "BAD"',
        '40 READ X,Y$:PRINT X;Y$;A(3,2);',
        '50 DEF FNS(Z)=Z*Z+1:PRINT FNS(3);',
        '60 IF X=1 THEN PRINT "Y" ELSE PRINT "N"',
        '70 END',
        '100 S=0:FOR K=1 TO 10 STEP 2:S=S+K:NEXT K:PRINT S;:RETURN',
        '200 DATA 7,"Q,R"',
    ):
        m.type(line)
    m.do("RUN")
    assert " 25  7 Q,R 6  10 N" in m.screen()


def test_save_load_round_trip(basic):
    m, card = basic
    m.do('10 PRINT "ROUND TRIP";')
    m.do('20 FOR I=1 TO 3:PRINT I;:NEXT')
    m.do('SAVE "RT"')
    assert (card / "RT.BAS").read_bytes() == b'10 PRINT "ROUND TRIP";\n20 FOR I=1 TO 3:PRINT I;:NEXT\n'
    m.do("NEW")
    m.do('LOAD "RT"')
    m.do("RUN")
    assert "ROUND TRIP 1  2  3" in m.screen()
    m.do('KILL "RT"')
    assert not (card / "RT.BAS").exists()


def test_tape_input_reads_records(basic):
    m, card = basic
    (card / "T.DAT").write_bytes(b' 12 \n"A, B" X\n3,4\n')
    for line in ('10 INPUT#-1,N', '20 INPUT#-1,L$', '30 INPUT#-1,P,Q', '40 PRINT N;L$;P+Q'):
        m.type(line)
    m.do('TAPE "T.DAT"')
    m.do("RUN")
    assert ' 12 "A, B" X 7' in m.screen()


def test_input_and_errors(basic):
    m, _ = basic
    m.do('10 INPUT "NAME";N$,K')
    m.type("RUN")
    m.frames(20)
    assert int(m.var("md")) == 2
    m.type("BOB,42")
    m.do("PRINT N$;K")
    assert "BOB 42" in m.screen()
    m.do("GOTO 999")
    assert "?UL ERROR" in m.screen()


def test_loads_and_runs_a_shipped_program(basic):
    m, _ = basic
    m.do('LOAD "PRIMES"')
    m.do("RUN")
    assert " 168 PRIMES." in m.screen()


def test_scott_adams_menu_mounts_the_chosen_adventure(basic):
    m, card = basic
    shutil.copy(ROOT / "storage" / "SCOTTADV.BAS", card / "SCOTTADV.BAS")
    shutil.copy(ROOT / "storage" / "ADV02.DAT", card / "ADV02.DAT")
    m.do('LOAD "SCOTTADV"')
    m.type("RUN")
    m.frames(40)
    assert int(m.var("md")) == 2 and "  2  PIRATE ADVENTURE" in m.screen()
    m.type("9")
    m.frames(10)
    assert "PLEASE TYPE 1 TO 5" in m.screen()
    m.type("2")
    m.ready(limit=400000)
    assert int(m.var("md")) == 2, "\n".join(m.screen())
    text = "\n".join(m.screen())
    assert "?NO TAPE" not in text and "FLAT IN LONDON" in text.upper(), text
