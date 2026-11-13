# JMR JS Computer

A computer whose processor runs JavaScript. There is no CPU underneath: the
compiled JavaScript is the instruction set. Programs are HTML files on a
microSD card. The machine boots into a Macintosh-style Finder and runs them
on a Digilent Nexys Video FPGA board. The same programs run on the PC in a
Python model and in an RTL simulator (FPGA-SIM).

The current release is **build 99**. Since build 98 a program has
**29,696 words for its code**, up from 21,504 (38% more), and since build 97
it has **32 KB for names and strings**, up from 16 KB. The Toolbox has its
own bank and does not use that room. Build 99 also runs most instructions in
3 clocks instead of 4.

## Get started

### What you need

| Item | Notes |
|---|---|
| Digilent Nexys Video (XC7A200T) | |
| microSD card | Erased when you burn it |
| HDMI monitor | 640×480 |
| USB keyboard | Jack **J15** |
| PS/2 mouse on a Pmod adapter | Jack **JA**. A second mouse on **JC**, a joystick on **JB**, both optional. [Wiring](docs/USB_KEYBOARD_PMOD_MICE.md) |
| Linux PC | Python 3 with `.venv` (`pip install -r requirements.txt`), `openFPGALoader`. Vivado only to build a new bitstream. |

### 1. Make a card

Run every command from this repository's folder. A terminal left in another
project (such as `~/JMR-BASIC-FPGA-COMPUTER`) has a different
`tools/make_sd_image.py` and would write the wrong card.

```sh
cd ~/JMR-JS-CSS-FPGA-COMPUTER
lsblk                                            # find the card, e.g. /dev/sdb
sudo python3 tools/make_sd_image.py burn /dev/sdX
```

`burn` builds `card.img` from `storage/` and writes it to the card. It
erases the card. Add `--keep-image` to write the `card.img` you already have.

### 2. Load the bitstream

Plug in the keyboard, mouse and monitor, put the card in, and turn the board
on. Then, from the same folder:

```sh
openFPGALoader -b nexysVideo releases/current/jmr_js_mac.bit
```

