# JMR JS Computer

A computer whose processor runs JavaScript. There is no CPU underneath: the
compiled JavaScript is the instruction set. Programs are HTML files on a
microSD card. The machine boots into a Macintosh-style Finder and runs them
on the Digilent Nexys Video (Vision). The custom A200T D2-A1 build is ready
for first-board testing. The same programs run on the PC in a Python model
and in an RTL simulator (FPGA-SIM).

The current release is **build 99**. Since build 98 a program has
**29,696 words for its code**, up from 21,504 (38% more), and since build 97
it has **32 KB for names and strings**, up from 16 KB. The Toolbox has its
own bank and does not use that room. Build 99 also runs most instructions in
3 clocks instead of 4.

See [Current board builds and project layout](docs/BOARD_BUILDS.md) for
the bitstreams, shared disk and simulator, and the A200T test results.

## Get started

### What you need

| Item | Notes |
|---|---|
| Custom A200T D2-A1 with C3 motherboard | VGA monitor, motherboard USB keyboard and mouse, and the external FT2232 JTAG adapter on channel B. [Wiring and first power-on](A200T_D2A1_BRINGUP/START_HERE.md) |
| Vision (Digilent Nexys Video) | HDMI monitor, USB keyboard at **J15**, PS/2 mouse at **JA** through a Pmod adapter. Optional second mouse on **JC** and joystick on **JB**. [Wiring](docs/USB_KEYBOARD_PMOD_MICE.md) |
| microSD card | Both boards use the same build 99 card. Burning an image erases the selected card. |
| Linux PC | Python 3 with `.venv` (`pip install -r requirements.txt`), `openFPGALoader`. Vivado only to build a new bitstream. |

### 1. Use the build 99 microSD

Use your existing build 99 microSD on either board. Power off before moving
the card. If you need to prepare another one, write the existing project
image from this repository's folder. Replace `/dev/sdX` with the whole
device for the removable card.

```sh
cd ~/JMR-JS-CSS-FPGA-COMPUTER
lsblk                                            # find the card, e.g. /dev/sdb
sudo python3 tools/make_sd_image.py burn /dev/sdX --keep-image
```

### 2. Install the bitstream over JTAG

Run the command for your board from the repository root. Both commands
load the FPGA for the current power session.

#### Custom A200T D2-A1 / C3

Follow the [A200T power and wiring guide](A200T_D2A1_BRINGUP/START_HERE.md),
then connect the same external FT2232 channel B adapter used for the A100T
BASIC and Macintosh boards. With the A200T powered, run:

```sh
python3 A200T_D2A1_BRINGUP/jtag.py load
```

The loader checks the package and the JTAG device before loading
`A200T_D2A1_BRINGUP/jmr_js_a200t_d2a1.bit`. Allow about 30 seconds for the
64 MiB HyperRAM self-test and startup. First-board testing is pending.

#### Vision (Digilent Nexys Video)

Connect the board's USB PROG port to the Linux PC and turn on the board.

```sh
openFPGALoader -b nexysVideo releases/current/jmr_js_mac.bit
```

For a persistent Vision install, use `openFPGALoader -b nexysVideo -f releases/current/jmr_js_mac.bit`
and set JP4 to QSPI for boot. [Vision loading guide](docs/FPGA_BRINGUP.md#loading-a-bitstream)

### 3. Boot and check

The machine shows a startup picture, then Finder. In the ship menu at the
left of the menu bar, Finder's About shows the build the card was made for
("Build 99" and the date). Both builds load `TOOLBOX.ROM` from the shared
build 99 card.

### 4. Run a program

Double-click a program to run it, a document to read it. Esc returns to
Finder. Special → Help opens the on-card manual (`storage/HELP.MD`).

## Custom A200T board resources and timing

The custom A200T build meets routed timing with **+0.002 ns setup** and
**+0.051 ns hold** slack. Block RAM is the closest resource to capacity
at **97.12%**. The board guide lists the components, FPGA usage, clocks,
and simulation evidence. [A200T resources and timing](docs/BOARD_BUILDS.md#a200t-components-fpga-use-and-timing)

## Commands

Run from the repository folder.

| To | Command |
|---|---|
| Build `card.img` from `storage/` | `python3 tools/make_sd_image.py create card.img` |
| Write a microSD card | `sudo python3 tools/make_sd_image.py burn /dev/sdX` (`--keep-image` to skip the rebuild) |
| Install on custom A200T (JTAG) | `python3 A200T_D2A1_BRINGUP/jtag.py load` |
| Install on Vision (JTAG) | `openFPGALoader -b nexysVideo releases/current/jmr_js_mac.bit` |
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
| Rebuild a bitstream | [Vision build flow](docs/FPGA_FIT.md) or [A200T build flow](boards/a200t_d2a1/README.md#rebuild-and-checks) |
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
| `A200T_D2A1_BRINGUP/` | Custom A200T bitstream, JTAG loader, bring-up guide and FPGA reports. |
| `boards/a200t_d2a1/` | Custom A200T hardware interface sources and build flow. |
| `releases/` | The Vision bitstream. Earlier ones are in git history (build 98 at commit cdb489d, build 97 at d6dbe8e). |
| `build/` | Generated output. Not source. |
| `traces/` | GUI session logs |
| `Prince/` | Prince of Persia source material; `tools/make_prince_art.py` makes `PRINCEB`'s art from it |
| `Vigil_prince_like/` | VIGIL, a game in progress. Not on the card. |
| `gauntlet/` | A Gauntlet conversion in progress. Not on the card. |
| `to_be_deleted/` | Retired files, not tracked by git |
