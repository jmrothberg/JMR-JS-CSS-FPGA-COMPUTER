"""Top-level machine — PYTHON behavioral truth.

LLM NOTE: Monitor + bytecode + Canvas + INPUT. Engines stay separate modules.
Glass: monitor text and games share the same 640×480 framebuffer (BASIC method).
"""

from __future__ import annotations

import time
from pathlib import Path
from typing import Callable, List, Optional

from .bytecode import VM
from .canvas_engine import CONSOLE_VISIBLE_LINES, FB_BYTES, HEIGHT, WIDTH, CanvasEngine
from .compiler import CompileError, compile_source
from .html_loader import extract_html_program
from .input_engine import InputEngine
from .js_host import HtmlJsHost
from .sram_engine import SramEngine
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
        # NEW: external SRAM asset bank model (ASET payload lives here)
        self.sram = SramEngine()
        self._spr_descs: list = []  # (w, h, sram_off) per sprite handle
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
        self._list_more_waiting: bool = False  # NEW: GUI more_waiting / ESC abort
        self.prompt_buf: str = ""  # live "> …" shown on glass
        self.break_requested: bool = False
        self.html_host: Optional[HtmlJsHost] = None
        # NEW: one-shot RUN (RECTDEMO) keeps pixels until next command / CLS
        self._keep_fb: bool = False
        # NEW: bytecode HTML path is bytecode / .JSH (dukpy only if JMR_HTML_DUKPY=1)
        self._bytecode_html: bool = False
        self._html_chunk = None
        self._raf_q: list = []
        self._listeners: list = []
        self._key_prev: int = 0
        self._play_t: float = 0.0
        self._play_frames: int = 0
        # Always-on flight log (BASIC TraceLog method)
        self.trace = TraceLog(self)
        # NEW: Architecture Monitor phase (LOAD vs compile-on-RUN vs execute)
        self._arch_phase: str = "idle"
        self._arch_cmd: str = ""
        # NEW: HTML RUN executes the serialized ProgramImage on the hardware
        # model. The functional Chunk is kept only for Architecture Monitor.
        self._hw_vm = None

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

    def paint_monitor(
        self, prompt: Optional[str] = None, cursor_on: bool = False,
        cursor_col: Optional[int] = None,
    ) -> None:
        """Paint console_log + prompt onto FRONT FB (HDMI letterbox — same as SIM/BOARD)."""
        if self.running and (
            self._loop_chunk is not None
            or self.html_host is not None
            or getattr(self, "_bytecode_html", False)
        ):
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
            cursor_on=cursor_on,
            cursor_col=cursor_col,
        )

    # --- INPUT --------------------------------------------------------

    def set_joy(self, bits: int) -> None:
        self.input.set_joy(bits)

    def set_key_bits(self, bits: int) -> None:
        # KEYBITS→JS only while a game is running. Typing Space in
        # LOAD "NAME.HTML" used to queue keydown 32 into the first rAF.
        self.input.key_bits = int(bits) & 0x3F
        if self.running:
            self.input._sync_play_bits_to_keys()

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
        more_abort = bool(self._list_more_waiting)
        self.running = False
        self._loop_chunk = None
        self._keep_fb = False
        # NEW: clear bytecode-HTML frame state
        self._bytecode_html = False
        self._html_chunk = None
        self._hw_vm = None
        self._raf_q = []
        self._listeners = []
        self._timers = []  # NEW: kill pending setTimeout/setInterval
        if self.html_host is not None:
            self.html_host.stop()
            self.html_host = None
        # NEW: LIST MORE — GUI break_program push_key(ESC) then hard_break.
        # Do not clear the abort the waiter still has to observe.
        if more_abort:
            self.break_requested = True
            if self._more_key is None:
                self._more_key = "\x1b"
        else:
            self.input.clear_escape()
            self.break_requested = False
        self._print("^BREAK")
        self._ready()
        self.paint_monitor("> ")
        # NEW: HTML still in the editor; bytecode chunk was cleared above
        self._arch_phase = "loaded" if self.source_lines else "idle"
        self.trace.edge("BREAK", "hard_break")
        # NEW: one VM telemetry line on BREAK (minimal, no spam)
        self.trace.edge(
            "NOTE",
            "VM raf_n=%s to_n=%s"
            % (
                len(getattr(self, "_raf_q", [])),
                len(getattr(self, "_timers", [])),
            ),
        )
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
        self._arch_cmd = line
        # NEW: any new command releases a kept RUN frame
        self._keep_fb = False
        self.trace.edge("LINE", repr(line)[:120])
        self.console_log.append(f"> {line}")
        out = self.execute_line(line)
        for row in out:
            if row != READY:
                self.console_log.append(row)
                if row.startswith("ERROR") or row.startswith("?SN") or row.startswith("?FN"):
                    self.trace.edge("ERROR", row[:160])
                    self.trace.dump_ring("ERROR")
        # NEW: log glass after DIR/LOAD/LIST/SAVE (not just the typed line)
        u = line.strip().upper()
        if u == "DIR" or u.startswith("LOAD") or u.startswith("SAVE") or u == "LIST" or u.startswith("LIST"):
            glass = " | ".join(x for x in out if x and x != READY)[:400]
            self.trace.edge("GLASS", glass)
            if out and str(out[0]).startswith("LOADED"):
                self.trace.edge("LOADED", out[0][:160])
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
                "LOAD name   quotes optional;  e.g. LOAD INVADERS.HTML",
                'e.g. LOAD INVADERS.JS   or   LOAD "PACMAN.HTML"',
                "LIST / LIST -  pages with -- MORE -- (Space/Enter=next Esc=abort)",
                "LIST 10-20  range;  EDIT n  then type new line + Enter",
                "CLS  clears the glass;  Games: arrows + Space, ESC quit",
            ]
        if upper == "DIR":
            names = self.storage.catalog()
            if not names:
                return ["(empty)"]
            # PYTHON glass spec: names only (no DIR indices). Hide .JSB/.JSH
            # via catalog(). FPGA-SIM DIR must look the same.
            return list(names)
        if upper.startswith("LOAD"):
            return self._cmd_load(text)
        if upper == "SAVE" or upper.startswith("SAVE "):
            return self._cmd_save(text)
        if upper == "NEW":
            self.source_lines = []
            self.source_name = "UNTITLED.JS"
            self._arch_phase = "idle"
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
        if upper.startswith("REMOVE"):
            # NEW: same verb as RTL REMOVE (alias of DELETE)
            return self._cmd_delete("DELETE" + text[6:])
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

        # NEW: bare identifier / unknown verb → ?SN ERROR (laod), not silent JS
        first = text.split(None, 1)[0]
        if first.isidentifier() and first[0].isalpha():
            js_kw = (
                "var", "let", "const", "function", "class", "if", "for",
                "while", "return", "new", "typeof", "void", "async", "await",
            )
            if first.lower() not in js_kw and not any(c in text for c in "()="):
                return ["?SN ERROR"]
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
            return ["?FN FILE NOT FOUND"]
        self.source_lines = raw.splitlines()
        self._arch_phase = "loaded"
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
        """Print pages of LIST_PAGE_LINES glass ROWS; wait for key between pages.

        NEW: pre-wrap each line at the glass width (64 cols) and page by
        wrapped ROWS. A 15K-char data:image line used to wrap to ~245 rows at
        paint time, flooding the whole page past -- MORE -- (INVADERS "LIST
        truncates"; PACMAN pages scrolled their tops off the glass).
        """
        from .canvas_engine import CONSOLE_COLS

        shown: List[str] = []
        on_page = 0
        for line in lines:
            text = line.replace("\t", " ")
            segs = [text[i : i + CONSOLE_COLS] for i in range(0, len(text), CONSOLE_COLS)] or [""]
            for seg in segs:
                self._print(seg)
                on_page += 1
                self.paint_monitor("")  # NEW: no `>` over LIST / MORE
                if on_page >= LIST_PAGE_LINES:
                    self._print("-- MORE --")
                    self.paint_monitor("")
                    if not self._await_list_more():
                        self._print("^BREAK")
                        return shown
                    # remove MORE line from log for cleaner next page
                    if self.console_log and self.console_log[-1] == "-- MORE --":
                        self.console_log.pop()
                    on_page = 0
            shown.append(line)
        return shown

    def _await_list_more(self) -> bool:
        """True = next page; False = abort (Esc). Pattern cite BASIC MORE."""
        self._more_key = None
        self._list_more_waiting = True
        polls = 0
        try:
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
        finally:
            self._list_more_waiting = False

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
        """`N body` in the prompt — same as BASIC EDIT (Enter strips N)."""
        if self._edit_waiting is None:
            return None
        idx = self._editor_index(self._edit_waiting)
        if 0 <= idx < len(self.source_lines):
            return f"{self._edit_waiting} {self.source_lines[idx]}"
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
            if load_out and (
                load_out[0].startswith("ERROR") or load_out[0].startswith("?FN")
            ):
                return load_out
        src = "\n".join(self.source_lines)
        if not src.strip():
            return ["ERROR: NO PROGRAM"]
        # HTML Canvas games → bytecode / .JSH (product). Simple .JS → bytecode VM.
        name_u = self.source_name.upper()
        if name_u.endswith(".HTML") or name_u.endswith(".HTM") or "<canvas" in src.lower():
            return self._run_html(src)
        return self._run_source(src)

    def _run_html(self, html: str) -> List[str]:
        import os

        # Product path: bytecode / .JSH (CONSTITUTION). dukpy is opt-in debug only.
        if os.environ.get("JMR_HTML_DUKPY", "").strip() in ("1", "true", "yes"):
            try:
                self.html_host = HtmlJsHost(self.canvas, self.input)
                # Playable titles are one HTML file (inline JS + data: URIs), same
                # as dropping the file in a browser. Leftover relative src= still
                # resolves next to the HTML (storage/), not a special games_* remap.
                self.html_host.load_html(html, base_dir=self.storage.root)
                self.running = True
                self._loop_chunk = None
                return ["HTML GAME RUNNING - arrows + space, ESC quit"]
            except Exception as e:
                self.html_host = None
                self.running = False
                return [f"ERROR: HTML/JS {e}"]
        return self._run_html_bytecode(html)

    def _run_html_bytecode(self, html: str) -> List[str]:
        """Compile-on-RUN: current HTML → ephemeral ProgramImage → VM.

        Never read or write a .JSB/.JSH sidecar (HTML is the program).
        CompileError.line is the HTML editor line, not a sidecar.
        """
        from .compiler import CompileError
        from tools.compile_js import compile_html_text, encode_html_chunk

        # NEW: compiler front-end is live now (GUI paints this before the wait)
        self._arch_phase = "compile"
        try:
            chunk = compile_html_text(html)
        except CompileError as e:
            self._arch_phase = "loaded"
            where = f" LINE {e.line}" if e.line else ""
            return [f"ERROR{where}: {e.message}"]
        except Exception as e:
            self._arch_phase = "loaded"
            return [f"ERROR: HTML/JS {e}"]
        blob = encode_html_chunk(chunk)
        # Execute only the serialized ProgramImage. The decoded Chunk is the
        # Architecture Monitor / ASET observer, never the executor.
        from .jsb_format import ProgramImage, build_aset_payload
        from hardware_model.js_vm import JsHwVm

        image = ProgramImage(blob)
        observed = image.decode()
        self.trace.edge(
            "COMPILE",
            f"compile-on-RUN {self.source_name} → ProgramImage ({len(blob)} bytes)",
        )
        # Prompt/LIST Space must not arrive as the first game keydown.
        self.input.discard_queued_keys()
        self.html_host = None
        self._loop_chunk = None
        self._html_chunk = observed
        if getattr(observed, "palette", None):
            payload, descs = build_aset_payload(observed.palette, observed.sprites)
            self.sram.load(payload)
            self._spr_descs = list(descs)
            self.canvas.palette = list(observed.palette)
        else:
            self._spr_descs = []
        self._css_cache = {}
        self._sprites = list(self._spr_descs)
        # New glass for this RUN — leftover READY/WORKING letterbox must not
        # sit on the opposite swap buffer. DONKEY setTransform+clearRect only
        # covers the scaled world, so uncleared monitor text would show through.
        self.canvas.clear_front(0)
        self.canvas.clear(0)
        hw = JsHwVm()
        hw.canvas = self.canvas
        hw.input = self.input
        hw._m.canvas = self.canvas
        hw._m.input = self.input
        hw._m._sprites = list(self._sprites)
        hw.load_image(image)
        self._hw_vm = hw
        self.vm = hw._m.vm
        self.running = bool(hw.running) and not hw.error
        self._arch_phase = "run" if self.running else "loaded"
        self._bytecode_html = True
        if hw.error:
            self.running = False
            self._html_chunk = None
            self._hw_vm = None
            self._bytecode_html = False
            return [hw.error]
        return ["HTML BYTECODE RUNNING - arrows + space, ESC quit"]

    def _html_jsh_path(self) -> Optional[Path]:
        """Legacy cache-name helper; the product RUN path does not persist it."""
        stem = Path(self.source_name).stem
        if not stem:
            return None
        return self.storage.root / (stem.upper()[:8] + ".JSH")

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
            # NEW: platformer climb (DONKEY) — same joy bits as GUI KEYBITS
            "keyUp": self._nat_key_up,
            "keyDown": self._nat_key_down,
            "startLoop": self._nat_start_loop,
            # NEW (compiler v2): Math natives for HTML titles (PYTHON first)
            "Math.floor": self._nat_math_floor,
            "Math.abs": self._nat_math_abs,
            "Math.min": self._nat_math_min,
            "Math.max": self._nat_math_max,
            "Math.random": self._nat_math_random,
            "Math.sqrt": self._nat_math_sqrt,
            "typeof": self._nat_typeof,
            # NEW: DOM / storage stubs so HTML titles can compile+run on bytecode path
            "document.getElementById": self._nat_dom_el,
            "document.querySelector": self._nat_dom_el,
            "document.createElement": self._nat_dom_el,
            "document.addEventListener": self._nat_add_event_listener,
            "window.addEventListener": self._nat_add_event_listener,
            "addEventListener": self._nat_add_event_listener,  # NEW: bare global
            # NEW: real removal (DONKEY startSelect removes itself; a missing
            # native here killed the handler before gameState changed)
            "removeEventListener": self._nat_remove_event_listener,
            "document.removeEventListener": self._nat_remove_event_listener,
            "window.removeEventListener": self._nat_remove_event_listener,
            # NEW: synthetic events — DONKEY boot script fires Enter itself
            "document.dispatchEvent": self._nat_dispatch_event,
            "window.dispatchEvent": self._nat_dispatch_event,
            "localStorage.getItem": self._nat_ls_get,
            "localStorage.setItem": self._nat_ls_set,
            "localStorage.removeItem": self._nat_ls_remove,
            "JSON.parse": self._nat_json_parse,
            "JSON.stringify": self._nat_json_stringify,
            "Date": self._nat_new_date,
            "Image": self._nat_new_image,
            # NEW (full-game builtins): Array(n) constructor (PACMAN grids)
            "Array": self._nat_new_array,
            # NEW: real frame-scheduled timers (rAF stays queue-per-frame)
            "requestAnimationFrame": self._nat_raf,
            "setTimeout": self._nat_set_timeout,
            "clearTimeout": self._nat_clear_timer,
            "setInterval": self._nat_set_interval,
            "clearInterval": self._nat_clear_timer,
            # NEW: JSB v2 unknown CALL_NATIVE
            "_stub": self._nat_noop,
            # NEW: Canvas2D methods via ctx.* (HTML bytecode path)
            "ctx.fillRect": self._nat_fill_rect,
            "ctx.clearRect": self._nat_clear_rect,
            "ctx.setFillStyle": self._nat_fill_style_css,
            "ctx.drawImage": self._nat_draw_image,
            "ctx.fillText": self._nat_fill_text,
            "ctx.fillPath": self._nat_fill_path,
            "ctx.strokePath": self._nat_stroke_path,
            # NEW: canvas growth for full games
            "ctx.measureText": self._nat_measure_text,
            "ctx.strokeRect": self._nat_stroke_rect,
            "ctx.getImageData": self._nat_get_image_data,
            "ctx.putImageData": self._nat_put_image_data,
            "setFillStyle": self._nat_fill_style_css,
            "__ctx_xform": self._nat_ctx_xform,
            "__fire_click": self._nat_fire_click,
        }

    def _nat_ctx_xform(self, x=0, y=0, sx=1, sy=1):
        # NEW: setTransform scale (DONKEY world 1510×685 → 640×480 glass)
        self._ctx_tx = float(x or 0)
        self._ctx_ty = float(y or 0)
        self._ctx_sx = float(sx if sx is not None else 1) or 1.0
        self._ctx_sy = float(sy if sy is not None else 1) or 1.0
        return None

    _XF_OMIT = object()

    def _xf(self, x, y, w=_XF_OMIT, h=_XF_OMIT):
        """Apply current canvas transform (translate + axis scale).

        Point form is omit-w (`_xf(x, y)`). A rect native that passes JS
        undefined (None) still gets four values — ToNumber(undefined)=0.
        """
        sx = float(getattr(self, "_ctx_sx", 1) or 1)
        sy = float(getattr(self, "_ctx_sy", 1) or 1)
        tx = float(getattr(self, "_ctx_tx", 0) or 0)
        ty = float(getattr(self, "_ctx_ty", 0) or 0)
        ix = int(float(x or 0) * sx + tx)
        iy = int(float(y or 0) * sy + ty)
        if w is self._XF_OMIT:
            return ix, iy
        ww = 0 if w is None else w
        hh = 0 if h is None else h
        return (
            ix,
            iy,
            max(1, int(float(ww or 0) * sx)),
            max(1, int(float(hh or 0) * sy)),
        )

    def _nat_fill_style_css(self, color):
        """Map CSS color to a 256-entry title-palette index.

        NEW (external SRAM asset bank): the palette is per-title (harvested
        source colors are exact hits; sprites quantized to the same entries),
        so fillStyle maps by nearest match over all 256 — not the old fixed 8.
        Black maps to 0 (background); index 0 is only transparent for blits.
        """
        from .canvas_engine import nearest_palette_index, parse_css_color

        if isinstance(color, (int, float)):
            self.canvas.fill_style = int(color) & 0xFF
            return None
        s = str(color).strip().lower()
        cache = getattr(self, "_css_cache", None)
        if cache is None:
            cache = self._css_cache = {}
        idx = cache.get(s)
        if idx is None:
            rgb = parse_css_color(s)
            if rgb is None:
                idx = 7  # unknown string — keep legacy magenta tell
            elif rgb == (0, 0, 0):
                idx = 0
            else:
                idx = nearest_palette_index(self.canvas.palette, rgb, lo=1)
            cache[s] = idx
        self.canvas.fill_style = idx
        return None

    def _nat_log(self, *args):
        self._print(*[str(a) for a in args])
        return None

    def _nat_fill_rect(self, x, y, w, h, color=None):
        ix, iy, iw, ih = self._xf(x, y, w, h)
        if color is not None:
            self.canvas.fill_rect(ix, iy, iw, ih, int(color))
        else:
            self.canvas.fill_rect(ix, iy, iw, ih)
        return None

    def _nat_draw_image(self, *args):
        """Blit sprite pixels from Image._pix / jmr:spr pack (no magenta stub)."""
        sx = sy = 0
        sw = sh = dw = dh = None
        img = None
        if len(args) >= 9:
            img, sx, sy, sw, sh, dx, dy, dw, dh = args[:9]
        elif len(args) >= 5:
            img, dx, dy, dw, dh = args[:5]
        elif len(args) >= 3:
            img, dx, dy = args[:3]
        else:
            return None
        pix = None
        iw = ih = 0
        if isinstance(img, dict):
            pix = img.get("_pix")
            iw = int(img.get("width") or 0)
            ih = int(img.get("height") or 0)
            # NEW: ASET handle — pixels live in the external SRAM asset bank
            if pix is None and img.get("_spr") is not None:
                si = int(img["_spr"])
                descs = self._spr_descs
                if 0 <= si < len(descs):
                    w_, h_, off = descs[si]
                    if w_ > 0 and h_ > 0:
                        pix = self.sram.view(off, w_ * h_)
                        iw, ih = w_, h_
        if not pix or iw <= 0 or ih <= 0:
            return None
        if sw is None:
            sw, sh = iw, ih
        if dw is None:
            dw, dh = sw, sh
        dx, dy, dw, dh = self._xf(dx, dy, dw, dh)
        try:
            self.canvas.blit_indexed(
                pix, iw, ih, int(sx), int(sy), int(sw), int(sh),
                dx, dy, dw, dh,
            )
        except Exception:
            pass
        return None

    def _font_scale(self, font=None) -> int:
        """ctx.font '20px Arial' → integer glyph scale (8×8 base), including
        the current canvas x-scale (DONKEY world→glass setTransform)."""
        px = 8.0
        if font:
            m = None
            import re as _re

            m = _re.search(r"(\d+(?:\.\d+)?)\s*px", str(font))
            if m:
                px = float(m.group(1))
        sx = float(getattr(self, "_ctx_sx", 1) or 1)
        return max(1, int(round(px * sx / 8.0)))

    def _nat_fill_text(self, t, x, y, style=None, align="left", font=None):
        if style is not None:
            self._nat_fill_style_css(style)
        ix, iy = self._xf(x, y)
        self.canvas.fill_text(
            t, ix, iy, align=str(align or "left"), scale=self._font_scale(font)
        )
        return None

    def _nat_measure_text(self, t, font=None):
        # NEW: width matches fill_text glyph geometry (8 px × scale per char)
        return {"width": len(str(t)) * 8 * self._font_scale(font)}

    def _nat_stroke_rect(self, x, y, w, h, style=None):
        # NEW: 1px outline via four edges (device-space thickness)
        if style is not None:
            self._nat_fill_style_css(style)
        ix, iy, iw, ih = self._xf(x, y, w, h)
        c = self.canvas.fill_style
        self.canvas.fill_rect(ix, iy, iw, 1, c)
        self.canvas.fill_rect(ix, iy + ih - 1, iw, 1, c)
        self.canvas.fill_rect(ix, iy, 1, ih, c)
        self.canvas.fill_rect(ix + iw - 1, iy, 1, ih, c)
        return None

    def _nat_get_image_data(self, x=0, y=0, w=0, h=0):
        """NEW: indexed snapshot of the BACK buffer (PACMAN maze cache).
        Device space — Canvas2D getImageData ignores the transform."""
        ix, iy, iw, ih = int(x), int(y), int(w), int(h)
        iw = max(0, iw)
        ih = max(0, ih)
        buf = bytearray(iw * ih)
        back = self.canvas.back
        cw, chh = self.canvas.width, self.canvas.height
        x0 = max(0, -ix)
        x1 = min(iw, cw - ix)
        for yy in range(ih):
            sy = iy + yy
            if sy < 0 or sy >= chh or x1 <= x0:
                continue
            row = sy * cw + ix
            drow = yy * iw
            buf[drow + x0 : drow + x1] = back[row + x0 : row + x1]
        return {"__class": "ImageData", "width": iw, "height": ih, "_idx": bytes(buf)}

    def _nat_put_image_data(self, d, dx=0, dy=0, *_a):
        if not isinstance(d, dict) or d.get("_idx") is None:
            return None
        iw = int(d.get("width") or 0)
        ih = int(d.get("height") or 0)
        buf = d["_idx"]
        ix, iy = int(dx), int(dy)
        back = self.canvas.back
        cw, chh = self.canvas.width, self.canvas.height
        self.canvas.dirty = True
        x0 = max(0, -ix)
        x1 = min(iw, cw - ix)
        for yy in range(ih):
            ty = iy + yy
            if ty < 0 or ty >= chh or x1 <= x0:
                continue
            row = ty * cw + ix
            srow = yy * iw
            back[row + x0 : row + x1] = buf[srow + x0 : srow + x1]
        return None

    def _nat_fill_path(self, spec, style=None):
        if style is not None:
            self._nat_fill_style_css(style)
        self._raster_path(spec, stroke=False)
        return None

    def _nat_stroke_path(self, spec, style=None):
        if style is not None:
            self._nat_fill_style_css(style)
        self._raster_path(spec, stroke=True)
        return None

    def _raster_path(self, spec, stroke: bool) -> None:
        """PACMAN maze/beans: one primitive per beginPath (arc or move+line)."""
        import math

        if not spec:
            return
        c = self.canvas.fill_style
        if isinstance(spec, list):
            cmds = spec
        else:
            cmds = str(spec).split("|")
        for cmd in cmds:
            if not cmd:
                continue
            if isinstance(cmd, tuple):
                parts = list(cmd)
                op = parts[0]
            else:
                parts = str(cmd).split(",")
                op = parts[0]
            if op == "A" and len(parts) >= 4:
                cx, cy, r = float(parts[1]), float(parts[2]), float(parts[3])
                ix, iy = self._xf(cx, cy)
                sx = float(getattr(self, "_ctx_sx", 1) or 1)
                # NEW: real start/end angles (PACMAN mouth / ghost skirts)
                a0 = float(parts[4]) if len(parts) > 4 else 0.0
                a1 = float(parts[5]) if len(parts) > 5 else 0.0
                ccw = bool(len(parts) > 6 and float(parts[6]))
                if len(parts) <= 4 or abs(a1 - a0) >= 2 * math.pi - 1e-6:
                    self.canvas.fill_circle(
                        ix, iy, max(1, int(float(r) * sx)), c, stroke
                    )
                elif a0 != a1:
                    self.canvas.fill_circle(
                        ix, iy, max(1, int(float(r) * sx)), c, stroke,
                        a0=a0, a1=a1, ccw=ccw,
                    )
                self._path_x, self._path_y = ix, iy
            elif op == "L" and len(parts) >= 3:
                x1, y1 = self._xf(float(parts[1]), float(parts[2]))
                x0 = getattr(self, "_path_x", x1)
                y0 = getattr(self, "_path_y", y1)
                self._line(x0, y0, x1, y1, c)
                self._path_x, self._path_y = x1, y1
            elif op == "Q" and len(parts) >= 5:
                # NEW: quadratic curve — subdivide into 8 line segments
                qcx, qcy = self._xf(float(parts[1]), float(parts[2]))
                x1, y1 = self._xf(float(parts[3]), float(parts[4]))
                x0 = getattr(self, "_path_x", x1)
                y0 = getattr(self, "_path_y", y1)
                px, py = x0, y0
                for i in range(1, 9):
                    t = i / 8.0
                    u = 1.0 - t
                    bx = int(u * u * x0 + 2 * u * t * qcx + t * t * x1)
                    by = int(u * u * y0 + 2 * u * t * qcy + t * t * y1)
                    self._line(px, py, bx, by, c)
                    px, py = bx, by
                self._path_x, self._path_y = x1, y1
            elif op == "M" and len(parts) >= 3:
                self._path_x, self._path_y = self._xf(float(parts[1]), float(parts[2]))

    def _line(self, x0, y0, x1, y1, c) -> None:
        self.canvas.dirty = True
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        back = self.canvas.back
        w = self.canvas.width
        h = self.canvas.height
        while True:
            if 0 <= x0 < w and 0 <= y0 < h:
                back[y0 * w + x0] = c
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def _nat_clear_rect(self, x, y, w, h):
        ix, iy, iw, ih = self._xf(x, y, w, h)
        self.canvas.clear_rect(ix, iy, iw, ih)
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

    def _nat_key_up(self):
        from .input_engine import KEY_UP

        return 1 if (self.input.play_bits() & KEY_UP) else 0

    def _nat_key_down(self):
        from .input_engine import KEY_DOWN

        return 1 if (self.input.play_bits() & KEY_DOWN) else 0

    def _nat_start_loop(self):
        self._loop_chunk = True
        return None

    # NEW (compiler v2): Math natives — int-friendly; random is deterministic seed later
    def _nat_math_floor(self, x):
        import math

        return int(math.floor(float(x)))

    def _nat_math_abs(self, x):
        return abs(x)

    def _nat_math_min(self, a, b):
        return a if a < b else b

    def _nat_math_max(self, a, b):
        return a if a > b else b

    def _nat_math_random(self):
        # PYTHON control: real random; RTL will use LFSR — parity via seeded tests
        import random

        return random.random()

    def _nat_math_sqrt(self, x):
        import math

        return math.sqrt(float(x)) if float(x) >= 0 else 0.0

    def _nat_typeof(self, x):
        # NEW: JS typeof for PACMAN map checks
        if x is None:
            return "undefined"
        if isinstance(x, bool):
            return "boolean"
        if isinstance(x, (int, float)):
            return "number"
        if isinstance(x, str):
            return "string"
        if callable(x) or (isinstance(x, dict) and x.get("__class") == "Fn"):
            return "function"
        return "object"

    # NEW: tiny DOM/storage stubs for HTML→bytecode path (leaderboard etc.)
    def _nat_dom_el(self, *_a):
        return {"__class": "Element", "style": {}}

    def _nat_noop(self, *_a):
        return None

    def _nat_ls_get(self, key):
        if not hasattr(self, "_ls"):
            self._ls = {}
        return self._ls.get(str(key))

    def _nat_ls_set(self, key, val):
        if not hasattr(self, "_ls"):
            self._ls = {}
        self._ls[str(key)] = str(val)
        return None

    def _nat_ls_remove(self, key):
        if not hasattr(self, "_ls"):
            self._ls = {}
        self._ls.pop(str(key), None)
        return None

    def _nat_json_parse(self, s):
        import json

        try:
            return json.loads(s) if s else None
        except Exception:
            return None

    def _nat_json_stringify(self, v):
        import json

        try:
            return json.dumps(v)
        except Exception:
            return "null"

    def _nat_new_date(self, *_a):
        # NEW: Date stub for HTML leaderboard
        return {"__class": "Date"}

    def _nat_new_image(self, *_a):
        # NEW: Image stub — onload/src set via props; host path paints real PNG
        return {"__class": "Image", "src": "", "width": 1, "height": 1}

    def _nat_new_array(self, *args):
        # NEW: Array(n) → n undefined slots (JS); Array(a,b,…) → [a,b,…]
        if len(args) == 1 and isinstance(args[0], (int, float)):
            return [None] * max(0, int(args[0]))
        return list(args)

    def _nat_raf(self, fn=None):
        # NEW: queue fn for next frame_tick (bytecode HTML path)
        if not hasattr(self, "_raf_q"):
            self._raf_q = []
        if fn is not None:
            self._raf_q.append(fn)
        return 1

    # NEW: real frame-scheduled timers — hardware-honest (RTL counts frames
    # the same way; no host wall-clock in the game loop).
    _MS_PER_FRAME = 1000.0 / 60.0

    def _ms_to_frames(self, ms) -> int:
        try:
            return max(1, int(round(float(ms or 0) / self._MS_PER_FRAME)))
        except (TypeError, ValueError):
            return 1

    def _nat_set_timeout(self, fn=None, ms=0, *_a):
        if fn is None:
            return 0
        if not hasattr(self, "_timers"):
            self._timers = []
            self._timer_seq = 1
            self._frame_no = 0
        tid = self._timer_seq
        self._timer_seq += 1
        self._timers.append([self._frame_no + self._ms_to_frames(ms), fn, None, tid])
        return tid

    def _nat_set_interval(self, fn=None, ms=0, *_a):
        if fn is None:
            return 0
        if not hasattr(self, "_timers"):
            self._timers = []
            self._timer_seq = 1
            self._frame_no = 0
        tid = self._timer_seq
        self._timer_seq += 1
        period = self._ms_to_frames(ms)
        self._timers.append([self._frame_no + period, fn, period, tid])
        return tid

    def _nat_clear_timer(self, tid=None, *_a):
        if tid is None or not hasattr(self, "_timers"):
            return None
        self._timers = [t for t in self._timers if t[3] != tid]
        return None

    def _nat_add_event_listener(self, event=None, fn=None, *_a):
        # NEW: store keydown/keyup handlers for bytecode HTML.
        # Chrome semantics: the same (type, listener) pair registers once —
        # DONKEY re-adds startSelect every title frame.
        if not hasattr(self, "_listeners"):
            self._listeners = []
        if event is not None and fn is not None:
            ev = str(event)
            for et, f in self._listeners:
                if et == ev and f is fn:
                    return None
            self._listeners.append((ev, fn))
        return None

    def _nat_remove_event_listener(self, event=None, fn=None, *_a):
        # NEW: remove by (type, listener identity) — DONKEY menu handlers
        if event is None or fn is None or not hasattr(self, "_listeners"):
            return None
        ev = str(event)
        self._listeners = [
            (et, f) for et, f in self._listeners if not (et == ev and f is fn)
        ]
        return None

    def _nat_dispatch_event(self, ev=None, *_a):
        # NEW: document/window.dispatchEvent(ev) — fire listeners matching
        # ev.type with the synthetic event object (DONKEY boot Enter).
        chunk = getattr(self, "_html_chunk", None)
        if chunk is None or not isinstance(ev, dict):
            return None
        etype = str(ev.get("type") or "keydown")
        for et, fn in list(getattr(self, "_listeners", [])):
            if et == etype:
                self.vm.call_fn(chunk, fn, [ev])
        return None

    def _nat_fire_click(self, *_a):
        # NEW: Element.click() → invoke registered "click" listeners
        chunk = getattr(self, "_html_chunk", None)
        if chunk is None:
            return None
        n = 0
        for et, fn in list(getattr(self, "_listeners", [])):
            if et == "click":
                n += 1
                self.vm.call_fn(chunk, fn, [{"type": "click"}])
        if n:
            self.trace.edge("CLICK", f"listeners={n}")
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
        # NEW: bytecode HTML path — fire key listeners + drain rAF
        if getattr(self, "_bytecode_html", False) and self.running:
            self._bytecode_html_frame()
            # NEW: 1 s play heartbeat so a hang is visible without µop spam
            self._play_frames = getattr(self, "_play_frames", 0) + 1
            now = time.monotonic()
            if not getattr(self, "_play_t", 0.0):
                self._play_t = now
            elif now - self._play_t >= 1.0:
                self.trace.edge(
                    "PLAY",
                    f"frames={self._play_frames} raf_n={len(getattr(self, '_raf_q', []))} "
                    f"to_n={len(getattr(self, '_timers', []))}",
                )
                self._play_t = now
                self._play_frames = 0
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

    def _bytecode_html_frame(self) -> None:
        """NEW: one frame for HTML-as-bytecode — keys then rAF queue."""
        hw = getattr(self, "_hw_vm", None)
        if hw is not None:
            hw.frame_tick()
            self.running = bool(hw.running) and not hw.error
            if hw.error:
                self._print(hw.error)
                self.hard_break()
                return
            if hw.canvas.dirty:
                hw.canvas.present()
                hw.canvas.dirty = False
                self._keep_fb = True
            return
        chunk = getattr(self, "_html_chunk", None)
        if chunk is None:
            return
        # NEW: tether KEYBITS → key-state edges; drain generic key event queue
        self.input._sync_play_bits_to_keys()
        evs = self.input.drain_key_events()
        if evs:
            self.trace.edge(
                "KEY",
                ",".join(f"{et}:{code}" for et, code, _k in evs),
            )
        for et, code, key in evs:
            self._fire_listeners(et, code, key)
        # NEW: surface listener errors (they used to die silently mid-handler)
        if self.vm.error:
            self._print(self.vm.error)
            self.hard_break()
            return
        self._frame_no = getattr(self, "_frame_no", 0) + 1
        # NEW: deterministic frame clock — Date.now/getTime tick with frames
        self.vm.time_ms = self._frame_no * (1000.0 / 60.0)
        # drain rAF (one generation)
        q = getattr(self, "_raf_q", [])
        self._raf_q = []
        # NEW: browser-style rAF timestamp (ms) — DONKEY's update(timestamp)
        # computes elapsed from it; without it DK animation/barrels froze.
        raf_ts = self._frame_no * (1000.0 / 60.0)
        for fn in q:
            try:
                self.vm.call_fn(chunk, fn, [raf_ts])
            except Exception as e:
                self._print(f"ERROR: JS {e}")
                self.hard_break()
                return
            if self.vm.error:
                self._print(self.vm.error)
                self.hard_break()
                return
        # NEW: fire due frame-scheduled timers AFTER rAF. A sub-frame timeout
        # set mid-handler (DK isThrowing, 10 ms) lands after the next rAF in
        # Chrome because the handler itself eats most of the frame slot; the
        # rAF handler must see the flag before the timeout clears it.
        due = [t for t in getattr(self, "_timers", []) if t[0] <= self._frame_no]
        for t in due:
            if t not in self._timers:
                continue  # cleared by an earlier callback this frame
            if t[2] is None:
                self._timers.remove(t)
            else:
                t[0] = self._frame_no + t[2]  # interval reschedule
            try:
                self.vm.call_fn(chunk, t[1], [])
            except Exception as e:
                self._print(f"ERROR: JS {e}")
                self.hard_break()
                return
            if self.vm.error:
                self._print(self.vm.error)
                self.hard_break()
                return
        # NEW: no machine auto-Enter — the HTML decides its own boot keys
        # (DONKEY ships a boot script that dispatchEvent()s Enter; PACMAN's
        # game stage binds Enter as PAUSE, so a fake Enter froze it).
        # NEW: present only frames the game drew (swap-on-draw) — setTimeout
        # paced loops draw every Nth tick; blind swap flashed stale buffers.
        if self.canvas.dirty:
            self.canvas.swap()
            self.canvas.dirty = False
            self._keep_fb = True

    def _fire_listeners(self, event: str, key_code: int, key: str) -> None:
        chunk = getattr(self, "_html_chunk", None)
        if chunk is None:
            return
        ev = {"key": key, "keyCode": key_code, "which": key_code, "code": key}
        for et, fn in list(getattr(self, "_listeners", [])):
            if et == event:
                self.vm.call_fn(chunk, fn, [ev])
