"""Gate: Editor titles, Save As sidecars, and replacing a compiled program.

Boot to Finder. Select BOMBFAST and choose Special > Editor: the window is
titled "BOMBFAST.HTM". File > Save As... NEWBOMB: the Editor comes back
titled "NEWBOMB.HTM", and the card has NEWBOMB.ICN and NEWBOMB.ART equal to
BOMBFAST's. Esc returns to Finder.

Then select BOXES (which has a BOXES.JSH) and choose Special > Compile. A
real compile takes minutes of board time, far too long for the simulator, so
on this card the first chain program is a stand-in that ends the way
COMPILER now ends: it writes an image (MENUEX.JSH's bytes) to BOXES.JS$,
renames it over the existing BOXES.JSH and reports cdone(0,0,0). Finder must
come back with no alert, BOXES.JSH must be the new image with no BOXES.JS$
left, and opening BOXES must run it (MENUEX's window, role 6).

    make -C sim sim_server_synth && python3 sim/document_check.py

Builds its own card from storage/ in build/document_check; card.img is not touched.
"""
import base64
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "build" / "document_check"
FINDER, EDITOR, TOOL = 9, 1, 6
BLACK, WHITE = 0, 255
BOX = (136, 112, 368, 200)

STANDIN = """<!doctype html>
<html><body><canvas id="c" width="640" height="480"></canvas><script>
// Stand-in for the end of COMPILER: image to NAME.JS$, rename over NAME.JSH.
function nm(at,s){var i=0;while(strByte(s,i)>=0){stgWrite(at+i,strByte(s,i));i=i+1;}stgWrite(at+i,0);}
nm(1000,"MENUEX.JSH");nm(1016,"BOXES.JS$");nm(1032,"BOXES.JSH");
var n=fsRead(1000,0,4096,200000);
if(n>0&&fsWrite(1016,4096,n,0)==n&&fsRename(1016,1032)==0)cdone(0,0,0);else cdone(15,0,0);
</script></body></html>
"""

shutil.rmtree(WORK, ignore_errors=True)
WORK.mkdir(parents=True)
CARD = WORK / "card.img"
subprocess.run([sys.executable, str(ROOT / "tools/make_sd_image.py"), "create", str(CARD)],
               check=True, stdout=subprocess.DEVNULL)
sys.path.insert(0, str(ROOT))
from hardware_model.fat32 import Fat32Volume  # noqa: E402
from hardware_model.sd_spi import SdSpiCard  # noqa: E402
from functional_model.memory import Memory  # noqa: E402
from tools.compile_js import compile_html_text, encode_html_chunk  # noqa: E402
from tools.make_sd_image import patch_card_file  # noqa: E402

patch_card_file(CARD, "ARTSCAN.JSH", encode_html_chunk(compile_html_text(STANDIN)))


def card_file(name):
    mem = Memory()
    sd = SdSpiCard(mem, bytearray(CARD.read_bytes()))
    sd.init()
    vol = Fat32Volume(mem, sd)
    vol.mount()
    try:
        return vol.read_file(name)
    except FileNotFoundError:
        return None


ICON, ART, MENUEX = card_file("BOMBFAST.ICN"), card_file("BOMBFAST.ART"), card_file("MENUEX.JSH")
assert ICON and ART and MENUEX and card_file("BOXES.JSH") not in (None, MENUEX)

os.environ["JMR_CARD_IMG"] = str(CARD)
os.environ.pop("JMR_SIM_HOST", None)
from runtime.backend import parse_status_kv  # noqa: E402
from runtime.sim_backend import SimBackend  # noqa: E402

sim = SimBackend()
rpc = sim._rpc
ADVANCES = re.search(r'strByte\("([A-Z]+)",i\)-64', (ROOT / "resources/toolbox/ui.js").read_text()).group(1)


def vm():
    state = parse_status_kv(rpc("VMSTAT?"))
    assert not state.get("fault"), state
    return state


def role():
    return int(re.search(r"role=(\d+)", rpc("WINDOW?")).group(1))


def settle(frames=2):
    for _ in range(frames):
        for _ in range(40):
            rpc("FRAME 20000000")
            state = vm()
            if state.get("sname") in ("S_DONE", "S_IDLE") or (
                    state.get("sname") == "S_WAIT_FRAME" and not state.get("fcap")):
                break
        else:
            raise AssertionError(("frame timeout", state))


