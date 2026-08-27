"""Storage — V1.0 disk is card.img (same FAT PYTHON / FPGA-SIM / BOARD play).

LLM NOTE: Pattern cite BASIC make_sd_image / storage/ — method only.
`storage/` is the seed (`make_sd_image.py create`). Default Machine() mounts
project card.img (or $JMR_CARD_IMG). Explicit `root=` stays a host folder
so unit tests can use a temp dir.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import List, Optional

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STORAGE = ROOT / "storage"
DEFAULT_CARD = ROOT / "card.img"
_HIDE_SUFFIX = {".JSH", ".JSB"}


class StorageEngine:
    def __init__(self, root: Optional[Path] = None) -> None:
        self.root = Path(root) if root is not None else DEFAULT_STORAGE
        env = os.environ.get("JMR_CARD_IMG", "").strip()
        if root is not None:
            # Explicit folder (tests). Not the product disk.
            self.card_img: Optional[Path] = None
            self.root.mkdir(parents=True, exist_ok=True)
        else:
            self.card_img = Path(env) if env else DEFAULT_CARD
            self.root.mkdir(parents=True, exist_ok=True)

    def catalog(self) -> List[str]:
        names: list[str] = []
        if self.card_img is not None:
            if not self.card_img.is_file():
                return []
            for n in self._mount().catalog():
                if Path(n).suffix.upper() in _HIDE_SUFFIX:
                    continue
                names.append(n)
            return names
        for p in sorted(self.root.iterdir()):
            if not p.is_file() or p.name.startswith("."):
                continue
            # Monitor DIR shows game/program files only.
            if p.suffix.upper() in (".JS", ".HTML", ".HTM", ".PNG", ".DAT"):
                names.append(p.name)
        return names

    def load_text(self, name: str) -> str:
        data = self.load_bytes(name)
        return data.decode("utf-8")

    def load_bytes(self, name: str) -> bytes:
        if self.card_img is not None:
            if not self.card_img.is_file():
                raise FileNotFoundError(name)
            vol = self._mount()
            resolved = self._resolve_card_name(vol, name)
            if resolved is None:
                raise FileNotFoundError(name)
            return vol.read_file(resolved)
        path = self._resolve(name)
        if not path.is_file():
            raise FileNotFoundError(name)
        return path.read_bytes()

    def resolve_name(self, name: str) -> str:
        """Return on-disk basename after case/extension resolve."""
        if self.card_img is not None:
            if not self.card_img.is_file():
                raise FileNotFoundError(name)
            resolved = self._resolve_card_name(self._mount(), name)
            if resolved is None:
                raise FileNotFoundError(name)
            return resolved
        path = self._resolve(name)
        if not path.is_file():
            raise FileNotFoundError(name)
        return path.name

    def save_text(self, name: str, text: str) -> None:
        data = text.encode("utf-8")
        if self.card_img is not None:
            if not self.card_img.is_file():
                raise FileNotFoundError(name)
            vol = self._mount()
            vol.write_file(name, data)
            # Board SAVE of HTML deletes the minted .JSH so a stale image
            # cannot RUN silently.
            dest = Path(name).name
            if Path(dest).suffix.upper() in (".HTML", ".HTM"):
                stem = Path(dest).stem.upper()[:8]
                try:
                    vol.delete_file(stem + ".JSH")
                except FileNotFoundError:
                    pass
            self.card_img.write_bytes(bytes(vol.card.image))
            return
        path = self._resolve(name)
        path.write_text(text, encoding="utf-8")

    def delete(self, name: str) -> None:
        if self.card_img is not None:
            if not self.card_img.is_file():
                return
            vol = self._mount()
            try:
                vol.delete_file(name)
            except FileNotFoundError:
                return
            self.card_img.write_bytes(bytes(vol.card.image))
            return
        path = self._resolve(name)
        if path.is_file():
            path.unlink()

    def _mount(self):
        from functional_model.memory import Memory
        from hardware_model.fat32 import Fat32Volume
        from hardware_model.sd_spi import SdSpiCard

        mem = Memory()
        card = SdSpiCard(mem, self.card_img)
        card.init()
        vol = Fat32Volume(mem, card)
        vol.mount()
        return vol

    @staticmethod
    def _resolve_card_name(vol, name: str) -> Optional[str]:
        """Match LOAD names the way FAT 8.3 does (HTML → HTM)."""
        base = Path(name).name
        if vol.find(base) is not None:
            return vol.decode_83(vol.encode_83(base))
        if "." not in base:
            for ext in (".JS", ".HTML", ".HTM"):
                cand = base + ext
                if vol.find(cand) is not None:
                    return vol.decode_83(vol.encode_83(cand))
        return None

    def _resolve(self, name: str) -> Path:
        # Keep names flat — no path traversal. Case-insensitive match on Linux.
        base = Path(name).name
        exact = self.root / base
        if exact.is_file():
            return exact
        want = base.casefold()
        for p in self.root.iterdir():
            if p.is_file() and p.name.casefold() == want:
                return p
        # Optional extension: INVADERS_FULL → INVADERS_FULL.HTML / .JS
        if "." not in base:
            # .JS first so LOAD "invaders" is the FPGA-SIM bytecode title.
            for ext in (".JS", ".HTML", ".HTM"):
                cand = self.root / (base + ext)
                if cand.is_file():
                    return cand
                for p in self.root.iterdir():
                    if p.is_file() and p.name.casefold() == (base + ext).casefold():
                        return p
        return exact
