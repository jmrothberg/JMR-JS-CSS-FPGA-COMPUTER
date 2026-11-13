"""Clocks per instruction by opcode on FPGA-SIM, for a few real programs.

Boots the card to Finder and profiles: Finder idle, Space Invaders (INVF),
Donkey Kong (CBDNKF) and MacPaint drawing with the mouse. Each run is a few
dozen frames. Counts are VM clocks (core clocks / 3), idle frame waits
excluded (OPPROFCLR / OPPROF? in sim/sim_main.cpp).

    make -C sim sim_server_synth && python3 sim/cpi_profile.py [out.json]

JMR_SIM_BUILD=<dir under sim/> picks another simulator build (A/B).
Builds its own card from storage/ in build/cpi_profile; card.img is not touched.
"""
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "build" / ("cpi_profile_" + os.environ.get("JMR_SIM_BUILD", "sim_build_synth"))
FINDER, APP = 9, 6
FRAMES = int(os.environ.get("CPI_FRAMES", "40"))
OPS = {1: "LOAD_CONST", 2: "LOAD_VAR", 3: "STORE_VAR", 4: "ADD", 5: "SUB", 6: "MUL",
       7: "DIV", 8: "LT", 9: "GT", 10: "EQ", 11: "JUMP", 12: "JIF", 13: "CALL",
       14: "RETURN", 15: "POP", 16: "DUP", 17: "NEG", 18: "NOT", 19: "MAKE_ARR",
       20: "ARR_GET", 21: "ARR_SET", 22: "LET_VAR", 23: "MOD", 24: "CALL_USER",
       25: "RET_VAL", 26: "MAKE_OBJ", 27: "GET_PROP", 28: "SET_PROP", 29: "NEW_OBJ",
       30: "CALL_METH", 31: "BIT_OR", 32: "BIT_AND", 33: "MAKE_FN", 34: "CALL_VAL"}

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


def wait_for(want, polls=400):
    for _ in range(polls):
        rpc("TICKN 1000")
        rpc("FRAME 2000000")
        if role() == want and vm().get("sname") not in ("S_IDLE", "S_DONE"):
            settle(4)
            return
    raise AssertionError(("timeout waiting for role", want, rpc("WINDOW?"), rpc("STATUS?")))


def arena(addr, n):
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


def finder_slot(name):
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
    for _ in range(30):
        rec = finder_slot(name)
        assert rec is not None, f"{name} is not in Finder's table"
        w, win = disk_window()
        x, y, ww, wh = struct.unpack("<HHHH", win[5:13])
        ix = x - win[14] * 16 + 2 + struct.unpack("<H", rec[22:24])[0]
        iy = y + 48 + struct.unpack("<H", rec[24:26])[0] - win[4] * 16
        if y + 52 <= iy and iy + 40 <= y + wh - 16 and x <= ix and ix + 32 <= x + ww - 16:
            click(ix + 16, iy + 16)
            click(ix + 16, iy + 16)
            return
        if iy + 40 > y + wh - 16:
            click(x + ww - 8, y + wh - 36)
        elif iy < y + 52:
            click(x + ww - 8, y + 70)
        else:
            raise AssertionError((name, "icon is off to the side", ix, iy))
    raise AssertionError((name, "could not scroll to the icon"))


def profile(label, step):
    rpc("OPPROFCLR")
    rpc("STATEHIST?")
    for i in range(FRAMES):
        step(i)
    reply = rpc("OPPROF?")
    hist = rpc("STATEHIST?").split(" | ")
    names = {}
    try:
        from runtime.vm_state_names import VM_STATE_NAMES as _N  # noqa: E402
        names = dict(enumerate(_N))
    except Exception:
        pass
    sh = sorted(((int(c), int(s)) for s, c in (t.split(":") for t in hist[0].split()[1:])), reverse=True)
    print("  parent states (VM clocks): " + " ".join(
        f"{names.get(s, s)}={c // 3}" for c, s in sh[:10]), flush=True)
    eh = sorted(((int(c), int(s)) for s, c in (t.split(":") for t in hist[1].split()[1:])), reverse=True)
    print("  exec sub-states: " + " ".join(f"{names.get(s, s)}={c // 3}" for c, s in eh[:6]), flush=True)
    head, _, sub = reply.partition(" |")
    kv = dict(p.split("=") for p in head.split()[1:4])
    ops = {}
    for tok in head.split()[4:]:
        op, n, clk = (int(v) for v in tok.split(":"))
        ops[OPS.get(op, str(op))] = (n, clk)
    subs = {}
    for tok in sub.split():
        key, n, clk = tok.split(":")
        subs[key] = (int(n), int(clk))
    insn, busy = int(kv["insn"]), int(kv["busy"])
    print(f"\n== {label}: {insn} instructions, {busy} busy VM clocks, "
          f"CPI {busy / max(insn, 1):.2f}, idle {kv['idle']}", flush=True)
    for name, (n, clk) in sorted(ops.items(), key=lambda t: -t[1][1])[:16]:
        print(f"  {name:10s} n={n:8d} {100 * n / max(insn, 1):5.1f}%  clk={clk:9d} "
              f"{100 * clk / max(busy, 1):5.1f}%  cpi={clk / max(n, 1):6.2f}")
    for key, (n, clk) in sorted(subs.items(), key=lambda t: -t[1][1])[:14]:
        op, arg = key.split(".")
        print(f"    {OPS.get(int(op), op)}#{arg} n={n} clk={clk} cpi={clk / max(n, 1):.1f}")
    return {"insn": insn, "busy": busy, "idle": int(kv["idle"]), "ops": ops, "subs": subs}


results = {}
try:
    rpc("TICKN 100")
    rpc("KEY 20")
    wait_for(FINDER)
    settle(4)
    results["finder_idle"] = profile("Finder idle", lambda i: settle(1))
    # Finder with the mouse moving over the desktop (pointer tracking).
    results["finder_mouse"] = profile(
        "Finder mouse move", lambda i: (rpc(f"MOUSE {100 + 8 * i} {200 + 3 * i} 0"), settle(1)))

    for game in ("INVF.HTM", "CBDNKF.HTM"):
        open_icon(game)
        running = 0
        for _ in range(1500):
            rpc("TICKN 1000")
            rpc("FRAME 2000000")
            if role() != FINDER and vm().get("sname") not in ("S_IDLE", "S_DONE"):
                running += 1
                if running >= 5:
                    break
            else:
                running = 0
        else:
            raise AssertionError((game, "did not start", rpc("WINDOW?")))
        settle(30)
        tap(13, 13)
        tap(32, 32)
        settle(10)

        def play(i):
            code = (37, 39, 32)[(i // 8) % 3]
            rpc(f"KEYEVT {code} 1 0")
            settle(1)
            rpc(f"KEYEVT {code} 0 0")
        results[game] = profile(game, play)
        rpc("KEY 1b")
        wait_for(FINDER)
        settle(4)

    open_icon("MACPAINT.HTM")
    wait_for(APP)
    settle(10)
    rpc("MOUSE 200 150 0")
    settle(2)

    def draw(i):
        x = 200 + 4 * (i % 30)
        y = 150 + 2 * (i % 30) + (i // 30) * 10
        rpc(f"MOUSE {x} {y} 1")
        settle(1)
    results["macpaint_draw"] = profile("MacPaint drawing", draw)
    rpc("MOUSE 320 240 0")
    settle(2)
    print("CPI_PROFILE_DONE")
finally:
    sim.shutdown()
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(json.dumps(results, indent=1))