Add `-f` (with jumper JP4 on QSPI) to keep it after power-off. The bit has
no Toolbox in it: it loads `TOOLBOX.ROM` from the card, so use a card made
from the current source. Other loading options: [FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md#loading-a-bitstream).

### 3. Boot and check

The machine shows a startup picture, then Finder. In the ship menu at the
left of the menu bar, Finder's About shows the build the card was made for
("Build 99" and the date). If it names a different build than the bit you
loaded, make a new card.

### 4. Run a program

Double-click a program to run it, a document to read it. Esc returns to
Finder. Special → Help opens the on-card manual (`storage/HELP.MD`).

## Commands

Run from the repository folder.

| To | Command |
|---|---|
| Build `card.img` from `storage/` | `python3 tools/make_sd_image.py create card.img` |
| Write a microSD card | `sudo python3 tools/make_sd_image.py burn /dev/sdX` (`--keep-image` to skip the rebuild) |
| Load the bitstream | `openFPGALoader -b nexysVideo releases/current/jmr_js_mac.bit` |
| Send one file to the card in the board | `python3 tools/tether_put.py storage/NAME.HTML` |
| Check a program's size against the limits | `python3 tools/check_port.py storage/NAME.HTML` |
| Run the GUI (Python, FPGA-SIM or board) | `JMR_CARD_IMG=card.img .venv/bin/python gui_jmr_js.py` |
| Relink the Toolbox | `python3 -m tools.toolbox_linker` |
| Re-mint the on-machine compiler after editing `COMPILER.HTML` or `COMPIL2.HTML` | `python3 tools/selfhost.py --write` |
| Check that source, storage and card match | `python3 tools/verify_current_set.py` |
| Record source changes without a new card | `python3 tools/update_current_set.py` |
| Record a new qualified bit | `python3 tools/update_current_set.py --set-id runNN-current-source --bit <bit> --wns <ns> --whs <ns> --synthesis build/runNN --placement build/runNN_<placement>`, then make a new card |
| Run the tests | `.venv/bin/python -m pytest` |

Notes:

- `create` and `burn` replace `card.img`, including documents saved on it.
  `create` refuses to build a card if `CURRENT_SET.json`'s `set_id` has no
  `runNN` (the build number About shows).
- `tether_put.py` needs Finder in front on the board and the GUI closed
  (only one program can own the USB tether). An HTML file also sends its
  compiled program, icon and art. A file over 512 KB that is already on the
  board must go to the Trash first; the tool says so.
- In the GUI, F9 cycles Python, FPGA-SIM and the board; F10 opens the
  Architecture Monitor. FPGA-SIM needs `make -C sim sim_server_synth` once.
  [GUI_RUNTIME.md](docs/GUI_RUNTIME.md).

## Write a program

A program is one HTML file in `storage/` with a 640×480 canvas and inline
`<script>`. Start from an example:

| Copy | For |
|---|---|
| `storage/MENUEX.HTML` | The smallest windowed program with a menu |
| `storage/TBDEMO.HTML` | Toolbox Tour: every dialog, menus, text, patterns, CopyBits, scrolling, dragging and sound |
| `storage/GUIDEX.HTML` | A windowed tool with mouse dragging |
| `storage/UISESS.HTML` | Open and Save As with your own file format |
| `storage/BOXES.HTML`, `storage/INVF.HTML` | A game: full screen, art, sound, keys |

Check it, then send it to the board:

```sh
python3 tools/check_port.py storage/MYPROG.HTML
python3 tools/tether_put.py storage/MYPROG.HTML
```

The machine can also edit and compile a program itself (Special → Editor,
Special → Compile). The full guide is [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).

### Limits (build 99)

The main limits. Every limit, with the fault codes, is in
[JMR_JS_COMPATIBILITY.md](docs/JMR_JS_COMPATIBILITY.md#limits).
`check_port.py` prints a program's use of each compile-time limit.

| Kind | Limit |
|---|---|
| Program code: instructions, constants and the name table together | 29,696 words (118,784 bytes); the Toolbox is in its own 8,192-word bank |
| Names and string literals | 1,024 entries, 32,768 bytes |
| Global variables | 512 slots, including the Toolbox's (about 200) in a linked program |
| HTML source the on-machine Editor and Compile can hold | 65,536 bytes |
| Live objects; properties per object | 960; 32 |
| Arrays: up to 32 elements; 33 to 128 elements | 1,536; 16 |
| Strings made while running | Share the 1,024 name entries and are never freed |
| Fast locals per call | 16 (more still work, but slower) |
| Art | 16 sheets, 6,860,800 bytes |
| Speed | 33.333 MHz, about 555,000 clocks per 1/60 s frame. Most instructions take 3 clocks. |

A run-time limit stops the program with a fault (Finder shows `ID = n`);
nothing is cut short silently.

### Common JavaScript that does not work here

| You write | What happens | Write instead |
|---|---|---|
| `x ** 2`, `<<`, `>>`, `>>>`, `^`, `~`, `??`, `...`, `[a, b] = …`, default parameters | Compile error | `x * x`, `Math.floor(x / 2)`, `x * 4`, `a !== undefined ? a : b` |
| `Math.sin` `cos` `atan2` `pow` `hypot` | Compile error | A sine table; `x * x`; `Math.sqrt(x * x + y * y)` |
| `.toFixed` `.toString` `.padStart` `.padEnd` `.repeat` `.concat` `.match` | Compile error | `String(n)`, a loop, pass numbers straight to `fillText` |
| Array `.reverse` `.shift` `.some` `.every` `.findIndex` | Compile error | A loop; `a.splice(0, 1)` |
| `delete o.k`, `arguments`, `instanceof`, `void 0` | No effect, `undefined`, or a compile error | `o.k = undefined`, named parameters |
| String `<` and `>` (`"apple" < "banana"`) | Always false | Compare bytes with `strByte` (`storage/GUIDEX.HTML`, `before()`) |
| `s.replace(/regex/, …)` | Wrong on the FPGA | `s.replace("text", …)` with a string pattern |
| `try { } catch (e) { }`, `throw` | The `catch` body never runs; `throw` does nothing | Return a status value |
| `let` / `const` in a block | Function scope, like `var` | Use different names |
| `1 == "1"` | False: no type conversion | Convert yourself |
| `{ get x() {} }`, `{ f() {} }` in an object literal; `class B extends A`, `static` | Compile error | A `class` with `get`; plain functions |
| `fetch`, `Promise`, `async`/`await`, `Map`, `Set`, typed arrays, `eval` | Absent | Card files with `fsRead`/`fsWrite`; objects and arrays |
| Binding Esc | Esc belongs to the system | Any other key |

String methods, `parseInt`, `parseFloat` and `Number(s)` work: the compiler
adds a JavaScript library (about 2,800 instructions) to programs that use
them. What does work, and what each construct compiles to:
[docs/JS_COMMANDS.md](docs/JS_COMMANDS.md).

## Read next

| To | Read |
|---|---|
| Find any guide | [docs/README.md](docs/README.md) |
| Write a program or game | [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) |
| Use menus, windows, dialogs and files | [docs/SYSTEM_APPLICATIONS.md](docs/SYSTEM_APPLICATIONS.md) |
| Understand the machine | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Build a bitstream | [docs/FPGA_FIT.md](docs/FPGA_FIT.md) |
| See what the next bitstream needs | [docs/NEXT_BUILD.md](docs/NEXT_BUILD.md) |
| The specification | [CONSTITUTION.md](CONSTITUTION.md) |

## Folders

| Folder | What it is |
|---|---|
| `storage/` | Programs and files that go on the card ([storage/README.md](storage/README.md)) |
| `rtl/` | The hardware. The simulator and the board build the same RTL. |
| `constraints/` | Pins and clocks for the board |
| `functional_model/`, `hardware_model/` | The Python model of the machine and its compiler |
| `runtime/` | How the GUI talks to Python, the simulator and the board |
| `sim/` | Verilator simulator and testbenches |
| `resources/` | Sources for the Toolbox, `SYSTEM.SYS`, MacPaint tables and Finder's About picture |
| `vectors/` | ROM images the RTL and the Python model load. Generated by `tools/`. |
| `assets/` | Desktop font and pointer art read by the exporters |
| `third_party/` | Digilent's HDMI encoder |
| `tools/` | Card builder, compiler, generators, Vivado flow ([tools/README.md](tools/README.md)) |
| `scripts/` | Shell setup for Vivado and the Python environment |
| `tests/` | `pytest` suite |
| `docs/` | Guides. Start at [docs/README.md](docs/README.md). |
| `releases/` | The current bitstream. Earlier ones are in git history (build 98 at commit cdb489d, build 97 at d6dbe8e). |
| `build/` | Generated output. Not source. |
| `traces/` | GUI session logs |
| `Prince/` | Prince of Persia source material; `tools/make_prince_art.py` makes `PRINCEB`'s art from it |
| `Vigil_prince_like/` | VIGIL, a game in progress. Not on the card. |
| `gauntlet/` | A Gauntlet conversion in progress. Not on the card. |
| `to_be_deleted/` | Retired files, not tracked by git |
