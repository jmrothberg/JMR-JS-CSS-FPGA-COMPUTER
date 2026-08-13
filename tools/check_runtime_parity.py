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


def _has_numbered_line(text: str, num: str) -> bool:
    prefix = num + " "
    for ln in text.replace("\\n", "\n").splitlines():
        if ln.lstrip().startswith(prefix):
            return True
    return False


def check_python_monitor_verbs() -> int:
    """PYTHON first: LIST numbers / MORE / EDIT / CLS / keep-fb after RUN."""
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    # LOAD invaders from FM disk
    py.type_line('LOAD "invaders"')
    py.type_line("LIST 10-20")
    st = py.screen_text()
    if not _has_numbered_line(st, "10") or not _has_numbered_line(st, "20"):
        print("FAIL PYTHON LIST 10-20 numbers", repr(st)[-300:])
        return 1
    print("OK PYTHON LIST 10-20 numbers")

    # LIST - must park on -- MORE -- (scripts auto-continue unless idle feeds Space)
    seen_more = {"v": False}

    def _idle_more() -> None:
        if m.console_log and m.console_log[-1] == "-- MORE --":
            seen_more["v"] = True
            m.push_key(" ")

    m.more_idle = _idle_more
    py.type_line("LIST -")
    m.more_idle = None
    if not seen_more["v"]:
        print("FAIL PYTHON LIST - never showed MORE")
        return 1
    print("OK PYTHON LIST - MORE")

    py.type_line("EDIT 20")
    pref = m.edit_prefill()
    if pref is None:
        print("FAIL PYTHON EDIT prefill None")
        return 1
    py.type_line("// PY_EDIT_OK")
    py.type_line("LIST 20")
    if "PY_EDIT_OK" not in py.screen_text():
        print("FAIL PYTHON EDIT replace", repr(py.screen_text())[-200:])
        return 1
    print("OK PYTHON EDIT 20")

    py.type_line("CLS")
    st = py.screen_text()
    if "PY_EDIT_OK" in st:
        # CLS clears log; only boot/READY should remain after type_line READY
        print("FAIL PYTHON CLS left old LIST text", repr(st)[-200:])
        return 1
    print("OK PYTHON CLS")

    # keep-fb: RECTDEMO pixels survive READY after one-shot RUN
    py.type_line('LOAD "rectdemo"')
    py.type_line("RUN")
    nz = sum(1 for b in m.canvas.front if b)
    if nz < 50:
        print("FAIL PYTHON RUN RECTDEMO empty", nz)
        return 1
    if not getattr(m, "_keep_fb", False):
        print("FAIL PYTHON keep_fb not set after RUN")
        return 1
    print("OK PYTHON RUN keep-fb", nz)

    # NEW: INVADERS.JS bytecode loop (not INVADERS.HTML product titles)
    py.type_line("LOAD INVADERS.JS")
    py.type_line("RUN")
    if not m.running or m._loop_chunk is None:
        print("FAIL PYTHON INVADERS not looping", m.running, m._loop_chunk, py.screen_text()[-200:])
        return 1
    for _ in range(5):
        py.frame_tick()
    nz_inv = sum(1 for b in m.canvas.front if b)
    if nz_inv < 50:
        print("FAIL PYTHON INVADERS FB empty", nz_inv)
        return 1
    # Letterbox must not wipe while running
    if not py.running:
        print("FAIL PYTHON backend.running False during INVADERS")
        return 1
    from functional_model.input_engine import KEY_FIRE, KEY_LEFT

    px0 = m.vm.globals.get("px")
    m.set_key_bits(KEY_LEFT)
    py.frame_tick()
    px1 = m.vm.globals.get("px")
    if px0 is None or px1 is None or not (px1 < px0):
        print("FAIL PYTHON Left did not move px", px0, px1)
        return 1
    m.set_key_bits(0)
    py.frame_tick()
    m.set_key_bits(KEY_FIRE)
    py.frame_tick()
    if m.vm.globals.get("bullet") != 1:
        print("FAIL PYTHON Space did not fire", m.vm.globals.get("bullet"))
        return 1
    m.set_key_bits(0)
    print("OK PYTHON INVADERS pixels + Left + Space", nz_inv)

    # NEW: LIST HTML numbered + -- MORE -- (not (HTML) stub; bytecode is the RUN path)
    m.hard_break()
    py.type_line("LOAD INVADERS.HTML")
    seen_more = {"v": False}

    def _idle_html_more() -> None:
        if m.console_log and m.console_log[-1] == "-- MORE --":
            seen_more["v"] = True
            m.push_key(" ")

    m.more_idle = _idle_html_more
    py.type_line("LIST")
    m.more_idle = None
    st = py.screen_text()
    if "(HTML)" in st:
        print("FAIL PYTHON LIST HTML stub", repr(st)[-200:])
        return 1
    if not seen_more["v"] and not _has_numbered_line(st, "10"):
        print("FAIL PYTHON LIST HTML numbers/MORE", repr(st)[-200:])
        return 1
    print("OK PYTHON LIST HTML numbered + MORE")

    # NEW: keyUp/keyDown natives (DONKEY climb bits)
    from functional_model.input_engine import KEY_DOWN, KEY_UP
    from functional_model.jsb_format import NATIVE_IDS

    if NATIVE_IDS.get("keyUp") != 8 or NATIVE_IDS.get("keyDown") != 9:
        print("FAIL JSB native IDs keyUp/keyDown", NATIVE_IDS)
        return 1
    m.set_key_bits(KEY_UP)
    if m._nat_key_up() != 1 or m._nat_key_down() != 0:
        print("FAIL PYTHON keyUp native")
        return 1
    m.set_key_bits(KEY_DOWN)
    if m._nat_key_down() != 1 or m._nat_key_up() != 0:
        print("FAIL PYTHON keyDown native")
        return 1
    m.set_key_bits(0)
    print("OK PYTHON keyUp/keyDown natives")

    # NEW: letterbox cursor blink paints cyan cell
    m.console_log.clear()
    m.paint_monitor("> ", cursor_on=True)
    from functional_model.canvas_engine import CONSOLE_ORIGIN_X, CONSOLE_ORIGIN_Y

    # prompt "> " → cursor at col 2, row 0 when log empty
    cx = CONSOLE_ORIGIN_X + 2 * 8
    cy = CONSOLE_ORIGIN_Y
    if m.canvas.front[cy * 640 + cx] != 6:
        print("FAIL cursor cell not cyan", m.canvas.front[cy * 640 + cx])
        return 1
    print("OK PYTHON cursor blink cell")
    return 0


