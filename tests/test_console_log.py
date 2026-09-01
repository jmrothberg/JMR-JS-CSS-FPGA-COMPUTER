"""Glass tests: console.log, EDIT, LIST MORE."""

from functional_model.console import Console
from functional_model.machine import BANNER, LIST_PAGE_LINES, READY, Machine


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


def test_dir_and_load_joydemo():
    m = Machine()
    c = Console(m)
    c.boot()
    names = m.storage.catalog()
    assert any(n.upper().startswith("JOYDEMO") for n in names), names
    out = c.handle_line("DIR")
    assert any("JOYDEMO" in x.upper() for x in out), out
    for row in out:
        if "JOYDEMO" in row:
            assert not row[:1].isdigit() or not row[1:2].isspace(), row
    out = c.handle_line("LOAD JOYDEMO.HTML")
    assert out[0].startswith("LOADED")
    c.handle_line("RUN")
    assert m.running


def test_dir_names_only_hides_jsb():
    m = Machine()
    names = m.execute_line("DIR")
    assert names, names
    assert not any(n.upper().endswith(".JSB") or n.upper().endswith(".JSH") for n in names)
    assert not any(n[:1].isdigit() and (len(n) > 1 and n[1] in " \t") for n in names)
    assert any("INVADERS" in n.upper() for n in names)


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
    assert m.edit_prefill() == "20 bbb"
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
    out = m.execute_line('LOAD "JOYDEMO.HTML"')
    assert out[0].startswith("LOADED"), out
    assert "LINES" in out[0], out[0]


def test_list_after_run_still_source_not_bytecode():
    m = Machine()
    m.execute_line('LOAD "JOYDEMO.HTML"')
    src0 = list(m.source_lines)
    m.execute_line("RUN")
    assert m.source_lines == src0
    assert any("fillRect" in (ln or "") for ln in m.source_lines)


def test_sim_run_wait_honors_break():
    """HTML RUN streams an in-memory ProgramImage; no sidecar or FAT wait."""
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    sim._started = True
    sim._use_rtl = True
    sim._loaded_name = "X.HTML"
    sim._program_image = b"JSB1" + b"\0" * 8
    calls = {"tickn": 0, "progstart": 0}

    def rpc(cmd: str) -> str:
        if str(cmd) == "PROGSTART":
            calls["progstart"] += 1
            return "OK bytes=12"
        if str(cmd).startswith(("PROGBEGIN", "PROGDATA")):
            return "OK"
        if str(cmd).startswith("TICKN"):
            calls["tickn"] += 1
            sim._break_run_wait = True
            return "OK"
        if cmd == "STATUS?":
            return "running=0"
        return "OK"

    sim._rpc = rpc  # type: ignore[method-assign]
    sim._html_loaded_stem = lambda: "X"  # type: ignore[method-assign]
    sim._load_card_jsh = lambda: True  # type: ignore[method-assign]
    sim._sync_glass = lambda *a, **k: None  # type: ignore[method-assign]
    sim._sync_palette = lambda: None  # type: ignore[method-assign]
    sim._abort_more = lambda: None  # type: ignore[method-assign]
    sim._log.type_line = lambda t: None  # type: ignore[method-assign]
    sim.type_line("RUN")
    assert calls["progstart"] == 1, calls
    assert calls["tickn"] == 0, calls["tickn"]


def test_sim_compile_uses_loaded_editor_program_image():
    """RUN compiles the backend's edited source and keeps bytes in memory."""
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    sim._loaded_name = "X.HTML"
    sim._loaded_html_text = (
        '<canvas width="640" height="480"></canvas>'
        "<script>var editedValue=41+1;</script>"
    )
    sim._html_lines = sim._loaded_html_text.splitlines()
    assert sim._compile_on_run_html() is True
    assert sim._program_image.startswith(b"JSB1")
    assert sim._html_chunk is not None
    assert "editedValue" in sim._html_chunk.names
    from functional_model.jsb_format import FLAG_ASET, FLAG_VALUE64, ProgramImage

    image = ProgramImage(sim._program_image)
    assert image.flags & FLAG_VALUE64
    assert image.flags & FLAG_ASET


def test_python_html_run_does_not_create_sidecar():
    """Product RUN keeps the ProgramImage in memory; HTML remains the only file."""
    from pathlib import Path

    m = Machine()
    m.source_name = "ZZNOSIDE.HTML"
    sidecar = Path(m.storage.root) / "ZZNOSIDE.JSH"
    assert not sidecar.exists()
    out = m._run_html_bytecode(
        '<canvas width="640" height="480"></canvas><script>var x=1;</script>'
    )
    # No rAF → VM finishes (running is false). The check is: no .JSH written.
    assert out and not str(out[0]).startswith("ERROR"), out
    assert not sidecar.exists()


