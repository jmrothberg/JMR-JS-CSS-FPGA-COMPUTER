"""BOARD backend — USB tether on the PROG cable mirrors HDMI glass into the GUI.

BASIC / T100 method: one USB cable does JTAG and the console mirror.
On Nexys Video the PROG jack's FT2232 channel A is an FT245 FIFO (DPTI), not a
UART — the bitstream speaks that FIFO, and Linux still exposes it as a tty
(VCP). Bytes are:

  S<rowhex>:<64 chars>\\n   — text console (64×16), letterboxed like HDMI
  P<rr>:<160 hex nibbles>\\n — mini-FB row (160×120) scaled ×4 → 640×480
  K\\n                      — PS/2 scancode strobe (J15 keyboard proof)
  V<st2><fault2><ip4>\\n    — VM heartbeat (casestate/fault/ip). Emitted per
                            dump and on every machine_fault rise; present from
                            run 46 (2b0f1f3). Still optional — older bits do
                            not send it, so parse defensively, never require.
  D<hh>\\n                  — storage stall telemetry (stor_state) after ~0.67s
                            of continuous storage busy, then every ~0.17s.
  H<8 hex>\\n               — run-60+: live {env,arr,obj} pool counts, beside
                            every V heartbeat (background scan, ~20us refresh).
  F<16 hex>\\n              — run-60+: at-fault forensics {kind,retried,state,
                            vcsp,vsp}+{env,arr,obj at fault}, once per
                            machine_fault rise.
  T<32 hex>\\n              — run-60+: last 8 committed ips, newest first,
                            once per machine_fault rise.

Port autodetect: JMR_JS_SERIAL env wins; otherwise FT2232 (pid 0x6010) channel A
(location ".0") — channel B is JTAG. Optional FT232R on J13 is a fallback only.
"""

from __future__ import annotations

import os
import re
import struct
import time
from pathlib import Path
from typing import Optional

from functional_model.canvas_engine import (
    CONSOLE_COLS,
    CONSOLE_ROWS,
    CanvasEngine,
)
from runtime.backend import ROOT, RuntimeBackend, card_catalog
from runtime.flight_log import FlightLog

# Board char VRAM geometry (jmr_video_vram / jmr_uart_link dump)
_MIRROR_COLS = CONSOLE_COLS
_MIRROR_ROWS = CONSOLE_ROWS

_FB_W = 160
_FB_H = 120
_FB_SCALE = 4  # → 640×480

_HINT = "\n".join([
    "BOARD RUNTIME - NO TETHER",
    "",
    "NO PROG USB-SERIAL PORT FOUND.",
    "THE BOARD'S SCREEN IS THE HDMI MONITOR.",
    "",
    "CHECKLIST:",
    "- PROG MICRO-USB CABLE (J12) — SAME AS T100",
    "- PLAY KEYS = GUI ARROWS+SPACE (J15 USB HOST DEAD)",
    "- JP4 = BOOT SOURCE ONLY (NOT KEYBOARD)",
    "- 'DONE' LED LIT = FPGA CONFIGURED",
    "- LD7 BLINKS ON USB SCANCODE (J15) IF FIXED",
    "",
    "F9 -> FPGA-SIM (RTL) = SAME CORE, MIRRORED HERE.",
])

_ROW_RE = re.compile(r"^S([0-9A-Fa-f]):(.*)$")
_FB_RE = re.compile(r"^P([0-9A-Fa-f]{2}):([0-9A-Fa-f]*)$")

