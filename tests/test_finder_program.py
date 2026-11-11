"""Finder program: a card program, not the built-in desktop.

The built-in desktop (functional_model/desktop.py) stays. These tests
run storage/FINDER.HTML on the Python machine. An idle frame, which
includes the shared Toolbox session frame, measures 313 steps. A View
repaint measures 21653.
"""
from pathlib import Path

from functional_model.jsb_format import FLAG_TOOLBOX, PROGRAM_CODE_WORDS, TOOLBOX_WORDS, ProgramImage
from functional_model.machine import Machine
from functional_model.storage_engine import StorageEngine
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text, encode_html_chunk

ROOT = Path(__file__).resolve().parents[1]
FINDER = ROOT / "storage" / "FINDER.HTML"
FINDER_JSH = ROOT / "storage" / "FINDER.JSH"
IDLE_BUDGET = 320
PAINT_BUDGET = 22000


def _image():
    blob = encode_html_chunk(compile_html_text(FINDER.read_text(), source_path=FINDER))
    image = ProgramImage(blob)
    resident = TOOLBOX_WORDS if image.flags & FLAG_TOOLBOX else 0
    assert image.code_end <= (PROGRAM_CODE_WORDS + resident) * 4
    return image


def _disk(tmp_path):
    (tmp_path / "GAME.HTM").write_text("game-body")
    (tmp_path / "GAME.JSH").write_bytes(b"OLDJSH")
    (tmp_path / "NOTE.TXT").write_text("hello note")
    (tmp_path / "FINDER.HTM").write_text("hidden")
    (tmp_path / "DESKTOP.FDR").write_bytes(b"nope")


def _boot(tmp_path, monkeypatch):
    monkeypatch.setenv("JMR_FINDER", "builtin")
    _disk(tmp_path)
    backend = PythonBackend(Machine(storage_root=tmp_path))
    backend.desktop.visible = False
    backend.machine._start_html_image(_image(), share_machine=True)
    return backend


def _frames(backend, n):
    for _ in range(n):
        backend.frame_tick()
    hw = backend.machine._hw_vm
    assert hw is not None and not hw.error


def _byte(machine, addr):
    return int(machine._nat_stg_read(addr))


def _settle(backend):
    for _ in range(12):
        backend.frame_tick()
        if _byte(backend.machine, 16384) == 1 and _byte(backend.machine, 16385) == 0 and _byte(backend.machine, 16600) == 0:
            break
    hw = backend.machine._hw_vm
    assert hw is not None and not hw.error
    assert _byte(backend.machine, 16384) == 1
    # The frame that cleared dirty was the paint. The next one is idle.
    backend.frame_tick()
    assert not hw.error


def _heap(hw):
    return sum(1 for obj in hw._value_objects if obj is not None)


def _key(backend, code):
    backend.key_event(code, "", True)
    backend.key_event(code, "", False)
    _frames(backend, 2)


def test_disk_natives_reject_a_bad_name_and_round_trip(tmp_path):
    machine = Machine(storage_root=tmp_path)
    (tmp_path / "NOTE.TXT").write_text("hello")
    machine._nat_stg_write(100, ord("?"))
    machine._nat_stg_write(101, 0)
    assert machine._nat_fs_remove(100) == -1
    assert machine._nat_fs_read(100, 0, 200, 4) == -1
    for i, ch in enumerate(b"NOTE.TXT"):
        machine._nat_stg_write(120 + i, ch)
    machine._nat_stg_write(128, 0)
    assert machine._nat_fs_read(120, 0, 200, 5) == 5
    assert bytes(int(machine._nat_stg_read(200 + i)) for i in range(5)) == b"hello"
    for i, ch in enumerate(b"COPY.TXT"):
        machine._nat_stg_write(140 + i, ch)
    machine._nat_stg_write(148, 0)
    machine._nat_stg_write(300, ord("!"))
    assert machine._nat_fs_write(140, 300, 1, 0) == 1
    machine._nat_stg_write(300, ord("?"))
    assert machine._nat_fs_write(140, 300, 1, 1) == 1
    assert (tmp_path / "COPY.TXT").read_bytes() == b"!?"
    for i, ch in enumerate(b"NEW.TXT"):
        machine._nat_stg_write(160 + i, ch)
    machine._nat_stg_write(167, 0)
    assert machine._nat_fs_rename(140, 160) == 0
    assert (tmp_path / "NEW.TXT").read_bytes() == b"!?"
    assert not (tmp_path / "COPY.TXT").exists()
    count = machine._nat_fs_list()
    assert count >= 2
    machine._nat_sys_run(160, 2)
    assert machine._finder_request == ("NEW.TXT", 2)
    assert machine.running is False


