"""Gate: MacWrite documents and MacPaint pictures open from Finder.

Boot to Finder and double-click MacWrite. Type a line, File > Save As
"TEST", Esc: the saved document quits without asking. Finder shows
TEST.WRT; double-click it and MacWrite opens with the line back. Type one
more character and press Esc: MacWrite asks to save (the dialog is up and
MacWrite stays); Return saves and quits. Then double-click MacPaint, draw a
dot with Space, File > Save As "TEST", Esc. Finder shows TEST.PNT as a
placed, visible document; double-click it and MacPaint opens with the dot.

    make -C sim sim_server_synth && python3 sim/macwrite_check.py

Builds its own card from storage/ in build/macwrite_check; card.img is not
touched. Icon places and Finder's file table are read from the arena.
"""
import base64
import os
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "build" / "macwrite_check"
FINDER, APP = 9, 6
TEXT = "Hello MacWrite"
TX = 69632                       # MacWrite's characters (MACWRITE.HTML)
PAGE = 4096                      # MacPaint's page, 288 bytes a row

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


def vm():
    state = parse_status_kv(rpc("VMSTAT?"))
    assert not state.get("fault"), state
    return state


def role():
    return int(re.search(r"role=(\d+)", rpc("WINDOW?")).group(1))


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


def tap(code, text=0):
    rpc(f"KEYEVT {code} 1 {text}")
    settle(2)
    rpc(f"KEYEVT {code} 0 0")
    settle(2)


def type_text(s):
    for c in s:
        tap(ord(c.upper()), ord(c))


def wait_for(want, polls=400):
    for _ in range(polls):
        rpc("TICKN 1000")
        rpc("FRAME 2000000")
        if role() == want and vm().get("sname") not in ("S_IDLE", "S_DONE"):
            settle(4)
            return
    raise AssertionError(("timeout waiting for role", want, rpc("WINDOW?"), rpc("STATUS?")))


def arena(addr, n):
    """Arena bytes: 0-73727 are SRAM words from 3747840, the rest from 3887104."""
    out = b""
    while n > 0:
        if addr < 73728:
            base, take = 3747840 + addr, min(n, 73728 - addr)
        else:
            base, take = 3887104 + addr - 73728, n
        reply = rpc(f"SRAMDUMP {base} {take}")
        out += base64.b64decode(reply.split(" ", 3)[3])
        addr, n = addr + take, n - take
    return out


def dialog_up():
    """The Toolbox dialog frame: top edge of 136,112 black for 356 pixels."""
    pixels = base64.b64decode(rpc("FB?").split(" ", 3)[3])
    return all(pixels[112 * 640 + x] == 0 for x in range(136, 492))


def finder_slot(name):
    """Finder's 32-byte record for a file, from its table at arena 8192."""
    count = arena(16386, 1)[0]
    table = arena(8192, count * 32)
    for s in range(count):
        rec = table[s * 32:s * 32 + 32]
        if rec[0] == len(name) and rec[1:1 + len(name)] == name.encode():
            return rec
    return None


def disk_window():
    wins = arena(16896, 128)
    for w in range(8):
        rec = wins[w * 16:w * 16 + 16]
        if rec[0] and rec[1] == 0 and rec[2] == 0:
            return w, rec
    raise AssertionError("no disk window")


def open_icon(name):
    """Scroll the disk window until the icon shows, then double-click it."""
    for _ in range(30):
        rec = finder_slot(name)
        assert rec is not None, f"{name} is not in Finder's table"
        assert rec[14] == 0 and not rec[15] & (2 | 16 | 32), (name, "not shown in the disk window", rec[13:16])
        w, win = disk_window()
        x, y, ww, wh = struct.unpack("<HHHH", win[5:13])
        assert win[3] == 0, "disk window is not by Icon"
        ix = x - win[14] * 16 + 2 + struct.unpack("<H", rec[22:24])[0]
        iy = y + 48 + struct.unpack("<H", rec[24:26])[0] - win[4] * 16
        if y + 52 <= iy and iy + 40 <= y + wh - 16 and x <= ix and ix + 32 <= x + ww - 16:
            click(ix + 16, iy + 16)
            click(ix + 16, iy + 16)
            return
        # Page the scroll bar: just above the down arrow, or below the up arrow.
        if iy + 40 > y + wh - 16:
            click(x + ww - 8, y + wh - 36)
        elif iy < y + 52:
            click(x + ww - 8, y + 70)
        else:
            raise AssertionError((name, "icon is off to the side", ix, iy))
    raise AssertionError((name, "could not scroll to the icon"))


