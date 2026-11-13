# What the next .bit needs

Only changes to `rtl/`, or to what is synthesized into the bitstream, wait
for a new bit. Fixes to the Toolbox, Finder or programs go out on a new
`card.img`. The bit holds no Toolbox (it loads `TOOLBOX.ROM` from the card),
so a Toolbox change never needs a build.

How to build and qualify a bit: [FPGA_FIT.md](FPGA_FIT.md). After
qualifying, record it with `tools/update_current_set.py --set-id runNN-current-source --bit …`
and make a new card ([README](../README.md#commands)).

## Current: build 99

`releases/current/jmr_js_mac.bit`, from `build/run99b`, placement
`p_ExtraTimingOpt`. Setup +0.089 ns, hold +0.041 ns at 33.333 MHz, no timing
waivers. 98,403 LUTs, 354 of 365 BRAM tiles, 30,625 slices. On the board,
on-machine Compile of COMPTEST gave 12 of 12.

## Open items

| Item | Why | Notes |
|---|---|---|
| A string area that can be freed | Strings made while running go into the name table and are never freed: 1,024 entries / 32,768 bytes, shared with literals and names. A program that makes new text every frame fills it (fault 3). | Not started. |
| String operations in RTL | The string library (`functional_model/strops_runtime.js`, `STROPS.JS`) makes string methods correct on the FPGA, but each call is a function call plus a byte loop, and it adds about 2,800 instructions to a program. RTL arms for `indexOf`, `slice` and `join` would be much faster. | |
| `s.replace(/regex/, …)` | Wrong on the FPGA, right on the Python model. | String patterns work. |
| Fewer clocks per instruction | Build 99 made most instructions 3 clocks. What is left: a `LET_VAR` that appends a new local (a function's first pass) still walks the scope; object property reads walk the object's slots (2 beats a slot); calls and returns cost 20–60 clocks; drawing waits for the raster engine (27% of Space Invaders). | [Measurements](#clocks-per-instruction) |
| Faster VM clock | The only faster synchronous setting is 50 MHz (100 MHz divided by 2). Build 97's netlist placed at 20 ns: WNS −8.1 ns, about 27,000 failing VM endpoints, 17–50 logic levels (code BRAM into the decoder, `state` into the stack window, `vsp` into heap write data). Pipelining multiply/float alone does not help; decode and the stack window must be split across cycles throughout the VM. 45 and 40 MHz need an asynchronous clock and new crossings. | The largest item. Needs timing margin first. |
| Timing margin | +0.089 ns is thin. The worst paths are a flat spread of about twenty within 0.1 ns ([FPGA_FIT.md](FPGA_FIT.md#known-gaps-in-the-current-source)). Aim for +0.1 ns or more. | |
| `SOURCE_MAX` 65,536 → 131,072 | The SOURCE buffer sits in the 8 MiB external window between the compiler arena and the staging region ([memory map](ARCHITECTURE.md#memory)). Doubling it takes 131,072 bytes from art (`CART_MAX_BYTES`) or moves the staging region. PRINCEB's HTML is about 44 KB. | Do it when a program needs it. |
| Hardware math (`sin`, `cos`, …) | Only if there is room and it is easy. | |

## To check on the board

| Symptom | Status |
|---|---|
| The first save in MacPaint after the board idled failed once (2026-11-12, build 97); the next save worked. FPGA-SIM saves every time. | Build 98 added a retry: an OPEN, DELETE or DIR whose SD command times out (~1.3 s) remounts the card and runs once more before reporting an error. Check on build 99: save right after opening MacPaint, after a few minutes idle. |

## Known test failures

- `tests/test_finder_program.py`: three tests fail with or without the
  build 98 changes (Toolbox identity mismatch in the fixtures, and the Trash
  test).
- `tests/test_rtl_snippets.py`: the same set fails on build 98 and build 99.

<a id="build-99-fewer-clocks-per-instruction"></a>

## Clocks per instruction

`sim/cpi_profile.py` boots the card to Finder on FPGA-SIM and profiles 40
frames of each workload. Busy VM clocks exclude frame waits.

| Program | Clocks per instruction, build 98 → 99 | Speed-up |
|---|---|---|
| Finder idle (68% is the garbage collection at each frame end) | 22.6 → 21.4 | 1.06× |
| Finder, mouse moving | 14.3 → 12.9 | 1.11× |
| Space Invaders (`INVF`) | 9.84 → 8.20 | 1.20× |
| Donkey Kong (`CBDNKF`) | 11.3 → 9.84 | 1.15× |
| MacPaint drawing | 9.30 → 7.79 | 1.19× |
| Compute loop (objects, array sieve, recursion, arithmetic; no drawing) | 6.55 → 4.73 | 1.38× |

Most executed instructions in Space Invaders, build 98 → 99:

| Op | Share of instructions | Clocks each |
|---|---|---|
| `LOAD_VAR` | 32% | 6.0 → 3.0 |
| `LOAD_CONST` | 12% | 4 → 3 |
| `LET_VAR` | 8% | 15.6 (scope walk; unchanged when it appends) |
| `GET_PROP` | 7% | 10 (walk of the object's slots; unchanged) |
| `JIF` | 6% | 4 → 3 |
| `POP` | 4% | 4 → 3 |
| `ADD` | 4% | 9 → 7 (float add with equal signs skips the normalize beat) |
| `STORE_VAR` | 4% | 7.7 → 3.0 |
| `CALL_METH` (fillRect, drawImage) | 1.3% | about 210, waiting for the raster engine: 27% of clocks |

## History

Each published bit is in git history at its commit.

### Build 99 (commit 09088a7)

| Change | Where |
|---|---|
| Ops whose execute arm reads no memory (`ADD SUB MUL DIV MOD LT GT EQ NEG NOT BIT_OR BIT_AND POP DUP JUMP JIF`, global `STORE_VAR`) skip the memory-settle beat: 4 → 3 clocks. | `jmr_js_vm_exec64.sv` (`beat2_free`) |
| `LOAD_CONST` and global `LOAD_VAR` get their operand on exec's fetch beat: 4 → 3 clocks. | `jmr_js_vm.sv` (`e64_fw_beat`) |
| Local `LOAD_VAR`, `STORE_VAR` and `LET_VAR` read or write the scope's hinted slot directly when it holds the name: a scope walk → 3 clocks. A miss takes the old walk. | `jmr_js_vm.sv`, `jmr_js_vm_exec64.sv` |
| Float add and subtract with equal signs skip the normalize beat: 9 → 7 clocks. | `jmr_js_vm_exec64.sv` |
| `Math.sqrt` is the correctly rounded IEEE double root, as in the Python model (it was a Q16.16 root, about 20 bits, wrong above 32767). | `S_SQRT` |
| `b=[]; b[50]=9` no longer loses the store (length was 0). The array promote now uses exec's stack head. | `S_ARR_PROMOTE` |

Test: `tests/test_build99_vm.py` (Python model and FPGA-SIM agree).

### Build 98 (commit cdb489d)

| Change | Where |
|---|---|
| Program code 21,504 → 29,696 words (+8 BRAM tiles). Code addresses are 16 bits because the Toolbox bank plus program is 37,888 words. The Python limit (`PROGRAM_CODE_WORDS`) and on-machine Compile follow. | `CODE_WORDS` in `jmr_js_vm.sv`, `jmr_js_vm_pkg.sv` |
| External memory port 22 → 25-bit word address (64 MiB). The DDR3 bridge maps the first 64 MiB; the memory map still uses the first 8 MiB. A HyperRAM board needs only a bridge with the same port. | `jmr_sram_port` clients, `jmr_ddr3_sram_bridge`, `jmr_sram_model` |
| No Toolbox in the bit. The bank starts empty and is filled from the card's `TOOLBOX.ROM` at every cold start; a missing or bad ROM shows `?TB`. No relink step before synthesis. | `jmr_toolbox_rom_pkg.sv` holds only the final jump word |
| Storage retries a timed-out OPEN, DELETE or DIR once after a remount. | `storage_engine.sv` |
| A growing array with all 16 long rows taken collects garbage once before fault 3. | `S_ARR_PROMOTE`; `tests/test_long_array_gc.py` |

The first build-98 card failed on-machine Compile because `storage/COMPILE.LNK`
still held the old stage checksums. Run `python3 tools/selfhost.py --write`
after any change to `COMPILER.HTML` or `COMPIL2.HTML`;
`tests/test_self_hosted_compile.py` catches a mismatch.

### Build 97 (commit d6dbe8e)

| Change | Where |
|---|---|
| Name table 16 → 32 KB (`NAME_CAP` 32768; `PROGRAM_NAME_BYTES` in Python). | `jmr_js_vm.sv`, `jmr_js_vm_pkg.sv`, `functional_model/jsb_format.py` |
| `Array(n)` longer than 32 no longer writes into another long array. | `S_HEAP_FILL`; `tests/test_array_fill_long.py` |

After build 97, string methods were fixed on the card, not in RTL: both
compilers add the string library to programs that use them
([Strings on the FPGA](JMR_JS_COMPATIBILITY.md#strings-on-the-fpga)).

## Decided not to do

- Ship menu Force Quit: three Escs is enough.
- Replacing a large file by tether: put the old one in the Trash first;
  `tools/tether_put.py` says so (over 512 KB).
- A clock: the board has no battery clock, so the time is lost at every power
  off.
- Clipboard shared between programs, Scrapbook, Key Caps, desk accessories.
