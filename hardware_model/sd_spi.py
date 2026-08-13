"""Phase-2 microSD SPI-mode card model.

Byte-level SPI BFM (`spi_select` / `spi_byte`) for RTL SPI-master cocotb, plus
`read_block` / `write_block` wrappers used by FAT32.  The block API drives the
same byte engine so byte path ≡ block path on one card image.
"""

from __future__ import annotations

from pathlib import Path

from functional_model import memory_map as mm
from functional_model.memory import Memory

SECTOR_SIZE = 512

# Rough device cycles at 25 MHz SPI: 512 bytes × 8 bits ≈ 4096 SPI clocks
# plus command overhead — charge separately so FM≡HM cycle parity is untouched.
SPI_CYCLES_PER_SECTOR = 4500


def _crc7(data: bytes) -> int:
    """CRC-7 (poly 0x09) used in SPI command framing."""
    crc = 0
    for byte in data:
        for bit in range(8):
            crc <<= 1
            if ((byte << bit) ^ (crc << 1)) & 0x80:
                crc ^= 0x09
            crc &= 0x7F
    return (crc << 1) | 1  # stop bit


def _crc16(data: bytes) -> int:
    """CRC-16-CCITT for data blocks."""
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


class SdSpiCard:
    """SPI-mode SD card state machine backed by a mutable sector image."""

    def __init__(
        self,
        memory: Memory,
        image: bytearray | bytes | Path | None = None,
        *,
        size_bytes: int = 8 * 1024 * 1024,
        record: bool = False,
    ) -> None:
        self.memory = memory
        self.device_cycles = 0
        self.present = True
        self.initialised = False
        self.busy = False
        self.error = False
        self._app_cmd = False  # set by CMD55
        self._idle = True
        if isinstance(image, Path):
            raw = bytearray(image.read_bytes())
        elif isinstance(image, (bytes, bytearray)):
            raw = bytearray(image)
        else:
            raw = bytearray(size_bytes)
        # Round up to whole sectors.
        if len(raw) % SECTOR_SIZE:
            raw.extend(b"\0" * (SECTOR_SIZE - len(raw) % SECTOR_SIZE))
        self.image = raw
        # Byte-level SPI state.
        self._cs = True  # inactive high
        self._cmd_buf = bytearray()
        self._tx_queue: list[int] = []
        self._rx_mode = "idle"  # idle | cmd | read_data | write_token | write_data | write_crc
        self._write_lba = 0
        self._write_buf = bytearray()
        self._write_crc_left = 0
        self.record = record
        self.transcript: list[dict] = []
        self._publish()

    @property
    def sector_count(self) -> int:
        return len(self.image) // SECTOR_SIZE

    # -- byte-level SPI BFM (RTL SPI master exam) ---------------------------

    def spi_select(self, cs_active: bool) -> None:
        """Drive chip-select.  `cs_active=True` means CS# asserted (low)."""
        was = self._cs
        self._cs = not cs_active
        if self.record:
            self.transcript.append({"op": "cs", "active": bool(cs_active)})
        if cs_active and was:
            # Fresh transaction.
            self._cmd_buf.clear()
            self._rx_mode = "cmd"
            if not self._tx_queue:
                self._tx_queue.append(0xFF)
        if not cs_active:
            self._rx_mode = "idle"
            self._cmd_buf.clear()

    def spi_byte(self, mosi: int) -> int:
        """Exchange one SPI byte; return MISO.  Host shifts MOSI, card shifts MISO."""
        mosi &= 0xFF
        if self._cs:
            # Deselected: high-Z → read as 0xFF.
            miso = 0xFF
            if self.record:
                self.transcript.append({"op": "byte", "mosi": mosi, "miso": miso, "note": "cs_high"})
            return miso

        # Pending response bytes first.
        if self._tx_queue:
            miso = self._tx_queue.pop(0) & 0xFF
        else:
            miso = 0xFF

        if self._rx_mode == "cmd":
            # Skip leading 0xFF clocks before a command start bit.
            if not self._cmd_buf and mosi == 0xFF:
                pass
            else:
                self._cmd_buf.append(mosi)
                if len(self._cmd_buf) >= 6:
                    self._handle_command(bytes(self._cmd_buf[:6]))
                    self._cmd_buf.clear()
        elif self._rx_mode == "write_token":
            if mosi == 0xFE:
                self._rx_mode = "write_data"
                self._write_buf = bytearray()
            # else keep waiting for token
        elif self._rx_mode == "write_data":
            self._write_buf.append(mosi)
            if len(self._write_buf) >= SECTOR_SIZE:
                self._rx_mode = "write_crc"
                self._write_crc_left = 2
        elif self._rx_mode == "write_crc":
            self._write_crc_left -= 1
            if self._write_crc_left <= 0:
                # Data response + busy + ready.
                off = self._write_lba * SECTOR_SIZE
                self.image[off : off + SECTOR_SIZE] = self._write_buf[:SECTOR_SIZE]
                self.memory.write_block(mm.STORAGE_BUFFER, bytes(self._write_buf[:SECTOR_SIZE]))
                self._tx_queue.extend([0x05, 0x00, 0xFF])  # accept, busy, ready
                self._rx_mode = "cmd"
                self.busy = False
                self._publish()

        if self.record:
            self.transcript.append({"op": "byte", "mosi": mosi, "miso": miso})
        return miso

    def _handle_command(self, frame: bytes) -> None:
        index = frame[0] & 0x3F
        arg = (frame[1] << 24) | (frame[2] << 16) | (frame[3] << 8) | frame[4]
        _ = _crc7(frame[:5])
        r1 = self._r1_for(index, arg)
        self._tx_queue.append(r1)
        if index == 8:
            # R7: R1 already queued; OCR echo 0x000001AA
            self._tx_queue.extend([0x00, 0x00, 0x01, 0xAA])
        elif index == 58:
            self._tx_queue.extend([0x40, 0xFF, 0x80, 0x00])  # CCS set, rough OCR
        elif index == 17 and r1 == 0x00:
            data = bytes(self.image[arg * SECTOR_SIZE : (arg + 1) * SECTOR_SIZE])
            crc = _crc16(data)
            self._tx_queue.append(0xFE)
            self._tx_queue.extend(data)
            self._tx_queue.append((crc >> 8) & 0xFF)
            self._tx_queue.append(crc & 0xFF)
            self.memory.write_block(mm.STORAGE_BUFFER, data)
        elif index == 24 and r1 == 0x00:
            self._write_lba = arg
            self._rx_mode = "write_token"
            self.busy = True
            self._publish()
        if index == 0:
            self._idle = True
            self.initialised = False
        if index == 41 and self._app_cmd is False and r1 == 0x00:
            # ACMD41 already cleared _app_cmd in _r1_for; mark ready.
            self.initialised = True
            self._idle = False

    def _r1_for(self, index: int, arg: int) -> int:
        if index == 55:
            self._app_cmd = True
            return 0x01 if self._idle else 0x00
        if self._app_cmd:
            self._app_cmd = False
            if index == 41:
                self.initialised = True
                self._idle = False
                return 0x00
        if index == 0:
            return 0x01
        if index == 8:
            return 0x01
        if index == 58:
            return 0x00
        if index in (17, 24):
            return 0x00 if self.initialised else 0x01
        if index == 13:
            return 0x00
        return 0x04

    def _host_cmd(self, index: int, arg: int) -> int:
        """Drive one SPI command via the byte BFM; return R1."""
        frame = bytes(
            [
                0x40 | (index & 0x3F),
                (arg >> 24) & 0xFF,
                (arg >> 16) & 0xFF,
                (arg >> 8) & 0xFF,
                arg & 0xFF,
            ]
        )
        crc = _crc7(frame)
        self.spi_select(True)
        # Ncr: a few 0xFF clocks, then command, then read until R1 (MSB clear).
        for _ in range(2):
            self.spi_byte(0xFF)
        for b in frame:
            self.spi_byte(b)
        self.spi_byte(crc)
        r1 = 0xFF
        for _ in range(8):
            r1 = self.spi_byte(0xFF)
            if r1 != 0xFF:
                break
        return r1

    # -- high-level block API (used by FAT32) --------------------------------

    def init(self) -> bool:
        """CMD0 → CMD8 → ACMD41 → CMD58; marks card initialised."""
        self.busy = True
        self._publish()
        r1 = self._host_cmd(0, 0)
        if r1 != 0x01:
            self.error = True
            self.busy = False
            self._publish()
            self.spi_select(False)
            return False
        self._host_cmd(8, 0x1AA)
        # Drain R7 payload already queued by byte engine (extra 0xFF clocks).
        for _ in range(4):
            self.spi_byte(0xFF)
        for _ in range(20):
            self._host_cmd(55, 0)
            r1 = self._host_cmd(41, 0x40000000)
            if r1 == 0x00:
                break
        else:
            self.error = True
            self.busy = False
            self._publish()
            self.spi_select(False)
            return False
        self._host_cmd(58, 0)
        for _ in range(4):
            self.spi_byte(0xFF)
        self.spi_select(False)
        self.initialised = True
        self._idle = False
        self.busy = False
        self.error = False
        self.device_cycles += SPI_CYCLES_PER_SECTOR // 4
        self._publish()
        self.memory.write(mm.IO_SD_ACK, mm.SD_ACK_DONE)
        return True

    def read_block(self, lba: int) -> bytes:
        """CMD17 single-block read → STORAGE_BUFFER + return bytes."""
        self.busy = True
        self.error = False
        self._publish()
        if not self.initialised:
            self.init()
        if lba < 0 or lba >= self.sector_count:
            self.error = True
            self.busy = False
            self._publish()
            raise IndexError(f"LBA {lba} out of range")
        r1 = self._host_cmd(17, lba)
        if r1 != 0x00:
            self.error = True
            self.busy = False
            self._publish()
            self.spi_select(False)
            raise IOError("CMD17 failed")
        # Clock until data token, then 512 + CRC16.
        token = 0xFF
        for _ in range(1000):
            token = self.spi_byte(0xFF)
            if token == 0xFE:
                break
        else:
            self.spi_select(False)
            raise IOError("no data token")
        data = bytearray()
        for _ in range(SECTOR_SIZE):
            data.append(self.spi_byte(0xFF))
        self.spi_byte(0xFF)  # CRC hi
        self.spi_byte(0xFF)  # CRC lo
        self.spi_select(False)
        self.memory.write_block(mm.STORAGE_BUFFER, bytes(data))
        self.device_cycles += SPI_CYCLES_PER_SECTOR
        self.busy = False
        self._publish()
        self.memory.write(mm.IO_SD_ACK, mm.SD_ACK_DONE)
        return bytes(data)

    def write_block(self, lba: int, data: bytes) -> None:
        """CMD24 single-block write from data (also mirrored to STORAGE_BUFFER)."""
        self.busy = True
        self.error = False
        self._publish()
        if not self.initialised:
            self.init()
        if lba < 0 or lba >= self.sector_count:
            self.error = True
            self.busy = False
            self._publish()
            raise IndexError(f"LBA {lba} out of range")
        if len(data) != SECTOR_SIZE:
            data = bytes(data[:SECTOR_SIZE]).ljust(SECTOR_SIZE, b"\0")
        r1 = self._host_cmd(24, lba)
        if r1 != 0x00:
            self.error = True
            self.busy = False
            self._publish()
            self.spi_select(False)
            raise IOError("CMD24 failed")
        self.spi_byte(0xFE)
        for b in data:
            self.spi_byte(b)
        crc = _crc16(data)
        self.spi_byte((crc >> 8) & 0xFF)
        self.spi_byte(crc & 0xFF)
        # Data response + busy poll.
        resp = self.spi_byte(0xFF)
        for _ in range(16):
            if self.spi_byte(0xFF) == 0xFF:
                break
        self.spi_select(False)
        if (resp & 0x1F) != 0x05:
            self.error = True
            self.busy = False
            self._publish()
            raise IOError("write data rejected")
        self.device_cycles += SPI_CYCLES_PER_SECTOR
        self.busy = False
        self._publish()
        self.memory.write(mm.IO_SD_ACK, mm.SD_ACK_DONE)

    def status(self) -> int:
        """CMD13 R2 status (simplified: 0 when healthy)."""
        self._host_cmd(13, 0)
        self.spi_select(False)
        return 0

    # -- register-driven command path (FPGA MMIO shape) ---------------------

    def service_regs(self) -> None:
        """Poll IO_SD_CMD and execute if non-idle."""
        cmd = self.memory.read(mm.IO_SD_CMD)
        if cmd == mm.SD_CMD_IDLE:
            return
        lba = (
            self.memory.read(mm.IO_SD_LBA_0)
            | (self.memory.read(mm.IO_SD_LBA_1) << 8)
            | (self.memory.read(mm.IO_SD_LBA_2) << 16)
            | (self.memory.read(mm.IO_SD_LBA_3) << 24)
        )
        self.memory.write(mm.IO_SD_ACK, 0)
        try:
            if cmd == mm.SD_CMD_INIT:
                self.init()
            elif cmd == mm.SD_CMD_READ:
                self.read_block(lba)
            elif cmd == mm.SD_CMD_WRITE:
                data = bytes(
                    self.memory.read_block(mm.STORAGE_BUFFER, SECTOR_SIZE)
                )
                self.write_block(lba, data)
        except (IndexError, IOError):
            self.error = True
            self.busy = False
            self._publish()
        self.memory.write(mm.IO_SD_CMD, mm.SD_CMD_IDLE)

    def save_image(self, path: Path) -> None:
        path.write_bytes(self.image)

    def _publish(self) -> None:
        status = 0
        if self.present:
            status |= mm.SD_STATUS_PRESENT
        if self.busy:
            status |= mm.SD_STATUS_BUSY
        if self.error:
            status |= mm.SD_STATUS_ERROR
        if self.initialised:
            status |= mm.SD_STATUS_INIT
        self.memory.write(mm.IO_SD_STATUS, status)
