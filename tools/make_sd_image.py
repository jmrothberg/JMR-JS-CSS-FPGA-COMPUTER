"""Build / populate / dump FAT32 microSD card images for the JMR JS Computer.

Ported from JMR-BASIC-FPGA-COMPUTER/tools/make_sd_image.py (same FAT32 + burn
guards). Seeds from project `storage/` root files only (not subfolders).
No title list — whatever is in `storage/` (except docs / leftover sidecars)
lands on the card as 8.3 names.

Usage:
  python3 tools/make_sd_image.py create card.img
  python3 tools/make_sd_image.py list card.img
  python3 tools/make_sd_image.py check
  sudo python3 tools/make_sd_image.py burn /dev/sdX
  sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image

Board FAT is 8.3 only — `NAME.HTML` becomes `NAME.HTM` via card_name_83.
"""

from __future__ import annotations

import argparse
import os
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from functional_model.memory import Memory  # noqa: E402
from hardware_model.fat32 import Fat32Volume  # noqa: E402
from hardware_model.sd_spi import SECTOR_SIZE, SdSpiCard  # noqa: E402

# Project library that always goes on the card unless --no-storage.
STORAGE_DIR = ROOT / "storage"

# Hard limit on a BASIC source line, set by the console's line buffer:
# rtl/engines/console_engine.sv declares `logic [7:0] line [0:127]`, so a LOADed
# line of more than 128 characters does not fit. The board now reports ?LS for
# one, but PYTHON and FPGA-SIM load programs host-side and never touch that
# buffer, so a too-long line passes every host test and only fails on hardware.
# That is why this check lives in the card builder.
LINE_MAX = 128
# ST_LN_DIG accepts at most 5 digits of line number.
LINE_NO_MAX = 65535
# NEW: console tok_buf is 128 bytes; source can fit LINE_MAX chars but tokenize
# longer (e.g. SET(x,y,color) × 6). Overflow used to wrap and corrupt the line.
TOK_MAX = 128

# Default geometry: 16 MiB (JS/HTML demos + room to grow).
DEFAULT_SIZE = 16 * 1024 * 1024
PART_LBA = 2048
RESERVED = 32
FAT_COUNT = 2
SECTORS_PER_CLUSTER = 8  # 4 KiB clusters
ROOT_CLUSTER = 2
FSINFO_SECTOR = 1

# Card seeds: whatever sits in storage/ root. Stale sidecars on the HOST are
# still skipped — the card's .JSH is MINTED here from the HTML at build time
# (see compile_sidecars), never copied from storage/.
_SKIP_SUFFIX = {".JSH", ".JSB", ".MD", ".MDC", ".TXT", ".JSON"}
_KEEP_SUFFIX = {".HTML", ".HTM", ".JS", ".PNG", ".DAT", ".BIN"}


def compile_sidecars(files: list[tuple[str, bytes]]) -> list[tuple[str, bytes]]:
    """Mint a .JSH ProgramImage next to every HTML title on the card.

    **V1.0 (2026-08-25):** compile when you **make the card** — mint `.JSH`
    here so the FPGA can `RUN` with no PC (the chip has no JS compiler).
    **V1.5 tries** compile-on-RUN on the machine; then this sidecar can go.
    Byte-identical to runtime/board_backend.py:274
    (`encode_html_chunk(compile_html_text(html))`) — same compiler, same
    encoder, different delivery. Never copy a stale `.JSH` from `storage/`.

    Compile failures are reported and skipped, never silently dropped:
    a title without a .JSH simply has no standalone path yet.
    """
    from tools.compile_js import compile_html_text, encode_html_chunk

    out: list[tuple[str, bytes]] = []
    have = {n.upper() for n, _ in files}
    for name, data in files:
        if not name.upper().endswith(".HTM"):
            continue
        stem = name.rsplit(".", 1)[0]
        side = f"{stem}.JSH"
        if side.upper() in have:
            continue
        try:
            html = data.decode("utf-8", "replace")
            blob = encode_html_chunk(compile_html_text(html))
        except Exception as exc:  # compile error: report, keep going
            print(f"note: {name}: no .JSH sidecar ({type(exc).__name__}: {exc})")
            continue
        out.append((side, blob))
        print(f"note: {name} -> {side} ({len(blob)} bytes, standalone RUN)")
    return out