def check_python_html_bytecode_invaders() -> int:
    """PYTHON LOAD/RUN INVADERS.HTML via bytecode/.JSH (not dukpy).

    Pixels + Left + Space; FB must persist across extra frames (no vanish).
    """
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    py.type_line("LOAD INVADERS.HTML")
    py.type_line("RUN")
    if not m.running or not getattr(m, "_bytecode_html", False):
        print(
            "FAIL PYTHON HTML BYTECODE INVADERS not running",
            m.running,
            getattr(m, "_bytecode_html", None),
            m.vm.error,
            py.screen_text()[-200:],
        )
        return 1
    if m.html_host is not None:
        print("FAIL PYTHON HTML BYTECODE used dukpy")
        return 1
    for _ in range(30):
        py.frame_tick()
        if m.vm.error:
            print("FAIL PYTHON HTML BYTECODE VM", m.vm.error)
            return 1
    nz = sum(1 for b in m.canvas.front if b)
    if nz < 100:
        print("FAIL PYTHON HTML BYTECODE INVADERS FB empty", nz)
        return 1
    for _ in range(30):
        py.frame_tick()
    nz2 = sum(1 for b in m.canvas.front if b)
    if nz2 < 100:
        print("FAIL PYTHON HTML BYTECODE INVADERS vanished", nz, nz2)
        return 1
    player = m.vm.globals.get("player")
    pos = player.get("position") if isinstance(player, dict) else None
    px0 = pos.get("x") if isinstance(pos, dict) else None
    from functional_model.input_engine import KEY_FIRE, KEY_LEFT

    m.set_key_bits(KEY_LEFT)
    py.frame_tick()
    player = m.vm.globals.get("player")
    pos = player.get("position") if isinstance(player, dict) else None
    px1 = pos.get("x") if isinstance(pos, dict) else None
    if px0 is None or px1 is None or not (px1 < px0):
        print("FAIL PYTHON HTML BYTECODE Left did not move player.x", px0, px1)
        return 1
    m.set_key_bits(0)
    py.frame_tick()
    n0 = m.vm.globals.get("projectiles")
    n0 = len(n0) if isinstance(n0, list) else -1
    m.set_key_bits(KEY_FIRE)
    py.frame_tick()
    n1 = m.vm.globals.get("projectiles")
    n1 = len(n1) if isinstance(n1, list) else -1
    if n1 <= n0:
        print("FAIL PYTHON HTML BYTECODE Space did not fire", n0, n1)
        return 1
    m.set_key_bits(0)
    print("OK PYTHON HTML BYTECODE INVADERS pixels + Left + Space", nz2, "compile-on-RUN")
    return 0