def menu_item(menu_x, index):
    click(menu_x, 10)
    click(menu_x + 20, 34 + 21 * index)


def save_as(name):
    menu_item(50, 4)                 # File > Save As... (fifth item)
    settle(16)                       # the chosen item blinks 12 frames first, as on the Mac
    assert dialog_up(), "Save As dialog did not open"
    type_text(name)
    tap(13)
    settle(6)


try:
    rpc("TICKN 100")
    rpc("KEY 20")
    wait_for(FINDER)
    settle(4)
    print("boot to Finder ok", flush=True)

    open_icon("MACWRITE.HTM")
    wait_for(APP)
    settle(10)
    type_text(TEXT)
    settle(4)
    text = arena(TX, len(TEXT) + 1)
    assert text == b"\x01" + TEXT.encode(), ("typed text not in the document", text)
    print("MacWrite opened and took typing", flush=True)
    save_as("TEST")
    tap(27)                         # saved: Esc quits without asking
    wait_for(FINDER)
    settle(6)
    rec = finder_slot("TEST.WRT")
    assert rec is not None and rec[13] == 2, ("TEST.WRT missing or not a document", rec)
    size = struct.unpack("<I", rec[16:20])[0]
    assert size == 32 + 32 + 3 * (len(TEXT) + 1), ("TEST.WRT size", size)
    print("Save As wrote TEST.WRT; Finder lists it", flush=True)

    open_icon("TEST.WRT")
    wait_for(APP)
    settle(10)
    text = arena(TX, len(TEXT) + 1)
    assert text == b"\x01" + TEXT.encode(), ("TEST.WRT did not load", text)
    print("double-clicking TEST.WRT opened MacWrite with the text", flush=True)
    type_text("!")
    tap(27)
    settle(6)
    assert role() == APP and dialog_up(), "Esc on a changed document did not ask to save"
    print("Esc on a changed document asks to save", flush=True)
    tap(13)                         # Save
    wait_for(FINDER)
    settle(6)
    rec = finder_slot("TEST.WRT")
    size = struct.unpack("<I", rec[16:20])[0]
    assert size == 32 + 32 + 3 * (len(TEXT) + 2), ("Save from the Esc dialog", size)
    print("Save from the dialog wrote the change and quit", flush=True)

    open_icon("MACPAINT.HTM")
    wait_for(APP)
    settle(10)
    tap(32)                         # Space: the pencil draws at the pen, 16,16
    settle(4)
    dot = arena(PAGE + 16 * 288 + 8, 1)[0] >> 4
    assert dot == 1, ("MacPaint did not draw", dot)
    save_as("TEST")
    tap(27)
    wait_for(FINDER)
    settle(6)
    rec = finder_slot("TEST.PNT")
    assert rec is not None, "TEST.PNT not in Finder's table"
    assert rec[13] == 2 and rec[15] & 64 and not rec[15] & (2 | 16 | 32), ("TEST.PNT hidden or unplaced", rec[13:16])
    print("MacPaint Save As wrote TEST.PNT; Finder shows it", flush=True)
    open_icon("TEST.PNT")
    wait_for(APP)
    settle(12)
    dot = arena(PAGE + 16 * 288 + 8, 1)[0] >> 4
    assert dot == 1, ("TEST.PNT did not load", dot)
    assert arena(30090, 4)[0] == 0, "hand-off left armed"
    print("double-clicking TEST.PNT opened MacPaint with the picture", flush=True)
    tap(27)
    wait_for(FINDER)
    print("MACWRITE_CHECK_PASS")
finally:
    sim.shutdown()