def _u16(n: int) -> bytes:
    return struct.pack("<H", n & 0xFFFF)


def _u32(n: int) -> bytes:
    return struct.pack("<I", n & 0xFFFFFFFF)


def collect_storage_files(
    storage_dir: Path = STORAGE_DIR,
) -> list[tuple[str, bytes]]:
    """Gather host files that belong on the card (8.3 names, root only).

    Only regular files directly in `storage/` — not `games_invaders/` etc.
    No title hardwire: 8.3 comes from card_name_83 (HTML → HTM).
    """
    pairs: dict[str, bytes] = {}
    hosts: dict[str, str] = {}
    if not storage_dir.is_dir():
        return []
    for path in sorted(storage_dir.iterdir()):
        if not path.is_file() or path.name.startswith("."):
            continue
        suf = path.suffix.upper()
        if suf in _SKIP_SUFFIX or suf not in _KEEP_SUFFIX:
            continue
        host = path.name
        card = card_name_83(host)
        if card in pairs:
            raise SystemExit(
                f"card name collision: {host!r} and {hosts[card]!r} both map to "
                f"{card!r}. Rename one file in storage/ (stem ≤ 8, ext ≤ 3)."
            )
        if card != host.upper():
            print(f"note: {host} -> {card} on card (8.3)", file=sys.stderr)
        pairs[card] = path.read_bytes()
        hosts[card] = host
    return [(name, data) for name, data in sorted(pairs.items())]


def card_name_83(host_name: str) -> str:
    """The 8.3 name the board will actually see for a host file.

    Fat32Volume.write_file stores 8.3 only, so `Invaders_V.bas` lands as
    `INVADER.BAS`-style truncation. LOAD on the board takes the card name, not
    the host name, so print the mapping whenever it changes.
    """
    stem, _, ext = host_name.rpartition(".")
    if not stem:  # no extension
        stem, ext = host_name, ""
    return (stem[:8] + ("." + ext[:3] if ext else "")).upper()


def strip_blank_bas_lines(name: str, data: bytes) -> tuple[bytes, int]:
    """Drop empty / whitespace-only lines from a .bas before it hits the card.

    NEW: RTL LOAD treats a non-empty non-digit line (including a lone space) as
    an immediate statement and stops filing the rest of the program. Host /
    FPGA-SIM LOAD never sees that path, so a program can "run and draw" in sim
    then die on the board once it GOSUBs past the truncated part. Stripping at
    image build time keeps storage/ readable with blank lines for humans while
    the card the FPGA reads is safe. Non-.bas files are left alone.
    """
    if not name.upper().endswith(".BAS"):
        return data, 0
    text = data.decode("latin-1")
    kept: list[str] = []
    removed = 0
    for raw in text.splitlines():
        line = raw.rstrip("\r")
        if not line.strip():
            removed += 1
            continue
        kept.append(line)
    if removed == 0:
        return data, 0
    # Join with LF; FAT tools and the board's line reader both accept it.
    out = ("\n".join(kept) + ("\n" if kept else "")).encode("latin-1")
    return out, removed


def squash_long_html_lines(name: str, data: bytes) -> tuple[bytes, int]:
    """Replace giant single lines in card .HTM/.HTML with a placeholder.

    The card copy of an HTML title is display-only: RUN compiles the HOST
    storage/ file (compile-on-RUN), and the board runs .JSH sidecars. LIST,
    however, streams the card copy through the RTL console line buffer —
    one 100KB+ base64 sprite line took megabytes of SPI reads and froze
    the monitor for minutes ("list stalls on embedded graphics"). Keep
    readable lines as-is; anything over 200 chars becomes
    `<LINE n: EMBEDDED DATA ... OMITTED>` so LIST stays honest and fast.
    Non-HTML files are left alone (a .JS/.JSB card copy IS the program).
    """
    up = name.upper()
    if not (up.endswith(".HTM") or up.endswith(".HTML")):
        return data, 0
    limit = 200
    out: list[bytes] = []
    squashed = 0
    for i, ln in enumerate(data.split(b"\n"), start=1):
        if len(ln) > limit:
            tag = (b"EMBEDDED DATA" if (b"base64" in ln or b"data:" in ln)
                   else b"LONG LINE")
            out.append(b"<LINE %d: %s %d CHARS OMITTED>" % (i, tag, len(ln)))
            squashed += 1
        else:
            out.append(ln)
    if squashed == 0:
        return data, 0
    return b"\n".join(out), squashed


