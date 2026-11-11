"""Verilator FPGA-SIM backend — line protocol client.

FPGA-SIM defaults to real RTL (jmr_js_sim_server). Never silently
fall back to the PYTHON host twin — that fake default burned hours comparing
the wrong machine to silicon.

  Default:          sim_build_synth/jmr_js_sim_server (RTL)
  Host model:       select the separate PYTHON runtime
  Missing RTL:      fail loud (do not pretend PYTHON is FPGA-SIM)

Finder services use typed requests into the same core ports as the tether.
The GUI reads framebuffer and observer data directly; no command screen is rendered.
"""

from __future__ import annotations

import base64
import os
import subprocess
import time
from pathlib import Path
from typing import Optional

from functional_model.canvas_engine import CanvasEngine
from runtime.backend import (
    ROOT, RuntimeBackend, parse_status_kv,
    decode_ip, decode_op_at, fmt_code_window, fmt_html_window,
)
from runtime.flight_log import FlightLog
from runtime.finder_tether import FinderServices, Operation

SIM_DIR = ROOT / "sim"
# JMR_SIM_BUILD: pick an alternate build dir (A/B binaries, e.g. the
# JMR_PF_SKIP experimental build in sim_build_pf) without touching the
# default. The suite and GUI keep using sim_build_synth.
_SYNTH = SIM_DIR / os.environ.get("JMR_SIM_BUILD", "sim_build_synth") / "jmr_js_sim_server"
_HOST_PY = SIM_DIR / "host_sim_server.py"

# Observer-only probes. The sim answers an unrecognised verb with plain "ERR"
# (one line, never a hang), so a GUI built against a newer sim_main.cpp still
# drives an older binary — it just loses that view. These must not reach the
# flight log as faults: the log is what you read after a crash, and one
# "missing verb" line per second would bury the real one.
_OPTIONAL_VERBS = frozenset((
    "PROF?", "PROFCLR", "IPTRACE",
    # Inspector peeks — the drill-downs degrade to "no view" without them.
    "OBJPEEK", "ARRPEEK", "STK?", "VARPEEK", "VVARPEEK", "SRAMPEEK",
    "RAFPEEK?", "TMR?", "LSNPEEK?", "ENVSTAT?", "VENVPEEK?", "FNPEEK",
    "NAMEPEEK", "GCSNAP?", "VRING?", "IPTRACE?", "STATEHIST?", "PXCNT?",
))


