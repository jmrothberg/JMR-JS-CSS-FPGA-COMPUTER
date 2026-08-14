"""Phase-2 FAT32 filesystem over SdSpiCard (read, create, grow, delete).

Constraints (buildable in fabric):
  FAT32 only, MBR + one partition, 512-byte sectors, root directory only,
  8.3 uppercase names, no LFN creation, no subdirectories.
  NEW: delete_file marks the dirent 0xE5 and frees the cluster chain.

Device-local sector buffer lives outside the 64K map; only STORAGE_BUFFER
is BASIC-visible (via SdSpiCard.read_block / write_block).
"""

from __future__ import annotations

from dataclasses import dataclass

from functional_model import memory_map as mm
from functional_model.memory import Memory

from .sd_spi import SECTOR_SIZE, SdSpiCard

EOC = 0x0FFFFFFF  # end-of-cluster marker (FAT32)
BAD = 0x0FFFFFF7
FREE = 0x00000000
ATTR_DIR = 0x10
ATTR_VOLUME = 0x08
ATTR_LFN = 0x0F


@dataclass
class FatGeom:
    part_lba: int
    bytes_per_sector: int
    sectors_per_cluster: int
    reserved_sectors: int
    fat_count: int
    sectors_per_fat: int
    root_cluster: int
    fsinfo_sector: int
    fat_start: int  # absolute LBA of first FAT
    data_start: int  # absolute LBA of cluster 2
    # NEW: partition sector count (BPB total_sectors_32) — caps allocation so
    # FAT tail entries with no backing data sectors are never handed out
    total_sectors: int = 0


