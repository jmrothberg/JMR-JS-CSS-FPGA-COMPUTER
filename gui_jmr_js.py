#! /usr/bin/env python3
"""Graphical host for the JMR JS Computer — single 640×480 glass.

Pattern cite: JMR-BASIC-FPGA-COMPUTER/gui_jmr.py — one phosphor for console+program.
Monitor text and Canvas games share the same framebuffer. No separate Text console.

  python3 gui_jmr_js.py

F9 cycles PYTHON → FPGA-SIM → BOARD → (ASIC-SIM later).load 
F10 toggles the Architecture Monitor (JS schematic). Arrows + Space = play.
"""

from __future__ import annotations

import argparse
import collections
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
from gui_arch_monitor import ArchitectureView  # noqa: E402
from runtime.backend import PythonBackend  # noqa: E402

FRAME_MS = 16
DEADZONE = 40

# NEW: Tk keysym → (JS keyCode, JS event.key). The HTML decides bindings —
# this is the raw-keyboard path (Enter starts PACMAN; letters for DONKEY).
_TK_TO_JS = {
    "Return": (13, "Enter"),
    "KP_Enter": (13, "Enter"),
    "space": (32, " "),
    "Left": (37, "ArrowLeft"),
    "Up": (38, "ArrowUp"),
    "Right": (39, "ArrowRight"),
    "Down": (40, "ArrowDown"),
    "BackSpace": (8, "Backspace"),
    "Tab": (9, "Tab"),
    # F-keys forwarded to a running title (run-66 board parity: the PS/2
    # decoder now delivers all F-keys). HTML decides bindings. F12 leaves a
    # running program at the GUI. Esc is machine BREAK.
    "F1": (112, "F1"),
    "F2": (113, "F2"),
    "F3": (114, "F3"),
    "F4": (115, "F4"),
    "F5": (116, "F5"),
    "F6": (117, "F6"),
    "F7": (118, "F7"),
    "F8": (119, "F8"),
    "F11": (122, "F11"),
    "Shift_L": (16, "Shift"),
    "Shift_R": (16, "Shift"),
    "Control_L": (17, "Control"),
    "Control_R": (17, "Control"),
}


def apply_line_key(buf: str, col: int, keysym: str, char: str = "") -> tuple[str, int]:
    """Monitor line editor: Left/Right move an insert index; Backspace deletes there."""
    col = max(0, min(int(col), len(buf)))
    if keysym == "Left":
        return buf, max(0, col - 1)
    if keysym == "Right":
        return buf, min(len(buf), col + 1)
    if keysym == "BackSpace":
        if col <= 0:
            return buf, 0
        return buf[: col - 1] + buf[col:], col - 1
    if char and char.isprintable():
        return buf[:col] + char + buf[col:], col + 1
    return buf, col


# GUI → editor paste. KEYEVT is an 8-bit keyCode (FPGA-SIM FIFO is 8 deep,
# one event per VM frame). F2=113 is also ASCII 'q', so the editor arms a
# paste window on F6 and disarms on F7; bytes 32-126 are then SOURCE, not
# function keys. No RTL: this is the existing key_event tether.
_PASTE_BEGIN = 117  # F6
_PASTE_END = 118    # F7
_PASTE_MAX = 65536  # SOURCE_MAX


def clip_to_editor_keys(clip: str) -> list[int]:
    """Clipboard text → editor keyCodes. Newline=Enter; tab=two spaces; ASCII 32-126."""
    keys: list[int] = []
    text = clip.replace("\r\n", "\n").replace("\r", "\n")
    for ch in text:
        if ch == "\n":
            keys.append(13)
        elif ch == "\t":
            keys.append(32)
            keys.append(32)
        else:
            o = ord(ch)
            if 32 <= o < 127:
                keys.append(o)
        if len(keys) >= _PASTE_MAX:
            break
    return keys


