"""Hardware model stubs for card.img tooling + JS VM memory twin.

LLM NOTE: fat32.py / sd_spi.py copied from JMR-BASIC-FPGA-COMPUTER (working
FAT32 path). js_vm.py is the Python HM of rtl/engines/jmr_js_vm.sv.
"""

from .fat32 import Fat32Volume
from .js_vm import (
    ARRAY_ELEMENTS,
    CALL_DEPTH,
    CODE_WORDS,
    ENV_DEPTH,
    HEAP_SLOTS,
    LISTENERS_PER_EVENT,
    MAX_ARRAYS,
    MAX_CONSTS,
    MAX_OBJECTS,
    MAX_VARS,
    RAF_QUEUE_DEPTH,
    STACK_DEPTH,
    TIMER_QUEUE_DEPTH,
    JsHwVm,
    ProgramImage,
)
from .sd_spi import SdSpiCard

__all__ = [
    "Fat32Volume",
    "SdSpiCard",
    "JsHwVm",
    "ProgramImage",
    "CODE_WORDS",
    "MAX_CONSTS",
    "MAX_VARS",
    "HEAP_SLOTS",
    "STACK_DEPTH",
    "CALL_DEPTH",
    "MAX_OBJECTS",
    "MAX_ARRAYS",
    "ARRAY_ELEMENTS",
    "ENV_DEPTH",
    "RAF_QUEUE_DEPTH",
    "TIMER_QUEUE_DEPTH",
    "LISTENERS_PER_EVENT",
]
