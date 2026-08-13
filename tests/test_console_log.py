"""Glass tests: console.log, EDIT, LIST MORE, invaders keys."""

from functional_model.console import Console
from functional_model.machine import BANNER, LIST_PAGE_LINES, READY, Machine
from functional_model.input_engine import KEY_LEFT


def test_boot_banner():
    c = Console()
    assert c.boot() == [BANNER, READY]


def test_console_log():
    c = Console()
    assert c.handle_line('console.log("HELLO")') == ["HELLO", READY]


def test_unknown_is_compile_or_sn():
    c = Console()
    out = c.handle_line("!!!")
    assert out[-1] == READY
    assert out[0].startswith("ERROR") or out[0].startswith("?SN")


def test_dir_and_load_rectdemo():
    m = Machine()
    c = Console(m)
    c.boot()
    names = m.storage.catalog()
    assert "RECTDEMO.JS" in names
    out = c.handle_line("LOAD RECTDEMO.JS")
    assert out[0].startswith("LOADED")
    out = c.handle_line("RUN")
    assert any("HELLO FROM CARD" in x or "RECT DEMO" in x for x in out)


def test_joy_bits():
    m = Machine()
    m.set_joy(0x15)
    assert m.execute_line("console.log(joy())")[0] == "21"


def test_edit_roundtrip():
    m = Machine()
    m.source_lines = ["aaa", "bbb", "ccc"]
    out = m.execute_line("EDIT 20")
    assert out[0].startswith("20 ")
    assert "bbb" in out[0]
    assert m._edit_waiting == 20
    assert m.edit_prefill() == "bbb"
    out = m.execute_line("bbb * 2")
    assert out == ["OK"]
    assert m.source_lines[1] == "bbb * 2"
    assert m._edit_waiting is None


def test_list_paged_auto_more():
    """Without GUI more_idle, MORE auto-continues after poll budget."""
    m = Machine()
    m.source_lines = [f"line{i}" for i in range(30)]
    # Bare LIST pages
    out = m.execute_line("LIST -")
    assert len(out) == 30
    assert any("-- MORE --" in x for x in m.console_log) or len(out) > LIST_PAGE_LINES


def test_invaders_arrows():
    m = Machine()
    m.boot_lines()
    m.execute_line("LOAD INVADERS.JS")
    out = m.execute_line("RUN")
    assert m.running
    assert m.vm.error is None
    m.set_key_bits(KEY_LEFT)
    px0 = m.vm.globals.get("px")
    m.frame_tick()
    assert m.vm.globals.get("px") < px0
