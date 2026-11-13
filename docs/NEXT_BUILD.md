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

## Build 98 (`releases/current/jmr_js_mac.bit`, from `build/run98`, placement `build/run98/p_Explore`)

Timing met at the unchanged 33.333 MHz VM clock: setup +0.007 ns, hold +0.025 ns,
DRC 0 errors, no timing exceptions added. 98,992 LUTs, 353.5 of 365 BRAM tiles,
30,348 slices. FPGA-SIM `user_loop`, `alert_check` and `esc_check` pass on the
same RTL.

| Item | Change |
|---|---|
| `CODE_WORDS` 21504 → 29696 | `code_mem` is 16K+8K+4K+1K words (+8 BRAM tiles). Code addresses are 16 bits throughout `jmr_js_vm.sv`, `jmr_js_vm_exec64.sv` and the console loader, because the Toolbox prefix plus the bank is 37,888 words. Python limits (`jsb_format.PROGRAM_CODE_WORDS`), the simulator's code pokes and the on-machine Compile limit (`COMPILER.HTML`) follow. |
| External memory address 22 → 25 bits | `jmr_sram_port` (core arbiter, every client port, `jmr_ddr3_sram_bridge`, `jmr_sram_model`) carries a 25-bit word address: 32M × 16 = 64 MiB. The bridge maps the first 64 MiB of DDR3; the simulator model is 64 MiB. The memory map still uses the first 8 MiB. A HyperRAM board needs only a bridge with the same port. |
| No Toolbox copy in the bit | The Toolbox bank starts empty and is filled from the card's `TOOLBOX.ROM` at every cold start. A program that links the Toolbox starts only after a whole ROM is loaded (`toolbox_loaded`). A missing or bad ROM stops Finder with `?TB` on the recovery display. `jmr_toolbox_rom_pkg.sv` holds only the fixed padding word; the linker no longer writes RTL, and there is no relink step before synthesis. |
| Storage first-write retry | `storage_engine.sv`: an OPEN, DELETE or DIR whose SD command times out (~1.3 s) or returns an SPI error before the operation has written a sector remounts the card and runs once more from its start. Only a second failure reaches the program. |
| Long-array pool GC | A push or `a[i]=` that grows an array past 32 elements with all 16 long rows taken now collects garbage once and re-runs the instruction before fault 3, as a new long array already did (`S_ARR_PROMOTE`; Python model `_value64_ensure_long`). Test: `tests/test_long_array_gc.py` (model and FPGA-SIM). |

### Not in build 98, and why

| Item | Why |
|---|---|
| Faster VM clock | Measured, not built. The VM clock is the 100 MHz fabric clock through a BUFGCE divider, so the only faster setting that keeps the VM synchronous with the fabric is 50 MHz (divide by 2). 45 and 40 MHz are not reachable without an asynchronous clock and new crossings everywhere the VM meets the fabric. Build 97's netlist placed with a 20 ns VM clock: WNS −8.1 ns, 26,988 failing endpoints, 20,807 worse than 1 ns, 7,349 worse than 3 ns. The multiply/float path is only the tail; the bulk is the whole VM: instruction word from the code/Toolbox BRAM into the decoder (listeners, sprite and class registers), `state` into the stack window `vst_win`, `vsp` into heap write values, 17–50 logic levels. Pipelining multiply/float alone would not move WNS. 50 MHz needs the decode and stack-window paths split across cycles throughout the VM. |
| A string area that can be freed | Not started (time). |
| Fewer clocks per instruction | Measured only. On FPGA-SIM a loop iteration of about 14 instructions costs 207 core clocks (property read), 225 (array read), 288 (call), 306 (float multiply): about 5 VM clocks per instruction. |

## Found while building 98 (not changed)

- `b=[]; b[50]=9` leaves `b.length` 0 on FPGA-SIM; the Python model gives 51.
- `Math.sqrt(2)` on FPGA-SIM is `0x3ff6a09000000000` (about 20 bits); the Python model is exact.
- `tests/test_finder_program.py`: three tests fail with or without the build-98 changes (Toolbox identity mismatch in the fixtures, and the Trash test).

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

When starting a build: follow `docs/FPGA_FIT.md`, then
`python3 tools/update_current_set.py --bit ...` (top-level README). The bit
holds no Toolbox, so a Toolbox change never needs a build.
