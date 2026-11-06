from pathlib import Path
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
