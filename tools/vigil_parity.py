"""Compare VIGIL's picture between PYTHON and FPGA-SIM, region by region.

    python3 tools/vigil_parity.py

Prints, for the title frame and for the first game frame, the palette-index
histogram of four bands (menu bar, HUD, room, footer) from both models. A
band whose histograms disagree is where the two machines draw differently —
that is the whole output; no pictures, no guesses.

Slow on purpose: the RTL takes a minute or two per frame.
"""
from __future__ import annotations

import os
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

BANDS = (("menu", 0, 24), ("hud", 24, 64), ("room", 64, 448), ("foot", 448, 480))


def bands(raw: bytes) -> dict:
    out = {}
    for name, y0, y1 in BANDS:
        out[name] = Counter(raw[y0 * 640:y1 * 640])
    return out


def show(tag: str, b: dict) -> None:
    for name, _y0, _y1 in BANDS:
        top = b[name].most_common(4)
        print(f"  {tag:6s} {name:5s} " + "  ".join(f"{i}:{n}" for i, n in top))


def python_frames() -> tuple[bytes, bytes]:
    """Title frame and the frame right after Space, from the Python model."""
    from functional_model.jsb_format import ProgramImage
    from functional_model.machine import Machine
    from runtime.backend import PythonBackend
    from tools.compile_js import compile_html_text, encode_html_chunk

    html = ROOT / "storage" / "VIGIL.HTML"
    image = ProgramImage(encode_html_chunk(compile_html_text(
        html.read_text(), source_path=html)))
    b = PythonBackend(Machine(storage_root=ROOT / "storage"))
    b.desktop.visible = False
    b.machine._start_html_image(image)
    try:
        for _ in range(8):
            b.frame_tick()
        title = bytes(b.framebuffer().front)
        b.machine.input.key_event(32, " ", True)
        b.frame_tick()
        b.machine.input.key_event(32, " ", False)
        for _ in range(6):
            b.frame_tick()
        play = bytes(b.framebuffer().front)
        return title, play
    finally:
        b.shutdown()


def rtl_frames() -> tuple[bytes, bytes]:
    from runtime.sim_backend import SimBackend
    from tests.test_rtl_snippets import _fb_raw
    from tools.make_sd_image import open_volume

    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        raise SystemExit("FPGA-SIM RTL binary missing")

    def frame() -> bytes:
        for _ in range(200000):
            sim._rpc("TICKN 1")
            if "sname=S_WAIT_FRAME" in sim._rpc("VMSTAT?"):
                break
        sim._rpc("FRAME")
        return _fb_raw(sim)

    image = open_volume(ROOT / "card.img").read_file("VIGIL.JSH")
    try:
        for _ in range(300):
            sim._rpc("TICK")
        with tempfile.TemporaryDirectory(prefix="vigil_parity_") as tmp:
            jsh = Path(tmp) / "VIGIL.JSH"
            jsh.write_bytes(image)
            if not sim._rpc(f"JSHLOAD {jsh}").startswith("OK"):
                raise SystemExit("JSHLOAD failed")
            for _ in range(6):
                title = frame()
            sim.key_event(32, " ", True)
            frame()
            sim.key_event(32, " ", False)
            for _ in range(6):
                play = frame()
        return title, play
    finally:
        sim.shutdown()


def main() -> int:
    os.environ.pop("JMR_SIM_HOST", None)
    print("python model:")
    p_title, p_play = python_frames()
    show("title", bands(p_title))
    show("play", bands(p_play))
    print("fpga-sim:")
    r_title, r_play = rtl_frames()
    show("title", bands(r_title))
    show("play", bands(r_play))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