def check_python_html_bytecode_title(stem: str) -> int:
    """LOAD/RUN STEM.HTML on bytecode/.JSH — pixels + Left FB change.

    INVADERS keeps the stricter player.x / Space-fire check above.
    """
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    py.type_line(f"LOAD {stem}.HTML")
    py.type_line("RUN")
    if not m.running or not getattr(m, "_bytecode_html", False):
        print(
            f"FAIL PYTHON HTML BYTECODE {stem} not running",
            m.running,
            getattr(m, "_bytecode_html", None),
            m.vm.error,
            py.screen_text()[-200:],
        )
        return 1
    if m.html_host is not None:
        print(f"FAIL PYTHON HTML BYTECODE {stem} used dukpy")
        return 1
    for _ in range(40):
        py.frame_tick()
        if m.vm.error:
            print(f"FAIL PYTHON HTML BYTECODE {stem} VM", m.vm.error)
            return 1
    nz = sum(1 for b in m.canvas.front if b)
    if nz < 50:
        print(f"FAIL PYTHON HTML BYTECODE {stem} FB empty", nz)
        return 1
    fb0 = bytes(m.canvas.front)
    from functional_model.input_engine import KEY_LEFT

    m.set_key_bits(KEY_LEFT)
    # setTimeout-paced titles (DONKEY ~30 Hz) repaint every other rAF tick —
    # allow a few frames before calling the FB static.
    changed = False
    for _ in range(4):
        py.frame_tick()
        if bytes(m.canvas.front) != fb0:
            changed = True
            break
    if not changed:
        print(f"FAIL PYTHON HTML BYTECODE {stem} Left no FB change")
        return 1
    m.set_key_bits(0)
    print(f"OK PYTHON HTML BYTECODE {stem} pixels + Left", nz)
    return 0


def check_python_html_bytecode_donkey() -> int:
    return check_python_html_bytecode_title("DONKEY")


def check_python_html_bytecode_pacman() -> int:
    return check_python_html_bytecode_title("PACMAN")


