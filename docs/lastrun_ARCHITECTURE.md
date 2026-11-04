# Memory map

Who owns the disk, the FPGA, and each byte of the 8 MiB aperture. Which bitstream is the rollback, and which folder is in progress: [FPGA_FIT.md](FPGA_FIT.md). Finder is a JavaScript program on the same VM as a game.

![Memory map](diagrams/rarchitecture.svg)

Current board jacks, matching `rtl/top_nexys_video.sv` (`USB_MOUSE=0`):
USB keyboard on **J15**, PS/2 mouse on **JA**, second PS/2 mouse on **JC**,
joystick on **JB**. Pin 1 is mouse data and pin 3 is mouse clock.
`USB_MOUSE=1` is the older J15-mouse / JA-keyboard arrangement, kept so an
older bit can still be built. Details: [USB_KEYBOARD_PMOD_MICE.md](USB_KEYBOARD_PMOD_MICE.md).

## Who owns what

The `.bit` creates the CPU/VM, memory interfaces, graphics engines, input,
filesystem services and shared menu/dialog machinery. These are hardware.

`FINDER.HTM` is the disk source, compiled to `FINDER.JSH`. Finder draws and
manages the desktop, windows, icons, folders, sorting and Trash. Its executable
and saved arena live in external memory across application launches. Returning
replays the executable from RAM and restores the arena; globals/functions are
reconstructed. This is one running application at a time, not two VMs or a
fully suspended Finder heap. Repainting still takes time.

`SYSTEM.SYS` supplies supported shared fonts, captions and dialog settings.
It is data, not executable JavaScript. Python and RTL load the same file from
the mounted disk. Programs provide their own menu actions and About information
through `ctx.systemMenus` and `ctx.systemAbout`; system services handle shared
interaction and rendering. Editor, Reader, Compiler, Note and Utility combine
program behavior with those common services.

Cold boot loads and validates SYS, commits shared resources, and loads Finder.
The Enterprise startup display remains until Finder paints its first frame. Opening an application
parks Finder's arena. File → Quit restores Finder from RAM. Invalid/missing SYS
on cold start retains compiled-in resources. Restart after publishing new SYS
or Finder code; this release has no live resource reload command.

## What is in memory

The board uses a DDR-backed **8 MiB address aperture**. This is separate from
the FPGA's scarce on-chip BRAM. More external RAM does not automatically provide
more BRAM ports or remove placement congestion. The following addresses are
**physical byte offsets**, with end addresses excluded. RTL constants use
16-bit word addresses, so multiply those constants by two.

- **0–6,893,568:** packed artwork / compile-time artwork staging. Programs share
  this space; it is not a simultaneous cache of every game on disk.
- **6,893,568–7,057,408: 160 KiB Finder executable cache.** The shipped JSH is
  148,000 bytes, leaving 15,840 bytes in that fixed cache.
- **7,057,408–7,131,136: 72 KiB parked Finder arena.** File slots, windows, ordering, and comments survive while another program runs. Icon pixels in that cache are not trusted after a program such as MacPaint draws; the next Finder paint reloads them from disk.
- **7,131,136–7,155,712: 24 KiB SYS staging.** The payload uses 24,320 bytes,
  leaving 256 bytes. The 16-byte header is checked separately in registers.
- **7,155,712–7,462,912: 300 KiB DDR front image**, 640 × 480 indexed pixels.
- **7,462,912–7,495,680:** work/storage area plus its reserved gap.
- **7,495,680–7,643,136:** compiler/shared arena, 73,728 logical bytes stored
  one byte per 16-bit physical word. The parked Finder copy is packed; this
  active arena is not. These two sizes must not be confused.
- **7,643,136–7,774,208:** SOURCE, 65,536 logical bytes, one byte per word.
- **7,774,208–8,388,608:** image/compile staging, 307,200 logical bytes, one
  byte per word. Compiler use borrows regions when a game is not running.

Inside the FPGA are the VM execution memories/state, the persistent indexed
BRAM canvas, shared font/caption/keyboard memories and buffering/control logic.
The BRAM canvas and DDR front image have different jobs; adding a resident
Finder did not add another canvas or another VM. Files and original assets
remain on disk until loaded. A 32 MiB card image is storage, not 32 MiB of RAM.

## FPGA usage

Numbers for the qualified bit are on [FPGA_FIT.md](FPGA_FIT.md). Do not copy them here. Spare registers cannot stand in for BRAM. The VM clock is 33.333 MHz. Fabric and DDR stay at 100 MHz.

## What the architecture gained

