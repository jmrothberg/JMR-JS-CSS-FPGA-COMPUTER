"""Verilator FPGA-SIM backend — line protocol client.

HARD RULE: FPGA-SIM defaults to real RTL (jmr_js_sim_server). Never silently
fall back to the PYTHON host twin — that fake default burned hours comparing
the wrong machine to silicon.

  Default:          sim_build_synth/jmr_js_sim_server (RTL)
  Host twin only:   JMR_SIM_HOST=1 (dukpy / full Canvas — explicit opt-in)
  Missing RTL:      fail loud (do not pretend PYTHON is FPGA-SIM)

RTL text is rasterized from SCREEN? into the local 640×480 canvas.
TICK stays cheap (FB SAME). GUI pulls FB? while game_mode.
"""

from __future__ import annotations

import base64
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

from functional_model.canvas_engine import CanvasEngine
from runtime.backend import ROOT, RuntimeBackend
from runtime.flight_log import FlightLog

SIM_DIR = ROOT / "sim"
_SYNTH = SIM_DIR / "sim_build_synth" / "jmr_js_sim_server"
_HOST_PY = SIM_DIR / "host_sim_server.py"


class SimBackend(RuntimeBackend):
    name = "FPGA-SIM"

    def __init__(self) -> None:
        self._proc: Optional[subprocess.Popen] = None
        self._canvas = CanvasEngine()
        self._screen = ""
        self._started = False
        self._running = False  # NEW: RTL game_mode — skip prompt overlay
        self._more = False     # NEW: parked on -- MORE --
        self._edit_prefill: Optional[str] = None
        self._loaded_name: str = ""
        self._log = FlightLog(self.name)
        # HARD RULE: RTL is default. Host twin ONLY via explicit JMR_SIM_HOST=1.
        # JMR_SIM_RTL=1 is accepted as a no-op alias (legacy scripts).
        host_opt = os.environ.get("JMR_SIM_HOST", "").strip().lower() in ("1", "true", "yes")
        self._use_rtl = not host_opt
        self._log.note(
            f"sim synth={_SYNTH.is_file()} host={_HOST_PY.is_file()} "
            f"mode={'RTL' if self._use_rtl else 'HOST'}"
        )

    @property
    def mode_label(self) -> str:
        """GUI status: FPGA-SIM (RTL) vs FPGA-SIM (HOST)."""
        return "RTL" if self._use_rtl else "HOST"

    @property
    def available(self) -> bool:
        # RTL path: binary must exist. Host path: only when explicitly opted in.
        if self._use_rtl:
            return _SYNTH.is_file()
        return _HOST_PY.is_file()

    def _start(self) -> None:
        if self._started:
            return
        if self._use_rtl:
            if not _SYNTH.is_file():
                self._log.fault("NO_RTL", "build: make -C sim sim_server_synth")
                raise RuntimeError(
                    "FPGA-SIM RTL missing — run: make -C sim sim_server_synth "
                    "(refusing host twin; set JMR_SIM_HOST=1 only for dukpy twin)"
                )
            cmd = [str(_SYNTH)]
            self._log.note(f"spawn RTL {cmd[0]}")
        else:
            if not _HOST_PY.is_file():
                self._log.fault("NO_HOST", str(_HOST_PY))
                raise RuntimeError("JMR_SIM_HOST=1 but host_sim_server.py missing")
            cmd = [sys.executable, "-B", str(_HOST_PY)]
            self._log.note("spawn host_sim_server.py (explicit JMR_SIM_HOST=1)")
        env = os.environ.copy()
        env["JMR_STANDALONE"] = env.get("JMR_STANDALONE", "1")
        # NEW: always the project card.img (sim_main prefers ../card.img from
        # sim/ cwd — a stale root image used to hide INVADERS.JSH → ?NH)
        env.setdefault("JMR_CARD_IMG", str(ROOT / "card.img"))
        # NEW: keep stderr separate — RTL prints "SD image …" on cerr; merging
        # into stdout used to steal the READY handshake (fake/broken SIM start).
        self._proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(SIM_DIR),
            bufsize=1,
            env=env,
        )
        assert self._proc.stdout is not None
        hello = self._proc.stdout.readline().strip()
        if hello != "READY":
            self._log.fault("NO_READY", repr(hello))
            raise RuntimeError(f"sim server did not READY: {hello!r}")
        self._started = True
        self._rpc("SCREEN?")
        self._sync_glass()

    def _rpc(self, cmd: str) -> str:
        self._start()
        assert self._proc and self._proc.stdin and self._proc.stdout
        t0 = time.perf_counter()
        self._proc.stdin.write(cmd + "\n")
        self._proc.stdin.flush()
        resp = self._proc.stdout.readline().rstrip("\n")
        dt_ms = (time.perf_counter() - t0) * 1000.0
        if resp.startswith("SCREEN "):
            self._screen = resp[7:].replace("\\n", "\n")
        elif resp.startswith("FB "):
            parts = resp.split(None, 3)
            if len(parts) == 4:
                raw = base64.b64decode(parts[3])
                if len(raw) == len(self._canvas.front):
                    self._canvas.front[:] = raw
        elif resp == "FB SAME":
            pass
        elif resp.startswith("ERR") or resp.startswith("FAULT"):
            self._log.fault("RPC", f"cmd={cmd!r} resp={resp!r}")
        if cmd.startswith("LINE ") or cmd.startswith("KEY ") or dt_ms > 25.0:
            self._log.note(f"rpc {cmd.split()[0]} {dt_ms:.1f}ms")
        return resp

    @property
    def running(self) -> bool:
        """True while RTL game_mode — GUI must not paint a monitor prompt on top."""
        return self._running

    @property
    def more_waiting(self) -> bool:
        """True while LIST/DIR parked on -- MORE -- (Space/Enter continues)."""
        return self._more

    def edit_prefill(self) -> Optional[str]:
        """Body text after EDIT n (for GUI line_buf)."""
        return self._edit_prefill

    def _screen_has_more(self) -> bool:
        # NEW: skip trailing blank VRAM rows — MORE is last non-empty line
        for ln in reversed(self._screen.splitlines()):
            t = ln.strip()
            if not t:
                continue
            return t.startswith("-- MORE")
        return False

    def _abort_more(self) -> None:
        """Esc out of -- MORE -- so the next LINE is not eaten as a page key."""
        for _ in range(32):
            self._rpc("SCREEN?")
            if not self._screen_has_more():
                self._more = False
                return
            self._rpc("KEY 1b")
            for _ in range(30):
                self._rpc("TICK")
        self._more = False

    def _note_edit_prefill(self) -> None:
        """After EDIT n, SCREEN shows '20 body' — capture body for GUI prefill."""
        self._edit_prefill = None
        for ln in reversed(self._screen.splitlines()):
            t = ln.strip()
            if not t or t in ("READY", ">", "OK", "?"):
                continue
            if t.startswith("-- MORE") or t.startswith(">"):
                continue
            parts = t.split(None, 1)
            if parts and parts[0].isdigit():
                self._edit_prefill = parts[1] if len(parts) > 1 else ""
                return
            # wrapped continuation of EDIT body — keep scanning for 'N body'

    def _paint_screen_local(
        self, prompt: Optional[str] = None, cursor_on: bool = False
    ) -> None:
        """RTL text path — HDMI letterbox (same geometry as PYTHON / BOARD)."""
        # NEW: while MORE, do not append a second ">"
        if self._more:
            pr = None
            lines = self._screen.splitlines()
            self._canvas.paint_console_letterbox(lines, prompt="")
            return
        pr = prompt if prompt is not None else "> "
        self._canvas.paint_console_letterbox(
            self._screen.splitlines(),
            prompt=pr,
            cursor_on=cursor_on,
        )

    def _sync_glass(self, prompt: Optional[str] = None) -> None:
        """Pull SCREEN? + FB?; paint FB when game_mode, else HDMI letterbox text."""
        self._rpc("SCREEN?")
        self._more = self._screen_has_more()
        resp = self._rpc("FB?")
        if resp.startswith("FB ") and len(resp.split(None, 3)) == 4:
            # Real pixels from RTL mini-FB — keep them; do not letterbox on top
            self._running = True
            return
        st = self._rpc("STATUS?")
        self._running = "running=1" in st
        if self._running:
            return
        if self._use_rtl or resp == "FB SAME" or not resp.startswith("FB "):
            if self._use_rtl or not any(self._canvas.front):
                self._paint_screen_local(prompt)

    def type_line(self, text: str) -> None:
        self._log.type_line(text)
        # NEW: leave MORE before a new command (else first char advances the page)
        self._abort_more()
        stripped = text.strip()
        upper = stripped.upper()
        if upper.startswith("LOAD"):
            self._loaded_name = stripped[4:].strip().strip('"').strip("'")
        # Compile-on-RUN: fresh .JSH into the live card, then RTL FAT-loads it.
        if upper == "RUN" or upper.startswith("RUN "):
            if self._html_loaded_stem() and not self._compile_on_run_html():
                self._sync_glass("> ")
                return
        self._rpc(f"LINE {text}")
        self._sync_glass("> ")
        if upper.startswith("EDIT"):
            self._note_edit_prefill()

    def _html_loaded_stem(self) -> str:
        name = (self._loaded_name or "").upper()
        if name.endswith(".HTML") or name.endswith(".HTM"):
            return Path(name).stem[:8]
        return ""

    def _compile_on_run_html(self) -> bool:
        """Compile current storage HTML → fresh .JSH on card.img → SDRELOAD.

        RTL still FAT-loads NAME.JSH; that file is this compile, not a stale sidecar.
        """
        stem = self._html_loaded_stem()
        html_path = ROOT / "storage" / f"{stem}.HTML"
        if not html_path.is_file():
            self._log.fault("COMPILE", f"no {html_path.name} — refuse RUN (?NH)")
            return False
        try:
            from functional_model.compiler import CompileError
            from tools.compile_js import compile_html_text, encode_html_chunk
            from tools.make_sd_image import patch_card_file

            html = html_path.read_text(encoding="utf-8")
            chunk = compile_html_text(html)
            blob = encode_html_chunk(chunk)
            jsh_name = f"{stem}.JSH"
            (ROOT / "storage" / jsh_name).write_bytes(blob)
            card = Path(os.environ.get("JMR_CARD_IMG") or (ROOT / "card.img"))
            if card.is_file():
                patch_card_file(card, jsh_name, blob)
                resp = self._rpc("SDRELOAD")
                if resp != "OK":
                    self._log.fault(
                        "SDRELOAD",
                        f"{resp} — rebuild sim (SDRELOAD) so RUN cannot load a stale .JSH",
                    )
                    return False
            self._log.note(f"compile-on-RUN {html_path.name} → {jsh_name} ({len(blob)} bytes)")
            return True
        except CompileError as e:
            where = f" LINE {e.line}" if e.line else ""
            self._log.fault("COMPILE", f"ERROR{where}: {e.message}")
            return False
        except Exception as e:
            self._log.fault("COMPILE", str(e))
            return False

    def push_key(self, ch: str) -> None:
        """MORE continue / Esc — GUI Space/Enter while more_waiting."""
        if not self._started:
            self._start()
        if ch == "\x1b":
            self._rpc("KEY 1b")
        elif ch in (" ", "\r", "\n"):
            self._rpc("KEY 20" if ch == " " else "KEY 0d")
        else:
            self._rpc(f"KEY {ord(ch):02x}")
        for _ in range(40):
            self._rpc("TICK")
        self._sync_glass("> " if not self._more else "")

    def screen_text(self) -> str:
        if not self._started:
            self._start()
        return self._screen

    def set_joy(self, bits: int) -> None:
        self._rpc(f"JOY {bits}")

    def set_key_bits(self, bits: int) -> None:
        self._rpc(f"KEYBITS {bits}")

    def paint_prompt(self, prompt: str, cursor_on: bool = False) -> None:
        if not self._started:
            self._start()
        # NEW: game owns the glass (BASIC method) — never overlay `>` on FB
        if self._running or self._more:
            return
        if self._use_rtl:
            self._paint_screen_local(prompt, cursor_on=cursor_on)
        else:
            self._rpc(f"PROMPT {prompt}")
            resp = self._rpc("FB?")
            if resp == "FB SAME":
                self._rpc("SCREEN?")
                self._paint_screen_local(prompt, cursor_on=cursor_on)

    def hard_break(self) -> None:
        self._log.note("BREAK")
        self._abort_more()
        self._rpc("KEY 1b")
        self._sync_glass("> ")
        self._edit_prefill = None

    def framebuffer(self):
        return self._canvas

    def poll(self) -> None:
        return

    def frame_tick(self) -> None:
        if not self._started:
            return
        self._rpc("TICK")
        # NEW: TICK stays cheap; pull FB while the game is up so GUI animates
        if self._running:
            self._rpc("FB?")
        elif self._more:
            self._rpc("SCREEN?")
            self._more = self._screen_has_more()
            if not self._more:
                self._paint_screen_local("> ")

    def trace_path(self) -> Optional[Path]:
        return self._log.path

    def shutdown(self) -> None:
        if self._proc is None:
            return
        try:
            if self._proc.stdin and self._proc.poll() is None:
                self._proc.stdin.write("QUIT\n")
                self._proc.stdin.flush()
        except Exception:
            pass
        try:
            self._proc.terminate()
        except Exception:
            pass
        self._proc = None
        self._started = False
        self._log.note("shutdown")
