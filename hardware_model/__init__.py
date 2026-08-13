"""Hardware model stubs for card.img tooling + JS VM memory twin.

LLM NOTE: fat32.py / sd_spi.py copied from JMR-BASIC-FPGA-COMPUTER (working
FAT32 path). js_vm.py is the Python HM of rtl/engines/jmr_js_vm.sv.
"""

from .fat32 import Fat32Volume
from .js_vm import CODE_WORDS, HEAP_SLOTS, MAX_CONSTS, MAX_VARS, JsHwVm
from .sd_spi import SdSpiCard

__all__ = [
    "Fat32Volume",
    "SdSpiCard",
    "JsHwVm",
    "CODE_WORDS",
    "MAX_CONSTS",
    "MAX_VARS",
    "HEAP_SLOTS",
]
