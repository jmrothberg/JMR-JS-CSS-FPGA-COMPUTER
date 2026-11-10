# JMR JS Computer — Constitution

This is the architectural specification. If the implementation disagrees
with this document, the implementation is wrong. Change the architecture
only by changing this document first.

Terms: [docs/WORDS.md](docs/WORDS.md).

## Goal

A standalone FPGA computer whose native language is JavaScript. It runs
HTML5 Canvas programs and 2D games, and boots into a Macintosh-like Finder.

JavaScript is compiled to compact bytecode. The bytecode is the processor's
instruction set (NLISC-JS). Hardware engines execute it. Canvas drawing is
hardware.

It is not:

- a soft CPU running V8, QuickJS or any other JavaScript engine
- a browser, or Linux with a browser
- a general HTML/CSS renderer
- the JMR BASIC computer with different keywords

The aim is a machine a student can read from keyboard input to HDMI output.
Prefer clarity over minimum code.

## Rules

1. No Z80, 6502, RISC-V, MicroBlaze or other general-purpose CPU inside.
2. No host JavaScript engine (dukpy, Duktape, V8, QuickJS, Node) on the
   product path, in Python, FPGA-SIM or the board.
3. The bytecode is the instruction set. The user never programs an
   assembly-level machine.
4. Independent engines with defined interfaces. No monolith.
5. Every subsystem has a Python reference model.
6. Every RTL module corresponds to a documented subsystem.
7. The same user-visible behaviour on Python, FPGA-SIM and the board before
   a feature is done.
8. Standalone: HDMI, a local keyboard, mouse and optional joystick. A PC is
   never required to use the machine. The USB tether is for debugging.
9. FPGA-SIM is the RTL that becomes the bitstream. Its memories are
   synthesizable: address in one clock, data out the next. One JavaScript
   heap. Overflow is reported, never hidden.
10. Limits are general and fail loudly. No program name appears in the RTL,
    the compiler or a native.
11. The HTML decides the key bindings. The hardware delivers raw key, mouse
    and joystick events only.
12. ASIC work is out of scope until explicitly opened
    ([docs/FUTURE_ASIC_EXTERNAL_RAM.md](docs/FUTURE_ASIC_EXTERNAL_RAM.md)).

## One disk, one program image

- `card.img` is the disk for all three runtimes. The board uses the same
  image written to a microSD card. `storage/` is its source.
- A program is one `NAME.HTML`. The card builder
  (`tools/make_sd_image.py`) compiles it to `NAME.JSH`. The compiler on the
  machine, itself a JavaScript program on the card, produces the same file.
- Running a program loads its `.JSH`. Python, FPGA-SIM and the board load
  the same bytes.
- Art is carried in the `.JSH` at full quality and loaded into external
  memory. It is never packed into code memory or downscaled to fit.
- A compile error reports the HTML line.

## Development order

```text
Constitution
  → Python functional model      (functional_model/)
  → Python hardware model        (hardware_model/, executes the serialized image)
  → SystemVerilog                (rtl/)
  → FPGA-SIM                     (Verilator, same RTL)
  → board bitstream
```

- Do not skip a step. Do not build a bitstream to find a bug that FPGA-SIM
  has not already shown fixed.
- Python is the fast reference. It must give the same results as the chip:
  same program bytes, same numbers, same faults. It does not model the
  chip's timing.
- Parity is proven on the serialized program image, not on Python objects
  the hardware never sees.
- Compare Python and RTL on small programs first: instruction pointer,
  frames, heap, events, pixels, faults. Debug games after those match.
- Replace one engine at a time. Remove a workaround only when its test
  passes without it.
- Read `traces/` before re-running a failure.

Build and release steps: [docs/FPGA_FIT.md](docs/FPGA_FIT.md). Bring-up:
[docs/FPGA_BRINGUP.md](docs/FPGA_BRINGUP.md).

## Hardware

| Item | Value |
|---|---|
| Board | Digilent Nexys Video, Artix-7 XC7A200T |
| VM clock | 33.333 MHz (the 100 MHz clock divided by three) |
| Fabric and DDR3 clock | 100 MHz. Do not slow it to make the VM meet timing. |
| Display | HDMI, 640×480 at 60 Hz, 8 bits per pixel, 256-colour palette |
| External memory | 8 MiB behind a simple SRAM port. On the board it is DDR3. |
| Disk | microSD, FAT32 |
| Keyboard | USB on J15 |
| Mouse | PS/2 on JA; a second on JC |
| Joystick | Pmod on JB, optional |
| Sound | Four-voice generator to the line-out codec |

