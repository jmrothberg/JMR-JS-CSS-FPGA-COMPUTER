#!/usr/bin/env python3
"""FPGA-SIM protocol server (host twin of RTL sim_main line protocol).

LLM NOTE: Speaks KEY/JOY/LINE/FB?/SCREEN?/STATUS?/RUNCLK/TICK/PROMPT like the
Verilator server. Uses the PYTHON FM as the DUT stand-in until
`make -C sim sim_server_synth` produces jmr_js_sim_server.

TICK = RUNCLK + FB-if-changed (reply FB SAME when unchanged) — keeps typing
responsive. PROMPT paints the monitor line into the FM canvas.

Pattern cite: BASIC sim/sim_main.cpp command surface (method only).
"""

from __future__ import annotations

import base64
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from functional_model import Machine  # noqa: E402


def _fb_hash(front) -> bytes:
    return hashlib.blake2b(bytes(front), digest_size=16).digest()


def main() -> int:
    m = Machine()
    m.boot_lines()
    last_hash = _fb_hash(m.canvas.front)
    print("READY", flush=True)
    line_acc = ""
    for raw in sys.stdin:
        cmd = raw.rstrip("\n")
        if not cmd:
            continue
        if cmd.startswith("KEY "):
            try:
                b = int(cmd.split()[1], 16)
            except (IndexError, ValueError):
                print("ERR", flush=True)
                continue
            if b == 0x1B:
                m.hard_break()
                last_hash = _fb_hash(m.canvas.front)
                print("OK", flush=True)
                continue
            if b in (10, 13):
                m.type_line(line_acc)
                line_acc = ""
                last_hash = _fb_hash(m.canvas.front)
            else:
                ch = chr(b)
                if ch.isprintable():
                    line_acc += ch
            print("OK", flush=True)
        elif cmd.startswith("LINE "):
            m.type_line(cmd[5:])
            last_hash = _fb_hash(m.canvas.front)
            print("OK", flush=True)
        elif cmd.startswith("PROMPT "):
            # Live typing echo into sim glass (not host PYTHON Machine)
            m.paint_monitor(cmd[7:])
            last_hash = _fb_hash(m.canvas.front)
            print("OK", flush=True)
        elif cmd.startswith("JOY "):
            try:
                bits = int(cmd.split()[1], 0)
            except (IndexError, ValueError):
                print("ERR", flush=True)
                continue
            m.set_joy(bits)
            print("OK", flush=True)
        elif cmd.startswith("KEYBITS "):
            try:
                bits = int(cmd.split()[1], 0)
            except (IndexError, ValueError):
                print("ERR", flush=True)
                continue
            m.set_key_bits(bits)
            print("OK", flush=True)
        elif cmd == "SCREEN?":
            text = m.screen_text().replace("\n", "\\n")
            print(f"SCREEN {text}", flush=True)
        elif cmd == "FB?":
            b64 = base64.b64encode(bytes(m.canvas.front)).decode("ascii")
            last_hash = _fb_hash(m.canvas.front)
            print(f"FB {m.canvas.width} {m.canvas.height} {b64}", flush=True)
        elif cmd == "STATUS?":
            print(f"STATUS running={int(m.running)} joy={m.input.joy}", flush=True)
        elif cmd.startswith("RUNCLK"):
            m.frame_tick()
            print("OK", flush=True)
        elif cmd == "TICK":
            # One RPC: advance + FB only when pixels changed
            m.frame_tick()
            h = _fb_hash(m.canvas.front)
            if h == last_hash:
                print("FB SAME", flush=True)
            else:
                last_hash = h
                b64 = base64.b64encode(bytes(m.canvas.front)).decode("ascii")
                print(f"FB {m.canvas.width} {m.canvas.height} {b64}", flush=True)
        elif cmd == "QUIT":
            print("BYE", flush=True)
            return 0
        else:
            print("ERR", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
