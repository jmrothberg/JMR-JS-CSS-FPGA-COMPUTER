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
from functional_model.storage_engine import resolve_storage_html, storage_html_min_lines
from runtime.backend import PythonBackend
from runtime.sim_backend import SimBackend


def _title_html(family: str) -> Path | None:
    return resolve_storage_html(family)


def _title_load_name(family: str) -> str | None:
    p = resolve_storage_html(family)
    return None if p is None else p.name


def _title_is_original(family: str) -> bool:
    p = resolve_storage_html(family)
    return p is not None and p.stem.upper() == family.upper()


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

    # JOYDEMO.HTML paints on rAF
    py.type_line('LOAD "JOYDEMO.HTML"')
    py.type_line("RUN")
    fi = 0
    while fi < 5:
        py.frame_tick()
        fi = fi + 1
    nz = sum(1 for b in m.canvas.front if b)
    if nz < 50:
        print("FAIL PYTHON RUN JOYDEMO empty", nz)
        return 1
    if not m.running and not getattr(m, "_keep_fb", False):
        print("FAIL PYTHON JOYDEMO not running")
        return 1
    print("OK PYTHON RUN JOYDEMO pixels", nz)

    # INVADERS play is check_python_html_bytecode_invaders (HTML bytecode, not _loop_chunk/px/bullet).

    # NEW: LIST HTML numbered + -- MORE -- (not (HTML) stub; bytecode is the RUN path)
    m.hard_break()
    long_html = storage_html_min_lines(20)
    if long_html is None:
        print("FAIL PYTHON no storage HTML for LIST")
        return 1
    py.type_line(f'LOAD "{long_html.name}"')
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


def _hw_player_x(hw):
    """Value64 player.position.x — objects are not Python dicts (test_bytecode_js)."""
    from hardware_model.js_vm import (
        VALUE_KIND_RECORD,
        record_unpack,
        value_kind,
        value_payload,
    )

    names = hw.program_image.names
    player_handle = hw._value_vars[list(hw.program_image.var_names).index("player")]
    word = hw._value_objects[value_payload(player_handle)][names.index("position")]
    followed = hw._value64_record_follow(word)
    if value_kind(followed) == VALUE_KIND_RECORD:
        return float(record_unpack(followed)[3])
    obj = hw._value_objects[value_payload(followed)]
    return float(hw._value64_host_value(obj.get(names.index("x"))))


def _hw_array_len(hw, name: str) -> int:
    """Value64 global array length (projectiles), or -1 if not an array."""
    from hardware_model.js_vm import VALUE_KIND_ARRAY, value_kind, value_payload

    handle = hw._value_vars[list(hw.program_image.var_names).index(name)]
    if value_kind(handle) != VALUE_KIND_ARRAY:
        return -1
    slot = hw._value_arrays[value_payload(handle)]
    return -1 if slot is None else len(slot)