Wiring: [docs/USB_KEYBOARD_PMOD_MICE.md](docs/USB_KEYBOARD_PMOD_MICE.md).
Pins and constraints belong to this repository's `constraints/`. Do not copy
pinouts from the BASIC sibling.

## User experience

- Power-on starts Finder from the card (`FINDER.JSH`). Finder is a
  JavaScript program on the same VM as every other program.
- Double-click a program to run it and a document to read it. Quitting, or
  Escape, returns to Finder. A program cannot intercept Escape.
- Games fill the screen under the shared menu bar. Tools draw in a window.
- Windows, menus and dialogs are drawn by the resident Toolbox, a shared
  JavaScript library loaded from the card.
- The editor, reader and compiler are programs on the card. A user can
  edit, compile and run a program with no PC.
- There is no command prompt. A read-only recovery display appears only
  when Finder itself cannot run.

Details: [docs/lastrun_ARCHITECTURE.md](docs/lastrun_ARCHITECTURE.md),
[docs/SYSTEM_APPLICATIONS.md](docs/SYSTEM_APPLICATIONS.md).

## Machine surface

- A subset of JavaScript: [docs/JS_COMMANDS.md](docs/JS_COMMANDS.md).
- A subset of Canvas 2D, in hardware.
- A minimal HTML container: one `<canvas>` and `<script>` blocks. No layout
  and no CSS engine.
- A frame clock, timers and `requestAnimationFrame`.
- Keyboard, mouse and joystick events.
- File, document and program-launch services for system programs.

What is absent, and every limit:
[docs/JMR_JS_COMPATIBILITY.md](docs/JMR_JS_COMPATIBILITY.md).

## Architecture

The processor is a set of engines. Keep them separate. Share datapaths
instead of duplicating them; multi-cycle operations are acceptable.

| Engine | Job |
|---|---|
| Bytecode VM | Fetch, decode, execute. Numbers, heap, strings, calls, garbage collection. |
| Raster engine | Rectangle fill, sprite blit and image-data copy at the fabric clock. |
| Framebuffer present and scanout | Copy changed canvas blocks to the displayed image; feed HDMI. |
| Input | Keyboard FIFO, mouse events, joystick bits. |
| Storage | SD card and FAT32 file services. |
| Program loader and Finder shell | Load a program image, start Finder, switch programs. |
| Sound | Four-voice generator. |

The compiler is not hardware. It is a JavaScript program on the card, and
the same compiler in Python on the PC.

Execution:

```text
NAME.HTML → compile → NAME.JSH → load → fetch / decode / execute
```

Module map: [docs/RTL_REORG.md](docs/RTL_REORG.md). RTL coding rules:
[docs/RTL_DESIGN_PRINCIPLES.md](docs/RTL_DESIGN_PRINCIPLES.md).

## Memory

| Where | Holds |
|---|---|
| Block RAM (on chip) | Code, the JavaScript heap, the value stack, the 640×480 canvas, the Toolbox instruction bank |
| External memory (8 MiB) | Art, the displayed image, the SOURCE document, the Finder cache, compiler work space |
| microSD | Files |

- On-chip arrays are real memories: one-dimensional, one or two ports,
  registered read. An array that only simulates is forbidden even when
  FPGA-SIM programs look right.
- The VM sees external memory only through the SRAM port (22-bit word
  address, 16-bit data, request and acknowledge). FPGA-SIM, the board and
  any later chip implement that same port.
- Addresses are defined once, in `rtl/engines/jmr_js_vm_pkg.sv` and
  `functional_model/jsb_format.py`. Do not hard-code them elsewhere.

Address map: [docs/diagrams/memory-map.png](docs/diagrams/memory-map.png).

## Testing

- Real programs are the regression tests. Every accepted program stays one.
- `pytest` in `tests/`; the simulator user loop in `sim/`.
- Do not use random program generation as the main strategy.

## Rules for agents

Do: implement, refactor locally, add tests, keep documents current.

Do not: redesign the architecture, merge engines, add a hidden CPU or host
JavaScript engine, add behaviour that exists only in RTL, or delete files
without being asked.

## Success

- It feels like an early personal computer that speaks JavaScript: switch
  on, see the desktop, run, edit, compile.
- The same picture and behaviour on Python, FPGA-SIM and the board.
- `INVF.HTML`, `PACFAST.HTML` and `DNKF.HTML` (Space Invaders, Pac-Man,
  Donkey Kong) run and are playable on all three.
- Standalone: HDMI, USB keyboard, PS/2 mouse, optional joystick. No PC.
- A reader of the repository can follow how a complete computer works.
