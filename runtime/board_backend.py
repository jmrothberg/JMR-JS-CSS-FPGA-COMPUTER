"""BOARD backend — USB tether on the PROG cable mirrors HDMI glass into the GUI.

BASIC / T100 method: one USB cable does JTAG and the console mirror.
On Nexys Video the PROG jack's FT2232 channel A is an FT245 FIFO (DPTI), not a
UART — the bitstream speaks that FIFO, and Linux still exposes it as a tty
(VCP). Bytes are:

  S<rowhex>:<64 chars>\\n   — text console (64×16), letterboxed like HDMI
  (P<rr>: framebuffer pixel rows — no longer sent since build 96; see
   `git show 09088a7:archive/rtl/fb_dump/README.md`. The picture is on HDMI only.)
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
import time
from pathlib import Path
from typing import Optional

from functional_model.canvas_engine import (
    CONSOLE_COLS,
    CONSOLE_ROWS,
    CanvasEngine,
)
from runtime.backend import ROOT, RuntimeBackend
from runtime.flight_log import FlightLog
from runtime.finder_tether import FinderServices, Operation

# Board char VRAM geometry (jmr_video_vram / jmr_uart_link dump)
_MIRROR_COLS = CONSOLE_COLS
_MIRROR_ROWS = CONSOLE_ROWS

# The board no longer sends the P<rr> framebuffer pixel rows since build 96
# (removed for timing); see `git show 09088a7:archive/rtl/fb_dump/README.md`. The GUI shows the
# S-row text mirror instead and never waits for pixels.

_HINT = "\n".join([
    "BOARD RUNTIME - NO TETHER",
    "",
    "NO PROG USB-SERIAL PORT FOUND.",
    "THE BOARD'S SCREEN IS THE HDMI MONITOR.",
    "",
    "CHECKLIST:",
    "- PROG MICRO-USB CABLE (J12) — SAME AS T100",
    "- KEYBOARD ON J15; GUI ARROWS+SPACE ALSO PLAY",
    "- JP4 = BOOT SOURCE ONLY (NOT KEYBOARD)",
    "- 'DONE' LED LIT = FPGA CONFIGURED",
    "- LD7 BLINKS ON EACH J15 SCANCODE",
    "",
    "F9 -> FPGA-SIM (RTL) = SAME CORE, MIRRORED HERE.",
])

_ROW_RE = re.compile(r"^S([0-9A-Fa-f]):(.*)$")

# Lockstep with sim/sim_main.cpp vm_sname[] / jmr_js_vm.sv st_t (append-only).
# Unknown index → S_<hex>; never raise. Host-only: RTL V line may not exist yet.
from runtime.vm_state_names import VM_STATE_NAMES as _VM_SNAME



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


def _parse_g_line(line: str):
    """Parse `G<12 hex>` — {fault_site16, fault_arg32}: the RTL site id that
    faulted and the value it refused (an index or an unknown native id).
    None if missing/torn (older bits never send G)."""
    if not isinstance(line, str) or not line or line[0] not in ("G", "g"):
        return None
    body = line[1:].strip()
    if len(body) < 12:
        return None
    try:
        v = int(body[:12], 16)
    except ValueError:
        return None
    site = (v >> 32) & 0xFFFF
    arg = v & 0xFFFFFFFF
    arg_signed = arg - 0x100000000 if arg & 0x80000000 else arg
    return {"fsite": site, "arg": arg, "arg_signed": arg_signed}


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
    # VERIFIED on silicon: S-rows stream on the ".0" interface.
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


class BoardBackend(FinderServices, RuntimeBackend):
    name = "BOARD"

    def __init__(self) -> None:
        self._ser = None
        self._init_finder_services()
        self._rows = [""] * _MIRROR_ROWS
        self._rx_buf = b""
        self._canvas = CanvasEngine()
        self._log = FlightLog(self.name)
        self._ps2_strobes = 0
        self._loaded_name = ""
        # Optional RTL V-line sample. Stay None until a well-formed V arrives
        # so today's bitstream (no V) keeps F10 on board_coarse / no VMSTAT.
        self._vm_st = None
        self._vm_fault = None
        self._vm_ip = None
        self._vm_logged = None  # (st, fault) last NOTE — change-only, no spam
        # Optional H/F/T telemetry. Stay None
        # until a well-formed line arrives so older bits keep dashed fields.
        self._heap_live = None  # (env, arr, obj) from the H-line
        self._fault_snap = None  # dict from the F-line
        self._fault_gsnap = None  # dict from the G-line (fsite + faulting value)
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
        # Host RX heartbeat — every ~3s log how many tether
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
            if self._receive_service_line(line):
                continue
            if len(line) == 3 and line[0] == "D":
                # storage stalled >0.67s in one state - names the wedge
                self._log.note(f"STOR-STALL state=0x{line[1:]}")
                continue
            if line and line[0] == "E" and len(line) in (3, 5, 9):
                # free-running storage(+console)-state beat (change-only log).
                # len 3 = stor only; len 5 = stor+cons;
                # len 9 = + op duration, x256 clocks, saturating)
                if line[1:5] != getattr(self, "_stor_beat", None):
                    self._stor_beat = line[1:5]
                    tag = f"stor=0x{line[1:3]}"
                    if len(line) >= 5:
                        tag += f" cons=0x{line[3:5]}"
                    if len(line) == 9:
                        try:
                            tag += f" op_ms={int(line[5:9], 16) * 256 / 100000.0:.2f}"
                        except ValueError:
                            pass
                    self._log.note(f"STOR-BEAT {tag}")
                continue
            if line == "K" or (len(line) == 3 and line[0] == "K"):
                # K or Kxx
                # USB Host scancode reached RTL (ps2_strobe)
                self._ps2_strobes += 1
                # Keystroke evidence for the Architecture Monitor's Keyboard
                # block. On BOARD the keyboard plugs into the board itself,
                # so GUI key events never see these — the K-line is the ONLY
                # proof a keystroke reached the RTL.
                self._kbd_last_t = time.monotonic()
                self._log.note(f"ps2_strobe n={self._ps2_strobes} code={line[1:] or '??'}")
                continue
            # Optional heap gauge / fault forensics. Malformed or
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
            parsed_g = _parse_g_line(line)
            if parsed_g is not None:
                self._fault_gsnap = parsed_g
                self._log.note(
                    f"GSITE fsite={parsed_g['fsite']} "
                    f"arg={parsed_g['arg_signed']} (0x{parsed_g['arg']:08X})"
                )
                continue
            parsed_t = _parse_t_line(line)
            if parsed_t is not None:
                self._fault_ip_trail = parsed_t
                self._log.note(
                    "TRAIL " + " ".join(f"{ip:04X}" for ip in parsed_t)
                )
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
                continue  # Historical text telemetry never takes display ownership.
            # P<rr> pixel rows: not sent since build 96
            # (`git show 09088a7:archive/rtl/fb_dump/README.md`); other lines are ignored.

    def frame_tick(self) -> None:
        # Board directive: the GUI must never die mid-session
        # while the board keeps running (a crashed GUI stops forwarding
        # keystrokes and masquerades as a dead board console). Any parser
        # or paint surprise logs a fault and drops the rx buffer to
        # resync instead of propagating.
        try:
            self.poll()
            self._poll_service_status()
            self._paint_mirror()
        except Exception as e:
            self._log.fault("GUI_TICK", repr(e))
            self._rx_buf = b""

    def _paint_mirror(self) -> None:
        """Show the board's text rows; the picture itself is on HDMI.

        The board stopped sending framebuffer pixels in build 96
        (`git show 09088a7:archive/rtl/fb_dump/README.md`), so there is nothing to wait for.
        """
        self._canvas.clear_front(0)
        if self._ser is None:
            for i, line in enumerate(_HINT.splitlines()[:25]):
                self._canvas.draw_text_front(2, 2 + i, line[:76], 3)
            return
        self._canvas.draw_text_front(2, 2, "BOARD PICTURE IS ON HDMI (NO PIXEL MIRROR SINCE BUILD 96)", 3)
        for i, line in enumerate(self._rows[:_MIRROR_ROWS]):
            self._canvas.draw_text_front(2, 4 + i, line[:76], 3)

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
            # A jmr:spr title whose .ARTX/.ART sidecar is gone
            # compiled fine with the art silently dropped; the board then
            # faulted inside the running game and the GUI sat in "running"
            # with a dead console. Refuse loudly instead.
            if "jmr:spr" in html:
                sib = [html_path.with_suffix(".ARTX"), html_path.with_suffix(".ART")]
                if not any(q.is_file() for q in sib):
                    self._log.fault(
                        "COMPILE",
                        f"{html_path.stem}: jmr:spr sprites but no {html_path.stem}.ARTX/.ART — RUN refused",
                    )
                    self._rows[-1] = f"?NO ART {html_path.stem}.ARTX"
                    return b""
            blob = encode_html_chunk(
                compile_html_text(html, source_path=html_path)
            )
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
        # The shared GUI also supports developer runtimes. BOARD has Finder.
        return

    def hard_break(self) -> None:
        self._log.note("BREAK")
        if self._transfer_active:
            raise RuntimeError('Finish or resolve the file transfer before leaving Finder')
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
        # GUI stick bits share the tether joy word with the Pmod stick.
        self.set_key_bits(bits)

    def set_key_bits(self, bits: int) -> None:
        """GUI arrows/Space → PROG tether → RTL joy_in (J15 USB host is dead)."""
        if self._ser is None or self._transfer_active:
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

    @property
    def more_waiting(self) -> bool:
        return False  # Board directory results are typed catalog records.

    def shutdown(self) -> None:
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass

    def arch_snapshot(self) -> dict:
        """BOARD tether snapshot — coarse until an optional V line arrives."""
        state = self._service_snapshot
        running = bool(state and state['running'])
        glass = self.screen_text()[-800:]
        catalog = list(self._board_catalog) if self._board_catalog is not None else []
        snap = {
            "running": running,
            "sname": ("RUN" if running else "IDLE") if state is not None else "UNKNOWN",
            "hdmi_mode": "unavailable",  # no pixel mirror since build 96
            "glass": glass,
            "board_coarse": state is None,
            "execution_known": state is not None,
            "catalog_known": self._board_catalog is not None,
            "catalog_source": "board",
            "service_status": dict(state) if state is not None else None,
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
        # H-line: live pool counts. Reuses the same keys PYTHON/
        # FPGA-SIM already populate so _inspect_heap() needs no changes.
        if self._heap_live is not None:
            env, arr, obj = self._heap_live
            snap["envl"] = env
            snap["arr"] = arr
            snap["obj"] = obj
        # F/T-line: at-fault forensics, BOARD-specific field names
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
        if self._fault_gsnap is not None:
            # G-line: exact RTL fault site + the value it refused. Feed the
            # generic fsite slot too — for exec64 faults it is now real.
            snap["fsite"] = self._fault_gsnap["fsite"]
            snap["board_fault_arg"] = self._fault_gsnap["arg_signed"]
        if self._fault_ip_trail is not None:
            snap["board_ip_trail"] = self._fault_ip_trail
        return snap
