import base64
import io
import pytest
from PIL import Image

from tools.prepare_port import prepare
from tools.compile_js import compile_html_text, encode_html_chunk


def test_extract_embedded_art_preserves_product_bytes_and_original(tmp_path):
    buffer = io.BytesIO()
    Image.new('RGBA', (2, 1), (255, 0, 0, 255)).save(buffer, format='PNG')
    uri = 'data:image/png;base64,' + base64.b64encode(buffer.getvalue()).decode()
    source = tmp_path/'GAME.HTML'
    original = f'<script>var img=new Image();img.src="{uri}";</script>'.encode()
    source.write_bytes(original)
    out = tmp_path/'prepared'
    report = prepare(source, out)
    assert source.read_bytes() == original
    assert report['compiled_program_and_art_byte_identical']
    assert len(list(out.glob('*.png'))) == 1
    before = encode_html_chunk(compile_html_text(original.decode(), source_path=source))
    after_path = out/'GAME.HTML'
    after = encode_html_chunk(compile_html_text(after_path.read_text(), source_path=after_path))
    assert before == after


def test_prepare_port_never_overwrites_existing_directory(tmp_path):
    out = tmp_path/'existing'
    out.mkdir()
    marker = out/'keep.txt'
    marker.write_text('keep')
    with pytest.raises(ValueError, match='new output directory'):
        prepare(tmp_path/'unused.HTML', out)
    assert marker.read_text() == 'keep'


def test_prepare_port_refuses_undecodable_embedded_art_without_output(tmp_path):
    source = tmp_path/'BAD.HTML'
    source.write_text('<script>var img=new Image();img.src="data:image/png;base64,broken";</script>')
    out = tmp_path/'prepared'
    with pytest.raises(ValueError, match='decodable'):
        prepare(source, out)
    assert not out.exists()