# Lockstep with sim/sim_main.cpp vm_sname[] / jmr_js_vm.sv st_t (append-only).
# Unknown index → S_<hex>; never raise. Host-only: RTL V line may not exist yet.
_VM_SNAME = (
    "S_IDLE", "S_RD", "S_GOT_MAGIC", "S_GOT_HDR1", "S_GOT_HDR2", "S_LD_CONST",
    "S_TRAIL", "S_FETCH_WAIT", "S_EXEC", "S_NAT", "S_CLEAR", "S_RECT", "S_CIRCLE",
    "S_LINE", "S_BLIT", "S_SPR", "S_WAIT_FRAME", "S_DONE", "S_XF_MUL", "S_XF_APPLY",
    "S_PWALK", "S_PDO", "S_QSEG", "S_QPX", "S_QPY", "S_JOIN", "S_JOIN_FIND",
    "S_IDXOF", "S_CONCAT", "S_SQRT", "S_DIV", "S_DIV_FIN", "S_MUL", "S_MUL_WR",
    "S_ALU", "S_ALU_WR", "S_CALL", "S_FOREACH", "S_KEYEV", "S_ENV_LOAD",
    "S_JSON", "S_JSON_PARSE", "S_REPL", "S_IDXSTR", "S_STRIDX", "S_STRIDX_WR",
    "S_FONTPX", "S_TXT_LD", "S_TXT_DRAW", "S_STR_WR", "S_IMGD_GET", "S_IMGD_PUT",
    "S_NAMCPY", "S_ARR_DCOPY",
    "S_GC_CLEAR", "S_GC_ROOT", "S_GC_POP", "S_GC_OBJ", "S_GC_ARR",
    "S_V64_CONST_HI", "S_V64_EXEC", "S_V64_DIV", "S_V64_DIV_FIN", "S_V64_MOD",
    "S_V64_ALLOC", "S_V64_GC_CLEAR", "S_V64_GC_ROOT", "S_V64_GC_POP",
    "S_V64_GC_OBJ", "S_V64_GC_ARR", "S_V64_GC_SWEEP_OBJ",
    "S_V64_GC_SWEEP_ARR", "S_V64_GC_FN", "S_V64_GC_ENV",
    "S_V64_GC_SWEEP_ENV", "S_V64_CLEAR", "S_V64_RECT",
    "S_V64_WAIT_FRAME", "S_V64_FRAME_RAF", "S_V64_FRAME_TIMER",
    "S_V64_FOREACH", "S_V64_FRAME_KEY", "S_V64_STRIDX", "S_V64_STRIDX_WR",
    "S_V64_JSON", "S_V64_JSON_PARSE", "S_V64_CTOR_PAD",
    "S_HEAP_WAIT", "S_HEAP_CMP", "S_HEAP_WR", "S_HEAP_AWR", "S_HEAP_FILL",
    "S_V64_METH", "S_V64_FE_ELEM", "S_V64_FE_FILTER", "S_V64_OGETI_NAT",
    "S_V64_IDXSCAN", "S_V64_CTOR_ENV", "S_V64_CTOR_VARS", "S_REL_ENV",
    "S_FREE_OBJ", "S_FREE_ARR",
    "S_V64_BIND", "S_V64_MINMAX", "S_V64_WIN_FILL", "S_ARR_PROMOTE",
    "S_V64_RECT_LD", "S_HEAP_CLR",
    "S_V64_SLICE", "S_V64_SORT", "S_FB_SYNC", "S_V64_DISPATCH",
)


def _vm_sname(st: int) -> str:
    if isinstance(st, int) and 0 <= st < len(_VM_SNAME):
        return _VM_SNAME[st]
    try:
        return f"S_{int(st) & 0xFF:02X}"
    except (TypeError, ValueError):
        return "S_??"


def _parse_vm_v_line(line: str):
    """Parse optional `V<st2><fault2><ip4>`. None if missing/torn. Never raises."""
    if not isinstance(line, str) or not line or (line[0] != "V" and line[0] != "v"):
        return None
    body = line[1:].strip()
    if len(body) < 8:
        return None
    hex8 = body[:8]
    try:
        int(hex8, 16)
    except ValueError:
        return None
    try:
        return (int(hex8[0:2], 16), int(hex8[2:4], 16), int(hex8[4:8], 16))
    except (TypeError, ValueError):
        return None


