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
from runtime.backend import ROOT, RuntimeBackend, card_catalog, parse_status_kv
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
        self._listing = False  # LIST/DIR until READY — no '>' between pages
        self._edit_prefill: Optional[str] = None
        self._loaded_name: str = ""
        self._break_run_wait: bool = False
        self._fb_logged: bool = False  # first game FB? only
        extra = ""
        if _SYNTH.is_file():
            extra = f"# rtl_mtime={_SYNTH.stat().st_mtime:.0f}\n"
        self._log = FlightLog(self.name, extra_header=extra)
        self._kev_n = 0
        self._kev_codes: list = []
        self._play_t = 0.0
        self._play_frames = 0
        self._play_fclk: list = []
        self._last_glass = ""
        self._more_page = 0
        # NEW: Architecture Monitor — cache VMSTAT/STATUS (no extra RPC while RUN)
        self._vmstat_raw = ""
        self._status_raw = ""
        self._vmstat_t = 0.0
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
                if not self._fb_logged:
                    self._fb_logged = True
                    self._log.note(f"rpc FB? first-frame {dt_ms:.1f}ms")
        elif resp == "FB SAME":
            pass
        elif resp.startswith("ERR") or resp.startswith("FAULT"):
            self._log.fault("RPC", f"cmd={cmd!r} resp={resp!r}")
        if resp.startswith("VMSTAT"):
            self._vmstat_raw = resp
            self._vmstat_t = time.monotonic()
        elif resp.startswith("STATUS"):
            self._status_raw = resp
        # Do not log every FB?/TICK timing (hundreds of NOTE rpc FB? 316ms).
        # LINE/KEY always; FB? only on fault (already logged) or first game frame.
        verb = cmd.split()[0] if cmd else ""
        quiet = verb in (
            "FB?", "TICK", "TICKN", "FRAME", "SCREEN?", "STATUS?", "PAL?",
            "JOY", "KEYBITS", "VMSTAT?",
        )
        if verb == "LINE":
            self._log.note(f"rpc LINE {dt_ms:.1f}ms {resp}")
        elif verb == "KEYEVT":
            self._kev_n += 1
            parts = cmd.split()
            if len(parts) >= 2:
                self._kev_codes.append(parts[1])
            if self._kev_n == 1:
                self._kev_t0 = time.monotonic()
            elif time.monotonic() - getattr(self, "_kev_t0", 0.0) >= 5.0:
                self._flush_keyevts()
        elif verb in ("KEY", "SDRELOAD"):
            self._log.note(f"rpc {verb} {dt_ms:.1f}ms")
        elif (not quiet) and dt_ms > 25.0:
            self._log.note(f"rpc {verb} {dt_ms:.1f}ms")
        return resp

    def _flush_keyevts(self) -> None:
        if not self._kev_n:
            return
        codes = ",".join(self._kev_codes[:16])
        self._log.note(f"keyevts n={self._kev_n} codes={codes}")
        self._kev_n = 0
        self._kev_codes = []
        self._kev_t0 = time.monotonic()

    def _last_glass_line(self) -> str:
        """Last non-empty VRAM row (not a 16-row 400-char join)."""
        last = ""
        for ln in reversed(self._screen.replace("\\n", "\n").splitlines()):
            t = ln.strip()
            if t:
                last = t
                break
        return last

    def _note_glass(self, tag: str) -> None:
        """LIST/DIR/LOAD/SAVE — last non-empty row so a long URI is readable."""
        last = self._last_glass_line()
        msg = f"GLASS {tag} {last[:120]}"
        if msg == self._last_glass:
            return
        self._last_glass = msg
        self._log.note(msg)
        if last.startswith("-- MORE"):
            self._note_more()

    def _note_more(self) -> None:
        """MORE page + the source line above it (wrap=1 if mid-URI / long)."""
        self._more_page = getattr(self, "_more_page", 0) + 1
        prev = ""
        seen_more = False
        for ln in reversed(self._screen.replace("\\n", "\n").splitlines()):
            t = ln.strip()
            if not t:
                continue
            if t.startswith("-- MORE"):
                seen_more = True
                continue
            if seen_more:
                prev = t
                break
        wrap = int(
            ("data:image" in prev.lower())
            or prev.endswith("|")
            or len(prev) >= 60
        )
        self._log.note(f"MORE page={self._more_page} wrap={wrap} {prev[:80]}")

    def _load_reply_ready(self, glass: str, stem: str) -> bool:
        """True only for THIS load's LOADED stem+LINES (or ?IO/?FN/?LS)."""
        g = glass.replace("\\n", "\n")
        if "?IO" in g or "?LS" in g or "?FN" in g:
            return True
        want = (stem or "").upper()[:8]
        if not want:
            return "LOADED" in g and "LINES" in g
        for ln in g.splitlines():
            u = ln.upper()
            if "LOADED" in u and "LINES" in u and want in u:
                return True
        return False

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
                self._listing = False
                return
            self._rpc("KEY 1b")
            for _ in range(30):
                self._rpc("TICK")
        self._more = False
        self._listing = False

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
        self, prompt: Optional[str] = None, cursor_on: bool = False,
        cursor_col: Optional[int] = None,
    ) -> None:
        """RTL text path — HDMI letterbox (same geometry as PYTHON / BOARD)."""
        # Parked on -- MORE -- (or paging to the next MORE): never overlay '>'
        if self._more or self._screen_has_more():
            self._more = True
            lines = self._screen.splitlines()
            self._canvas.paint_console_letterbox(lines, prompt="")
            return
        pr = prompt if prompt is not None else "> "
        self._canvas.paint_console_letterbox(
            self._screen.splitlines(),
            prompt=pr,
            cursor_on=cursor_on,
            cursor_col=cursor_col,
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
        last = self._last_glass_line()
        if last in ("READY",) or last.startswith("READY"):
            self._listing = False
        if self._use_rtl or resp == "FB SAME" or not resp.startswith("FB "):
            if self._use_rtl or not any(self._canvas.front):
                # LIST/DIR: keep -- MORE -- (or the current page) without '>'
                if self._more or self._listing:
                    self._paint_screen_local("")
                else:
                    self._paint_screen_local(prompt)

    def _pump_until_more_or_ready(self, *, leave_more: bool = False) -> None:
        """Wait until MORE or READY. Fat data-URI LIST needs millions of SPI clocks."""
        for _ in range(500):
            pump = getattr(self, "run_wait_idle", None)
            if pump is not None:
                pump()
            if getattr(self, "_break_run_wait", False):
                break
            self._rpc("SCREEN?")
            has = self._screen_has_more()
            if leave_more:
                if not has:
                    break
            elif has:
                break
            last = self._last_glass_line()
            if last in ("READY", ">", "> ") or last.startswith("READY"):
                break
            # TICKN 20000 = 20M clocks (same as fat RUN)
            self._rpc("TICKN 20000")

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
        # LIST/DIR may park on -- MORE --; LINE now waits, but keep pumping
        # until MORE or prompt so we never paint '>' over a mid-page.
        if upper == "LIST" or upper.startswith("LIST ") or upper == "DIR":
            self._listing = True
            self._more_page = 0
            self._pump_until_more_or_ready()
        # HTML LOAD: wait for THIS stem+LINES, not a stale LOADED still on glass.
        if upper.startswith("LOAD") and self._html_loaded_stem():
            self._break_run_wait = False
            stem = self._html_loaded_stem()
            for i in range(500):
                pump = getattr(self, "run_wait_idle", None)
                if pump is not None:
                    pump()
                if getattr(self, "_break_run_wait", False):
                    break
                self._rpc("TICKN 20000")
                self._rpc("SCREEN?")
                if self._load_reply_ready(self._screen, stem):
                    break
        if upper.startswith("SAVE"):
            self._persist_save(stripped)
        # HTML RUN FAT-loads a large fresh .JSH (sprites); wait for VM start.
        # Scale TICKN by compile size (any fat HTML, not one title). TICKN n =
        # n×1000 clocks; ~100 clk/byte of FAT+SRAM stream plus headroom.
        if (upper == "RUN" or upper.startswith("RUN ")) and self._html_loaded_stem():
            nbytes = int(getattr(self, "_last_jsh_bytes", 0) or 0)
            clocks = max(40_000_000, nbytes * 200)
            # NEW: TICKN 20000 = 20M clocks/RPC (cap 100000). Fat .JSH was
            # 236× TICKN 2000 RPCs after LINE's 100M cap — minutes of overhead.
            slices = max(1, (clocks + 19_999_999) // 20_000_000)
            self._break_run_wait = False
            for i in range(slices):
                pump = getattr(self, "run_wait_idle", None)
                if pump is not None:
                    pump()
                if getattr(self, "_break_run_wait", False):
                    break
                self._rpc("TICKN 20000")
                st = self._rpc("STATUS?")
                glass = self.screen_text()
                if "running=1" in st or "?NH" in glass or "?NB" in glass:
                    break
                # Do not overlay '>' during LINE/FAT wait (typed RUN vanished).
            # NEW: ASET palette landed in the RTL palette BRAM during the FAT
            # load — mirror it so the GUI colors FB indices like HDMI would.
            self._sync_palette()
        self._sync_glass()
        if upper == "DIR" or upper.startswith("LOAD") or upper.startswith("SAVE") or upper == "LIST" or upper.startswith("LIST"):
            self._note_glass(upper.split()[0])
        if upper.startswith("EDIT"):
            self._note_edit_prefill()

    def _sync_palette(self) -> None:
        """Pull the RTL palette BRAM (PAL?) into the GUI canvas palette."""
        resp = self._rpc("PAL?")
        if resp.startswith("PAL "):
            raw = base64.b64decode(resp[4:])
            if len(raw) == 768:
                self._canvas.palette = [
                    (raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]) for i in range(256)
                ]

    def _html_loaded_stem(self) -> str:
        name = (self._loaded_name or "").upper()
        if name.endswith(".HTML") or name.endswith(".HTM"):
            return Path(name).stem[:8]
        return ""

    def _persist_save(self, text: str) -> None:
        """Host-copy full HTML onto card.img after RTL SAVE (SOURCE may truncate).

        SDRELOAD picks up the patched FAT so LOAD of the new name works.
        """
        rest = text[4:].strip().strip('"').strip("'")
        if not rest:
            return
        stem = self._html_loaded_stem() or Path(self._loaded_name or "").stem[:8]
        if not stem:
            return
        src = None
        for ext in (".HTML", ".HTM", ".JS"):
            p = ROOT / "storage" / f"{stem}{ext}"
            if p.is_file():
                src = p
                break
        if src is None:
            return
        try:
            from tools.make_sd_image import patch_card_file

            data = src.read_bytes()
            dest = ROOT / "storage" / rest
            dest.write_bytes(data)
            card = Path(os.environ.get("JMR_CARD_IMG") or (ROOT / "card.img"))
            if card.is_file():
                patch_card_file(card, rest, data)
                self._rpc("SDRELOAD")
            self._log.note(f"SAVE persist {src.name} → {rest} ({len(data)} bytes)")
        except Exception as e:
            self._log.fault("SAVE", str(e))

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
            self._last_jsh_bytes = len(blob)
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
        """MORE continue / Esc — GUI Space/Enter while more_waiting.

        After the page key, TICKN until the next -- MORE -- or prompt
        (LIST of a fat HTML needs ~10^5 clocks; a handful of TICK is not enough).
        """
        if not self._started:
            self._start()
        if ch == "\x1b":
            self._rpc("KEY 1b")
        elif ch in (" ", "\r", "\n"):
            self._rpc("KEY 20" if ch == " " else "KEY 0d")
        else:
            self._rpc(f"KEY {ord(ch):02x}")
        # Leave the current MORE page first (SCREEN still shows the old -- MORE --)
        self._pump_until_more_or_ready(leave_more=True)
        # Then wait until the next -- MORE -- or prompt (same as type_line LIST)
        self._pump_until_more_or_ready()
        self._sync_glass()

    def screen_text(self) -> str:
        if not self._started:
            self._start()
        return self._screen

    def set_joy(self, bits: int) -> None:
        self._rpc(f"JOY {bits}")

    def set_key_bits(self, bits: int) -> None:
        self._rpc(f"KEYBITS {bits}")

    def key_event(self, key_code: int, key: str, pressed: bool) -> None:
        # NEW: raw keyboard → RTL KEYEVT for every code. HTML decides bindings.
        # KEYBITS still tethers arrows/space; RTL skips synthetic keydown when
        # a KEYEVT is already queued (no double-fire).
        self._rpc(f"KEYEVT {int(key_code) & 0xFF} {1 if pressed else 0}")

    def paint_prompt(self, prompt: str, cursor_on: bool = False, cursor_col=None) -> None:
        if not self._started:
            self._start()
        # NEW: game owns the glass (BASIC method) — never overlay `>` on FB
        if self._running or self._more:
            return
        if self._use_rtl:
            self._paint_screen_local(prompt, cursor_on=cursor_on, cursor_col=cursor_col)
        else:
            self._rpc(f"PROMPT {prompt}")
            resp = self._rpc("FB?")
            if resp == "FB SAME":
                self._rpc("SCREEN?")
                self._paint_screen_local(prompt, cursor_on=cursor_on, cursor_col=cursor_col)

    def hard_break(self) -> None:
        self._flush_keyevts()
        self._log.note("BREAK")
        # NEW: one VM telemetry line on BREAK (n_obj / heap_ovf / to_ovf / raf)
        try:
            self._log.note(self._rpc("VMSTAT?"))
            self._log.note(self._rpc("PXCNT?"))
            self._log.note(self._rpc("FBRAW?"))
        except Exception:
            pass
        self._break_run_wait = True  # NEW: abort size-scaled RUN TICKN wait
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
        # NEW: while running, one VM frame (tick-to-swap) not TICK=1000
        if self._running:
            resp = self._rpc("FRAME")
            self._play_frames += 1
            now = time.monotonic()
            if self._play_t == 0.0:
                self._play_t = now
            # Capped FRAME returns FB SAME while game_mode — that is the hang.
            capped = resp == "FB SAME"
            first3 = self._play_frames <= 3
            beat = now - self._play_t >= 1.0
            st = ""
            if capped or first3 or beat:
                try:
                    st = self._rpc("VMSTAT?")
                except Exception:
                    st = ""
            if st:
                fclk = 0
                for tok in st.split():
                    if tok.startswith("fclk="):
                        try:
                            fclk = int(tok.split("=", 1)[1])
                        except ValueError:
                            pass
                if fclk:
                    self._play_fclk.append(fclk)
                if capped or "fcap=1" in st:
                    self._log.note(f"FRAME {st}")
                elif first3:
                    self._log.note(f"FRAME {st}")
            if beat:
                n = len(self._play_fclk)
                avg = (sum(self._play_fclk) // n) if n else 0
                mx = max(self._play_fclk) if n else 0
                self._flush_keyevts()
                self._log.note(
                    f"play fb_frames={self._play_frames} fclk_avg={avg} "
                    f"fclk_max={mx} {st}"
                )
                self._play_t = now
                self._play_frames = 0
                self._play_fclk = []
        elif self._more:
            # Parked: do not TICK (C_LIST_WAIT is key-driven) and do not
            # paint '>' between pages while the next MORE is still printing.
            self._rpc("SCREEN?")
            self._more = self._screen_has_more()
            if not self._more:
                last = self._last_glass_line()
                if last in ("READY",) or last.startswith("READY"):
                    self._paint_screen_local("> ")
        else:
            self._rpc("TICK")

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
        self._flush_keyevts()
        self._log.note("shutdown")

    def arch_snapshot(self) -> dict:
        """FPGA-SIM observer: cached VMSTAT?/STATUS?/SCREEN? (no extra RPC while RUN)."""
        if self._started and not self._running:
            now = time.monotonic()
            if now - self._vmstat_t >= 0.25:
                try:
                    self._rpc("VMSTAT?")
                except Exception:
                    pass
                try:
                    self._rpc("STATUS?")
                except Exception:
                    pass
        snap = parse_status_kv(self._vmstat_raw)
        snap.update(parse_status_kv(self._status_raw))
        snap["running"] = bool(self._running) or snap.get("running") in (1, "1", True)
        snap["glass"] = self._screen or ""
        snap["hdmi_mode"] = "game" if self._running else "letterbox"
        snap["source_name"] = self._loaded_name or ""
        snap["more"] = bool(self._more)
        snap["catalog"] = card_catalog()
        snap["sp"] = snap.get("sp", 0)
        return snap
