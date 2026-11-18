from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

from tools.gui_runtime import configure
from runtime.backend import PythonBackend

ROOT = Path(__file__).resolve().parents[1]


def test_published_root_configuration(monkeypatch):
    monkeypatch.delenv('JMR_CARD_IMG', raising=False)
    selected = configure(ROOT)
    assert selected['source'] == ROOT
    assert selected['disk'] == ROOT / 'card.img'
    assert selected['simulator'].is_relative_to(ROOT / 'sim')


def test_finder_uses_disk_bytes():
    backend = PythonBackend.__new__(PythonBackend)
    backend._finder_image = None
    backend.machine = Mock()
    backend.machine.storage.load_bytes.return_value = b'exact disk Finder'
    assert backend._finder_blob() == b'exact disk Finder'
    assert backend._finder_blob() == b'exact disk Finder'
    backend.machine.storage.load_bytes.assert_called_once_with('FINDER.JSH')


def test_fpga_sim_enter_at_prompt_without_edit_prefill():
    from gui_jmr_js import App
    from runtime.sim_backend import SimBackend

    # Exercise the real Enter handler and backend property without a second
    # simulator process or a Tk window. An empty line needs no RPC.
    backend = SimBackend.__new__(SimBackend)
    backend._transfer_active = False
    backend._running = False
    backend._editor_live = False
    app = App.__new__(App)
    app.backend = backend
    app._alive = True
    app._keys_down = set()
    app.line_buf = ' '
    app.line_col = 1
    app._boot_showing = Mock(return_value=False)
    app._log_key_event = Mock()
    app._key_status_text = Mock(return_value='')
    app._set_key_status = Mock()
    app._paint_prompt = Mock()
    app.canvas_label = Mock()
    app._refresh_fb = Mock()
    app._update_arch_monitor = Mock()

    assert app.on_key_press(SimpleNamespace(keysym='Return', char='\r')) == 'break'
    assert app.line_buf == ''
    assert app.line_col == 0
    app.canvas_label.focus_set.assert_called_once()
