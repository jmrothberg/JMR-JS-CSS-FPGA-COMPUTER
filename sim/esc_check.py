"""Gate: Esc cancels a dialog without quitting, and three Escs still stop a program.

Boot to Finder, open Editor from Special, choose File > Save As...: Esc (a
key event) closes the dialog and the Editor stays. Esc again quits to Finder.
Then open STUCK.HTM, which claims Esc and then never returns from a frame,
so its listeners never run: the first two Escs leave it running, the third
stops it and Finder comes back.

    make -C sim sim_server_synth && python3 sim/esc_check.py

Builds its own card from storage/ plus STUCK.HTM in build/esc_check;
card.img is not touched.
"""
import base64
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "build" / "esc_check"
FINDER, EDITOR, UTILITY = 9, 1, 4

STUCK = """<!doctype html>
<!-- jmr-toolbox: resident-v2 -->
<html><body><canvas id="c" width="640" height="480"></canvas><script>
// A Utility-role program (it claims Esc) that hangs in a frame after a
// few good ones. Only the machine's third unanswered Esc can stop it.
var ctx=document.getElementById("c").getContext("2d");
tbSessionProperty(ctx,0,4);
var n=0;
function frame(){n=n+1;if(n>30){while(n>0){n=n+1;}}tbSessionFrame(frame);}
tbSessionFrame(frame);
</script></body></html>
"""

shutil.rmtree(WORK, ignore_errors=True)
WORK.mkdir(parents=True)
(WORK / "STUCK.HTM").write_text(STUCK)
subprocess.run([sys.executable, str(ROOT / "tools/make_sd_image.py"), "create", str(WORK / "card.img"),
                "--files", str(WORK / "STUCK.HTM")], check=True, stdout=subprocess.DEVNULL)
os.environ["JMR_CARD_IMG"] = str(WORK / "card.img")
os.environ.pop("JMR_SIM_HOST", None)
sys.path.insert(0, str(ROOT))
from runtime.backend import parse_status_kv  # noqa: E402
from runtime.sim_backend import SimBackend  # noqa: E402

sim = SimBackend()
rpc = sim._rpc


def vm():
    return parse_status_kv(rpc("VMSTAT?"))


def role():
    return int(re.search(r"role=(\d+)", rpc("WINDOW?")).group(1))


def settle(frames=2):
    """Advance until the VM waits for its next frame, `frames` times."""
    for _ in range(frames):
        for _ in range(40):
            rpc("FRAME 20000000")
            state = vm()
            assert not state.get("fault"), state
            if state.get("sname") in ("S_DONE", "S_IDLE") or (
                    state.get("sname") == "S_WAIT_FRAME" and not state.get("fcap")):
                break
        else:
            raise AssertionError(("frame timeout", state))


def click(x, y):
    for button in (1, 0):
        rpc(f"MOUSE {x} {y} {button}")
        settle()


def tap(code):
    rpc(f"KEYEVT {code} 1 {code}")
    settle(2)
    rpc(f"KEYEVT {code} 0 0")
    settle(2)


def wait_for(want, polls=400):
    for _ in range(polls):
        rpc("TICKN 1000")
        rpc("FRAME 2000000")
        if role() == want and vm().get("sname") not in ("S_IDLE", "S_DONE"):
            return
    raise AssertionError(("timeout waiting for role", want, rpc("WINDOW?"), rpc("STATUS?")))


def dialog_up():
    """The Toolbox dialog frame: top edge of 136,112 black for 356 pixels."""
    reply = rpc("FB?")
    pixels = base64.b64decode(reply.split(" ", 3)[3])
    return all(pixels[112 * 640 + x] == 0 for x in range(136, 492))


try:
    rpc("TICKN 100")
    rpc("KEY 20")
    wait_for(FINDER)
    settle(4)
    print("boot to Finder ok", flush=True)

    click(205, 10)              # Special menu
    click(230, 137)             # Editor (sixth item)
    wait_for(EDITOR)
    settle(4)
    click(60, 10)               # File menu
    click(80, 97)               # Save As... (fourth item)
    settle(16)                       # the chosen item blinks 12 frames first, as on the Mac
    assert dialog_up(), "Save As dialog did not open"
    tap(27)
    settle(4)
    assert role() == EDITOR, "Esc in Save As quit the Editor"
    assert not dialog_up(), "Esc did not close Save As"
    print("Esc cancelled Save As, Editor stayed", flush=True)
    rpc("KEY 1b")
    wait_for(FINDER)
    settle(4)
    print("Esc quit the Editor", flush=True)

    settle(45)                  # Finder forgets a typed prefix after 40 frames
    for c in "STUC":
        tap(ord(c))
    click(50, 10)               # File menu
    click(80, 55)               # Open
    wait_for(UTILITY)
    for _ in range(40):         # past its 30 good frames, into the hang
        rpc("TICKN 1000")
        rpc("FRAME 2000000")
    for n in (1, 2, 3):
        rpc("KEY 1b")
        for _ in range(20):
            rpc("TICKN 1000")
            rpc("FRAME 2000000")
        if n < 3:
            assert role() == UTILITY, ("Esc %d stopped the program early" % n, rpc("WINDOW?"))
    wait_for(FINDER)
    print("three Escs stopped a hung program", flush=True)
    print("ESC_CHECK_PASS")
finally:
    sim.shutdown()
