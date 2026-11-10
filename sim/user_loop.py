"""Gate: the loop a person does on the board, run on the RTL simulator.

Boot to Finder, open Editor, quit back to Finder, twice; then run a game for
60 frames and quit. Fails on a VM fault, a hang, a frozen picture, or the
Terminal window (role 7) appearing between programs.

    make -C sim sim_server_synth && python3 sim/user_loop.py     (about 20 minutes)

Builds its own card image from storage/ in build/user_loop; card.img is not touched.
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "build" / "user_loop"
FINDER, EDITOR, TERMINAL, GAME = 9, 1, 7, 8

shutil.rmtree(WORK, ignore_errors=True)
WORK.mkdir(parents=True)
subprocess.run([sys.executable, str(ROOT / "tools/make_sd_image.py"), "create", str(WORK / "card.img")],
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
    state = parse_status_kv(rpc("VMSTAT?"))
    assert not state.get("fault"), state
    return state


def settle(frames=2):
    """Advance until the VM is waiting for the next frame, `frames` times."""
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


def wait_for(role):
    for _ in range(400):
        rpc("TICKN 1000")
        rpc("FRAME 2000000")
        window = rpc("WINDOW?")
        shown = int(re.search(r"role=(\d+)", window).group(1))
        roles.append(shown)
        if shown == role and vm()["sname"] not in ("S_IDLE", "S_DONE"):
            settle(4)
            return
    raise AssertionError(("timeout waiting for window role", role, window, rpc("STATUS?")))


try:
    rpc("TICKN 100")
    rpc("KEY 20")
    wait_for(FINDER)
    print("boot to Finder ok", flush=True)
    roles.clear()
    for n in (1, 2):
        click(205, 10)      # Special menu
        click(230, 159)     # Editor (seventh item)
        wait_for(EDITOR)
        rpc("KEY 1b")       # Esc quits
        wait_for(FINDER)
        print(f"Editor and back, pass {n} ok", flush=True)
    click(470, 105)         # BOXES icon, double-click
    click(470, 105)
    wait_for(GAME)
    pictures = set()
    for _ in range(60):
        settle(1)
        pictures.add(hash(rpc("FB?")))
    assert len(pictures) > 1, "game picture never changed"
    rpc("KEY 1b")
    wait_for(FINDER)
    print("game and back ok", flush=True)
    assert TERMINAL not in roles, "Terminal window shown between programs"
    print("USER_LOOP_PASS")
finally:
    sim.shutdown()
