"""Gate: a program that crashes or cannot be opened brings back Finder with an alert.

Boot to Finder. Open CRASH.HTM, which stops with VM fault 4: Finder comes
back with the System Error box (bomb, "ID = 4"); Return dismisses it. Open
NOFILE.HTM, which asks for a program that is not on the card: Finder comes
back with the "could not be opened" alert; Esc dismisses it. The Terminal
window (role 7) must never appear.

    make -C sim sim_server_synth && python3 sim/alert_check.py

Builds its own card from storage/ plus the two test programs in
build/alert_check; card.img is not touched.
"""
import base64
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "build" / "alert_check"
FINDER, TERMINAL = 9, 7
BLACK, WHITE = 0, 255           # Finder's RGB332 palette
BOX = (136, 112, 368, 200)      # alert frame, the Toolbox dialog rectangle
ICON = (160, 136)               # 32x32 alert icon

CRASH = """<!doctype html>
<html><body><canvas id="c" width="640" height="480"></canvas><script>
// Stops with VM fault 4 on its first frame.
var ctx=document.getElementById("c").getContext("2d");
function frame(){runtimeFault(4);}
requestAnimationFrame(frame);
</script></body></html>
"""
NOFILE = """<!doctype html>
<html><body><canvas id="c" width="640" height="480"></canvas><script>
// Asks to run NOSUCH.HTM, which is not on the card.
var ctx=document.getElementById("c").getContext("2d");
function frame(){
 var name="NOSUCH.HTM",i=0;
 while(i<10){stgWrite(96+i,strByte(name,i));i=i+1;}
 stgWrite(106,0);
 sysRun(96,0);
}
requestAnimationFrame(frame);
</script></body></html>
"""

shutil.rmtree(WORK, ignore_errors=True)
WORK.mkdir(parents=True)
(WORK / "CRASH.HTM").write_text(CRASH)
(WORK / "NOFILE.HTM").write_text(NOFILE)
subprocess.run([sys.executable, str(ROOT / "tools/make_sd_image.py"), "create", str(WORK / "card.img"),
                "--files", str(WORK / "CRASH.HTM"), str(WORK / "NOFILE.HTM")],
               check=True, stdout=subprocess.DEVNULL)
os.environ["JMR_CARD_IMG"] = str(WORK / "card.img")
os.environ.pop("JMR_SIM_HOST", None)
sys.path.insert(0, str(ROOT))
from runtime.backend import parse_status_kv  # noqa: E402
from runtime.sim_backend import SimBackend  # noqa: E402

sim = SimBackend()
rpc = sim._rpc
roles = []


def vm():
    return parse_status_kv(rpc("VMSTAT?"))


def role():
    shown = int(re.search(r"role=(\d+)", rpc("WINDOW?")).group(1))
    roles.append(shown)
    return shown


def settle(frames=2):
    """Advance until the VM waits for its next frame, `frames` times."""
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


def tap(code):
    rpc(f"KEYEVT {code} 1 {code}")
    settle(2)
    rpc(f"KEYEVT {code} 0 0")
    settle(2)


def picture():
    reply = rpc("FB?")
    if not reply.startswith("FB 640 480 "):
        return None
    return base64.b64decode(reply.split(" ", 3)[3])


def alert(pixels):
    """(frame drawn, black pixels in the icon square)."""
    x, y, w, h = BOX
    row = lambda yy: pixels[yy * 640 + x:yy * 640 + x + w]
    framed = (all(p == BLACK for p in row(y)) and all(p == BLACK for p in row(y + h - 1))
              and sum(p == WHITE for p in row(y + 90)) > w * 3 // 4)
    icon = sum(pixels[(ICON[1] + j) * 640 + ICON[0] + i] == BLACK for j in range(32) for i in range(32))
    return framed, icon


def wait_finder(shown, polls=400):
    """Run until Finder is up and the alert is (shown=True) or is not drawn."""
    for _ in range(polls):
        rpc("TICKN 1000")
        rpc("FRAME 2000000")
        if role() == FINDER and vm().get("sname") not in ("S_IDLE", "S_DONE"):
            pixels = picture()
            if pixels is not None and alert(pixels)[0] == shown:
                settle(2)               # the frame can be read while Finder is still painting
                return picture() or pixels
    raise AssertionError(("timeout: Finder with alert" if shown else "timeout: alert still up",
                          rpc("WINDOW?"), rpc("STATUS?"), vm()))


def open_by_name(prefix):
    """Select the file by typing its name, then File > Open."""
    settle(45)                  # Finder forgets a typed prefix after 40 frames
    for c in prefix:
        tap(ord(c))
    click(50, 10)               # File menu
    click(80, 55)               # Open (second item)


try:
    rpc("TICKN 100")
    rpc("KEY 20")
    plain = wait_finder(False)
    settle(4)
    assert not alert(picture() or plain)[0], "alert on a clean boot"
    print("boot to Finder ok", flush=True)

    open_by_name("CRAS")
    shown = wait_finder(True)
    framed, icon = alert(shown)
    assert icon > 100, ("System Error box has no bomb", icon)
    tap(13)                     # Return
    wait_finder(False)
    print("VM fault: bomb shown, Return dismissed it", flush=True)

    open_by_name("NOFI")
    shown = wait_finder(True)
    framed, icon = alert(shown)
    assert icon > 40, ("load alert has no icon", icon)
    rpc("KEY 1b")               # Esc
    wait_finder(False)
    print("load failure: alert shown, Esc dismissed it", flush=True)

    assert TERMINAL not in roles, "Terminal window shown"
    print("ALERT_CHECK_PASS")
finally:
    sim.shutdown()