Moving desktop policy into Finder removes the old dedicated desktop renderer
from the selected build and reuses the existing VM. Desktop changes become
program updates. The tradeoff is 232 KiB of external RAM for the cache and
parked state, plus execution/repaint time. Return avoids rereading Finder from
disk, but is not instantaneous.

SYS replaces fixed-only UI resources with boot-writable memories. Changing a
supported glyph, caption or button position updates both Python and RTL without
Vivado. It adds a loader, validation and write paths; it does **not** inherently
save RAM. The unused legacy About bitmap was separately removed during run75,
recovering four BRAM36 tiles in the isolated overlay synthesis. That is a local
measured saving, not a measured total saving from Finder alone.

There is no controlled old/new synthesis here isolating the Finder conversion
from all other changes, so no total LUT/BRAM saving is claimed. The clearest gain
is avoiding hardware rebuilds for many future UI improvements, not a promise
that every future hardware build will route faster. Current BRAM remains tight.

## SYSTEM.SYS in detail

![SYSTEM.SYS resource flow](diagrams/system-sys.svg)

The 24,336-byte binary has a 16-byte header and a fixed 24,320-byte payload.
The header identifies format 1, exact length and CRC-32. The payload contains
font rows; caption characters and indexes; fixed menu headings; dialog offsets,
button coordinates and style flags; pre-rendered keyboard/ship/accessory
captions; and reserved bytes. See [the exact format](SYSTEM_RESOURCES.md).

The loader validates the staged payload before transferring it to consumers.
An acknowledged clock-domain bridge commits display memory writes in the pixel
clock. Drawing subsequently reads local memories; it does not open the disk
on each pixel or game frame. Dialog hit regions use the corresponding settings,
so moving a supported button also moves its clickable area.

You can change glyph shapes within the existing Chicago metrics, captions,
whole-dialog offsets, button positions/widths, rounded corners and the default
button outline. You cannot add arbitrary dialogs, change font metrics, create
new actions or replace all game graphics with SYS. Finder's desktop lettering
is currently embedded in its program, independent of the shared menu font.
Startup text is resource-driven; the Enterprise silhouette/layout is hardware.

## A small Macintosh-inspired example you can actually try

Apple's [1984 Macintosh manual](https://vintageapple.org/macmanuals/pdf/Macintosh_1984.pdf)
shows the prompt “Save current document as”. Use that wording, retain Chicago,
rounded buttons and the outlined default, and arrange Cancel left / Save right.
This is an adaptation to our fixed dialog geometry, not an exact reproduction
of the original disk dialog or a claim that it provides all its controls.

A complete, packer-validated example is saved as
[macintosh-save.json](../resources/system/examples/macintosh-save.json).
The actual changes from today's configuration are:

```json
"147": "Save current document as:"
```

and, inside `dialog_buttons`:

```json
"save_as": [[400, 214, 84], [278, 214, 96], [0, 0, 0]]
```

Slots retain their identities: first is Save, second Cancel. Save has moved
right; the default outline and actions remain attached to Save. No extra pixels
are stored and the SYS file remains exactly 24,336 bytes. The example's font
path is adjusted only because it lives in the examples subdirectory.

The example has **not** replaced the release or your disk. To adopt it, make
those edits in `resources/system/system.json`, then run:

```sh
.venv/bin/python tools/build_system_resources.py --image card.img
```

Reopen Python, then test FPGA-SIM: File → Save As, inspect the prompt and
outline, click each relocated button, and confirm Save writes and Cancel leaves
the document alone. Copy the resulting SYSTEM.SYS to the board's disk and reboot
after simulator acceptance. No new `.bit` is required.

### Instructions to give an agent

> Read docs/SYSTEM_RESOURCES.md. Apply the Macintosh Save As example from
> resources/system/examples/macintosh-save.json to the production system.json:
> change prompt 147 and the two save_as button placements, retain font metrics
> and all action identities. Publish only SYSTEM.SYS to card.img, test Python
> and RTL Save/Cancel drawing and hit regions, and report the results. Do not
> rebuild the FPGA or change application code for this appearance-only edit.

No model training is required: these are editable resource settings. For a new
Finder behavior or application menu action, instruct the agent to change that
program's JavaScript and rebuild its JSH instead. For a new native primitive,
RTL and a new bitstream would be needed.

## Source of truth

Memory constants: `rtl/engines/jmr_js_vm_pkg.sv`,
`rtl/engines/jmr_console_engine.sv` and `rtl/jmr_js_core.sv`.
Format/validation: `tools/build_system_resources.py`. Resource source:
`resources/system/system.json`. Exact built hardware and reports are frozen
under the build folder named in [FPGA_FIT.md](FPGA_FIT.md). Diagrams describe ownership and flow, not physical
FPGA placement or a proportional drawing of memory sizes.
