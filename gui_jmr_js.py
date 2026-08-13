#!/usr/bin/env python3
"""Graphical host for the JMR JS Computer — single 640×480 glass.

Pattern cite: JMR-BASIC-FPGA-COMPUTER/gui_jmr.py — one phosphor for console+program.
Monitor text and Canvas games share the same framebuffer. No separate Text console.

  python3 gui_jmr_js.py

F9 cycles PYTHON → FPGA-SIM → BOARD → (ASIC-SIM later).
Arrows + Space = play. Mouse stick OFF (was fighting KEYBITS on FPGA-SIM).
"""

from __future__ import annotations

import argparse
import sys
import time
import tkinter as tk
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Prefer project venv when launched as /bin/python3 from the IDE
_venv_py = ROOT / ".venv" / "bin" / "python"
if _venv_py.is_file() and Path(sys.executable).resolve() != _venv_py.resolve():
    import os

    os.execv(str(_venv_py), [str(_venv_py), *sys.argv])

from functional_model import Machine  # noqa: E402
from functional_model.canvas_engine import HEIGHT, WIDTH  # noqa: E402
from functional_model.input_engine import (  # noqa: E402
    JOY_DOWN,
    JOY_FIRE1,
    JOY_FIRE2,
    JOY_LEFT,
    JOY_RIGHT,
    JOY_UP,
)
from runtime.backend import PythonBackend  # noqa: E402

FRAME_MS = 16
DEADZONE = 40


def _try_sim_backend():
    try:
        from runtime.sim_backend import SimBackend

        return SimBackend()
    except Exception:
        return None


def _try_board_backend():
    try:
        from runtime.board_backend import BoardBackend

        return BoardBackend()
    except Exception:
        return None


def _try_asic_backend():
    try:
        from runtime.asic_sim_backend import AsicSimBackend

        return AsicSimBackend()
    except Exception:
        return None