def _parse_heap_hex8(hex8: str):
    """Unpack a 32-bit {env[9:0], arr[10:0], obj[10:0]} hex8 word. None if bad."""
    try:
        val = int(hex8, 16)
    except ValueError:
        return None
    obj = val & 0x7FF
    arr = (val >> 11) & 0x7FF
    env = (val >> 22) & 0x3FF
    return (env, arr, obj)


_FAULT_KIND_NAME = {0: "obj", 1: "arr", 2: "fn", 3: "env"}


def _parse_h_line(line: str):
    """Parse `H<8 hex>` — live {env,arr,obj} pool counts. None if missing/torn."""
    if not isinstance(line, str) or not line or line[0] not in ("H", "h"):
        return None
    body = line[1:].strip()
    if len(body) < 8:
        return None
    return _parse_heap_hex8(body[:8])


def _parse_f_line(line: str):
    """Parse `F<16 hex>` — at-fault forensics snapshot. None if missing/torn.

    Layout (docs/ARCH_MONITOR.md): first 8 hex = {kind2,retried1,state7,
    vcsp8,vsp12,00} packed MSB-first; last 8 hex = {env10,arr11,obj11} at
    the moment of fault (same packing as the H-line).
    """
    if not isinstance(line, str) or not line or line[0] not in ("F", "f"):
        return None
    body = line[1:].strip()
    if len(body) < 16:
        return None
    try:
        head = int(body[:8], 16)
    except ValueError:
        return None
    pools = _parse_heap_hex8(body[8:16])
    if pools is None:
        return None
    vsp = (head >> 2) & 0xFFF
    vcsp = (head >> 14) & 0xFF
    state = (head >> 22) & 0x7F
    retried = bool((head >> 29) & 0x1)
    kind = (head >> 30) & 0x3
    env, arr, obj = pools
    return {
        "kind": kind,
        "kind_name": _FAULT_KIND_NAME.get(kind, "?"),
        "retried": retried,
        "state": state,
        "vcsp": vcsp,
        "vsp": vsp,
        "env": env,
        "arr": arr,
        "obj": obj,
    }


def _parse_t_line(line: str):
    """Parse `T<32 hex>` — last 8 committed ips, newest first. None if torn."""
    if not isinstance(line, str) or not line or line[0] not in ("T", "t"):
        return None
    body = line[1:].strip()
    if len(body) < 32:
        return None
    hex32 = body[:32]
    try:
        int(hex32, 16)
    except ValueError:
        return None
    return [int(hex32[i * 4:(i + 1) * 4], 16) for i in range(8)]


def _find_serial_port() -> Optional[str]:
    env_port = os.environ.get("JMR_JS_SERIAL", "").strip()
    if env_port:
        return env_port
    try:
        from serial.tools import list_ports
    except ImportError:
        return None
    # PROG FT2232 (pid 0x6010): ch A (".0") = DPTI FIFO tether, ch B (".1") =
    # JTAG (openFPGALoader board nexysVideo uses cable digilent_b = channel B).
    # VERIFIED on silicon 2026-08-12: S-rows stream on the ".0" interface.
    ftdi = [p for p in list_ports.comports() if p.vid == 0x0403]
    for p in ftdi:
        if p.pid == 0x6010 and (p.location or "").endswith(".0"):
            return p.device
    for p in ftdi:
        if p.pid == 0x6010 and not (p.location or "").endswith(".1"):
            return p.device
    for p in ftdi:
        if p.pid == 0x6001:
            return p.device
    return None


