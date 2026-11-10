"""Finder service protocol v1, independent of console text and pixel telemetry.

Request: FA, version/op/u32 transaction/u32 argument/name-length/name[12],
then IEEE CRC32 over the 23-byte body. Integers are little endian.
Reply: Q + hexadecimal version/op/transaction/phase/status/value + CRC32 + LF.
Reply CRC covers the 24 ASCII payload characters, excluding Q and CRC.
"""
from dataclasses import dataclass
from enum import IntEnum
import re
import struct
import zlib


class Operation(IntEnum):
    STATUS = 0
    ENTER_FINDER = 1
    SAVE_SOURCE = 2
    SAVE_CART = 3
    LAUNCH = 4
    STREAM_PROGRAM = 5
    QUERY_TRANSACTION = 6
    CATALOG = 7


class Phase(IntEnum):
    ACCEPTED = 1
    COMPLETED = 2
    DETAIL = 3
    NAME_FIRST = 0x10
    NAME_SECOND = 0x11
    NAME_LAST = 0x12


STATUS_NAMES = {
    0: 'OK', 1: 'BUSY', 2: 'BAD_VERSION', 3: 'BAD_OP', 4: 'BAD_NAME',
    5: 'RANGE', 6: 'CRC', 7: 'IO', 8: 'CANCELLED',
    9: 'UNKNOWN_TRANSACTION', 10: 'CONFLICT',
}
_REPLY = re.compile(r'Q([0-9A-Fa-f]{24})([0-9A-Fa-f]{8})')


def fat_name(name):
    """Validate a bare 8.3 filename; never truncate or accept a host path."""
    if not isinstance(name, str):
        raise ValueError('Filename must be text')
    name = name.upper()
    if not name:
        return b''
    parts = name.split('.')
    if len(parts) > 2 or not 1 <= len(parts[0]) <= 8:
        raise ValueError('Expected a bare FAT 8.3 filename')
    if len(parts) == 2 and not 1 <= len(parts[1]) <= 3:
        raise ValueError('Expected a FAT extension of 1–3 characters')
    if any(ord(c) < 33 or ord(c) > 126 or c in '\\/:*?"<>|+,;=[]' for c in name):
        raise ValueError('Invalid FAT filename character')
    return name.encode('ascii')


def request(op, transaction, argument=0, name=''):
    op = Operation(op)
    if not 1 <= transaction <= 0xffffffff or not 0 <= argument <= 0xffffffff:
        raise ValueError('Transaction and argument must fit protocol fields')
    encoded = fat_name(name)
    if op in (Operation.SAVE_SOURCE, Operation.SAVE_CART, Operation.LAUNCH):
        if not encoded:
            raise ValueError('This service requires a filename')
    elif encoded:
        raise ValueError('This service does not accept a filename')
    body = struct.pack('<BBIIB12s', 1, op, transaction, argument,
                       len(encoded), encoded.ljust(12, b'\0'))
    return b'\xfa' + body + struct.pack('<I', zlib.crc32(body) & 0xffffffff)


@dataclass(frozen=True)
class Reply:
    operation: int
    transaction: int
    phase: int
    status: int
    value: int

    @property
    def error(self):
        return self.phase in (Phase.ACCEPTED, Phase.COMPLETED) and self.status != 0


def parse_reply(line):
    """Return None for a torn/invalid/other telemetry line; no state mutation."""
    if isinstance(line, bytes):
        try:
            line = line.decode('ascii')
        except UnicodeDecodeError:
            return None
    if not isinstance(line, str):
        return None
    m = _REPLY.fullmatch(line.rstrip('\r\n'))
    if not m:
        return None
    body, crc = m.groups()
    if zlib.crc32(body.encode('ascii')) & 0xffffffff != int(crc, 16):
        return None
    version, op = int(body[:2], 16), int(body[2:4], 16)
    phase = int(body[12:14], 16)
    if version != 1 or op not in Operation._value2member_map_ or phase not in Phase._value2member_map_:
        return None
    return Reply(op, int(body[4:12], 16), phase,
                 int(body[14:16], 16), int(body[16:24], 16))


