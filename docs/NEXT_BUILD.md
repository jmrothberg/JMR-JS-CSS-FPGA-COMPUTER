# Build 97 and after: items that need a new .bit

Everything in the tables changes `rtl/` or what is synthesized into the
bitstream. Fixes that only change the card (Toolbox, Finder, programs) go out
with a new `card.img` and do not wait for this list.

## Build 97 (at commit d6dbe8e, from `build/run97b`)

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

## Build 99: fewer clocks per instruction

Built as `build/run99b` (sources `build/run99b_src`), placement `build/run99b/p_ExtraTimingOpt`, bit `build/run99b_release/jmr_js_mac_b99.bit`. Timing met at the unchanged 33.333 MHz VM clock: setup +0.089 ns, hold +0.041 ns, 0 routing errors, DRC 0 errors, timing exceptions identical to build 98 (no waivers). 98,403 LUTs, 354 of 365 BRAM tiles, 30,625 slices. FPGA-SIM `user_loop`, `alert_check` and `esc_check` pass on the same RTL; the `tests/test_rtl_snippets.py` failures are the same set as build 98's. Installed as `releases/current/jmr_js_mac.bit` on 2026-11-13; on the board, on-machine Compile of COMPTEST gave 12 of 12. The Explore placement of the same netlist was stopped when this one closed.

### Where the clocks went (measured on FPGA-SIM before the change)

`sim/cpi_profile.py` boots the card to Finder and profiles 40 frames each of
Finder idle, Finder with the mouse moving, Space Invaders (`INVF`), Donkey Kong
(`CBDNKF`) and MacPaint drawing with the mouse held down. The simulator counts
every busy VM clock (frame waits excluded) against the op word exec holds, and
one instruction per change of `ip` (`OPPROFCLR` / `OPPROF?` in
`sim/sim_main.cpp`). Build 98 RTL:

| Program | Instructions | Busy VM clocks | Clocks per instruction |
|---|---|---|---|
| Finder idle | 11,880 | 269,010 | 22.6 (68% is the per-frame garbage collection at the end of each rAF) |
| Finder, mouse moving | 26,000 | 370,480 | 14.3 |
| Space Invaders | 1,155,388 | 11,370,729 | 9.84 |
| Donkey Kong | 130,646 | 1,472,173 | 11.3 |
| MacPaint drawing | 209,842 | 1,951,018 | 9.30 |

Most executed instructions and their cost (Space Invaders; the other programs
have the same order):

