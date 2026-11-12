# Build 97 and after: items that need a new .bit

Everything in the tables changes `rtl/` or what is synthesized into the
bitstream. Fixes that only change the card (Toolbox, Finder, programs) go out
with a new `card.img` and do not wait for this list.

## Build 97 (in progress, `build/run97`)

| Item | Change |
|---|---|
| Name table 32 KB | `NAME_CAP` 16384 → 32768 in `jmr_js_vm.sv`, `jmr_js_vm_pkg.sv` and `functional_model/jsb_format.py` (`PROGRAM_NAME_BYTES`). Address widths were already 15–16 bits. About 4 more BRAM tiles. Sized from measurement: Prince today uses 15,038 name bytes; the original Apple II tables packed from `SEQTABLE.S` (2,546 bytes) and `FRAMEDEF.S` (2,001 bytes) bring it to 19,585, about 21,100 as base64. 49,152 is not needed. |
| Built-in Toolbox matches the card | The bit's fallback bank is rebuilt from `vectors/toolbox_code*.hex` (menu flash, optimized Toolbox). |

The Toolbox is now compiled with the same optimizer as applications
(`tools/toolbox_linker.py`): 7,512 words instead of 8,189, so about 680 words
are free in the existing 8,191-word bank. Doubling the bank is no longer
needed for the items it was waiting on.

## Not in build 97, and why

| Item | Why not yet |
|---|---|
| `SOURCE_MAX` 65536 → 131072 | The SOURCE buffer sits in the 8 MiB external window between the compiler arena and the image/compile staging region (`docs/lastrun_ARCHITECTURE.md`, Memory). Doubling it needs 131,072 more bytes of that window: either the art ceiling (`CART_MAX_BYTES`) drops by that much or the staging region moves. Prince's HTML is 44,143 of 65,536 bytes today; do it when a program needs it. |
| `CODE_WORDS` 21504 → 29696 | Only after the Prince move player is written and `tools/check_port.py` overflows (about 10 KB of code image is free). About 7 BRAM tiles. |
| Fewer clocks per instruction | Measure clocks per instruction on the RTL simulator for the most-run instructions (property read, compare, branch, call), then shorten the common ones in `jmr_js_vm.sv`. |
| Faster VM clock | The VM clock has +0.037 ns at 30 ns: its longest paths (the 64-bit multiply and float path in `u_exec64`, 25 logic levels) fill the cycle. Pipelining them would allow 50 MHz, 1.5× for every program. The largest item; needs timing margin first. |
| Timing margin | At +0.005 ns any new logic can fail timing. The remaining paths are a flat spread of about twenty within 0.1 ns (`docs/FPGA_FIT.md`, known gaps 1 and 2); aim for +0.1 ns. |
| Hardware math commands | Only if there is room and it is easy. Donkey Kong spends little time in math. |

Donkey Kong's speed was a card change, not a bit change: the game ran about
3,200 instructions a frame and moved 1 world pixel per frame. It now runs its
rules `DK_SPEED` (2) times per frame (`storage/CBDNKF.HTML`).

## Decided not to do

- Ship menu Force Quit: three Escs is enough.
- Replacing a large file by tether: put the old one in the Trash first;
  `tools/tether_put.py` says so (over 512 KB).
- Clock: the board has no battery clock, so the time is lost at every power
  off.
- Clipboard shared between programs, Scrapbook, Key Caps, desk accessories.

When starting a build: run `python3 -m tools.toolbox_linker` first so the
bit's built-in Toolbox matches the card, then follow `docs/FPGA_FIT.md`, then
`python3 tools/update_current_set.py --bit ...` (top-level README).
