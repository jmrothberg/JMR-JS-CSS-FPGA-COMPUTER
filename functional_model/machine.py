"""Top-level machine — PYTHON behavioral truth.

LLM NOTE: Monitor + bytecode + Canvas + INPUT. Engines stay separate modules.
Glass: monitor text and games share the same 640×480 framebuffer (BASIC method).
"""

from __future__ import annotations

from pathlib import Path
from typing import Callable, List, Optional

from .bytecode import VM
from .canvas_engine import CONSOLE_VISIBLE_LINES, FB_BYTES, HEIGHT, WIDTH, CanvasEngine
from .compiler import CompileError, compile_source
from .html_loader import extract_html_program
from .input_engine import InputEngine
from .js_host import HtmlJsHost
from .storage_engine import StorageEngine
from .trace import TraceLog

BANNER = "JMR JS-NATIVE-CPU V0.0.1"
READY = "READY"
# Pattern cite: BASIC LIST_PAGE_LINES / -- MORE --
LIST_PAGE_LINES = 14
# HDMI console: last 16 lines (64-col wrap) — matches RTL char VRAM + board tether
MONITOR_VISIBLE_ROWS = CONSOLE_VISIBLE_LINES


class Machine:
    """JS-native glass host for PYTHON runtime (and GUI PythonBackend)."""

    def __init__(self, storage_root: Optional[Path] = None) -> None:
        self.input = InputEngine()
        self.canvas = CanvasEngine()
        self.storage = StorageEngine(storage_root)
        self.lines_out: List[str] = []
        self.console_log: List[str] = []
        self.source_name: str = "UNTITLED.JS"
        self.source_lines: List[str] = []
        self.running: bool = False
        self._edit_waiting: Optional[int] = None  # display line no. (10,20,…)
        self.vm = VM(natives=self._natives())
        self._loop_chunk = None
        # GUI sets more_idle to pump Tk while LIST waits for MORE.
        self.more_idle: Optional[Callable[[], None]] = None
        self._more_key: Optional[str] = None
        self.prompt_buf: str = ""  # live "> …" shown on glass
        self.break_requested: bool = False
        self.html_host: Optional[HtmlJsHost] = None
        # NEW: one-shot RUN (RECTDEMO) keeps pixels until next command / CLS
        self._keep_fb: bool = False
        # Always-on flight log (BASIC TraceLog method)
        self.trace = TraceLog(self)

    # --- boot / glass -------------------------------------------------

    def boot_lines(self) -> List[str]:
        self.console_log = [BANNER, READY]
        self.paint_monitor()
        self.trace.edge("BOOT", "banner painted")
        return list(self.console_log)

    def screen_text(self) -> str:
        return "\n".join(self.console_log[-40:])

    def _print(self, *parts: str) -> None:
        msg = " ".join(str(p) for p in parts)
        self.lines_out.append(msg)
        self.console_log.append(msg)

    def _ready(self) -> None:
        self.console_log.append(READY)

    def paint_monitor(self, prompt: Optional[str] = None) -> None:
        """Paint console_log + prompt onto FRONT FB (HDMI letterbox — same as SIM/BOARD)."""
        if self.running and (self._loop_chunk is not None or self.html_host is not None):
            return  # game owns the glass
        # NEW: last RUN frame stays until CLS / next typed command
        if self._keep_fb and not self.running:
            return
        if prompt is not None:
            self.prompt_buf = prompt
        pr = self.prompt_buf if self.prompt_buf else "> "
        self.canvas.paint_console_letterbox(
            self.console_log[-MONITOR_VISIBLE_ROWS:],
            prompt=pr,
        )

    # --- INPUT --------------------------------------------------------

    def set_joy(self, bits: int) -> None:
        self.input.set_joy(bits)

    def set_key_bits(self, bits: int) -> None:
        self.input.set_key_bits(bits)

    def push_key(self, ch: str) -> None:
        if ch == "\x1b":
            self.break_requested = True
            self.input.push_key(ch)
            return
        # MORE waiter
        if self._more_key is None and ch:
            self._more_key = ch
        self.input.push_key(ch)

    def hard_break(self) -> None:
        self.running = False
        self._loop_chunk = None
        self._keep_fb = False
        if self.html_host is not None:
            self.html_host.stop()
            self.html_host = None
        self.input.clear_escape()
        self.break_requested = False
        self._print("^BREAK")
        self._ready()
        self.paint_monitor("> ")
        self.trace.edge("BREAK", "hard_break")
        self.trace.dump_ring("BREAK")

    def poll_escape(self) -> bool:
        if self.input.escape_pending or self.break_requested:
            self.hard_break()
            return True
        return False

    # --- monitor ------------------------------------------------------

    def type_line(self, text: str) -> None:
        if self.poll_escape():
            return
        line = text.rstrip("\n")
        # NEW: any new command releases a kept RUN frame
        self._keep_fb = False
        self.trace.edge("LINE", repr(line)[:120])
        self.console_log.append(f"> {line}")
        out = self.execute_line(line)
        for row in out:
            if row != READY:
                self.console_log.append(row)
                if row.startswith("ERROR"):
                    self.trace.edge("ERROR", row[:160])
                    self.trace.dump_ring("ERROR")
        if not self.running:
            self._ready()
            if not self._keep_fb:
                self.paint_monitor("> ")
        else:
            # Game started — leave FB to game after first frame
            self.trace.edge("RUN", f"src={self.source_name!r}")

    def execute_line(self, line: str) -> List[str]:
        text = line.strip()
        if self._edit_waiting is not None:
            return self._finish_edit(text)

        if not text:
            return []

        upper = text.upper()

        if text[0].isdigit():
            parts = text.split(None, 1)
            try:
                n = int(parts[0])
                body = parts[1] if len(parts) > 1 else ""
                return self._replace_editor_line(n, body)
            except ValueError:
                pass

        if upper == "HELP":
            return [
                "DIR LOAD SAVE NEW LIST EDIT INSERT DELETE RUN MEM HELP CLS",
                "LOAD name  or  LOAD n  (n = DIR number); quotes optional",
                "e.g. LOAD INVADERS_FULL.HTML   or   LOAD 3",
                "LIST / LIST -  pages with -- MORE -- (Space/Enter=next Esc=abort)",
                "LIST 10-20  range;  EDIT n  then type new line + Enter",
                "CLS  clears the glass;  Games: arrows + Space, ESC quit",
            ]
        if upper == "DIR":
            names = self.storage.catalog()
            if not names:
                return ["(empty)"]
            return [f"{i}  {name}" for i, name in enumerate(names, 1)]
        if upper.startswith("LOAD"):
            return self._cmd_load(text)
        if upper == "SAVE" or upper.startswith("SAVE "):
            return self._cmd_save(text)
        if upper == "NEW":
            self.source_lines = []
            self.source_name = "UNTITLED.JS"
            return ["OK"]
        # NEW: CLS — clear glass like BASIC (log + FB); type_line adds READY
        if upper == "CLS":
            self.console_log = []
            self._keep_fb = False
            self.canvas.clear(0)
            return []
        if upper == "LIST" or upper.startswith("LIST"):
            return self._cmd_list(text)
        if upper.startswith("EDIT"):
            return self._cmd_edit(text)
        if upper.startswith("INSERT"):
            return self._cmd_insert(text)
        if upper.startswith("DELETE"):
            return self._cmd_delete(text)
        if upper == "RUN" or upper.startswith("RUN "):
            return self._cmd_run(text)
        if upper == "MEM":
            return [
                f"SOURCE LINES {len(self.source_lines)}",
                f"FB {WIDTH}x{HEIGHT} x2 = {FB_BYTES * 2} bytes",
                f"JOY {self.input.play_bits():#04x}",
            ]
        if text.isdigit():
            return self._cmd_run(f"RUN {text}")

        return self._run_source(text)

    @staticmethod
    def _parse_filename(rest: str) -> str:
        """Strip spaces and ASCII/smart quotes from LOAD/SAVE names."""
        s = (rest or "").strip()
        # LLM NOTE: paste from chat often uses U+201C/U+201D curly quotes
        for q in ('"', "'", "\u201c", "\u201d", "\u2018", "\u2019", "`"):
            s = s.strip(q)
        return s.strip()

    def _cmd_load(self, text: str) -> List[str]:
        rest = self._parse_filename(text[4:])
        if not rest:
            return ["ERROR: LOAD NAME"]
        # LOAD n — same index as DIR (1-based)
        if rest.isdigit():
            names = self.storage.catalog()
            i = int(rest) - 1
            if i < 0 or i >= len(names):
                return ["ERROR: NO ENTRY"]
            rest = names[i]
        try:
            raw = self.storage.load_text(rest)
            self.source_name = self.storage.resolve_name(rest)
        except FileNotFoundError:
            return [f"ERROR: FILE NOT FOUND {rest}"]
        self.source_lines = raw.splitlines()
        return [f"LOADED {self.source_name} ({len(self.source_lines)} LINES)"]

    def _cmd_save(self, text: str) -> List[str]:
        rest = self._parse_filename(text[4:])
        name = rest if rest else self.source_name
        body = "\n".join(self.source_lines)
        if body and not body.endswith("\n"):
            body += "\n"
        self.storage.save_text(name, body)
        self.source_name = Path(name).name
        return [f"SAVED {self.source_name}"]

    def _display_num(self, index0: int) -> int:
        return (index0 + 1) * 10

    def _editor_index(self, display_n: int) -> int:
        """10,20,30… → 0-based. Also accept 1..N as 1-based row."""
        if display_n <= 0:
            return -1
        if display_n % 10 == 0:
            return display_n // 10 - 1
        # small integers: treat as 1-based line index
        if display_n < 10 or display_n <= len(self.source_lines):
            return display_n - 1
        return display_n // 10 - 1

    def _replace_editor_line(self, display_n: int, body: str) -> List[str]:
        idx = self._editor_index(display_n)
        if idx < 0:
            return ["ERROR: BAD LINE"]
        while len(self.source_lines) <= idx:
            self.source_lines.append("")
        self.source_lines[idx] = body
        return ["OK"]

    def _cmd_list(self, text: str) -> List[str]:
        """LIST / LIST n-m / LIST - (paged MORE)."""
        rest = text[4:].strip()
        page = False
        start, end = 1, len(self.source_lines)
        if rest == "-" or rest.upper() == "-":
            page = True
        elif rest:
            if rest.endswith("-") and rest[:-1].strip().isdigit():
                start = int(rest[:-1].strip())
                if start >= 10 and start % 10 == 0:
                    start = start // 10
                end = len(self.source_lines)
            elif "-" in rest:
                a, b = rest.split("-", 1)
                a, b = a.strip(), b.strip()
                start = int(a) if a else 1
                end = int(b) if b else len(self.source_lines)
                # display numbers 10,20 → row indices
                if start >= 10 and start % 10 == 0:
                    start = start // 10
                if end >= 10 and end % 10 == 0:
                    end = end // 10
            else:
                n = int(rest)
                if n >= 10 and n % 10 == 0:
                    n = n // 10
                start = end = n
        else:
            # Bare LIST: also page like LIST - (BASIC glass fills then MORE)
            page = True

        if not self.source_lines:
            return ["(empty)"]

        lines: List[str] = []
        for i in range(start, end + 1):
            if 1 <= i <= len(self.source_lines):
                lines.append(f"{self._display_num(i - 1)} {self.source_lines[i - 1]}")

        if not page:
            return lines or ["(empty)"]

        # Paged listing onto glass with -- MORE --
        return self._list_paged(lines)

    def _list_paged(self, lines: List[str]) -> List[str]:
        """Print pages of LIST_PAGE_LINES; wait for key between pages."""
        shown: List[str] = []
        on_page = 0
        for line in lines:
            self._print(line)
            shown.append(line)
            on_page += 1
            self.paint_monitor("> ")
            if on_page >= LIST_PAGE_LINES:
                self._print("-- MORE --")
                self.paint_monitor("")
                if not self._await_list_more():
                    self._print("^BREAK")
                    break
                # remove MORE line from log for cleaner next page
                if self.console_log and self.console_log[-1] == "-- MORE --":
                    self.console_log.pop()
                on_page = 0
        return shown

    def _await_list_more(self) -> bool:
        """True = next page; False = abort (Esc). Pattern cite BASIC MORE."""
        self._more_key = None
        polls = 0
        while True:
            if self.break_requested or self.input.escape_pending:
                self.break_requested = False
                self.input.clear_escape()
                return False
            if self._more_key is not None:
                k = self._more_key
                self._more_key = None
                if k in ("\x1b", "\x03"):
                    return False
                return True
            ch = self.input.pop_key()
            if ch is not None:
                if ch in ("\x1b", "\x03"):
                    return False
                return True
            idle = self.more_idle
            if idle is not None:
                idle()
                continue
            polls += 1
            if polls >= 50:
                return True  # scripts / pytest: auto-continue

    def _cmd_edit(self, text: str) -> List[str]:
        rest = text[4:].strip()
        if not rest:
            return ["ERROR: EDIT N"]
        try:
            n = int(rest.split()[0])
        except ValueError:
            return ["ERROR: EDIT N"]
        # Normalize to display number 10,20,30…
        if n > 0 and n < 10:
            display = n * 10
        elif n % 10 == 0:
            display = n
        else:
            display = n * 10 if n <= len(self.source_lines) else n
        idx = self._editor_index(display)
        if idx < 0 or idx >= len(self.source_lines):
            return ["ERROR: NO LINE"]
        self._edit_waiting = display
        body = self.source_lines[idx]
        return [f"{display} {body}"]

    def edit_prefill(self) -> Optional[str]:
        """Source line text for GUI line_buf when EDIT is waiting."""
        if self._edit_waiting is None:
            return None
        idx = self._editor_index(self._edit_waiting)
        if 0 <= idx < len(self.source_lines):
            return self.source_lines[idx]
        return ""

    def _finish_edit(self, text: str) -> List[str]:
        n = self._edit_waiting or 0
        self._edit_waiting = None
        body = text
        parts = text.split(None, 1)
        if parts and parts[0].isdigit():
            body = parts[1] if len(parts) > 1 else ""
        return self._replace_editor_line(n, body)

    def _cmd_insert(self, text: str) -> List[str]:
        rest = text[6:].strip()
        if not rest:
            return ["ERROR: INSERT N"]
        n = int(rest.split()[0])
        idx = self._editor_index(n if n >= 10 else n * 10)
        idx = max(0, min(idx, len(self.source_lines)))
        self.source_lines.insert(idx, "")
        return ["OK"]

    def _cmd_delete(self, text: str) -> List[str]:
        rest = text[6:].strip()
        if not rest:
            return ["ERROR: DELETE N"]
        n = int(rest.split()[0])
        idx = self._editor_index(n if n >= 10 else n * 10)
        if 0 <= idx < len(self.source_lines):
            del self.source_lines[idx]
            return ["OK"]
        return ["ERROR: NO LINE"]

    def _cmd_run(self, text: str) -> List[str]:
        rest = text[3:].strip()
        if rest.isdigit():
            names = self.storage.catalog()
            i = int(rest) - 1
            if i < 0 or i >= len(names):
                return ["ERROR: NO ENTRY"]
            load_out = self._cmd_load(f"LOAD {names[i]}")
            if load_out and load_out[0].startswith("ERROR"):
                return load_out
        src = "\n".join(self.source_lines)
        if not src.strip():
            return ["ERROR: NO PROGRAM"]
        # HTML Canvas games → dukpy host (FM). Simple .JS → bytecode VM.
        name_u = self.source_name.upper()
        if name_u.endswith(".HTML") or name_u.endswith(".HTM") or "<canvas" in src.lower():
            return self._run_html(src)
        return self._run_source(src)

    def _run_html(self, html: str) -> List[str]:
        base = self.storage.root
        # If source was loaded from a subfolder name, still resolve scripts from storage/
        try:
            self.html_host = HtmlJsHost(self.canvas, self.input)
            # Prefer games_invaders as base when loading INVADERS_FULL
            from pathlib import Path as P

            base_dir = base
            if "INVADERS" in self.source_name.upper():
                cand = base / "games_invaders"
                if cand.is_dir():
                    base_dir = cand
            self.html_host.load_html(html, base_dir=base_dir)
            self.running = True
            self._loop_chunk = None
            return ["HTML GAME RUNNING - arrows + space, ESC quit"]
        except Exception as e:
            self.html_host = None
            self.running = False
            return [f"ERROR: HTML/JS {e}"]

    def _run_source(self, src: str) -> List[str]:
        before = len(self.lines_out)
        try:
            chunk = compile_source(src)
        except CompileError as e:
            where = f" LINE {e.line}" if e.line else ""
            return [f"ERROR{where}: {e.message}"]
        self.running = True
        self.vm.natives = self._natives()
        self.vm.globals.clear()
        self._loop_chunk = None
        self.vm.run(chunk)
        if self.vm.error:
            self.running = False
            self._loop_chunk = None
            return [self.vm.error]
        printed = self.lines_out[before:]
        if self._loop_chunk is not None:
            if not printed:
                return ["GAME RUNNING - arrows + space, ESC quit"]
            return printed
        self.running = False
        return printed

    # --- natives ------------------------------------------------------

    def _natives(self):
        return {
            "console.log": self._nat_log,
            "fillRect": self._nat_fill_rect,
            "clearRect": self._nat_clear_rect,
            "clear": self._nat_clear,
            "swapBuffers": self._nat_swap,
            "setFillStyle": self._nat_fill_style,
            "joy": self._nat_joy,
            "getJoy": self._nat_joy,
            "keyLeft": self._nat_key_left,
            "keyRight": self._nat_key_right,
            "keyFire": self._nat_key_fire,
            "startLoop": self._nat_start_loop,
        }

    def _nat_log(self, *args):
        self._print(*[str(a) for a in args])
        return None

    def _nat_fill_rect(self, x, y, w, h, color=None):
        if color is not None:
            self.canvas.fill_rect(int(x), int(y), int(w), int(h), int(color))
        else:
            self.canvas.fill_rect(int(x), int(y), int(w), int(h))
        return None

    def _nat_clear_rect(self, x, y, w, h):
        self.canvas.clear_rect(int(x), int(y), int(w), int(h))
        return None

    def _nat_clear(self, color=0):
        self.canvas.clear(int(color))
        return None

    def _nat_swap(self):
        self.canvas.swap()
        # NEW: one-shot demos keep pixels after RUN returns to READY
        self._keep_fb = True
        return None

    def _nat_fill_style(self, idx):
        self.canvas.fill_style = int(idx) & 0xFF
        return None

    def _nat_joy(self):
        return self.input.play_bits()

    def _nat_key_left(self):
        from .input_engine import KEY_LEFT

        return 1 if (self.input.play_bits() & KEY_LEFT) else 0

    def _nat_key_right(self):
        from .input_engine import KEY_RIGHT

        return 1 if (self.input.play_bits() & KEY_RIGHT) else 0

    def _nat_key_fire(self):
        from .input_engine import KEY_FIRE

        return 1 if (self.input.play_bits() & KEY_FIRE) else 0

    def _nat_start_loop(self):
        self._loop_chunk = True
        return None

    def frame_tick(self) -> None:
        if self.poll_escape():
            return
        if self.html_host is not None and self.html_host.alive:
            try:
                self.html_host.frame()
            except Exception as e:
                self._print(f"ERROR: JS {e}")
                self.hard_break()
            return
        if not self.running or self._loop_chunk is None:
            return
        src = "\n".join(self.source_lines)
        if not src.strip():
            return
        try:
            chunk = compile_source(src)
        except CompileError:
            return
        self.vm.natives = self._natives()
        self.vm.run(chunk)
        if self.vm.error:
            self._print(self.vm.error)
            self.running = False
            self._loop_chunk = None
            self.paint_monitor("> ")