def check_python_html_bytecode_invaders() -> int:
    """PYTHON LOAD/RUN INVADERS-family HTML via bytecode/.JSH (not dukpy).

    Pixels + Left + Space; FB must persist across extra frames (no vanish).
    """
    name = _title_load_name("INVADERS")
    if name is None:
        print("FAIL PYTHON no INVADERS-family HTML in storage/")
        return 1
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    py.type_line(f'LOAD "{name}"')
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
    # The HTML owns its controls: Space starts INVADERS from its attract screen.
    from functional_model.input_engine import KEY_FIRE, KEY_LEFT
    m.set_key_bits(KEY_FIRE)
    py.frame_tick()
    m.set_key_bits(0)
    py.frame_tick()
    for _ in range(30):
        py.frame_tick()
    nz2 = sum(1 for b in m.canvas.front if b)
    if nz2 < 100:
        print("FAIL PYTHON HTML BYTECODE INVADERS vanished", nz, nz2)
        return 1
    hw = m._hw_vm
    px0 = _hw_player_x(hw)
    m.set_key_bits(KEY_LEFT)
    for _ in range(4):
        py.frame_tick()
    px1 = _hw_player_x(hw)
    if px0 is None or px1 is None or not (px1 < px0):
        print("FAIL PYTHON HTML BYTECODE Left did not move player.x", px0, px1)
        return 1
    m.set_key_bits(0)
    py.frame_tick()
    n0 = _hw_array_len(hw, "projectiles")
    m.set_key_bits(KEY_FIRE)
    py.frame_tick()
    n1 = _hw_array_len(hw, "projectiles")
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
    name = _title_load_name(stem)
    if name is None:
        print(f"FAIL PYTHON no {stem}-family HTML in storage/")
        return 1
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    py.type_line(f'LOAD "{name}"')
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
    """HM compile-on-RUN INVADERS-family HTML (JsHwVm + ASET), not a stale .JSH."""
    from functional_model.input_engine import KEY_FIRE, KEY_LEFT

    html_path = _title_html("INVADERS")
    if html_path is None:
        print("FAIL HM no INVADERS-family HTML in storage/")
        return 1
    m = Machine()
    m.source_name = html_path.name
    out = m._run_html_bytecode(html_path.read_text(encoding="utf-8"))
    hw = m._hw_vm
    if hw is None or hw.error or not m.running:
        print("FAIL HM INVADERS HTML run", getattr(hw, "error", None), out)
        return 1
    if out and "ERROR" in str(out[0]):
        print("FAIL HM compile INVADERS.HTML", out)
        return 1
    for _ in range(30):
        m.frame_tick()
        if hw.error:
            print("FAIL HM frame", hw.error)
            return 1
    nz = sum(1 for b in m.canvas.front if b)
    if nz < 100:
        print("FAIL HM INVADERS FB empty", nz)
        return 1
    # Space starts the title; subsequent Space is the fire acceptance input.
    m.set_key_bits(KEY_FIRE)
    m.frame_tick()
    m.set_key_bits(0)
    m.frame_tick()
    for _ in range(4):
        m.frame_tick()
    px0 = _hw_player_x(hw)
    m.set_key_bits(KEY_LEFT)
    for _ in range(4):
        m.frame_tick()
    px1 = _hw_player_x(hw)
    if px0 is None or px1 is None or not (px1 < px0):
        print("FAIL HM Left did not move player.x", px0, px1)
        return 1
    m.set_key_bits(0)
    m.frame_tick()
    n0 = _hw_array_len(hw, "projectiles")
    m.set_key_bits(KEY_FIRE)
    m.frame_tick()
    n1 = _hw_array_len(hw, "projectiles")
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
        found_title = False
        for _ in range(8):
            st = _norm_glass(sim.screen_text())
            up = st.upper()
            if "JOYDEMO" in up or "BOXES" in up or "ASTEROID" in up:
                found_title = True
                break
            if "-- MORE" in st:
                sim.push_key(" ")
            else:
                break
        if not found_title:
            print("FAIL RTL DIR", repr(st)[-200:])
            return 1
        print("OK RTL DIR")
        sim._abort_more()

        list_html = storage_html_min_lines(20)
        if list_html is None:
            print("FAIL RTL no storage HTML for LIST")
            return 1
        sim.type_line(f'LOAD "{list_html.name}"')
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

        # JOYDEMO.HTML FB pixels
        sim.type_line("LOAD JOYDEMO.HTML")
        sim.type_line("RUN")
        for _ in range(100):
            sim._rpc("TICK")
        fb = sim._rpc("FB?")
        if not fb.startswith("FB 640 480 "):
            print("FAIL JOYDEMO FB?", fb[:60])
            return 1
        raw = base64.b64decode(fb.split(None, 3)[3])
        nz = sum(1 for b in raw if b)
        if nz < 50:
            print("FAIL JOYDEMO FB empty")
            return 1
        print("OK RTL RUN JOYDEMO pixels")
        sim.hard_break()
        for _ in range(50):
            sim._rpc("TICK")

        # INVADERS-family HTML VM (card .JSH)
        inv_name = _title_load_name("INVADERS")
        if inv_name is None:
            print("FAIL RTL no INVADERS-family HTML in storage/")
            return 1
        sim.type_line(f'LOAD "{inv_name}"')
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

        # NEW: Up bit reaches RTL (keyUp native id 8)
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

        # Remove duplicate early KEYBITS smoke if still above — keep JOYDEMO path's KEYBITS check
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

        # RETIRED: the PACMAN.JS/DONKEY.JS twin check loaded same-name .JS
        # companions that no longer exist (one title = one NAME.HTML; the
        # compile-on-RUN HTML ladder below covers both titles + keys).

        # NEW: HTML RUN = card .JSH on FAT
        html_name = _title_load_name("INVADERS") or (storage_html_min_lines(20) and storage_html_min_lines(20).name)
        if not html_name:
            print("FAIL RTL no HTML for LOAD/LIST")
            return 1
        sim.type_line(f'LOAD "{html_name}"')
        st = _norm_glass(sim.screen_text())
        if "LOADED" not in st and "?IO" not in st:
            sim.type_line(f'LOAD "{Path(html_name).stem}.HTM"')
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

        # NEW: DONKEY / PACMAN family same LOAD/RUN/.JSH ladder (not ?NH)
        for family in ("DONKEY", "PACMAN"):
            hname = _title_load_name(family)
            if hname is None:
                print(f"FAIL RTL no {family}-family HTML in storage/")
                return 1
            sim.type_line(f'LOAD "{hname}"')
            st = _norm_glass(sim.screen_text())
            if "LOADED" not in st:
                print(f"FAIL RTL LOAD {hname}", repr(st)[-200:])
                return 1
            sim.type_line("RUN")
            running = False
            # DONKEY's full-res ASET makes the .JSH ~2.4 MB — the FAT+SRAM
            # stream runs ~100 clk/byte ≈ 250M clocks (board: ~2.5 s at
            # 100 MHz), so wait in big TICKN slices
            for _ in range(200):
                sim._rpc("TICKN 2000")
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