def check_hm_invaders_jsh() -> int:
    """HM loads compile-on-RUN bytecode from INVADERS.HTML (not a stale .JSH)."""
    from hardware_model.js_vm import JsHwVm
    from functional_model.compiler import CompileError
    from functional_model.input_engine import KEY_FIRE, KEY_LEFT
    from tools.compile_js import compile_html_text, encode_html_chunk

    html_path = ROOT / "storage" / "INVADERS.HTML"
    try:
        chunk = compile_html_text(html_path.read_text(encoding="utf-8"))
        blob = encode_html_chunk(chunk)
    except CompileError as e:
        print("FAIL HM compile INVADERS.HTML", e.line, e.message)
        return 1
    except Exception as e:
        print("FAIL HM compile INVADERS.HTML", e)
        return 1
    vm = JsHwVm()
    try:
        vm.load_blob(blob)
    except Exception as e:
        print("FAIL HM load bytecode", e)
        return 1
    if vm.error or not vm.running:
        print("FAIL HM INVADERS HTML run", vm.error)
        return 1
    for _ in range(30):
        vm.frame_tick()
        if vm.error:
            print("FAIL HM frame", vm.error)
            return 1
    nz = sum(1 for b in vm.canvas.front if b)
    if nz < 100:
        print("FAIL HM INVADERS FB empty", nz)
        return 1
    player = vm.globals.get("player")
    pos = player.get("position") if isinstance(player, dict) else None
    px0 = pos.get("x") if isinstance(pos, dict) else None
    vm.set_key_bits(KEY_LEFT)
    vm.frame_tick()
    player = vm.globals.get("player")
    pos = player.get("position") if isinstance(player, dict) else None
    px1 = pos.get("x") if isinstance(pos, dict) else None
    if px0 is None or px1 is None or not (px1 < px0):
        print("FAIL HM Left did not move player.x", px0, px1)
        return 1
    vm.set_key_bits(0)
    vm.frame_tick()
    n0 = vm.globals.get("projectiles")
    n0 = len(n0) if isinstance(n0, list) else -1
    vm.set_key_bits(KEY_FIRE)
    vm.frame_tick()
    n1 = vm.globals.get("projectiles")
    n1 = len(n1) if isinstance(n1, list) else -1
    if n1 <= n0:
        print("FAIL HM Space did not fire", n0, n1)
        return 1
    print("OK HM INVADERS HTML compile-on-RUN pixels + Left + Space", nz)
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
        # NEW: numbered + MORE paging — braces may be on a later page
        if not (
            _has_numbered_line(st, "10")
            or _has_numbered_line(st, "20")
            or "-- MORE --" in st
        ):
            print("FAIL RTL LIST missing numbers/MORE", repr(st)[-300:])
            return 1
        found_brace = "{" in st and "}" in st
        if not found_brace:
            for _ in range(40):
                if not sim.more_waiting:
                    break
                sim.push_key(" ")
                st = _norm_glass(sim.screen_text())
                if "{" in st and "}" in st:
                    found_brace = True
                    break
        if not found_brace:
            print("FAIL RTL LIST missing braces", repr(st)[-300:])
            return 1
        print("OK RTL LIST numbers + braces")

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

        # NEW: KEYBITS must stick (GUI no longer JOY-wipes) and match Left/Fire bits
        kb = sim._rpc("KEYBITS 4")  # JOY_LEFT
        if kb.strip() != "OK":
            print("FAIL KEYBITS left", repr(kb))
            return 1
        st = sim._rpc("STATUS?")
        if "joy=4" not in st:
            print("FAIL RTL Left joy not held", st)
            return 1
        # Move left several frames; FB must change (gun was at px≈300)
        fb0 = bytes(sim.framebuffer().front)
        for _ in range(30):
            sim._rpc("TICK")
        sim._rpc("FB?")
        fb1 = bytes(sim.framebuffer().front)
        if fb0 == fb1:
            print("FAIL RTL Left KEYBITS did not move gun")
            return 1
        print("OK RTL KEYBITS Left moves gun")

        sim._rpc("KEYBITS 16")  # JOY_FIRE1
        st = sim._rpc("STATUS?")
        if "joy=16" not in st:
            print("FAIL RTL Fire joy not held", st)
            return 1
        for _ in range(20):
            sim._rpc("TICK")
        sim._rpc("FB?")
        # Bullet or muzzle change — not identical to pre-fire frame
        fb2 = bytes(sim.framebuffer().front)
        if fb2 == fb1:
            print("FAIL RTL Fire KEYBITS no FB change")
            return 1
        sim._rpc("KEYBITS 0")
        print("OK RTL KEYBITS Fire")

        # NEW: Up bit reaches RTL (keyUp native id 8; full CLIMB needs card→JSB load)
        sim._rpc("KEYBITS 1")  # JOY_UP
        st = sim._rpc("STATUS?")
        if "joy=1" not in st:
            print("FAIL RTL Up joy not held", st)
            return 1
        sim._rpc("KEYBITS 0")
        print("OK RTL KEYBITS Up (keyUp path)")

        sim.hard_break()
        for _ in range(100):
            sim._rpc("TICK")
        st = sim._rpc("STATUS?")
        if "running=1" in st:
            print("FAIL Esc did not leave game_mode", st)
            return 1
        print("OK RTL Esc exits game")

        # Remove duplicate early KEYBITS smoke if still above — keep RECTDEMO path's KEYBITS check
        # Quoted LOAD — same as the GUI user: load "invaders" then RUN
        sim.type_line('LOAD "invaders"')
        st = _norm_glass(sim.screen_text())
        if "LOADED" not in st:
            print("FAIL quoted LOAD invaders", repr(st)[-200:])
            return 1
        sim.type_line("LIST")
        st = _norm_glass(sim.screen_text())
        found_brace = "{" in st and "}" in st
        if not found_brace:
            for _ in range(40):
                if not sim.more_waiting:
                    break
                sim.push_key(" ")
                st = _norm_glass(sim.screen_text())
                if "{" in st and "}" in st:
                    found_brace = True
                    break
        if not found_brace:
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
        for _ in range(100):
            sim._rpc("TICK")

        # NEW: PACMAN.JS + DONKEY.JS must RUN (not ?NB) via companion .JSB
        for title, keybits in (("PACMAN.JS", 4), ("DONKEY.JS", 1)):
            sim.type_line(f"LOAD {title}")
            st = _norm_glass(sim.screen_text())
            if "LOADED" not in st:
                print(f"FAIL RTL LOAD {title}", repr(st)[-200:])
                return 1
            sim.type_line("RUN")
            running = False
            for _ in range(5000):
                sim._rpc("TICK")
                if "running=1" in sim._rpc("STATUS?"):
                    running = True
                    break
            if not running:
                st = _norm_glass(sim.screen_text())
                print(f"FAIL RTL RUN {title} not running", st[-120:], sim._rpc("STATUS?"))
                return 1
            for _ in range(200):
                sim._rpc("TICK")
            fb = sim._rpc("FB?")
            raw = base64.b64decode(fb.split(None, 3)[3])
            nz = sum(1 for b in raw if b)
            if nz < 50:
                print(f"FAIL RTL RUN {title} FB empty", nz)
                return 1
            sim._rpc(f"KEYBITS {keybits}")
            fb0 = bytes(sim.framebuffer().front)
            for _ in range(40):
                sim._rpc("TICK")
            sim._rpc("FB?")
            fb1 = bytes(sim.framebuffer().front)
            if fb0 == fb1:
                print(f"FAIL RTL {title} KEYBITS {keybits} no FB change")
                return 1
            sim._rpc("KEYBITS 0")
            print(f"OK RTL RUN {title} pixels ({nz}) + key")
            sim.hard_break()
            for _ in range(100):
                sim._rpc("TICK")

        # NEW: HTML RUN = compile-on-RUN → fresh .JSH on card → RTL FAT-load
        sim.type_line('LOAD "invaders.html"')
        st = _norm_glass(sim.screen_text())
        if "LOADED" not in st and "?IO" not in st:
            # FAT 8.3 may be INVADERS.HTM — try that if .html open failed
            sim.type_line("LOAD INVADERS.HTM")
            st = _norm_glass(sim.screen_text())
        if "LOADED" not in st:
            print("FAIL RTL LOAD HTML", repr(st)[-200:])
            return 1
        sim.type_line("LIST")
        st = _norm_glass(sim.screen_text())
        if "(HTML)" in st:
            print("FAIL RTL LIST HTML still stub", repr(st)[-200:])
            return 1
        if "-- MORE --" not in st and not _has_numbered_line(st, "10"):
            print("FAIL RTL LIST HTML numbers/MORE", repr(st)[-200:])
            return 1
        print("OK RTL LIST HTML numbered + MORE")
        sim.type_line("RUN")
        running = False
        for _ in range(8000):
            sim._rpc("TICK")
            if "running=1" in sim._rpc("STATUS?"):
                running = True
                break
        st = _norm_glass(sim.screen_text())
        if "?NH" in st:
            print("FAIL RTL RUN HTML still ?NH", repr(st)[-200:])
            return 1
        if not running:
            print("FAIL RTL RUN HTML VM not running", sim._rpc("STATUS?"), repr(st)[-200:])
            return 1
        for _ in range(4000):
            sim._rpc("TICK")
        sim._rpc("FB?")
        nz_h = sum(1 for b in sim.framebuffer().front if b)
        if nz_h < 50:
            print("FAIL RTL RUN HTML FB empty", nz_h)
            return 1
        for _ in range(4000):
            sim._rpc("TICK")
        sim._rpc("FB?")
        nz_h2 = sum(1 for b in sim.framebuffer().front if b)
        if nz_h2 < 50:
            print("FAIL RTL RUN HTML vanished", nz_h, nz_h2)
            return 1
        fb0 = bytes(sim.framebuffer().front)
        sim._rpc("KEYBITS 4")  # Left
        for _ in range(2000):
            sim._rpc("TICK")
        sim._rpc("FB?")
        fb1 = bytes(sim.framebuffer().front)
        if fb0 == fb1:
            print("FAIL RTL HTML KEYBITS Left no FB change")
            return 1
        sim._rpc("KEYBITS 0")
        sim._rpc("KEYBITS 16")  # Space
        for _ in range(2000):
            sim._rpc("TICK")
        sim._rpc("FB?")
        print("OK RTL HTML LOAD/LIST/RUN pixels + key", nz_h2)
        sim.hard_break()
        for _ in range(100):
            sim._rpc("TICK")
        sim.framebuffer().front[:] = b"\x00" * len(sim.framebuffer().front)

        # NEW: DONKEY.HTML / PACMAN.HTML same LOAD/RUN/.JSH ladder (not ?NH)
        for hname in ("DONKEY.HTM", "PACMAN.HTM"):
            sim.type_line(f"LOAD {hname}")
            st = _norm_glass(sim.screen_text())
            if "LOADED" not in st:
                print(f"FAIL RTL LOAD {hname}", repr(st)[-200:])
                return 1
            sim.type_line("RUN")
            running = False
            for _ in range(8000):
                sim._rpc("TICK")
                if "running=1" in sim._rpc("STATUS?"):
                    running = True
                    break
            st = _norm_glass(sim.screen_text())
            if "?NH" in st:
                print(f"FAIL RTL RUN {hname} still ?NH", repr(st)[-200:])
                return 1
            if not running:
                print(f"FAIL RTL RUN {hname} VM not running", sim._rpc("STATUS?"), repr(st)[-200:])
                return 1
            for _ in range(6000):
                sim._rpc("TICK")
            sim._rpc("FB?")
            nz_t = sum(1 for b in sim.framebuffer().front if b)
            if nz_t < 50:
                print(f"FAIL RTL RUN {hname} FB empty", nz_t)
                return 1
            fb0 = bytes(sim.framebuffer().front)
            sim._rpc("KEYBITS 4")  # Left
            for _ in range(2000):
                sim._rpc("TICK")
            sim._rpc("FB?")
            fb1 = bytes(sim.framebuffer().front)
            if fb0 == fb1:
                print(f"FAIL RTL {hname} KEYBITS Left no FB change")
                return 1
            sim._rpc("KEYBITS 0")
            print(f"OK RTL HTML {hname} pixels + key", nz_t)
            sim.hard_break()
            for _ in range(100):
                sim._rpc("TICK")
            sim.framebuffer().front[:] = b"\x00" * len(sim.framebuffer().front)
        return 0
    finally:
        sim.shutdown()


