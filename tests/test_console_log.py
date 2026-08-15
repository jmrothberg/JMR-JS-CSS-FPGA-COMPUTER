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


def test_unknown_command_sn_error():
    """laod (typo) must print ?SN ERROR, not silent READY."""
    m = Machine()
    out = m.execute_line("laod")
    assert out and out[0].startswith("?SN ERROR"), out
    out = m.execute_line("xyzzy")
    assert out and out[0].startswith("?SN ERROR"), out
    # Real JS still runs
    out = m.execute_line('console.log("HI")')
    assert out[0] == "HI"


def test_missing_file_fn():
    m = Machine()
    out = m.execute_line('LOAD "NOPE.HTML"')
    assert out and out[0].startswith("?FN FILE NOT FOUND"), out


def test_list_long_data_uri_pages_to_mark():
    """A multi-KB data:image line must MORE and still list the marker after it."""
    m = Machine()
    uri = 'var s = "data:image/png;base64,' + ("A" * 3000) + '";'
    m.source_lines = ["<html>", "<script>", uri, "</script>", "<!--MARK-->", "</html>"]
    out = m.execute_line("LIST")
    blob = "\n".join(out)
    assert "MARK" in blob, blob[-200:]
    assert "data:image" in blob or "AAAA" in blob


def test_dir_and_load_rectdemo():
    m = Machine()
    c = Console(m)
    c.boot()
    names = m.storage.catalog()
    assert "RECTDEMO.JS" in names
    out = c.handle_line("DIR")
    assert any(x == "RECTDEMO.JS" or x.endswith("RECTDEMO.JS") for x in out)
    # PYTHON DIR is names only — no "1  RECTDEMO.JS"
    for row in out:
        if "RECTDEMO" in row:
            assert not row[:1].isdigit() or not row[1:2].isspace(), row
    out = c.handle_line("LOAD RECTDEMO.JS")
    assert out[0].startswith("LOADED")
    out = c.handle_line("RUN")
    assert any("HELLO FROM CARD" in x or "RECT DEMO" in x for x in out)


def test_dir_names_only_hides_jsb():
    m = Machine()
    names = m.execute_line("DIR")
    assert names, names
    assert not any(n.upper().endswith(".JSB") or n.upper().endswith(".JSH") for n in names)
    assert not any(n[:1].isdigit() and (len(n) > 1 and n[1] in " \t") for n in names)
    assert any("INVADERS.HTML" in n or n == "INVADERS.HTML" for n in names)


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


def test_list_more_esc_aborts():
    """Space pages; Esc must abort even if hard_break follows (GUI order)."""
    m = Machine()
    m.source_lines = [f"line{i}" for i in range(40)]
    hits = {"n": 0}

    def idle():
        if m.console_log and m.console_log[-1] == "-- MORE --":
            hits["n"] += 1
            if hits["n"] == 1:
                m.push_key("\x1b")
                m.hard_break()

    m.more_idle = idle
    out = m.execute_line("LIST")
    m.more_idle = None
    assert hits["n"] >= 1, "never parked on MORE"
    assert len(out) < 40, len(out)


def test_python_backend_more_waiting():
    from runtime.backend import PythonBackend

    m = Machine()
    py = PythonBackend(m)
    assert py.more_waiting is False
    m.source_lines = [f"line{i}" for i in range(40)]
    seen = {"ok": False}

    def idle():
        if py.more_waiting:
            seen["ok"] = True
            m.push_key("\x1b")

    m.more_idle = idle
    m.execute_line("LIST")
    m.more_idle = None
    assert seen["ok"] is True
    assert py.more_waiting is False


def test_load_html_reports_line_count():
    m = Machine()
    out = m.execute_line('LOAD "RECTDEMO.JS"')
    assert out[0].startswith("LOADED"), out
    assert "LINES" in out[0], out[0]


def test_list_after_run_still_source_not_bytecode():
    m = Machine()
    m.execute_line('LOAD "RECTDEMO.JS"')
    src0 = list(m.source_lines)
    m.execute_line("RUN")
    assert m.source_lines == src0
    assert any("fillRect" in (ln or "") for ln in m.source_lines)