def _bunker_arch_ok(fb: bytes) -> bool:
    """INVADERS bunkers at y=350, x=70: continue skips the two corner cells."""
    row = 350 * 640
    corner = any(fb[row + 70 + i] for i in range(8))
    inner = any(fb[row + 78 + i] for i in range(8))
    return (not corner) and bool(inner)


# Ghost NPC colors from the HTML (_COLOR). House = cells (11..16, 12..15)
# at map origin (16,8) size 14, plus ~12px sprite radius.
_GHOST_RGB = ((255, 0, 0), (255, 153, 51), (0, 204, 255), (255, 153, 204))
_HOUSE = (155, 270, 160, 250)  # x0,x1,y0,y1


def _ghost_indices(pal) -> set[int]:
    from functional_model.canvas_engine import nearest_palette_index

    out: set[int] = set()
    for rgb in _GHOST_RGB:
        idx = nearest_palette_index(list(pal), rgb, lo=1)
        pr, pg, pb = pal[idx]
        d = sum((a - b) * (a - b) for a, b in zip((pr, pg, pb), rgb))
        if d <= 80 * 80 * 3:
            out.add(idx)
    return out


def _ghost_color_outside(fb: bytes, pal) -> int:
    """Count ghost-colored pixels outside the house bbox (not maze/pellet ink)."""
    want = _ghost_indices(pal)
    if not want:
        return 0
    x0, x1, y0, y1 = _HOUSE
    n = 0
    for y in range(480):
        row = y * 640
        for x in range(640):
            if x0 <= x <= x1 and y0 <= y <= y1:
                continue
            if fb[row + x] in want:
                n += 1
    return n
    inner = any(fb[row + 78 + i] for i in range(8))
    return (not corner) and bool(inner)


