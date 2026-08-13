"""ASIC-SIM backend slot — later when explicitly opened.

Pattern cite: BASIC asic_sim_backend.py. Not available until asic sim binary exists.
"""

from __future__ import annotations

from pathlib import Path
from typing import Optional

from runtime.sim_backend import SimBackend, SIM_DIR

_ASIC = SIM_DIR / "sim_build_asic" / "jmr_js_sim_server"


class AsicSimBackend(SimBackend):
    name = "ASIC-SIM"

    @property
    def available(self) -> bool:
        # Later: F9 fourth runtime when asic Verilator binary is built.
        return _ASIC.is_file()