def test_sim_edit_updates_compile_source():
    """The line entered after EDIT changes the source used by the next RUN."""
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    sim._started = True
    sim._loaded_name = "X.HTML"
    sim._loaded_html_text = "<script>\nvar value=1;\n</script>"
    sim._html_lines = sim._loaded_html_text.splitlines()
    sim._rpc = lambda cmd: "OK"  # type: ignore[method-assign]
    sim._abort_more = lambda: None  # type: ignore[method-assign]
    sim._sync_glass = lambda *a, **k: None  # type: ignore[method-assign]
    sim._note_edit_prefill = lambda: None  # type: ignore[method-assign]
    sim._log.type_line = lambda t: None  # type: ignore[method-assign]
    sim.type_line("EDIT 20")
    sim.type_line("20 var value=2;")
    assert sim._html_lines[1] == "var value=2;"
    assert "var value=2;" in sim._loaded_html_text


def test_load_wait_ignores_stale_loaded():
    """FPGA-SIM LOAD waits for THIS stem on FAT glass, not a leftover LOADED."""
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    sim._started = True
    sim._use_rtl = True
    sim._loaded_name = "DONKEY.HTML"
    sim._screen = "LOADED INVADERS.HTML (1038 LINES)\nREADY\n> "
    calls = {"tickn": 0, "line": 0}

    def rpc(cmd: str) -> str:
        if str(cmd).startswith("LINE"):
            calls["line"] += 1
            return "OK"
        if str(cmd).startswith("TICKN"):
            calls["tickn"] += 1
            sim._screen = "LOADED DONKEY.HTM (1121 LINES)\nREADY\n> "
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
    sim._mirror_card_html = lambda stem: None  # type: ignore[method-assign]
    sim._sync_glass = lambda *a, **k: None  # type: ignore[method-assign]
    sim._sync_palette = lambda: None  # type: ignore[method-assign]
    sim._abort_more = lambda: None  # type: ignore[method-assign]
    sim._log.type_line = lambda t: None  # type: ignore[method-assign]
    sim._log.note = lambda t: None  # type: ignore[method-assign]
    sim.type_line('LOAD "DONKEY.HTML"')
    assert calls["line"] == 1, calls
    assert calls["tickn"] >= 1, calls
    assert "DONKEY" in sim._screen


def test_python_sim_dir_load_list_shape():
    """PYTHON glass is the spec: DIR names, LOAD LINES, LIST MORE. RTL skipped if missing."""
    m = Machine()
    names = m.execute_line("DIR")
    assert not any(n.upper().endswith((".JSB", ".JSH")) for n in names)
    assert any("INVADERS" in n.upper() for n in names)
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
    import os
    import shutil
    import tempfile
    from pathlib import Path

    root = Path(__file__).resolve().parents[1]
    real = root / "card.img"
    if not real.is_file():
        return
    scratch = Path(tempfile.gettempdir()) / "jmr_save_test_card.img"
    shutil.copy2(real, scratch)
    prev = os.environ.get("JMR_CARD_IMG")
    os.environ["JMR_CARD_IMG"] = str(scratch)
    try:
        m = Machine()
        m.execute_line('LOAD "JOYDEMO.HTML"')
        n0 = len(m.source_lines)
        m.execute_line('SAVE "savetest.js"')
        m.execute_line("NEW")
        out = m.execute_line('LOAD "savetest.js"')
        assert out[0].startswith("LOADED"), out
        assert f"({n0} LINES)" in out[0], out[0]
        assert len(m.source_lines) == n0
    finally:
        if prev is None:
            os.environ.pop("JMR_CARD_IMG", None)
        else:
            os.environ["JMR_CARD_IMG"] = prev


def test_edit_cursor_insert_middle():
    from gui_jmr_js import apply_line_key

    buf, col = apply_line_key("</body>", 7, "Left")
    assert col == 6, col
    buf, col = apply_line_key(buf, col, "x", "x")
    assert buf == "</bodyx>" or buf[col - 1] == "x", (buf, col)
    assert "x" in buf


def test_clip_to_editor_keys_ascii_newline_tab():
    from gui_jmr_js import clip_to_editor_keys

    assert clip_to_editor_keys("ab\n\tc") == [97, 98, 13, 32, 32, 99]
    assert clip_to_editor_keys("qrst") == [113, 114, 115, 116]
    assert 10 not in clip_to_editor_keys("line\n")