def snapshot(value):
    return {
        'running': bool(value & 1), 'storage_busy': bool(value & 2),
        'source_staged': bool(value & 4), 'cart_staged': bool(value & 8),
        'transfer_owned': bool(value & 16), 'finder_active': bool(value & 32),
        'link_reset_required': bool(value & 64),
        'role': (value >> 8) & 255, 'fault': (value >> 16) & 255,
    }


class Catalog:
    """Assemble bounded FAT names; reject missing/reordered chunks or count."""
    def __init__(self):
        self.names = []
        self._parts = []
        self._length = 0

    def accept(self, reply):
        if reply.operation != Operation.CATALOG:
            raise ValueError('Wrong service in catalog response')
        if reply.phase in (Phase.NAME_FIRST, Phase.NAME_SECOND, Phase.NAME_LAST):
            if reply.phase != Phase.NAME_FIRST + len(self._parts):
                raise ValueError('Out-of-order catalog chunk')
            if not self._parts:
                self._length = reply.status
            if not 1 <= self._length <= 12 or reply.status != self._length:
                raise ValueError('Invalid catalog name length')
            self._parts.append(reply.value.to_bytes(4, 'little'))
            if reply.phase == Phase.NAME_LAST:
                raw = b''.join(self._parts)
                if any(raw[self._length:]):
                    raise ValueError('Nonzero catalog name padding')
                name = raw[:self._length].decode('ascii')
                if fat_name(name) != raw[:self._length]:
                    raise ValueError('Noncanonical catalog filename')
                self.names.append(name)
                self._parts.clear()
        elif reply.phase == Phase.COMPLETED:
            if reply.error or self._parts or reply.value != len(self.names):
                raise ValueError('Incomplete or failed board catalog')


class ServiceError(RuntimeError):
    def __init__(self, reply):
        self.reply = reply
        message = 'Finder service: ' + STATUS_NAMES.get(reply.status, 'UNKNOWN_ERROR')
        if reply.status == 1 and reply.operation == Operation.ENTER_FINDER:
            message = 'Return to Finder to receive files; an application or system operation is active'
        super().__init__(message)