def _js_key(event: tk.Event) -> tuple[int, str] | None:
    """Tk keysym → (JS keyCode, event.key). HTML decides bindings."""
    ks = event.keysym
    if ks in _TK_TO_JS:
        return _TK_TO_JS[ks]
    ch = getattr(event, "char", "") or ""
    if len(ks) == 1 and ks.isalpha():
        return (ord(ks.upper()), ch if ch else ks)
    if len(ks) == 1:
        return (ord(ks), ch if ch else ks)
    if len(ch) == 1 and ch.isprintable():
        return (ord(ch.upper()) if ch.isalpha() else ord(ch), ch)
    return None


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
        self._alive = True
        self._after_id: str | None = None
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
        self.line_col = 0
        self._fire1 = False
        self._fire2 = False
        self._key_left = False
        self._key_right = False
        self._key_up = False
        self._key_down = False
        self._key_fire = False
        # NEW: real-time key display + capture (2026-08-29 — diagnosing
        # whether X11 auto-repeat masquerades as distinct keydowns; the
        # keysym-already-down check works because this desktop runs
        # detectable autorepeat — see on_key_release's existing note).
        self._keys_down: set[str] = set()
        self._key_trace: collections.deque = collections.deque(maxlen=200)
        self._key_repeat_total = 0
        self._last_key_event: tuple | None = None  # (t, keysym, down, repeat)
        # Last GUI keystroke (monotonic) — feeds the Architecture Monitor's
        # Keyboard/PHY_PS2 block so it blinks on real input instead of never
        # (the RTL's own S_KEYEV dispatch state is one board V-line sample
        # in ~0.67s away from being caught). Semantic matches the board's
        # K-line: connector-level activity, any key except GUI chrome
        # (F9/F10). BOARD adds its own stamp from tether K-lines — the
        # board keyboard never passes through the GUI (merge takes newest).
        self._kbd_last_t: float | None = None
        self._ppm_bytes: bytes | None = None
        # NEW: letterbox cursor blink (~2 Hz) — HDMI already blinks via frame_div[5]
        self._cursor_on = True
        self._cursor_t = time.monotonic()
        self._last_prompt: str | None = None
        self._busy_prompt: str | None = None  # keep typed RUN/LIST until LINE returns
        self._arch_phase_override: str | None = None
        # NEW: ignore leftover F9/F10 from the launch key queue / auto-repeat.
        self._gui_t0 = time.monotonic()
        self._fkey_t = 0.0
        # GUI Ctrl-V → editor: keyCodes drip-fed before each frame_tick.
        self._paste_q: collections.deque[int] = collections.deque()

        self._build_ui()
        # MORE waiter: pump Tk + refresh glass (BASIC more_idle pattern)
        self.machine.more_idle = self._more_idle
        for b in self.backends:
            # 2026-09-04: BOARD too — its SAVE/PUT waits used to block Tk
            if getattr(b, "name", "") in ("FPGA-SIM", "BOARD"):
                b.run_wait_idle = self._more_idle

        # bind_all so arrows work even if focus is weird (no Text widget to steal them)
        self.root.bind_all("<KeyPress>", self.on_key_press)
        self.root.bind_all("<KeyRelease>", self.on_key_release)
        # Paste like BASIC GUI (Ctrl-V / <<Paste>>). No Super-v — Linux Tk rejects it.
        self.root.bind_all("<<Paste>>", self.on_paste)
        self.root.bind_all("<Control-v>", self.on_paste)
        self.root.bind_all("<Control-V>", self.on_paste)
        # F8=put / F9=runtime / F10=monitor are GUI chrome at READY
        # (KeyRelease, so X11 auto-repeat cannot fire them). While a
        # title runs, F8 stays a TITLE key (on_key_press F1–F11 group).
        # NEW: mouse stick OFF — click only focuses glass (no JOY overwrite of KEYBITS)
        self.canvas_label.bind("<Button-1>", lambda e: self.canvas_label.focus_set())
        # KeyRelease: X11 auto-repeat is extra KeyPress only. A held F9 used
        # to PYTHON→FPGA-SIM→BOARD in one tap. bind_all covers the arch window.
        self.root.bind_all("<KeyRelease-F8>", self.on_put_file)
        self.root.bind_all("<KeyRelease-F9>", self.cycle_runtime)
        self.root.bind_all("<KeyRelease-F10>", self._toggle_arch_monitor)
        self.root.bind_all("<Escape>", lambda e: self.break_program())

        self.machine.paint_monitor("> ")
        self._refresh_fb()
        self.canvas_label.focus_set()
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)
        # NEW: size once. Status/log text must never grow the window or the
        # 640×480 glass (Enter / F9 / LOADING used to widen the alleys).
        self.root.update_idletasks()
        gw = self.root.winfo_reqwidth()
        gh = self.root.winfo_reqheight()
        self.root.geometry(f"{gw}x{gh}")
        self.root.minsize(gw, gh)
        self.root.maxsize(gw, gh)
        self.root.resizable(False, False)
        self._status_shown = None
        self._set_status(self._status_text())
        self._key_status_shown = None
        self._set_key_status(self._key_status_text())
        # NEW: Architecture Monitor is a second window (does not grow the glass)
        self._build_arch_monitor()
        self._after_id = self.root.after(FRAME_MS, self._frame)

    def _build_ui(self) -> None:
        self.status = tk.Label(
            self.root,
            text=self._status_text(),
            fg="#c0ffc0",
            bg="#1a1a1a",
            anchor="w",
            font=("Courier", 11),
            width=80,
        )
        self.status.pack(fill=tk.X, padx=6, pady=4)

        # NEW: real-time key state readout, same fixed-width discipline as
        # `status` — must never grow the window (geometry is locked right
        # after _build_ui in __init__).
        self.key_status = tk.Label(
            self.root,
            text=self._key_status_text(),
            fg="#ffe08a",
            bg="#1a1a1a",
            anchor="w",
            font=("Courier", 11),
            width=80,
        )
        self.key_status.pack(fill=tk.X, padx=6, pady=(0, 4))

        self.photo = tk.PhotoImage(width=WIDTH, height=HEIGHT)
        self.canvas_label = tk.Label(
            self.root, image=self.photo, bg="#000", takefocus=1,
            width=WIDTH, height=HEIGHT,
        )
        self.canvas_label.pack(padx=6, pady=4)

        self.hint = tk.Label(
            self.root,
            text="F8=put  F9=runtime  F10=monitor  ESC=break  F12=leave  Ctrl-V paste  arrows+space=play  type+Enter",
            fg="#888",
            bg="#1a1a1a",
            anchor="w",
            width=80,
        )
        self.hint.pack(fill=tk.X, padx=6, pady=2)
        self._hint_keys = self.hint.cget("text")

    def _build_arch_monitor(self) -> None:
        """Second window: JS Architecture Monitor (F10 hide/show)."""
        self.arch_window = tk.Toplevel(self.root)
        self.arch_window.title("JMR ARCHITECTURE MONITOR")
        self.arch_window.configure(bg="#0d0f0d")
        self.arch = ArchitectureView(self.arch_window)
        # NEW: X hides (does not quit the glass). bind_all F10 already covers focus.
        self.arch_window.protocol("WM_DELETE_WINDOW", self._hide_arch_monitor)
        # F9/F10: bind_all KeyRelease already covers this toplevel.
        self.arch_window.bind("<Escape>", lambda e: self.break_program())
        self._place_arch_window()
        try:
            self.root.lift()
            self.canvas_label.focus_set()
        except tk.TclError:
            pass
        self._update_arch_monitor()

    def _place_arch_window(self) -> None:
        """Put the monitor to the right of the locked 640×480 glass."""
        try:
            self.root.update_idletasks()
            self.arch_window.update_idletasks()
            gap = 8
            x0 = int(self.root.winfo_x())
            y0 = int(self.root.winfo_y())
            gw = int(self.root.winfo_width())
            self.arch_window.geometry(f"+{x0 + gw + gap}+{y0}")
        except tk.TclError:
            pass

    def _arch_visible(self) -> bool:
        try:
            return (
                self.arch_window.winfo_exists()
                and self.arch_window.state() != "withdrawn"
            )
        except tk.TclError:
            return False

    def _hide_arch_monitor(self) -> None:
        try:
            self.arch_window.withdraw()
        except tk.TclError:
            pass
        try:
            self.hint.configure(text="Architecture Monitor hidden · F10 to show")
        except tk.TclError:
            pass

    def _show_arch_monitor(self) -> None:
        try:
            self.arch_window.deiconify()
            self.arch_window.lift()
            self._place_arch_window()
            self.hint.configure(text=self._hint_keys)
        except tk.TclError:
            pass

    def _toggle_arch_monitor(self, _event=None) -> str:
        if not self._fkey_ok():
            return "break"
        if self._arch_visible():
            self._hide_arch_monitor()
        else:
            self._show_arch_monitor()
        return "break"

    def _fkey_ok(self) -> bool:
        """One F-key per physical press. Drop launch-queue and auto-repeat."""
        now = time.monotonic()
        if now - getattr(self, "_gui_t0", now) < 0.40:
            return False
        if now - getattr(self, "_fkey_t", 0.0) < 0.25:
            return False
        self._fkey_t = now
        return True

    def _update_arch_monitor(self) -> None:
        if not self._arch_visible():
            return
        snap = {}
        getter = getattr(self.backend, "arch_snapshot", None)
        if callable(getter):
            try:
                snap = getter() or {}
            except Exception:
                snap = {}
        # NEW: real keystrokes reaching the machine — lights the
        # Keyboard/PHY_PS2 block the same way every other engine block
        # lights (gui_arch_monitor.py's heat_stamp/decay), instead of
        # relying on catching the RTL's one-cycle S_KEYEV dispatch state
        # on a coarse board heartbeat. Newest evidence wins: the backend
        # may already carry its own stamp (BOARD sets kbd_last_t from
        # tether K-lines — the board keyboard never passes through the
        # GUI, so neither side alone covers both input paths).
        backend_t = snap.get("kbd_last_t")
        backend_t = backend_t if isinstance(backend_t, (int, float)) else None
        gui_t = self._kbd_last_t
        newest = max(t for t in (backend_t, gui_t) if t is not None) \
            if (backend_t is not None or gui_t is not None) else None
        if newest is not None:
            snap["kbd_last_t"] = newest
        override = getattr(self, "_arch_phase_override", None)
        if override:
            snap["phase"] = override
            if override == "load":
                snap["sname"] = "LOAD"
            elif override == "compile":
                snap["sname"] = "COMPILE"
        # Peeks are pull-only: the monitor calls this just while a drill-down
        # is open, so a closed inspector costs no extra RPC during play.
        self.arch.update(
            runtime=self.backend.name,
            snap=snap,
            line_buf=self.line_buf,
            peek=getattr(self.backend, "arch_peek", None),
            decode=getattr(self.backend, "arch_decode", None),
        )

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

    def _set_status(self, text: str) -> None:
        # NEW: truncate inside a fixed-width label — never wrap (height) or
        # grow (width). Courier width=80 chars matches the 640 glass.
        max_ch = 80
        if len(text) > max_ch:
            text = text[: max_ch - 1] + "…"
        if text == getattr(self, "_status_shown", None):
            return
        self._status_shown = text
        try:
            self.status.configure(text=text)
        except tk.TclError:
            pass

    def _log_key_event(self, event: tk.Event, down: bool, repeat: bool) -> None:
        """Capture: every keydown/keyup, tagged with X11-autorepeat detection.

        Written to the active backend's flight log (same file the V/F/T-line
        fault forensics land in) so a held-key storm can be lined up against
        a board fault by timestamp after the fact.
        """
        jk = _js_key(event)
        code, key = jk if jk is not None else (None, event.keysym)
        t = time.monotonic() - self._gui_t0
        self._last_key_event = (t, event.keysym, down, repeat)
        self._key_trace.append(self._last_key_event)
        log = getattr(self.backend, "_log", None)
        if log is not None:
            try:
                log.note(
                    f"KEY {'DOWN' if down else 'UP'} keysym={event.keysym} "
                    f"jscode={code} key={key!r} repeat={repeat} t={t:.3f}"
                )
            except Exception:
                pass

    def _key_status_text(self) -> str:
        held = " ".join(sorted(self._keys_down)) or "(none)"
        last = self._last_key_event
        if last is None:
            last_str = "(none yet)"
        else:
            t, keysym, down, repeat = last
            last_str = f"{keysym} {'DOWN' if down else 'UP'}{' REPEAT' if repeat else ''} t=+{t:.2f}s"
        return f"KEYS held:[{held}]  last:{last_str}  repeats={self._key_repeat_total}"

    def _set_key_status(self, text: str) -> None:
        max_ch = 80
        if len(text) > max_ch:
            text = text[: max_ch - 1] + "…"
        if text == getattr(self, "_key_status_shown", None):
            return
        self._key_status_shown = text
        try:
            self.key_status.configure(text=text)
        except tk.TclError:
            pass

    def _is_running(self) -> bool:
        """Game owns the glass — PYTHON loop / last frame or FPGA-SIM game_mode.

        MORE paging is console, not a running game — Enter must type_line / page.
        """
        if getattr(self.backend, "running", False):
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
        if not self._alive:
            return
        try:
            # Re-stamp typed RUN/LIST if SCREEN? wiped the letterbox mid-LINE.
            if getattr(self, "_busy_prompt", None) and hasattr(self.backend, "paint_prompt"):
                if not getattr(self.backend, "running", False) and not getattr(
                    self.backend, "more_waiting", False
                ):
                    self.backend.paint_prompt(self._busy_prompt, cursor_on=False)
            self._refresh_fb()
            self.root.update()
            self._update_arch_monitor()
        except tk.TclError:
            self._alive = False
            return
        time.sleep(0.01)

    def cycle_runtime(self, _event=None) -> str:
        if not self._fkey_ok():
            return "break"
        old = self.backend
        self.backend_index = (self.backend_index + 1) % len(self.backends)
        self.backend = self.backends[self.backend_index]
        if old.name == "FPGA-SIM":
            old.shutdown()
        if self.backend.name == "FPGA-SIM":
            self.backend._started = False
            self.backend._proc = None
        # NEW: every runtime owns its own glass. The half-typed line belongs to
        # the machine you just left, so it must not follow you across F9.
        self.line_buf = ""
        self.line_col = 0
        self._busy_prompt = None
        self._last_prompt = None
        self._ppm_bytes = None
        self._paste_q.clear()
        self._set_status(self._status_text())
        self._paint_prompt()
        self.canvas_label.focus_set()
        return "break"

    def break_program(self) -> None:
        if not self._fkey_ok():
            return
        m = getattr(self.backend, "machine", self.machine)
        m.push_key("\x1b")
        self.backend.hard_break()
        self.line_buf = ""
        self.line_col = 0
        self._paste_q.clear()
        self._paint_prompt()
        self.canvas_label.focus_set()

    def leave_program(self) -> None:
        """F3 / unused F-keys: stop the title and restore READY, no ^BREAK."""
        if not self._fkey_ok():
            return
        hb = self.backend.hard_break
        try:
            hb(quiet=True)
        except TypeError:
            hb()
        self.line_buf = ""
        self.line_col = 0
        self._paste_q.clear()
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

    def _editor_accepts_paste(self) -> bool:
        """True while EDIT owns the glass (PYTHON _edit_active / FPGA-SIM _editor_live)."""
        if getattr(self.backend, "_editor_live", False):
            return True
        m = getattr(self.backend, "machine", None)
        return bool(m is not None and getattr(m, "_edit_active", False))

    def _queue_editor_paste(self, clip: str) -> None:
        keys = clip_to_editor_keys(clip)
        if not keys:
            return
        if not self._paste_q:
            self._paste_q.append(_PASTE_BEGIN)
        elif self._paste_q[-1] == _PASTE_END:
            self._paste_q.pop()
        self._paste_q.extend(keys)
        self._paste_q.append(_PASTE_END)

    def _feed_editor_paste(self) -> None:
        """Push queued paste keyCodes before this frame's rAF. PYTHON drains
        the whole input queue per tick; FPGA-SIM KEYEVT FIFO is 8 and one
        event per FRAME — so one code per GUI tick there."""
        if not self._paste_q:
            return
        if not self._editor_accepts_paste():
            self._paste_q.clear()
            return
        ke = getattr(self.backend, "key_event", None)
        if ke is None:
            self._paste_q.clear()
            return
        n = 64 if getattr(self.backend, "name", "") == "PYTHON" else 1
        i = 0
        while i < n and self._paste_q:
            code = self._paste_q.popleft()
            ch = chr(code) if 32 <= code < 127 else ""
            ke(code, ch, True)
            i += 1

    def on_paste(self, _event: tk.Event | None = None) -> str:
        """Insert clipboard into the monitor line, or into EDIT via key_event."""
        try:
            clip = self.root.clipboard_get()
        except tk.TclError:
            return "break"
        if not clip:
            return "break"
        if self._editor_accepts_paste():
            self._queue_editor_paste(clip)
            return "break"
        m = getattr(self.backend, "machine", self.machine)
        if m.running and (m._loop_chunk is not None or getattr(m, "html_host", None) is not None):
            return "break"
        clip = clip.replace("\r\n", "\n").replace("\r", "\n")
        parts = clip.split("\n")
        for i, part in enumerate(parts):
            last = i == len(parts) - 1
            col = getattr(self, "line_col", len(self.line_buf))
            self.line_buf = self.line_buf[:col] + part + self.line_buf[col:]
            self.line_col = col + len(part)
            if not last:
                line = self.line_buf
                self.line_buf = ""
                self.line_col = 0
                self.backend.type_line(line)
                self._after_command()
        self._paint_prompt()
        self.canvas_label.focus_set()
        return "break"

    def _ask_put_source(self) -> str | None:
        """F8: host file vs card.img. Returns 'host', 'card', or None."""
        win = tk.Toplevel(self.root)
        win.title("Send to card")
        win.transient(self.root)
        win.resizable(False, False)
        result: dict = {"v": None}

        def pick(v: str | None) -> None:
            result["v"] = v
            win.destroy()

        tk.Label(win, text="Where is the file?", padx=12, pady=8).pack()
        tk.Button(win, text="Host file (storage/ …)", command=lambda: pick("host")).pack(
            fill=tk.X, padx=12, pady=2
        )
        tk.Button(win, text="card.img  (HTML / ART / JSH)", command=lambda: pick("card")).pack(
            fill=tk.X, padx=12, pady=2
        )
        tk.Button(win, text="Cancel", command=lambda: pick(None)).pack(
            fill=tk.X, padx=12, pady=(2, 8)
        )
        win.grab_set()
        self.root.wait_window(win)
        return result["v"]

    def _ask_card_names(self) -> list:
        """Pick HTML/ART/JSH already on card.img (storage/ has no .JSH)."""
        from tools.make_sd_image import card_html_sidecars, list_card_put_files

        rows = list_card_put_files()
        if not rows:
            from tkinter import messagebox
            messagebox.showerror("Send to card", "card.img has no HTML/ART/JSH", parent=self.root)
            return []
        win = tk.Toplevel(self.root)
        win.title("card.img")
        win.transient(self.root)
        chosen: list = []
        tk.Label(
            win,
            text="Shift/Ctrl click. HTML also takes .ART + .JSH.",
            padx=8, pady=4,
        ).pack()
        lb = tk.Listbox(win, selectmode=tk.EXTENDED, width=36, height=min(18, len(rows)))
        for name, size in rows:
            lb.insert(tk.END, f"{name:12s}  {size}")
        lb.pack(fill=tk.BOTH, expand=True, padx=8, pady=4)

        def ok() -> None:
            avail = {n for n, _ in rows}
            seen: set[str] = set()
            for i in lb.curselection():
                name = rows[int(i)][0]
                if name not in seen:
                    chosen.append(name)
                    seen.add(name)
                for side in card_html_sidecars(name, avail):
                    if side not in seen:
                        chosen.append(side)
                        seen.add(side)
            win.destroy()

        tk.Button(win, text="Send", command=ok).pack(pady=(0, 8))
        win.grab_set()
        self.root.wait_window(win)
        return chosen

    def on_put_file(self, _event: tk.Event | None = None) -> str:
        """F8: pick storage/ or card.img files → host card.img (+ BOARD SAVE)."""
        from tkinter import filedialog, messagebox

        if self._is_running():
            return "break"
        src = self._ask_put_source()
        if not src:
            return "break"
        try:
            if src == "card":
                names_in = self._ask_card_names()
                if not names_in:
                    return "break"
                putc = getattr(self.backend, "put_card_names", None)
                names = putc(names_in) if callable(putc) else ""
            else:
                paths = filedialog.askopenfilenames(
                    parent=self.root,
                    title="Send host file to card",
                    initialdir=str(ROOT / "storage"),
                    filetypes=[
                        ("HTML / JSH / ART", "*.HTML *.HTM *.JS *.JSH *.ARTX *.ART"),
                        ("All files", "*"),
                    ],
                )
                if not paths:
                    return "break"
                put = getattr(self.backend, "put_files_on_card", None)
                names = put(list(paths)) if callable(put) else ""
            self._set_status(f"PUT {names}")
            self.backend.type_line("DIR *")
            self._after_command()
        except Exception as e:
            try:
                messagebox.showerror("Send to card", str(e), parent=self.root)
            except tk.TclError:
                self._set_status(f"PUT ERR {e}")
        return "break"

    def on_key_press(self, event: tk.Event) -> str | None:
        # NEW: real-time capture, before any early return, so nothing is
        # missed. This desktop runs detectable X11 autorepeat (see
        # on_key_release below) — a held key resends KeyPress with no
        # KeyRelease in between, so "keysym already in _keys_down" IS the
        # repeat signal; no timestamp trick needed.
        is_repeat = event.keysym in self._keys_down
        if is_repeat:
            self._key_repeat_total += 1
        else:
            self._keys_down.add(event.keysym)
        self._log_key_event(event, down=True, repeat=is_repeat)
        self._set_key_status(self._key_status_text())
        # Keyboard-block heat: same semantic as the board's K-line (any
        # scancode on the connector, even a bare Shift). F8/F9/F10 are GUI
        # chrome at READY, not machine input; Escape IS (break_program).
        # F8 while a title runs is a TITLE key (F1–F11 group below).
        if event.keysym not in ("F9", "F10") and not (
            event.keysym == "F8" and not self._is_running()
        ):
            self._kbd_last_t = time.monotonic()
        if event.keysym in ("F9", "F10", "Escape"):
            return None
        if event.keysym == "F8" and not self._is_running():
            return "break"  # put on KeyRelease-F8, like F9
        # F12 leaves a running program (READY). Every other F-key is a
        # TITLE key while running (HTML decides bindings — board parity
        # with the run-66 PS/2 map). F9/F10 are GUI chrome.
        if event.keysym == "F12":
            if self._is_running():
                self.leave_program()
            return "break"
        if event.keysym in ("F1", "F3", "F4", "F5", "F6", "F7", "F8", "F11"):
            if self._is_running():
                jk = _js_key(event)
                if jk is not None and hasattr(self.backend, "key_event"):
                    self.backend.key_event(jk[0], jk[1], True)
            return "break"
        # Ctrl/Cmd+V handled by on_paste binds — do not also type 'v'
        state = int(getattr(event, "state", 0) or 0)
        if (state & 0x4) or (state & 0x40):  # Control or Mod4/Super
            if event.keysym.lower() == "v":
                return self.on_paste(event)
            return "break"
        # NEW: game running → forward the RAW key (JS keyCode/key) to the
        # runtime key-state engine. The HTML decides bindings (Enter starts
        # PACMAN); KEYBITS below stays as the joy tether.
        if self._is_running():
            jk = _js_key(event)
            if jk is not None and hasattr(self.backend, "key_event"):
                self.backend.key_event(jk[0], jk[1], True)
        # Play keys only while a game is running (or MORE paging).
        # At the monitor prompt, Left/Right move the insert cursor.
        playing = self._is_running()
        if event.keysym == "Left":
            if playing:
                self._key_left = True
                self._emit_keys()
                self._feed_more(" ")
            else:
                self.line_buf, self.line_col = apply_line_key(
                    self.line_buf, self.line_col, "Left"
                )
                self._paint_prompt()
            return "break"
        if event.keysym == "Right":
            if playing:
                self._key_right = True
                self._emit_keys()
                self._feed_more(" ")
            else:
                self.line_buf, self.line_col = apply_line_key(
                    self.line_buf, self.line_col, "Right"
                )
                self._paint_prompt()
            return "break"
        if event.keysym == "Up":
            if playing:
                self._key_up = True
                self._emit_keys()
            return "break"
        if event.keysym == "Down":
            if playing:
                self._key_down = True
                self._emit_keys()
            return "break"
        if event.keysym == "space":
            # Prompt Space is a command character, not FIRE. Emitting
            # KEYBITS here queued keydown 32 into the first game frame.
            if playing:
                self._key_fire = True
                self._emit_keys()
            self._feed_more(" ")
            m = getattr(self.backend, "machine", None)
            if m is not None and m.running:
                return "break"
            if self._is_running():
                return "break"
            self.line_buf, self.line_col = apply_line_key(
                self.line_buf, self.line_col, "space", " "
            )
            self._paint_prompt()
            return "break"
        if self._is_running():
            return "break"

        if event.keysym in ("Return", "KP_Enter"):
            if getattr(self.backend, "more_waiting", False):
                self._feed_more("\r")
                return "break"
            self._feed_more("\r")
            line = self.line_buf
            up = line.strip().upper()
            busy = (
                up == "RUN"
                or up.startswith("RUN ")
                or up.startswith("LOAD")
                or up == "LIST"
                or up.startswith("LIST")
                or up == "COMPILE"
                or up == "EDIT"
            )
            if busy:
                # RTL already echoes the typed line on glass. Overlaying
                # WORKING on that same row wiped RUN, then READY cleared
                # both. Keep the echoed command; status bar says compiling.
                self._busy_prompt = f"> {line}"
                if up.startswith("LOAD"):
                    self._arch_phase_override = "load"
                elif up == "RUN" or up.startswith("RUN "):
                    self._arch_phase_override = "compile"
                if hasattr(self.backend, "paint_prompt"):
                    self.backend.paint_prompt(self._busy_prompt, cursor_on=False)
                else:
                    self.machine.paint_monitor(self._busy_prompt, cursor_on=False)
                self._refresh_fb()
            self.line_buf = ""
            self.line_col = 0
            # NEW: fat LOAD/RUN must not freeze the window (swallows Enter)
            if up == "RUN" or up.startswith("RUN ") or up.startswith("LOAD"):
                try:
                    self._set_status(self._status_text() + "  LOADING/COMPILING")
                    self._update_arch_monitor()
                    self.root.update_idletasks()
                except tk.TclError:
                    pass
            self.backend.type_line(line)
            self._arch_phase_override = None
            self._busy_prompt = None
            self._after_command()
            return "break"
        if event.keysym == "BackSpace":
            self.line_buf, self.line_col = apply_line_key(
                self.line_buf, self.line_col, "BackSpace"
            )
            self._paint_prompt()
            return "break"
        ch = event.char
        if ch and ch.isprintable():
            self.line_buf, self.line_col = apply_line_key(
                self.line_buf, self.line_col, "char", ch
            )
            self._paint_prompt()
            return "break"
        return None

    def on_key_release(self, event: tk.Event) -> str | None:
        # NEW: real-time capture (see on_key_press). Detectable autorepeat
        # means this fires exactly once per physical release, never
        # mid-hold — so no repeat filtering needed on the release side.
        self._keys_down.discard(event.keysym)
        self._log_key_event(event, down=False, repeat=False)
        self._set_key_status(self._key_status_text())
        if event.keysym not in ("F8", "F9", "F10"):
            self._kbd_last_t = time.monotonic()
        if event.keysym in ("F9", "F10", "Escape"):
            return None
        if event.keysym == "F12":
            return "break"
        if event.keysym == "F8" and not self._is_running():
            return "break"  # KeyRelease-F8 → on_put_file
        if event.keysym in ("F1", "F3", "F4", "F5", "F6", "F7", "F8", "F11"):
            if self._is_running():
                jk = _js_key(event)
                if jk is not None and hasattr(self.backend, "key_event"):
                    self.backend.key_event(jk[0], jk[1], False)
            return "break"
        # NEW: raw keyup twin of the on_key_press key_event forward
        if self._is_running():
            jk = _js_key(event)
            if jk is not None and hasattr(self.backend, "key_event"):
                self.backend.key_event(jk[0], jk[1], False)
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
            self.line_col = len(pref)
        # NEW: LOAD/RUN can outlive the window (DONKEY compile); skip
        # focus if the user already closed Tk.
        if not self._alive:
            return
        try:
            self._paint_prompt()
            self.canvas_label.focus_set()
        except tk.TclError:
            return
        self._refresh_fb()
        self._update_arch_monitor()

    def _paint_prompt(self) -> None:
        if self._is_running():
            return
        if getattr(self.backend, "more_waiting", False):
            return
        if getattr(self, "_busy_prompt", None):
            prompt = self._busy_prompt
            if hasattr(self.backend, "paint_prompt"):
                self.backend.paint_prompt(prompt, cursor_on=False)
            else:
                self.machine.paint_monitor(prompt, cursor_on=False)
            self._last_prompt = prompt
            self._refresh_fb()
            return
        m = getattr(self.backend, "machine", self.machine)
        prompt = self._prompt_text()
        col = max(0, min(getattr(self, "line_col", len(self.line_buf)), len(self.line_buf)))
        # NEW: cyan block at insert index (`> ` is 2 cols) — no yellow '|'
        cc = 2 + col
        if hasattr(self.backend, "paint_prompt"):
            self.backend.paint_prompt(prompt, cursor_on=self._cursor_on, cursor_col=cc)
        else:
            m.paint_monitor(prompt, cursor_on=self._cursor_on, cursor_col=cc)
        self._last_prompt = prompt
        self._refresh_fb()

    def _prompt_text(self) -> str:
        """`> ` + line. Cursor is the cyan block, not a '|' glyph."""
        return f"> {self.line_buf}"

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

    def _on_close(self) -> None:
        # NEW: cancel the after-loop before destroy so Tk does not fire
        # `_frame` / focus on a dead interpreter (close during LOAD/RUN).
        self._alive = False
        if self._after_id is not None:
            try:
                self.root.after_cancel(self._after_id)
            except tk.TclError:
                pass
            self._after_id = None
        try:
            self.root.destroy()
        except tk.TclError:
            pass

    def _frame(self) -> None:
        if not self._alive:
            return
        try:
            # One tick only (SimBackend.frame_tick does TICK; poll is a no-op)
            self._feed_editor_paste()
            self.backend.frame_tick()
            # NEW: blink cyan block on letterbox so you can see the insert point
            now = time.monotonic()
            blink_flip = False
            if now - self._cursor_t >= 0.5:
                self._cursor_on = not self._cursor_on
                self._cursor_t = now
                blink_flip = True
            if getattr(self, "_busy_prompt", None):
                if hasattr(self.backend, "paint_prompt") and (
                    self._last_prompt != self._busy_prompt or blink_flip
                ):
                    self.backend.paint_prompt(self._busy_prompt, cursor_on=False)
                    self._last_prompt = self._busy_prompt
            elif not self._is_running():
                prompt = self._prompt_text()
                col = max(0, min(getattr(self, "line_col", 0), len(self.line_buf)))
                cc = 2 + col
                if hasattr(self.backend, "paint_prompt"):
                    if self._last_prompt != prompt or blink_flip:
                        self.backend.paint_prompt(
                            prompt, cursor_on=self._cursor_on, cursor_col=cc
                        )
                        self._last_prompt = prompt
            self._refresh_fb()
            self._set_status(self._status_text())
            self._set_key_status(self._key_status_text())
            self._update_arch_monitor()
            self._after_id = self.root.after(FRAME_MS, self._frame)
        except tk.TclError as e:
            # dying gasp: a TclError here silently ends the GUI frame loop
            # (frozen GUI, silent flight log) — name it before stopping
            try:
                self.backend._log.fault("GUI_FRAME", repr(e))
            except Exception:
                pass
            self._alive = False
            self._after_id = None

    def run(self) -> None:
        self.root.mainloop()
        self._alive = False
        for b in self.backends:
            b.shutdown()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="JMR JS Computer GUI")
    parser.parse_args(argv)
    App().run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
