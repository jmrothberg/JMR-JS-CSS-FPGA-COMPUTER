# JMR JS Computer

A computer whose processor runs JavaScript. Programs are HTML files on a
microSD card; the machine boots into a Macintosh-style Finder and runs them
natively on a Nexys Video FPGA board. The same programs run in a Python model
and in an RTL simulator on the PC.

Keyboard on USB **J15**. PS/2 mouse on **JA**, second mouse on **JC**, joystick on **JB**. [Wiring](docs/USB_KEYBOARD_PMOD_MICE.md).

## Common commands

Send one file to the card in the tethered board. The board must be on Finder, and the GUI must be closed (only one program can own the USB tether). An HTML file also sends its compiled program, icon, and pictures. A file already on the board that is over 512 KB has to be dragged to the Trash first; this bitstream times out while replacing it.

```sh
python3 tools/tether_put.py storage/HELP.MD
python3 tools/tether_put.py storage/PRINCEB.HTML
```

Make the disk image from `storage/`. This replaces `card.img`, including documents saved on the previous image, and updates `CURRENT_SET.json`.

```sh
python3 tools/make_sd_image.py create card.img
```

Make a microSD card. Find the device with `lsblk` first. This erases the card. It needs your password because it writes the raw device.

```sh
sudo python3 tools/make_sd_image.py burn /dev/sdX
```

`burn` rebuilds `card.img` from `storage/` and then writes it. Add `--keep-image` to write the `card.img` you already have and skip the rebuild.

Flash the bitstream. The current release is build 98 (`releases/current/jmr_js_mac.bit`, timing met, setup +0.007 ns, hold +0.025 ns). It has no built-in Toolbox, so use it with a card made from the current source. Build 97 is in git history at commit d6dbe8e. Add `-f` with JP4 on QSPI to keep it after power-off. How to build one: [docs/FPGA_FIT.md](docs/FPGA_FIT.md).

```sh
openFPGALoader -b nexysVideo releases/current/jmr_js_mac.bit
```

After source changes without a new card, run `python3 tools/update_current_set.py`. After qualifying a new bit, record it: `python3 tools/update_current_set.py --set-id runNN-current-source --bit <bit> --wns <ns> --whs <ns> --synthesis build/runNN --placement build/runNN_<placement>`.

## Run it on the PC

```sh
JMR_CARD_IMG=card.img .venv/bin/python gui_jmr_js.py
```

F9 cycles Python, FPGA-SIM and the board. F10 opens the Architecture Monitor.
FPGA-SIM needs `make -C sim sim_server_synth` once. [More](docs/GUI_RUNTIME.md).

## Writing a program

A program is one HTML file in `storage/` with a 640×480 canvas and inline
`<script>`. Start from an example:

| Copy | For |
|---|---|
| `storage/MENUEX.HTML` | The smallest windowed program with a menu |
| `storage/TBDEMO.HTML` | Toolbox Tour: every dialog, check marks, dimmed items, system-font text, patterns, CopyBits, ports, scrolling, mouse dragging and sound, in one window |
| `storage/GUIDEX.HTML` | A windowed tool with mouse dragging |
| `storage/UISESS.HTML` | Open and Save As with your own file format |
| `storage/BOXES.HTML`, `storage/INVF.HTML` | A game: full screen, art, sound, keys |

Check it, then put it on the board:

```sh
python3 tools/check_port.py storage/MYPROG.HTML
python3 tools/tether_put.py storage/MYPROG.HTML
```

`check_port.py` compiles the file and prints its sizes against the limits
below. The full guide is [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md); menus,
windows and files are in [docs/SYSTEM_APPLICATIONS.md](docs/SYSTEM_APPLICATIONS.md).

### Limits (build 98)

