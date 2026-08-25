"""Standalone HTML RUN (CONSTITUTION rule 10): RUN with NAME.JSH on the
card must boot the title through the console's FAT path - no host
stream, no PC. The card builder mints .JSH beside every .HTML
(tools/make_sd_image.compile_sidecars); on a FAT miss the console falls
back to the host tether (whose ESC + ~10.7s timeout end in ?NB).
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tests.test_rtl_snippets import _fb_nz, _scratch_card, _sim


def test_rtl_standalone_html_run_from_card_jsh():
    from tools.compile_js import compile_html_text, encode_html_chunk
    from tools.make_sd_image import patch_card_file

    html = """<!DOCTYPE html>
<html><body><canvas id="c" width="640" height="480"></canvas><script>
var c = document.getElementById('c').getContext('2d');
function tick() {
  c.fillStyle = '#f00';
  c.fillRect(20, 20, 60, 40);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
</script></body></html>
"""
    sim = _sim()
    try:
        card = _scratch_card() or (ROOT / "card.img")
        patch_card_file(card, "SBOX.HTML", html.encode())
        patch_card_file(card, "SBOX.JSH",
                        encode_html_chunk(compile_html_text(html)))
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "SBOX.HTML"')
        # raw console typing: the backend's type_line intercepts RUN for
        # HTML and host-streams via RPC - the standalone path under test
        # is the RTL console's own FAT .JSH load, so drive it with LINE
        sim._rpc("LINE RUN")
        # standalone: the console loads SBOX.JSH from FAT and starts the
        # VM itself - no PROG stream is ever sent. The get_byte walk is
        # slow (~8k clks/byte, sector re-read class - ledgered), so give
        # the load a generous polling budget; break as soon as it runs.
        st = ""
        for _ in range(60):
            for _ in range(500):
                sim._rpc("TICK")
            st = sim._rpc("STATUS?")
            if "running=1" in st:
                break
        assert "running=1" in st, f"standalone RUN did not start ({st})"
        sim._rpc("FRAME")
        assert _fb_nz(sim) >= 100, "standalone RUN drew nothing"
    finally:
        sim.shutdown()