def sanitize_bas_files(
    files: list[tuple[str, bytes]],
) -> tuple[list[tuple[str, bytes]], list[str]]:
    """Apply strip_blank_bas_lines to every .bas; return (files, notes)."""
    out: list[tuple[str, bytes]] = []
    notes: list[str] = []
    for name, data in files:
        cleaned, n = strip_blank_bas_lines(name, data)
        cleaned, m = squash_long_html_lines(name, cleaned)
        out.append((name, cleaned))
        if n:
            notes.append(f"{name}: stripped {n} blank/whitespace-only line(s) for the board")
        if m:
            notes.append(f"{name}: squashed {m} over-long line(s) for LIST (card copy only)")
    return out, notes


def check_program(name: str, data: bytes) -> tuple[list[str], list[str]]:
    """Lint one card file. BASIC .BAS rules kept; JS/HTML get soft size checks."""
    errors: list[str] = []
    warns: list[str] = []
    upper = name.upper()
    if upper.endswith(".BAS"):
        text = data.decode("latin-1")
        for i, raw in enumerate(text.splitlines(), start=1):
            line = raw.rstrip("\r")
            if not line.strip():
                continue
            if len(line) > LINE_MAX:
                errors.append(
                    f"{name}:{i}: {len(line)} chars, over the {LINE_MAX}-char limit"
                )
        return errors, warns
    # JS / HTML Canvas seeds — board LOAD path still growing; warn only on huge files.
    # Single-file HTML with embedded PNG sprites is expected to exceed 512 KiB.
    limit = 2 * 1024 * 1024 if upper.endswith((".HTM", ".HTML")) else 512 * 1024
    if len(data) > limit:
        warns.append(f"{name}: {len(data)} bytes is large for early board storage")
    return errors, warns


def check_storage(
    files: list[tuple[str, bytes]], *, note_names: bool = False
) -> tuple[list[str], list[str]]:
    """Lint every file heading for the card.

    Names on `files` are already card 8.3 names from collect_storage_files.
    """
    errors: list[str] = []
    warns: list[str] = []
    for name, data in files:
        if note_names:
            warns.append(f"on card: {name} ({len(data)} bytes)")
        e, w = check_program(name, data)
        errors.extend(e)
        warns.extend(w)
    return errors, warns