def test_sim_run_wait_honors_break():
    """Fat HTML RUN wait must stop when hard_break sets the flag (no Donkey)."""
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    sim._started = True
    sim._loaded_name = "X.HTML"
    sim._last_jsh_bytes = 2_400_000
    calls = {"tickn": 0}

    def rpc(cmd: str) -> str:
        if str(cmd).startswith("TICKN"):
            calls["tickn"] += 1
            sim._break_run_wait = True
            return "OK"
        if cmd == "STATUS?":
            return "running=0"
        return "OK"

    sim._rpc = rpc  # type: ignore[method-assign]
    sim._html_loaded_stem = lambda: "X"  # type: ignore[method-assign]
    sim._compile_on_run_html = lambda: True  # type: ignore[method-assign]
    sim._sync_glass = lambda *a, **k: None  # type: ignore[method-assign]
    sim._sync_palette = lambda: None  # type: ignore[method-assign]
    sim._abort_more = lambda: None  # type: ignore[method-assign]
    sim._log.type_line = lambda t: None  # type: ignore[method-assign]
    sim.type_line("RUN")
    assert calls["tickn"] <= 2, calls["tickn"]


def test_load_wait_ignores_stale_loaded():
    """A previous LOADED on glass must not end the wait for this LOAD."""
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    sim._started = True
    sim._loaded_name = "DONKEY.HTML"
    sim._screen = "LOADED INVADERS.HTML (1038 LINES)\nREADY\n> "
    calls = {"tickn": 0}

    def rpc(cmd: str) -> str:
        if str(cmd).startswith("LINE"):
            return "OK"
        if str(cmd).startswith("TICKN"):
            calls["tickn"] += 1
            if calls["tickn"] >= 2:
                sim._screen = "LOADED DONKEY.HTML (1121 LINES)\nREADY\n> "
            return "OK"
        if cmd == "SCREEN?":
            return "SCREEN " + sim._screen.replace("\n", "\\n")
        if cmd == "STATUS?":
            return "running=0"
        if cmd.startswith("FB?"):
            return "FB SAME"
        return "OK"

    sim._rpc = rpc  # type: ignore[method-assign]
    sim._html_loaded_stem = lambda: "DONKEY"  # type: ignore[method-assign]
    sim._sync_glass = lambda *a, **k: None  # type: ignore[method-assign]
    sim._sync_palette = lambda: None  # type: ignore[method-assign]
    sim._abort_more = lambda: None  # type: ignore[method-assign]
    sim._log.type_line = lambda t: None  # type: ignore[method-assign]
    sim._log.note = lambda t: None  # type: ignore[method-assign]
    sim.type_line('LOAD "DONKEY.HTML"')
    assert calls["tickn"] >= 2, calls["tickn"]
    assert "DONKEY" in sim._screen


def test_python_sim_dir_load_list_shape():
    """PYTHON glass is the spec: DIR names, LOAD LINES, LIST MORE. RTL skipped if missing."""
    m = Machine()
    names = m.execute_line("DIR")
    assert not any(n.upper().endswith((".JSB", ".JSH")) for n in names)
    assert any("INVADERS.HTML" in n for n in names)
    loaded = m.execute_line('LOAD "INVADERS.HTML"')
    assert loaded and loaded[0].startswith("LOADED") and "LINES" in loaded[0]
    assert "INVADERS" in loaded[0].upper()

    os_mod = __import__("os")
    from pathlib import Path

    synth = Path(__file__).resolve().parents[1] / "sim" / "sim_build_synth" / "jmr_js_sim_server"
    if os_mod.environ.get("JMR_SIM_HOST", "").strip() or not synth.is_file():
        return
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        return
    try:
        sim.type_line("DIR")
        st = sim.screen_text().replace("\\n", "\n")
        for ln in st.splitlines():
            t = ln.strip().upper()
            assert not t.endswith(".JSB"), ln
            assert not t.endswith(".JSH"), ln
        assert "INVADERS" in st.upper(), st[-400:]
        sim.type_line('LOAD "INVADERS.HTML"')
        st = sim.screen_text().replace("\\n", "\n")
        assert "LOADED" in st and "LINES" in st and "INVADERS" in st.upper(), st[-300:]
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        assert "-- MORE" in st, st[-400:]
    finally:
        sim.shutdown()


def test_save_after_load_roundtrip_line_count():
    m = Machine()
    m.execute_line('LOAD "RECTDEMO.JS"')
    n0 = len(m.source_lines)
    m.execute_line('SAVE "savetest.js"')
    m.execute_line("NEW")
    out = m.execute_line('LOAD "savetest.js"')
    assert out[0].startswith("LOADED"), out
    assert f"({n0} LINES)" in out[0], out[0]
    assert len(m.source_lines) == n0


def test_edit_cursor_insert_middle():
    from gui_jmr_js import apply_line_key

    buf, col = apply_line_key("</body>", 7, "Left")
    assert col == 6, col
    buf, col = apply_line_key(buf, col, "x", "x")
    assert buf == "</bodyx>" or buf[col - 1] == "x", (buf, col)
    assert "x" in buf


def test_invaders_arrows():
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