def check_rtl_list_edit_cls() -> int:
    """FPGA-SIM: LIST ranges / MORE / EDIT / CLS — same verbs as PYTHON."""
    os.environ.pop("JMR_SIM_HOST", None)
    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        print("FAIL FPGA-SIM RTL missing/default wrong")
        return 1
    try:
        for _ in range(100):
            sim._rpc("TICK")
        sim.type_line('LOAD "invaders"')
        if "LOADED" not in sim.screen_text():
            print("FAIL RTL LOAD invaders", repr(sim.screen_text())[-200:])
            return 1

        sim.type_line("LIST 10-20")
        st = _norm_glass(sim.screen_text())
        if "?" in st and "LIST 10-20" in st and not _has_numbered_line(st, "10"):
            print("FAIL RTL LIST 10-20 got ?", repr(st)[-200:])
            return 1
        if not _has_numbered_line(st, "10") or not _has_numbered_line(st, "20"):
            print("FAIL RTL LIST 10-20 numbers", repr(st)[-300:])
            return 1
        print("OK RTL LIST 10-20 numbers")

        sim.type_line("LIST -")
        st = _norm_glass(sim.screen_text())
        if "-- MORE --" not in st or not sim.more_waiting:
            print("FAIL RTL LIST - MORE", repr(st)[-200:])
            return 1
        sim.push_key(" ")
        print("OK RTL LIST - MORE")

        sim.type_line("EDIT 20")
        pref = sim.edit_prefill()
        if pref is None:
            print("FAIL RTL EDIT prefill None", repr(sim.screen_text())[-200:])
            return 1
        sim.type_line("// RTL_EDIT_OK")
        sim.type_line("LIST 20")
        if "RTL_EDIT_OK" not in sim.screen_text():
            print("FAIL RTL EDIT replace", repr(sim.screen_text())[-300:])
            return 1
        print("OK RTL EDIT 20")

        sim.type_line("CLS")
        st = _norm_glass(sim.screen_text())
        if "RTL_EDIT_OK" in st:
            print("FAIL RTL CLS", repr(st)[-200:])
            return 1
        print("OK RTL CLS")
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
        check_python_monitor_verbs,
        check_python_html_bytecode_invaders,
        check_python_html_bytecode_donkey,
        check_python_html_bytecode_pacman,
        check_hm_invaders_jsh,
        check_one_glass_parity,
        check_rtl_help_list_run,
        check_rtl_list_edit_cls,
        check_ps2_bench,
        check_board_optional,
    ]
    for fn in steps:
        rc = fn()
        if rc:
            print("BATTERY FAIL")
            return rc
    print("BATTERY PASS — PYTHON+FPGA-SIM keys/LIST/RUN; Vivado only if WNS ≥ 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