def format_fat32(size_bytes: int = DEFAULT_SIZE, part_lba: int = PART_LBA) -> bytearray:
    """Return a fresh FAT32 image (MBR + partition)."""
    if size_bytes % SECTOR_SIZE:
        size_bytes += SECTOR_SIZE - (size_bytes % SECTOR_SIZE)
    image = bytearray(size_bytes)
    total_sectors = size_bytes // SECTOR_SIZE
    part_sectors = total_sectors - part_lba
    if part_sectors < 64:
        raise ValueError("image too small for FAT32 partition")

    # Estimate sectors per FAT so data area fits.
    # data_sectors ≈ part_sectors - reserved - fat_count * spf
    # clusters ≈ data_sectors / spc
    # spf ≈ (clusters + 2) * 4 / 512
    spc = SECTORS_PER_CLUSTER
    reserved = RESERVED
    # Iterate once for a stable spf.
    approx_data = part_sectors - reserved - 100
    clusters = max(approx_data // spc, 16)
    spf = max((clusters + 2) * 4 // SECTOR_SIZE + 1, 1)
    data_start_rel = reserved + FAT_COUNT * spf
    clusters = (part_sectors - data_start_rel) // spc
    spf = max((clusters + 2) * 4 // SECTOR_SIZE + 1, 1)

    # --- MBR ---
    mbr = bytearray(SECTOR_SIZE)
    # Partition entry 0 at offset 446.
    mbr[446] = 0x00  # status
    mbr[450] = 0x0C  # FAT32 LBA
    mbr[454:458] = _u32(part_lba)
    mbr[458:462] = _u32(part_sectors)
    mbr[510] = 0x55
    mbr[511] = 0xAA
    image[0:SECTOR_SIZE] = mbr

    # --- VBR / BPB ---
    bpb = bytearray(SECTOR_SIZE)
    bpb[0:3] = b"\xeb\x58\x90"  # jump
    bpb[3:11] = b"JMRFAT32"
    bpb[11:13] = _u16(SECTOR_SIZE)
    bpb[13] = spc
    bpb[14:16] = _u16(reserved)
    bpb[16] = FAT_COUNT
    bpb[17:19] = _u16(0)  # root entries (FAT32 = 0)
    bpb[19:21] = _u16(0)  # total sectors 16
    bpb[21] = 0xF8
    bpb[22:24] = _u16(0)  # fat size 16
    bpb[32:36] = _u32(part_sectors)
    bpb[36:40] = _u32(spf)
    bpb[44:48] = _u32(ROOT_CLUSTER)
    bpb[48:50] = _u16(FSINFO_SECTOR)
    bpb[50:52] = _u16(6)  # backup boot sector
    bpb[66] = 0x29  # ext boot sig
    bpb[67:71] = _u32(0x4A4D5231)  # volume serial "JMR1"
    bpb[71:82] = b"JMR JS     "  # exactly 11 bytes volume label
    bpb[82:90] = b"FAT32   "
    bpb[510] = 0x55
    bpb[511] = 0xAA
    image[part_lba * SECTOR_SIZE : (part_lba + 1) * SECTOR_SIZE] = bpb
    # Backup boot sector.
    image[(part_lba + 6) * SECTOR_SIZE : (part_lba + 7) * SECTOR_SIZE] = bpb

    # --- FSInfo ---
    fs = bytearray(SECTOR_SIZE)
    fs[0:4] = b"RRaA"
    fs[484:488] = b"rrAa"
    fs[488:492] = _u32(0xFFFFFFFF)  # free count unknown
    fs[492:496] = _u32(ROOT_CLUSTER + 1)  # next free hint
    fs[510] = 0x55
    fs[511] = 0xAA
    image[(part_lba + FSINFO_SECTOR) * SECTOR_SIZE : (part_lba + FSINFO_SECTOR + 1) * SECTOR_SIZE] = fs

    # --- FATs ---
    fat = bytearray(spf * SECTOR_SIZE)
    # Cluster 0: media + EOC, cluster 1: EOC, cluster 2 (root): EOC
    def put_fat(c: int, val: int) -> None:
        off = c * 4
        fat[off : off + 4] = _u32(val)

    put_fat(0, 0x0FFFFFF8)
    put_fat(1, 0x0FFFFFFF)
    put_fat(ROOT_CLUSTER, 0x0FFFFFFF)
    fat_start = part_lba + reserved
    for fi in range(FAT_COUNT):
        base = (fat_start + fi * spf) * SECTOR_SIZE
        image[base : base + len(fat)] = fat

    # Root directory cluster is already zeroed (empty).
    return image


def populate(image: bytearray, files: list[tuple[str, bytes]]) -> bytearray:
    """Write named files into the image via Fat32Volume."""
    mem = Memory()
    card = SdSpiCard(mem, image)
    card.init()
    vol = Fat32Volume(mem, card)
    vol.mount()
    for name, data in files:
        vol.write_file(name, data)
    return card.image


def patch_card_file(img_path: Path, name: str, data: bytes) -> None:
    """Overwrite one 8.3 file in an existing card.img."""
    data, _ = squash_long_html_lines(name, data)
    raw = bytearray(img_path.read_bytes())
    mem = Memory()
    card = SdSpiCard(mem, raw)
    card.init()
    vol = Fat32Volume(mem, card)
    vol.mount()
    vol.write_file(name, data)
    img_path.write_bytes(bytes(card.image))


def create_image(
    path: Path,
    size_bytes: int = DEFAULT_SIZE,
    files: list[tuple[str, bytes]] | None = None,
    *,
    include_storage: bool = True,
    force: bool = False,
) -> Path:
    """Format a FAT32 image, optionally seed from storage/, then add `files`."""
    image = format_fat32(size_bytes)
    pairs: list[tuple[str, bytes]] = []
    if include_storage:
        pairs.extend(collect_storage_files())
    if files:
        # Explicit --files override same-named storage entries.
        by_name = {n: d for n, d in pairs}
        for name, data in files:
            by_name[name.upper()] = data
        pairs = list(by_name.items())
    # NEW: blank/whitespace-only .bas lines never reach the card (see
    # strip_blank_bas_lines). Do this BEFORE check_storage so the lint sees
    # what the board will actually load.
    # Standalone: mint .JSH from the RAW html, before squash_long_html_lines
    # replaces fat asset lines with placeholders (the card HTML is display-only,
    # but the sidecar must be compiled from the real source).
    sidecars = compile_sidecars(pairs)
    pairs, strip_notes = sanitize_bas_files(pairs)
    for n in strip_notes:
        print(f"note: {n}", file=sys.stderr)
    pairs.extend(sidecars)
    # Refuse by default to build a card the board cannot read (--force overrides).
    errors, warns = check_storage(pairs)
    for w in warns:
        print(f"warning: {w}", file=sys.stderr)
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        if not force:
            raise SystemExit(
                f"{len(errors)} problem(s) the board cannot load; "
                f"fix them or pass --force"
            )
    if pairs:
        image = populate(image, pairs)
    path.write_bytes(image)
    return path


def _lsblk(device: str = "") -> str:
    cmd = ["lsblk", "-o", "NAME,SIZE,TYPE,RM,MOUNTPOINT,MODEL"]
    if device:
        cmd.append(device)
    try:
        return subprocess.run(cmd, capture_output=True, text=True, check=False).stdout
    except FileNotFoundError:
        return "(lsblk not available)\n"


def _base_disk(device: str) -> str:
    """/dev/sdb1 -> sdb, /dev/mmcblk0p1 -> mmcblk0."""
    name = Path(device).name
    for path in Path("/sys/block").iterdir():
        if name == path.name or name.startswith(path.name):
            return path.name
    return name


def _mounted_partitions(device: str) -> list[tuple[str, str]]:
    """Every mounted partition of this disk, as (device, mountpoint)."""
    out: list[tuple[str, str]] = []
    base = _base_disk(device)
    for line in Path("/proc/mounts").read_text().splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].startswith("/dev/"):
            if Path(parts[0]).name.startswith(base):
                out.append((parts[0], parts[1]))
    return out


def guard_device(device: str, *, allow_fixed: bool = False) -> None:
    """Refuse anything that is not plainly a removable card. Raises SystemExit.

    This tool writes raw sectors, so pointing it at the wrong disk destroys it.
    Every check here is about making that mistake impossible, not about FAT32.
    """
    path = Path(device)
    if not path.exists():
        raise SystemExit(f"{device} does not exist\n\n{_lsblk()}")
    if not path.is_block_device():
        raise SystemExit(f"{device} is not a block device\n\n{_lsblk()}")
    base = _base_disk(device)
    if path.name != base:
        raise SystemExit(
            f"{device} looks like a partition; give the whole disk (/dev/{base}) "
            f"-- the image contains its own MBR and partition table"
        )
    removable = Path(f"/sys/block/{base}/removable")
    is_rm = removable.is_file() and removable.read_text().strip() == "1"
    # USB card readers often report removable=0, so also accept a USB transport.
    is_usb = "usb" in os.path.realpath(f"/sys/block/{base}").lower()
    if not (is_rm or is_usb or allow_fixed):
        raise SystemExit(
            f"/dev/{base} is not removable and is not on USB -- refusing.\n"
            f"If you are certain, re-run with --allow-fixed.\n\n{_lsblk()}"
        )
    for dev, mnt in _mounted_partitions(device):
        if mnt in ("/", "/boot", "/boot/efi", "/home", "/usr", "/var"):
            raise SystemExit(f"{dev} is mounted at {mnt} -- this is a system disk")


def _holders(mountpoint: str) -> str:
    """Processes keeping a mountpoint busy. fuser reports on stderr."""
    try:
        r = subprocess.run(
            ["fuser", "-vm", mountpoint], capture_output=True, text=True, check=False
        )
        return (r.stderr or r.stdout).strip() or "(none found)"
    except FileNotFoundError:
        return "(fuser not installed; try: lsof " + mountpoint + ")"


def unmount_device(device: str) -> None:
    """Unmount every partition of the card; a mounted card corrupts a raw write.

    A desktop file manager (Nautilus/GVFS) holds a directory handle on any card
    it has a window open for, which makes a bare `umount` fail with EBUSY. Ask
    udisks first -- it owns the mount and coordinates the release with the file
    manager -- and only fall back to umount. Never lazy-unmount: the kernel could
    write dirty pages of the old filesystem back over the image we just laid down.
    """
    for dev, mnt in _mounted_partitions(device):
        print(f"unmounting {dev} (at {mnt}) ...")
        for cmd in (["udisksctl", "unmount", "-b", dev], ["umount", dev]):
            try:
                r = subprocess.run(cmd, capture_output=True, text=True, check=False)
            except FileNotFoundError:
                continue
            if all(d != dev for d, _ in _mounted_partitions(device)):
                break
            msg = (r.stderr or r.stdout).strip()
            if msg:
                print(f"  {cmd[0]}: {msg}")
        else:
            raise SystemExit(
                f"\n{dev} is still mounted at {mnt} -- refusing to write it.\n"
                f"Something is holding it open:\n{_holders(mnt)}\n\n"
                f"An open Files/Nautilus window on the card is the usual cause: "
                f"close it (or eject the card in Files) and re-run."
            )


def write_device(image_path: Path, device: str, *, verify: bool = True) -> None:
    """Raw-write the image to the card, then read it back and mount it.

    Verification re-mounts the bytes read back off the card through the same
    Fat32Volume the FPGA's storage_engine mirrors, so "the board can see it" is
    actually proven rather than assumed.
    """
    data = image_path.read_bytes()
    print(f"writing {len(data)} bytes to {device} ...")
    with open(device, "wb") as fh:
        fh.write(data)
        fh.flush()
        os.fsync(fh.fileno())
    subprocess.run(["sync"], check=False)
    if not verify:
        return
    # Drop the page cache for this device so the readback is really from flash.
    with open(device, "rb") as fh:
        try:
            os.posix_fadvise(fh.fileno(), 0, 0, os.POSIX_FADV_DONTNEED)
        except (AttributeError, OSError):
            pass
        back = fh.read(len(data))
    if back != data:
        first = next((i for i in range(len(data)) if back[i : i + 1] != data[i : i + 1]), 0)
        # The desktop auto-remounts a card the moment it is written, and mounting
        # vfat dirties the boot sector's dirty bit -- that is a remount, not a bad
        # card, so say which one it is instead of just crying corruption.
        remounted = _mounted_partitions(device)
        hint = (
            f"\n{remounted[0][0]} was auto-remounted at {remounted[0][1]} during the "
            f"write, which rewrites FAT metadata. Eject the card in Files, then "
            f"re-run."
            if remounted
            else ""
        )
        raise SystemExit(f"verify FAILED: card differs from image at byte {first}{hint}")
    print("verify: card matches image byte for byte")
    mem = Memory()
    card = SdSpiCard(mem, bytearray(back))
    card.init()
    vol = Fat32Volume(mem, card)
    vol.mount()
    names = vol.catalog()
    print(f"card mounts as FAT32; {len(names)} file(s) visible to the board:")
    print("  " + ", ".join(names) if names else "  (empty)")


def open_volume(path: Path) -> Fat32Volume:
    mem = Memory()
    card = SdSpiCard(mem, path)
    card.init()
    vol = Fat32Volume(mem, card)
    vol.mount()
    return vol


def _parse_size(text: str) -> int:
    text = text.strip().upper()
    if text.endswith("M"):
        return int(float(text[:-1]) * 1024 * 1024)
    if text.endswith("K"):
        return int(float(text[:-1]) * 1024)
    return int(text)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_create = sub.add_parser("create", help="create a FAT32 card image")
    p_create.add_argument("image", type=Path)
    p_create.add_argument("--size", default="16M")
    p_create.add_argument(
        "--files",
        nargs="*",
        default=[],
        help="extra host files to copy onto the card (override storage/ on name clash)",
    )
    p_create.add_argument(
        "--no-storage",
        action="store_true",
        help="do not auto-copy project storage/ onto the card",
    )
    p_create.add_argument(
        "--force",
        action="store_true",
        help="build the card even if a program breaks a board limit",
    )

    sub.add_parser("check", help="lint storage/ against the board's LOAD limits")

    p_burn = sub.add_parser(
        "burn",
        help="rebuild card.img from storage/ and raw-write it to a real card",
    )
    p_burn.add_argument("device", help="whole-disk device of the card, e.g. /dev/sdb")
    p_burn.add_argument("--image", type=Path, default=ROOT / "card.img")
    p_burn.add_argument("--size", default="16M")
    p_burn.add_argument(
        "--keep-image",
        action="store_true",
        help="write the existing --image as-is instead of rebuilding from storage/",
    )
    p_burn.add_argument(
        "--allow-fixed",
        action="store_true",
        help="permit a non-removable, non-USB disk (dangerous)",
    )
    p_burn.add_argument("--no-verify", action="store_true")
    p_burn.add_argument("--force", action="store_true", help="ignore program problems")

    p_list = sub.add_parser("list", help="list root directory")
    p_list.add_argument("image", type=Path)

    p_extract = sub.add_parser("extract", help="extract one file")
    p_extract.add_argument("image", type=Path)
    p_extract.add_argument("name")
    p_extract.add_argument("dest", type=Path, nargs="?", default=None)

    args = parser.parse_args(argv)
    if args.cmd == "create":
        pairs: list[tuple[str, bytes]] = []
        for f in args.files:
            p = Path(f)
            pairs.append((p.name.upper(), p.read_bytes()))
        create_image(
            args.image,
            _parse_size(args.size),
            pairs or None,
            include_storage=not args.no_storage,
            force=args.force,
        )
        # Report what landed on the card.
        vol = open_volume(args.image)
        names = vol.catalog()
        print(f"wrote {args.image} ({args.image.stat().st_size} bytes)")
        print(f"{len(names)} file(s): {', '.join(names) if names else '(empty)'}")
        return 0
    if args.cmd == "check":
        errors, warns = check_storage(collect_storage_files(), note_names=True)
        for w in warns:
            print(f"warning: {w}")
        for e in errors:
            print(f"error: {e}")
        if errors:
            print(f"\n{len(errors)} problem(s) the board cannot load")
            return 1
        print(f"storage/ is clean for the board (lines <= {LINE_MAX} chars)")
        return 0
    if args.cmd == "burn":
        # Guard before anything is built, so a bad device name costs nothing.
        guard_device(args.device, allow_fixed=args.allow_fixed)
        if os.geteuid() != 0:
            # Raw sector writes and umount both need root; say so rather than
            # failing with a bare EACCES halfway through.
            print(_lsblk(args.device))
            raise SystemExit(
                f"burning needs root to unmount the card and write raw sectors.\n"
                f"Re-run:  sudo python3 tools/make_sd_image.py burn {args.device}"
            )
        if args.keep_image:
            if not args.image.is_file():
                raise SystemExit(f"{args.image} does not exist")
            print(f"using existing {args.image}")
        else:
            create_image(
                args.image, _parse_size(args.size), None,
                include_storage=True, force=args.force,
            )
            print(f"built {args.image} from storage/")
        print(_lsblk(args.device))
        unmount_device(args.device)
        write_device(args.image, args.device, verify=not args.no_verify)
        print("done -- the card is safe to remove")
        return 0
    if args.cmd == "list":
        vol = open_volume(args.image)
        for name in vol.catalog():
            print(name)
        return 0
    if args.cmd == "extract":
        vol = open_volume(args.image)
        data = vol.read_file(args.name)
        dest = args.dest or Path(args.name)
        dest.write_bytes(data)
        print(f"extracted {args.name} -> {dest} ({len(data)} bytes)")
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
