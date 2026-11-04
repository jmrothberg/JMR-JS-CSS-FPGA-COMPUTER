"""Optional artwork -> actual FAT sidecar -> PYTHON and RTL pixel parity."""

from io import BytesIO
from pathlib import Path
import shutil
import subprocess

from PIL import Image
import pytest

from functional_model.desktop_icons import (
    DesktopIcon, GENERIC_PROGRAM_ICON, ICON_FILE_BYTES, ICON_HEADER,
    decode_icon, icon_card_name,
)
from functional_model.storage_engine import StorageEngine
from tools.desktop_icons import convert_icon
from tools.make_sd_image import collect_storage_files, create_image

ROOT = Path(__file__).resolve().parents[1]


def _image_bytes(fmt="PNG"):
    im = Image.new("RGBA", (32, 32))
    # Exercise every mask bit, RGB332 value, row and RAM mask address.
    for y in range(32):
        for x in range(32):
            im.putpixel((x, y), (x * 8, y * 8, (x ^ y) * 8,
                                  255 if (x + y) % 3 else 0))
    buf = BytesIO()
    im.save(buf, format=fmt, **({"sizes": [(32, 32)]} if fmt == "ICO" else {}))
    return buf.getvalue()


@pytest.mark.parametrize("fmt", ["PNG", "ICO"])
def test_source_art_preserves_mask_and_native_passthrough(fmt):
    native = convert_icon(_image_bytes(fmt))
    icon = decode_icon(native)
    assert len(native) == ICON_FILE_BYTES
    assert convert_icon(native) == native
    for y in range(32):
        for x in range(32):
            r, g, b = x * 8, y * 8, (x ^ y) * 8
            assert icon.pixel(x, y) == (
                (r & 0xE0) | ((g >> 3) & 0x1C) | (b >> 6),
                bool((x + y) % 3))


def test_markdown_files_get_the_text_icon(tmp_path):
    from tools.pick_icon import missing_html

    (tmp_path / "Guide.md").write_text("# Guide\n")
    (tmp_path / "OTHER.MD").write_text("hello\n")
    (tmp_path / "HELP.MD").write_text("help\n")
    (tmp_path / "Guide.ICON").write_bytes(_image_bytes())
    # HELP has no icon, so the chooser must offer it. Guide already has one.
    offered = [p.name for p in missing_html(tmp_path)]
    assert offered == ["HELP.MD", "OTHER.MD"]
    (tmp_path / "GAME.HTML").write_text("<script>var x=1;</script>")
    pairs = dict(collect_storage_files(tmp_path))
    assert pairs["GUIDE.ICN"] == convert_icon(_image_bytes())
    assert pairs["OTHER.ICN"] == pairs["HELP.ICN"]
    assert pairs["HELP.ICN"] != pairs["GUIDE.ICN"]
    assert "GAME.ICN" not in pairs
    icon = decode_icon(pairs["HELP.ICN"])
    assert icon.pixel(0, 0) == (0, False)
    assert icon.pixel(16, 16)[1] is True


def test_titles_without_pictures_have_a_builtin_selection():
    from tools.pick_icon import stock_images

    stock = stock_images()
    assert [name for name, _image in stock] == [
        "Text", "Computer", "Folder", "Disk", "Trash", "Printer", "Case", "Generic",
        "Asteroids", "Pac-Man", "Missiles", "Tank", "Ship", "Ball", "Star",
        "Smile", "Picture", "Badge", "Ask", "Cards", "Mac", "Letter", "Diamond",
        "Floppy", "Basket", "Press", "Bomb", "Cabinet", "Pencil", "Balloon",
        "Papers", "Flag", "Suitcase", "Tab", "Watch", "Command", "Dog", "Speaker",
        "Hands", "Eject",
        "Rocks", "Saucer", "Thrust", "Chomp", "Ghost", "Pellet",
        "Cities", "Battery", "Skyline", "Turret", "Duel", "Splatter",
        "Curtain", "Catch", "Gems", "Red blue", "Overlap", "Pair",
        "Grid", "Mosaic", "Swatch", "Sword", "Arch", "Potion",
        "Amp", "Notes", "Wave", "Stick", "Pad", "Tilt"]
    assert len({image.tobytes() for _name, image in stock}) == len(stock)


def test_card_builder_matches_names_and_leaves_peer_assets_alone(tmp_path):
    (tmp_path / "MyGame.HTML").write_text("<script>var x=1;</script>")
    (tmp_path / "OTHER.HTML").write_text("<script>var y=2;</script>")
    (tmp_path / "NOICON.HTML").write_text("<script>var z=3;</script>")
    # A plain root PNG is a game's sprite, never its desktop icon.
    sprite = tmp_path / "NOICON.png"
    sprite.write_bytes(_image_bytes())
    source = tmp_path / "mygame.icons"
    source.write_bytes(_image_bytes("ICO"))
    icon_dir = tmp_path / "icons"
    icon_dir.mkdir()
    (icon_dir / "other.png").write_bytes(_image_bytes())
    before = {p: p.read_bytes() for p in tmp_path.rglob("*") if p.is_file()}
    pairs = dict(collect_storage_files(tmp_path))
    assert pairs["MYGAME.ICN"] == pairs["OTHER.ICN"]
    assert "NOICON.ICN" not in pairs
    assert "MYGAME.ICO" not in pairs
    assert "NOICON.PNG" not in pairs
    assert all(p.read_bytes() == data for p, data in before.items())
    assert icon_card_name("MyGame.HTML") == icon_card_name("MYGAME.HTM")