| Kind | Limit |
|---|---|
| **Program size** | |
| HTML source the on-machine Editor and Compile can hold | 65,536 bytes |
| Compiled code, constants and name tables together | 29,696 words (118,784 bytes) |
| Names and string literals | 1,024 entries, 32,768 bytes |
| Constants | 1,024 |
| Global variables | 1,024 |
| Classes; methods per class | 16; 16 |
| **Functions** | |
| Parameters of one function | 16 |
| Fast local slots per call (more locals still work, but slower) | 16 |
| Call depth | 128 |
| Value stack | 1,024 |
| **Memory while running** | |
| Live objects; properties per object | 960; 32 |
| Arrays of up to 32 elements | 1,536 |
| Arrays of 33 to 128 elements | 16 |
| Elements in one array | 128 |
| Live scopes (one per active call or closure) | 384 |
| Strings made while running | share the 1,024 name entries and are never freed |
| Scratch arena (`stgRead`/`stgWrite`, Toolbox descriptors) | 380,928 bytes |
| SOURCE document buffer | 65,536 bytes |
| **Events** | |
| Timers | 64 |
| Pending `requestAnimationFrame` callbacks | 8 |
| Listeners per event type | 4 |
| **Screen, art and text** | |
| Screen | 640×480, one 256-colour palette per program |
| Art sheets; art bytes | 16; 6,860,800 |
| `fillText` | 64 bytes per call, ASCII only |
| One canvas path | 16 commands |
| **Speed** | |
| VM | 33.333 MHz, about 555,000 clocks per 1/60 s frame, about 5 clocks per instruction (50 MHz measured not to close; [NEXT_BUILD.md](docs/NEXT_BUILD.md#not-in-build-98-and-why)) |

Reaching a run-time limit stops the program with a fault (the Finder shows
`ID = n`); nothing is cut short silently. Every limit, with the fault codes:
[docs/JMR_JS_COMPATIBILITY.md](docs/JMR_JS_COMPATIBILITY.md#limits).

### Common JavaScript that does not work here

Measured on build 97 on the FPGA simulator and the Python model.

| You write | What happens | Write instead |
|---|---|---|
| `x ** 2`, `<<`, `>>`, `>>>`, `^`, `~`, `??`, `...`, `[a, b] = …`, default parameters | Compile error | `x * x`, `Math.floor(x / 2)`, `x * 4`, `a !== undefined ? a : b` |
| `Math.sin` `cos` `atan2` `pow` `hypot` | Compile error | A sine table; `x * x`; `Math.sqrt(x * x + y * y)` |
| `.toFixed` `.toString` `.padStart` `.padEnd` `.repeat` `.concat` `.match` | Compile error | `String(n)`, a loop, pass numbers straight to `fillText` |
| Array `.reverse` `.shift` `.some` `.every` `.findIndex` | Compile error | A loop; `a.splice(0, 1)` |
| `delete o.k`, `arguments`, `instanceof`, `void 0` | No effect, `undefined`, or a compile error | `o.k = undefined`, named parameters |
| String `<` and `>` (`"apple" < "banana"`) | Always false | Compare bytes with `strByte` (`storage/GUIDEX.HTML`, `before()`) |
| `s.replace(/regex/, …)` | Wrong on the FPGA | `s.replace("text", …)` with a string pattern |
| String methods, `parseInt`, `parseFloat`, `Number(s)`, `Math.trunc`, `Math.sign`, `Number.isInteger` | Work on both machines; the compiler adds a JavaScript library (about 2,800 instructions) to programs that use them. Strings made while running are never freed: 1,024 strings / 32,768 bytes per program, shared with literals and names | Do not make new strings every frame |
| `try { } catch (e) { }`, `throw` | The `catch` body never runs; `throw` does nothing | Return a status value |
| `let` / `const` in a block | Function scope, like `var` | Use different names |
| `1 == "1"` | False: no type conversion | Convert yourself |
| `{ get x() {} }`, `{ f() {} }` in an object literal; `class B extends A`, `static` | Compile error | A `class` with `get`; plain functions |
| `fetch`, `Promise`, `async`/`await`, `Map`, `Set`, typed arrays, `eval` | Absent | Card files with `fsRead`/`fsWrite`; objects and arrays |
| Binding Esc | Esc belongs to the system | Any other key |

What does work, and what each construct compiles to:
[docs/JS_COMMANDS.md](docs/JS_COMMANDS.md).

## Folders

| Folder | What it is |
|---|---|
| `rtl/` | The hardware. The only RTL; simulator and FPGA both build it. |
| `constraints/` | Pins and clocks for the board. |
| `storage/` | Programs and files that go on the card. |
| `resources/` | Sources for the resident Toolbox, `SYSTEM.SYS`, MacPaint tables, and Finder's About picture. |
| `vectors/` | ROM images the RTL loads. Generated by `tools/`. |
| `functional_model/`, `hardware_model/` | The Python model of the machine and its compiler. |
| `runtime/` | How the GUI talks to Python, the simulator and the board. |
| `sim/` | Verilator simulator and testbenches. |
| `tools/` | Card builder, compiler, generators, Vivado build. |
| `tests/` | `pytest` suite. |
| `docs/` | How to write programs and how the machine works. Start at [docs/README.md](docs/README.md). |
| `archive/` | Retired code kept for reference: the second version of each game, the tether pixel dump, old tests. |
| `build/` | Generated output, including the rollback bitstream. |
| `releases/` | Published builds. |
| `traces/` | GUI session logs. |
| `to_be_deleted/` | Retired files awaiting deletion. |

Specification: [CONSTITUTION.md](CONSTITUTION.md).