class SimBackend(FinderServices, RuntimeBackend):
    name = "FPGA-SIM"

    def __init__(self) -> None:
        self._init_finder_services()
        self._proc: Optional[subprocess.Popen] = None
        self._canvas = CanvasEngine()
        self._screen = ""
        self._started = False
        self._running = False  # RTL game_mode — skip prompt overlay
        self._desktop_visible = False
        self._desktop_busy = False
        self._system_keyboard = False
        self._ui_generation = -1
        self._ui_overlays = []
        self._native_action = 0
        self._native_phase = 0
        self._more = False     # Parked on -- MORE --
        self._listing = False  # LIST/DIR until READY — no '>' between pages
        self._paging = False   # push_key already pumping — do not nest Enter
        self._editor_live = False  # interactive editor/reader uses the VM
        self._text_palette_synced = False
        self._palette_role = None
        self._typed_log: list[str] = []  # typed monitor rows; never drop them
        self._edit_prefill: Optional[str] = None
        self._loaded_name: str = ""
        self._arch_phase: str = "idle"
        self._last_cmd: str = ""
        self._html_chunk = None
        self._html_lines: list = []
        self._loaded_html_text: str = ""
        self._program_image: bytes = b""
        self._edit_waiting_line: Optional[int] = None
        self._break_run_wait: bool = False
        self._fb_logged: bool = False  # first game FB? only
        extra = ""
        if _SYNTH.is_file():
            extra = f"# rtl_mtime={_SYNTH.stat().st_mtime:.0f}\n"
        self._log = FlightLog(self.name, extra_header=extra)
        self._kev_n = 0
        self._mouse_protocol = None
        self._kev_codes: list = []
        self._play_t = 0.0
        self._play_frames = 0
        self._play_fclk: list = []
        self._log_vdraw = ""
        self._run_snap_done = False
        self._last_glass = ""
        self._more_page = 0
        # Architecture Monitor — cache VMSTAT/STATUS (no extra RPC while RUN)
        self._vmstat_raw = ""
        self._status_raw = ""
        self._vmstat_t = 0.0
        # Architecture Monitor engine heat. VMSTAT is one sample per beat and
        # a frame almost always ends parked in S_WAIT_FRAME, so a single sname
        # cannot say which engines the frame used. PROF? is the RTL's own
        # per-state cycle histogram — that is where the cycles actually went.
        self._prof_raw = ""
        self._prof_armed = False
        self._prof_ok = True   # cleared for good if this sim lacks PROF?
        self._ip_ring: list[int] = []
        self._ip_trace_ok = True
        self._image_meta: dict = {}
        self._aset_bytes = 0
        # RTL is default. Host twin ONLY via explicit JMR_SIM_HOST=1.
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
        if not self._use_rtl:
            raise RuntimeError('Finder services require RTL; use the PYTHON runtime for the host model')
        if not _SYNTH.is_file():
            self._log.fault("NO_RTL", "build: make -C sim sim_server_synth")
            raise RuntimeError("FPGA-SIM RTL missing — run: make -C sim sim_server_synth")
        if _SYNTH.resolve() == (ROOT / 'sim/sim_build_synth/jmr_js_sim_server').resolve():
            from tools.simulator_provenance import verify
            verify(ROOT, _SYNTH)
        cmd = [str(_SYNTH)]
        self._log.note(f"spawn RTL {cmd[0]}")
        env = os.environ.copy()
        env["JMR_STANDALONE"] = env.get("JMR_STANDALONE", "1")
        # Always the project card.img (sim_main prefers ../card.img from
        # sim/ cwd — a stale root image used to hide a missing HTML compile path → ?NH)
        env.setdefault("JMR_CARD_IMG", str(ROOT / "card.img"))
        # Keep stderr separate — RTL prints "SD image …" on cerr; merging
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
        # Arm the sim's rolling cycle ring (freezes on fault_code /
        # running-drop) so a play fault leaves VRING forensics in the trace.
        try:
            self._rpc("RINGSTOP -1")
        except Exception:
            pass
        if not self._use_rtl:
            raise RuntimeError('Finder services require RTL; use the PYTHON runtime for the host model')
        self._rpc("FB?")

    def _service_connected(self):
        return True  # The first request starts the selected RTL simulator.

    def _accept_service_rpc(self, response):
        parts = response.split()
        if not parts or parts[0] != 'SERVICE':
            raise RuntimeError('RTL Finder service unavailable: ' + response)
        for record in parts[1:]:
            if not self._receive_service_line(record):
                raise RuntimeError('Invalid RTL service reply')

    def _send_service_packet(self, packet):
        self._accept_service_rpc(self._rpc('SERVICE ' + packet.hex()))

    def _stream_program_image(self) -> str:
        """Stream self._program_image into the simulator and start it (tests)."""
        blob = self._program_image
        if not blob:
            return "ERR no image"
        resp = self._rpc(f"PROGBEGIN {len(blob)}")
        if not resp.startswith("OK"):
            return resp
        # 32 KiB chunks keep each RPC line bounded.
        for off in range(0, len(blob), 32768):
            resp = self._rpc(f"PROGDATA {blob[off : off + 32768].hex()}")
            if not resp.startswith("OK"):
                return resp
        return self._rpc("PROGSTART")

    def _stream_staged(self, prefix, data):
        import tempfile
        if prefix not in (0xFB, 0xFC, 0xFD):
            raise ValueError('Unsupported bulk staging service')
        try:
            with tempfile.NamedTemporaryFile(prefix='jmr-finder-', suffix='.bin') as staged:
                staged.write(data)
                staged.flush()
                self._accept_service_rpc(self._rpc(f'SERVICEBULK {prefix:02X} {staged.name}'))
        except Exception:
            self._transfer_fault = True
            raise

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
            # An optional observer probe against a sim build that predates the
            # verb answers plain "ERR". That is a missing feature, not a fault
            # — logging it would bury a real fault under one line per second.
            if (cmd.split()[0] if cmd else "") not in _OPTIONAL_VERBS:
                shown = f"{cmd.split()[0]} bytes={max(0, (len(cmd) - 9) // 2)}" \
                    if cmd.startswith("PROGDATA ") else repr(cmd)
                self._log.fault("RPC", f"cmd={shown} resp={resp!r}")
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
            "JOY", "KEYBITS", "VMSTAT?", "PROGBEGIN", "PROGDATA", "PROGSTART",
            *_OPTIONAL_VERBS,
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



    @property
    def running(self) -> bool:
        """True while a title or the canvas editor owns the glass."""
        return self._running or self._editor_live

    @property
    def more_waiting(self) -> bool:
        return False


    @property
    def edit_prefill(self):
        return None









            # wrapped continuation of EDIT body — keep scanning for 'N body'









    def _sync_native_source(self):
        reply=self._rpc("SOURCE?")
        if not reply.startswith("SOURCE name="):return
        name=reply.split("name=",1)[1].split(" bytes=",1)[0]
        if name!=self._loaded_name:
            self._loaded_name=name;self._html_chunk=None;self._html_lines=[]
            self._loaded_html_text="";self._program_image=b"";self._image_meta={};self._aset_bytes=0

    def type_line(self, text: str) -> None:
        """Compatibility adapter for host tools; never type into FPGA RAM."""
        if self._transfer_active:
            raise RuntimeError('A Finder transfer owns the tether')
        command, _, tail = text.strip().partition(' ')
        command = command.upper()
        name = tail.strip().strip('"')
        if command in ('DIR', 'CATALOG'):
            self.refresh_board_catalog()
        elif command == 'LOAD':
            from runtime.finder_tether import fat_name
            if not fat_name(name):
                raise ValueError('Select a filename')
            self._loaded_name = name
        elif command in ('RUN', 'EDIT', 'READ', 'COMPILE'):
            name = name or self._loaded_name
            if not name:
                raise ValueError('Select a program or document in Finder')
            self.launch_named(name, {'RUN': 0, 'EDIT': 1, 'READ': 2, 'COMPILE': 3}[command])
        elif command in ('HOME', 'DESKTOP'):
            self._service(Operation.ENTER_FINDER, 1, timeout=120.0)
        elif command:
            raise ValueError('Use Finder for file operations; this FPGA has no command monitor')


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

    def _card_storage(self):
        """Same card.img FPGA-SIM SPI uses ($JMR_CARD_IMG or project card.img)."""
        from functional_model.storage_engine import StorageEngine

        return StorageEngine()

    def _mirror_card_html(self, stem: str) -> None:
        """Editor mirror from the card HTML (display-only; may be squashed)."""
        st = self._card_storage()
        for name in (f"{stem}.HTM", f"{stem}.HTML"):
            try:
                text = st.load_text(name)
            except FileNotFoundError:
                continue
            self._loaded_html_text = text
            self._html_lines = text.splitlines()
            return
        self._loaded_html_text = ""
        self._html_lines = []

    def _load_card_jsh(self, stem=None, expected_ops=None) -> bool:
        """V1.0 RUN: minted NAME.JSH bytes from card.img (not a storage/ recompile)."""
        stem = stem or self._html_loaded_stem()
        if not stem:
            return False
        try:
            blob = self._card_storage().load_bytes(f"{stem}.JSH")
        except FileNotFoundError:
            self._log.fault("COMPILE", f"no {stem}.JSH on card — refuse RUN (?NH)")
            return False
        try:
            from functional_model.jsb_format import ProgramImage

            image = ProgramImage(blob)
            if expected_ops is not None and image.n_ops != expected_ops:
                return False  # Transition still exposes the previous VM header.
            try:
                self._html_chunk = image.decode()
            except Exception:
                self._html_chunk = None
            self._image_meta = {
                "n_ops": int(image.n_ops or 0),
                "n_consts": int(image.n_consts or 0),
                "n_vars": int(image.n_vars or 0),
                "flags": int(image.flags or 0),
            }
            self._aset_bytes = self._measure_aset(self._html_chunk) if self._html_chunk else 0
            self._program_image = image.data
            self._log.note(
                f"observer image {stem}.JSH ({len(blob)} bytes); execution remains in RTL"
            )
            return True
        except Exception as e:
            self._log.fault("COMPILE", str(e))
            return False







    @staticmethod
    def _measure_aset(chunk) -> int:
        """ASET payload bytes streamed to asset SRAM (0 when the title has none)."""
        palette = getattr(chunk, "palette", None)
        if not palette:
            return 0
        try:
            from functional_model.jsb_format import build_aset_payload

            payload, _descs = build_aset_payload(palette, getattr(chunk, "sprites", ()))
            return len(payload)
        except Exception:
            return 0



    def push_key(self, ch):
        if ch == '\x1b':
            self.hard_break()


    def screen_text(self) -> str:
        if not self._started:
            self._start()
        return self._screen

    def set_joy(self, bits: int) -> None:
        self._rpc(f"JOY {bits}")

    def set_key_bits(self, bits: int) -> None:
        self._rpc(f"KEYBITS {bits}")

    def set_mouse(self, x: int, y: int, buttons: int) -> bool:
        if self._mouse_protocol is None:
            self._mouse_protocol = self._use_rtl and self._rpc("MOUSE?") == "MOUSE 1"
        if not self._mouse_protocol:
            raise RuntimeError("This simulator has no mouse support; rebuild sim_server_synth.")
        return self._rpc(f"MOUSE {int(x)} {int(y)} {int(buttons) & 7}") == "OK"

    def key_event(self, key_code: int, key: str, pressed: bool) -> None:
        # Raw keyboard → RTL KEYEVT for every code. HTML decides bindings.
        # KEYBITS still tethers arrows/space; RTL skips synthetic keydown when
        # a KEYEVT is already queued (no double-fire).
        text = ord(key) if pressed and len(key) == 1 else 0
        self._rpc(f"KEYEVT {int(key_code) & 0xFF} {1 if pressed else 0} {text & 255}")

    def paint_prompt(self, prompt, cursor_on=False, cursor_col=None):
        return  # Finder owns the FPGA-SIM display.


    def hard_break(self):
        if self._transfer_active:
            raise RuntimeError('Finish or resolve the Finder transfer first')
        self._log.note('BREAK')
        self._rpc('KEY 1b')
        self._rpc('VMSTAT?')
        self._rpc('FB?')


    def framebuffer(self):
        return self._canvas

    def poll(self):
        if self._service_pending:
            self._accept_service_rpc(self._rpc('SERVICEPOLL'))


    def frame_tick(self):
        if not self._started:
            return
        if self._service_pending:
            self.poll()
        else:
            self._rpc('FRAME 500000')
        self._poll_service_status()
        status = parse_status_kv(self._rpc('STATUS?'))
        self._running = bool(status.get('vm_busy', status.get('running', 0)))
        self._arch_phase = 'run' if self._running else 'idle'
        role = parse_status_kv(self._rpc('WINDOW?')).get('role', 0)
        if role != self._palette_role:
            self._sync_palette()
            self._palette_role = role
            self._sync_native_source()
        self._desktop_status()
        self._rpc('FB?')
        now = time.monotonic()
        if now - self._vmstat_t >= 0.25:
            vm = parse_status_kv(self._rpc('VMSTAT?'))
            self._sync_native_source()
            stem = {1: 'EDITOR', 2: 'READ', 3: 'COMPILE', 4: 'UTILITY',
                    5: 'EDITOR', 9: 'FINDER'}.get(role, self._html_loaded_stem())
            key = (stem, vm.get('nops'))
            if stem and key != getattr(self, '_observer_image_key', None):
                if self._load_card_jsh(stem, vm.get('nops')):
                    self._mirror_card_html(stem)
                    self._observer_image_key = key
        # Keep existing optional inspector data available without CLI scraping.
        if now - self._play_t >= 1.0:
            self._read_ip_trace()
            self._sample_prof()
            self._play_t = now


    @property
    def system_keyboard(self):
        return self._system_keyboard

    @property
    def console_line(self):
        return ""


    def console_key(self, char):
        if int(char) == 27:
            self.hard_break()


    def _desktop_status(self):
        state = parse_status_kv(self._rpc("DESKTOP?"))
        self._desktop_visible = bool(state.get("active", 0))
        self._desktop_busy = bool(state.get("busy", 0))
        self._native_action = int(state.get("action",0))
        self._native_phase = int(state.get("state",0))
        ui = self._rpc(f"UISURFACE {self._ui_generation}").split()
        if len(ui) >= 5 and ui[0] == "UI":
            if ui[1] == "SAME":
                self._system_keyboard = ui[4] == "1"
            else:
                self._ui_generation = int(ui[1])
                self._system_keyboard = ui[3] == "1"
                self._ui_overlays = []
                for index in range(int(ui[4])):
                    p = 5+index*5
                    self._ui_overlays.append((*map(int,ui[p:p+4]),base64.b64decode(ui[p+4])))
        overlay = self._rpc("OVERLAY?").split()
        if len(overlay) == 5 and overlay[0] == "OVERLAY":
            # These RGBA pixels come from the actual RTL overlay circuit.
            self._canvas.display_overlays = self._ui_overlays + [
                (620, 0, 20, 22, base64.b64decode(overlay[3])),
                (int(overlay[1]), int(overlay[2]), 16, 16, base64.b64decode(overlay[4])),
            ]

    # How many distinct consecutive IPs to capture per frame. IPTRACE records
    # a prefix of the frame — real work, not the park it ends on.
    _IP_TRACE_N = 600

    def _read_ip_trace(self) -> None:
        if not self._ip_trace_ok:
            return
        try:
            resp = self._rpc("IPTRACE?")
        except Exception:
            self._ip_trace_ok = False
            return
        if not resp.startswith("IPS"):
            self._ip_trace_ok = False
            self._ip_ring = []
            return
        ring = []
        for tok in resp.split()[1:]:
            # `<ip>` or `<ip>:<vsp>`
            head = tok.split(":", 1)[0]
            try:
                ring.append(int(head))
            except ValueError:
                continue
        if ring:
            self._ip_ring = ring

    def _sample_prof(self) -> None:
        """Read the RTL per-state cycle histogram, then re-arm it for the next beat.

        Two RPCs per second while a game runs. PROFCLR both zeroes the
        counters and enables them, so the first beat only arms.

        A sim binary without these verbs answers "ERR". Give up permanently on
        the first refusal rather than asking again every second — the monitor
        falls back to sname-only heat and nothing else changes.
        """
        if not self._prof_ok:
            return
        try:
            if self._prof_armed:
                resp = self._rpc("PROF?")
                if not resp.startswith("PROF"):
                    self._prof_ok = False
                    self._prof_raw = ""
                    self._log.note("PROF? unsupported by this sim — sname-only heat")
                    return
                self._prof_raw = resp
            if not self._rpc("PROFCLR").startswith("OK"):
                self._prof_ok = False
                self._prof_raw = ""
                self._log.note("PROFCLR unsupported by this sim — sname-only heat")
                return
            self._prof_armed = True
        except Exception:
            self._prof_ok = False
            self._prof_raw = ""

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
        # The RTL is gone — nothing of this session may survive onto the
        # glass of the next runtime (F9 used to show the dead session's text).
        self._running = False
        self._more = False
        self._listing = False
        self._prof_raw = ""
        self._prof_armed = False
        # Re-probe after a restart: the next _start() may launch a sim binary
        # you just recompiled, which can have verbs the old one lacked.
        self._prof_ok = True
        self._ip_ring = []
        self._ip_trace_ok = True
        self._typed_log = []
        self._screen = ""
        self._canvas.front[:] = bytes(len(self._canvas.front))
        self._canvas.back[:] = bytes(len(self._canvas.back))
        self._flush_keyevts()
        self._log.note("shutdown")

    # Neutral peek name → RTL verb. `{}` slots take the caller's args.
    _PEEK_VERBS = {
        "obj": "OBJPEEK {0}",
        "arr": "ARRPEEK {0}",
        "stack": "STK?",
        "vars": "VARPEEK {0} {1}",
        "vvar": "VVARPEEK {0}",
        # SRAMPEEK addresses 16-bit words; the panel speaks bytes (so do the
        # ASET offsets in the docs). Converted in arch_peek, not here.
        "sram": "SRAMPEEK {0} {1}",
        "raf": "RAFPEEK?",
        "timers": "TMR?",
        "listeners": "LSNPEEK?",
        "env": "ENVSTAT?",
        "venv": "VENVPEEK?",
        "fn": "FNPEEK {0}",
        "name": "NAMEPEEK {0}",
        "gc": "GCSNAP?",
        "ring": "VRING?",
        "iptrace": "IPTRACE?",
        "statehist": "STATEHIST?",
        "px": "PXCNT?",
    }

    def arch_decode(self, ip) -> dict:
        return decode_ip(self._html_chunk, list(self._html_lines or []), ip)

    def arch_peek(self, what: str, *args) -> str:
        """One peek RPC, on demand, for an open inspector only.

        Never called from the frame loop — the monitor only asks while a
        drill-down is open and throttles its own refresh, so play still costs
        one FRAME per tick. A build without the verb answers "ERR"; report it
        as "no view" rather than pretending the structure is empty.
        """
        if not self._started or self._proc is None:
            return ""
        what = (what or "").lower()
        template = self._PEEK_VERBS.get(what)
        if template is None:
            return ""
        if what == "sram" and len(args) >= 2:
            # Caller passes a byte offset and a byte count, matching the ASET
            # layout in the docs and the PYTHON peek. The RTL indexes 16-bit
            # words, so the same request would otherwise read a different
            # address on each runtime.
            args = (int(args[0]) // 2, max(1, int(args[1]) // 2)) + tuple(args[2:])
        try:
            cmd = template.format(*args) if "{" in template else template
        except (IndexError, KeyError):
            return ""
        try:
            resp = self._rpc(cmd)
        except Exception:
            return ""
        if resp.startswith("ERR") or resp.startswith("FAULT"):
            return f"(this sim build has no {cmd.split()[0]})"
        return resp

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
        running = bool(self._running) or snap.get("running") in (1, "1", True)
        snap["running"] = running
        phase = self._arch_phase
        if running:
            phase = "run"
        elif phase == "idle" and self._loaded_name:
            phase = "loaded"
        snap["phase"] = phase
        snap["glass"] = self._screen or ""
        snap["hdmi_mode"] = "game" if running else "letterbox"
        snap["source_name"] = self._loaded_name or ""
        snap["last_cmd"] = self._last_cmd
        snap["more"] = bool(self._more)
        snap["catalog"] = list(self._board_catalog or [])
        snap["catalog_known"] = self._board_catalog is not None
        snap["catalog_source"] = "RTL storage"
        snap["prof"] = self._prof_raw
        snap["ip_ring"] = list(self._ip_ring)
        chunk = self._html_chunk
        src_lines = list(self._html_lines or [])
        meta = self._image_meta or {}
        snap["n_ops"] = meta.get(
            "n_ops", len(getattr(chunk, "code", None) or []) if chunk is not None else 0
        )
        snap["n_consts"] = meta.get("n_consts", 0)
        snap["n_vars"] = meta.get("n_vars", 0)
        snap["flags"] = meta.get("flags", 0)
        snap["sram_bytes"] = self._aset_bytes
        snap["n_html"] = len(src_lines)
        ip = int(snap.get("ip") or 0)
        src_line = 0
        op_lines = getattr(chunk, "op_lines", None) if chunk is not None else None
        if op_lines and 0 <= ip < len(op_lines):
            src_line = int(op_lines[ip] or 0)
        snap["src_line"] = src_line
        snap["html_line"] = (
            src_lines[src_line - 1][:88] if src_line and 0 < src_line <= len(src_lines)
            else ""
        )
        snap["code_window"] = fmt_code_window(chunk, ip) if chunk is not None else ""
        snap["html_window"] = fmt_html_window(
            src_lines, src_line or (1 if src_lines else 0),
        )
        # VMSTAT carries no opcode byte, but the RTL executes this very image
        # and reports the IP it is parked on — so the op is knowable exactly.
        # Deriving it here keeps the DISPATCH caption and the sequencer's own
        # disassembly from naming two different instructions.
        op_name, op_arg, native_name, native_id = decode_op_at(chunk, ip)
        snap["op_name"] = op_name
        snap["op_arg"] = op_arg
        snap["native_name"] = native_name
        snap["native_id"] = native_id
        if phase == "compile":
            snap["sname"] = "COMPILE"
        elif phase == "load":
            snap["sname"] = "LOAD"
        elif phase == "loaded" and not running:
            snap["sname"] = "LOADED"
        return snap