def test_finder_hides_itself_and_the_desktop_file(tmp_path):
    _disk(tmp_path)
    names = StorageEngine(tmp_path).catalog(all_files=True)
    assert "FINDER.HTM" not in names
    assert "DESKTOP.FDR" not in names
    assert "GAME.HTM" in names


def test_finder_window_folder_trash_and_idle_budget(tmp_path, monkeypatch):
    backend = _boot(tmp_path, monkeypatch)
    try:
        _settle(backend)
        machine = backend.machine
        assert machine.system_window[0] == 9
        assert _byte(machine, 16386) >= 3
        assert _byte(machine, 16389) >= 1
        kinds = {}
        for slot in range(_byte(machine, 16386)):
            base = 8192 + slot * 32
            n = _byte(machine, base)
            kinds[bytes(_byte(machine, base + 1 + i) for i in range(n))] = _byte(machine, base + 13)
        assert kinds[b"GAME.HTM"] == 0
        assert kinds[b"GAME.JSH"] == 4
        assert kinds[b"NOTE.TXT"] == 2
        hw = machine._hw_vm
        assert hw.last_steps <= IDLE_BUDGET
        heap = _heap(hw)
        for _ in range(1000):
            backend.frame_tick()
            assert not hw.error
            assert hw.last_steps <= IDLE_BUDGET
        assert _heap(hw) == heap
        _key(backend, 160)
        assert _byte(machine, 16388) == 1
        _key(backend, 170)
        assert _byte(machine, 16388) == 0
        backend.key_event(179, "", True)
        backend.key_event(179, "", False)
        backend.frame_tick()
        assert IDLE_BUDGET < hw.last_steps <= PAINT_BUDGET
        # Drag the first icon onto the Trash picture.
        backend.set_mouse(62, 108, 1)
        _frames(backend, 1)
        backend.set_mouse(580, 420, 1)
        _frames(backend, 1)
        backend.set_mouse(580, 420, 0)
        _frames(backend, 2)
        assert _byte(machine, 16387) == 1
        assert (tmp_path / "GAME.HTM").read_text() == "game-body"
        _key(backend, 185)
        assert _byte(machine, 16620) == 1
        backend.set_mouse(270, 285, 1)
        _frames(backend, 1)
        backend.set_mouse(270, 285, 0)
        _frames(backend, 2)
        assert _byte(machine, 16387) == 1  # Cancel leaves the file on the disk
        _key(backend, 185)
        backend.set_mouse(385, 285, 1)
        _frames(backend, 1)
        backend.set_mouse(385, 285, 0)
        _frames(backend, 2)
        assert _byte(machine, 16387) == 0
        assert not (tmp_path / "GAME.HTM").exists()
        assert (tmp_path / "GAME.JSH").read_bytes() == b"OLDJSH"
        assert (tmp_path / "DESKTOP.FDR").is_file()
    finally:
        backend.shutdown()


def test_open_asks_the_launcher_and_keeps_the_file(tmp_path, monkeypatch):
    monkeypatch.setenv("JMR_FINDER", "builtin")
    _disk(tmp_path)
    machine = Machine(storage_root=tmp_path)
    machine._start_html_image(_image(), share_machine=True)
    for _ in range(8):
        machine.frame_tick()
    machine.input.set_mouse(62, 108, 1)
    machine.frame_tick()
    machine.input.set_mouse(62, 108, 0)
    machine.frame_tick()
    assert machine._finder_request is None  # first click is never a double-click
    for _ in range(25):machine.frame_tick()
    machine.input.set_mouse(62, 108, 1)
    machine.frame_tick()
    machine.input.set_mouse(62, 108, 0)
    machine.frame_tick()
    assert int(machine._nat_stg_read(16409)) == 1
    machine.input.set_mouse(62, 108, 1)
    machine.frame_tick()
    machine.input.set_mouse(62, 108, 0)
    machine.frame_tick()
    assert int(machine._nat_stg_read(16409)) == 0
    assert machine._finder_request is not None
    assert machine._finder_request[0] == "GAME.HTM"
    # Opening stops the program inside mouse-up. The gesture must already be over.
    assert int(machine._nat_stg_read(16392)) == 0
    assert int(machine._nat_stg_read(16395)) == 0
    assert (tmp_path / "GAME.HTM").read_text() == "game-body"
    assert (tmp_path / "GAME.JSH").read_bytes() == b"OLDJSH"


