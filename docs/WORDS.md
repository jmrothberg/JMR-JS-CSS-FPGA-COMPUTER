# Words and the folder map

Commands are on the [README](../README.md). The specification is
[CONSTITUTION.md](../CONSTITUTION.md).

## Words used in this project

### The machine

| Word | Meaning |
|---|---|
| **NLISC** | Native Language Instruction Set Computing. The language the user writes is the processor's instruction set. There is no second CPU underneath. This machine is NLISC-JS. |
| **ISA** | Instruction Set Architecture. Here: the 34 bytecode instructions. [JS_COMMANDS.md](JS_COMMANDS.md) |
| **bytecode**, **opcode** | The numbered instructions the compiler emits; one instruction number. |
| **VM** | The engine that executes bytecode: `rtl/engines/jmr_js_vm.sv` and `jmr_js_vm_exec64.sv`. Not a browser, not a soft CPU. |
| **native** | A built-in function the compiler knows by name. It compiles to `CALL_NATIVE` plus an id. |
| **method** | A call on a value (`ctx.fillRect(…)`). It compiles to `CALL_METHOD` plus the name. |
| **Value64** | The 64-bit word that holds every JavaScript value. [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md#values) |
| **heap** | The fixed tables of objects, arrays, scopes and functions. |
| **GC** | Garbage collection: mark and sweep over the heap. |
| **generation** | A counter on each heap slot. A handle whose generation does not match is stale. |
| **fault** | A machine error that stops the program. [Codes](JMR_JS_COMPATIBILITY.md#fault-codes) |
| **Finder** | The desktop. A JavaScript program on the card (`FINDER.HTML`) that starts at power-on and launches the others. |
| **Toolbox** | The shared JavaScript library for windows, menus, dialogs and drawing, loaded from `TOOLBOX.ROM`. [RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md) |
| **resident client** | A program linked to the Toolbox. Its HTML carries the marker `jmr-toolbox: resident-v2`. |
| **session** | The Toolbox layer that owns a program's menus, input routing and frame callback (`tbSession…` calls). [SYSTEM_APPLICATIONS.md](SYSTEM_APPLICATIONS.md) |
| **SOURCE** | The 65,536-byte document buffer the editor, reader and compiler share. |
| **recovery display** | The read-only text screen shown when Finder fails twice in a row. |

### Files

| Word | Meaning |
|---|---|
| **HTML** | A program's source file: one `<canvas>` plus `<script>` blocks. |
| **JSH** | The compiled program on the card: bytecode plus art. Built by the card builder or by the on-machine compiler. |
| **JSB** | The encoding of a JSH (magic `JSB1`). |
| **program image** | The same bytes once loaded into the machine. |
| **ASET** | The art section of a program image: a 256-colour palette and 8-bit pixels. |
| **ARTX** | A program's art file beside its HTML (`NAME.ARTX`, `NAME.ART` on the card). Built from PNG sheets by `tools/make_artx.py`. |
| **ARTJS** | The same art as a script a browser can load. The machine does not run it. |
| **sheet** | One image in the art. A program addresses it as `"jmr:spr:N"`. |
| **card.img** | The FAT32 disk image all three runtimes use. Built from `storage/`. |
| **SYSTEM.SYS** | Fonts, captions and dialog layouts shared by all programs. [SYSTEM_RESOURCES.md](SYSTEM_RESOURCES.md) |
| **8.3 name** | The card's file name form: 8 characters, a dot, 3 characters. |

### Runtimes and tools

| Word | Meaning |
|---|---|
| **Python** (runtime) | The Python model in `functional_model/`. Same results as the chip, not the same speed. |
| **hardware model** | `hardware_model/js_vm.py`. Python that executes the serialized program image with the chip's memories and limits. |
| **FPGA-SIM** | The root `rtl/` compiled by Verilator. The same RTL as the bitstream. |
| **board** | The Nexys Video, reached over the USB tether. |
| **F9** | GUI key that cycles Python, FPGA-SIM and board. |
| **F10** | GUI key that opens the Architecture Monitor. [ARCH_MONITOR.md](ARCH_MONITOR.md) |
| **tether** | The USB link the GUI uses to watch and feed the board. The board runs without it. |
| **host twin** | A Python stand-in for FPGA-SIM, enabled only by `JMR_SIM_HOST=1`. Never the default. |
| **Verilator** | Compiles SystemVerilog to a host executable. |
| **Vivado** | The AMD tool that turns RTL into a bitstream. Linux only. |
| **bitstream** | The file that configures the FPGA (`.bit`). Which one to load: [FPGA_FIT.md](FPGA_FIT.md) |
| **trace** | A session log in `traces/`. Read the newest before re-running a failure. |

### Hardware

| Word | Meaning |
|---|---|
| **FPGA** | Field-Programmable Gate Array. Here the XC7A200T on the Nexys Video. |
| **RTL** | Register-Transfer Level hardware description: the `.sv` files in `rtl/`. |
| **ASIC** | Custom silicon. Not current work. [FUTURE_ASIC_EXTERNAL_RAM.md](FUTURE_ASIC_EXTERNAL_RAM.md) |
| **clock** | The VM runs at 33.333 MHz. Fabric and DDR3 logic run at 100 MHz. |
| **frame** | One 640×480 picture; 1/60 s of machine time. |
| **BRAM** | Block RAM inside the FPGA: code, heap and the canvas. |
| **LUTRAM** | Logic cells used as RAM. Only for tiny tables. |
| **Port A** | The legal on-chip memory shape: address in this clock, data out the next. |
| **external memory** | The 8 MiB window, behind a simple SRAM port, that holds art, the displayed image, SOURCE and the Finder cache. On the board it is DDR3. |
| **DDR3**, **MIG** | The board's memory chip; the Vivado controller that drives it. |
| **FB** | Framebuffer. The canvas in BRAM, and the displayed copy in external memory. |
| **PHY** | The pin-level circuits: HDMI, PS/2, SD, audio. |
| **PSG** | The four-voice sound generator. |
| **Pmod** | Digilent plug-in jacks. JA and JC mice, JB joystick. [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md) |
| **J15** | The USB keyboard jack. |
| **FSM** | Finite state machine. |
| **CDC** | Clock-domain crossing. |
| **WNS** | Worst negative slack. Zero or more means timing is met. |
| **XDC** | Constraints file: `constraints/nexys_video.xdc`. |

## Method (steal from the BASIC sibling — not the product)

Python model, then hardware model, then FPGA-SIM, then the board. The full
rule is in
[CONSTITUTION.md](../CONSTITUTION.md#development-order). The sibling
repository `JMR-BASIC-FPGA-COMPUTER` is a reference for that method only.
Do not copy its tokens, microcode or pinouts.

## Rules for agents

Always-on rules live in `.cursor/rules/`.

| Rule file | Rule | Human page |
|---|---|---|
| `never-fake-fpga-sim.mdc` | FPGA-SIM is the chip's RTL. Memories are synthesizable. | [RTL_DESIGN_PRINCIPLES.md](RTL_DESIGN_PRINCIPLES.md) |
| `one-heap-keep-gen.mdc` | One JavaScript heap. Keep the generation check. | [RTL_REORG.md](RTL_REORG.md) |
| `no-dukpy-cheat-native-cpu.mdc` | No host JavaScript engine, browser or soft CPU as the machine. | [CONSTITUTION.md](../CONSTITUTION.md) |
| `python-first-parity.mdc` | Python, then FPGA-SIM, then the board. | [CONSTITUTION.md](../CONSTITUTION.md#development-order) |
| `no-game-hardwire.mdc` | No program names in RTL, compiler or natives. | [GAME_DESIGN.md](GAME_DESIGN.md) |
| `html-game-v1.mdc` | Programs stay inside the language and size limits. | [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) |
| `poll-fire-needs-cooldown.mdc` | Held-fire polling needs a frame-count cooldown. | [GAME_DESIGN.md](GAME_DESIGN.md#fire-needs-a-cooldown) |
| `no-splice-after-kill-calls.mdc` | Mark dead, sweep once after the loop. | [GAME_DESIGN.md](GAME_DESIGN.md#removing-items-from-a-list) |
| `no-maze-flood-on-tick.mdc` | No full-grid search on a tick. | [GAME_DESIGN.md](GAME_DESIGN.md#speed) |
| `use-existing-traces.mdc` | Read `traces/` before re-running the GUI. | — |
| `single-active-release.mdc` | One active RTL, storage tree, disk image and bitstream. | [FPGA_FIT.md](FPGA_FIT.md) |
| `phone-diagrams.mdc` | Diagrams are high-resolution PNGs. | — |

## Folder map

| Path | What it is |
|---|---|
| `CONSTITUTION.md` | The specification. |
| `gui_jmr_js.py` | The GUI. `gui_arch_monitor.py` is its Architecture Monitor window. |
| `card.img` | The disk image. Built from `storage/`. |
| `CURRENT_SET.json` | Hashes of the matched source, storage and disk set. Checked by `tools/verify_current_set.py`. |
| `storage/` | Source files for the card. [storage/README.md](../storage/README.md) |
| `functional_model/` | The Python model: compiler, bytecode format, machine, canvas, desktop. |
| `hardware_model/` | Python at hardware level: the VM's memories, FAT32, SD. |
| `runtime/` | The GUI's backends for Python, FPGA-SIM and the board. |
| `rtl/` | The SystemVerilog. `engines/` machine, `video/` display, `phys/` pin-level links. [RTL_REORG.md](RTL_REORG.md) |
| `sim/` | Verilator simulator and module testbenches. |
| `constraints/` | Pin and timing constraints for the Nexys Video. |
| `third_party/digilent_rgb2dvi/` | Digilent's HDMI encoder. |
| `vectors/` | ROM images. Builds copy them beside the RTL and into `sim/`. |
| `resources/` | Sources for generated card files: `system/` (SYSTEM.SYS), `toolbox/` (the Toolbox library), `macpaint/`, `compiler_authoring/`. |
| `assets/` | Desktop font and pointer art read by the exporters. |
| `tools/` | Host tools: card builder, compiler front end, art, icons, exporters, `board_flow/` for Vivado. [tools/README.md](../tools/README.md) |
| `scripts/` | Shell setup for Vivado and the Python environment. |
| `tests/` | `pytest` tests. |
| `docs/` | Documentation. [Index](README.md) |
| `gauntlet/` | A game conversion in progress. Not on the card. |
| `releases/` | Release records. Status: [FPGA_FIT.md](FPGA_FIT.md) |
| `build/` | Generated output. Not source. |
| `traces/` | GUI session logs. |
| `to_be_deleted/` | Retired material. Nothing uses it. |
| `.cursor/rules/` | The agent rules above. |