def test_bad_icon_does_not_prevent_program_from_reaching_card(tmp_path, capsys):
    (tmp_path / "GAME.HTML").write_text("<script>var x=1;</script>")
    (tmp_path / "GAME.ico").write_bytes(b"broken ICO")
    files = dict(collect_storage_files(tmp_path))
    assert "GAME.HTM" in files
    assert "GAME.ICN" not in files
    assert "unusable icon" in capsys.readouterr().out


def test_native_icon_is_read_from_the_same_mounted_fat_disk(tmp_path, monkeypatch):
    native = convert_icon(_image_bytes())
    path = create_image(tmp_path / "icons.img", size_bytes=4*1024*1024,
                        include_storage=False,
                        files=[("GAME.HTM", b"<script>var x=1;</script>"),
                               ("GAME.ICN", native), ("BAD.ICN", b"broken")])
    monkeypatch.setenv("JMR_CARD_IMG", str(path))
    storage = StorageEngine()
    assert storage.program_icon("GAME.HTML") == decode_icon(native)
    assert storage.program_icon("MISSING.HTM") == GENERIC_PROGRAM_ICON
    assert storage.program_icon("BAD.HTM") == GENERIC_PROGRAM_ICON
    assert "GAME.ICN" not in storage.catalog()
    assert "GAME.ICN" in storage.catalog(all_files=True)


@pytest.fixture(scope="module")
def rtl_icon_reader(tmp_path_factory):
    if not shutil.which("verilator"):
        pytest.skip("Verilator missing")
    folder = tmp_path_factory.mktemp("icon_rtl")
    exe = folder / "bench"
    subprocess.run([
        "verilator", "-cc", "-exe", "-build", "-j", "2",
        "-Mdir", str(folder / "obj"), "-o", str(exe),
        "--top-module", "jmr_icon_stream",
        str(ROOT / "rtl/engines/jmr_icon_stream.sv"),
        str(ROOT / "sim/tb_icon_stream.cpp"),
    ], check=True, capture_output=True, text=True)
    return exe


@pytest.mark.parametrize("failure", [None, "missing", "size", "header", "abort"])
def test_real_rtl_matches_all_python_pixels_under_stalls(rtl_icon_reader, tmp_path, failure):
    data = convert_icon(_image_bytes())
    declared_size = len(data)
    abort_after = -1
    expected = decode_icon(data)
    if failure:
        expected = GENERIC_PROGRAM_ICON
    if failure == "missing":
        declared_size = 0
        data = b""
    elif failure == "size":
        declared_size -= 1
    elif failure == "header":
        data = data[:6] + b"\x02" + data[7:]
    elif failure == "abort":
        abort_after = 721  # mid-drawing: fallback must repaint the entire icon
    src, out = tmp_path / "icon.bin", tmp_path / "pixels.bin"
    src.write_bytes(data)
    result = subprocess.run([str(rtl_icon_reader), str(src), str(declared_size),
                             str(abort_after), str(out), str(int(bool(failure)))],
                            check=True, capture_output=True, text=True)
    assert "PASS icon stream" in result.stdout
    wanted = bytes(v for y in range(32) for x in range(32)
                   for v in expected.pixel(x, y))
    assert out.read_bytes() == wanted


def test_f8_copies_documents_and_optional_program_icon(tmp_path):
    from tools.make_sd_image import put_host_files_on_card, list_card_put_files, card_html_sidecars, read_card_file
    card=create_image(tmp_path/"put.img",size_bytes=4*1024*1024,include_storage=False)
    html=tmp_path/"GAME.HTML";html.write_text("<script>var x=1;</script>")
    (tmp_path/"GAME.ICON").write_bytes(_image_bytes())
    manual=tmp_path/"GUIDE.md";manual.write_text("# Guide\nRead this file.\n")
    names=put_host_files_on_card([html,manual],card)
    assert set(names)=={"GAME.HTM","GAME.JSH","GAME.ICN","GUIDE.MD"}
    assert read_card_file("GUIDE.MD",card)==manual.read_bytes()
    assert read_card_file("GAME.ICN",card)==convert_icon(_image_bytes())
    available={n for n,size in list_card_put_files(card)}
    assert {"GUIDE.MD","GAME.ICN"}<=available
    assert set(card_html_sidecars("GAME.HTM",available))=={"GAME.JSH","GAME.ICN"}


def test_hidden_artwork_names_do_not_collide_and_readme_stays_on_host(tmp_path):
    from functional_model.desktop import display_name
    (tmp_path/'GAME.ARTX').write_bytes(b'binary')
    (tmp_path/'GAME.ARTJS').write_bytes(b'source')
    (tmp_path/'README.md').write_text('Folder guide')
    (tmp_path/'HELP.MD').write_text('Computer manual')
    files=dict(collect_storage_files(tmp_path))
    assert files['GAME.ART']==b'binary' and files['GAME.ARJ']==b'source'
    assert 'HELP.MD' in files and 'README.MD' not in files
    assert [display_name(n) for n in ('GAME.ARJ','GAME.ART','GAME.ICN')]==['GAME.ARTJS','GAME.ARTX','GAME.ICON']