def click(x, y):
    for button in (1, 0):
        rpc(f"MOUSE {x} {y} {button}")
        settle()


def tap(code, char=None):
    rpc(f"KEYEVT {code} 1 {code if char is None else char}")
    settle(2)
    rpc(f"KEYEVT {code} 0 0")
    settle(2)


def picture():
    reply = rpc("FB?")
    return base64.b64decode(reply.split(" ", 3)[3]) if reply.startswith("FB 640 480 ") else None


def title_is(text):
    pixels = picture()
    if pixels is None:
        return False
    xs = [x for y in range(36, 56) for x in range(30, 600) if pixels[y * 640 + x] == 0]
    width = sum(ord(ADVANCES[ord(c) - 32]) - 64 for c in text)
    left = 8 + (612 - width) // 2
    return bool(xs) and abs(min(xs) - left) <= 2 and abs(max(xs) - (left + width)) <= 3


def dialog_up():
    """The Toolbox dialog frame: top edge of 136,112 black for 356 pixels."""
    pixels = picture()
    return pixels is not None and all(pixels[112 * 640 + x] == 0 for x in range(136, 492))


def alert_up(pixels):
    x, y, w, h = BOX
    row = lambda yy: pixels[yy * 640 + x:yy * 640 + x + w]
    return all(p == BLACK for p in row(y)) and all(p == BLACK for p in row(y + h - 1))


def wait_for(want, check=None, polls=600):
    for _ in range(polls):
        rpc("TICKN 1000")
        rpc("FRAME 2000000")
        if role() == want and vm().get("sname") not in ("S_IDLE", "S_DONE") and (check is None or check()):
            settle(4)
            return
    raise AssertionError(("timeout waiting for", want, rpc("WINDOW?"), rpc("STATUS?")))


def select(prefix):
    settle(45)                  # Finder forgets a typed prefix after 40 frames
    for c in prefix:
        tap(ord(c))


try:
    rpc("TICKN 100")
    rpc("KEY 20")
    wait_for(FINDER)
    print("boot to Finder ok", flush=True)

    select("BOMB")
    click(205, 10)              # Special menu
    click(230, 137)             # Editor
    wait_for(EDITOR, lambda: title_is("BOMBFAST.HTM"))
    print("Editor titled BOMBFAST.HTM", flush=True)

    click(60, 10)               # File menu
    click(80, 97)               # Save As...
    settle(4)
    assert dialog_up(), "Save As dialog did not open"
    for _ in range(13):
        tap(8)                  # clear the offered name
    for c in "NEWBOMB":
        tap(ord(c))
    tap(190, 46)                # "." (key 190; key 46 is Delete)
    for c in "HTM":             # without an ending the name would get .TXT
        tap(ord(c))
    tap(13)
    settle(4)
    wait_for(EDITOR, lambda: title_is("NEWBOMB.HTM"), polls=1500)
    print("Save As: Editor titled NEWBOMB.HTM", flush=True)
    rpc("KEY 1b")
    wait_for(FINDER)
    assert card_file("NEWBOMB.HTM"), "NEWBOMB.HTM not saved"
    assert card_file("NEWBOMB.ICN") == ICON, "icon not copied"
    assert card_file("NEWBOMB.ART") == ART, "art not copied"
    print("Save As copied BOMBFAST.ICN and BOMBFAST.ART to NEWBOMB", flush=True)

    select("BOXE")
    click(205, 10)              # Special menu
    click(230, 121)             # Compile
    wait_for(FINDER, lambda: card_file("BOXES.JSH") == MENUEX, polls=1500)
    settle(10)
    assert not alert_up(picture()), "Finder shows an alert after the compile"
    assert card_file("BOXES.JS$") is None, "temporary BOXES.JS$ left behind"
    print("compile replaced the existing BOXES.JSH, no alert", flush=True)

    select("BOXE")
    click(50, 10)               # File menu
    click(80, 55)               # Open
    wait_for(TOOL)
    print("the new BOXES.JSH runs", flush=True)
    rpc("KEY 1b")
    wait_for(FINDER)
    print("DOCUMENT_CHECK_PASS")
finally:
    if sim._proc.poll() is not None:
        print("simulator exited", sim._proc.returncode, sim._proc.stderr.read()[-2000:], flush=True)
    sim.shutdown()