class BoardBackend(RuntimeBackend):
    name = "BOARD"

    def __init__(self) -> None:
        self._ser = None
        self._rows = [""] * _MIRROR_ROWS
        self._rx_buf = b""
        self._canvas = CanvasEngine()
        self._prompt = "> "
        self._log = FlightLog(self.name)
        # NEW: mini-FB mirror (game_mode P-rows) — full 640×480 after ×4 scale
        self._fb = bytearray(_FB_W * _FB_H)
        self._have_fb = False
        self._ps2_strobes = 0
        self._loaded_name = ""
        # Optional RTL V-line sample. Stay None until a well-formed V arrives
        # so today's bitstream (no V) keeps F10 on board_coarse / no VMSTAT.
        self._vm_st = None
        self._vm_fault = None
        self._vm_ip = None
        self._vm_logged = None  # (st, fault) last NOTE — change-only, no spam
        # Optional run-60+ H/F/T telemetry (docs/ARCH_MONITOR.md). Stay None
        # until a well-formed line arrives so older bits keep dashed fields.
        self._heap_live = None  # (env, arr, obj) from the H-line
        self._fault_snap = None  # dict from the F-line
        self._fault_ip_trail = None  # list[8] from the T-line
        # Last K-line arrival (monotonic) — board-keyboard keystroke proof
        # for the Architecture Monitor's Keyboard block heat.
        self._kbd_last_t: Optional[float] = None
        port = _find_serial_port()
        if port:
            try:
                import serial

                self._ser = serial.Serial(port, 115200, timeout=0.05)
                self._log.note(f"open {port}")
            except Exception as e:
                self._ser = None
                self._log.fault("SERIAL", str(e))
        else:
            self._log.note("no UART port found (HDMI-only BOARD)")

    @property
    def available(self) -> bool:
        return True

    def poll(self) -> None:
        if self._ser is None:
            return
        try:
            n = self._ser.in_waiting
            if n:
                self._rx_buf += self._ser.read(n)
        except Exception as e:
            self._log.fault("SERIAL", str(e))
            self._ser = None
            return
        # 2026-08-27: host RX heartbeat — every ~3s log how many tether
        # bytes arrived. Distinguishes "board TX went silent" (rx=+0) from
        # "GUI stopped polling" (no TETHER lines at all) — the DIR-freeze
        # flight log ended at TYPE dir with neither side identifiable.
        now = time.monotonic()
        self._rx_total = getattr(self, "_rx_total", 0) + (n or 0)
        last = getattr(self, "_rx_beat_t", 0.0)
        if now - last >= 3.0:
            self._rx_beat_t = now
            delta = self._rx_total - getattr(self, "_rx_beat_total", 0)
            self._rx_beat_total = self._rx_total
            self._log.note(f"TETHER rx=+{delta}B")
        while b"\n" in self._rx_buf:
            raw, self._rx_buf = self._rx_buf.split(b"\n", 1)
            line = raw.decode("ascii", errors="replace").rstrip("\r")
            if len(line) == 3 and line[0] == "D":
                # storage stalled >0.67s in one state - names the wedge
                self._log.note(f"STOR-STALL state=0x{line[1:]}")
                continue
            if line and line[0] == "E" and len(line) in (3, 5):
                # free-running storage(+console)-state beat (change-only log).
                # len 3 = run-48 bits (stor only); len 5 = run-49+ (stor+cons)
                if line[1:] != getattr(self, "_stor_beat", None):
                    self._stor_beat = line[1:]
                    tag = f"stor=0x{line[1:3]}"
                    if len(line) == 5:
                        tag += f" cons=0x{line[3:5]}"
                    self._log.note(f"STOR-BEAT {tag}")
                continue
            if line == "K" or (len(line) == 3 and line[0] == "K"):
                # K or Kxx (scancode hex, 2026-08-25 arrows debug)
                # NEW: USB Host scancode reached RTL (ps2_strobe)
                self._ps2_strobes += 1
                # Keystroke evidence for the Architecture Monitor's Keyboard
                # block. On BOARD the keyboard plugs into the board itself,
                # so GUI key events never see these — the K-line is the ONLY
                # proof a keystroke reached the RTL.
                self._kbd_last_t = time.monotonic()
                self._log.note(f"ps2_strobe n={self._ps2_strobes} code={line[1:] or '??'}")
                continue
            # Optional run-60+ heap gauge / fault forensics. Malformed or
            # absent → ignore (older bits never send these).
            parsed_h = _parse_h_line(line)
            if parsed_h is not None:
                self._heap_live = parsed_h
                continue
            parsed_f = _parse_f_line(line)
            if parsed_f is not None:
                self._fault_snap = parsed_f
                self._log.note(
                    f"FAULT kind={parsed_f['kind_name']} retried={parsed_f['retried']} "
                    f"state=0x{parsed_f['state']:02X} vcsp={parsed_f['vcsp']} "
                    f"vsp={parsed_f['vsp']} env={parsed_f['env']} arr={parsed_f['arr']} "
                    f"obj={parsed_f['obj']}"
                )
                continue
            parsed_t = _parse_t_line(line)
            if parsed_t is not None:
                self._fault_ip_trail = parsed_t
                continue
            # Optional VM heartbeat. Malformed / absent → ignore (old bits).
            parsed_v = _parse_vm_v_line(line)
            if parsed_v is not None:
                st, fault, ip = parsed_v
                self._vm_st = st
                self._vm_fault = fault
                self._vm_ip = ip
                key = (st, fault)
                if key != self._vm_logged:
                    self._vm_logged = key
                    try:
                        self._log.note(
                            f"VM st={_vm_sname(st)} fault={fault} ip={ip:04X}"
                        )
                    except Exception:
                        pass
                continue
            m = _ROW_RE.match(line)
            if m:
                self._rows[int(m.group(1), 16)] = m.group(2)
                self._have_fb = False
                continue
            fm = _FB_RE.match(line)
            if fm:
                row = int(fm.group(1), 16)
                hexpix = fm.group(2)
                if 0 <= row < _FB_H and len(hexpix) >= _FB_W:
                    base = row * _FB_W
                    for x in range(_FB_W):
                        self._fb[base + x] = int(hexpix[x], 16) & 0xF
                    self._have_fb = True

    def frame_tick(self) -> None:
        # Board directive 2026-08-25: the GUI must never die mid-session
        # while the board keeps running (a crashed GUI stops forwarding
        # keystrokes and masquerades as a dead board console). Any parser
        # or paint surprise logs a fault and drops the rx buffer to
        # resync instead of propagating.
        try:
            self.poll()
            self._paint_mirror()
        except Exception as e:
            self._log.fault("GUI_TICK", repr(e))
            self._rx_buf = b""

    def _prompt_row(self) -> int:
        for r in range(_MIRROR_ROWS - 1, -1, -1):
            if self._rows[r].startswith(">"):
                return r
        return _MIRROR_ROWS - 1

    def _paint_fb_scaled(self) -> None:
        """Mini 160×120 → full 640×480 (same ×4 as HDMI game scanout)."""
        front = self._canvas.front
        w = self._canvas.width
        for fy in range(_FB_H):
            src = fy * _FB_W
            for fx in range(_FB_W):
                pix = self._fb[src + fx]
                x0 = fx * _FB_SCALE
                y0 = fy * _FB_SCALE
                for dy in range(_FB_SCALE):
                    base = (y0 + dy) * w + x0
                    for dx in range(_FB_SCALE):
                        front[base + dx] = pix

    def _paint_mirror(self) -> None:
        """Rasterize tether into full 640×480 glass (shared HDMI letterbox)."""
        if self._ser is None:
            self._canvas.clear_front(0)
            for i, line in enumerate(_HINT.splitlines()[:25]):
                self._canvas.draw_text_front(2, 2 + i, line[:76], 3)
            return
        if self._have_fb:
            self._canvas.clear_front(0)
            self._paint_fb_scaled()
            return
        if not any(self._rows):
            self._canvas.clear_front(0)
            self._canvas.draw_text_front(2, 2, "HDMI MONITOR IS THE SCREEN", 3)
            self._canvas.draw_text_front(2, 4, "TYPE ON THE USB KEYBOARD IN J15", 3)
            self._canvas.draw_text_front(2, 6, "JP4=BOOT SOURCE ONLY — NOT KEYBOARD", 3)
            self._canvas.draw_text_front(2, 8, "LD6 ON=PS/2 CLK IDLE; LD7=SCANCODE", 3)
            return
        rows = [r.rstrip() for r in self._rows]
        pr = self._prompt_row()
        # paint_console_letterbox wraps/truncates; pass exact 16 VRAM rows
        self._canvas.clear_front(0)
        for r in range(_MIRROR_ROWS):
            text = rows[r] if r < len(rows) else ""
            for c, ch in enumerate(text[:_MIRROR_COLS]):
                color = 5 if r == pr else 3
                ch_out = ch
                if r == pr and c < len(self._prompt):
                    ch_out = self._prompt[c]
                elif r == pr and c >= len(self._prompt.rstrip()):
                    # keep board row under overlay past prompt
                    ch_out = ch if ch else " "
                self._canvas.draw_console_char(c, r, ch_out if ch_out else " ", color)
        # Ensure prompt chars visible
        for c, ch in enumerate(self._prompt[:_MIRROR_COLS]):
            self._canvas.draw_console_char(c, pr, ch, 5)

    def type_line(self, text: str) -> None:
        self._log.type_line(text)
        self._prompt = "> "
        if self._ser is None:
            return
        stripped = text.strip()
        upper = stripped.upper()
        if upper.startswith("LOAD"):
            self._loaded_name = stripped[4:].strip().strip('"').strip("'")
        try:
            # HTML RUN: host-compile current HTML, type RUN, PROG-stream bytes.
            # Card stays HTML-only.
            if upper == "RUN" or upper.startswith("RUN "):
                if self._html_loaded_stem():
                    blob = self._compile_html_blob()
                    if not blob:
                        return
                    self._ser.write((text + "\n").encode("ascii", errors="replace"))
                    self._ser.flush()
                    time.sleep(0.05)
                    self._ser.write(bytes([0xFD]) + struct.pack("<I", len(blob)))
                    mv = memoryview(blob)
                    for i in range(0, len(blob), 16384):
                        self._ser.write(mv[i : i + 16384])
                    self._ser.flush()
                    self._log.note(f"PROG ProgramImage stream {len(blob)} bytes")
                    return
            self._ser.write((text + "\n").encode("ascii", errors="replace"))
            self._ser.flush()
        except Exception as e:
            self._log.fault("SERIAL", str(e))

    def _html_loaded_stem(self) -> str:
        name = (self._loaded_name or "").upper()
        if name.endswith(".HTML") or name.endswith(".HTM"):
            return Path(name).stem[:8]
        return ""

    def _compile_html_blob(self) -> bytes:
        """Host compile-on-RUN for BOARD. Empty if not HTML (tiny .JS keeps FAT .JSB)."""
        stem = self._html_loaded_stem()
        if not stem:
            return b""
        html_path = ROOT / "storage" / f"{stem}.HTML"
        if not html_path.is_file():
            self._log.fault("COMPILE", f"no {html_path.name} — refuse RUN")
            return b""
        try:
            from functional_model.compiler import CompileError
            from tools.compile_js import compile_html_text, encode_html_chunk

            html = html_path.read_text(encoding="utf-8")
            blob = encode_html_chunk(compile_html_text(html))
            self._log.note(f"compile-on-RUN {html_path.name} ({len(blob)} bytes, PROG stream)")
            return blob
        except CompileError as e:
            where = f" LINE {e.line}" if e.line else ""
            self._log.fault("COMPILE", f"ERROR{where}: {e.message}")
            return b""
        except Exception as e:
            self._log.fault("COMPILE", str(e))
            return b""

    def paint_prompt(self, prompt: str, cursor_on: bool = False, cursor_col=None) -> None:
        self._prompt = prompt
        self._paint_mirror()

    def hard_break(self) -> None:
        self._log.note("BREAK")
        if self._ser is not None:
            try:
                self._ser.write(b"\x1b")
            except Exception:
                pass

    def screen_text(self) -> str:
        if self._ser is None:
            return _HINT
        return "\n".join(self._rows)

    def set_joy(self, bits: int) -> None:
        # NEW: same wire as KEYBITS — board joy_in was hardwired 0
        self.set_key_bits(bits)

    def set_key_bits(self, bits: int) -> None:
        """GUI arrows/Space → PROG tether → RTL joy_in (J15 USB host is dead)."""
        if self._ser is None:
            return
        try:
            # 0xFE prefix + 6-bit play field (matches jmr_uart_link joy_cmd)
            self._ser.write(bytes([0xFE, bits & 0x3F]))
            self._ser.flush()
        except Exception as e:
            self._log.fault("KEYBITS", str(e))

    def framebuffer(self):
        return self._canvas

    def trace_path(self) -> Optional[Path]:
        return self._log.path

    def shutdown(self) -> None:
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass

    def arch_snapshot(self) -> dict:
        """BOARD tether snapshot — coarse until an optional V line arrives."""
        running = bool(self._have_fb)
        try:
            glass = self.screen_text()[-800:]
        except Exception:
            glass = ""
        try:
            catalog = card_catalog()
        except Exception:
            catalog = []
        snap = {
            "running": running,
            "sname": "RUN" if running else "IDLE",
            "hdmi_mode": "game" if running else "letterbox",
            "glass": glass,
            "board_coarse": True,
            "tether": self._ser is not None,
            "catalog": catalog,
            "more": False,
        }
        # V line present (new bit): F10 gets real sname/ip/fault. No V: leave
        # board_coarse so the monitor still says "no VMSTAT" instead of zeros.
        if self._vm_st is not None:
            snap["sname"] = _vm_sname(self._vm_st)
            snap["ip"] = self._vm_ip
            snap["fault"] = self._vm_fault
            snap["board_coarse"] = False
        # Board-keyboard keystrokes (K-lines) — lights the Architecture
        # Monitor's Keyboard block. GUI-side key events can't cover this
        # runtime: the keyboard is plugged into the board, not the host.
        if self._kbd_last_t is not None:
            snap["kbd_last_t"] = self._kbd_last_t
        # Run-60+ H-line: live pool counts. Reuses the same keys PYTHON/
        # FPGA-SIM already populate so _inspect_heap() needs no changes.
        if self._heap_live is not None:
            env, arr, obj = self._heap_live
            snap["envl"] = env
            snap["arr"] = arr
            snap["obj"] = obj
        # Run-60+ F/T-line: at-fault forensics, BOARD-specific field names
        # (distinct from PYTHON/FPGA-SIM's fsite/badst/heapovf vocabulary,
        # which mean something more precise there and would be misleading
        # to overload with this coarser hardware snapshot).
        if self._fault_snap is not None:
            snap["board_fault_kind"] = self._fault_snap["kind"]
            snap["board_fault_kind_name"] = self._fault_snap["kind_name"]
            snap["board_fault_retried"] = self._fault_snap["retried"]
            snap["board_fault_state"] = self._fault_snap["state"]
            snap["board_fault_vcsp"] = self._fault_snap["vcsp"]
            snap["board_fault_vsp"] = self._fault_snap["vsp"]
            snap["board_fault_env"] = self._fault_snap["env"]
            snap["board_fault_arr"] = self._fault_snap["arr"]
            snap["board_fault_obj"] = self._fault_snap["obj"]
        if self._fault_ip_trail is not None:
            snap["board_ip_trail"] = self._fault_ip_trail
        return snap