| Op | Share of instructions | Clocks each | Share of clocks |
|---|---|---|---|
| `LOAD_VAR` | 32% | 6.0 (4 for a global; a local walked the current scope) | 20% |
| `LOAD_CONST` | 12% | 4 | 5% |
| `LET_VAR` | 8% | 15.6 (heap walk, append on a function's first pass) | 13% |
| `GET_PROP` | 7% | 10 (heap walk of the object's slots) | 7% |
| `JIF` | 6% | 4 | 3% |
| `POP` | 4% | 4 | 2% |
| `STORE_VAR` | 4% | 7.7 | 3% |
| `ADD` | 4% | 9 (float adder) | 3.5% |
| `CALL_METH` (fillRect/drawImage) | 1.3% | 210 (waits for the raster engine) | 27% |

Every instruction paid at least 4 VM clocks: exec beat 1 (clock the operand
read addresses), beat 2 (memory output settles), beat 3 (execute) and a leave
beat in which the parent's `S_FETCH_WAIT` arm runs and the next word is read.

### What changed (`rtl/engines/jmr_js_vm_exec64.sv`, `rtl/engines/jmr_js_vm.sv`)

| Change | Clocks |
|---|---|
| Beat 2 is skipped for ops whose execute arm reads no memory (only the stack window and the op word): `ADD SUB MUL DIV MOD LT GT EQ NEG NOT BIT_OR BIT_AND POP DUP JUMP JIF`, and a global `STORE_VAR` (`beat2_free`). | 4 → 3 |
| On exec's own fetch beat (`e64_fw_beat`: exec state `S_FETCH_WAIT`, word on `code_rdata`) the parent addresses the constant table and the global table straight from the word, so `LOAD_CONST` and a global `LOAD_VAR` have their operand one beat sooner. exec's registered read addresses follow one beat later and address the same entries, so every other reader sees what it saw before. | 4 → 3 |
| Local variables: on the same fetch beat the parent reads the current scope's hinted slot (`LOAD_VAR`/`STORE_VAR` a1 = slot + 2, local `LET_VAR` a1[7:1] = slot + 1). If that slot is inside the scope and holds the name, exec pushes it (`LOAD_VAR`) or writes it (`STORE_VAR`, `LET_VAR`, one `venv` write port shared with `S_HEAP_WR`) itself. This is exactly the hit the parent's verified first guess (heap phase 5/6) finds; any miss, a pending constructor jump, or an entry after a parent flow takes the old walk. | local read, store or let hit: a heap walk → 3 (Space Invaders `LOAD_VAR` 6.0 → 3.0, `STORE_VAR` 7.7 → 3.0) |
| Float add/subtract with equal signs skips the normalize beat (it was a no-op). | 9 → 7 |

Not done (measured, larger): a `LET_VAR` that appends a new name to a scope
(a function's first pass over its locals) still walks the scope, because a
name can already sit at a lower slot after inlining; object property reads
still walk the object's slots (2 beats a slot); drawing still waits for the
raster engine; calls and returns cost 20–60 clocks.

### After (same FPGA-SIM runs, same instruction counts)

| Program | Busy VM clocks before → after | Clocks per instruction | Speed-up |
|---|---|---|---|
| Finder idle | 269,010 → 254,564 | 22.6 → 21.4 | 1.06× |
| Finder, mouse moving | 370,480 → 334,930 | 14.3 → 12.9 | 1.11× |
| Space Invaders | 11,370,729 → 9,479,766 | 9.84 → 8.20 | 1.20× |
| Donkey Kong | 1,472,173 → 1,285,460 | 11.3 → 9.84 | 1.15× |
| MacPaint drawing | 1,951,018 → 1,633,774 | 9.30 → 7.79 | 1.19× |
| Compute loop (objects, array sieve, recursion, arithmetic; no drawing) | 788,772 → 569,657 | 6.55 → 4.73 | 1.38× |

The remaining time in the games is mostly not instructions: fillRect/drawImage
waiting for the raster engine (27% of Space Invaders), the `toolbox` native's
bulk copies (MacPaint, Donkey Kong) and the garbage collection at each frame end.

### Fixed with build 99 (were RTL-vs-model differences)

| Item | Change |
|---|---|
| `Math.sqrt` | `S_SQRT` computes the IEEE double root, correctly rounded (54-step restoring root on the 53-bit significand, subnormals normalized first), as the Python model does. It was a Q16.16 root (~20 bits, wrong above 32767). |
| `b=[]; b[50]=9` gave length 0 | An `ARRAY_SET` past 32 elements promotes the array (`S_ARR_PROMOTE`). That state is not a handshake state, so `vsp` there was the parent's stale copy; the stack window moved down and back, and the re-decoded `ARRAY_SET` saw a wrong receiver and dropped the store. The promote now holds exec's stack head (`hs_vsp(e64_vsp_q)`). |

Test: `tests/test_build99_vm.py` (Python model and FPGA-SIM give the same
globals for the shortened ops, local variables, closures, recursion, `sqrt`
and array growth).

## Build 98 (at commit cdb489d, from `build/run98`, placement `build/run98/p_Explore`)

On-machine Compile failed on the first build-98 card ("It did not compile"). The bit was fine: `storage/COMPILE.LNK` still held build 97's stage checksums after `COMPILER.HTML` changed, and COMPILER refuses mismatched stages (`STAGE2`). Fixed by `python3 tools/selfhost.py --write`; `tests/test_self_hosted_compile.py` now fails whenever `COMPILE.LNK` does not match the stage files a card carries. Re-run `selfhost.py --write` after any change to `COMPILER.HTML` or `COMPIL2.HTML`.

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
| Fewer clocks per instruction | Measured only. On FPGA-SIM a loop iteration of about 14 instructions costs 207 core clocks (property read), 225 (array read), 288 (call), 306 (float multiply): about 5 VM clocks per instruction. Done in build 99. |

## Found while building 98

- `b=[]; b[50]=9` leaves `b.length` 0 on FPGA-SIM; the Python model gives 51. Fixed in the build-99 RTL.
- `Math.sqrt(2)` on FPGA-SIM is `0x3ff6a09000000000` (about 20 bits); the Python model is exact. Fixed in the build-99 RTL.
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