class FinderServices:
    """Single-owner host adapter; completion comes from Q, never screen text."""
    def _init_finder_services(self):
        import time
        self._service_serial = time.monotonic_ns() & 0xffffffff or 1
        self._service_pending = {}
        self._service_snapshot = None
        self._service_caps = None
        self._board_catalog = None
        self._transfer_active = False
        self._uncertain_transaction = None
        self._transfer_fault = False
        self._status_poll_tx = None
        self._status_poll_at = 0.0
        self._status_poll_failures = 0

    def _receive_service_line(self, line):
        if not line.startswith('Q'):
            return False
        reply = parse_reply(line)
        if reply is None:
            self._log.fault('SERVICE', 'Malformed service response ignored')
            return True
        if reply.operation == Operation.STATUS and reply.phase == Phase.DETAIL:
            if reply.transaction == 0 or reply.transaction in self._service_pending:
                self._service_snapshot = snapshot(reply.value)
                if self._service_snapshot['link_reset_required']:
                    self._transfer_fault = True
                    self._log.fault('TETHER_RESET', 'Interrupted transfer: physical reset required before further commands')
        if reply.phase == Phase.COMPLETED and reply.status == 8 and reply.value & 0x80000000:
            self._transfer_fault = True
            self._log.fault('TETHER_RESET', 'Transfer cancelled: physical reset required')
        pending = self._service_pending.get(reply.transaction)
        if pending is not None and pending['op'] == reply.operation:
            pending['replies'].append(reply)
            if reply.operation == Operation.STATUS:
                if reply.phase == Phase.DETAIL:
                    self._service_snapshot = snapshot(reply.value)
                elif reply.phase == Phase.COMPLETED and not reply.error:
                    self._service_caps = reply.value
            if reply.transaction == self._status_poll_tx and reply.phase == Phase.COMPLETED:
                self._service_pending.pop(reply.transaction, None)
                self._status_poll_tx = None
                self._status_poll_failures = 0 if not reply.error else self._status_poll_failures + 1
        return True

    def _poll_service_status(self):
        """Nonblocking status sampling; no debugger dependency on a text screen."""
        import time
        now = time.monotonic()
        if self._status_poll_tx is not None:
            if now - self._status_poll_at > 5.0:
                self._service_pending.pop(self._status_poll_tx, None)
                self._status_poll_tx = None
                self._service_snapshot = None
                self._status_poll_failures += 1
            return
        if (not self._service_connected() or self._transfer_active or self._transfer_fault
                or self._service_pending or self._status_poll_failures >= 3
                or now - self._status_poll_at < 1.0):
            return
        self._status_poll_at = now
        self._status_poll_tx = self._begin_service(Operation.STATUS)
        # An in-process RTL transport may already have returned completion.
        pending = self._service_pending.get(self._status_poll_tx)
        if pending and any(r.phase == Phase.COMPLETED for r in pending['replies']):
            self._service_pending.pop(self._status_poll_tx, None)
            self._status_poll_tx = None

    def _service_connected(self):
        return self._ser is not None

    def _write_all(self, data):
        remaining = memoryview(data)
        while remaining:
            written = self._ser.write(remaining)
            if written is None or written <= 0:
                raise IOError('Tether stopped accepting bytes')
            remaining = remaining[written:]

    def _send_service_packet(self, packet):
        try:
            self._write_all(packet)
            self._ser.flush()
        except Exception:
            self._transfer_fault = True  # A partial envelope cannot be replayed safely.
            raise

    def _begin_service(self, op, argument=0, name=''):
        if not self._service_connected():
            raise RuntimeError('FPGA tether is not connected')
        if self._transfer_fault:
            raise RuntimeError('A partial bulk stream requires reconnect/reset before new requests')
        if self._uncertain_transaction is not None and op not in (Operation.STATUS, Operation.QUERY_TRANSACTION):
            raise RuntimeError('Previous transfer outcome is unknown; resolve its transaction before another operation')
        if self._status_poll_tx is not None:
            self._service_pending.pop(self._status_poll_tx, None)
            self._status_poll_tx = None
        self._service_serial = (self._service_serial + 1) & 0xffffffff or 1
        tx = self._service_serial
        packet = request(op, tx, argument, name)
        self._service_pending[tx] = {'op': int(op), 'replies': []}
        try:
            self._send_service_packet(packet)
        except Exception:
            self._service_pending.pop(tx, None)
            if op not in (Operation.STATUS, Operation.CATALOG, Operation.QUERY_TRANSACTION):
                self._uncertain_transaction = tx
            raise
        return tx

    def _wait_service(self, tx, timeout=10.0, accepted=False):
        import time
        pending = self._service_pending[tx]
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self._transfer_fault:
                self._service_pending.pop(tx, None)
                raise RuntimeError('Tether requires a physical reset after an interrupted transfer')
            for reply in pending['replies']:
                if reply.error:
                    self._service_pending.pop(tx, None)
                    raise ServiceError(reply)
                if reply.phase == Phase.COMPLETED or (accepted and reply.phase == Phase.ACCEPTED):
                    if reply.phase == Phase.COMPLETED:
                        self._service_pending.pop(tx, None)
                    return list(pending['replies'])
            self.poll()
            pump = getattr(self, 'run_wait_idle', None)
            if pump:
                pump()
            time.sleep(0.01)
        self._service_pending.pop(tx, None)
        if pending['op'] not in (Operation.STATUS, Operation.CATALOG, Operation.QUERY_TRANSACTION):
            self._uncertain_transaction = tx
        raise TimeoutError(f'Finder service transaction {tx:08X} timed out; no automatic replay')

    def _service(self, op, argument=0, name='', timeout=10.0):
        return self._wait_service(self._begin_service(op, argument, name), timeout)

    def refresh_service_status(self):
        self._service(Operation.STATUS)
        if self._service_caps is None or not self._service_caps & 1:
            raise RuntimeError('This FPGA does not advertise Finder service protocol v1')
        if self._service_snapshot is None:
            raise RuntimeError('The FPGA did not return its service status')
        return self._service_snapshot

    def resolve_transaction(self):
        target = self._uncertain_transaction
        if target is None:
            return None
        tx = self._begin_service(Operation.QUERY_TRANSACTION, target)
        try:
            replies = self._wait_service(tx, accepted=True)
            reply = replies[-1]
            if reply.phase == Phase.COMPLETED:
                self._uncertain_transaction = None
            return reply
        except ServiceError as error:
            if error.reply.phase == Phase.COMPLETED and error.reply.status not in (9, 10):
                self._uncertain_transaction = None
            raise
        finally:
            self._service_pending.pop(tx, None)

    def refresh_board_catalog(self):
        if self._service_caps is None:
            self.refresh_service_status()
        if not self._service_caps & (1 << 5):
            self._board_catalog = None
            raise RuntimeError('Board catalog service is unavailable')
        if self._transfer_active:
            raise RuntimeError('Another Finder service owns the storage')
        self._transfer_active = True
        acquired = False
        try:
            self._service(Operation.ENTER_FINDER, 0)
            acquired = True
            catalog = Catalog()
            for reply in self._service(Operation.CATALOG, timeout=120.0):
                catalog.accept(reply)
            self._board_catalog = catalog.names
            self._service(Operation.ENTER_FINDER, 1, timeout=120.0)
            acquired = False
            return list(catalog.names)
        finally:
            self._transfer_active = False
            if acquired and self._uncertain_transaction is None and not self._transfer_fault:
                self._service(Operation.ENTER_FINDER, 1, timeout=120.0)

    def launch_named(self, name, how=0):
        if type(how) is not int or how not in range(4):
            raise ValueError('Unsupported Finder launch action')
        return self._service(Operation.LAUNCH, how, name, timeout=120.0)

    def can_transfer_files(self):
        # Actual ownership is checked by ENTER_FINDER before any bulk bytes.
        return (self._service_connected() and not self._transfer_active
                and not self._transfer_fault and self._uncertain_transaction is None
                and (self._service_snapshot is None or not self._service_snapshot["running"]
                     or self._service_snapshot["finder_active"]))

    def refresh_files(self):
        return self.refresh_board_catalog()

    def _stream_staged(self, prefix, data):
        if self._ser is None:
            raise RuntimeError('FPGA tether is not connected')
        try:
            self._write_all(bytes([prefix]) + struct.pack('<I', len(data)))
            for i in range(0, len(data), 16384):
                self._write_all(memoryview(data)[i:i + 16384])
            self._write_all(struct.pack('<I', zlib.crc32(data) & 0xffffffff))
            self._ser.flush()
        except Exception:
            self._transfer_fault = True
            raise

    def _save_staged(self, name, data, large=False):
        from functional_model.jsb_format import SOURCE_MAX
        limit = self._BIG_MAX if large else SOURCE_MAX
        if len(data) > limit:
            raise ValueError(f'{name}: {len(data)} bytes exceeds staging limit {limit}')
        # Validate filename before writing any staging bytes.
        fat_name(name)
        op = Operation.SAVE_CART if large else Operation.SAVE_SOURCE
        for attempt in range(3):
            self._stream_staged(0xFB if large else 0xFC, data)
            try:
                replies = self._service(op, len(data), name, max(300.0, len(data) / 4000.0))
                if replies[-1].value != len(data):
                    raise RuntimeError('FPGA committed byte count differs from uploaded length')
                return
            except ServiceError as error:
                if error.reply.status != 6 or attempt == 2:
                    raise
                self._log.note(f'CRC rejected {name}; resend {attempt + 1}/3')

    def stream_program(self, data):
        """Explicit developer image launch; keep FD transport, no typed RUN."""
        from functional_model.jsb_format import ProgramImage
        ProgramImage(data).decode()  # Reject malformed host image before ownership changes.
        tx = self._begin_service(Operation.STREAM_PROGRAM, len(data))
        replies = self._wait_service(tx, accepted=True)
        if replies[-1].phase != Phase.ACCEPTED:
            raise RuntimeError('FPGA completed program request before receiving its image')
        try:
            self._stream_staged(0xFD, data)
            return self._wait_service(tx, timeout=120.0)
        except Exception:
            self._uncertain_transaction = tx
            raise

    @staticmethod
    def _save_order(name: str) -> int:
        # HTML first (deletes stale .JSH), then ART, JSH last so RUN can find it.
        u = name.upper()
        if u.endswith(".HTM") or u.endswith(".HTML"):
            return 0
        if u.endswith(".ART") or u.endswith(".ARTX"):
            return 1
        if u.endswith(".JSH"):
            return 2
        return 3

    _BIG_MAX = 1480704 * 2   # CART staging bank, bytes (2 B/word)

    @staticmethod
    def _check_ordinary_import(names):
        # Generic file import cannot establish a complete relinked resident set.
        # System-library installation belongs to the matched release updater.
        if any(str(name).upper() in ('TOOLBOX.ROM', 'TOOLBOX.LNK') for name in names):
            raise ValueError('Toolbox updates require a complete matched release package, not individual file import')

    def _save_jobs_to_msd(self, jobs: list) -> str:
        from functional_model.jsb_format import SOURCE_MAX
        self._check_ordinary_import(name for name, _ in jobs)
        if self._service_snapshot and self._service_snapshot['running'] and not self._service_snapshot['finder_active']:
            raise RuntimeError('Return to Finder to receive files')
        if not self.can_transfer_files():
            raise RuntimeError('FPGA transfer unavailable or another transfer is unresolved')
        jobs = sorted(jobs, key=lambda x: (self._save_order(x[0]), x[0]))
        for name, data in jobs:
            if not fat_name(name) or len(data) > self._BIG_MAX:
                raise ValueError(f'Invalid or oversized transfer: {name}')
        self._transfer_active = True
        acquired = False
        try:
            self.refresh_service_status()
            required = (1 << 1) | (1 << 2)
            if self._service_caps & required != required:
                raise RuntimeError('FPGA does not support both staging transfer services')
            # The board rejects active non-Finder applications. Never discard
            # an editor document merely because the host wants to send a file.
            self._service(Operation.ENTER_FINDER, 0)
            acquired = True
            for name, data in jobs:
                self._save_staged(name, data, large=len(data) > SOURCE_MAX)
            self._service(Operation.ENTER_FINDER, 1, timeout=120.0)
            acquired = False
            return ', '.join(name for name, _ in jobs) or 'nothing'
        finally:
            self._transfer_active = False
            # Do not inject a new request behind a partial stream or uncertain
            # commit. Releasing a known failed operation is safe; replay is not.
            if acquired and self._uncertain_transaction is None and not self._transfer_fault:
                self._service(Operation.ENTER_FINDER, 1, timeout=120.0)

    def put_files_on_card(self, paths: list) -> str:
        """F8: host card.img (mint) + live µSD via SOURCE+SAVE of what landed."""
        import os

        from tools.make_sd_image import open_volume, put_host_files_on_card
        from pathlib import Path
        ROOT = Path(__file__).resolve().parents[1]

        self._check_ordinary_import(Path(p).name for p in paths)
        names = put_host_files_on_card([Path(p) for p in paths])
        card = Path(os.environ.get("JMR_CARD_IMG") or (ROOT / "card.img"))
        vol = open_volume(card)
        jobs = []
        for name in names:
            try:
                jobs.append((name, vol.read_file(name)))
            except FileNotFoundError:
                continue
        live = self._save_jobs_to_msd(jobs)
        return f"{live} (host {', '.join(names)})"

    def put_card_names(self, names: list) -> str:
        """F8 from card.img: stream existing FAT files onto the board µSD."""
        import os

        from tools.make_sd_image import open_volume
        from pathlib import Path
        ROOT = Path(__file__).resolve().parents[1]

        card = Path(os.environ.get("JMR_CARD_IMG") or (ROOT / "card.img"))
        vol = open_volume(card)
        jobs = []
        for name in names:
            jobs.append((name, vol.read_file(name)))
        return self._save_jobs_to_msd(jobs)

