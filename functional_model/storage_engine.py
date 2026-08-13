"""Storage — host directory of ordinary .JS / .HTML files (card seed).

LLM NOTE: Pattern cite BASIC make_sd_image / storage/ — method only.
V1 FM uses a writable workspace dir (default storage/) so SAVE/LOAD work
without a full FAT32 stack; card.img tooling wraps the same files.
"""

from __future__ import annotations

from pathlib import Path
from typing import List, Optional

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STORAGE = ROOT / "storage"


class StorageEngine:
    def __init__(self, root: Optional[Path] = None) -> None:
        self.root = Path(root) if root is not None else DEFAULT_STORAGE
        self.root.mkdir(parents=True, exist_ok=True)

    def catalog(self) -> List[str]:
        names: List[str] = []
        for p in sorted(self.root.iterdir()):
            if not p.is_file() or p.name.startswith("."):
                continue
            # Monitor DIR shows game/program files only.
            if p.suffix.upper() in (".JS", ".HTML", ".HTM", ".PNG", ".DAT"):
                names.append(p.name)
        return names

    def load_text(self, name: str) -> str:
        path = self._resolve(name)
        if not path.is_file():
            raise FileNotFoundError(name)
        return path.read_text(encoding="utf-8")

    def resolve_name(self, name: str) -> str:
        """Return on-disk basename after case/extension resolve."""
        path = self._resolve(name)
        if not path.is_file():
            raise FileNotFoundError(name)
        return path.name

    def save_text(self, name: str, text: str) -> None:
        path = self._resolve(name)
        path.write_text(text, encoding="utf-8")

    def delete(self, name: str) -> None:
        path = self._resolve(name)
        if path.is_file():
            path.unlink()

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