def test_return_drops_icon_cache_a_paint_program_overwrote(tmp_path, monkeypatch):
    """MacPaint's color plane starts at arena byte 73728, over the icon runs."""
    monkeypatch.setenv("JMR_FINDER", "program")
    (tmp_path / "FINDER.JSH").write_bytes(FINDER_JSH.read_bytes())
    backend = PythonBackend(Machine(storage_root=tmp_path))
    try:
        _frames(backend, 6)
        machine = backend.machine
        hw = machine._hw_vm
        assert hw is not None and hw._value_raf
        machine._nat_stg_write(48000, 2)
        machine._finder_raf = list(hw._value_raf)
        backend._park_finder()
        machine._nat_stg_write(73728, 99)
        machine._ctx_sy = 0.05
        assert backend._resume_finder()
        assert _byte(machine, 48000) == 0
        assert machine._ctx_sx == 1 and machine._ctx_sy == 1
    finally:
        backend.shutdown()


def test_program_switch_boots_the_finder_and_builtin_does_not(tmp_path, monkeypatch):
    monkeypatch.setenv("JMR_FINDER", "builtin")
    builtin = PythonBackend(Machine(storage_root=tmp_path))
    try:
        assert builtin.desktop.visible and not builtin._finder_home
    finally:
        builtin.shutdown()
    monkeypatch.setenv("JMR_FINDER", "program")
    (tmp_path / "FINDER.JSH").write_bytes(FINDER_JSH.read_bytes())
    program = PythonBackend(Machine(storage_root=tmp_path))
    try:
        assert not program.desktop.visible and program._finder_home
        _frames(program, 3)
        assert program.machine.running and program.machine.system_window[0] == 9
    finally:
        program.shutdown()


def test_cold_finder_initializes_dirty_external_ram(tmp_path, monkeypatch):
    """DDR power-on contents and previous tools must not become UI state."""
    backend = _boot(tmp_path, monkeypatch)
    try:
        machine = backend.machine
        for addr in range(73728):
            machine._nat_stg_write(addr, 0xA5)
        # The hardware loader guarantees this flag, not a zeroed arena.
        machine._nat_stg_write(16384, 0)
        _settle(backend)
        assert [_byte(machine, a) for a in (16390, 16391, 16392, 16409, 16620)] == [0]*5
        win = bytes(_byte(machine, 16896+i) for i in range(16))
        import struct
        assert win[:5] == bytes([1, 0, 0, 0, 0])
        assert struct.unpack('<HHHH', win[5:13]) == (8, 34, 548, 354)
        _key(backend, 39)
        assert _byte(machine, 16446) > 0
    finally:
        backend.shutdown()


def test_menu_commands_exit_rename_and_open_does_not_park_editor(tmp_path, monkeypatch):
    backend = _boot(tmp_path, monkeypatch)
    try:
        _settle(backend)
        m = backend.machine
        _key(backend, 39)
        _key(backend, 13)
        assert _byte(m, 16409) == 1
        _key(backend, 179)  # View by name must not become filename input.
        assert _byte(m, 16409) == 0
        assert _byte(m, 16896+3) == 2
        _key(backend, 13)
        assert _byte(m, 16409) == 1
        # Use the machine directly: inspect the actual launch boundary before
        # the Python supervisor consumes its request and switches applications.
        m.input.key_event(161, '', True)
        m.frame_tick()
        assert m._finder_request is not None
        assert _byte(m, 16409) == 0
    finally:
        backend.shutdown()