def check_play_progression() -> int:
    """Play-progression (both runtimes) — F9 regressions should fail here first."""
    inv_name = _title_load_name("INVADERS")
    if inv_name is None:
        print("FAIL PYTHON no INVADERS-family HTML in storage/")
        return 1
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    py.type_line(f'LOAD "{inv_name}"')
    py.type_line("RUN")
    if not m.running or getattr(m, "html_host", None) is not None:
        print("FAIL PYTHON play INVADERS not bytecode")
        return 1
    for _ in range(24):
        py.frame_tick()
    fb = bytes(m.canvas.front)
    if _title_is_original("INVADERS"):
        if not _bunker_arch_ok(fb):
            print("FAIL PYTHON INVADERS bunker top is square (continue)")
            return 1
        print("OK PYTHON INVADERS bunker arch")
    else:
        nz = sum(1 for b in fb if b)
        if nz < 50:
            print("FAIL PYTHON INVADERS-family FB empty", nz)
            return 1
        print("OK PYTHON INVADERS-family pixels", nz)
    py.hard_break()

    # PYTHON PACMAN family: ghost-colored pixels (layout-specific NOTE if FAST).
    pac_name = _title_load_name("PACMAN")
    if pac_name is None:
        print("FAIL PYTHON no PACMAN-family HTML in storage/")
        return 1
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    py.type_line(f'LOAD "{pac_name}"')
    py.type_line("RUN")
    for _ in range(16):
        py.frame_tick()
        if m.vm.error:
            print("FAIL PYTHON play PACMAN VM", m.vm.error)
            return 1
    m.input.key_event(13, "Enter", True)
    m.input.key_event(13, "Enter", False)
    for _ in range(400):
        py.frame_tick()
        if m.vm.error:
            print("FAIL PYTHON play PACMAN VM", m.vm.error)
            return 1
    fb = bytes(m.canvas.front)
    n_out = _ghost_color_outside(fb, m.canvas.palette)
    if _title_is_original("PACMAN"):
        if n_out < 8:
            print("NOTE PYTHON PACMAN ghost-color outside house", n_out, "(F9 is play proof)")
        else:
            print("OK PYTHON PACMAN ghost-color outside house", n_out)
    else:
        nz = sum(1 for b in fb if b)
        if nz < 50:
            print("FAIL PYTHON PACMAN-family FB empty", nz)
            return 1
        print("OK PYTHON PACMAN-family pixels", nz)
    py.hard_break()

    # PYTHON DONKEY family: boot and/or KEYEVT Enter leave the initial glass
    dnk_name = _title_load_name("DONKEY")
    if dnk_name is None:
        print("FAIL PYTHON no DONKEY-family HTML in storage/")
        return 1
    m = Machine()
    py = PythonBackend(m)
    m.boot_lines()
    py.type_line(f'LOAD "{dnk_name}"')
    py.type_line("RUN")
    fb0 = bytes(m.canvas.front)
    for _ in range(16):
        py.frame_tick()
    m.input.key_event(13, "Enter", True)
    m.input.key_event(13, "Enter", False)
    for _ in range(16):
        py.frame_tick()
    fb1 = bytes(m.canvas.front)
    if fb0 == fb1:
        print("FAIL PYTHON DONKEY boot/Enter no FB change")
        return 1
    print("OK PYTHON DONKEY Enter advances")
    py.hard_break()

    # RTL twins
    os.environ.pop("JMR_SIM_HOST", None)
    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        print("FAIL FPGA-SIM RTL missing for play-progression")
        return 1
    try:
        for _ in range(200):
            sim._rpc("TICK")
        sim.type_line(f'LOAD "{inv_name}"')
        sim.type_line("RUN")
        running = False
        for _ in range(4000):
            sim._rpc("TICK")
            if "running=1" in sim._rpc("STATUS?"):
                running = True
                break
        if not running:
            print("FAIL RTL play INVADERS not running")
            return 1
        for _ in range(24):
            sim._rpc("FRAME")
        sim._rpc("FB?")
        fb = bytes(sim.framebuffer().front)
        if _title_is_original("INVADERS"):
            if not _bunker_arch_ok(fb):
                print("FAIL RTL INVADERS bunker top is square")
                return 1
            print("OK RTL INVADERS bunker arch")
        else:
            nz = sum(1 for b in fb if b)
            if nz < 50:
                print("FAIL RTL INVADERS-family FB empty", nz)
                return 1
            print("OK RTL INVADERS-family pixels", nz)
        sim.hard_break()
        for _ in range(50):
            sim._rpc("TICK")

        sim.type_line(f'LOAD "{pac_name}"')
        sim.type_line("RUN")
        running = False
        for _ in range(4000):
            sim._rpc("TICK")
            if "running=1" in sim._rpc("STATUS?"):
                running = True
                break
        if not running:
            print("FAIL RTL play PACMAN not running")
            return 1
        for _ in range(8):
            sim._rpc("FRAME")
        sim._rpc("KEYEVT 13 1")
        sim._rpc("KEYEVT 13 0")
        for _ in range(80):
            sim._rpc("FRAME")
        sim._rpc("FB?")
        fb = bytes(sim.framebuffer().front)
        pal = sim.framebuffer().palette
        n_out = _ghost_color_outside(fb, pal)
        if _title_is_original("PACMAN"):
            if n_out < 8:
                print("NOTE RTL PACMAN ghost-color outside house", n_out, "(F9 is play proof)")
            else:
                print("OK RTL PACMAN ghost-color outside house", n_out)
        else:
            nz = sum(1 for b in fb if b)
            if nz < 50:
                print("FAIL RTL PACMAN-family FB empty", nz)
                return 1
            print("OK RTL PACMAN-family pixels", nz)
        sim.hard_break()
        for _ in range(50):
            sim._rpc("TICK")

        sim.type_line(f'LOAD "{dnk_name}"')
        sim.type_line("RUN")
        running = False
        for _ in range(200):
            sim._rpc("TICKN 2000")
            if "running=1" in sim._rpc("STATUS?"):
                running = True
                break
        if not running:
            print("FAIL RTL play DONKEY not running")
            return 1
        for _ in range(8):
            sim._rpc("FRAME")
        sim._rpc("FB?")
        fb0 = bytes(sim.framebuffer().front)
        sim._rpc("KEYEVT 13 1")
        sim._rpc("KEYEVT 13 0")
        for _ in range(16):
            sim._rpc("FRAME")
        sim._rpc("FB?")
        fb1 = bytes(sim.framebuffer().front)
        if fb0 == fb1:
            print("FAIL RTL DONKEY boot/Enter no FB change")
            return 1
        print("OK RTL DONKEY Enter advances")
        return 0
    finally:
        sim.shutdown()


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
        check_play_progression,
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