class App:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("JMR JS Computer")
        self.root.configure(bg="#1a1a1a")
        self.machine = Machine()
        self.machine.boot_lines()

        self.backends = []
        self.backends.append(PythonBackend(self.machine))
        sim = _try_sim_backend()
        if sim is not None and sim.available:
            self.backends.append(sim)
        board = _try_board_backend()
        if board is not None and board.available:
            self.backends.append(board)
        asic = _try_asic_backend()
        if asic is not None and asic.available:
            self.backends.append(asic)
        self.backend_index = 0
        self.backend = self.backends[0]

        self.line_buf = ""
        self._fire1 = False
        self._fire2 = False
        self._key_left = False
        self._key_right = False
        self._key_up = False
        self._key_down = False
        self._key_fire = False
        self._ppm_bytes: bytes | None = None
        # NEW: letterbox cursor blink (~2 Hz) — HDMI already blinks via frame_div[5]
        self._cursor_on = True
        self._cursor_t = time.monotonic()
        self._last_prompt: str | None = None

        self._build_ui()
        # MORE waiter: pump Tk + refresh glass (BASIC more_idle pattern)
        self.machine.more_idle = self._more_idle

        # bind_all so arrows work even if focus is weird (no Text widget to steal them)
        self.root.bind_all("<KeyPress>", self.on_key_press)
        self.root.bind_all("<KeyRelease>", self.on_key_release)
        # Paste like BASIC GUI (Ctrl-V / <<Paste>>). No Super-v — Linux Tk rejects it.
        self.root.bind_all("<<Paste>>", self.on_paste)
        self.root.bind_all("<Control-v>", self.on_paste)
        self.root.bind_all("<Control-V>", self.on_paste)
        # NEW: mouse stick OFF — click only focuses glass (no JOY overwrite of KEYBITS)
        self.canvas_label.bind("<Button-1>", lambda e: self.canvas_label.focus_set())
        self.root.bind_all("<F9>", self.cycle_runtime)
        self.root.bind_all("<Escape>", lambda e: self.break_program())

        self.machine.paint_monitor("> ")
        self._refresh_fb()
        self.canvas_label.focus_set()
        self.root.after(FRAME_MS, self._frame)

    def _build_ui(self) -> None:
        self.status = tk.Label(
            self.root,
            text=self._status_text(),
            fg="#c0ffc0",
            bg="#1a1a1a",
            anchor="w",
            font=("Courier", 11),
        )
        self.status.pack(fill=tk.X, padx=6, pady=4)

        self.photo = tk.PhotoImage(width=WIDTH, height=HEIGHT)
        self.canvas_label = tk.Label(self.root, image=self.photo, bg="#000", takefocus=1)
        self.canvas_label.pack(padx=6, pady=4)

        self.hint = tk.Label(
            self.root,
            text="F9=runtime  ESC=break  Ctrl-V paste  EDIT n / LIST -  arrows+space=play  type+Enter",
            fg="#888",
            bg="#1a1a1a",
            anchor="w",
        )
        self.hint.pack(fill=tk.X, padx=6, pady=2)

    def _status_text(self) -> str:
        # NEW: show FPGA-SIM (RTL) vs (HOST) so a fake twin cannot hide
        names = []
        for b in self.backends:
            label = getattr(b, "mode_label", None)
            names.append(f"{b.name} ({label})" if label else b.name)
        cur = self.backend.name
        ml = getattr(self.backend, "mode_label", None)
        if ml:
            cur = f"{cur} ({ml})"
        tr = self.backend.trace_path()
        tip = f"  log={tr.name}" if tr is not None else ""
        return f"Runtime: {cur}   [{' | '.join(names)}]{tip}"

    def _is_running(self) -> bool:
        """Game owns the glass — PYTHON loop / last frame or FPGA-SIM game_mode."""
        if getattr(self.backend, "running", False):
            return True
        if getattr(self.backend, "more_waiting", False):
            return True
        m = getattr(self.backend, "machine", None)
        if m is None:
            return False
        return bool(
            m.running
            or getattr(m, "_keep_fb", False)
            or m._loop_chunk is not None
            or getattr(m, "html_host", None) is not None
        )

    def _more_idle(self) -> None:
        try:
            self._refresh_fb()
            self.root.update()
        except tk.TclError:
            pass
        time.sleep(0.01)

    def cycle_runtime(self, _event=None) -> None:
        old = self.backend
        self.backend_index = (self.backend_index + 1) % len(self.backends)
        self.backend = self.backends[self.backend_index]
        if old.name == "FPGA-SIM":
            old.shutdown()
        if self.backend.name == "FPGA-SIM":
            self.backend._started = False
            self.backend._proc = None
        self.status.configure(text=self._status_text())
        self._paint_prompt()
        self.canvas_label.focus_set()

    def break_program(self) -> None:
        m = getattr(self.backend, "machine", self.machine)
        m.push_key("\x1b")
        self.backend.hard_break()
        self.line_buf = ""
        self._paint_prompt()
        self.canvas_label.focus_set()

    def _play_key_held(self) -> bool:
        return (
            self._key_left
            or self._key_right
            or self._key_up
            or self._key_down
            or self._key_fire
        )

    def on_paste(self, _event: tk.Event | None = None) -> str:
        """Insert clipboard into the monitor line (BASIC gui_jmr.py method)."""
        try:
            clip = self.root.clipboard_get()
        except tk.TclError:
            return "break"
        if not clip:
            return "break"
        m = getattr(self.backend, "machine", self.machine)
        if m.running and (m._loop_chunk is not None or getattr(m, "html_host", None) is not None):
            return "break"
        clip = clip.replace("\r\n", "\n").replace("\r", "\n")
        parts = clip.split("\n")
        for i, part in enumerate(parts):
            last = i == len(parts) - 1
            self.line_buf += part
            if not last:
                line = self.line_buf
                self.line_buf = ""
                self.backend.type_line(line)
                self._after_command()
        self._paint_prompt()
        self.canvas_label.focus_set()
        return "break"

    def on_key_press(self, event: tk.Event) -> str | None:
        if event.keysym in ("F9", "Escape"):
            return None
        # Ctrl/Cmd+V handled by on_paste binds — do not also type 'v'
        state = int(getattr(event, "state", 0) or 0)
        if (state & 0x4) or (state & 0x40):  # Control or Mod4/Super
            if event.keysym.lower() == "v":
                return self.on_paste(event)
            return "break"
        # Play keys — always (games or monitor MORE)
        if event.keysym == "Left":
            self._key_left = True
            self._emit_keys()
            self._feed_more(" ")
            return "break"
        if event.keysym == "Right":
            self._key_right = True
            self._emit_keys()
            self._feed_more(" ")
            return "break"
        if event.keysym == "Up":
            self._key_up = True
            self._emit_keys()
            return "break"
        if event.keysym == "Down":
            self._key_down = True
            self._emit_keys()
            return "break"
        if event.keysym == "space":
            self._key_fire = True
            self._emit_keys()
            self._feed_more(" ")
            m = getattr(self.backend, "machine", None)
            if m is not None and m.running:
                return "break"
            if self._is_running():
                return "break"
            self.line_buf += " "
            self._paint_prompt()
            return "break"
        if self._is_running():
            return "break"

        if event.keysym in ("Return", "KP_Enter"):
            self._feed_more("\r")
            line = self.line_buf
            self.line_buf = ""
            self.backend.type_line(line)
            self._after_command()
            return "break"
        if event.keysym == "BackSpace":
            self.line_buf = self.line_buf[:-1]
            self._paint_prompt()
            return "break"
        ch = event.char
        if ch and ch.isprintable():
            self.line_buf += ch
            self._paint_prompt()
            return "break"
        return None

    def on_key_release(self, event: tk.Event) -> str | None:
        if event.keysym == "Left":
            self._key_left = False
            self._emit_keys()
            return "break"
        if event.keysym == "Right":
            self._key_right = False
            self._emit_keys()
            return "break"
        if event.keysym == "Up":
            self._key_up = False
            self._emit_keys()
            return "break"
        if event.keysym == "Down":
            self._key_down = False
            self._emit_keys()
            return "break"
        if event.keysym == "space":
            self._key_fire = False
            self._emit_keys()
            return "break"
        return None

    def _feed_more(self, ch: str) -> None:
        # NEW: FPGA-SIM MORE must get KEY — not only the PYTHON machine
        if hasattr(self.backend, "push_key") and (
            getattr(self.backend, "more_waiting", False)
            or self.backend.name == "FPGA-SIM"
        ):
            if getattr(self.backend, "more_waiting", False) or ch == "\x1b":
                self.backend.push_key(ch)
                self._refresh_fb()
                return
        m = getattr(self.backend, "machine", self.machine)
        m.push_key(ch)

    def _after_command(self) -> None:
        # Prefill after EDIT (PYTHON machine or FPGA-SIM SCREEN capture)
        pref = None
        if hasattr(self.backend, "edit_prefill"):
            pref = self.backend.edit_prefill()
        m = getattr(self.backend, "machine", None)
        if pref is None and m is not None and hasattr(m, "edit_prefill"):
            pref = m.edit_prefill() if getattr(m, "_edit_waiting", None) is not None else None
        if pref is not None:
            self.line_buf = pref
        self._paint_prompt()
        self.canvas_label.focus_set()
        self._refresh_fb()

    def _paint_prompt(self) -> None:
        if self._is_running():
            return
        if getattr(self.backend, "more_waiting", False):
            return
        m = getattr(self.backend, "machine", self.machine)
        prompt = f"> {self.line_buf}"
        # Paint into the ACTIVE runtime glass (FPGA-SIM uses PROMPT RPC)
        if hasattr(self.backend, "paint_prompt"):
            self.backend.paint_prompt(prompt, cursor_on=self._cursor_on)
        else:
            m.paint_monitor(prompt, cursor_on=self._cursor_on)
        self._last_prompt = prompt
        self._refresh_fb()

    def _emit_keys(self) -> None:
        # NEW: KEYBITS only — never JOY 0 (SIM assigns joy_in; JOY wiped arrows/Space)
        bits = 0
        if self._key_left:
            bits |= JOY_LEFT
        if self._key_right:
            bits |= JOY_RIGHT
        if self._key_up:
            bits |= JOY_UP
        if self._key_down:
            bits |= JOY_DOWN
        if self._key_fire:
            bits |= JOY_FIRE1
        self.backend.set_key_bits(bits)

    def _refresh_fb(self) -> None:
        fb = self.backend.framebuffer()
        if fb is None:
            # BOARD now paints its own canvas (UART mirror or checklist hint)
            if hasattr(self.backend, "machine"):
                fb = self.backend.machine.canvas
            else:
                return
        rgb = fb.front_rgb_preview()
        # In-memory PPM — avoid ~900KB disk write every frame (FPGA-SIM lag)
        header = f"P6\n{WIDTH} {HEIGHT}\n255\n".encode("ascii")
        data = header + rgb
        if data == self._ppm_bytes:
            return
        self._ppm_bytes = data
        try:
            self.photo.configure(data=data, format="PPM")
        except tk.TclError:
            pass

    def _frame(self) -> None:
        # One tick only (SimBackend.frame_tick does TICK; poll is a no-op)
        self.backend.frame_tick()
        # NEW: blink cyan block on letterbox so you can see the insert point
        now = time.monotonic()
        blink_flip = False
        if now - self._cursor_t >= 0.5:
            self._cursor_on = not self._cursor_on
            self._cursor_t = now
            blink_flip = True
        if not self._is_running():
            prompt = f"> {self.line_buf}"
            if hasattr(self.backend, "paint_prompt"):
                if self._last_prompt != prompt or blink_flip:
                    self.backend.paint_prompt(prompt, cursor_on=self._cursor_on)
                    self._last_prompt = prompt
        self._refresh_fb()
        self.status.configure(text=self._status_text())
        self.root.after(FRAME_MS, self._frame)

    def run(self) -> None:
        self.root.mainloop()
        for b in self.backends:
            b.shutdown()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="JMR JS Computer GUI")
    parser.parse_args(argv)
    App().run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
