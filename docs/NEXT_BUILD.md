# Build 97 and after: items that need a new .bit

Everything in the tables changes `rtl/` or what is synthesized into the
bitstream. Fixes that only change the card (Toolbox, Finder, programs) go out
with a new `card.img` and do not wait for this list.

## Build 97 (`releases/current/jmr_js_mac.bit`, from `build/run97b`)

| Item | Change |
|---|---|
| Name table 32 KB | `NAME_CAP` 16384 → 32768 in `jmr_js_vm.sv`, `jmr_js_vm_pkg.sv` and `functional_model/jsb_format.py` (`PROGRAM_NAME_BYTES`). Address widths were already 15–16 bits. About 4 more BRAM tiles. Sized from measurement: Prince today uses 15,038 name bytes; the original Apple II tables packed from `SEQTABLE.S` (2,546 bytes) and `FRAMEDEF.S` (2,001 bytes) bring it to 19,585, about 21,100 as base64. 49,152 is not needed. |
| `Array(n)` fill fix | An `Array(n)` longer than 32 elements wrote its first element before the VM had read that the array was long, so the write landed in element 32 of another long array, and the new array's element 0 read as 0 instead of undefined (MacPaint's About showed "pict?re"). `S_HEAP_FILL` in `jmr_js_vm.sv` now waits a settle beat before every write. Test: `tests/test_array_fill_long.py`. |
| Built-in Toolbox matches the card | The bit's fallback bank is rebuilt from `vectors/toolbox_code*.hex` (menu flash, optimized Toolbox). |

The Toolbox is now compiled with the same optimizer as applications
(`tools/toolbox_linker.py`): 7,557 words (with the menu blink) instead of 8,189, so about 630 words
are free in the existing 8,191-word bank. Doubling the bank is no longer
needed for the items it was waiting on.

## Found after build 97: string methods on the FPGA (fixed on the card)

Measured 2026-11-12 on FPGA-SIM: the RTL got `s.indexOf(t)` / `s.includes(t)`
wrong unless `t` was at index 0, `s.slice`, `s.substr`, `s.trim` and
`s.replace` gave unusable strings, `a.join(sep)` left the separator out, and
`parseInt`, `parseFloat`, `Number(s)`, `Math.trunc`, `Math.sign`,
`Number.isInteger`, `s.lastIndexOf` were `undefined`; `0x1F` compiled as 0 and
`do … while` never ended.

Fixed without a new bitstream: both compilers now add the JavaScript string
library `functional_model/strops_runtime.js` (`STROPS.JS` on the card) to
programs that use these, and compile hex/binary literals and `do … while`
(`tests/test_string_library.py`, Python model and FPGA-SIM agree;
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md#strings-on-the-fpga)).
`s.replace(/regex/, …)` is still wrong on the FPGA, and `s < t` between
strings is still always false on both machines.

What stays for the hardware:

| Item | Why |
|---|---|
| A string area that can be freed | Strings made while running are interned in the program's name table and never freed: 1,024 entries / 32,768 bytes, shared with literals and names. A program that makes new text every frame fills it (fault 3). |
| Speed | Each library call is a function call plus a byte loop (`strByte`, `toolbox` word writes, `stringFromBytes`). RTL arms for `indexOf`, `slice` and `join` on strings would be much faster. |
| Code size | The library is about 2,800 instructions in every program that uses it (`INVF.HTML` 20,142 → 22,929, `CBPACFAST.HTML` 17,873 → 20,660). |

## Build 98 plan

| Item | Change |
|---|---|
| No Toolbox copy in the bit | The Toolbox bank is filled from the card's `TOOLBOX.ROM` at every start; the bit also pre-fills it from `rtl/engines/jmr_toolbox_rom_pkg.sv`, a second copy that drifts (build 97's has the old menu blink). Start the bank empty, and have the boot report a missing or bad `TOOLBOX.ROM` instead of running an old copy. Removes the relink-before-synthesis step. |
| External memory address 22 → 25 bits | `jmr_sram_port` reaches 2M × 16 (4 MB) of DDR3 today. Widen it so nothing assumes 4 MB; the custom board's 512 Mb (64 MB) HyperRAM then needs only a `jmr_hyperram_sram_bridge` with the same port in place of `jmr_ddr3_sram_bridge.sv`. The custom board has the same XC7A200T as the Nexys Video, so timing results carry over; it adds 64 MB HyperRAM, and its keyboard and mouse share one USB port through a combined receiver, the same circuit as the Macintosh board. Build 98 changes nothing for that input; it stays behind the existing key and mouse event ports, and the board port adds only its front end. |
| Timing margin first | Aim for +0.1 ns before adding logic (see below). |
| `CODE_WORDS` 21504 → 29696 | Finder has 32 bytes of code left, COMPIL2 6 %, MacPaint is at 512 globals. |
| A string area that can be freed | See above; then RTL `indexOf`/`slice`/`join`. |
| Storage first-write retry | If the MacPaint first-save failure is confirmed on the board (below). |
| Fewer clocks per instruction | Measure first, then shorten the common instructions. |

## To measure on the board

| Symptom | Likely cause | How to check |
|---|---|---|
| The first save in MacPaint failed on the board; the next Save As and Save worked (2026-11-12). FPGA-SIM saves every time. | `rtl/engines/storage_engine.sv`: an SD command with no answer in about 1.3 s, or any storage error, goes to `S_ERR`, which marks the card unmounted; the next file operation remounts it and succeeds. So the first write after a long idle may return −1. MacPaint now reports a failed save with an alert instead of drawing over the picture. | Save right after opening MacPaint, several times, after the board has idled for a few minutes. If the first `fsWrite` fails, retry once inside the storage engine after a remount instead of reporting the error. |

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
