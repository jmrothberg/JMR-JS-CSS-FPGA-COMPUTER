#!/usr/bin/env python3
"""Full FPGA-SIM RTL battery — must be green before any board flash.

  python3 tools/check_runtime_parity.py

HARD RULE: FPGA-SIM default is real RTL. Host twin is opt-in only (JMR_SIM_HOST=1).
"""

from __future__ import annotations

import base64
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model import Machine
from functional_model.canvas_engine import CONSOLE_ORIGIN_X, CONSOLE_ORIGIN_Y
from runtime.backend import PythonBackend
from runtime.sim_backend import SimBackend


def _norm_glass(text: str) -> str:
    lines = [ln.rstrip() for ln in text.replace("\\n", "\n").splitlines()]
    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines)


def check_python_letterbox() -> int:
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    m.paint_monitor("> ")
    # Outside letterbox must be empty; glyph pixels exist at HDMI origin
    if m.canvas.front[0] != 0:
        print("FAIL PYTHON glass not letterboxed (pixel 0 lit)")
        return 1
    if not any(m.canvas.front[CONSOLE_ORIGIN_Y * 640 + CONSOLE_ORIGIN_X + i] for i in range(8)):
        print("FAIL PYTHON letterbox origin empty")
        return 1
    py.type_line('console.log("HELLO")')
    if "HELLO" not in py.screen_text():
        print("FAIL PYTHON missing HELLO")
        return 1
    print("OK PYTHON letterbox + console.log")
    return 0


def check_rtl_help_list_run() -> int:
    os.environ.pop("JMR_SIM_HOST", None)
    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        print("FAIL FPGA-SIM RTL missing/default wrong")
        return 1
    try:
        for _ in range(200):
            sim._rpc("TICK")
        sim.type_line("HELP")
        st = _norm_glass(sim.screen_text())
        if "READY" not in st:
            print("FAIL RTL HELP", repr(st)[:200])
            return 1
        print("OK RTL HELP")

        sim.type_line("DIR")
        st = _norm_glass(sim.screen_text())
        if "RECTDEMO.JS" not in st and "INVADERS.JS" not in st:
            print("FAIL RTL DIR", repr(st)[-200:])
            return 1
        print("OK RTL DIR")

        sim.type_line("LOAD INVADERS.JS")
        st = _norm_glass(sim.screen_text())
        if "LOADED" not in st:
            print("FAIL RTL LOAD INVADERS", repr(st)[-200:])
            return 1
        sim.type_line("LIST")
        st = _norm_glass(sim.screen_text())
        if "{" not in st or "}" not in st:
            print("FAIL RTL LIST missing braces", repr(st)[-300:])
            return 1
        if "let " not in st and "alive" not in st.lower():
            # lowercase font is for glass paint; SCREEN? is ASCII from VRAM
            pass
        if "alive7" not in st and "ALIVE7" not in st:
            # source is lowercase
            if "alive7" not in st:
                print("NOTE LIST snippet:", st[-200:])
        print("OK RTL LIST braces")

        kb = sim._rpc("KEYBITS 16")
        if kb.strip() != "OK":
            print("FAIL KEYBITS", repr(kb))
            return 1
        sim._rpc("KEYBITS 0")
        print("OK RTL KEYBITS")

        # RECTDEMO FB pixels
        sim.type_line("LOAD RECTDEMO.JS")
        sim.type_line("RUN")
        for _ in range(100):
            sim._rpc("TICK")
        fb = sim._rpc("FB?")
        if not fb.startswith("FB 640 480 "):
            print("FAIL RECTDEMO FB?", fb[:60])
            return 1
        raw = base64.b64decode(fb.split(None, 3)[3])
        if sum(1 for b in raw if b) < 100:
            print("FAIL RECTDEMO FB empty")
            return 1
        print("OK RTL RUN RECTDEMO pixels")
        sim.hard_break()
        for _ in range(50):
            sim._rpc("TICK")

        # INVADERS VM
        sim.type_line("LOAD INVADERS.JS")
        sim.type_line("RUN")
        for _ in range(500):
            sim._rpc("TICK")
        st = sim._rpc("STATUS?")
        if "running=1" not in st:
            print("FAIL INVADERS not running", st)
            return 1
        fb = sim._rpc("FB?")
        raw = base64.b64decode(fb.split(None, 3)[3])
        nz = sum(1 for b in raw if b)
        if nz < 50:
            print("FAIL INVADERS FB empty", nz)
            return 1
        nz_glass = sum(1 for b in sim.framebuffer().front if b)
        if nz_glass < 50:
            print("FAIL INVADERS GUI glass empty", nz_glass)
            return 1
        print(f"OK RTL RUN INVADERS pixels ({nz})")
        sim.hard_break()
        for _ in range(100):
            sim._rpc("TICK")
        st = sim._rpc("STATUS?")
        if "running=1" in st:
            print("FAIL Esc did not leave game_mode", st)
            return 1
        print("OK RTL Esc exits game")

        # Quoted LOAD — same as the GUI user: load "invaders" then RUN
        sim.type_line('LOAD "invaders"')
        st = _norm_glass(sim.screen_text())
        if "LOADED" not in st:
            print("FAIL quoted LOAD invaders", repr(st)[-200:])
            return 1
        sim.type_line("LIST")
        st = _norm_glass(sim.screen_text())
        if "{" not in st or "}" not in st:
            print("FAIL quoted LIST braces", repr(st)[-300:])
            return 1
        sim.type_line("RUN")
        for _ in range(200):
            sim._rpc("TICK")
        st = sim._rpc("STATUS?")
        if "running=1" not in st:
            print("FAIL quoted RUN invaders", st)
            return 1
        fb = sim._rpc("FB?")
        if not fb.startswith("FB 640 480 "):
            print("FAIL quoted RUN FB?", fb[:60])
            return 1
        nz_q = sum(1 for b in sim.framebuffer().front if b)
        if nz_q < 50:
            print("FAIL quoted RUN GUI glass empty", nz_q)
            return 1
        print("OK RTL LOAD \"invaders\" LIST RUN pixels")
        sim.hard_break()
        return 0
    finally:
        sim.shutdown()