class Fat32Volume:
    """Mounted FAT32 volume with create / grow / overwrite."""

    def __init__(self, memory: Memory, card: SdSpiCard) -> None:
        self.memory = memory
        self.card = card
        self.geom: FatGeom | None = None
        # Device-local sector cache (not in the 64K map).
        self._cache_lba = -1
        self._cache = bytearray(SECTOR_SIZE)
        self._cache_dirty = False

    # -- mount --------------------------------------------------------------

    def mount(self) -> None:
        if not self.card.initialised:
            self.card.init()
        mbr = self.card.read_block(0)
        # Prefer MBR partition type 0x0B/0x0C; fall back to superfloppy at LBA 0.
        part_lba = 0
        entry = mbr[446 : 446 + 16]
        ptype = entry[4]
        if ptype in (0x0B, 0x0C, 0x0E) or (ptype != 0 and mbr[510:512] == b"\x55\xaa"):
            part_lba = (
                entry[8] | (entry[9] << 8) | (entry[10] << 16) | (entry[11] << 24)
            )
            if part_lba == 0 and ptype == 0:
                part_lba = 0
        bpb = self.card.read_block(part_lba)
        if bpb[510:512] != b"\x55\xaa":
            self._set_error()
            raise OSError("no FAT32 signature")
        bps = bpb[11] | (bpb[12] << 8)
        if bps != SECTOR_SIZE:
            self._set_error()
            raise OSError(f"unsupported bytes/sector {bps}")
        spc = bpb[13]
        reserved = bpb[14] | (bpb[15] << 8)
        fats = bpb[16]
        # FAT32: sectors_per_fat_32 at offset 36; root_cluster at 44; fsinfo at 48.
        spf = (
            bpb[36]
            | (bpb[37] << 8)
            | (bpb[38] << 16)
            | (bpb[39] << 24)
        )
        # If FAT16 BPB (spf16 non-zero and spf32 zero), reject.
        spf16 = bpb[22] | (bpb[23] << 8)
        if spf == 0:
            if spf16:
                self._set_error()
                raise OSError("FAT16 not supported")
            self._set_error()
            raise OSError("invalid sectors per FAT")
        root = (
            bpb[44]
            | (bpb[45] << 8)
            | (bpb[46] << 16)
            | (bpb[47] << 24)
        )
        fsinfo = bpb[48] | (bpb[49] << 8)
        # NEW: partition size (total_sectors_32 at offset 32) for alloc bound
        total32 = (
            bpb[32]
            | (bpb[33] << 8)
            | (bpb[34] << 16)
            | (bpb[35] << 24)
        )
        fat_start = part_lba + reserved
        data_start = fat_start + fats * spf
        self.geom = FatGeom(
            part_lba=part_lba,
            bytes_per_sector=bps,
            sectors_per_cluster=spc,
            reserved_sectors=reserved,
            fat_count=fats,
            sectors_per_fat=spf,
            root_cluster=root if root >= 2 else 2,
            fsinfo_sector=fsinfo,
            fat_start=fat_start,
            data_start=data_start,
            total_sectors=total32,
        )
        self._publish_geom()
        self.memory.write(mm.IO_FS_STATUS, mm.FS_STATUS_MOUNTED)

    def _set_error(self) -> None:
        self.memory.write(mm.IO_FS_STATUS, mm.FS_STATUS_ERROR)

    def _publish_geom(self) -> None:
        g = self.geom
        assert g is not None
        self.memory.write(mm.IO_FS_SPC, g.sectors_per_cluster & 0xFF)
        self.memory.write(mm.IO_FS_RESERVED_LO, g.reserved_sectors & 0xFF)
        self.memory.write(mm.IO_FS_RESERVED_HI, (g.reserved_sectors >> 8) & 0xFF)
        for i, b in enumerate(
            (
                g.sectors_per_fat & 0xFF,
                (g.sectors_per_fat >> 8) & 0xFF,
                (g.sectors_per_fat >> 16) & 0xFF,
                (g.sectors_per_fat >> 24) & 0xFF,
            )
        ):
            self.memory.write(mm.IO_FS_FAT_SECTS_0 + i, b)
        for i, b in enumerate(
            (
                g.root_cluster & 0xFF,
                (g.root_cluster >> 8) & 0xFF,
                (g.root_cluster >> 16) & 0xFF,
                (g.root_cluster >> 24) & 0xFF,
            )
        ):
            self.memory.write(mm.IO_FS_ROOT_CLUS_0 + i, b)
        for i, b in enumerate(
            (
                g.part_lba & 0xFF,
                (g.part_lba >> 8) & 0xFF,
                (g.part_lba >> 16) & 0xFF,
                (g.part_lba >> 24) & 0xFF,
            )
        ):
            self.memory.write(mm.IO_FS_PART_LBA_0 + i, b)

    def _require(self) -> FatGeom:
        if self.geom is None:
            self.mount()
        assert self.geom is not None
        return self.geom

    # -- sector cache -------------------------------------------------------

    def _read_sector(self, lba: int) -> bytearray:
        if self._cache_lba == lba and not self._cache_dirty:
            return self._cache
        self._flush()
        data = self.card.read_block(lba)
        self._cache = bytearray(data)
        self._cache_lba = lba
        self._cache_dirty = False
        return self._cache

    def _write_sector(self, lba: int, data: bytes | bytearray) -> None:
        self._flush()
        payload = bytes(data[:SECTOR_SIZE]).ljust(SECTOR_SIZE, b"\0")
        self.card.write_block(lba, payload)
        self._cache = bytearray(payload)
        self._cache_lba = lba
        self._cache_dirty = False

    def _mark_dirty(self) -> None:
        self._cache_dirty = True

    def _flush(self) -> None:
        if self._cache_dirty and self._cache_lba >= 0:
            self.card.write_block(self._cache_lba, bytes(self._cache))
            self._cache_dirty = False

    # -- cluster / FAT ------------------------------------------------------

    def _cluster_lba(self, cluster: int) -> int:
        g = self._require()
        return g.data_start + (cluster - 2) * g.sectors_per_cluster

    def _fat_get(self, cluster: int) -> int:
        g = self._require()
        offset = cluster * 4
        sect = g.fat_start + (offset // SECTOR_SIZE)
        off = offset % SECTOR_SIZE
        buf = self._read_sector(sect)
        val = (
            buf[off]
            | (buf[off + 1] << 8)
            | (buf[off + 2] << 16)
            | (buf[off + 3] << 24)
        )
        return val & 0x0FFFFFFF

    def _fat_set(self, cluster: int, value: int) -> None:
        g = self._require()
        value &= 0x0FFFFFFF
        offset = cluster * 4
        for fat_i in range(g.fat_count):
            sect = g.fat_start + fat_i * g.sectors_per_fat + (offset // SECTOR_SIZE)
            off = offset % SECTOR_SIZE
            buf = self._read_sector(sect)
            # Preserve top 4 bits of on-disk entry.
            old = (
                buf[off]
                | (buf[off + 1] << 8)
                | (buf[off + 2] << 16)
                | (buf[off + 3] << 24)
            )
            new = (old & 0xF0000000) | value
            buf[off] = new & 0xFF
            buf[off + 1] = (new >> 8) & 0xFF
            buf[off + 2] = (new >> 16) & 0xFF
            buf[off + 3] = (new >> 24) & 0xFF
            self._mark_dirty()
            self._flush()

    def _alloc_cluster(self) -> int:
        g = self._require()
        hint = 2
        # FSInfo free-cluster hint at offset 492 of FSInfo sector (optional).
        if g.fsinfo_sector:
            fs = self._read_sector(g.part_lba + g.fsinfo_sector)
            if fs[0:4] == b"RRaA" and fs[484:488] == b"rrAa":
                hint = (
                    fs[492] | (fs[493] << 8) | (fs[494] << 16) | (fs[495] << 24)
                )
                if hint < 2 or hint >= 0x0FFFFFF0:
                    hint = 2
        max_cluster = (g.sectors_per_fat * SECTOR_SIZE) // 4
        # NEW: FAT sizing rounds up, so tail entries can point past the card
        # (DONKEY 2.4 MB patch hit "LBA 32768 out of range"). Cap allocation
        # at clusters whose data sectors actually exist in the partition.
        if g.total_sectors:
            data_secs = g.part_lba + g.total_sectors - g.data_start
            max_cluster = min(max_cluster, 2 + data_secs // g.sectors_per_cluster)
        if hint >= max_cluster:
            hint = 2
        for c in range(hint, max_cluster):
            if self._fat_get(c) == FREE:
                self._fat_set(c, EOC)
                self._update_fsinfo(c + 1)
                # Zero the new cluster.
                lba = self._cluster_lba(c)
                blank = bytes(SECTOR_SIZE)
                for s in range(g.sectors_per_cluster):
                    self._write_sector(lba + s, blank)
                return c
        for c in range(2, hint):
            if self._fat_get(c) == FREE:
                self._fat_set(c, EOC)
                self._update_fsinfo(c + 1)
                lba = self._cluster_lba(c)
                blank = bytes(SECTOR_SIZE)
                for s in range(g.sectors_per_cluster):
                    self._write_sector(lba + s, blank)
                return c
        raise OSError("disk full")

    def _update_fsinfo(self, next_free: int) -> None:
        g = self._require()
        if not g.fsinfo_sector:
            return
        fs = self._read_sector(g.part_lba + g.fsinfo_sector)
        if fs[0:4] != b"RRaA":
            return
        fs[492] = next_free & 0xFF
        fs[493] = (next_free >> 8) & 0xFF
        fs[494] = (next_free >> 16) & 0xFF
        fs[495] = (next_free >> 24) & 0xFF
        # Leave free-count as unknown (0xFFFFFFFF).
        fs[488:492] = b"\xff\xff\xff\xff"
        self._mark_dirty()
        self._flush()

    def _free_chain(self, cluster: int) -> None:
        while 2 <= cluster < BAD:
            nxt = self._fat_get(cluster)
            self._fat_set(cluster, FREE)
            if nxt >= BAD or nxt == EOC or nxt < 2:
                break
            cluster = nxt

    def _chain(self, start: int) -> list[int]:
        out: list[int] = []
        c = start
        seen: set[int] = set()
        while 2 <= c < BAD:
            if c in seen:
                break
            seen.add(c)
            out.append(c)
            nxt = self._fat_get(c)
            if nxt >= BAD or nxt < 2:
                break
            c = nxt
        return out

    # -- 8.3 names ----------------------------------------------------------

    @staticmethod
    def encode_83(name: str) -> bytes:
        """Uppercase 8.3 directory name (11 bytes, space-padded)."""
        name = name.replace("/", "\\").split("\\")[-1].upper()
        if "." in name:
            stem, _, ext = name.partition(".")
        else:
            stem, ext = name, ""
        stem = "".join(c for c in stem if c.isalnum() or c in "$%'-_@~`!(){}^#&")[:8]
        ext = "".join(c for c in ext if c.isalnum() or c in "$%'-_@~`!(){}^#&")[:3]
        return (stem.ljust(8) + ext.ljust(3)).encode("ascii")

    @staticmethod
    def decode_83(raw: bytes) -> str:
        stem = raw[0:8].decode("ascii", "replace").rstrip()
        ext = raw[8:11].decode("ascii", "replace").rstrip()
        return f"{stem}.{ext}" if ext else stem

    # -- directory ----------------------------------------------------------

    def _dir_entries(self):
        """Yield (cluster, sector_index, offset, entry_bytes) for root dir."""
        g = self._require()
        for cluster in self._chain(g.root_cluster):
            base = self._cluster_lba(cluster)
            for s in range(g.sectors_per_cluster):
                buf = self._read_sector(base + s)
                for off in range(0, SECTOR_SIZE, 32):
                    yield cluster, s, off, bytes(buf[off : off + 32])

    def find(self, name: str) -> tuple[int, int, int, bytes] | None:
        """Locate 8.3 entry; return (cluster, sect_in_clus, offset, entry) or None."""
        target = self.encode_83(name)
        for cluster, s, off, ent in self._dir_entries():
            if ent[0] == 0x00:
                return None  # end of directory
            if ent[0] == 0xE5:
                continue
            attr = ent[11]
            if attr == ATTR_LFN or attr & ATTR_VOLUME:
                continue
            if ent[0:11] == target:
                return cluster, s, off, ent
        return None

    def exists(self, name: str) -> bool:
        return self.find(name) is not None

    def list_root(self) -> list[str]:
        names: list[str] = []
        for _c, _s, _o, ent in self._dir_entries():
            if ent[0] == 0x00:
                break
            if ent[0] == 0xE5:
                continue
            attr = ent[11]
            if attr == ATTR_LFN or attr & ATTR_VOLUME or attr & ATTR_DIR:
                continue
            names.append(self.decode_83(ent[0:11]))
        return names

    def _entry_cluster(self, ent: bytes) -> int:
        return (
            ent[26]
            | (ent[27] << 8)
            | (ent[20] << 16)
            | (ent[21] << 24)
        )

    def _entry_size(self, ent: bytes) -> int:
        return ent[28] | (ent[29] << 8) | (ent[30] << 16) | (ent[31] << 24)

    def _write_entry(
        self,
        cluster: int,
        sect_in_clus: int,
        offset: int,
        name83: bytes,
        first_cluster: int,
        size: int,
        attr: int = 0x20,
    ) -> None:
        g = self._require()
        lba = self._cluster_lba(cluster) + sect_in_clus
        buf = self._read_sector(lba)
        ent = bytearray(32)
        ent[0:11] = name83
        ent[11] = attr
        ent[20] = (first_cluster >> 16) & 0xFF
        ent[21] = (first_cluster >> 24) & 0xFF
        ent[26] = first_cluster & 0xFF
        ent[27] = (first_cluster >> 8) & 0xFF
        ent[28] = size & 0xFF
        ent[29] = (size >> 8) & 0xFF
        ent[30] = (size >> 16) & 0xFF
        ent[31] = (size >> 24) & 0xFF
        buf[offset : offset + 32] = ent
        self._mark_dirty()
        self._flush()

    def _find_free_slot(self) -> tuple[int, int, int]:
        """Return (cluster, sect_in_clus, offset) for a free/deleted dir entry."""
        g = self._require()
        last = None
        for cluster, s, off, ent in self._dir_entries():
            last = (cluster, s, off)
            if ent[0] == 0x00 or ent[0] == 0xE5:
                return cluster, s, off
        # Grow root directory by one cluster.
        assert last is not None
        chain = self._chain(g.root_cluster)
        new_c = self._alloc_cluster()
        self._fat_set(chain[-1], new_c)
        self._fat_set(new_c, EOC)
        return new_c, 0, 0

    # -- file I/O -----------------------------------------------------------

    def read_file(self, name: str) -> bytes:
        found = self.find(name)
        if found is None:
            raise FileNotFoundError(name)
        _c, _s, _o, ent = found
        size = self._entry_size(ent)
        start = self._entry_cluster(ent)
        if size == 0 or start < 2:
            return b""
        g = self._require()
        out = bytearray()
        for cluster in self._chain(start):
            lba = self._cluster_lba(cluster)
            for s in range(g.sectors_per_cluster):
                out.extend(self._read_sector(lba + s))
                if len(out) >= size:
                    return bytes(out[:size])
        return bytes(out[:size])

    def write_file(self, name: str, data: bytes) -> None:
        """Create or overwrite an 8.3 file with `data`."""
        g = self._require()
        name83 = self.encode_83(name)
        found = self.find(name)
        if found is not None:
            cluster, s, off, ent = found
            old = self._entry_cluster(ent)
            if old >= 2:
                self._free_chain(old)
        else:
            cluster, s, off = self._find_free_slot()

        if not data:
            self._write_entry(cluster, s, off, name83, 0, 0)
            self._flush()
            return

        bytes_per_cluster = g.sectors_per_cluster * SECTOR_SIZE
        first = None
        prev = None
        offset = 0
        while offset < len(data):
            c = self._alloc_cluster()
            if first is None:
                first = c
            if prev is not None:
                self._fat_set(prev, c)
            self._fat_set(c, EOC)
            chunk = data[offset : offset + bytes_per_cluster]
            lba = self._cluster_lba(c)
            for si in range(g.sectors_per_cluster):
                part = chunk[si * SECTOR_SIZE : (si + 1) * SECTOR_SIZE]
                self._write_sector(lba + si, part.ljust(SECTOR_SIZE, b"\0"))
            offset += bytes_per_cluster
            prev = c

        assert first is not None
        self._write_entry(cluster, s, off, name83, first, len(data))
        self._flush()

    def catalog(self) -> list[str]:
        self._require()
        return self.list_root()

    # NEW: console REMOVE / host unlink — mark dirent deleted + free clusters
    def delete_file(self, name: str) -> None:
        found = self.find(name)
        if found is None:
            raise FileNotFoundError(name)
        cluster, sect_in_clus, offset, ent = found
        first = self._entry_cluster(ent)
        lba = self._cluster_lba(cluster) + sect_in_clus
        buf = self._read_sector(lba)
        buf[offset] = 0xE5
        self._mark_dirty()
        self._flush()
        if first >= 2:
            self._free_chain(first)
        self._flush()