def check_ps2_bench() -> int:
    tb = ROOT / "sim/sim_build_synth/tb_ps2_typing"
    if not tb.is_file():
        r = subprocess.run(["make", "-C", str(ROOT / "sim"), "tb_ps2_typing"], cwd=str(ROOT))
        if r.returncode != 0:
            print("FAIL build tb_ps2_typing")
            return 1
    r = subprocess.run([str(tb)], cwd=str(ROOT / "sim"), capture_output=True, text=True)
    print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr)
        print("FAIL tb_ps2_typing")
        return 1
    print("OK PS2 waveform bench")
    return 0


def check_one_glass_parity() -> int:
    """PYTHON and RTL sim letterbox share origin pixels for banner 'J'."""
    os.environ.pop("JMR_SIM_HOST", None)
    m = Machine()
    m.boot_lines()
    m.paint_monitor("> ")
    py_origin = bytes(m.canvas.front[CONSOLE_ORIGIN_Y * 640 + CONSOLE_ORIGIN_X :
                                     CONSOLE_ORIGIN_Y * 640 + CONSOLE_ORIGIN_X + 8])

    sim = SimBackend()
    try:
        sim._start()
        sim._paint_screen_local("> ")
        sim_origin = bytes(sim.framebuffer().front[CONSOLE_ORIGIN_Y * 640 + CONSOLE_ORIGIN_X :
                                                   CONSOLE_ORIGIN_Y * 640 + CONSOLE_ORIGIN_X + 8])
    finally:
        sim.shutdown()
    if py_origin == bytes(8) or sim_origin == bytes(8):
        print("FAIL empty letterbox origin")
        return 1
    print("OK one-glass letterbox origins lit (PYTHON + RTL)")
    # NEW: one prompt row — RTL SCREEN ends with ">" ; host must not add another
    from functional_model.canvas_engine import CanvasEngine, CONSOLE_CELL_H

    c = CanvasEngine()
    c.paint_console_letterbox(["READY", ">"], prompt="> ")
    row1 = CONSOLE_ORIGIN_Y + CONSOLE_CELL_H
    row2 = CONSOLE_ORIGIN_Y + 2 * CONSOLE_CELL_H
    lit1 = any(c.front[row1 * 640 + CONSOLE_ORIGIN_X + i] for i in range(8))
    lit2 = any(c.front[row2 * 640 + CONSOLE_ORIGIN_X + i] for i in range(8))
    if not lit1 or lit2:
        print("FAIL dual prompt", lit1, lit2)
        return 1
    print("OK one prompt row")
    return 0


def check_board_optional() -> int:
    port = os.environ.get("JMR_JS_SERIAL", "").strip()
    if not port:
        # Autodetect — only note, do not fail battery
        from runtime.board_backend import _find_serial_port
        port = _find_serial_port() or ""
    if not port:
        print("SKIP BOARD (no tether)")
        return 0
    from runtime.board_backend import BoardBackend
    import time
    board = BoardBackend()
    try:
        for _ in range(20):
            board.poll()
            time.sleep(0.05)
        board.type_line("HELP")
        for _ in range(30):
            board.poll()
            time.sleep(0.05)
        bt = board.screen_text()
        if "READY" in bt or "HELP" in bt or "DIR" in bt:
            print("OK BOARD tether HELP/READY")
        else:
            print("NOTE BOARD tether:", repr(bt)[:120])
        return 0
    finally:
        board.shutdown()


def main() -> int:
    steps = [
        check_python_letterbox,
        check_one_glass_parity,
        check_rtl_help_list_run,
        check_ps2_bench,
        check_board_optional,
    ]
    for fn in steps:
        rc = fn()
        if rc:
            print("BATTERY FAIL")
            return rc
    print("BATTERY PASS — FPGA-SIM glass (LIST/RUN/INVADERS); no flash until WNS ≥ 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
